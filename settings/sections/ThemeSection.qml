// ThemeSection.qml
// Settings tab content for the Theme picker. A "Current: X" status line
// followed by a Flow of ThemeCard items (one per entry in
// ThemePresets.all — built-in palettes first, then any user-defined
// themes from ~/.config/quickshell-bar/themes/*.jsonc).
//
// Cards apply their palette on click, writing all 14 colour keys via
// ThemePresets.applyTheme. The selected indicator on each card and
// the "Current:" label both read ThemePresets.currentTheme, which is
// reactive on Local.data — so manual ColorRow edits flip the selection
// to "Custom" without explicit wiring.
//
// Layout: Flow auto-wraps cards based on available width. At the
// popup's 808 px content width with 8 px gaps, four cards fit per row
// (4 × 188 + 3 × 8 = 776, plus padding). 10 built-in themes therefore
// take three rows; user themes overflow onto subsequent rows. The Flow
// wraps cleanly at any width, so resizing the popup later won't break
// the layout.

import QtQuick
import qs
import qs.settings.controls
import qs.themes

Column {
    width: parent ? parent.width : 0
    spacing: 12

    // ---- Status line ----
    //
    // "Current: <label>" or "Current: Custom" depending on whether
    // ThemePresets.currentTheme matches anything. Visually mirrors a
    // SectionHeader but with a normal-weight body trailing the label,
    // so it reads as informational rather than a section divider.
    Item {
        width: parent.width
        height: 22

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Current"
            color: Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 64
            anchors.verticalCenter: parent.verticalCenter
            text: ThemePresets.currentTheme
                ? ThemePresets.currentTheme.label
                : "Custom"
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    // ---- Theme grid ----
    //
    // Flow wraps cards based on available width. Spacing matches the
    // ColorPicker / PresetDropdownList padding norms (4–8 px) and
    // pairs cleanly with ThemeCard's 188 × 80 size.
    Flow {
        width: parent.width
        spacing: 8

        Repeater {
            model: ThemePresets.all

            delegate: ThemeCard {
                required property var modelData
                theme: modelData
            }
        }
    }
}
