// ActiveWindow.qml
// Bar widget showing the focused window's title.
//
// Reads ToplevelManager from Quickshell.Wayland rather than going through
// Compositor.*. That is deliberate: the compositor abstraction's
// windowFocused(id) signal carries an opaque id and nothing else, and
// widening it would mean touching all four backends for data the
// wlr-foreign-toplevel protocol already exposes compositor-agnostically.
// No backend-specific API is referenced here, so the abstraction rule
// ("never reference Hyprland.*/I3.*/niri outside compositor/Backend*.qml")
// is respected.
//
// Sizing: unlike every other bar widget this one has no natural width --
// a title can be arbitrarily long. The parent is expected to anchor both
// left and right to bound the available space (see Bar.qml, where it is
// pinned between the workspaces and the centred clock); the label then
// elides inside whatever is left over. It is the first bar widget to
// elide, and elide is a no-op on an unbounded Text, so that bound matters.

import QtQuick
import Quickshell.Wayland
import qs

Item {
    id: root

    // Width comes from the parent's anchors; only the height is intrinsic.
    implicitHeight: 22

    readonly property bool enabled: Local.get("activeWindowEnabled", true)
    readonly property int maxWidth: Local.get("activeWindowMaxWidth", 400)

    // Fall back to appId: some clients (file dialogs, splash windows) set
    // no title at all, and showing nothing there looks like a bug.
    readonly property string title: {
        const t = ToplevelManager.activeToplevel;
        if (!t)
            return "";
        const name = (t.title || "").trim();
        if (name.length > 0)
            return name;
        return (t.appId || "").trim();
    }

    visible: root.enabled && root.title.length > 0

    // Measured off-screen so the pill can size itself without the label's
    // width feeding back into it. Binding Text.implicitWidth into a width
    // that then constrains the same Text is the kind of loop that is easy
    // to introduce here.
    TextMetrics {
        id: metrics
        font: label.font
        text: root.title
    }

    readonly property int available: Math.max(0, Math.min(root.width, root.maxWidth))
    readonly property bool elided: metrics.width + 10 > root.available

    Item {
        id: pill
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(metrics.width + 10, root.available)
        height: 22

        // Titles change on every focus switch; animating the width keeps
        // that from snapping.
        Behavior on width {
            NumberAnimation {
                duration: Theme.animMed
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: hover.containsMouse ? Theme.surface : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Text {
            id: label
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 10
            text: root.title
            elide: Text.ElideRight
            color: hover.containsMouse ? Theme.text : Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeNormal
            renderType: Text.NativeRendering
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor
        }
    }

    // Only worth a tooltip when the text is actually cut off.
    BarTooltip {
        anchorItem: pill
        show: hover.containsMouse && root.elided
        text: root.title
    }
}
