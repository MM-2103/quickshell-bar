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

Singleton {
    id: root

    // ---- popup state ----

    property bool popupOpen: false

    // Active tab. One of: "colors" | "typography" | "layout" | "behavior".
    // Reset to "colors" on each open so users land at a predictable spot.
    property string activeTab: "colors"

    function setTab(name) {
        if (!name) name = "colors";
        root.activeTab = name;
    }

    // ---- open / close ----

    function openPopup() {
        if (popupOpen) return;
        PopupController.open(root, () => root.closePopup());
        root.activeTab = "colors";
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
}
