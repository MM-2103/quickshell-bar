// Brightness.qml
// Bar widget for backlight control. Hidden when no backlight device exists
// (i.e. a desktop). Mirrors the Volume widget's controls:
//   Left   -> toggle the brightness popup
//   Wheel  -> +/- 5 % brightness

import QtQuick
import Quickshell
import qs
import qs.osd

MouseArea {
    id: root

    visible: OsdService.hasBrightness
    implicitWidth: visible ? 22 : 0
    implicitHeight: 22
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton

    onClicked: popup.toggle()

    onWheel: wheel => {
        if (!OsdService.hasBrightness) return;
        const step = 0.05;
        const delta = wheel.angleDelta.y > 0 ? step : -step;
        OsdService.setBrightness(OsdService.brightnessRatio + delta);
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

    // Sun glyph — Font Awesome 7 Solid \uf185.
    BarIcon {
        anchors.centerIn: parent
        glyph: "\uf185"
    }

    BarTooltip {
        anchorItem: root
        show: root.containsMouse && !popup.visible
        text: "Brightness " + Math.round(OsdService.brightnessRatio * 100) + "%"
    }

    BrightnessPopup {
        id: popup
        anchorItem: root
    }
}
