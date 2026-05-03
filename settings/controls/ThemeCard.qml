// ThemeCard.qml
// Clickable card that previews and applies a theme palette. Used by
// ThemeSection's Flow grid; one card per entry in `ThemePresets.all`.
//
//   ┌────────────────────────────────┐
//   │ Tokyo Night Storm           ✓  │
//   │                                │
//   │ ▮ ▮ ▮ ▮ ▮ ▮                    │   ← bg / surface / surfaceHi /
//   └────────────────────────────────┘     accent / text / error
//
// The card flips its selected state via ThemePresets.currentTheme,
// which reactively re-evaluates whenever Local.data changes (so the
// indicator follows manual ColorRow edits without explicit wiring).
// Clicking writes all 14 keys via ThemePresets.applyTheme — the 500 ms
// debounce inside Local.set coalesces the writes into a single
// config.jsonc flush.
//
// Visual contract: 188 × 80 fits a 4-column Flow at the popup's 808 px
// content width with 8 px gaps. Swatch row uses the same 24 × 24 size
// as the ColorRow swatch so the visual vocabulary stays uniform.

import QtQuick
import qs
import qs.themes

Rectangle {
    id: card

    // The theme to render. Shape: id (string), label (string),
    // palette (record of the 14 colour keys). Built-in themes ship
    // their palette inline; user themes load the same record from
    // ~/.config/quickshell-bar/themes/*.jsonc.
    property var theme: null

    // True when ThemePresets says this theme matches the user's current
    // 14-key state. ID match is the only reliable comparison — the user
    // could in principle hand-craft a config that exactly mirrors a
    // built-in palette, in which case currentTheme picks the FIRST
    // match in `all`, which is what we render here too.
    readonly property bool _isSelected:
        ThemePresets.currentTheme
        && card.theme
        && ThemePresets.currentTheme.id === card.theme.id

    // Six representative swatches in left-to-right reading order:
    // surface tones first, then accent, then a text + error sample.
    // Six is enough to communicate the palette's character without
    // crowding the card. Order chosen so neighbouring swatches contrast
    // (bg/surface/surfaceHi all dark, then accent jumps in tone, then
    // text is bright, then error is the saturated finale).
    readonly property var _previewKeys: [
        "bg", "surface", "surfaceHi", "accent", "text", "error"
    ]

    width: 188
    height: 80
    radius: Theme.radius
    color: cardMa.containsMouse ? Theme.surfaceHi : Theme.surface
    border.color: card._isSelected ? Theme.accent : Theme.border
    // 2 px border when selected — matches the "filled = on" muscle
    // memory established by Tile.qml's active state and the wallpaper
    // picker's selector pills, just expressed as a heavier outline
    // since flipping the card's fill colour to accent would obliterate
    // the swatch row's preview.
    border.width: card._isSelected ? 2 : 1
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    // ---- Content ----
    //
    // Column with header row (name + check) on top, swatch row beneath.
    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        // Header: theme name on the left, check mark right-aligned
        // when selected. Item wrapper used (not Row) so the check
        // can right-anchor without disturbing the name's elide width.
        Item {
            width: parent.width
            height: 16

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (checkIcon.visible ? 18 : 0)
                text: card.theme ? card.theme.label : ""
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            // FA Solid \uf00c check — visible only when this card is the
            // currently-applied theme.
            Text {
                id: checkIcon
                visible: card._isSelected
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf00c"
                color: Theme.accent
                font.family: Theme.fontIcon
                font.styleName: "Solid"
                font.pixelSize: 11
                renderType: Text.NativeRendering
            }
        }

        // Swatch row: 6 fixed-size squares from the theme's palette.
        // Each cell is 24 × 24 with a faint border so swatches stay
        // visible against backgrounds that match their colour (e.g.
        // the bg swatch on a Default-themed card is the same colour
        // as Theme.bg minus an alpha — the border anchors it).
        Row {
            spacing: 4

            Repeater {
                model: card._previewKeys
                delegate: Rectangle {
                    required property string modelData
                    width: 24
                    height: 24
                    radius: Theme.radiusSmall
                    color: card.theme && card.theme.palette
                        ? (card.theme.palette[modelData] || "#000000")
                        : "#000000"
                    border.color: Theme.border
                    border.width: 1
                }
            }
        }
    }

    // ---- Click ----
    //
    // Whole-card click applies the theme. No nested click zones — the
    // card has no chevron-style secondary action.
    MouseArea {
        id: cardMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (card.theme) ThemePresets.applyTheme(card.theme);
        }
    }
}
