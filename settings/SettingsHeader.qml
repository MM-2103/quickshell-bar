// SettingsHeader.qml
// Title row at the top of the Settings popup. Layout:
//
//   ┌──────────────────────────────────────────────────────────────┐
//   │ Settings                  [Reset all] [Open in editor]  [×]  │
//   └──────────────────────────────────────────────────────────────┘
//
// "Reset all" calls `Local.resetAll()` (drops every override, file
// shrinks to `{}`). "Open in editor" spawns `xdg-open` on the config
// file path so the user can hand-edit alongside the UI. "×" closes.

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.settings

Item {
    id: root

    height: 28

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "Settings"
        color: Theme.text
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // ---- Reset all ----
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: resetLabel.implicitWidth + 16
            height: 24
            radius: Theme.radiusSmall
            color: resetMa.containsMouse ? Theme.surfaceHi : Theme.surface
            border.color: Theme.border
            border.width: 1
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Text {
                id: resetLabel
                anchors.centerIn: parent
                text: "Reset all"
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
            }

            MouseArea {
                id: resetMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Local.resetAll()
            }
        }

        // ---- Open in editor ----
        //
        // xdg-open on the config path. If the user hasn't yet set any
        // override the file may not exist; we trigger a flush first by
        // calling resetAll on an already-empty data, which still
        // writes a (mostly empty) header to the file. Or simpler: just
        // launch xdg-open and let the editor's "file doesn't exist"
        // dialog handle it. Going with the simple version.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: editorLabel.implicitWidth + 16
            height: 24
            radius: Theme.radiusSmall
            color: editorMa.containsMouse ? Theme.surfaceHi : Theme.surface
            border.color: Theme.border
            border.width: 1
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Text {
                id: editorLabel
                anchors.centerIn: parent
                text: "Open in editor"
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
            }

            MouseArea {
                id: editorMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: editorProc.running = true
            }
        }

        // ---- Close (×) ----
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 24
            radius: Theme.radiusSmall
            color: closeMa.containsMouse ? Theme.surfaceHi : Theme.surface
            border.color: Theme.border
            border.width: 1
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            // FA Solid \uf00d xmark
            Text {
                anchors.centerIn: parent
                text: "\uf00d"
                color: Theme.text
                font.family: Theme.fontIcon
                font.styleName: "Solid"
                font.pixelSize: 11
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: closeMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: SettingsService.closePopup()
            }
        }
    }

    // xdg-open spawner; one-shot Process restarted on each click.
    Process {
        id: editorProc
        running: false
        command: ["xdg-open",
                  Quickshell.env("HOME") + "/.config/quickshell-bar/config.jsonc"]
    }
}
