// Media.qml
// Bar icon for the media controller. Shows a music note glyph when at
// least one MPRIS player exists; entirely hidden otherwise.
//
//   Left click  -> toggle the media popup
//   Middle click-> toggle play/pause without opening the popup

import QtQuick
import Quickshell
import qs

MouseArea {
    id: root

    visible: MediaService.hasPlayers
    implicitWidth: visible ? 22 : 0
    implicitHeight: 22
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
            popup.toggle();
        } else if (mouse.button === Qt.MiddleButton) {
            MediaService.togglePlay();
        }
    }

    // Hover / active background pill
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: popup.visible
            ? Theme.surfaceHi
            : (root.containsMouse ? Theme.surface : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // Music note glyph — Font Awesome 7 Solid \uf001. Always rendered;
    // the playback state is signalled by the popup's transport icons,
    // not by changing the bar glyph (Theme.accent and Theme.text are
    // visually indistinguishable on this palette anyway).
    BarIcon {
        anchors.centerIn: parent
        glyph: "\uf001"
    }

    MediaPopup {
        id: popup
        anchorItem: root
    }
}
