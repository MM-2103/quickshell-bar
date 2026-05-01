// VolumePopup.qml
// Plasma-style volume mixer popup. Two sections:
//   - Output: slider + mute toggle + selectable list of audio sinks
//   - Input:  slider + mute toggle + selectable list of audio sources
// Default device is changed by writing Pipewire.preferredDefaultAudioSink/Source.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs

PopupWindow {
    id: popup

    required property Item anchorItem

    color: "transparent"

    // Fade-aware visibility: the inner Rectangle's opacity drives the
    // animation, the window stays mapped briefly during fade-out via
    // the `hideHold` Timer.
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

    // Anchored under the bar icon, horizontally centered.
    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? -((popup.width - anchorItem.width) / 2) : 0
    // Y compensates for the 12 px shadow padding.
    anchor.rect.y: anchorItem ? anchorItem.height + 6 - 12 : 0
    anchor.adjustment: PopupAdjustment.SlideX

    // Surface grows by 24 px in each axis to leave shadow padding around
    // the visible body.
    implicitWidth: 320 + 24
    implicitHeight: contentColumn.implicitHeight + 16 + 24

    // Track defaults so .audio.volume / .muted are valid.
    // Tracking includes the default sink/source plus every app stream so
    // their `properties` (application.name / application.icon-name / etc.)
    // are populated. Without tracking, those property maps come back empty.
    PwObjectTracker {
        objects: {
            const out = [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource];
            const all = Pipewire.nodes.values;
            for (let i = 0; i < all.length; i++) {
                const n = all[i];
                if (n && n.audio && n.isStream) out.push(n);
            }
            return out;
        }
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

    // App streams that produce audio (i.e. sink-input streams). Filter via
    // media.class because the meaning of `isSink` for streams varies; the
    // class string is unambiguous: "Stream/Output/Audio" = app -> sink.
    readonly property var audioStreams: {
        const list = [];
        const all = Pipewire.nodes.values;
        for (let i = 0; i < all.length; i++) {
            const n = all[i];
            if (!n || !n.audio || !n.isStream) continue;
            const cls = (n.properties && n.properties["media.class"]) || "";
            if (cls === "Stream/Output/Audio") list.push(n);
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

            // Slider — shared component (4 px track + 12 px thumb).
            Slider {
                id: volSlider
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - muteBtn.width - pctText.width - sliderRow.spacing * 2
                value: section.node && section.node.audio ? section.node.audio.volume : 0
                dimmed: section.node && section.node.audio && section.node.audio.muted
                enabled: section.node && section.node.audio
                onUserChanged: v => {
                    if (section.node && section.node.audio) section.node.audio.volume = v;
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
        anchors.margins: 12
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

            // ---- Per-app streams section ----
            //
            // Visible only when at least one app is producing audio. Each
            // row: app icon (click to mute) + app name + slider + %.

            Rectangle {
                visible: popup.audioStreams.length > 0
                width: parent.width
                height: 1
                color: Theme.border
            }

            Column {
                id: appsSection
                visible: popup.audioStreams.length > 0
                width: parent.width
                spacing: 6

                Text {
                    text: "APPS"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                }

                Repeater {
                    model: popup.audioStreams
                    delegate: AppStreamRow {
                        required property var modelData
                        stream: modelData
                        width: appsSection.width
                    }
                }
            }
        }
    }

    // ================================================================
    // Inline component: a single per-app stream row.
    // ================================================================
    component AppStreamRow: Row {
        id: appRow
        required property var stream

        height: 30
        spacing: 8

        function _appName() {
            if (!stream || !stream.properties) return "?";
            return stream.properties["application.name"]
                || stream.properties["node.name"]
                || (stream.description || "")
                || "Unknown app";
        }

        function _appIconName() {
            if (!stream || !stream.properties) return "";
            return stream.properties["application.icon-name"] || "";
        }

        readonly property bool _muted:
            stream && stream.audio && stream.audio.muted

        // Icon / mute toggle (click to mute).
        MouseArea {
            id: iconMa
            anchors.verticalCenter: parent.verticalCenter
            width: 24; height: 24
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (appRow.stream && appRow.stream.audio) {
                    appRow.stream.audio.muted = !appRow.stream.audio.muted;
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: iconMa.containsMouse ? Theme.surfaceHi : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            // App icon resolved via XDG icon theme.
            IconImage {
                id: appIcon
                anchors.centerIn: parent
                implicitSize: 16
                source: appRow._appIconName() !== ""
                    ? Quickshell.iconPath(appRow._appIconName(), true)
                    : ""
                asynchronous: true
                visible: source !== "" && status === Image.Ready
                opacity: appRow._muted ? 0.45 : 1.0
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            }

            // Letter fallback when no icon.
            Text {
                anchors.centerIn: parent
                visible: !appIcon.visible
                text: appRow._appName().charAt(0).toUpperCase()
                color: appRow._muted ? Theme.textMuted : Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
            }
        }

        // App name + slider stacked.
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 24 - parent.spacing - 36 - parent.spacing
            spacing: 1

            Text {
                width: parent.width
                text: appRow._appName()
                color: appRow._muted ? Theme.textDim : Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }

            Slider {
                width: parent.width
                value: appRow.stream && appRow.stream.audio
                    ? appRow.stream.audio.volume : 0
                dimmed: appRow._muted
                enabled: appRow.stream && appRow.stream.audio
                onUserChanged: v => {
                    if (appRow.stream && appRow.stream.audio)
                        appRow.stream.audio.volume = v;
                }
            }
        }

        // Percentage readout.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            horizontalAlignment: Text.AlignRight
            text: Math.round((appRow.stream && appRow.stream.audio
                ? appRow.stream.audio.volume : 0) * 100) + "%"
            color: Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeBadge
        }
    }
}
