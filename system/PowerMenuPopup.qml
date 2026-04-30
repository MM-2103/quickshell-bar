// PowerMenuPopup.qml
// wlogout-style horizontal row of round buttons.
// Click an action → fires the corresponding command via execDetached and
// closes the popup. No confirmation dialog (matches wlogout convention).

import QtQuick
import QtQuick.Shapes
import Quickshell
import qs

PopupWindow {
    id: popup

    required property Item anchorItem

    color: "transparent"
    visible: false

    function toggle() {
        if (popup.visible) {
            popup.visible = false;
        } else {
            PopupController.open(popup, () => popup.visible = false);
            popup.visible = true;
        }
    }
    function close()  { popup.visible = false; }
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

        implicitWidth: row.implicitWidth + 16
        implicitHeight: row.implicitHeight + 16

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            // ============================================================
            // Inline button component — round pill with icon + label.
            // ============================================================
            component PowerButton: MouseArea {
                id: btn
                property string label
                property var iconDraw            // Component drawing the icon
                property var onActivate            // function to call

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

                        // Icon drawn via the supplied Component
                        Loader {
                            anchors.centerIn: parent
                            sourceComponent: btn.iconDraw
                            // Pass `iconColor` through; the icon component can
                            // bind to it for hover-flip readability.
                            property color iconColor:
                                btn.containsMouse ? Theme.bg : Theme.text
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: btn.label
                        color: Theme.textDim
                        font.pixelSize: 10
                    }
                }
            }

            // ============================================================
            // Per-icon Components — each draws on a 20×20 canvas.
            // ============================================================

            // Padlock — closed shackle + body
            Component {
                id: lockIcon
                Item {
                    id: lockGlyph
                    width: 20; height: 20
                    readonly property color c: parent ? parent.iconColor : Theme.text

                    Shape {
                        anchors.fill: parent
                        antialiasing: true
                        layer.enabled: true
                        layer.samples: 4

                        ShapePath {
                            strokeColor: lockGlyph.c
                            strokeWidth: 1.6
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            startX: 6;  startY: 9
                            PathLine { x: 6; y: 6 }
                            PathArc { x: 14; y: 6; radiusX: 4; radiusY: 4; direction: PathArc.Clockwise }
                            PathLine { x: 14; y: 9 }
                        }
                    }
                    Rectangle {
                        x: 4; y: 9
                        width: 12; height: 9
                        radius: 2
                        color: lockGlyph.c
                    }
                }
            }

            // Suspend — crescent moon
            Component {
                id: suspendIcon
                Item {
                    id: suspendGlyph
                    width: 20; height: 20
                    readonly property color c: parent ? parent.iconColor : Theme.text

                    Shape {
                        anchors.fill: parent
                        antialiasing: true
                        layer.enabled: true
                        layer.samples: 4

                        ShapePath {
                            strokeColor: suspendGlyph.c
                            strokeWidth: 1.6
                            fillColor: suspendGlyph.c
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin

                            startX: 14; startY: 4
                            PathArc { x: 14; y: 16; radiusX: 7; radiusY: 7; direction: PathArc.Counterclockwise }
                            PathArc { x: 14; y: 4;  radiusX: 5; radiusY: 5; direction: PathArc.Clockwise }
                        }
                    }
                }
            }

            // Logout — door with arrow pointing right
            Component {
                id: logoutIcon
                Item {
                    id: logoutGlyph
                    width: 20; height: 20
                    readonly property color c: parent ? parent.iconColor : Theme.text

                    Shape {
                        anchors.fill: parent
                        antialiasing: true
                        layer.enabled: true
                        layer.samples: 4

                        ShapePath {
                            strokeColor: logoutGlyph.c
                            strokeWidth: 1.6
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin

                            startX: 9; startY: 3
                            PathLine { x: 3; y: 3 }
                            PathLine { x: 3; y: 17 }
                            PathLine { x: 9; y: 17 }
                        }

                        ShapePath {
                            strokeColor: logoutGlyph.c
                            strokeWidth: 1.6
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            startX: 8; startY: 10
                            PathLine { x: 17; y: 10 }
                        }
                        ShapePath {
                            strokeColor: logoutGlyph.c
                            strokeWidth: 1.6
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin

                            startX: 13; startY: 6
                            PathLine { x: 17; y: 10 }
                            PathLine { x: 13; y: 14 }
                        }
                    }
                }
            }

            // Reboot — circular arrow
            Component {
                id: rebootIcon
                Item {
                    id: rebootGlyph
                    width: 20; height: 20
                    readonly property color c: parent ? parent.iconColor : Theme.text

                    Shape {
                        anchors.fill: parent
                        antialiasing: true
                        layer.enabled: true
                        layer.samples: 4

                        ShapePath {
                            strokeColor: rebootGlyph.c
                            strokeWidth: 1.6
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            startX: 13; startY: 3
                            PathArc {
                                x: 13; y: 17
                                radiusX: 7; radiusY: 7
                                direction: PathArc.Counterclockwise
                                useLargeArc: true
                            }
                        }

                        ShapePath {
                            strokeColor: rebootGlyph.c
                            strokeWidth: 1.6
                            fillColor: rebootGlyph.c
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin

                            startX: 13; startY: 3
                            PathLine { x: 9;  y: 1 }
                            PathLine { x: 11; y: 6 }
                            PathLine { x: 13; y: 3 }
                        }
                    }
                }
            }

            // Shutdown — power symbol (broken circle + vertical line)
            Component {
                id: shutdownIcon
                Item {
                    id: shutdownGlyph
                    width: 20; height: 20
                    readonly property color c: parent ? parent.iconColor : Theme.text

                    Shape {
                        anchors.fill: parent
                        antialiasing: true
                        layer.enabled: true
                        layer.samples: 4

                        ShapePath {
                            strokeColor: shutdownGlyph.c
                            strokeWidth: 1.6
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            startX: 6; startY: 5
                            PathArc {
                                x: 14; y: 5
                                radiusX: 7; radiusY: 7
                                direction: PathArc.Clockwise
                                useLargeArc: true
                            }
                        }

                        ShapePath {
                            strokeColor: shutdownGlyph.c
                            strokeWidth: 1.8
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            startX: 10; startY: 2
                            PathLine { x: 10; y: 10 }
                        }
                    }
                }
            }

            // ============================================================
            // The five buttons.
            // ============================================================
            PowerButton {
                label: "Lock"
                iconDraw: lockIcon
                onActivate: () => popup._run(["loginctl", "lock-session"])
            }
            PowerButton {
                label: "Suspend"
                iconDraw: suspendIcon
                onActivate: () => popup._run(["systemctl", "suspend"])
            }
            PowerButton {
                label: "Logout"
                iconDraw: logoutIcon
                onActivate: () => popup._run(["niri", "msg", "action", "quit"])
            }
            PowerButton {
                label: "Reboot"
                iconDraw: rebootIcon
                onActivate: () => popup._run(["systemctl", "reboot"])
            }
            PowerButton {
                label: "Shutdown"
                iconDraw: shutdownIcon
                onActivate: () => popup._run(["systemctl", "poweroff"])
            }
        }
    }
}
