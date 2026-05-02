// ControlCenter.qml
// Bar trigger for the unified Control Center. Click toggles the popup;
// the popup itself is anchored to this widget (so its position tracks
// where this widget sits in the right cluster).
//
// Glyph: \uf737 sliders (Font Awesome Solid). Subtle and recognisable as
// "settings/quick controls"; matches the dark/mono aesthetic.

import QtQuick
import Quickshell
import qs
import qs.controlcenter

MouseArea {
    id: root

    implicitWidth: 22
    implicitHeight: 22
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton

    onClicked: popup.toggle()

    // Hover / active background pill.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: popup.visible
            ? Theme.surfaceHi
            : (root.containsMouse ? Theme.surface : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    BarIcon {
        anchors.centerIn: parent
        glyph: "\uf737"
    }

    ControlCenterPopup {
        id: popup
        anchorItem: root
    }

    BarTooltip {
        anchorItem: root
        show: root.containsMouse && !popup.visible
        text: "Control Center"
    }
}
