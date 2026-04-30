// IdleInhibit.qml
// Toggle to keep the system from sleeping / locking.
// Implementation: long-running `systemd-inhibit ... sleep infinity` Process.
// Visual: a coffee cup. Outline-only when inactive; filled with steam when active.
//
// Scope: covers logind-managed sleep and lid-close handling. Does NOT
// suppress compositor screen blanking / DPMS (those use the Wayland
// idle-inhibit-v1 protocol, which Quickshell doesn't expose).

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs

MouseArea {
    id: root

    implicitWidth: 22
    implicitHeight: 22
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    property bool active: false

    onClicked: root.active = !root.active

    Process {
        running: root.active
        command: [
            "systemd-inhibit",
            "--what=idle:sleep:handle-lid-switch",
            "--who=quickshell-bar",
            "--why=user requested always-on",
            "--mode=block",
            "sleep", "infinity"
        ]
    }

    // Hover / active background pill
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: root.active
            ? (root.containsMouse ? Theme.surface : Theme.surfaceHi)
            : (root.containsMouse ? Theme.surface : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // Coffee cup glyph drawn with QtQuick.Shapes for crisp curves.
    Item {
        id: cup
        anchors.centerIn: parent
        width: 16
        height: 16

        // Idle stroke matches the surrounding theme icons (full Theme.text);
        // the off/on state is conveyed by fill + steam + background pill,
        // not by dimming the outline.
        readonly property color stroke: root.active ? Theme.accent : Theme.text
        readonly property color fill:   root.active ? Theme.accent : "transparent"

        // Cup body + handle.
        Shape {
            anchors.fill: parent
            antialiasing: true
            layer.enabled: true
            layer.samples: 4

            // Cup body outline / fill.
            ShapePath {
                strokeColor: cup.stroke
                strokeWidth: 1.5
                fillColor: cup.fill
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                startX: 3.5; startY: 6
                PathLine { x: 10.5; y: 6 }                      // rim
                PathLine { x: 9.8;  y: 13 }                     // right side (taper)
                PathQuad { x: 4.2; y: 13; controlX: 7; controlY: 14.2 }  // rounded bottom
                PathLine { x: 3.5; y: 6 }                       // back to start
            }

            // Handle: D-ring on the right.
            ShapePath {
                strokeColor: cup.stroke
                strokeWidth: 1.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                startX: 10.5; startY: 8
                PathQuad { x: 13.5; y: 9.5; controlX: 14; controlY: 8  }
                PathQuad { x: 10.5; y: 11;  controlX: 14; controlY: 11 }
            }
        }

        // Steam — visible only when active.
        Shape {
            visible: root.active
            anchors.fill: parent
            antialiasing: true
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                strokeColor: cup.stroke
                strokeWidth: 1.2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 5.5; startY: 4
                PathQuad { x: 5.5; y: 1; controlX: 7; controlY: 2.5 }
            }
            ShapePath {
                strokeColor: cup.stroke
                strokeWidth: 1.2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 8.5; startY: 4
                PathQuad { x: 8.5; y: 1; controlX: 10; controlY: 2.5 }
            }
        }
    }
}
