// Slider.qml
// Interactive horizontal slider used by VolumePopup and MediaPopup.
//
// 4 px track + 12 px round thumb. Drag or click-to-seek; supports a wheel
// step. Bind `value` (0..1) and listen on `userChanged` (emitted whenever
// the user drags / clicks / wheels — not when the binding is updated
// from outside).
//
// Visuals
//   ────────●──────────────       4 px track, accent thumb
//
// Two state hooks:
//   - `dimmed`: paints the fill in `Theme.textMuted` (e.g. when muted)
//   - `enabled`: false → cursor stays as ArrowCursor and clicks no-op

import QtQuick
import qs

Item {
    id: root

    // 0..1 — bind to your model property; we don't write back to it,
    // consumers handle changes via `userChanged(newValue)`.
    property real value: 0
    // Wheel adjusts the value by ±wheelStep (default 5%).
    property real wheelStep: 0.05
    // When true, fill renders dimmed (mute / disabled feel).
    property bool dimmed: false
    // Hide the thumb when not interactive (e.g. media is not seekable).
    property bool showThumb: true

    signal userChanged(real newValue)

    // Standard sizing — height accommodates the thumb.
    implicitHeight: 18
    implicitWidth: 160

    function _commit(x) {
        if (!enabled) return;
        const v = Math.max(0, Math.min(1, x / track.width));
        userChanged(v);
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: 4
        radius: 2
        color: Theme.surfaceHi

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(1, root.value))
            radius: parent.radius
            color: root.dimmed ? Theme.textMuted : Theme.text
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }

    Rectangle {
        id: thumb
        anchors.verticalCenter: track.verticalCenter
        x: track.width * Math.max(0, Math.min(1, root.value)) - width / 2
        width: 12
        height: 12
        radius: 6
        color: Theme.accent
        border.color: Theme.bg
        border.width: 1
        visible: root.showThumb && root.enabled
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4   // expand hit area vertically
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled

        onPressed: mouse => root._commit(mouse.x)
        onPositionChanged: mouse => { if (pressed) root._commit(mouse.x); }
        onWheel: wheel => {
            if (!root.enabled) return;
            const delta = wheel.angleDelta.y > 0 ? root.wheelStep : -root.wheelStep;
            root.userChanged(Math.max(0, Math.min(1, root.value + delta)));
        }
    }
}
