pragma Singleton

// BarService.qml
// Auto-hide state shared by every Bar instance (one per monitor).
//
// With barAutoHide on, each bar hides its panel and keeps only a 2 px
// strip along the top edge that takes input. Resting the pointer on that
// strip for revealDelay ms slides the bar in; leaving it for hideDelay ms
// slides it out. Bar.qml owns the per-monitor reveal logic. This file
// only holds the settings and the pin.
//
// Settings, all routed through Local so the Settings page and
// config.jsonc can change them:
//
//   barAutoHide                bool  false  hide the bar until hovered
//   barRevealDelay             int   150    ms at the edge before revealing
//   barHideDelay               int   400    ms after leaving before hiding
//   barPeekOnWorkspaceSwitch   bool  true   reveal briefly on a switch
//
// pinned is the keybind state: qs ipc call bar toggle. A pinned bar stays
// revealed and reserves space like a bar without auto-hide. Not saved,
// so every shell start is unpinned.
//
// IMPORTANT: pragma Singleton must be line 1 (gotcha #45). Header comments
// must NOT contain curly braces.

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool autoHide: Local.get("barAutoHide", false)
    readonly property int revealDelay: Math.max(0, Local.get("barRevealDelay", 150))
    readonly property int hideDelay: Math.max(0, Local.get("barHideDelay", 400))
    readonly property bool peekOnWorkspaceSwitch: Local.get("barPeekOnWorkspaceSwitch", true)

    property bool pinned: false

    function togglePinned() {
        root.pinned = !root.pinned;
    }

    function statusText() {
        if (!root.autoHide) return "auto-hide off";
        return "auto-hide on"
            + " | " + (root.pinned ? "pinned" : "not pinned")
            + " | reveal " + root.revealDelay + "ms"
            + " | hide " + root.hideDelay + "ms"
            + " | workspace peek " + (root.peekOnWorkspaceSwitch ? "on" : "off");
    }
}
