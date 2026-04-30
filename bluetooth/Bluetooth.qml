// Bluetooth.qml
// Bar icon for the Bluetooth manager.
//   Left  -> toggle the bluetooth popup
//   Middle-> toggle adapter on/off

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets
import qs

MouseArea {
    id: root

    implicitWidth: 22
    implicitHeight: 22
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: adapter ? adapter.enabled : false

    // Any device currently connected on the default adapter.
    readonly property bool hasConnected: {
        if (!adapter) return false;
        const list = Bluetooth.devices.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].connected) return true;
        }
        return false;
    }

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
            popup.toggle();
        } else if (mouse.button === Qt.MiddleButton) {
            if (root.adapter) root.adapter.enabled = !root.adapter.enabled;
        }
    }

    // Hover background
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: popup.visible
            ? Theme.surfaceHi
            : (root.containsMouse ? Theme.surface : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // Icon (theme glyph with letter fallback). State conveyed by color.
    Item {
        anchors.centerIn: parent
        width: 16
        height: 16
        opacity: root.btEnabled ? 1.0 : 0.45
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        IconImage {
            id: btIcon
            anchors.fill: parent
            implicitSize: 16
            source: Quickshell.iconPath("network-bluetooth-symbolic", true)
            asynchronous: false
            visible: status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: btIcon.status !== Image.Ready
            text: "B"
            color: root.hasConnected ? Theme.accent : Theme.text
            font.pixelSize: 13
            font.bold: true
        }

        // Small accent dot when at least one device is connected.
        Rectangle {
            visible: root.btEnabled && root.hasConnected
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -1
            anchors.bottomMargin: -1
            width: 6
            height: 6
            radius: 3
            color: Theme.accent
            border.color: Theme.bg
            border.width: 1
        }
    }

    BluetoothPopup {
        id: popup
        anchorItem: root
    }
}
