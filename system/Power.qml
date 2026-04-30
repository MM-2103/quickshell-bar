// Power.qml
// Bar icon for the power menu. Click opens a popup with
// Lock / Suspend / Logout / Reboot / Shutdown buttons.

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs

MouseArea {
    id: root

    implicitWidth: 22
    implicitHeight: 22
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton

    onClicked: popup.toggle()

    // Hover / active background pill
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: popup.visible
            ? Theme.surfaceHi
            : (root.containsMouse ? Theme.surface : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // Standard power glyph (`system-shutdown-symbolic` from breeze-dark
    // renders as a clean broken-circle + line in white). Letter fallback
    // if the theme is missing it for some reason.
    Item {
        anchors.centerIn: parent
        width: 14
        height: 14

        IconImage {
            id: pwrIcon
            anchors.fill: parent
            implicitSize: 14
            source: Quickshell.iconPath("system-shutdown-symbolic", true)
            asynchronous: false
            visible: status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: !pwrIcon.visible
            text: "⏻"
            color: Theme.text
            font.pixelSize: 13
            font.bold: true
        }
    }

    PowerMenuPopup {
        id: popup
        anchorItem: root
    }
}
