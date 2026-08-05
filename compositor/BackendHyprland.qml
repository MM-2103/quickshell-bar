// BackendHyprland.qml
// Hyprland compositor adapter. Wraps `Quickshell.Hyprland` and re-shapes
// the data into the common backend interface.
//
// HyprlandWorkspace fields → common shape mapping:
//   id        → id   (negative for named workspaces; we surface name in that case)
//   id (>0) / name → idx    (dispatch + sort key — always the global id)
//   name / id      → label  (what the chip renders)
//   active    → is_active
//   focused   → is_focused   (active AND on the focused monitor)
//   monitor.name → output
//   name      → name (when distinct from idx)
//
// idx and label differ deliberately. The Hyprland config gives each monitor its
// own block of workspace ids (DP-1 owns 1-9, DP-2 owns 11-19) so that every
// output has an independent set, the way niri and AwesomeWM behave. The chip
// must still *dispatch* the global id — otherwise clicking "3" on the second
// monitor would jump to the first — but it should *read* 1-9 on every monitor.
//
// The label is derived arithmetically from the id, which means wsStride below
// duplicates a constant that really lives in the compositor config. That is
// deliberate: the obvious alternative — having the config name each workspace
// after its slot via `default_name`, so the bar could just render the name —
// is broken. Workspace names are a global namespace in Hyprland, so naming both
// DP-1's workspace 1 and DP-2's workspace 11 "1" makes the name-based IPC events
// ambiguous:
//
//   focusedmon>>DP-2,1       <- which "1"?
//   focusedmonv2>>DP-2,11    <- v2 events carry the id and stay unambiguous
//
// Quickshell resolves some of those by name, so duplicate names made it
// re-parent DP-1's workspace onto DP-2: the Dell rendered two "1" chips and the
// LG rendered none until refocused. Arithmetic here is the lesser evil.

import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: root

    // Size of each monitor's block of workspace ids. MUST match M.stride in
    // the Hyprland config: ~/system-config/dotfiles/hypr/lua/workspaces.lua
    readonly property int wsStride: 10

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
                // Slot within the owning monitor's block: 1 -> 1, 11 -> 1,
                // 13 -> 3. Named workspaces keep showing their name.
                label: isNamed ? w.name : ((w.id - 1) % root.wsStride) + 1,
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

    // Hyprland 0.56's Lua config parser evaluates the dispatch payload as Lua:
    // it runs `return hl.dispatch(<payload>)`. The old space-separated form is
    // a syntax error there —
    //
    //   dispatch workspace 11    -> error: ')' expected near '11'
    //   dispatch hl.dsp.no_op()  -> ok
    //
    // and Quickshell's dispatch() discards the reply, so a wrong payload fails
    // silently. These therefore only work on a Lua-config Hyprland; hyprlang is
    // deprecated upstream and deliberately unsupported here.

    function dispatchFocusWorkspace(idx) {
        // Numeric ids go through bare. Named and special workspaces arrive as
        // strings and have to become Lua string literals — stringify rather
        // than concatenate, so a name can't inject into the evaluated Lua.
        const sel = (typeof idx === "number")
            ? String(idx)
            : JSON.stringify(String(idx));
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + sel + " })");
    }

    function dispatchLogout() {
        // Terminates the compositor. On session managers that own the
        // lifecycle (uwsm and friends) this skips their ordered shutdown —
        // set `logoutCommand` in config.jsonc to override the button.
        Hyprland.dispatch("hl.dsp.exit()");
    }
}
