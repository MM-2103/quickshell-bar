// Media.qml
// Bar icon for the media controller. Shows a music note glyph when at
// least one MPRIS player exists; entirely hidden otherwise.
//
//   Left click  -> toggle the media popup
//   Middle click-> toggle play/pause without opening the popup

import QtQuick
import QtQuick.Shapes
import Quickshell
import qs

MouseArea {
    id: root

    visible: MediaService.hasPlayers
    implicitWidth: visible ? 22 : 0
    implicitHeight: 22
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
            popup.toggle();
        } else if (mouse.button === Qt.MiddleButton) {
            MediaService.togglePlay();
        }
    }

    // Hover / active background pill
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: popup.visible
            ? Theme.surfaceHi
            : (root.containsMouse ? Theme.surface : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // Music note glyph: tilted oval head + vertical stem + curved flag.
    Item {
        id: note
        anchors.centerIn: parent
        width: 14
        height: 14

        readonly property color stroke:
            MediaService.isPlaying ? Theme.accent : Theme.text
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        // Note head — small oval, slightly tilted for the eighth-note look.
        Rectangle {
            x: 1
            y: 9
            width: 6
            height: 4
            radius: 2
            color: note.stroke
            antialiasing: true
            transform: Rotation { origin.x: 3; origin.y: 2; angle: -18 }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        // Stem
        Rectangle {
            x: 6.6
            y: 2
            width: 1.4
            height: 9
            radius: 0.7
            color: note.stroke
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        // Flag — curve coming off the top of the stem.
        Shape {
            anchors.fill: parent
            antialiasing: true
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                strokeColor: note.stroke
                strokeWidth: 1.4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                startX: 7;  startY: 2.5
                PathQuad { x: 11; y: 6.5; controlX: 12; controlY: 3 }
            }
        }
    }

    MediaPopup {
        id: popup
        anchorItem: root
    }
}
