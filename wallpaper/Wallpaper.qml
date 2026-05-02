// Wallpaper.qml
// Bar icon for the wallpaper picker. Click toggles the picker popup,
// which is a layer-shell PanelWindow centered on the focused monitor
// (see WallpaperPickerPopup.qml + the Variants block in shell.qml).
//
// Mouse semantics:
//   Left click -> toggle the picker
//
// No middle/right/wheel handlers — there's no obvious quick-action and
// the user explicitly opted for a single-click open.

import QtQuick
import Quickshell
import qs
import qs.wallpaper

MouseArea {
    id: root

    implicitWidth: 22
    implicitHeight: 22
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton

    onClicked: WallpaperService.togglePicker()

    // Hover / active background pill — same recipe as Power, Volume, etc.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: WallpaperService.popupOpen
            ? Theme.surfaceHi
            : (root.containsMouse ? Theme.surface : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // Image glyph — Font Awesome 7 Solid \uf03e (image / picture frame).
    BarIcon {
        anchors.centerIn: parent
        glyph: "\uf03e"
    }

    BarTooltip {
        anchorItem: root
        show: root.containsMouse && !WallpaperService.popupOpen
        text: "Wallpaper"
    }
}
