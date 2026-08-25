pragma Singleton

// AudioPortService.qml
// Output port switching -- choosing which physical jack on a sound card
// the audio comes out of.
//
// One card shows up as a single PipeWire node. "Built-in Audio Analog
// Stereo" is one sink, but the machine has both speakers on Line Out and
// headphones on the headphone jack, and picking between them means
// changing the card's active *port*. That is a device-level concept.
//
// Quickshell's Pipewire module models nodes, links and link groups only
// -- PwNode exposes id/name/description/isSink/type/properties/audio and
// nothing about devices or routes -- so there is no property to bind to.
// Hence pactl, which pipewire-pulse answers. PwNode.name and pactl's sink
// name are the same string for ALSA sinks, so no id mapping is needed.
//
// pactl is asked for JSON. Its default listing is whitespace-structured
// and would need a fragile hand-written parser for something this
// peripheral.
//
// Refreshed on demand, never polled: the data only matters while the
// volume popup is open, and a poller would keep respawning a process for
// a value that changes when you plug a cable in.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // [{ name, description, activePort, ports: [{ name, description, available }] }]
    property var sinks: []

    // pactl present. Everything degrades to "no port UI" when it is not.
    property bool available: false

    property bool refreshing: false
    property string lastError: ""

    function _sinkEntry(sinkName) {
        const list = root.sinks;
        for (let i = 0; i < list.length; i++)
            if (list[i].name === sinkName) return list[i];
        return null;
    }

    // Ports for a sink, or [] when unknown. Callers treat "fewer than two"
    // as "nothing to choose", so an empty list is a safe default.
    function portsFor(sinkName) {
        const e = root._sinkEntry(sinkName);
        return e ? e.ports : [];
    }

    function activePortFor(sinkName) {
        const e = root._sinkEntry(sinkName);
        return e ? e.activePort : "";
    }

    // Only worth showing a picker when there is an actual choice. A card
    // with one jack (HDMI) would otherwise render a single dead pill.
    function hasChoice(sinkName) {
        return root.available && root.portsFor(sinkName).length > 1;
    }

    function refresh() {
        if (!root.available) return;
        if (lister.running) return;    // single-flight
        root.refreshing = true;
        lister.running = true;
    }

    function setPort(sinkName, portName) {
        if (!root.available || !sinkName || !portName) return;
        if (root.activePortFor(sinkName) === portName) return;
        setter.command = ["pactl", "set-sink-port", sinkName, portName];
        // Re-fire even if a previous call is still in flight.
        setter.running = false;
        setter.running = true;
    }

    Process {
        id: probe
        running: true
        command: ["sh", "-c", "command -v pactl >/dev/null 2>&1"]
        onExited: code => {
            root.available = (code === 0);
            if (!root.available) {
                console.log("[AudioPortService] pactl not found; "
                    + "output port switching unavailable");
                return;
            }
            root.refresh();
        }
    }

    Process {
        id: lister
        command: ["pactl", "-f", "json", "list", "sinks"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const out = [];
                    for (let i = 0; i < data.length; i++) {
                        const s = data[i];
                        const ports = [];
                        const raw = s.ports || [];
                        for (let j = 0; j < raw.length; j++) {
                            ports.push({
                                name: raw[j].name || "",
                                description: raw[j].description || raw[j].name || "",
                                // pactl reports "available" / "not available" /
                                // "unknown". Only a definite "not available"
                                // means the jack has nothing plugged into it;
                                // "unknown" is the common case on cards with no
                                // jack detection and must stay selectable.
                                available: raw[j].availability !== "not available"
                            });
                        }
                        out.push({
                            name: s.name || "",
                            description: s.description || s.name || "",
                            activePort: s.active_port || "",
                            ports: ports
                        });
                    }
                    root.sinks = out;
                    root.lastError = "";
                } catch (e) {
                    console.warn("[AudioPortService] parse error:", e);
                    root.lastError = "Bad pactl output";
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.length > 0)
                    console.warn("[AudioPortService] list:", this.text.trim());
            }
        }

        onRunningChanged: if (!running) root.refreshing = false
    }

    Process {
        id: setter

        // pactl exits 1 and prints "Failure: ..." on a bad sink or port,
        // so stderr is the only place a problem shows up.
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.length > 0) {
                    const msg = this.text.trim();
                    console.warn("[AudioPortService] set-sink-port:", msg);
                    root.lastError = msg;
                }
            }
        }

        onExited: code => {
            if (code === 0) root.lastError = "";
            // Re-read either way: on success to pick up the new active port,
            // on failure because the card may have changed under us and the
            // cached list is what led us to send a bad port in the first place.
            root.refresh();
        }
    }
}
