// ProgressBar.qml
// Passive horizontal progress fill — no thumb, no interaction. Used by
// the OSDs and any other "ratio readout" widget.
//
// Bind `value` (0..1). `dimmed` paints the fill in Theme.textMuted (mute
// state), `low` swaps to Theme.error when value falls below `lowAt` (e.g.
// battery <20%). The track is always Theme.surfaceHi.

import QtQuick
import qs

Item {
    id: root

    property real value: 0
    property bool dimmed: false
    // Threshold below which the fill switches to `Theme.error`.
    // Set to a non-positive value to disable the low-state coloring.
    property real lowAt: 0
    // Track height. Height of the Item adapts.
    property int trackHeight: 4

    implicitHeight: trackHeight
    implicitWidth: 160

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surfaceHi

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(1, root.value))
            radius: parent.radius
            color: root.dimmed
                ? Theme.textMuted
                : (root.lowAt > 0 && root.value <= root.lowAt
                    ? Theme.error
                    : Theme.text)
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }
}
