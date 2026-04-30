// OsdService.qml
// On-screen display service. Watches:
//   - Volume / mute (via Pipewire)
//   - Caps Lock / Num Lock LEDs (sysfs polling at 10 Hz)
//   - Brightness (sysfs polling at 10 Hz, no-op on machines without backlight)
//   - Keyboard layout (set externally from shell.qml; see show("layout"))
//
// On any change AFTER an initialization grace period, sets `currentKind`
// and starts a 1500ms dismiss timer. The Osd window watches `currentKind`
// to decide what to render and when to fade in/out.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    // ---- Public state read by the Osd window ----
    property string currentKind: ""    // "" | "volume" | "caps" | "num" | "brightness" | "layout"

    // Volume — live values for the bar/text.
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volumeRatio: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted:       sink && sink.audio ? sink.audio.muted  : false

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    // Locks
    property bool capsOn: false
    property bool numOn: false

    // Brightness (raw + ratio + has-it flag)
    property real brightnessRatio: 0
    property bool hasBrightness: false

    // Layout — written from shell.qml when it sees Niri.currentLayout change.
    property string layoutName: ""

    // ---- Show / dismiss ----
    property bool initialized: false

    function show(kind) {
        if (!initialized) return;
        root.currentKind = kind;
        dismissTimer.restart();
    }

    Timer {
        id: dismissTimer
        interval: 1500
        repeat: false
        onTriggered: root.currentKind = ""
    }

    // 1s startup grace period: every "first reading" of caps/num/volume etc.
    // arrives during this window and is absorbed silently as the baseline.
    Timer {
        interval: 1000
        running: true
        repeat: false
        onTriggered: root.initialized = true
    }

    // ---- Reset volume baseline when default sink changes (so switching the
    //       default device doesn't trigger a phantom OSD comparing two
    //       different sinks' values).
    onSinkChanged: root._volBaselineSet = false

    // ---- Volume change detection ----
    property real _lastVol: -1
    property bool _lastMuted: false
    property bool _volBaselineSet: false

    Connections {
        target: root.sink && root.sink.audio ? root.sink.audio : null
        enabled: target !== null
        function onVolumeChanged() {
            const v = root.sink.audio.volume;
            if (!root._volBaselineSet) {
                root._lastVol = v;
                root._lastMuted = root.sink.audio.muted;
                root._volBaselineSet = true;
                return;
            }
            if (Math.abs(v - root._lastVol) > 0.001) {
                root._lastVol = v;
                root.show("volume");
            }
        }
        function onMutedChanged() {
            const m = root.sink.audio.muted;
            if (!root._volBaselineSet) return; // baseline not yet set, ignore
            if (m !== root._lastMuted) {
                root._lastMuted = m;
                root.show("volume");
            }
        }
    }

    // ---- Sysfs poller for caps/num/brightness ----
    //
    // Single long-running bash subprocess polls every 100ms and emits
    // "caps numlock brightness max_brightness" lines. Cheap and reliable
    // (sysfs doesn't fire inotify events for value changes, so polling
    // is the standard approach here). The 2>/dev/null + ${VAR:-0} fallbacks
    // make this a no-op on systems missing any of the files.
    property bool _capsBaselineSet: false
    property int _lastCaps: 0
    property bool _numBaselineSet: false
    property int _lastNum: 0
    property int _lastBrightnessRaw: -1

    Process {
        id: poller
        running: true
        command: ["sh", "-c", `
while true; do
  C=$(cat /sys/class/leds/input*::capslock/brightness 2>/dev/null | grep -q 1 && echo 1 || echo 0)
  N=$(cat /sys/class/leds/input*::numlock/brightness 2>/dev/null | grep -q 1 && echo 1 || echo 0)
  B=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -1)
  M=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -1)
  echo "$C $N \${B:-0} \${M:-0}"
  sleep 0.1
done
`]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (!line) return;
                const parts = line.trim().split(/\s+/);
                if (parts.length < 4) return;
                const c = parseInt(parts[0]) || 0;
                const n = parseInt(parts[1]) || 0;
                const b = parseInt(parts[2]) || 0;
                const m = parseInt(parts[3]) || 0;

                // Caps Lock
                if (!root._capsBaselineSet) {
                    root._capsBaselineSet = true;
                    root._lastCaps = c;
                    root.capsOn = c === 1;
                } else if (c !== root._lastCaps) {
                    root._lastCaps = c;
                    root.capsOn = c === 1;
                    root.show("caps");
                }

                // Num Lock
                if (!root._numBaselineSet) {
                    root._numBaselineSet = true;
                    root._lastNum = n;
                    root.numOn = n === 1;
                } else if (n !== root._lastNum) {
                    root._lastNum = n;
                    root.numOn = n === 1;
                    root.show("num");
                }

                // Brightness — only if the device exists (m > 0).
                if (m > 0) {
                    root.hasBrightness = true;
                    root.brightnessRatio = b / m;
                    if (root._lastBrightnessRaw < 0) {
                        root._lastBrightnessRaw = b;
                    } else if (b !== root._lastBrightnessRaw) {
                        root._lastBrightnessRaw = b;
                        root.show("brightness");
                    }
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                console.warn("[OsdService] poller exited, restarting");
                running = true;
            }
        }
    }
}
