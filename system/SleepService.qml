pragma Singleton

// SleepService.qml
// Locks the session before the machine suspends, and honours logind's
// inbound Lock signal so external callers can lock us.
//
// Why this isn't just "lock when we see PrepareForSleep"
// -----------------------------------------------------
// logind emits PrepareForSleep and then suspends. Calling lock() on that
// signal starts the lock, but the surface maps asynchronously — so the
// machine can go down with the desktop still on screen and flash it on
// resume before the lock paints.
//
// The fix is a **delay** inhibitor, held continuously. It does not prevent
// suspend; it asks logind to wait after PrepareForSleep until we release it,
// bounded by InhibitDelayMaxSec (5 s by default). We release only once
// LockService.secure confirms the compositor has covered every output.
//
// This is the standard pattern rather than anything clever — kwin_wayland
// holds the exact same inhibitor, with the reason string "Ensuring that the
// screen gets locked before going to sleep".
//
// Fail-open, by necessity
// -----------------------
// If secure never arrives, a watchdog releases anyway. That is not a
// preference: logind proceeds once its budget expires no matter what we do,
// so refusing to release would buy nothing and risk wedging suspend. The
// watchdog simply makes the release deliberate and keeps us inside budget.
//
// Why gdbus and not dbus-monitor
// ------------------------------
// Quickshell ships no generic DBus client, so the signal has to come from a
// subprocess. `dbus-monitor --system` needs privileges a user session does
// not have: it fails to enable monitoring and falls back to eavesdropping,
// which modern dbus policy denies. `gdbus monitor` uses ordinary match
// rules and works unprivileged. Output is one line per signal:
//
//   /org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)
//   /org/freedesktop/login1/session/_33: org.freedesktop.login1.Session.Lock ()
//
// IMPORTANT: pragma Singleton must be line 1 (gotcha #45). Header comments
// must NOT contain curly braces — the qmlscanner doesn't strip them and the
// brace tracker gets confused, silently registering this file as a regular
// type instead of a singleton.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.compositor
import qs.lock

Singleton {
    id: root

    // ---- Public state ----

    // True between PrepareForSleep(true) and PrepareForSleep(false).
    property bool sleeping: false

    // Our own session's logind object path, e.g.
    // "/org/freedesktop/login1/session/_33". Resolved once at startup.
    // Empty means inbound Lock handling is inactive.
    property string sessionPath: ""

    // Whether we intend to be holding the delay inhibitor. Distinct from
    // inhibitor.running: during the suspend window we deliberately let go,
    // and the death-watch below must not fight that.
    property bool _wantInhibitor: false

    // Same idea for the watcher. Both death-watches are gated on intent
    // rather than restarting unconditionally, because "the child exited"
    // is also what teardown looks like: respawning there races the shell's
    // own destruction and spawns a process into a half-torn-down state.
    property bool _wantWatcher: false

    readonly property bool inhibitorHeld: inhibitor.running

    function statusText() {
        return "inhibitor " + (root.inhibitorHeld ? "held" : "released")
            + " | watcher " + (watcher.running ? "alive" : "dead")
            + " | session " + (root.sessionPath !== "" ? root.sessionPath : "unresolved")
            + " | resume output check " + (Compositor.supportsOutputProbe ? "on" : "unsupported")
            + (root.sleeping ? " | sleeping" : "");
    }

    // ---- Inhibitor ----

    function _takeInhibitor() {
        root._wantInhibitor = true;
        if (!inhibitor.running) inhibitor.running = true;
    }

    function _releaseInhibitor() {
        // Clear the intent BEFORE stopping, or the death-watch in
        // onRunningChanged re-takes the lock we are trying to drop and
        // suspend stalls until logind's budget expires.
        root._wantInhibitor = false;
        releaseWatchdog.stop();
        if (inhibitor.running) inhibitor.running = false;
    }

    Process {
        id: inhibitor
        // setpriv --pdeathsig TERM: Quickshell does NOT reap long-running
        // child processes when the shell exits — they get reparented to init
        // and survive. Verified by killing the shell and watching the
        // inhibitor stay in `systemd-inhibit --list`.
        //
        // That matters more here than for a typical stray process: an orphan
        // delay inhibitor keeps claiming a slice of logind's suspend budget
        // with nothing behind it to lock, and they accumulate one per shell
        // restart. pdeathsig ties the child's lifetime to ours, so the
        // inhibitor fd closes and the lock is released the moment we die.
        command: [
            "setpriv", "--pdeathsig", "TERM", "--",
            "systemd-inhibit",
            "--what=sleep",
            "--mode=delay",
            "--who=quickshell-bar",
            "--why=lock before sleep",
            "sleep", "infinity"
        ]
        onRunningChanged: {
            // Re-take if it died on its own (logind restart, OOM kill). A
            // silently-missing delay inhibitor is the failure mode that puts
            // us back to racing the lock against suspend, so it is worth a
            // warning rather than a quiet retry.
            if (!running && root._wantInhibitor) {
                console.warn("[SleepService] delay inhibitor exited unexpectedly, re-taking");
                running = true;
            }
        }
    }

    // Backstop for the release. Well inside logind's 5 s InhibitDelayMaxSec
    // so we always release on our own terms rather than being overridden.
    Timer {
        id: releaseWatchdog
        interval: 2500
        repeat: false
        onTriggered: {
            console.warn("[SleepService] lock surface not confirmed in",
                releaseWatchdog.interval + "ms; suspending anyway");
            root._releaseInhibitor();
        }
    }

    // Release the moment the compositor reports every output covered.
    Connections {
        target: LockService
        function onSecureChanged() {
            if (root.sleeping && LockService.secure) root._releaseInhibitor();
        }
    }

    // ---- Signal handling ----

    function _onSleep() {
        if (root.sleeping) return;
        root.sleeping = true;
        root._cancelOutputChecks();

        LockService.lock();

        // Already covered (e.g. suspending from an existing lock) — nothing
        // to wait for.
        if (LockService.secure) {
            root._releaseInhibitor();
            return;
        }
        releaseWatchdog.restart();
    }

    function _onResume() {
        root.sleeping = false;
        // Re-arm for the next cycle. Deliberately does NOT unlock: coming
        // back from suspend is not authentication.
        root._takeInhibitor();

        root._resumedAt = Date.now();
        if (Compositor.supportsOutputProbe) resumeCheck.restart();
    }

    // ---- Post-resume output recovery ----
    //
    // On the desktop (RX 9060 XT, amdgpu), deep sleep resume does a MODE1
    // GPU reset. Sometimes the DP links come back wedged: the kernel logs
    // "No EDID read" on DP-1 and niri then fails every page flip with
    // EINVAL, on both outputs, until the cables are physically replugged.
    // niri's own resume recovery only runs on a logind session pause and
    // resume, which S3 does not trigger, so nothing resyncs it. Seen on
    // 2026-09-23 at 14:46 and 19:12.
    //
    // So 5 s after resume we ask the compositor whether any frame failed
    // since just before the resume. On a bad resume niri logs the flip
    // failure within the first second and keeps logging it twice a second.
    // On a good one it logs none, and nothing else happens. The first
    // version cycled on every resume, and a good wake visibly blinked.
    //
    // If frames are failing, power the outputs off and on again through
    // Compositor.dispatchDpms. Untested theory: the fresh modeset clears
    // the stale link state the way a replug does. 5 s after power-on we
    // check again and log "recovered" or "still failing", which is what
    // settles the theory. No automatic retry, so a failure the cycle cannot
    // fix does not become a blink loop. If the log keeps saying "still
    // failing", the fallback is a root sleep hook that writes off and
    // detect to /sys/class/drm/card1-DP-*/status.
    //
    // Skipped entirely on compositors without an output probe.

    // Epoch ms of the last PrepareForSleep(false).
    property real _resumedAt: 0
    // Epoch ms when the last cycle powered the outputs back on.
    property real _cycleOnAt: 0
    // Bumped when a suspend starts. A probe answer that arrives after that
    // belongs to the previous wake and is dropped.
    property int _checkGen: 0

    // Search back to lookbackSec ago, and cycle the outputs if frames have
    // failed in that window. The post-resume path, callable from IPC.
    function checkOutputs(lookbackSec) {
        if (!Compositor.supportsOutputProbe) {
            console.log("[SleepService] output check not supported on this compositor");
            return;
        }
        root._checkSince(Date.now() - lookbackSec * 1000, false);
    }

    // Power the outputs off and on again, then check the result. Ignored
    // while a cycle is already running.
    function cycleOutputs() {
        if (cycleOnDelay.running) return;
        console.log("[SleepService] cycling outputs");
        Compositor.dispatchDpms(false);
        cycleOnDelay.restart();
    }

    // afterCycle: this is the check that follows a cycle. It only reports,
    // never cycles again.
    function _checkSince(sinceMs, afterCycle) {
        const gen = root._checkGen;
        const since = Qt.formatDateTime(new Date(sinceMs), "yyyy-MM-dd HH:mm:ss");
        Compositor.probeOutputsFailing(sinceMs / 1000, failing => {
            if (gen !== root._checkGen) return;
            if (afterCycle) {
                if (failing) console.warn("[SleepService] frames still failing after the output cycle");
                else console.log("[SleepService] outputs recovered after the cycle");
            } else if (failing) {
                console.warn("[SleepService] frames failing since", since, "- cycling outputs");
                root.cycleOutputs();
            } else {
                console.log("[SleepService] outputs OK, no failed frames since", since);
            }
        });
    }

    function _cancelOutputChecks() {
        root._checkGen++;
        resumeCheck.stop();
        cycleVerify.stop();
        // cycleOnDelay is left to run. Stopping it mid-cycle would leave
        // the outputs off.
    }

    Timer {
        id: resumeCheck
        interval: 5000
        repeat: false
        // 2 s of lookback in case niri logged its first failure before the
        // PrepareForSleep(false) line reached us.
        onTriggered: root._checkSince(root._resumedAt - 2000, false)
    }

    Timer {
        id: cycleOnDelay
        interval: 1000
        repeat: false
        onTriggered: {
            Compositor.dispatchDpms(true);
            root._cycleOnAt = Date.now();
            if (Compositor.supportsOutputProbe) cycleVerify.restart();
        }
    }

    Timer {
        id: cycleVerify
        interval: 5000
        repeat: false
        // Starts 2 s after power-on, so a flip that failed while the panels
        // were still coming up does not count against the cycle.
        onTriggered: root._checkSince(root._cycleOnAt + 2000, true)
    }

    function _handleLine(line) {
        if (!line || line.length === 0) return;

        if (line.indexOf("PrepareForSleep (true") >= 0)  { root._onSleep();  return; }
        if (line.indexOf("PrepareForSleep (false") >= 0) { root._onResume(); return; }

        // Inbound lock request. Deliberately NOT handling Session.Unlock:
        // `loginctl unlock-session` would drop the lock screen without PAM
        // ever running, which is a straight authentication bypass. Locking
        // is safe to accept from anyone; unlocking is not.
        if (line.indexOf(".Session.Unlock") >= 0) return;
        if (root.sessionPath === "") return;
        if (line.indexOf(root.sessionPath + ":") !== 0) return;
        if (line.indexOf(".Session.Lock") >= 0) {
            console.log("[SleepService] logind Lock signal — locking");
            LockService.lock();
        }
    }

    Process {
        id: watcher
        // pdeathsig for the same reason as the inhibitor above — otherwise
        // every shell restart strands another gdbus monitor on the bus.
        command: ["setpriv", "--pdeathsig", "TERM", "--",
                  "gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root._handleLine(line)
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: line => console.warn("[SleepService gdbus]", line)
        }
        onRunningChanged: {
            if (!running && root._wantWatcher) {
                console.warn("[SleepService] gdbus monitor exited, restarting...");
                running = true;
            }
        }
    }

    // ---- Session path ----
    //
    // logind escapes session ids into object paths (XDG_SESSION_ID=3 becomes
    // /org/freedesktop/login1/session/_33), so ask for the path instead of
    // building it. --json=short keeps the reply trivially parseable:
    //   {"type":"o","data":["/org/freedesktop/login1/session/_33"]}

    Process {
        id: sessionQuery
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = (this.text || "").trim();
                if (raw.length === 0) return;
                try {
                    const parsed = JSON.parse(raw);
                    if (parsed && parsed.data && parsed.data.length > 0) {
                        root.sessionPath = parsed.data[0];
                    }
                } catch (e) {
                    console.warn("[SleepService] session path parse error:", e, "raw:", raw);
                }
            }
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: line => console.warn("[SleepService busctl]", line)
        }
    }

    // Forces instantiation from shell.qml. Singletons are lazy, and a lazy
    // SleepService is one that never takes the inhibitor — same reason
    // IdleService and SystemTheme have one.
    function bootstrap() {
        root._takeInhibitor();

        root._wantWatcher = true;
        watcher.running = true;

        const sid = Quickshell.env("XDG_SESSION_ID") || "";
        if (sid.length === 0) {
            // Not fatal: suspend-lock works regardless. Only the inbound
            // Lock signal needs the path, and without a session id there is
            // no session to scope it to.
            console.warn("[SleepService] XDG_SESSION_ID unset — inbound lock signal disabled");
            return;
        }
        sessionQuery.command = [
            "busctl", "--system", "--json=short", "call",
            "org.freedesktop.login1", "/org/freedesktop/login1",
            "org.freedesktop.login1.Manager", "GetSession", "s", sid
        ];
        sessionQuery.running = true;
    }
}
