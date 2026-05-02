// Bar.qml
// PanelWindow rendered once per monitor (instantiated by Variants in shell.qml).

import QtQuick
import Quickshell
import qs.workspaces
import qs.clock
import qs.volume
import qs.tray
import qs.system
import qs.notifications
import qs.media
import qs.controlcenter

PanelWindow {
    id: bar

    required property var modelData // injected by Variants — the ShellScreen

    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight
    color: Theme.bg
    exclusiveZone: implicitHeight

    // Bottom border
    Rectangle {
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        height: 1
        color: Theme.border
    }

    // Left section
    Workspaces {
        id: leftSection
        output: bar.screen.name
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 12
        }
    }

    // Center section
    Clock {
        anchors.centerIn: parent
    }

    // Right section. Flat layout: every widget has the same gap to its
    // neighbour. No groups, no separators.
    Row {
        id: rightSection
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: 12
        }
        spacing: 14

        // Five widgets (IdleInhibit, PowerProfile, Network, Bluetooth,
        // Wallpaper) moved into the Control Center to declutter the bar.
        // Their interactions live behind the CC tile grid; their state
        // is still surfaced via the same underlying services.
        Notifications  { anchors.verticalCenter: parent.verticalCenter }
        TrayCollapser  { anchors.verticalCenter: parent.verticalCenter }
        Media          { anchors.verticalCenter: parent.verticalCenter }
        Battery        { anchors.verticalCenter: parent.verticalCenter }
        Brightness     { anchors.verticalCenter: parent.verticalCenter }
        Volume         { anchors.verticalCenter: parent.verticalCenter }
        ControlCenter  { anchors.verticalCenter: parent.verticalCenter }
        Power          { anchors.verticalCenter: parent.verticalCenter }
    }
}
