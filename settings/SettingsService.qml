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
        root.popupOpen = false;
    }
    function togglePopup() {
        if (popupOpen) closePopup();
        else            openPopup();
    }
    onPopupOpenChanged: if (!popupOpen) PopupController.closed(root)
}
