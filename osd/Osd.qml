// Osd.qml
// One layer-shell PanelWindow per monitor; only the focused-monitor's panel
// shows the OSD when OsdService.currentKind is non-empty.
//
// The pill-shaped Rectangle inside the panel handles fade + slide-in/out
// animations, and switches its content via a Loader keyed on currentKind.

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs

PanelWindow {
    id: panel

    required property var modelData
    required property string focusedOutput

    screen: modelData

    readonly property bool isFocusedScreen:
        modelData && modelData.name === focusedOutput
    readonly property bool wantShow:
        OsdService.currentKind !== "" && isFocusedScreen

    // Keep the panel mapped briefly after wantShow goes false so the fade-out
    // animation can play. After 320ms (>animation duration) we drop visibility.
    visible: wantShow || hideHold.running
    Timer {
        id: hideHold
        interval: 320
        repeat: false
    }
    onWantShowChanged: {
        if (wantShow) hideHold.stop();
        else          hideHold.restart();
    }

    anchors {
        bottom: true
        // No left/right anchors → layer-shell horizontally centers the surface.
    }
    margins.bottom: 80

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight + 16    // breathing room for the slide

    // ================================================================
    // The OSD pill
    // ================================================================
    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        implicitWidth: contentLoader.implicitWidth + 28
        implicitHeight: contentLoader.implicitHeight + 16

        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

        opacity: panel.wantShow ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        // Slight slide-up on enter / slide-down on exit.
        transform: Translate {
            id: slideXform
            y: panel.wantShow ? 0 : 8
            Behavior on y {
                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
            }
        }

        Loader {
            id: contentLoader
            anchors.centerIn: parent
            sourceComponent: {
                switch (OsdService.currentKind) {
                case "volume":     return volumeContent;
                case "caps":
                case "num":        return lockContent;
                case "brightness": return brightnessContent;
                case "layout":     return layoutContent;
                default:           return null;
                }
            }
        }
    }

    // ================================================================
    // Content components — switched by Loader above.
    // ================================================================

    // Volume: speaker icon (4-tier + muted) + bar + percentage.
    Component {
        id: volumeContent
        Row {
            spacing: 12

            // Speaker icon — same icon name logic as our Volume widget.
            function _iconName() {
                if (OsdService.muted || OsdService.volumeRatio <= 0.001)
                    return "audio-volume-muted-symbolic";
                if (OsdService.volumeRatio < 0.34)
                    return "audio-volume-low-symbolic";
                if (OsdService.volumeRatio < 0.67)
                    return "audio-volume-medium-symbolic";
                return "audio-volume-high-symbolic";
            }

            Item {
                width: 18; height: 18
                anchors.verticalCenter: parent.verticalCenter

                IconImage {
                    id: volIcon
                    anchors.fill: parent
                    implicitSize: 18
                    source: Quickshell.iconPath(parent.parent._iconName(), true)
                    asynchronous: false
                    visible: status === Image.Ready
                }
                // Font Awesome fallback if theme is missing the symbolic icon.
                Text {
                    anchors.centerIn: parent
                    visible: !volIcon.visible
                    // \uf6a9 volume-xmark / \uf028 volume-high
                    text: OsdService.muted ? "\uf6a9" : "\uf028"
                    color: Theme.text
                    font.family: Theme.fontIcon
                    font.styleName: "Solid"
                    font.pixelSize: 14
                    renderType: Text.NativeRendering
                }
            }

            // Track + filled portion (shared ProgressBar component).
            ProgressBar {
                anchors.verticalCenter: parent.verticalCenter
                width: 160
                value: OsdService.volumeRatio
                dimmed: OsdService.muted
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 50
                horizontalAlignment: Text.AlignRight
                text: OsdService.muted
                    ? "Muted"
                    : Math.round(OsdService.volumeRatio * 100) + "%"
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeNormal
            }
        }
    }

    // Caps Lock / Num Lock — identical layout, glyph + label switches by kind.
    Component {
        id: lockContent
        Row {
            spacing: 12

            // Caps → \uf062 arrow-up (shift held). Num → \uf292 hashtag.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: OsdService.currentKind === "caps" ? "\uf062" : "\uf292"
                color: Theme.text
                font.family: Theme.fontIcon
                font.styleName: "Solid"
                font.pixelSize: 18
                renderType: Text.NativeRendering
                width: 24
                horizontalAlignment: Text.AlignHCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: OsdService.currentKind === "caps" ? "Caps Lock" : "Num Lock"
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: Font.Bold
                }
                Text {
                    text: {
                        const on = OsdService.currentKind === "caps"
                            ? OsdService.capsOn : OsdService.numOn;
                        return on ? "ON" : "OFF";
                    }
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }

    // Brightness: sun glyph + bar + percent.
    Component {
        id: brightnessContent
        Row {
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                // Font Awesome 7 Solid: \uf185 sun
                text: "\uf185"
                color: Theme.text
                font.family: Theme.fontIcon
                font.styleName: "Solid"
                font.pixelSize: 16
                renderType: Text.NativeRendering
                width: 18
                horizontalAlignment: Text.AlignHCenter
            }

            ProgressBar {
                anchors.verticalCenter: parent.verticalCenter
                width: 160
                value: OsdService.brightnessRatio
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 50
                horizontalAlignment: Text.AlignRight
                text: Math.round(OsdService.brightnessRatio * 100) + "%"
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeNormal
            }
        }
    }

    // Layout: small keyboard glyph + layout name.
    Component {
        id: layoutContent
        Row {
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                // Font Awesome 7 Solid: \uf11c keyboard
                text: "\uf11c"
                color: Theme.text
                font.family: Theme.fontIcon
                font.styleName: "Solid"
                font.pixelSize: 14
                renderType: Text.NativeRendering
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: OsdService.layoutName || "—"
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeNormal
                font.weight: Font.Bold
            }
        }
    }
}
