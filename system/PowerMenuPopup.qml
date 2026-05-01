// PowerMenuPopup.qml
// wlogout-style horizontal row of round buttons.
// Click an action → fires the corresponding command via execDetached and
// closes the popup. No confirmation dialog (matches wlogout convention).

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

    implicitWidth: container.implicitWidth
    implicitHeight: container.implicitHeight

    // Centralized action runner: fires the command and closes the popup.
    function _run(args) {
        Quickshell.execDetached(args);
        popup.close();
    }

    Rectangle {
        id: container
        anchors.fill: parent
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

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

        implicitWidth: row.implicitWidth + 16
        implicitHeight: row.implicitHeight + 16

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            // ============================================================
            // Inline button component — round disk + Font Awesome glyph
            // + label. The disk inverts on hover (white fill, dark glyph)
            // for a clear "primary action" feel.
            // ============================================================
            component PowerButton: MouseArea {
                id: btn
                property string label
                property string glyph         // Font Awesome 7 Solid codepoint
                property var onActivate       // function to call

                width: 56
                height: 64
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: btn.onActivate()

                Column {
                    anchors.fill: parent
                    spacing: 4

                    // Round icon disk
                    Item {
                        width: 44
                        height: 44
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: btn.containsMouse ? Theme.text : Theme.surface
                            border.color: Theme.border
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }

                        // Glyph — Font Awesome 7 Solid. Inverts to dark on
                        // hover so it stays readable on the white disk.
                        Text {
                            anchors.centerIn: parent
                            text: btn.glyph
                            color: btn.containsMouse ? Theme.bg : Theme.text
                            font.family: Theme.fontIcon
                            font.styleName: "Solid"
                            font.pixelSize: 18
                            renderType: Text.NativeRendering
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: btn.label
                        color: Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            // ============================================================
            // The five buttons. Glyphs (Font Awesome 7 Solid):
            //   \uf023 lock          \uf186 moon       \uf2f5 right-from-bracket
            //   \uf021 arrows-rotate \uf011 power-off
            // ============================================================
            PowerButton {
                label: "Lock"
                glyph: "\uf023"
                onActivate: () => popup._run(["loginctl", "lock-session"])
            }
            PowerButton {
                label: "Suspend"
                glyph: "\uf186"
                onActivate: () => popup._run(["systemctl", "suspend"])
            }
            PowerButton {
                label: "Logout"
                glyph: "\uf2f5"
                onActivate: () => popup._run(["niri", "msg", "action", "quit"])
            }
            PowerButton {
                label: "Reboot"
                glyph: "\uf021"
                onActivate: () => popup._run(["systemctl", "reboot"])
            }
            PowerButton {
                label: "Shutdown"
                glyph: "\uf011"
                onActivate: () => popup._run(["systemctl", "poweroff"])
            }
        }
    }
}
