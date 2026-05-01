// BackendHyprland.qml
// Hyprland compositor adapter. Wraps `Quickshell.Hyprland` and re-shapes
// the data into the common backend interface.
//
// HyprlandWorkspace fields → common shape mapping:
//   id        → id   (negative for named workspaces; we surface name in that case)
//   id (>0) / name → idx  (the label rendered on the chip)
//   active    → is_active
//   focused   → is_focused   (active AND on the focused monitor)
//   monitor.name → output
//   name      → name (when distinct from idx)

import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: root

    // Reactive readback of Hyprland.workspaces, mapped to the common shape.
    // ObjectModel's `values` property gives us a JS array.
    readonly property var workspaces: {
        const out = [];
        const list = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (let i = 0; i < list.length; i++) {
            const w = list[i];
            if (!w) continue;
            // Named workspaces in Hyprland have negative ids; show the
            // name in the chip label instead of the id.
            const isNamed = w.id < 0 && w.name && w.name.length > 0;
            out.push({
                id: w.id,
                idx: isNamed ? w.name : w.id,
                output: w.monitor ? w.monitor.name : "",
                is_focused: w.focused || false,
                is_active:  w.active  || false,
                name: w.name || ""
            });
        }
        return out;
    }

    readonly property string focusedOutput:
        Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

    // Current keyboard layout — Hyprland emits `activelayout` raw events
    // with a `keyboard,layout` payload. We only care about the layout half.
    property string currentLayout: ""

    signal windowFocused(var id)

    // ---- Wiring ----

    // Active toplevel change → emit windowFocused. Hyprland's
    // activeToplevel goes null on empty workspaces; we filter that out
    // (matches the BackendNiri filter behavior so popup auto-dismiss
    // semantics are consistent across compositors).
    property Connections _toplevelConn: Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            const t = Hyprland.activeToplevel;
            if (t && t.address) root.windowFocused(t.address);
        }
    }

    // Subscribe to socket2 events for keyboard-layout updates. We can't
    // pull this synchronously from the Hyprland singleton — it's only
    // surfaced via raw events.
    property Connections _eventsConn: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!event) return;
            if (event.name === "activelayout") {
                // Payload format: "<keyboard-name>,<layout-name>"
                const data = event.data || "";
                const idx = data.lastIndexOf(",");
                if (idx >= 0 && idx < data.length - 1) {
                    root.currentLayout = data.substring(idx + 1);
                }
            }
        }
    }

    function dispatchFocusWorkspace(idx) {
        // For named workspaces (negative id, idx is the string name),
        // dispatch by name; otherwise dispatch by index.
        Hyprland.dispatch("workspace " + idx);
    }

    function dispatchLogout() {
        // `exit` cleanly terminates the Hyprland session.
        Hyprland.dispatch("exit");
    }
}
