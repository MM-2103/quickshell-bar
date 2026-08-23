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
import qs.system

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

    // ---- Idle-inhibit state (Caffeine) ----
    //
    // Used to live in the deleted IdleInhibit bar widget. Ownership
    // moved here so the Caffeine tile can read and toggle it.
    //
    // Two halves, because the two concerns have different owners:
    //
    //   1. Shell-side idle  — IdleService owns lock + DPMS now that
    //      Quickshell exposes ext-idle-notifier-v1. Suppressing it is just
    //      `enabled = false`; there is no other idle consumer left to
    //      inhibit, so no Wayland inhibitor of our own is required.
    //
    //   2. logind-side idle — suspend timers and lid-close are answered by
    //      systemd, not by us, so the inhibitor below still has a job. Note
    //      `idle:` has been dropped from --what: logind's idle notion drove
    //      nothing here once hypridle went away, and claiming it made the
    //      inhibitor look responsible for screen blanking when it never was.

    property bool idleInhibitActive: false

    function toggleIdleInhibit() {
        root.idleInhibitActive = !root.idleInhibitActive;
    }

    // Caffeine on -> shell idle handling off. One-way binding on purpose:
    // IdleService.enabled is also settable over IPC, and we don't want a
    // scripted `qs ipc call idle enable` to silently un-press the tile.
    onIdleInhibitActiveChanged: IdleService.setEnabled(!root.idleInhibitActive)

    Process {
        running: root.idleInhibitActive
        command: [
            "systemd-inhibit",
            "--what=sleep:handle-lid-switch",
            "--who=quickshell-bar",
            "--why=user requested always-on",
            "--mode=block",
            "sleep", "infinity"
        ]
    }
}
