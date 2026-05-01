// Workspaces.qml
// Renders a horizontal row of numbered chips for one output (monitor).
// Each chip is a 22 × 22 square with the workspace index in the shell's
// mono font; the focused workspace gets the accent fill, the active one
// gets a subtle elevated background, and idle ones sit dim on transparent.
//
//   Click a chip -> niri focus-workspace <idx>

import QtQuick
import Quickshell
import qs

Row {
    id: root

    required property var niri      // Niri service instance
    required property string output // monitor name, e.g. "DP-1"

    spacing: 4

    Repeater {
        // Read niri.workspaces directly so the binding tracks it.
        model: {
            if (!root.niri || !root.output) return [];
            return root.niri.workspaces
                .filter(w => w.output === root.output)
                .slice()
                .sort((a, b) => a.idx - b.idx);
        }

        delegate: MouseArea {
            id: chip
            required property var modelData

            readonly property bool focused: modelData.is_focused
            readonly property bool active: modelData.is_active

            implicitWidth: 22
            implicitHeight: 22
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(
                ["niri", "msg", "action", "focus-workspace", String(modelData.idx)]
            )

            // Chip background. Three resting states (focused / active / idle)
            // plus a hover overlay on idle chips.
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: chip.focused
                    ? Theme.accent
                    : chip.active
                        ? Theme.surfaceHi
                        : (chip.containsMouse ? Theme.surface : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.animMed } }
            }

            // Number label — always visible, mono, weight bumps on focus.
            Text {
                anchors.centerIn: parent
                text: chip.modelData.idx
                color: chip.focused ? Theme.accentText : Theme.text
                opacity: chip.focused ? 1.0 : (chip.active ? 0.95 : 0.55)
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeNormal
                font.weight: chip.focused ? Font.Bold : Font.Medium
                Behavior on color   { ColorAnimation  { duration: Theme.animMed } }
                Behavior on opacity { NumberAnimation { duration: Theme.animMed } }
            }

            // Tooltip — workspace name if niri set one, else "Workspace N".
            BarTooltip {
                anchorItem: chip
                show: chip.containsMouse
                text: {
                    const n = chip.modelData.name;
                    if (n && n.length > 0) return n;
                    return "Workspace " + chip.modelData.idx;
                }
            }
        }
    }
}
