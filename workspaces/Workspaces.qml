// Workspaces.qml
// Renders a horizontal row of workspace pips for one output (monitor).
// Highlights the focused workspace and shows the active one slightly larger.

import QtQuick
import qs

Row {
    id: root

    required property var niri      // Niri service instance
    required property string output // monitor name, e.g. "DP-1"

    spacing: 6

    Repeater {
        // Read niri.workspaces directly so the binding tracks it.
        model: {
            if (!root.niri || !root.output) return [];
            return root.niri.workspaces
                .filter(w => w.output === root.output)
                .slice()
                .sort((a, b) => a.idx - b.idx);
        }

        delegate: Rectangle {
            id: pip
            required property var modelData

            readonly property bool focused: modelData.is_focused
            readonly property bool active: modelData.is_active

            width: focused ? 26 : (active ? 16 : 12)
            height: 12
            radius: 6
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

            color: focused
                ? Theme.pipFocused
                : (active ? Theme.pipActive : Theme.pipIdle)
            border.color: Theme.border
            border.width: 1

            Behavior on width { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }
            Behavior on color { ColorAnimation { duration: Theme.animMed } }

            Text {
                anchors.centerIn: parent
                visible: pip.width >= 18
                text: pip.modelData.idx
                color: pip.focused ? Theme.accentText : Theme.text
                font.pixelSize: 9
                font.bold: pip.focused
            }
        }
    }
}
