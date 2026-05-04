pragma Singleton

// SettingsService.qml
// State for the Settings page — a centered Overlay popup that visually
// edits `~/.config/quickshell-bar/config.jsonc` (the same file users can
// hand-edit; see `docs/CUSTOMIZATION.md`).
//
// All actual file I/O lives in `Local.qml` — this singleton just owns the
// popup's open/close state, the active tab, and the popup mutex
// integration. Settings rows call `Local.set(key, value)` /
// `Local.reset(key)` directly; this service is only the orchestrator.
//
// Per-monitor pattern: one `SettingsPopup` per screen via `Variants` in
// shell.qml; visibility gated on `popupOpen && isFocusedScreen` so on
// multi-monitor setups only the focused monitor shows the popup.

import QtQuick
import Quickshell
import qs
import qs.themes

Singleton {
    id: root

    // ---- popup state ----

    property bool popupOpen: false

    // Active tab. One of: "theme" | "colors" | "typography" | "layout"
    // | "behavior". Reset to "theme" on each open — the lighter-touch
    // entry point. Users browsing settings land on the visual catalogue
    // first; if they want to drill into individual colour overrides
    // they're one click into "Colours" away.
    property string activeTab: "theme"

    function setTab(name) {
        if (!name) name = "theme";
        root.activeTab = name;
    }

    // ---- open / close ----

    function openPopup() {
        if (popupOpen) return;
        PopupController.open(root, () => root.closePopup());
        root.activeTab = "theme";
        // Re-scan ~/.config/quickshell-bar/themes on every open so a
        // user-dropped theme file appears without a daemon restart.
        // Cheap (sub-ms for ~10 small JSONC files) and runs only on
        // explicit popup-open, not on every interaction.
        ThemePresets.rescan();
        root.popupOpen = true;
    }
    function closePopup() {
        if (!popupOpen) return;
        // Close the picker too if it was open — orphan picker state on
        // close looks weird and would re-show on next openPopup().
        root.closePicker();
        root.popupOpen = false;
    }
    function togglePopup() {
        if (popupOpen) closePopup();
        else            openPopup();
    }
    onPopupOpenChanged: if (!popupOpen) PopupController.closed(root)

    // ---- color picker state ----
    //
    // The colour picker is a SINGLE instance owned by SettingsPopup at
    // its top level (after the Column → after the Flickable → drawn
    // on top of every settings row regardless of which row triggered
    // it). ColorRow doesn't embed its own picker because z-ordering
    // wouldn't beat sibling rows that render after it in the Column.
    //
    // ColorRow's swatch click calls `openPicker(key, color, anchor)`;
    // SettingsPopup binds the picker's visibility, position, and
    // current colour from these properties. Picker writes go through
    // `Local.set(pickerKey, c)`.

    property bool pickerOpen: false
    property string pickerKey: ""
    property color pickerColor: "#000000"
    // The swatch Item itself — used by SettingsPopup to compute card-
    // relative position via mapToItem.
    property var pickerAnchor: null

    function openPicker(key, color, anchor) {
        // Click same swatch again → close (toggle behaviour, KDE-like).
        if (root.pickerOpen && root.pickerKey === key) {
            root.closePicker();
            return;
        }
        // Opening a different overlay closes any existing one first so
        // we don't render a colour picker and a dropdown list on top of
        // each other.
        root.closeDropdown();
        root.pickerKey = key;
        root.pickerColor = color;
        root.pickerAnchor = anchor;
        root.pickerOpen = true;
    }
    function closePicker() {
        if (!pickerOpen) return;
        root.pickerOpen = false;
        root.pickerAnchor = null;
    }

    // ---- preset-dropdown state ----
    //
    // Same architecture as the colour picker: a SINGLE dropdown list
    // owned by SettingsPopup at root level so it draws above all rows.
    // The trigger Rectangle stays embedded in `PresetDropdown`; only
    // the floating list is hoisted, positioned via mapToItem from the
    // trigger anchor.

    property bool dropdownOpen: false
    property string dropdownKey: ""
    // Optional secondary key (e.g. companionLabel write for searchName
    // when picking a search-engine preset for searchUrl).
    property string dropdownCompanionKey: ""
    property var dropdownPresets: []         // [{ label, value, companionLabel? }]
    property string dropdownSelectedValue: ""
    property var dropdownAnchor: null

    function openDropdown(key, presets, selectedValue, companionKey, anchor) {
        if (root.dropdownOpen && root.dropdownKey === key) {
            root.closeDropdown();
            return;
        }
        // Mutually-exclusive with the colour picker.
        root.closePicker();
        root.dropdownKey = key;
        root.dropdownPresets = presets || [];
        root.dropdownSelectedValue = selectedValue || "";
        root.dropdownCompanionKey = companionKey || "";
        root.dropdownAnchor = anchor;
        root.dropdownOpen = true;
    }
    function closeDropdown() {
        if (!dropdownOpen) return;
        root.dropdownOpen = false;
        root.dropdownAnchor = null;
    }
}
