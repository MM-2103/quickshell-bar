// Volume.qml
// Bar icon for the audio mixer.
//   Left  -> toggle the volume popup
//   Middle-> mute/unmute default sink
//   Wheel -> +/- 5% volume on default sink

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs

MouseArea {
    id: root

    implicitWidth: 22
    implicitHeight: 22
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    // Required so sink.audio.volume / muted are valid.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    function _iconName() {
        if (root.muted || root.volume <= 0.001) return "audio-volume-muted-symbolic";
        if (root.volume < 0.34) return "audio-volume-low-symbolic";
        if (root.volume < 0.67) return "audio-volume-medium-symbolic";
        return "audio-volume-high-symbolic";
    }

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
            popup.toggle();
        } else if (mouse.button === Qt.MiddleButton) {
            if (root.sink && root.sink.audio) {
                root.sink.audio.muted = !root.sink.audio.muted;
            }
        }
    }

    onWheel: wheel => {
        if (!root.sink || !root.sink.audio) return;
        const step = 0.05;
        const delta = wheel.angleDelta.y > 0 ? step : -step;
        root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + delta));
    }

    // Hover background
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: popup.visible
            ? Theme.surfaceHi
            : (root.containsMouse ? Theme.surface : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // Theme icon (with text fallback if missing)
    Item {
        anchors.centerIn: parent
        width: 16
        height: 16

        IconImage {
            id: vIcon
            anchors.fill: parent
            implicitSize: 16
            source: Quickshell.iconPath(root._iconName(), true)
            asynchronous: false
            visible: status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: vIcon.status !== Image.Ready
            text: root.muted ? "x" : "♪"
            color: Theme.text
            font.pixelSize: 11
            font.bold: true
        }
    }

    VolumePopup {
        id: popup
        anchorItem: root
    }
}
