// TilesView.qml
// Default tiles view: SlidersBlock + 3 × 2 tile grid + NowPlayingCard.
// The tile *order* is fixed to keep muscle memory stable across versions:
//
//   Row 1:  Wi-Fi    · Bluetooth   · Power Profile
//   Row 2:  Caffeine · DND         · Wallpaper
//
// Each tile's body click does its "primary action"; tiles that have a
// detail view show a chevron whose click navigates the CC into that view.
// The Wallpaper tile is the odd one out — its picker is too wide to fit
// the CC, so it opens the existing centered WallpaperPickerPopup.
// Clicking any tile that triggers a separate popup will also auto-close
// the CC via PopupController's mutex.
//
// Sliders + NowPlaying are placed only here (not in detail views) — when
// the user drills into a Wi-Fi / BT / Profile detail view, the Loader
// swaps to that view and they get the full body height for scrolling.

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs
import qs.controlcenter
import qs.lock
import qs.notifications
import qs.network
import qs.wallpaper

Item {
    id: root

    // Computed at instantiation; tile width is derived from the parent
    // container's width minus inter-tile spacing. The popup card is 340 px
    // wide with 14 px outer + 14 px inner margins, so the usable inner
    // grid area is 312. 3 columns × 8 px gap × 2 = 296 / 3 ≈ 98 per tile.
    readonly property int _tileSpacing: 8
    readonly property int _tileWidth:
        Math.floor((width - _tileSpacing * 2) / 3)
    readonly property int _tileHeight: 64

    // ---- Bluetooth helpers (mirrors Bluetooth.qml's old logic) ----
    readonly property var _btAdapter: Bluetooth.defaultAdapter
    readonly property bool _btEnabled: _btAdapter ? _btAdapter.enabled : false
    readonly property int _btConnectedCount: {
        const list = Bluetooth.devices.values;
        let n = 0;
        for (let i = 0; i < list.length; i++) if (list[i].connected) n++;
        return n;
    }

    // ---- PowerProfile helpers (mirrors PowerProfile.qml) ----
    function _profileGlyph() {
        const p = PowerProfiles.profile;
        if (p === PowerProfile.Performance) return "\uf0e7"; // bolt
        if (p === PowerProfile.Balanced)    return "\uf624"; // gauge
        return "\uf06c";                                      // leaf
    }
    function _profileName() {
        const p = PowerProfiles.profile;
        if (p === PowerProfile.Performance) return "Performance";
        if (p === PowerProfile.Balanced)    return "Balanced";
        return "Power Saver";
    }
    function _cycleProfile() {
        const list = [PowerProfile.PowerSaver, PowerProfile.Balanced];
        if (PowerProfiles.hasPerformanceProfile) list.push(PowerProfile.Performance);
        const cur = PowerProfiles.profile;
        const idx = list.indexOf(cur);
        const next = list[(idx + 1) % list.length];
        PowerProfiles.profile = next;
    }

    // ---- Network helpers ----
    function _wifiState() {
        if (!NetworkService.wifiEnabled) return "Off";
        if (NetworkService.wifiConnected) return NetworkService.currentSsid;
        return "Disconnected";
    }
    function _wifiIcon() {
        // Re-use bar widget's logic so the tile glyph changes with state.
        if (NetworkService.wiredConnected)  return "\uf796"; // ethernet
        if (NetworkService.wifiConnected)   return "\uf1eb"; // wifi
        if (!NetworkService.wifiEnabled)    return "\uf127"; // link-slash
        return "\uf1eb";
    }

    // ---- Bluetooth state strings ----
    function _btState() {
        if (!_btAdapter)        return "No adapter";
        if (!_btEnabled)        return "Off";
        if (_btConnectedCount === 0) return "On";
        if (_btConnectedCount === 1) return "1 device";
        return _btConnectedCount + " devices";
    }

    // ================================================================
    // Layout: Column with [SlidersBlock, Grid of tiles, NowPlayingCard]
    // ================================================================
    Column {
        anchors.fill: parent
        spacing: 12

        // ---- Sliders (volume + brightness) ----
        SlidersBlock {
            width: parent.width
        }

        // ---- Tile grid ----
        Grid {
        width: parent.width
        columns: 3
        spacing: root._tileSpacing

        // ---- Wi-Fi ----
        // Body: toggle radio (matches old middle-click on bar widget).
        // Chevron: open NetworkView with the full picker.
        Tile {
            width: root._tileWidth
            height: root._tileHeight
            icon: root._wifiIcon()
            label: "Wi-Fi"
            stateText: root._wifiState()
            active: NetworkService.wifiEnabled
            showChevron: true
            onClicked: NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)
            onChevronClicked: ControlCenterService.setView("network")
        }

        // ---- Bluetooth ----
        // Body: toggle adapter (matches old middle-click on bar widget).
        // Chevron: open BluetoothView.
        Tile {
            width: root._tileWidth
            height: root._tileHeight
            icon: "\uf293"
            brand: true
            label: "Bluetooth"
            stateText: root._btState()
            active: root._btEnabled
            showChevron: true
            onClicked: {
                if (root._btAdapter)
                    root._btAdapter.enabled = !root._btAdapter.enabled;
            }
            onChevronClicked: ControlCenterService.setView("bluetooth")
        }

        // ---- Power Profile ----
        // Body: cycle through profiles (matches old middle-click).
        // Chevron: open the explicit 3-radio detail view.
        Tile {
            width: root._tileWidth
            height: root._tileHeight
            icon: root._profileGlyph()
            // Performance is always considered "active" visually since
            // it's the standout profile (was accent-tinted in the bar
            // widget's original design). Other profiles render as inactive.
            active: PowerProfiles.profile === PowerProfile.Performance
            label: "Profile"
            stateText: root._profileName()
            showChevron: true
            onClicked: root._cycleProfile()
            onChevronClicked: ControlCenterService.setView("powerprofile")
        }

        // ---- Caffeine (Idle Inhibit) ----
        // Body: toggle. No detail view — there's nothing more to configure.
        Tile {
            width: root._tileWidth
            height: root._tileHeight
            icon: ControlCenterService.idleInhibitActive ? "\uf7b6" : "\uf0f4"
            label: "Caffeine"
            stateText: ControlCenterService.idleInhibitActive ? "On" : "Off"
            active: ControlCenterService.idleInhibitActive
            onClicked: ControlCenterService.toggleIdleInhibit()
        }

        // ---- DND ----
        // Body: toggle. No detail view.
        // Right-click on the bar bell still toggles DND too — both surface
        // the same NotificationService.dndEnabled flag.
        Tile {
            width: root._tileWidth
            height: root._tileHeight
            icon: NotificationService.dndEnabled ? "\uf1f6" : "\uf0f3"
            label: "DND"
            stateText: NotificationService.dndEnabled ? "On" : "Off"
            active: NotificationService.dndEnabled
            onClicked: NotificationService.toggleDnd()
        }

        // ---- Wallpaper ----
        // Body: open the existing centered WallpaperPickerPopup. The
        // PopupController mutex auto-closes the CC when it opens.
        // No chevron because there's no in-CC detail view.
        Tile {
            width: root._tileWidth
            height: root._tileHeight
            icon: "\uf03e"
            label: "Wallpaper"
            stateText: "Browse…"
            active: false
            onClicked: WallpaperService.openPicker()
        }
        }   // end Grid

        // ---- Now Playing card ----
        //
        // Reused from the lock screen. Auto-hides when no MPRIS player has
        // a track (its `visible` binding handles that internally), so a
        // collapsed item takes 0 vertical space in this Column and the
        // popup appears more compact when there's nothing to show.
        // Width override fills the CC's inner width (~412 px); the card's
        // hardcoded 360 default would leave awkward asymmetric padding.
        NowPlayingCard {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
        }
    }
}
