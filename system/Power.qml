// Power.qml
// Bar icon for the power menu. Click opens a popup with
// Lock / Suspend / Logout / Reboot / Shutdown buttons.

import QtQuick
import Quickshell
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

    // Power glyph — Font Awesome 7 Solid \uf011 power-off.
    BarIcon {
        anchors.centerIn: parent
        glyph: "\uf011"
    }

    PowerMenuPopup {
        id: popup
        anchorItem: root
    }
}
