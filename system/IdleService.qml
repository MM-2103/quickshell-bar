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
    function blankNow() { root._dpmsOff(); }

    function statusText() {
        if (!root.enabled) return "idle handling disabled (caffeine)";
        if (!root.anyStageEnabled) return "no idle stages configured";
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

    function _dpmsOff() {
        if (root.monitorsBlanked) return;
        root.monitorsBlanked = true;
        Compositor.dispatchDpms(false);
    }

    function _dpmsOn() {
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
        enabled: root.enabled && root.anyStageEnabled

        timeout: root.firstStageSeconds

        // Honour idle-inhibit-v1 holders: video players, presentation mode,
        // games. Free, and better than what the old hypridle config did.
        respectInhibitors: true

        onIsIdleChanged: {
            if (monitor.isIdle) root._onIdle();
            else root._onActive();
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

    // Forces instantiation from shell.qml. Singletons are lazy, and a lazy
    // idle service is one that never arms — same reason SystemTheme has one.
    //
    // Logged as "initial" because config.jsonc has not necessarily been read
    // yet at this point; see onFirstStageSecondsChanged.
    function bootstrap() {
        root._booted = true;
        console.log("[IdleService] initial:", root.statusText());
    }
}
