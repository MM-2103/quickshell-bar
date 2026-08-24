// TilesView.qml
// Default tiles view: SlidersBlock + 3 × 3 tile grid + WeatherCard +
// NowPlayingCard.
// The tile *order* is fixed to keep muscle memory stable across versions:
//
//   Row 1:  Wi-Fi    · Bluetooth   · Power Profile
//   Row 2:  Caffeine · DND         · Wallpaper
//   Row 3:  Theme    · Night light · (empty)
//
// Cell 9 stays empty (the Grid simply doesn't render anything in that
// slot). Future tiles slot into it without disturbing the existing eight.
//
// Night light is conditional: it renders only where hyprsunset is
// installed AND the compositor backend implements a night-light dispatch,
// so on niri/Sway row 3 still ends after Theme.
//
// Each tile's body click does its "primary action"; tiles that have a
// detail view show a chevron whose click navigates the CC into that view.
// The Wallpaper tile is the odd one out — its picker is too wide to fit
// the CC, so it opens the existing centered WallpaperPickerPopup.
// Clicking any tile that triggers a separate popup will also auto-close
// the CC via PopupController's mutex.
//
// The Theme tile is a momentary action — it never enters an "active"
// state. When enabled, click applies the sibling of the current theme
// (Mocha → Latte etc.); when disabled (no current theme, or current
// theme has no sibling), the tile renders dimmed and clicks no-op.
//
// Sliders + Weather + NowPlaying are placed only here (not in detail
// views) — when the user drills into a Wi-Fi / BT / Profile / Cities
// detail view, the Loader swaps to that view and it gets the full body
// height for scrolling.

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs
import qs.controlcenter
import qs.lock
import qs.notifications
import qs.network
import qs.nightlight
import qs.themes
import qs.wallpaper
import qs.weather

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
        // Body: toggle. No detail view — the two timeouts it suppresses live
        // on the Settings page's Behaviour tab, not here.
        //
        // Suppresses both IdleService stages (lock + screen blank) AND holds
        // a logind inhibitor for the suspend timer / lid switch. See
        // ControlCenterService.
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

        // ---- Theme (light/dark toggle) ----
        // Body: apply the sibling of the current theme (e.g. Catppuccin
        // Mocha → Catppuccin Latte). Disabled when no current theme
        // matches (Custom state) or the matched theme has no sibling
        // declared (built-in or user theme without siblingId).
        //
        // Icon: sun glyph when current is dark (toggle would go light),
        // moon glyph when current is light (toggle would go dark). The
        // icon points at the destination kind, mirroring how a "dark
        // mode" toggle in mainstream OSes shows the moon when in light
        // mode (and vice versa).
        //
        // State text shows "Switch to Light" / "Switch to Dark" rather
        // than the sibling's full label — a 104 px tile can't fit
        // "Switch to Catppuccin Latte" without elision, and the kind
        // alone is unambiguous in context (the user knows which theme
        // family they're on from the Theme tab).
        Tile {
            width: root._tileWidth
            height: root._tileHeight
            icon: ThemePresets.currentTheme && ThemePresets.currentTheme.kind === "light"
                ? "\uf186"   // moon (toggling FROM light TO dark)
                : "\uf185"   // sun  (toggling FROM dark TO light)
            label: "Theme"
            stateText: {
                if (!ThemePresets.currentTheme) return "Apply a theme first";
                if (!ThemePresets.currentSibling) return "No light/dark variant";
                return ThemePresets.currentSibling.kind === "light"
                    ? "Switch to Light"
                    : "Switch to Dark";
            }
            active: false
            enabled: ThemePresets.currentSibling !== null
            onClicked: ThemePresets.toggleLightDark()
        }

        // Night light (cell 8). Hidden rather than dimmed when the feature
        // can't work — either hyprsunset isn't installed or this
        // compositor's backend has no night-light dispatch. A permanently
        // disabled tile would just be noise, and because this is the last
        // cell in the Grid, hiding it doesn't reflow the seven above.
        //
        // The moon glyph matches the Theme tile's moon, but the two never
        // mean the same thing in the same place: Theme's icon points at
        // the destination kind and flips, while this one is constant and
        // its label reads "Night light".
        Tile {
            width: root._tileWidth
            height: root._tileHeight
            visible: NightLightService.available
            icon: "\uf186"   // moon
            label: "Night light"
            stateText: NightLightService.enabled
                ? (NightLightService.temperature + "K")
                : "Off"
            active: NightLightService.enabled
            onClicked: NightLightService.toggle()
        }
        }   // end Grid

        // ---- Weather card ----
        //
        // KNMI-backed (via Open-Meteo's `models=knmi_seamless`) current
        // conditions + today's high/low. Clicking the city pill opens
        // the cities detail view in the CC's view-stack. First-run state
        // ("Set location") is whole-card clickable to the same view.
        WeatherCard {
            width: parent.width
        }

        // ---- Now Playing card ----
        //
        // Reused from the lock screen. Auto-hides when no MPRIS player has
        // a track (its `visible` binding handles that internally), so a
        // collapsed item takes 0 vertical space in this Column and the
        // popup appears more compact when there's nothing to show.
        // Width override fills the CC's inner width (~396 px after the
        // popup-padding bump); the card's hardcoded 360 default would
        // leave awkward asymmetric padding.
        NowPlayingCard {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
        }
    }
}
