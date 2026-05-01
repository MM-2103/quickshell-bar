// BackendSway.qml
// Sway / i3 compositor adapter. Wraps `Quickshell.I3` and re-shapes the
// data into the common backend interface.
//
// I3Workspace fields → common shape mapping:
//   num        → idx  (sway/i3 numeric workspace label)
//   name       → name (full name; may be like "1: code" or just "1")
//   focused    → is_focused
//   visible    → is_active   (visible on its monitor)
//   output     → output      (monitor name)
//
// Caveats vs niri/Hyprland:
//   - i3/Sway exposes NO keyboard-layout-changed IPC event, so the layout
//     OSD never fires on this backend (currentLayout stays "").
//   - The `windowFocused` signal is derived from `rawEvent` filtering on
//     the `change === "focus"` event of the `window` event class.

import QtQuick
import Quickshell
import Quickshell.I3

QtObject {
    id: root

    // Reactive readback of I3.workspaces, mapped to the common shape.
    readonly property var workspaces: {
        const out = [];
        const list = I3.workspaces ? I3.workspaces.values : [];
        for (let i = 0; i < list.length; i++) {
            const w = list[i];
            if (!w) continue;
            // I3Workspace has `num` (numeric label), `name` (full label),
            // `focused`, `visible`, and `monitor`.
            const num = (w.num !== undefined && w.num >= 0) ? w.num : null;
            out.push({
                id: w.id !== undefined ? w.id : i,
                idx: num !== null ? num : w.name,
                output: w.monitor ? w.monitor.name : "",
                is_focused: w.focused || false,
                is_active:  w.visible || false,
                name: w.name || ""
            });
        }
        return out;
    }

    readonly property string focusedOutput:
        I3.focusedMonitor ? I3.focusedMonitor.name : ""

    // No layout-changed event in i3/Sway IPC — leave empty.
    readonly property string currentLayout: ""

    signal windowFocused(var id)

    // Filter rawEvent for `window` class with `change === "focus"`. The
    // event payload contains `container.id` for the focused window. We
    // emit that id (matches niri's int-typed window id semantics).
    property Connections _eventsConn: Connections {
        target: I3
        function onRawEvent(event) {
            if (!event) return;
            // I3Event has `type` (string like "window", "workspace") and
            // a `data` JSON-parseable payload.
            if (event.type !== "window") return;
            const payload = event.data ? JSON.parse(event.data) : null;
            if (!payload || payload.change !== "focus") return;
            const winId = payload.container ? payload.container.id : null;
            if (winId !== null && winId !== undefined)
                root.windowFocused(winId);
        }
    }

    function dispatchFocusWorkspace(idx) {
        // For numeric workspaces use `workspace number N`; for named ones
        // (idx is a string) use `workspace <name>`.
        if (typeof idx === "number") {
            I3.dispatch("workspace number " + idx);
        } else {
            I3.dispatch("workspace " + idx);
        }
    }

    function dispatchLogout() {
        // `exit` ends the Sway / i3 session.
        I3.dispatch("exit");
    }
}
