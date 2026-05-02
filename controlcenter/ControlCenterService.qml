pragma Singleton

// ControlCenterService.qml
// State for the unified control-center popup. Replaces five separate bar
// widgets (IdleInhibit, PowerProfile, Network, Bluetooth, Wallpaper) by
// hosting their interactions inside a single tiled drawer.
//
// View-stack model: the CC has one default "tiles" view plus a small set
// of detail views (`network`, `bluetooth`, `powerprofile`) that take over
// the popup's content area when the user clicks a tile's chevron. The
// Wallpaper tile is special — it doesn't have an in-CC detail view and
// instead opens the existing standalone WallpaperPickerPopup (centered,
// 720 wide; doesn't compress sensibly to the CC's 340).
//
// Open/close state lives on the popup itself (per-monitor), not here —
// so multi-monitor users only see the CC on the bar they clicked. Same
// pattern as BrightnessPopup / NetworkPopup / BluetoothPopup.
//
// Public surface consumed by:
//   - ControlCenterPopup.qml  — reads currentView; navigates via setView/goBack
//   - TilesView.qml           — wires tile clicks
//   - Idle-inhibit state      — owned here (no bar widget left to own it)

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    // ---- View stack ----
    //
    // "tiles"        — default 3×2 grid
    // "network"      — embedded NetworkView (extract of old NetworkPopup)
    // "bluetooth"    — embedded BluetoothView
    // "powerprofile" — embedded PowerProfileView
    property string currentView: "tiles"

    function setView(name) {
        if (!name) name = "tiles";
        root.currentView = name;
    }
    function goBack() { root.currentView = "tiles"; }

    // Reset to tiles view. Called by the popup on close so the next open
    // starts predictably at the grid rather than wherever the user last
    // navigated to.
    function resetView() { root.currentView = "tiles"; }

    // ---- Idle-inhibit state ----
    //
    // Used to live in the deleted IdleInhibit bar widget. Ownership
    // moved here so the Caffeine tile can read and toggle it; the
    // long-running systemd-inhibit Process is below.

    property bool idleInhibitActive: false

    function toggleIdleInhibit() {
        root.idleInhibitActive = !root.idleInhibitActive;
    }

    // Identical command to the old IdleInhibit.qml — covers logind sleep
    // and lid-close handling. Does NOT suppress compositor DPMS / blanking
    // (that's idle-inhibit-v1, which Quickshell doesn't expose).
    Process {
        running: root.idleInhibitActive
        command: [
            "systemd-inhibit",
            "--what=idle:sleep:handle-lid-switch",
            "--who=quickshell-bar",
            "--why=user requested always-on",
            "--mode=block",
            "sleep", "infinity"
        ]
    }
}
