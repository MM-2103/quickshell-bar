// MediaPopup.qml
// KDE-Plasma-style media controller popup:
//   ┌──────────────────────────────────────────┐
//   │ ‹ Player Name (1/2) ›   <- only when >1   │
//   │ ───                                      │
//   │ [art]  Track Title                       │
//   │        Artist • Album                    │
//   │        ───●─────────  1:23 / 3:45        │
//   │                                          │
//   │            ⏮     ⏯/⏸    ⏭                │
//   └──────────────────────────────────────────┘

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs

PopupWindow {
    id: popup

    required property Item anchorItem

    color: "transparent"

    // Tracks whether the user has asked the popup to be open. Actual
    // visibility ANDs this with hasPlayers so that when every MPRIS player
    // disappears the popup auto-closes — otherwise the bar icon would
    // hide while the popup remained on screen with no way to dismiss it.
    property bool wantOpen: false
    readonly property bool _shouldShow: wantOpen && MediaService.hasPlayers
    // Stay mapped briefly after _shouldShow goes false so the fade-out
    // animation can play. 180 ms > the 150 ms opacity tween.
    visible: _shouldShow || hideHold.running
    Timer { id: hideHold; interval: 180; repeat: false }
    on_ShouldShowChanged: {
        if (_shouldShow) hideHold.stop();
        else             hideHold.restart();
    }

    onVisibleChanged: {
        // If visibility dropped because hasPlayers went false (not because
        // the user toggled), clear the intent flag so the next click on
        // the icon opens a fresh popup instead of immediately re-closing.
        if (!visible && wantOpen) wantOpen = false;
        // Either way, tell the popup mutex we're not the active popup.
        if (!visible) PopupController.closed(popup);
    }

    function toggle() {
        if (popup.wantOpen) {
            popup.wantOpen = false;
        } else {
            PopupController.open(popup, () => popup.wantOpen = false);
            popup.wantOpen = true;
        }
    }

    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? -((popup.width - anchorItem.width) / 2) : 0
    // Y compensates for the 12 px shadow padding so the visible popup body
    // still lands 6 px below the anchor item.
    anchor.rect.y: anchorItem ? anchorItem.height + 6 - 12 : 0
    anchor.adjustment: PopupAdjustment.SlideX

    // Popup surface is 24 px taller and wider than the visible body, leaving
    // a 12 px transparent margin around it for the drop shadow to render in.
    implicitWidth: 360 + 24
    implicitHeight: container.implicitHeight + 24

    readonly property var player: MediaService.currentPlayer
    readonly property bool multiPlayer: MediaService.visiblePlayers.length > 1

    // Cached album-art URL — read from MediaService's shell-wide cache.
    // Kept centralized there so the popup, the lock surface, and any other
    // consumer all share the same "last seen non-empty URL" without each
    // having to maintain their own cache and miss out on URLs that only
    // appeared during a sibling's lifetime.
    readonly property string cachedArtUrl: MediaService.cachedArtUrl

    // MprisPlayer.position isn't reactive — emit positionChanged() periodically
    // while the popup is visible AND the player is playing, so the progress
    // bar updates smoothly.
    Timer {
        id: positionTick
        interval: 250
        repeat: true
        running: popup.visible && popup.player !== null && MediaService.isPlaying
        onTriggered: { if (popup.player) popup.player.positionChanged(); }
    }

    Rectangle {
        id: container
        anchors.fill: parent
        anchors.margins: 12   // shadow padding
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

        // Snappy fade + 4 px slide-up on open / mirror on close.
        opacity: popup._shouldShow ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        transform: Translate {
            y: popup._shouldShow ? 0 : 4
            Behavior on y {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }

        // Subtle drop shadow (depth + masks the rounded-corner-against-
        // wallpaper "torn corner" appearance on dark wallpapers).
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
            shadowBlur: 0.6
        }

        // Vertical sum of the inner sections (with margins).
        implicitHeight: 12
            + (popup.multiPlayer ? switcher.implicitHeight + 8 : 0)
            + bodyRow.implicitHeight
            + 14
            + transportRow.implicitHeight
            + 12

        // ================================================================
        // Player switcher — visible only when there's more than one player.
        // ================================================================
        Item {
            id: switcher
            visible: popup.multiPlayer
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 10
            }
            implicitHeight: visible ? 22 : 0
            height: implicitHeight

            // ‹ prev
            MouseArea {
                id: prevPlayerMa
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 22; height: 22
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: MediaService.pickPrev()

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: prevPlayerMa.containsMouse ? Theme.surface : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                }
            }

            // Player name + (i/N)
            Text {
                anchors.centerIn: parent
                text: popup.player
                    ? MediaService.playerName(popup.player)
                      + "  ("
                      + (MediaService.currentIndex + 1) + "/"
                      + MediaService.visiblePlayers.length + ")"
                    : ""
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }

            // › next
            MouseArea {
                id: nextPlayerMa
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 22; height: 22
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: MediaService.pickNext()

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: nextPlayerMa.containsMouse ? Theme.surface : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                Text {
                    anchors.centerIn: parent
                    text: "›"
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                }
            }
        }

        // ================================================================
        // Body — album art + title/artist + progress bar
        // ================================================================
        Item {
            id: bodyRow
            anchors {
                top: switcher.visible ? switcher.bottom : parent.top
                topMargin: switcher.visible ? 8 : 12
                left: parent.left
                right: parent.right
                margins: 12
                leftMargin: 12
                rightMargin: 12
            }
            implicitHeight: 88

            // ---- Album art ----
            Rectangle {
                id: artFrame
                width: 88
                height: 88
                radius: 6
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
                clip: true

                Image {
                    id: art
                    anchors.fill: parent
                    anchors.margins: 1
                    source: popup.cachedArtUrl
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    visible: source !== "" && status === Image.Ready
                }

                // Fallback placeholder when there's no art.
                Item {
                    anchors.fill: parent
                    visible: !art.visible

                    // Music note placeholder — Font Awesome 7 Solid \uf001.
                    Text {
                        anchors.centerIn: parent
                        text: "\uf001"
                        color: Theme.textDim
                        opacity: 0.4
                        font.family: Theme.fontIcon
                        font.styleName: "Solid"
                        font.pixelSize: 32
                        renderType: Text.NativeRendering
                    }
                }
            }

            // ---- Right column: title, artist, progress, time ----
            Column {
                anchors {
                    left: artFrame.right
                    leftMargin: 12
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }
                spacing: 4

                Text {
                    width: parent.width
                    text: popup.player ? (popup.player.trackTitle || "Unknown title") : "—"
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    width: parent.width
                    text: {
                        if (!popup.player) return "";
                        const a = popup.player.trackArtist || "";
                        const al = popup.player.trackAlbum || "";
                        if (a && al) return a + "  •  " + al;
                        return a || al || "";
                    }
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Item { width: 1; height: 6 }   // spacer

                // ---- Progress bar ----
                // Slider when seekable, ProgressBar otherwise — same shared
                // components used by VolumePopup and the OSDs, so all "fill
                // ratio" UI in the shell looks identical.
                Item {
                    width: parent.width
                    height: 18
                    visible: popup.player && popup.player.length > 0

                    readonly property real ratio: {
                        if (!popup.player || popup.player.length <= 0) return 0;
                        return Math.max(0, Math.min(1, popup.player.position / popup.player.length));
                    }
                    readonly property bool seekable: popup.player && popup.player.canSeek

                    Slider {
                        anchors.fill: parent
                        visible: parent.seekable
                        value: parent.ratio
                        wheelStep: 0   // no scrub-by-wheel; that's owned by Volume
                        onUserChanged: v => {
                            if (popup.player && popup.player.canSeek)
                                popup.player.position = v * popup.player.length;
                        }
                    }

                    ProgressBar {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !parent.seekable
                        value: parent.ratio
                    }
                }

                // ---- Time text ----
                Text {
                    width: parent.width
                    visible: popup.player && popup.player.length > 0
                    text: popup.player
                        ? (MediaService.formatTime(popup.player.position)
                           + " / "
                           + MediaService.formatTime(popup.player.length))
                        : ""
                    color: Theme.textMuted
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        // ================================================================
        // Transport row — prev / play-pause / next
        // ================================================================
        Item {
            id: transportRow
            anchors {
                top: bodyRow.bottom
                topMargin: 14
                left: parent.left
                right: parent.right
            }
            implicitHeight: 36
            height: implicitHeight

            Row {
                anchors.centerIn: parent
                spacing: 14

                // Reusable transport-button style. Glyph is rendered in
                // Font Awesome 7 Solid so Qt picks the dedicated icon font
                // instead of falling back to Noto Color Emoji's coloured
                // pictograms — keeps the popup visually consistent with
                // the lock surface's NowPlayingCard.
                component XportButton: MouseArea {
                    id: btn
                    property string glyph
                    property bool primary: false      // makes the play/pause bigger
                    property bool isEnabled: true
                    width: primary ? 36 : 30
                    height: width
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: isEnabled
                    opacity: isEnabled ? 1 : 0.35

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: btn.containsMouse
                            ? (btn.primary ? Theme.text : Theme.surfaceHi)
                            : (btn.primary ? Theme.surfaceHi : "transparent")
                        border.color: Theme.border
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: btn.glyph
                        color: btn.containsMouse && btn.primary ? Theme.bg : Theme.text
                        font.family: Theme.fontIcon
                        font.styleName: "Solid"
                        font.pixelSize: btn.primary ? 14 : 11
                        renderType: Text.NativeRendering
                    }
                }

                // Font Awesome 7 Solid codepoints:
                //   \uf048 = backward-step
                //   \uf04b = play
                //   \uf04c = pause
                //   \uf051 = forward-step
                XportButton {
                    glyph: "\uf048"
                    isEnabled: popup.player && popup.player.canGoPrevious
                    onClicked: MediaService.previous()
                    anchors.verticalCenter: parent.verticalCenter
                }

                XportButton {
                    glyph: MediaService.isPlaying ? "\uf04c" : "\uf04b"
                    primary: true
                    isEnabled: popup.player && popup.player.canTogglePlaying
                    onClicked: MediaService.togglePlay()
                    anchors.verticalCenter: parent.verticalCenter
                }

                XportButton {
                    glyph: "\uf051"
                    isEnabled: popup.player && popup.player.canGoNext
                    onClicked: MediaService.next()
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
