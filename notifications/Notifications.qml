// Notifications.qml
// Bar icon — bell glyph + count badge + DND indicator.
//   Left click  -> toggle the notification center popup
//   Right click -> toggle DND

import QtQuick
import QtQuick.Shapes
import Quickshell
import qs

MouseArea {
    id: root

    implicitWidth: 22
    implicitHeight: 22
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    readonly property int count: NotificationService.trackedNotifications
        ? NotificationService.trackedNotifications.values.length
        : 0
    readonly property bool dnd: NotificationService.dndEnabled
    readonly property bool hasNotifications: count > 0

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
            popup.toggle();
        } else if (mouse.button === Qt.RightButton) {
            NotificationService.toggleDnd();
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

    // Bell glyph
    Item {
        id: bell
        anchors.centerIn: parent
        width: 14
        height: 14

        // Always full brightness to match the theme icons. State is shown
        // by the badge (count) and the slash overlay (DND).
        readonly property color stroke: Theme.text
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        // Bell body (a rounded "U" shape capped flat at the top, with a small
        // base line and clapper). Drawn as a single ShapePath.
        Shape {
            anchors.fill: parent
            antialiasing: true
            layer.enabled: true
            layer.samples: 4

            // Body (dome + flared bottom)
            ShapePath {
                strokeColor: bell.stroke
                strokeWidth: 1.4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                // Start at lower-left of the bell body, just above the base bar.
                startX: 2; startY: 11
                // Sweep up the left side, curving inward over the dome top.
                PathQuad { x: 7;  y: 2;  controlX: 1;  controlY: 6 }
                // Right side back down, curving down to lower-right.
                PathQuad { x: 12; y: 11; controlX: 13; controlY: 6 }
                // Close along the bottom flared rim.
                PathLine { x: 2; y: 11 }
            }

            // Base line (the bar at the bottom of the bell)
            ShapePath {
                strokeColor: bell.stroke
                strokeWidth: 1.4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 1; startY: 12
                PathLine { x: 13; y: 12 }
            }

            // Clapper (small filled circle below the bell)
            ShapePath {
                strokeColor: bell.stroke
                strokeWidth: 0
                fillColor: bell.stroke
                startX: 7; startY: 13.2
                PathArc { x: 7; y: 13.2; radiusX: 1.1; radiusY: 1.1; useLargeArc: true }
            }
        }

        // DND slash — diagonal stroke through the bell
        Rectangle {
            visible: root.dnd
            anchors.centerIn: parent
            width: 18
            height: 1.6
            radius: 0.8
            color: Theme.accent
            rotation: -45
        }
    }

    // Unread badge — small accent circle with count text in the top-right.
    // Hidden when DND is on: the slash through the bell already conveys
    // "you're not being notified", and the user explicitly didn't want a
    // count of missed notifications staring at them.
    Rectangle {
        visible: root.hasNotifications && !root.dnd
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: 1
            topMargin: 1
        }
        width: countText.implicitWidth + 6
        height: 11
        radius: 5.5
        color: Theme.accent
        border.color: Theme.bg
        border.width: 1

        Text {
            id: countText
            anchors.centerIn: parent
            text: root.count > 9 ? "9+" : root.count
            color: Theme.accentText
            font.pixelSize: 8
            font.bold: true
        }
    }

    NotificationCenterPopup {
        id: popup
        anchorItem: root
    }
}
