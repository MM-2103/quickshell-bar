// NotificationCenterPopup.qml
// Notification center — full history list, DND toggle, clear-all.

import QtQuick
import Quickshell
import qs

PopupWindow {
    id: popup

    required property Item anchorItem

    color: "transparent"

    property bool wantOpen: false
    visible: wantOpen || hideHold.running
    Timer { id: hideHold; interval: 180; repeat: false }
    onWantOpenChanged: {
        if (wantOpen) hideHold.stop();
        else          hideHold.restart();
    }

    function toggle() {
        if (popup.wantOpen) {
            popup.wantOpen = false;
        } else {
            PopupController.open(popup, () => popup.wantOpen = false);
            popup.wantOpen = true;
        }
    }
    function close()  { popup.wantOpen = false; }
    onVisibleChanged: if (!visible) PopupController.closed(popup)

    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? -((popup.width - anchorItem.width) / 2) : 0
    anchor.rect.y: anchorItem ? anchorItem.height + 6 : 0
    anchor.adjustment: PopupAdjustment.SlideX

    implicitWidth: 380
    implicitHeight: container.implicitHeight

    readonly property var notifs: NotificationService.trackedNotifications
        ? NotificationService.trackedNotifications.values
        : []
    readonly property int count: notifs.length

    Rectangle {
        id: container
        anchors.fill: parent
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

        // Snappy fade-in + 4 px slide-up.
        opacity: popup.wantOpen ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        transform: Translate {
            y: popup.wantOpen ? 0 : 4
            Behavior on y {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }

        // Account for: header top margin (10) + header height + divider gap
        // (6) + divider (1) + bodyArea top margin (6) + bodyArea height +
        // bottom padding (10).
        implicitHeight: 10 + header.implicitHeight + 6 + 1 + 6
                      + bodyArea.implicitHeight + 10

        // ---- Header ----
        Item {
            id: header
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 10
            }
            implicitHeight: 26
            height: implicitHeight

            Text {
                id: titleLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeNormal
                font.weight: Font.Bold
            }

            Text {
                anchors.left: titleLabel.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: popup.count > 0
                text: popup.count
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
            }

            // Right-aligned controls: Clear + DND toggle
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                // "Clear" link
                MouseArea {
                    id: clearMa
                    anchors.verticalCenter: parent.verticalCenter
                    visible: popup.count > 0
                    width: clearLabel.implicitWidth
                    height: clearLabel.implicitHeight
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationService.clearAll()

                    Text {
                        id: clearLabel
                        text: "Clear"
                        color: clearMa.containsMouse ? Theme.text : Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }
                }

                // DND label + toggle pill grouped
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "DND"
                        color: NotificationService.dndEnabled ? Theme.text : Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: NotificationService.dndEnabled ? Font.Bold : Font.Normal
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }

                    Rectangle {
                        id: dndToggle
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 18
                        radius: 9
                        color: NotificationService.dndEnabled ? Theme.accent : Theme.surface
                        border.color: Theme.border
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Theme.animMed } }

                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            anchors.verticalCenter: parent.verticalCenter
                            x: NotificationService.dndEnabled ? parent.width - width - 3 : 3
                            color: NotificationService.dndEnabled ? Theme.bg : Theme.text
                            Behavior on x { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationService.toggleDnd()
                        }
                    }
                }
            }
        }

        // ---- Divider ----
        Rectangle {
            id: divider
            anchors.top: header.bottom
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            height: 1
            color: Theme.border
        }

        // ---- Body: list or empty state ----
        Item {
            id: bodyArea
            anchors {
                top: divider.bottom
                left: parent.left
                right: parent.right
                topMargin: 6
            }
            // Empty state needs a comfortable padding around the centered
            // text. List mode caps the height; we add slack so the last
            // card isn't visually pinched against the popup's bottom edge.
            implicitHeight: popup.count > 0
                ? Math.min(listView.contentHeight, 440)
                : 56

            // Empty state
            Text {
                id: emptyText
                visible: popup.count === 0
                anchors.centerIn: parent
                text: "No notifications"
                color: Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeNormal
            }

            // History list — newest first.
            ListView {
                id: listView
                anchors {
                    fill: parent
                    leftMargin: 8
                    rightMargin: 8
                }
                visible: popup.count > 0
                clip: true
                spacing: 6
                interactive: true
                boundsBehavior: Flickable.StopAtBounds

                // Reverse the model so newest notifications are at the top.
                model: {
                    const list = popup.notifs.slice();
                    list.reverse();
                    return list;
                }

                delegate: NotificationCard {
                    required property var modelData
                    notif: modelData
                    mode: "center"
                    width: ListView.view.width
                }
            }
        }
    }
}
