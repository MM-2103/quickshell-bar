// Notifications.qml
// Bar icon — bell glyph + count badge + DND indicator.
//   Left click  -> toggle the notification center popup
//   Right click -> toggle DND

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

    // Bell glyph — Font Awesome 7 Solid.
    //   Normal:  \uf0f3 bell
    //   DND on:  \uf1f6 bell-slash (the slash is baked into the glyph,
    //            so we no longer need a separate Rectangle overlay).
    BarIcon {
        anchors.centerIn: parent
        glyph: root.dnd ? "\uf1f6" : "\uf0f3"
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
