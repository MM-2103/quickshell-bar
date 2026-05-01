// Calendar.qml
// PopupWindow showing either a month-day grid or a 12-month year grid.
//
// Inputs (set by parent):
//   anchorItem    : Item to position under
//   today         : current date (drives "today" highlight)
//   pinned        : kept open by click
//   hoveringDate  : the date trigger in the bar is hovered
//
// Internal state:
//   displayYear / displayMonth : the period being viewed
//   monthView                  : true=day grid, false=12-month grid

import QtQuick
import Quickshell
import qs

PopupWindow {
    id: cal

    required property Item anchorItem
    property date today: new Date()
    property bool pinned: false
    property bool hoveringDate: false
    property bool hoveringPopup: false

    property int displayYear: today.getFullYear()
    property int displayMonth: today.getMonth() // 0-11
    property bool monthView: true

    readonly property bool wantOpen: pinned || hoveringDate || hoveringPopup
    visible: wantOpen

    // Reset to current month every time the popup opens.
    onWantOpenChanged: {
        if (wantOpen) {
            cal.displayYear = cal.today.getFullYear();
            cal.displayMonth = cal.today.getMonth();
            cal.monthView = true;
        }
    }

    // If the controller (or some other code path) clears `pinned`, let the
    // mutex know we're no longer the active popup. Hovering doesn't enter
    // the mutex so we don't need to track hover-driven close here.
    onPinnedChanged: if (!pinned) PopupController.closed(cal)

    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? (anchorItem.width - cal.width) / 2 : 0
    anchor.rect.y: anchorItem ? anchorItem.height + 6 : 0

    color: "transparent"
    implicitWidth: monthView ? 260 : 220
    implicitHeight: monthView ? 240 : 184

    // 6 rows x 7 cols of month cells. Day=0 means blank.
    readonly property var _monthCells: {
        const year = cal.displayYear;
        const month = cal.displayMonth;
        const firstDay = new Date(year, month, 1);
        const firstIdx = (firstDay.getDay() + 6) % 7; // Mon=0
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const cells = [];
        for (let i = 0; i < 42; i++) {
            const day = i - firstIdx + 1;
            cells.push(day > 0 && day <= daysInMonth ? day : 0);
        }
        return cells;
    }

    function _stepPrev() {
        if (cal.monthView) {
            if (cal.displayMonth === 0) {
                cal.displayMonth = 11;
                cal.displayYear -= 1;
            } else {
                cal.displayMonth -= 1;
            }
        } else {
            cal.displayYear -= 1;
        }
    }

    function _stepNext() {
        if (cal.monthView) {
            if (cal.displayMonth === 11) {
                cal.displayMonth = 0;
                cal.displayYear += 1;
            } else {
                cal.displayMonth += 1;
            }
        } else {
            cal.displayYear += 1;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

        // Hover detector behind everything (does not eat clicks).
        MouseArea {
            anchors.fill: parent
            z: -1
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onContainsMouseChanged: cal.hoveringPopup = containsMouse
        }

        // Header: ‹  Title  ›
        Item {
            id: header
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 8
            }
            height: 26

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                // Font Awesome 7 Solid: \uf053 chevron-left
                text: "\uf053"
                color: prevMa.containsMouse ? Theme.text : Theme.textDim
                font.family: Theme.fontIcon
                font.styleName: "Solid"
                font.pixelSize: 12
                renderType: Text.NativeRendering
                width: 24
                horizontalAlignment: Text.AlignHCenter
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                MouseArea {
                    id: prevMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cal._stepPrev()
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                // Font Awesome 7 Solid: \uf054 chevron-right
                text: "\uf054"
                color: nextMa.containsMouse ? Theme.text : Theme.textDim
                font.family: Theme.fontIcon
                font.styleName: "Solid"
                font.pixelSize: 12
                renderType: Text.NativeRendering
                width: 24
                horizontalAlignment: Text.AlignHCenter
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                MouseArea {
                    id: nextMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cal._stepNext()
                }
            }

            Text {
                id: titleText
                anchors.centerIn: parent
                text: cal.monthView
                    ? Qt.formatDate(new Date(cal.displayYear, cal.displayMonth, 1), "MMMM yyyy")
                    : cal.displayYear.toString()
                color: titleMa.containsMouse ? Theme.accent : Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeNormal
                font.weight: Font.Bold
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                MouseArea {
                    id: titleMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cal.monthView = !cal.monthView
                }
            }

            // Pinned-state indicator: tiny accent dot in the top-right of
            // the header. Only present when the user has clicked to pin
            // the popup open, so they can tell apart "open because hover"
            // from "open because pinned" at a glance.
            Rectangle {
                visible: cal.pinned
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -2
                anchors.topMargin: -2
                width: 5
                height: 5
                radius: 2.5
                color: Theme.accent
            }
        }

        // ---- Month view ----
        Item {
            id: monthBody
            anchors {
                top: header.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 8
                topMargin: 4
            }
            visible: cal.monthView

            Row {
                id: weekdays
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    delegate: Item {
                        required property string modelData
                        required property int index
                        width: 32
                        height: 18
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: index >= 5 ? Theme.textMuted : Theme.textDim
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                        }
                    }
                }
            }

            Grid {
                anchors.top: weekdays.bottom
                anchors.topMargin: 2
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 7
                Repeater {
                    model: cal._monthCells
                    delegate: Item {
                        id: dayCell
                        required property var modelData
                        required property int index
                        width: 32
                        height: 28

                        readonly property int day: modelData
                        readonly property bool isToday: day > 0
                            && day === cal.today.getDate()
                            && cal.displayMonth === cal.today.getMonth()
                            && cal.displayYear === cal.today.getFullYear()
                        readonly property bool isWeekend: (index % 7) >= 5

                        Rectangle {
                            visible: dayCell.isToday
                            anchors.centerIn: parent
                            width: 24
                            height: 22
                            radius: Theme.radiusSmall
                            color: Theme.accent
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: dayCell.day > 0
                            text: dayCell.day
                            color: dayCell.isToday
                                ? Theme.accentText
                                : (dayCell.isWeekend ? Theme.textMuted : Theme.text)
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: dayCell.isToday ? Font.Bold : Font.Normal
                        }
                    }
                }
            }
        }

        // ---- Year view ----
        Grid {
            id: yearBody
            anchors {
                top: header.bottom
                topMargin: 8
                horizontalCenter: parent.horizontalCenter
            }
            visible: !cal.monthView
            columns: 3
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
                model: 12
                delegate: Item {
                    id: monthCell
                    required property int index
                    width: 64
                    height: 32

                    readonly property bool isCurrent: index === cal.today.getMonth()
                        && cal.displayYear === cal.today.getFullYear()

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: monthCell.isCurrent
                            ? Theme.accent
                            : (monthMa.containsMouse ? Theme.surfaceHi : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: Qt.formatDate(new Date(2000, monthCell.index, 1), "MMM")
                        color: monthCell.isCurrent ? Theme.accentText : Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: monthCell.isCurrent ? Font.Bold : Font.Normal
                    }

                    MouseArea {
                        id: monthMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            cal.displayMonth = monthCell.index;
                            cal.monthView = true;
                        }
                    }
                }
            }
        }
    }
}
