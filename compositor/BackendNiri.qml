// BackendNiri.qml
// Niri compositor adapter. Streams workspace state from
// `niri msg --json event-stream`, parses the line-delimited JSON, and
// exposes the standard Compositor backend interface.
//
// Workspace shape (matches niri's payload, with nothing renamed):
//   { id, idx, output, is_focused, is_active, name? }

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var workspaces: []
    property string focusedOutput: ""
    property string currentLayout: ""

    signal windowFocused(var id)

    function dispatchFocusWorkspace(idx) {
        Quickshell.execDetached(
            ["niri", "msg", "action", "focus-workspace", String(idx)]
        );
    }

    function dispatchLogout() {
        Quickshell.execDetached(["niri", "msg", "action", "quit"]);
    }

    function _handleEvent(event) {
        if (event.WorkspacesChanged) {
            const list = event.WorkspacesChanged.workspaces;
            root.workspaces = list;
            const focused = list.find(w => w.is_focused);
            if (focused) root.focusedOutput = focused.output;
        } else if (event.WorkspaceActivated) {
            const id = event.WorkspaceActivated.id;
            const focused = event.WorkspaceActivated.focused;
            const ws = root.workspaces.find(w => w.id === id);
            if (!ws) return;
            const output = ws.output;
            // Update is_active per-output and is_focused globally.
            root.workspaces = root.workspaces.map(w => Object.assign({}, w, {
                is_active: w.output === output ? (w.id === id) : w.is_active,
                is_focused: focused ? (w.id === id) : w.is_focused
            }));
            if (focused) root.focusedOutput = output;
        } else if (event.KeyboardLayoutsChanged) {
            const k = event.KeyboardLayoutsChanged.keyboard_layouts;
            if (k && Array.isArray(k.names)
                && k.current_idx >= 0 && k.current_idx < k.names.length) {
                root.currentLayout = k.names[k.current_idx];
            }
        } else if (event.WindowFocusChanged) {
            // niri emits this with id=int (a toplevel focused) OR id=null
            // (no toplevel focused). The id=null case fires both for
            // legitimate "empty workspace" switches AND — crucially —
            // when one of OUR layer-shell surfaces takes keyboard focus
            // (e.g. ClipboardPopup is layer-shell with OnDemand focus).
            // We ignore null here so opening clipboard doesn't immediately
            // self-dismiss via the focus listener in shell.qml. Real
            // toplevel focus changes (alt-tab, click new app) still fire.
            const id = event.WindowFocusChanged.id;
            if (id !== null && id !== undefined) root.windowFocused(id);
        }
        // Other events (WindowsChanged, WindowFocusTimestampChanged, etc.)
        // are ignored.
    }

    property Process _events: Process {
        id: niriEvents
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (!line || line.length === 0) return;
                try {
                    root._handleEvent(JSON.parse(line));
                } catch (e) {
                    console.warn("[BackendNiri] parse error:", e, "line:", line);
                }
            }
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: line => console.warn("[BackendNiri stderr]", line)
        }
        // Auto-restart if the event-stream process exits (e.g. niri restart).
        onRunningChanged: {
            if (!running) {
                console.warn("[BackendNiri] event-stream exited, restarting...");
                running = true;
            }
        }
    }
}
