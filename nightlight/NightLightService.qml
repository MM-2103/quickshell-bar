pragma Singleton

// NightLightService.qml
// Blue-light filter state, backed by hyprsunset.
//
// Split of responsibilities: this service owns the daemon's lifecycle and
// the user-facing state, while the actual "set the temperature" call goes
// through Compositor.dispatchNightLight so no compositor-specific command
// leaks outside compositor/Backend*.qml.
//
// Turning the filter off dispatches identity rather than killing the
// daemon. Keeping it alive is what makes toggling instant: restarting
// hyprsunset resets gamma to neutral for as long as the restart takes,
// which reads as a flash every time you change the temperature.
//
// Both the on/off state and the temperature persist through Local, unlike
// Caffeine and DND which deliberately reset each session. A blue-light
// filter is a standing preference -- having it silently switch off
// because the shell reloaded would be a bug, not a feature.

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.compositor

Singleton {
    id: root

    // ---- Public state ----

    readonly property int temperature: {
        const k = Local.get("nightLightTemperature", 4000);
        return Math.max(1000, Math.min(20000, k));
    }

    readonly property bool enabled: Local.get("nightLightEnabled", false)

    // The tile hides entirely unless both halves are present: the binary
    // to talk to, and a backend that knows how to talk to it.
    readonly property bool available: root._binaryPresent && Compositor.supportsNightLight

    function toggle() {
        Local.set("nightLightEnabled", !root.enabled);
    }

    function setEnabled(on) {
        Local.set("nightLightEnabled", !!on);
    }

    function setTemperature(kelvin) {
        Local.set("nightLightTemperature",
                  Math.max(1000, Math.min(20000, Math.round(kelvin))));
    }

    function statusText() {
        if (!root._binaryPresent)
            return "unavailable (hyprsunset not installed)";
        if (!Compositor.supportsNightLight)
            return "unavailable (no night-light dispatch on this compositor)";
        return root.enabled ? ("on, " + root.temperature + "K") : "off";
    }

    // ---- Daemon lifecycle ----

    property bool _binaryPresent: false
    property bool _wantDaemon: false
    property bool _booted: false

    // True when a hyprsunset we did not start is already running, so the
    // death-watch stays out of the way. Someone enabling the shipped
    // hyprsunset.service should not end up with two daemons fighting over
    // the same gamma control.
    property bool _adopted: false

    Process {
        id: probeBinary
        command: ["sh", "-c", "command -v hyprsunset >/dev/null 2>&1"]
        onExited: code => {
            root._binaryPresent = (code === 0);
            if (!root._binaryPresent) {
                console.log("[NightLightService] hyprsunset not installed; night light disabled");
                return;
            }
            probeRunning.running = true;
        }
    }

    Process {
        id: probeRunning
        command: ["pgrep", "-x", "hyprsunset"]
        onExited: code => {
            // pgrep exits 0 when it matched something.
            root._adopted = (code === 0);
            if (root._adopted) {
                console.log("[NightLightService] adopting running hyprsunset");
            } else {
                root._wantDaemon = true;
                daemon.running = true;
            }
            // Push our persisted state onto whichever daemon we ended up
            // with -- adopted ones carry whatever the last session left.
            root._apply(true);
        }
    }

    Process {
        id: daemon

        // pdeathsig because hyprsunset is a quiet long-running child:
        // it writes nothing after startup, so it never takes a SIGPIPE
        // when the shell dies and would otherwise survive every reload.
        // An orphan holds the gamma control, so the screen would stay
        // warm with nothing left to turn it off.
        command: ["setpriv", "--pdeathsig", "TERM", "--", "hyprsunset"]

        stderr: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line && line.length > 0)
                    console.warn("[NightLightService hyprsunset]", line);
            }
        }

        onRunningChanged: {
            if (running) return;
            // Intent-gated: "the child exited" is also what shell teardown
            // looks like, and respawning during teardown strands a daemon.
            if (root._wantDaemon) {
                console.warn("[NightLightService] hyprsunset exited, restarting...");
                running = true;
            }
        }
    }

    // ---- Applying state ----

    // Last value actually dispatched, so repeated toggles or a slider
    // settling on the value it started from don't spawn hyprctl calls.
    // -1 means "nothing sent yet", distinct from 0 (= identity/off).
    property int _lastSent: -1

    function _apply(force) {
        if (!root._binaryPresent) return;
        const target = root.enabled ? root.temperature : 0;
        if (!force && target === root._lastSent) return;
        root._lastSent = target;
        Compositor.dispatchNightLight(target);
    }

    // Dragging the temperature slider would otherwise fire one hyprctl per
    // pixel. Local already debounces its disk write; this debounces the
    // dispatch.
    Timer {
        id: applyDebounce
        interval: 200
        repeat: false
        onTriggered: root._apply(false)
    }

    onTemperatureChanged: if (root._booted) applyDebounce.restart()

    // Toggling is a deliberate single action, so it applies immediately
    // rather than waiting out the debounce.
    onEnabledChanged: {
        if (!root._booted) return;
        applyDebounce.stop();
        root._apply(false);
    }

    // Forces instantiation from shell.qml. Singletons are lazy, and a lazy
    // night-light service is one that never restores its persisted state.
    function bootstrap() {
        root._booted = true;
        probeBinary.running = true;
    }
}
