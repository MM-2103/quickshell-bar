pragma Singleton

// ClipboardService.qml
// Wraps cliphist for the clipboard manager popup.
//
// Storage half (`wl-paste --watch cliphist store`) keeps running externally
// in niri's autostart. We only own the picker UI: list/decode/delete.
//
// Public surface used by ClipboardPopup + shell.qml IpcHandler:
//   entries: array<{ id, preview, isImage, ext, dimensions }>
//   popupOpen: bool                 (drives the popup's visible binding)
//   openPopup() / closePopup() / togglePopup()
//   refresh()                       (cliphist list)
//   paste(id)                       (cliphist decode <id> | wl-copy, then close)
//   remove(id, preview)             (delete entry by id+preview line)

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property var entries: []
    property bool popupOpen: false
    property bool loading: false

    // Where decoded image thumbnails live (cleared on reboot via systemd-tmpfiles).
    readonly property string thumbDir: "/tmp/quickshell-clipboard-thumbs"

    // ---- Popup control ----
    //
    // openPopup/closePopup are also responsible for talking to the
    // PopupController so opening the clipboard via Mod+V dismisses any
    // bar popup that happens to be open, and vice versa.

    function openPopup() {
        PopupController.open(root, () => root.popupOpen = false);
        root.popupOpen = true;
        refresh();
    }

    function closePopup() {
        root.popupOpen = false;
        PopupController.closed(root);
    }

    function togglePopup() {
        if (root.popupOpen) closePopup();
        else                openPopup();
    }

    // ---- Refresh ----

    function refresh() {
        root.loading = true;
        listProc.running = true;
    }

    Process {
        id: listProc
        running: false
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    if (!line) continue;
                    const tabIdx = line.indexOf("\t");
                    if (tabIdx < 0) continue;
                    const id = line.substring(0, tabIdx);
                    const preview = line.substring(tabIdx + 1);

                    // cliphist's image preview: "[[ binary data <n> <unit> <fmt> <WxH> ]]"
                    const m = preview.match(
                        /^\[\[\s+binary\s+data\s+\d+\s+\w+\s+(\w+)\s+(\d+x\d+)\s+\]\]\s*$/);
                    if (m) {
                        out.push({
                            id, preview,
                            isImage: true,
                            ext: m[1],
                            dimensions: m[2]
                        });
                    } else {
                        out.push({
                            id, preview,
                            isImage: false,
                            ext: "", dimensions: ""
                        });
                    }
                }
                root.entries = out;
                root.loading = false;
            }
        }
        onRunningChanged: {
            if (!running) {
                // Make sure loading flag clears even on early exit/error.
                root.loading = false;
            }
        }
    }

    // ---- Actions ----

    // Quote a string for safe inclusion in a single-quoted bash arg.
    function _q(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function paste(id) {
        // sh chain instead of pipeline as Process command (which doesn't run in
        // a shell on its own). We close the popup right away — wl-copy completes
        // async in milliseconds.
        pasteProc.command = [
            "sh", "-c",
            "cliphist decode " + _q(id) + " | wl-copy"
        ];
        pasteProc.running = true;
        closePopup();
    }

    Process {
        id: pasteProc
        running: false
    }

    function remove(id, preview) {
        // cliphist delete reads "id\tpreview\n" lines from stdin. We feed
        // exactly one such line via printf.
        removeProc.command = [
            "sh", "-c",
            "printf '%s\\t%s' " + _q(id) + " " + _q(preview) + " | cliphist delete"
        ];
        removeProc.running = true;
    }

    Process {
        id: removeProc
        running: false
        onRunningChanged: {
            if (!running) refresh();    // re-fetch list after a delete
        }
    }
}
