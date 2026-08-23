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
