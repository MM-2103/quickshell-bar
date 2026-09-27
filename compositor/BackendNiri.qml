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

    function dispatchDpms(on) {
        Quickshell.execDetached([
            "niri", "msg", "action",
            on ? "power-on-monitors" : "power-off-monitors"
        ]);
    }

    // ---- Output health probe ----
    //
    // Optional backend function, see Compositor.supportsOutputProbe. Calls
    // callback(true) if niri has failed a page flip since sinceSec (Unix
    // seconds). When a resume leaves the DP links wedged, every flip fails
    // with EINVAL and niri logs "Page flip commit failed" about twice a
    // second, so a match in a window of a few seconds means the outputs are
    // stuck. On a good resume it logs none.
    //
    // niri has no IPC for output health, so this searches its log in the
    // user journal. If niri does not log there (not run as a systemd unit),
    // the search finds nothing and the answer is false. The shell then never
    // blanks the screens on a guess.
    //
    // Requests queue, because the one Process can only run one search.
    property var _probeQueue: []
    property bool _probeExited: false

    function probeOutputsFailing(sinceSec, callback) {
        root._probeQueue = root._probeQueue.concat([{ since: Math.floor(sinceSec), cb: callback }]);
        if (!outputProbe.running) root._startNextProbe();
    }

    function _startNextProbe() {
        if (root._probeQueue.length === 0) return;
        root._probeExited = false;
        outputProbe.command = [
            "journalctl", "--user", "-t", "niri",
            "--since", "@" + root._probeQueue[0].since,
            "-g", "Page flip commit failed",
            "-q", "-n", "1", "-o", "cat"
        ];
        outputProbe.running = true;
    }

    property Process _outputProbe: Process {
        id: outputProbe
        stdout: StdioCollector { id: outputProbeOut }
        // exited only fires for a process that ran. A failed start goes
        // straight to running=false, and the collector then still holds
        // the previous search's text, which must not count as a match.
        onExited: root._probeExited = true
        onRunningChanged: {
            if (running) return;
            const failing = root._probeExited && outputProbeOut.text.trim().length > 0;
            const req = root._probeQueue[0];
            root._probeQueue = root._probeQueue.slice(1);
            // Start the next search first, so a throwing callback cannot
            // strand the rest of the queue.
            root._startNextProbe();
            if (req) req.cb(failing);
        }
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
        // setpriv --pdeathsig TERM: Quickshell does not reap child processes
        // when the shell exits — they reparent to init and keep running. This
        // one only writes on compositor events, so on a quiet system there is
        // nothing to SIGPIPE it when the reader goes away, and it survives
        // indefinitely. That leaks one `niri msg` per shell restart, which
        // during active QML editing is a restart every few minutes.
        //
        // See docs/STYLE.md "Long-running processes" for when this is needed
        // — the OSD sysfs poller deliberately does not use it.
        command: ["setpriv", "--pdeathsig", "TERM", "--",
                  "niri", "msg", "--json", "event-stream"]
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
