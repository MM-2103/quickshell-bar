// Volume.qml
// Bar icon for the audio mixer.
//   Left  -> toggle the volume popup
//   Middle-> mute/unmute default sink
//   Wheel -> +/- 5% volume on default sink

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
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

    function _glyph() {
        // Font Awesome 7 Solid:
        //   \uf6a9 volume-xmark (muted / 0 %)
        //   \uf027 volume-low   (<50 %)
        //   \uf028 volume-high  (≥50 %)
        if (root.muted || root.volume <= 0.001) return "\uf6a9";
        if (root.volume < 0.5) return "\uf027";
        return "\uf028";
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

    // Volume glyph — Font Awesome 7 Solid, swaps with mute / level state.
    // Muted gets dimmed slightly so the bar reads "off" at a glance.
    BarIcon {
        anchors.centerIn: parent
        glyph: root._glyph()
        opacity: root.muted ? 0.55 : 1.0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    BarTooltip {
        anchorItem: root
        show: root.containsMouse && !popup.visible
        text: root.muted
            ? "Muted"
            : ("Volume " + Math.round(root.volume * 100) + "%")
    }

    VolumePopup {
        id: popup
        anchorItem: root
    }
}
