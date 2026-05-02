// WallpaperPickerPopup.qml
// Picker UI. Replaces the waypaper GTK app.
//
// Layer-shell PanelWindow on the Overlay layer (above bar / fullscreen),
// centered on the focused monitor. One instance per screen (instantiated
// via Variants in shell.qml); only the focused-monitor's panel is visible
// — same architecture as Launcher / ClipboardPopup.
//
// Layout (top-to-bottom inside the rounded card):
//   1. Title row             ("Wallpaper")
//   2. Folder bar            (current path · ↑ up button)
//   3. Output selector pills ("Apply to: All · DP-1 · …")
//   4. Fill-mode pills       ("Fill · Fit · Stretch · Center · Tile")
//   5. Subfolder pills       (one per immediate subdir, if any)
//   6. Thumbnail GridView    (lazy-loaded; click sets wallpaper)
//
// Keyboard: Esc closes.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs
import qs.wallpaper

PanelWindow {
    id: panel

    required property var modelData
    required property string focusedOutput

    screen: modelData

    readonly property bool isFocusedScreen:
        modelData && modelData.name === focusedOutput
    readonly property bool wantOpen:
        WallpaperService.popupOpen && isFocusedScreen

    // Same fade-out trick as the other popups: stay mapped for 180 ms after
    // wantOpen drops so the opacity Behavior actually has time to play.
    visible: wantOpen || hideHold.running
    Timer { id: hideHold; interval: 180; repeat: false }
    onWantOpenChanged: {
        if (wantOpen) hideHold.stop();
        else          hideHold.restart();
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Above bar + fullscreen apps; Exclusive keyboard so Esc reaches us.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // No anchors → wlroots horizontally + vertically centers the surface.
    // 24 px padding on each side for the drop shadow.
    implicitWidth:  720 + 24
    implicitHeight: 540 + 24

    // ---- Card surface ----
    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: 12

        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

        opacity: panel.wantOpen ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        transform: Translate {
            y: panel.wantOpen ? 0 : 4
            Behavior on y {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
            shadowBlur: 0.6
        }

        // Esc to close. Item with focus + Keys handler — anchored to fill so
        // the layer-shell Exclusive focus delivery hits this item first.
        Item {
            id: keyTarget
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    WallpaperService.closePicker();
                    event.accepted = true;
                }
            }
        }
        // Refocus when popup opens so Esc works on first press.
        onVisibleChanged: if (visible) Qt.callLater(() => keyTarget.forceActiveFocus())

        // ================================================================
        // Inner content column
        // ================================================================
        Column {
            anchors {
                fill: parent
                margins: 14
            }
            spacing: 10

            // ---- 1. Title ----
            Text {
                text: "Wallpaper"
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
            }

            // ---- 2. Folder bar ----
            Row {
                width: parent.width
                spacing: 8

                // Folder glyph (FA Solid \uf07b folder)
                BarIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "\uf07b"
                    glyphSize: 13
                    color: Theme.textDim
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 22 - upBtn.width - parent.spacing * 2
                    elide: Text.ElideMiddle
                    text: WallpaperService.folder || "(no folder)"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                }

                // Up-one-level button. Disabled at root.
                Rectangle {
                    id: upBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 22
                    radius: Theme.radiusSmall
                    readonly property bool _enabled:
                        WallpaperService.folder && WallpaperService.folder !== "/"
                    color: !_enabled
                        ? "transparent"
                        : (upMa.containsMouse ? Theme.surfaceHi : Theme.surface)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    opacity: _enabled ? 1.0 : 0.4

                    // \uf062 arrow-up
                    Text {
                        anchors.centerIn: parent
                        text: "\uf062"
                        color: Theme.text
                        font.family: Theme.fontIcon
                        font.styleName: "Solid"
                        font.pixelSize: 11
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: upMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: parent._enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: parent._enabled
                        onClicked: WallpaperService.goUpFolder()
                    }
                }
            }

            // Thin separator line under the folder bar
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
                opacity: 0.5
            }

            // ---- 3. Output selector ----
            Row {
                width: parent.width
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Apply to"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    width: 60
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Build pill list from "All" + every detected screen name.
                    // Re-evaluates if Quickshell.screens mutates (hot-plug).
                    Repeater {
                        model: {
                            const out = ["All"];
                            const screens = Quickshell.screens || [];
                            for (let i = 0; i < screens.length; i++)
                                out.push(screens[i].name);
                            return out;
                        }
                        delegate: pillDelegate
                    }

                    // Inline component used for output-target pills.
                    Component {
                        id: pillDelegate
                        Rectangle {
                            id: pill
                            required property var modelData
                            readonly property bool _selected:
                                WallpaperService.pickerTarget === pill.modelData
                            width: pillLabel.implicitWidth + 16
                            height: 22
                            radius: 11
                            color: pill._selected
                                ? Theme.accent
                                : (pillMa.containsMouse ? Theme.surfaceHi : Theme.surface)
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                id: pillLabel
                                anchors.centerIn: parent
                                text: pill.modelData
                                color: pill._selected ? Theme.accentText : Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            MouseArea {
                                id: pillMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: WallpaperService.pickerTarget = pill.modelData
                            }
                        }
                    }
                }
            }

            // ---- 4. Fill-mode selector ----
            Row {
                width: parent.width
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Fill"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    width: 60
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Repeater {
                        model: WallpaperService.fillModeKeys
                        delegate: Rectangle {
                            id: fillPill
                            required property var modelData
                            readonly property bool _selected:
                                WallpaperService.fillMode === fillPill.modelData
                            width: fillLabel.implicitWidth + 16
                            height: 22
                            radius: 11
                            color: fillPill._selected
                                ? Theme.accent
                                : (fillMa.containsMouse ? Theme.surfaceHi : Theme.surface)
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                id: fillLabel
                                anchors.centerIn: parent
                                text: WallpaperService.fillModeLabels[fillPill.modelData]
                                      || fillPill.modelData
                                color: fillPill._selected ? Theme.accentText : Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            MouseArea {
                                id: fillMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: WallpaperService.setFillMode(fillPill.modelData)
                            }
                        }
                    }
                }
            }

            // ---- 5. Subfolder pills (visible only if any) ----
            Flow {
                width: parent.width
                spacing: 6
                visible: WallpaperService.subdirs.length > 0

                Repeater {
                    model: WallpaperService.subdirs
                    delegate: Rectangle {
                        id: subPill
                        required property var modelData
                        width: subRow.implicitWidth + 16
                        height: 22
                        radius: Theme.radiusSmall
                        color: subMa.containsMouse ? Theme.surfaceHi : Theme.surface
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Row {
                            id: subRow
                            anchors.centerIn: parent
                            spacing: 6
                            // \uf07b folder
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\uf07b"
                                color: Theme.textDim
                                font.family: Theme.fontIcon
                                font.styleName: "Solid"
                                font.pixelSize: 10
                                renderType: Text.NativeRendering
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: subPill.modelData
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }

                        MouseArea {
                            id: subMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const sep = WallpaperService.folder.endsWith("/") ? "" : "/";
                                WallpaperService.setFolder(
                                    WallpaperService.folder + sep + subPill.modelData);
                            }
                        }
                    }
                }
            }

            // ---- 6. Thumbnail grid ----
            //
            // Fills the remaining vertical space. Empty-state placeholder
            // shown when the folder has no images.
            Item {
                width: parent.width
                // Card height (540) - margins (28) - sum of fixed rows above
                // (~190 with subdirs visible, ~160 without). Use fillHeight
                // expression instead of hardcoding so layout adapts cleanly.
                height: card.height - y - 28

                GridView {
                    id: grid
                    anchors.fill: parent
                    clip: true
                    visible: WallpaperService.images.length > 0

                    cellWidth:  Math.floor(width / 4)
                    cellHeight: Math.round(cellWidth * 9 / 16) + 8
                    model: WallpaperService.images

                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: thumb
                        required property var modelData
                        width: grid.cellWidth
                        height: grid.cellHeight

                        // True if this thumbnail's path is the wallpaper
                        // currently set on the panel's screen — gives a
                        // visual highlight (accent border) so the user
                        // sees their current pick at a glance.
                        readonly property bool _selectedHere:
                            WallpaperService.pathFor(panel.modelData
                                ? panel.modelData.name : "") === thumb.modelData

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: Theme.radiusSmall
                            color: Theme.surface
                            border.color: thumb._selectedHere
                                ? Theme.accent
                                : (thumbMa.containsMouse ? Theme.border : "transparent")
                            border.width: thumb._selectedHere ? 2 : 1
                            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                            clip: true

                            // Decode-time downsample: 320×180 (2× the displayed
                            // size for hi-DPI sharpness without keeping a 4K
                            // pixel buffer in RAM per thumbnail).
                            Image {
                                anchors.fill: parent
                                anchors.margins: 2
                                source: thumb.modelData
                                sourceSize.width: 320
                                sourceSize.height: 180
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                clip: true
                            }

                            MouseArea {
                                id: thumbMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: WallpaperService.setWallpaper(
                                    WallpaperService.pickerTarget,
                                    thumb.modelData)
                            }
                        }
                    }
                }

                // Empty / scanning state.
                Text {
                    anchors.centerIn: parent
                    visible: WallpaperService.images.length === 0
                    text: WallpaperService.scanning
                        ? "Scanning…"
                        : "No images in this folder."
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeNormal
                }
            }
        }
    }
}
