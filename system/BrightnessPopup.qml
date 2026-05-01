// BrightnessPopup.qml
// Single-section slider for backlight brightness. Mirrors VolumePopup's
// output-section visual but without the device list — there's only one
// backlight target on most systems.

import QtQuick
import QtQuick.Effects
import Quickshell
import qs
import qs.osd

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
    function close() { popup.wantOpen = false; }
    onVisibleChanged: if (!visible) PopupController.closed(popup)

    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? -((popup.width - anchorItem.width) / 2) : 0
    anchor.rect.y: anchorItem ? anchorItem.height + 6 - 12 : 0
    anchor.adjustment: PopupAdjustment.SlideX

    implicitWidth: 280 + 24
    implicitHeight: contentColumn.implicitHeight + 16 + 24

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
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

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
            shadowBlur: 0.6
        }

        Column {
            id: contentColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 10
            }
            spacing: 8

            // Section header
            Text {
                text: "BRIGHTNESS"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
            }

            // Slider row: [sun glyph] [slider] [percentage]
            Row {
                width: parent.width
                spacing: 8

                BarIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "\uf185"
                    glyphSize: 14
                }

                Slider {
                    id: brightnessSlider
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 20 - pctText.width - parent.spacing * 2
                    value: OsdService.brightnessRatio
                    enabled: OsdService.hasBrightness
                    onUserChanged: v => OsdService.setBrightness(v)
                }

                Text {
                    id: pctText
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(OsdService.brightnessRatio * 100) + "%"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }
}
