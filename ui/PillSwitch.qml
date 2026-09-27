// PillSwitch.qml
// On/off switch for a view header (Wi-Fi radio, Bluetooth adapter).
// Accent fill when on, surface when off, 16 px thumb. Left click only.
// Takes part in the hint protocol like IconButton: while hovered, the
// header shows `hint` in place of its status text.

import QtQuick
import qs

Rectangle {
    id: pill

    property bool checked: false
    property string hint: ""

    signal toggled()

    readonly property string shownHint: ma.containsMouse && enabled ? hint : ""
    readonly property var hintTarget: {
        for (let p = pill.parent; p; p = p.parent) if (p.acceptsHints === true) return p;
        return null;
    }
    onShownHintChanged: if (hintTarget) hintTarget.setHint(pill, shownHint)

    width: 38
    height: 22
    radius: 11
    color: checked ? Theme.accent : Theme.surface
    border.color: Theme.border
    border.width: 1
    opacity: enabled ? 1.0 : 0.4
    Behavior on color { ColorAnimation { duration: Theme.animMed } }

    Rectangle {
        width: 16
        height: 16
        radius: 8
        anchors.verticalCenter: parent.verticalCenter
        x: pill.checked ? parent.width - width - 3 : 3
        color: pill.checked ? Theme.bg : Theme.text
        Behavior on x { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.toggled()
    }
}
