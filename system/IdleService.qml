pragma Singleton

// IdleService.qml
// Native idle handling. Replaces the external hypridle / swayidle daemon
// that this shell used to require.
//
// Quickshell 0.3.0 exposes ext-idle-notifier-v1 as Quickshell.Wayland's
// IdleMonitor, so the shell can watch for user inactivity itself instead of
// having a second daemon watch and then poke us over IPC.
//
// Two stages, both independently disableable by setting their timeout to 0:
//
//   idleLockSeconds  - lock the session      default 300
//   idleDpmsSeconds  - blank the monitors    default 360
//
// Staging with ONE monitor
// ------------------------
// IdleMonitor carries a single timeout, so N stages would naively mean N
// monitors all racing the same activity stream. Instead we arm one monitor
// at the EARLIEST enabled timeout and express every later stage as a delay
// measured from that point:
//
//   lock 300, dpms 360  ->  monitor fires at 300
//                           lock  delay =   0  -> fire immediately
//                           dpms  delay =  60  -> Timer
//
// Any activity flips isIdle back to false, which cancels the pending delay
// timers and wakes the monitors if we were the one who blanked them.
//
// respectInhibitors
// -----------------
// Set true, so anything holding idle-inhibit-v1 (mpv, browsers playing
// video, Steam) suppresses the whole cycle for free. hypridle's stock config
// did not do this, so this is a behaviour upgrade rather than parity.
//
// Caffeine
// --------
// Because the shell now owns idle detection, "keep awake" is just
// `enabled = false` on our own monitor — no Wayland inhibitor of our own
// needed, since there is nobody else left to inhibit. ControlCenterService
// still runs a systemd-inhibit alongside for the logind-level concerns
// (suspend timer, lid switch) that are not ours to answer.
//
// Not covered here
// ----------------
// Locking before suspend needs logind's PrepareForSleep signal, and
// Quickshell has no generic DBus client. That stays a systemd user unit —
// see examples/quickshell-lock.service. It is six lines and replaces the
// entire hypridle.conf.
//
// IMPORTANT: pragma Singleton must be line 1 (gotcha #45). Header comments
// must NOT contain curly braces — the qmlscanner doesn't strip them and the
// brace tracker gets confused, silently registering this file as a regular
// type instead of a singleton.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.compositor
import qs.lock

Singleton {
    id: root

    // ---- Config ----
    //
    // Seconds of inactivity before each stage. 0 disables that stage.
    // Clamped at 0 so a negative in config.jsonc reads as "off" rather than
    // arming a monitor with a nonsense timeout.

    readonly property int lockSeconds: Math.max(0, Local.get("idleLockSeconds", 300))
    readonly property int dpmsSeconds: Math.max(0, Local.get("idleDpmsSeconds", 360))

    // ---- Public state ----

    // Master switch. Caffeine flips this off; the IPC handler exposes it.
    // Persisted nowhere on purpose — same as DND, a fresh shell starts awake.
    property bool enabled: true

    // True between the monitor firing and the next activity.
    readonly property bool idle: monitor.isIdle

    // True while we are the reason the monitors are off. Guards the wake
    // dispatch so activity doesn't spam `dpms enable` at a compositor that
    // was never blanked by us.
    property bool monitorsBlanked: false

    // Apps currently asking us not to idle, over D-Bus. Strings of the form
    // "app: reason", published by system/inhibit-bridge.py.
    //
    // This is a separate channel from IdleMonitor's respectInhibitors, which
    // only covers the Wayland idle-inhibit-v1 protocol. Most browsers use the
    // older D-Bus route for windowed video — Firefox-family ones only take a
    // Wayland inhibitor when the video is fullscreen — so without this a
    // YouTube tab does not stop the lock. hypridle and Plasma both own these
    // D-Bus names; losing hypridle is what regressed the behaviour.
    property var inhibitHolders: []
    readonly property bool externalInhibited: root.inhibitHolders.length > 0

    // ---- Derived scheduling ----

    readonly property var _stages: {
        const out = [];
        if (root.lockSeconds > 0) out.push(root.lockSeconds);
        if (root.dpmsSeconds > 0) out.push(root.dpmsSeconds);
        return out;
    }

    readonly property bool anyStageEnabled: _stages.length > 0

    // The point we arm the single IdleMonitor at.
    readonly property int firstStageSeconds:
        anyStageEnabled ? Math.min.apply(null, _stages) : 0

    // Each stage's offset from firstStageSeconds. -1 means "stage disabled".
    readonly property int lockDelayMs:
        lockSeconds > 0 ? (lockSeconds - firstStageSeconds) * 1000 : -1
    readonly property int dpmsDelayMs:
        dpmsSeconds > 0 ? (dpmsSeconds - firstStageSeconds) * 1000 : -1

    // ---- Public methods ----

    function setEnabled(on) { root.enabled = !!on; }
    function toggle()       { root.enabled = !root.enabled; }

    // Force the DPMS stage now, without waiting for idle. Bound to the IPC
    // handler so a compositor keybind can blank the screen on demand.
    //
    // Arms wakeWatch, because otherwise this is a trap. The normal wake path
    // is the idle->active edge, and a manual blank never went idle, so that
    // edge never comes. Compositors don't reliably cover for us either:
    // Hyprland's key_press_enables_dpms / mouse_move_enables_dpms both
    // default to off, so on a stock config the screens would stay dark with
    // no input able to revive them.
    function blankNow() {
        root._manualBlank = true;
        root._wakeArmed = false;
        root._dpmsOff();
    }

    function statusText() {
        if (!root.enabled) return "idle handling disabled (caffeine)";
        if (!root.anyStageEnabled) return "no idle stages configured";
        if (root.externalInhibited) {
            // Lead with this: "why didn't my screen lock" is the question
            // this command exists to answer, and an app holding an inhibit
            // is the answer far more often than a misread timeout.
            return "inhibited by " + root.inhibitHolders.join(", ")
                + " | lock " + (root.lockSeconds > 0 ? root.lockSeconds + "s" : "off")
                + " | dpms " + (root.dpmsSeconds > 0 ? root.dpmsSeconds + "s" : "off");
        }
        return "armed at " + root.firstStageSeconds + "s"
            + " | lock " + (root.lockSeconds > 0 ? root.lockSeconds + "s" : "off")
            + " | dpms " + (root.dpmsSeconds > 0 ? root.dpmsSeconds + "s" : "off")
            + " | " + (root.idle ? "idle" : "active")
            + (root.monitorsBlanked ? " | monitors blanked" : "");
    }

    // ---- Internals ----

    // Set by bootstrap(). Gates the re-arm log so the binding system's first
    // evaluation of firstStageSeconds (0 -> default, which happens before
    // shell.qml's Component.onCompleted) doesn't report itself as a re-arm.
    property bool _booted: false

    // True while the current blank came from blankNow() rather than from the
    // idle cycle. Only these need wakeWatch; an idle blank is already woken
    // by the main monitor's idle->active edge.
    property bool _manualBlank: false

    // wakeWatch has gone idle at least once, so the next active edge is real
    // input rather than the monitor initialising.
    property bool _wakeArmed: false

    function _dpmsOff() {
        if (root.monitorsBlanked) return;
        root.monitorsBlanked = true;
        Compositor.dispatchDpms(false);
    }

    function _dpmsOn() {
        root._manualBlank = false;
        root._wakeArmed = false;
        if (!root.monitorsBlanked) return;
        root.monitorsBlanked = false;
        Compositor.dispatchDpms(true);
    }

    function _onIdle() {
        // Stage delays are measured from the monitor firing, so a 0 delay
        // means "this stage IS the monitor's timeout" — run it right now
        // rather than arming a zero-length Timer.
        if (root.lockDelayMs === 0) LockService.lock();
        else if (root.lockDelayMs > 0) lockTimer.restart();

        if (root.dpmsDelayMs === 0) root._dpmsOff();
        else if (root.dpmsDelayMs > 0) dpmsTimer.restart();
    }

    function _onActive() {
        lockTimer.stop();
        dpmsTimer.stop();
        root._dpmsOn();
        // Deliberately NOT unlocking. Waking the screen is not authentication;
        // LockService stays locked until PAM says otherwise.
    }

    IdleMonitor {
        id: monitor

        // Disarm entirely when caffeinated or when every stage is off. An
        // IdleMonitor with enabled=false holds no ext-idle-notifier
        // subscription at all, which is exactly the semantics we want for
        // caffeine — there is nothing left to inhibit.
        enabled: root.enabled && root.anyStageEnabled && !root.externalInhibited

        timeout: root.firstStageSeconds

        // Honour idle-inhibit-v1 holders: video players, presentation mode,
        // games. Covers the Wayland protocol only; the D-Bus half arrives via
        // externalInhibited above.
        respectInhibitors: true

        onIsIdleChanged: {
            if (monitor.isIdle) root._onIdle();
            else root._onActive();
        }
    }

    // Wake path for blankNow() only. Short timeout so it reaches the idle
    // state almost immediately after a manual blank; the next input then
    // produces the active edge that turns the monitors back on.
    //
    // respectInhibitors is deliberately false here, unlike the main monitor.
    // An inhibitor-respecting monitor never goes idle while mpv is playing,
    // which would leave _wakeArmed false and strand the screens dark — the
    // exact failure this exists to prevent.
    IdleMonitor {
        id: wakeWatch
        enabled: root.monitorsBlanked && root._manualBlank
        timeout: 1
        respectInhibitors: false
        onIsIdleChanged: {
            if (wakeWatch.isIdle) {
                root._wakeArmed = true;
                return;
            }
            // Ignore the false that comes from enabling/resetting; only a
            // transition after we've actually seen idle means real input.
            if (root._wakeArmed) root._dpmsOn();
        }
    }

    Timer {
        id: lockTimer
        interval: Math.max(0, root.lockDelayMs)
        repeat: false
        onTriggered: LockService.lock()
    }

    Timer {
        id: dpmsTimer
        interval: Math.max(0, root.dpmsDelayMs)
        repeat: false
        onTriggered: root._dpmsOff()
    }

    // Config edits land while we may be mid-cycle. Re-arming the monitor
    // with a new timeout does not re-run _onIdle, so drop any pending stage
    // timers and un-blank rather than leaving the user staring at a black
    // screen that no longer has a wake path.
    //
    // This also fires once shortly after startup: Local's FileView loads
    // asynchronously, so the first evaluation of lockSeconds/dpmsSeconds
    // uses the built-in defaults and the user's config arrives a moment
    // later. That's why bootstrap()'s log line says "initial" — it is not
    // necessarily the configuration we end up running with.
    onFirstStageSecondsChanged: {
        lockTimer.stop();
        dpmsTimer.stop();
        root._dpmsOn();
        if (root._booted) console.log("[IdleService] re-armed:", root.statusText());
    }

    onEnabledChanged: {
        if (!root.enabled) {
            lockTimer.stop();
            dpmsTimer.stop();
            root._dpmsOn();
        }
    }

    // ---- D-Bus inhibit bridge ----
    //
    // Quickshell can consume D-Bus services but cannot provide one, so the
    // ScreenSaver / PowerManagement.Inhibit names are owned by a helper
    // process that reports holder changes as JSON lines. See the file header
    // in system/inhibit-bridge.py for why both names and three object paths
    // are needed.

    property bool _wantBridge: false

    // Set when the helper exits 3 (PyGObject missing). Stops the death-watch
    // from spinning on a dependency that will not appear at runtime.
    property bool _bridgeUnavailable: false

    Process {
        id: inhibitBridge

        // pdeathsig for the same reason SleepService needs it: Quickshell
        // does not reap children on exit, and this one holds bus names. An
        // orphan would keep owning org.freedesktop.ScreenSaver after the
        // shell died, so the next shell silently fails to acquire it and
        // every inhibit request is answered by a corpse.
        command: ["setpriv", "--pdeathsig", "TERM", "--", "python3",
                  Qt.resolvedUrl("inhibit-bridge.py").toString().replace("file://", "")]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (!line || line.length === 0) return;
                try {
                    const payload = JSON.parse(line);
                    root.inhibitHolders = payload.holders || [];
                } catch (e) {
                    console.warn("[IdleService] inhibit bridge parse error:", e, "line:", line);
                }
            }
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: line => console.warn("[IdleService inhibit-bridge]", line)
        }

        onExited: code => {
            if (code === 3) {
                root._bridgeUnavailable = true;
                console.warn("[IdleService] D-Bus idle inhibits unavailable "
                    + "(python-gobject missing); Wayland inhibits still honoured");
            }
        }
        onRunningChanged: {
            if (running) return;
            // Anything we were told about died with the helper; holding stale
            // holders would inhibit idle forever.
            root.inhibitHolders = [];
            if (root._wantBridge && !root._bridgeUnavailable) {
                console.warn("[IdleService] inhibit bridge exited, restarting...");
                running = true;
            }
        }
    }

    // Forces instantiation from shell.qml. Singletons are lazy, and a lazy
    // idle service is one that never arms — same reason SystemTheme has one.
    //
    // Logged as "initial" because config.jsonc has not necessarily been read
    // yet at this point; see onFirstStageSecondsChanged.
    function bootstrap() {
        root._booted = true;
        root._wantBridge = true;
        inhibitBridge.running = true;
        console.log("[IdleService] initial:", root.statusText());
    }
}
