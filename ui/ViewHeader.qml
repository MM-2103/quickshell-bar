// ViewHeader.qml
// Top of a Control Center radio view (Wi-Fi, Bluetooth): status text,
// scan button, on/off switch, then a divider that is always shown.
// Hovering the button or switch shows its hint in place of the status
// text, the same way ListRow does.

import QtQuick
import qs

Column {
    id: header

    property string text: ""
    property string scanHint: "Scan"
    property bool scanEnabled: true
    property bool scanning: false
    property bool switchChecked: false
    property bool switchEnabled: true
    property string switchHint: ""

    signal scanClicked()
    signal switchToggled()

    function spinOnce() { scanBtn.spinOnce(); }

    // Hint protocol, see ListRow.
    readonly property bool acceptsHints: true
    property var _hints: []
    readonly property string hint: _hints.length > 0 ? _hints[_hints.length - 1].text : ""
    function setHint(owner, text) {
        const next = _hints.filter(h => h.owner !== owner);
        if (text) next.push({ owner: owner, text: text });
        _hints = next;
    }

    width: parent ? parent.width : 0
    spacing: 10

    Item {
        width: parent.width
        height: 24

        Text {
            anchors.left: parent.left
            anchors.right: scanBtn.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: header.hint !== "" ? header.hint : header.text
            color: header.hint !== "" ? Theme.text : Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }

        IconButton {
            id: scanBtn
            anchors.right: pill.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            glyph: "\uf021"
            hint: header.scanHint
            enabled: header.scanEnabled
            spinning: header.scanning
            active: header.scanning
            onClicked: header.scanClicked()
        }

        PillSwitch {
            id: pill
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: header.switchChecked
            enabled: header.switchEnabled
            hint: header.switchHint
            onToggled: header.switchToggled()
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.border
    }
}
