// Clock.qml
// Date + time row. The date area is hoverable/clickable and triggers a Calendar popup.

import QtQuick
import Quickshell
import qs

Row {
    id: root
    spacing: 10

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // Date — hoverable trigger for the calendar.
    Item {
        id: dateBox
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: dateText.implicitWidth + 10
        implicitHeight: dateText.implicitHeight + 4

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: calendar.pinned
                ? Theme.surfaceHi
                : (dateMouse.containsMouse ? Theme.surface : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Text {
            id: dateText
            anchors.centerIn: parent
            text: Qt.formatDateTime(clock.date, "ddd, MMM d")
            color: (dateMouse.containsMouse || calendar.pinned) ? Theme.text : Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeNormal
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        MouseArea {
            id: dateMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // Only the pinned (clicked) state participates in the popup
            // mutex — hovering opens the calendar but is non-grabby, so a
            // stray hover doesn't yank the active popup away from another
            // widget the user is interacting with.
            onClicked: {
                if (calendar.pinned) {
                    calendar.pinned = false;
                } else {
                    PopupController.open(calendar, () => calendar.pinned = false);
                    calendar.pinned = true;
                }
            }
        }
    }

    // Separator
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "—"
        color: Theme.textMuted
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeNormal
    }

    // Time
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(clock.date, "HH:mm:ss")
        color: Theme.text
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeNormal
        font.weight: Font.Bold
    }

    // Calendar popup. As a Window subclass it isn't laid out by Row.
    Calendar {
        id: calendar
        anchorItem: dateBox
        today: clock.date
        hoveringDate: dateMouse.containsMouse
    }
}
