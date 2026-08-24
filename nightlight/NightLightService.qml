pragma Singleton

// NightLightService.qml
// Blue-light filter state, backed by hyprsunset.
//
// Split of responsibilities: this service owns the daemon's lifecycle and
// the user-facing state, while the actual "set the temperature" call goes
// through Compositor.dispatchNightLight so no compositor-specific command
// leaks outside compositor/Backend*.qml.
//
// hyprsunset runs only while the filter is on. Nothing is left running
// for a feature that is off, so a shell restart with night light disabled
// costs nothing. Turning it on starts the daemon already warm via -t;
// changing the temperature afterwards goes over hyprctl, so the slider
// never restarts anything and never flashes neutral.
//
// Both the on/off state and the temperature persist through Local, unlike
// Caffeine and DND which deliberately reset each session. A blue-light
// filter is a standing preference -- having it silently switch off
// because the shell reloaded would be a bug, not a feature.
//
// Known: the gamma change lags the toggle slightly. That is not this code.
// Measured end to end, toggle() to hyprctl returning is ~3 ms, and the
// same lag happens running `hyprctl hyprsunset temperature` straight from
// a shell with no Quickshell involved. It sits in hyprsunset writing the
// LUT or the compositor committing it to the CRTC. Don't go looking for
// it in here -- and note that no screenshot can show it either, because
// wlr-gamma-control applies after compositing. See gotcha #77.

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
    //
    // The daemon runs only while the filter is on. Keeping one alive
    // permanently buys nothing -- a stopped hyprsunset and a hyprsunset
    // parked at identity look identical -- and costs a relaunch on every
    // shell restart and hot-reload, which is visible.
    //
    // It is started with -t, so it comes up already warm and there is no
    // flash of neutral between spawn and a first temperature command.
    // Changes while it is running still go over hyprctl, so moving the
    // slider never restarts anything.

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
            if (root._adopted)
                console.log("[NightLightService] adopting running hyprsunset");
            // force: an adopted daemon carries whatever the last session
            // left it set to, which may not match our persisted state.
            root._sync(true);
        }
    }

    Process {
        id: daemon

        // pdeathsig because hyprsunset is a quiet long-running child:
        // it writes nothing after startup, so it never takes a SIGPIPE
        // when the shell dies and would otherwise survive every reload.
        // An orphan holds the gamma control, so the screen would stay
        // warm with nothing left to turn it off.
        //
        // -t is read at startup only. A later temperature change goes over
        // hyprctl instead; this binding just decides what the *next* start
        // comes up as.
        command: ["setpriv", "--pdeathsig", "TERM", "--",
                  "hyprsunset", "-t", String(root.temperature)]

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

    // Last value the daemon is known to be at, so repeated toggles or a
    // slider settling back where it started don't spawn hyprctl calls.
    // -1 means "no daemon / nothing sent yet", distinct from 0 (identity).
    property int _lastSent: -1

    function _dispatch(target, force) {
        if (!force && target === root._lastSent) return;
        root._lastSent = target;
        Compositor.dispatchNightLight(target);
    }

    function _sync(force) {
        if (!root._binaryPresent || !Compositor.supportsNightLight) return;

        // Someone else's daemon (the shipped systemd unit, typically).
        // Steer it, never start or stop it -- its lifecycle isn't ours.
        if (root._adopted) {
            root._dispatch(root.enabled ? root.temperature : 0, force);
            return;
        }

        if (!root.enabled) {
            // Stopping is enough to clear the filter: wlr-gamma-control
            // has the compositor restore the original ramp when the client
            // disconnects, so there's no need to dispatch identity first.
            root._wantDaemon = false;
            daemon.running = false;
            root._lastSent = -1;
            return;
        }

        if (!daemon.running) {
            // -t in the command means it starts at the right temperature,
            // so nothing is dispatched here.
            root._lastSent = root.temperature;
            root._wantDaemon = true;
            daemon.running = true;
            return;
        }

        root._dispatch(root.temperature, force);
    }

    // Dragging the temperature slider would otherwise fire one hyprctl per
    // pixel. Local already debounces its disk write; this debounces the
    // dispatch.
    Timer {
        id: applyDebounce
        interval: 200
        repeat: false
        onTriggered: root._sync(false)
    }

    onTemperatureChanged: if (root._booted) applyDebounce.restart()

    // Toggling is a deliberate single action, so it applies immediately
    // rather than waiting out the debounce.
    onEnabledChanged: {
        if (!root._booted) return;
        applyDebounce.stop();
        root._sync(false);
    }

    // Forces instantiation from shell.qml. Singletons are lazy, and a lazy
    // night-light service is one that never restores its persisted state.
    function bootstrap() {
        root._booted = true;
        probeBinary.running = true;
    }
}
