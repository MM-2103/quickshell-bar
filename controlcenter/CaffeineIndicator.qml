// CaffeineIndicator.qml
// Bar indicator shown only when Caffeine (idle-inhibit) is active.
// Click toggles it off; disappears when off.
//
// State lives in ControlCenterService — this is a read-only consumer
// of the same property that drives the Caffeine tile in the CC grid.
// No Process here (that lives on the service so it survives whichever
// UI element the user interacts with).

import QtQuick
import Quickshell
import qs
import qs.controlcenter

MouseArea {
    id: root

    implicitWidth: visible ? 22 : 0
    implicitHeight: 22
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    visible: ControlCenterService.idleInhibitActive

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: root.containsMouse ? Theme.surfaceHi : Theme.surface
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    BarIcon {
        anchors.centerIn: parent
        glyph: "\uf7b6"                     // mug-hot
        color: Theme.text
    }

    BarTooltip {
        anchorItem: root
        show: root.containsMouse
        text: "Caffeine: On \u2014 Click to disable"
    }

    onClicked: ControlCenterService.toggleIdleInhibit()
}
