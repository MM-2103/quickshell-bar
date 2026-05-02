// SlidersBlock.qml
// Volume + Brightness sliders for the top of the Control Center's tiles
// view. Mirrors the bar widgets (Volume, Brightness) in functionality —
// adding here doesn't replace them, it just provides the universal
// "control center has sliders" affordance every other shell ships.
//
// Volume:
//   - Slider value tracks Pipewire.defaultAudioSink.audio.volume
//   - Wheel / drag / click writes back the same way VolumePopup does
//   - Speaker-icon click toggles mute
//   - When muted: slider dimmed, icon swap, "Muted" label instead of %
//
// Brightness:
//   - Slider value tracks OsdService.brightnessRatio (sysfs-polled)
//   - Adjustments call OsdService.setBrightness() — same writer the
//     existing BrightnessPopup uses
//   - Whole row hidden when !OsdService.hasBrightness (desktops with no
//     /sys/class/backlight entry — same gate the bar Brightness widget uses)

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.osd

Column {
    id: root

    spacing: 6

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volumeRatio:
        sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted:
        sink && sink.audio ? sink.audio.muted : false

    // Required for the sink's audio properties to populate reactively.
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    // ---- Volume row ----
    Row {
        width: parent.width
        spacing: 8
        height: 24

        MouseArea {
            id: volIconMa
            anchors.verticalCenter: parent.verticalCenter
            width: 24; height: 24
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: root.sink && root.sink.audio
            onClicked: {
                if (root.sink && root.sink.audio) {
                    root.sink.audio.muted = !root.sink.audio.muted;
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: volIconMa.containsMouse ? Theme.surfaceHi : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            // FA 7 Solid: \uf6a9 volume-xmark (muted) / \uf028 volume-high
            Text {
                anchors.centerIn: parent
                text: root.muted ? "\uf6a9" : "\uf028"
                color: Theme.text
                opacity: root.muted ? 0.45 : 1.0
                font.family: Theme.fontIcon
                font.styleName: "Solid"
                font.pixelSize: 14
                renderType: Text.NativeRendering
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            }
        }

        Slider {
            id: volSlider
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - volIconMa.width - volPct.width - parent.spacing * 2
            value: root.volumeRatio
            dimmed: root.muted
            enabled: !!(root.sink && root.sink.audio)
            // Match VolumePopup's behaviour: writing volume does NOT auto-
            // unmute. The mute toggle stays a deliberate click on the icon.
            onUserChanged: v => {
                if (root.sink && root.sink.audio)
                    root.sink.audio.volume = v;
            }
        }

        Text {
            id: volPct
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            horizontalAlignment: Text.AlignRight
            text: root.muted ? "Muted" : Math.round(root.volumeRatio * 100) + "%"
            color: Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    // ---- Brightness row ----
    //
    // Whole row collapses (visible: false → 0 height in Column) when no
    // backlight is present. Keeps desktops from showing a "stuck at 0%"
    // dummy slider.
    Row {
        width: parent.width
        spacing: 8
        height: visible ? 24 : 0
        visible: OsdService.hasBrightness

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 24; height: 24

            // FA 7 Solid: \uf185 sun
            Text {
                anchors.centerIn: parent
                text: "\uf185"
                color: Theme.text
                font.family: Theme.fontIcon
                font.styleName: "Solid"
                font.pixelSize: 14
                renderType: Text.NativeRendering
            }
        }

        Slider {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 24 - brPct.width - parent.spacing * 2
            value: OsdService.brightnessRatio
            enabled: OsdService.hasBrightness
            onUserChanged: v => OsdService.setBrightness(v)
        }

        Text {
            id: brPct
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            horizontalAlignment: Text.AlignRight
            text: Math.round(OsdService.brightnessRatio * 100) + "%"
            color: Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
