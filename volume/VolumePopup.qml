// VolumePopup.qml
// Plasma-style volume mixer popup. Two sections:
//   - Output: slider + mute toggle + selectable list of audio sinks
//   - Input:  slider + mute toggle + selectable list of audio sources
// Default device is changed by writing Pipewire.preferredDefaultAudioSink/Source.

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs

PopupWindow {
    id: popup

    required property Item anchorItem

    visible: false
    color: "transparent"

    function toggle() {
        if (popup.visible) {
            popup.visible = false;
        } else {
            PopupController.open(popup, () => popup.visible = false);
            popup.visible = true;
        }
    }
    function close() { popup.visible = false; }
    onVisibleChanged: if (!visible) PopupController.closed(popup)

    // Anchored under the bar icon, horizontally centered.
    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? -((popup.width - anchorItem.width) / 2) : 0
    anchor.rect.y: anchorItem ? anchorItem.height + 6 : 0
    anchor.adjustment: PopupAdjustment.SlideX

    implicitWidth: 320
    implicitHeight: contentColumn.implicitHeight + 16

    // Track defaults so .audio.volume / .muted are valid.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource

    readonly property var audioOutputs: {
        const list = [];
        const all = Pipewire.nodes.values;
        for (let i = 0; i < all.length; i++) {
            const n = all[i];
            if (n && n.audio && n.isSink && !n.isStream) list.push(n);
        }
        return list;
    }

    readonly property var audioInputs: {
        const list = [];
        const all = Pipewire.nodes.values;
        for (let i = 0; i < all.length; i++) {
            const n = all[i];
            if (n && n.audio && !n.isSink && !n.isStream) list.push(n);
        }
        return list;
    }

    // ================================================================
    // Inline component: a labeled slider + mute toggle + device list.
    // ================================================================
    component VolumeSection: Column {
        id: section

        required property string title
        required property var node              // current default PwNode (sink or source)
        required property var devices           // array of candidate PwNodes
        // emitted when user picks a device from the list
        signal deviceSelected(var dev)

        spacing: 6

        // Section header
        Text {
            text: section.title
            color: Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
        }

        // Slider row: [mute btn] [track] [percentage]
        Row {
            id: sliderRow
            width: section.width
            spacing: 8

            // Mute toggle
            Rectangle {
                id: muteBtn
                width: 24
                height: 24
                radius: Theme.radiusSmall
                color: muteMa.containsMouse ? Theme.surfaceHi : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    // Font Awesome 7 Solid: \uf6a9 volume-xmark / \uf028 volume-high
                    text: section.node && section.node.audio && section.node.audio.muted
                        ? "\uf6a9" : "\uf028"
                    color: Theme.text
                    font.family: Theme.fontIcon
                    font.styleName: "Solid"
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: muteMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (section.node && section.node.audio) {
                            section.node.audio.muted = !section.node.audio.muted;
                        }
                    }
                }
            }

            // Slider
            Item {
                id: sliderHolder
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - muteBtn.width - pctText.width - sliderRow.spacing * 2
                height: 24

                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Theme.surfaceHi

                    Rectangle {
                        id: fill
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        width: parent.width * Math.max(0, Math.min(1, section.node && section.node.audio ? section.node.audio.volume : 0))
                        radius: parent.radius
                        color: section.node && section.node.audio && section.node.audio.muted
                            ? Theme.textMuted
                            : Theme.text
                    }
                }

                Rectangle {
                    id: thumb
                    anchors.verticalCenter: track.verticalCenter
                    x: track.width * Math.max(0, Math.min(1, section.node && section.node.audio ? section.node.audio.volume : 0)) - width / 2
                    width: 12
                    height: 12
                    radius: 6
                    color: Theme.accent
                    border.color: Theme.bg
                    border.width: 1
                    visible: section.node && section.node.audio
                }

                MouseArea {
                    id: sliderMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    function setFromX(x) {
                        if (!(section.node && section.node.audio)) return;
                        const v = Math.max(0, Math.min(1, x / track.width));
                        section.node.audio.volume = v;
                    }

                    onPressed: mouse => setFromX(mouse.x)
                    onPositionChanged: mouse => { if (pressed) setFromX(mouse.x); }

                    onWheel: wheel => {
                        if (!(section.node && section.node.audio)) return;
                        const step = 0.05;
                        const delta = wheel.angleDelta.y > 0 ? step : -step;
                        section.node.audio.volume = Math.max(0, Math.min(1, section.node.audio.volume + delta));
                    }
                }
            }

            Text {
                id: pctText
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                horizontalAlignment: Text.AlignRight
                text: Math.round((section.node && section.node.audio ? section.node.audio.volume : 0) * 100) + "%"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        // Device list
        Column {
            width: section.width
            spacing: 1
            visible: section.devices.length > 0

            Repeater {
                model: section.devices

                delegate: Rectangle {
                    id: deviceRow
                    required property var modelData
                    width: section.width
                    height: 26
                    radius: Theme.radiusSmall
                    color: deviceMa.containsMouse ? Theme.surfaceHi : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    readonly property bool isCurrent: modelData === section.node

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 6

                        // Indicator dot
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10
                            height: 10
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: width / 2
                                color: deviceRow.isCurrent ? Theme.accent : "transparent"
                                border.color: Theme.textDim
                                border.width: deviceRow.isCurrent ? 0 : 1
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 22
                            text: deviceRow.modelData
                                ? (deviceRow.modelData.description
                                    || deviceRow.modelData.nickname
                                    || deviceRow.modelData.name
                                    || "(unknown)")
                                : ""
                            color: deviceRow.isCurrent ? Theme.text : Theme.textDim
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: deviceRow.isCurrent ? Font.Bold : Font.Normal
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: deviceMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: section.deviceSelected(deviceRow.modelData)
                    }
                }
            }
        }
    }

    // ================================================================
    // Layout
    // ================================================================
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

        Column {
            id: contentColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 10
            }
            spacing: 10

            VolumeSection {
                width: parent.width
                title: "OUTPUT"
                node: popup.defaultSink
                devices: popup.audioOutputs
                onDeviceSelected: dev => Pipewire.preferredDefaultAudioSink = dev
            }

            // Separator
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            VolumeSection {
                width: parent.width
                title: "INPUT"
                node: popup.defaultSource
                devices: popup.audioInputs
                onDeviceSelected: dev => Pipewire.preferredDefaultAudioSource = dev
            }
        }
    }
}
