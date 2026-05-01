// Workspaces.qml
// Renders a horizontal row of numbered chips for one output (monitor).
// Each chip is a 22 × 22 square with the workspace index in the shell's
// mono font; the focused workspace gets the accent fill, the active one
// gets a subtle elevated background, and idle ones sit dim on transparent.
//
//   Click a chip -> Compositor.dispatchFocusWorkspace(idx)

import QtQuick
import Quickshell
import qs
import qs.compositor

Row {
    id: root

    required property string output // monitor name, e.g. "DP-1"

    spacing: 4

    Repeater {
        // Read Compositor.workspaces directly so the binding tracks it.
        model: {
            if (!root.output) return [];
            // workspaces with a numeric idx sort numerically; named-only
            // workspaces (idx is a string, e.g. Hyprland special) keep
            // their incoming order via stable sort.
            return Compositor.workspaces
                .filter(w => w.output === root.output)
                .slice()
                .sort((a, b) => {
                    const an = (typeof a.idx === "number") ? a.idx : 0;
                    const bn = (typeof b.idx === "number") ? b.idx : 0;
                    return an - bn;
                });
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
            onClicked: Compositor.dispatchFocusWorkspace(modelData.idx)

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

            // Tooltip — workspace name if the compositor set one, else
            // a generic "Workspace N" label using the idx.
            BarTooltip {
                anchorItem: chip
                show: chip.containsMouse
                text: {
                    const n = chip.modelData.name;
                    if (n && n.length > 0 && n !== String(chip.modelData.idx))
                        return n;
                    return "Workspace " + chip.modelData.idx;
                }
            }
        }
    }
}
