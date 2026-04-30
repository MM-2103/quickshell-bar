// PowerProfile.qml
// Bar icon for power-profiles-daemon control.
//   Left   -> open the picker popup
//   Middle -> cycle to the next profile
//
// Visual: a half-circle gauge with a needle. Needle position = profile:
//   Power Saver  -> needle pointing left
//   Balanced     -> needle pointing straight up
//   Performance  -> needle pointing right (accent-colored)

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.UPower
import qs

MouseArea {
    id: root

    implicitWidth: 22
    implicitHeight: 22
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    function _needleAngle() {
        const p = PowerProfiles.profile;
        if (p === PowerProfile.Performance) return  60;
        if (p === PowerProfile.Balanced)    return  0;
        return -60; // PowerSaver
    }

    function _isPerformance() {
        return PowerProfiles.profile === PowerProfile.Performance;
    }

    function _cycle() {
        const list = [PowerProfile.PowerSaver, PowerProfile.Balanced];
        if (PowerProfiles.hasPerformanceProfile) list.push(PowerProfile.Performance);
        const cur = PowerProfiles.profile;
        const idx = list.indexOf(cur);
        const next = list[(idx + 1) % list.length];
        PowerProfiles.profile = next;
    }

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
            popup.toggle();
        } else if (mouse.button === Qt.MiddleButton) {
            root._cycle();
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

    // Half-circle gauge with a rotating needle.
    Item {
        id: gauge
        anchors.centerIn: parent
        width: 16
        height: 11

        // Needle pivot is at (8, 10) — center bottom of the gauge.
        readonly property real pivotX: 8
        readonly property real pivotY: 10

        // Animated needle angle (degrees, 0 = straight up).
        property real needleAngle: root._needleAngle()
        Behavior on needleAngle {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutBack
                easing.overshoot: 1.4
            }
        }

        // Match the brightness of theme icons. Profile state is shown by
        // needle position (and accent color when on Performance), not by
        // dimming the dial.
        readonly property color dialColor:   Theme.text
        readonly property color needleColor: root._isPerformance() ? Theme.accent : Theme.text

        // Dial arc + tick marks.
        Shape {
            anchors.fill: parent
            antialiasing: true
            layer.enabled: true
            layer.samples: 4

            // Outer arc
            ShapePath {
                strokeColor: gauge.dialColor
                strokeWidth: 1.3
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                startX: 1; startY: 10
                PathArc {
                    x: 15; y: 10
                    radiusX: 7; radiusY: 7
                    direction: PathArc.Clockwise
                }
            }

            // Three tick marks at -60° / 0° / +60° on the dial perimeter.
            // Computed once: r=6, pivot=(8,10).
            //   -60°: (8 + 6*sin(-60°), 10 - 6*cos(-60°)) = (2.80, 7.00)  outer (3.66, 5.50) inner-end (3.20, 6.40)
            //    0°:  (8, 4) outer ; (8, 5) inner
            //   +60°: (13.20, 7.00) outer ; (12.34, 5.50) inner
            ShapePath {
                strokeColor: gauge.dialColor
                strokeWidth: 1.0
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                // Left tick (-60°)
                startX: 3.20; startY: 6.40
                PathLine { x: 2.80; y: 7.00 }
            }
            ShapePath {
                strokeColor: gauge.dialColor
                strokeWidth: 1.0
                capStyle: ShapePath.RoundCap

                // Center tick (0°)
                startX: 8;   startY: 4
                PathLine { x: 8; y: 5 }
            }
            ShapePath {
                strokeColor: gauge.dialColor
                strokeWidth: 1.0
                capStyle: ShapePath.RoundCap

                // Right tick (+60°)
                startX: 12.80; startY: 6.40
                PathLine { x: 13.20; y: 7.00 }
            }
        }

        // Needle: a thin rectangle pivoting at its bottom-center.
        Rectangle {
            id: needle
            width: 1.6
            height: 6
            radius: 0.8
            color: gauge.needleColor
            x: gauge.pivotX - width / 2
            y: gauge.pivotY - height
            antialiasing: true

            transform: Rotation {
                origin.x: needle.width / 2
                origin.y: needle.height
                angle: gauge.needleAngle
            }

            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        // Pivot dot.
        Rectangle {
            width: 3; height: 3
            radius: 1.5
            color: gauge.needleColor
            x: gauge.pivotX - width / 2
            y: gauge.pivotY - height / 2
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }

    PowerProfilePopup {
        id: popup
        anchorItem: root
    }
}
