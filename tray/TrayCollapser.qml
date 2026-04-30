// TrayCollapser.qml
// Wraps the Tray widget with a chevron toggle so the icons can be hidden
// behind a single small button when there are several of them.
//
// Behavior based on tray item count:
//   0 items  -> entire component is hidden
//   1 item   -> show the single icon inline; no chevron
//   2+ items -> show a chevron; clicking it slides the icons out / in.
//               Default state when entering this mode: collapsed.

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs

Row {
    id: root

    // Don't render anything when there are no tray items.
    visible: SystemTray.items.values.length > 0
    spacing: 6

    // True when we should show the chevron toggle (2+ items).
    readonly property bool useCollapser: SystemTray.items.values.length > 1

    property bool expanded: false

    // If we drop from 2+ items to 1 (or 0), the expanded flag is irrelevant.
    // Reset it so we re-enter the multi-item case in the collapsed state.
    onUseCollapserChanged: {
        if (!useCollapser) expanded = false;
    }

    // Tray container. When in collapser mode, this is a clipping window whose
    // width animates between 0 and the natural tray width. Otherwise it just
    // sizes to fit.
    Item {
        id: trayClip
        anchors.verticalCenter: parent.verticalCenter
        clip: root.useCollapser
        height: tray.implicitHeight
        width: root.useCollapser
            ? (root.expanded ? tray.implicitWidth : 0)
            : tray.implicitWidth

        Behavior on width {
            enabled: root.useCollapser
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }

        // Single Tray instance, right-anchored so icons appear to slide
        // out from behind the chevron rather than from the left.
        Tray {
            id: tray
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Chevron toggle (only present in the 2+ items case).
    MouseArea {
        id: chevron
        visible: root.useCollapser
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 18
        implicitHeight: 22
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = !root.expanded

        // Hover/active background pill (consistent with other widgets).
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: root.expanded
                ? (chevron.containsMouse ? Theme.surface : Theme.surfaceHi)
                : (chevron.containsMouse ? Theme.surface : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Text {
            anchors.centerIn: parent
            text: root.expanded ? "›" : "‹"
            color: chevron.containsMouse || root.expanded ? Theme.text : Theme.textDim
            font.pixelSize: 16
            font.bold: true
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }
}
