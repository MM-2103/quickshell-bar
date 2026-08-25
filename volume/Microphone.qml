// Microphone.qml
// Bar indicator for the default audio source.
//   Left / Middle -> mute/unmute
//   Wheel         -> +/- 5% input gain
//
// Visibility is conditional by default, unlike the Volume widget next to
// it. A mic icon that is always present is noise -- the state that matters
// is "muted" or "something is listening". In `auto` mode this doubles as a
// privacy indicator: it appears whenever any application holds a capture
// stream, whether or not that application tells you.
//
// It sits to the LEFT of Volume in the bar so that Volume, which is always
// present, doesn't shift sideways when this one appears and disappears.

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs

MouseArea {
    id: root

    // "auto" (default) | "always" | "never"
    readonly property string mode: Local.get("microphoneIndicator", "auto")

    readonly property var source: Pipewire.defaultAudioSource
    readonly property real volume: source && source.audio ? source.audio.volume : 0
    readonly property bool muted:  source && source.audio ? source.audio.muted  : false

    // Any application currently capturing. The playback equivalent of this
    // filter lives in VolumePopup; media.class is used rather than isSink
    // because the meaning of isSink for streams varies.
    readonly property bool capturing: {
        const all = Pipewire.nodes.values;
        for (let i = 0; i < all.length; i++) {
            const n = all[i];
            if (!n || !n.audio || !n.isStream) continue;
            const cls = (n.properties && n.properties["media.class"]) || "";
            if (cls === "Stream/Input/Audio") return true;
        }
        return false;
    }

    visible: {
        if (!root.source) return false;          // no mic at all
        if (root.mode === "never") return false;
        if (root.mode === "always") return true;
        return root.muted || root.capturing;
    }

    implicitWidth: visible ? 22 : 0
    implicitHeight: 22
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    // Required so source.audio.volume / muted are valid. The Volume widget
    // tracks the same objects; trackers are additive, not exclusive.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSource]
    }

    function toggleMute() {
        if (root.source && root.source.audio)
            root.source.audio.muted = !root.source.audio.muted;
    }

    // Both buttons do the same thing here. There is no popup to open --
    // input devices and gain live in the Control Center's Input section --
    // so a left click has nothing better to do than mute.
    onClicked: root.toggleMute()

    onWheel: wheel => {
        if (!root.source || !root.source.audio) return;
        const step = 0.05;
        const delta = wheel.angleDelta.y > 0 ? step : -step;
        root.source.audio.volume =
            Math.max(0, Math.min(1, root.source.audio.volume + delta));
    }

    // Hover background
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: root.containsMouse ? Theme.surface : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // \uf130 microphone / \uf131 microphone-slash
    BarIcon {
        anchors.centerIn: parent
        glyph: root.muted ? "\uf131" : "\uf130"
        opacity: root.muted ? 0.55 : 1.0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    BarTooltip {
        anchorItem: root
        show: root.containsMouse
        text: {
            if (root.muted) return "Microphone muted";
            const pct = Math.round(root.volume * 100) + "%";
            return root.capturing
                ? ("Microphone in use · " + pct)
                : ("Microphone " + pct);
        }
    }
}
