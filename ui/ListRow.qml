// ListRow.qml
// One row in a Control Center list: Wi-Fi networks, Bluetooth devices,
// power profiles, cities. Every list uses it, so height, padding, fonts
// and colours are the same everywhere.
//
//   [icon]  Title                               [primary] [forget]
//           status line (or the hovered button's hint)
//
// By default the row itself ignores the mouse: no hover highlight, no
// click. Actions are IconButtons declared as children, which land in the
// right-aligned action row. clickable: true is for pick-one lists (power
// profile, city), where selecting the row is the only action.
//
// expansion holds extra content under the main line, such as the Wi-Fi
// password field. It is shown while expanded is true.

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs

Rectangle {
    id: row

    property string title: ""
    property string status: ""
    property bool statusError: false
    // Bold title and brighter status: connected device, current choice.
    property bool emphasized: false
    // Half opacity: present but unusable (unplugged cable).
    property bool dimmed: false

    // Leading 16 px slot. First match wins: radio dot, theme icon,
    // Font Awesome glyph, boxed fallback text.
    property bool radio: false
    property bool radioChecked: false
    property string iconName: ""
    property string glyph: ""
    property string fallbackText: ""

    property bool clickable: false
    signal clicked()

    default property alias actions: actionRow.data
    property alias expansion: expansionSlot.data
    property bool expanded: false

    // ---- Hint protocol ----
    // Buttons register the hint for their hovered or armed state. The
    // last one registered wins, so hovering Disconnect while Forget is
    // armed shows "Disconnect", and moving off shows the armed text again.
    readonly property bool acceptsHints: true
    property var _hints: []
    readonly property string hint: _hints.length > 0 ? _hints[_hints.length - 1].text : ""
    function setHint(owner, text) {
        const next = _hints.filter(h => h.owner !== owner);
        if (text) next.push({ owner: owner, text: text });
        _hints = next;
    }

    width: parent ? parent.width : 0
    height: 40 + (expanded ? expansionSlot.height + 8 : 0)
    radius: Theme.radiusSmall
    color: clickable && rowMa.containsMouse ? Theme.surfaceHi : Theme.surface
    opacity: dimmed ? 0.5 : 1.0
    clip: true
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }

    MouseArea {
        id: rowMa
        anchors.fill: parent
        enabled: row.clickable
        hoverEnabled: row.clickable
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }

    Item {
        id: main
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            leftMargin: 10
            rightMargin: 10
        }
        height: 40

        Item {
            id: leading
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16

            Rectangle {
                visible: row.radio
                anchors.centerIn: parent
                width: 10
                height: 10
                radius: 5
                color: row.radioChecked ? Theme.accent : "transparent"
                border.color: Theme.textDim
                border.width: row.radioChecked ? 0 : 1
            }

            IconImage {
                id: themeIcon
                anchors.fill: parent
                implicitSize: 16
                source: row.iconName !== "" ? Quickshell.iconPath(row.iconName, true) : ""
                asynchronous: false
                visible: !row.radio && row.iconName !== "" && status === Image.Ready
            }

            Text {
                visible: !row.radio && !themeIcon.visible && row.glyph !== ""
                anchors.centerIn: parent
                text: row.glyph
                color: Theme.textDim
                font.family: Theme.fontIcon
                font.styleName: "Solid"
                font.pixelSize: 12
                renderType: Text.NativeRendering
            }

            Rectangle {
                visible: !row.radio && !themeIcon.visible && row.glyph === ""
                anchors.fill: parent
                radius: 3
                color: Theme.bg
                border.color: Theme.border
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: row.fallbackText
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeBadge
                    font.weight: Font.Bold
                }
            }
        }

        Column {
            anchors.left: leading.right
            anchors.leftMargin: 8
            anchors.right: actionRow.left
            anchors.rightMargin: actionRow.width > 0 ? 8 : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: row.title
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeNormal
                font.weight: row.emphasized ? Font.Bold : Font.Normal
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: row.hint !== "" ? row.hint : row.status
                color: row.hint !== "" ? Theme.text
                     : row.statusError ? Theme.errorBright
                     : row.emphasized ? Theme.textDim
                     : Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        Row {
            id: actionRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
        }
    }

    Item {
        id: expansionSlot
        visible: row.expanded
        anchors {
            top: main.bottom
            left: parent.left
            right: parent.right
            leftMargin: 10
            rightMargin: 10
        }
        height: childrenRect.height
    }
}
