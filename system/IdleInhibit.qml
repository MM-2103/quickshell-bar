// IdleInhibit.qml
// Toggle to keep the system from sleeping / locking.
// Implementation: long-running `systemd-inhibit ... sleep infinity` Process.
// Visual: a coffee cup. Outline-only when inactive; filled with steam when active.
//
// Scope: covers logind-managed sleep and lid-close handling. Does NOT
// suppress compositor screen blanking / DPMS (those use the Wayland
// idle-inhibit-v1 protocol, which Quickshell doesn't expose).

import QtQuick
import Quickshell
import Quickshell.Io
import qs

MouseArea {
    id: root

    implicitWidth: 22
    implicitHeight: 22
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    property bool active: false

    onClicked: root.active = !root.active

    Process {
        running: root.active
        command: [
            "systemd-inhibit",
            "--what=idle:sleep:handle-lid-switch",
            "--who=quickshell-bar",
            "--why=user requested always-on",
            "--mode=block",
            "sleep", "infinity"
        ]
    }

    // Hover / active background pill
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: root.active
            ? (root.containsMouse ? Theme.surface : Theme.surfaceHi)
            : (root.containsMouse ? Theme.surface : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // Coffee cup glyph — Font Awesome 7 Solid.
    //   Inactive: \uf0f4 mug-saucer (cup on saucer, no steam)
    //   Active:   \uf7b6 mug-hot    (cup with rising steam — the active
    //                                metaphor for "stay awake" is baked
    //                                straight into the glyph).
    BarIcon {
        anchors.centerIn: parent
        glyph: root.active ? "\uf7b6" : "\uf0f4"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    BarTooltip {
        anchorItem: root
        show: root.containsMouse
        text: root.active
            ? "Keep system awake: ON"
            : "Keep system awake: OFF"
    }
}
