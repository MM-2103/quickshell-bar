// Tile.qml
// Reusable tile for the Control Center grid. Two-line layout:
//   Top row:    [icon] [label]      [chevron?]
//   Bottom row: state value
//
// Two click zones:
//   Body click   → primary action (toggle, cycle, or open detail view)
//   Chevron tap  → secondary action (typically open the detail view in
//                  cases where the body click does something else, e.g.
//                  Wi-Fi: body toggles radio, chevron drills into the list)
//
// Chevron is only shown for tiles that have a meaningful detail view AND
// a different primary body action. Pure-toggle tiles (Caffeine, DND) and
// pure-picker tiles (Wallpaper) have no chevron.
//
// Active state inverts the colour palette (accent fill, accentText fg)
// — same convention as the wallpaper picker's selector pills.

import QtQuick
import qs

Rectangle {
    id: root

    // ---- Public API ----

    // Font Awesome glyph code (or any unicode the chosen font carries).
    property string icon: ""

    // True if the icon comes from FA Brands (Bluetooth) rather than Solid.
    property bool brand: false

    // Top-row label. Shown bold, mono.
    property string label: ""

    // Bottom-row state ("MyNetwork", "Balanced", "Off", …).
    property string stateText: ""

    // Highlight (accent fill) when the underlying state is "on".
    property bool active: false

    // Render the chevron in the top-right and accept clicks on it.
    property bool showChevron: false

    // Optional: override the icon's tint (e.g. PowerProfile uses accent on
    // Performance even when the tile itself isn't active). Disabled tiles
    // render the icon dimmed regardless of override, so consumers don't
    // have to special-case the disabled state.
    property color iconColor: !root.enabled
        ? Theme.textMuted
        : (root.active ? Theme.accentText : Theme.text)

    // Note on `enabled`: this property is inherited from Item; consumers
    // bind `enabled: false` to render a dimmed, non-interactive tile
    // (used by the light/dark toggle when the current theme has no
    // sibling). Item.enabled cascades to all child MouseAreas, so click
    // suppression and hover suppression happen automatically — we only
    // need to express the visual delta here.

    signal clicked()
    signal chevronClicked()

    // ---- Visual ----

    height: 64
    radius: Theme.radiusSmall
    color: root.active
        ? Theme.accent
        : (bodyMa.containsMouse ? Theme.surfaceHi : Theme.surface)
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    // Two stacked rows, padded inside the tile.
    Column {
        anchors {
            fill: parent
            margins: 8
        }
        spacing: 4

        // Top row: icon + label + (optional chevron)
        Row {
            width: parent.width
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                color: root.iconColor
                font.family: root.brand ? Theme.fontBrand : Theme.fontIcon
                font.styleName: root.brand ? "Regular" : "Solid"
                font.pixelSize: 14
                renderType: Text.NativeRendering
                width: 16
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 16 - parent.spacing
                       - (root.showChevron ? 12 + parent.spacing : 0)
                text: root.label
                color: !root.enabled
                    ? Theme.textMuted
                    : (root.active ? Theme.accentText : Theme.text)
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            // Chevron (FA Solid \uf054 chevron-right). Visual only; the
            // hit-area is below as a separate MouseArea.
            Text {
                visible: root.showChevron
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf054"
                color: root.active ? Theme.accentText : Theme.textDim
                font.family: Theme.fontIcon
                font.styleName: "Solid"
                font.pixelSize: 9
                renderType: Text.NativeRendering
                width: 12
                horizontalAlignment: Text.AlignRight
            }
        }

        // Bottom row: state value (smaller, dim).
        Text {
            width: parent.width
            text: root.stateText
            color: !root.enabled
                ? Theme.textMuted
                : (root.active
                    ? Qt.rgba(Theme.accentText.r, Theme.accentText.g, Theme.accentText.b, 0.75)
                    : Theme.textDim)
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }
    }

    // ---- Click zones ----
    //
    // Order matters: chevronMa is declared SECOND so it sits on top of
    // bodyMa in z-order. When the user clicks inside the chevron strip
    // (top-right ~28×32 region), the chevron wins; clicks elsewhere fall
    // through to bodyMa. This gives us GNOME/KDE-style two-zone behaviour
    // without any explicit z assignment.

    MouseArea {
        id: bodyMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    MouseArea {
        id: chevronMa
        visible: root.showChevron
        enabled: root.showChevron
        anchors.right: parent.right
        anchors.top: parent.top
        width: 32
        height: 32
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.chevronClicked()
    }
}
