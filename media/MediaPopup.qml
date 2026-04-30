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
    visible: wantOpen && MediaService.hasPlayers

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
    anchor.rect.y: anchorItem ? anchorItem.height + 6 : 0
    anchor.adjustment: PopupAdjustment.SlideX

    implicitWidth: 360
    implicitHeight: container.implicitHeight

    readonly property var player: MediaService.currentPlayer
    readonly property bool multiPlayer: MediaService.visiblePlayers.length > 1

    // Cached album-art URL.
    //
    // Bound directly to player.trackArtUrl, browsers (Firefox / Zen) often
    // emit transient empty strings on pause/unpause cycles, which makes the
    // art flash to the placeholder mid-playback. Instead we hold the last
    // *non-empty* URL and only reset it on a true track change.
    property string cachedArtUrl: ""

    function _refreshArt() {
        if (popup.player && popup.player.trackArtUrl) {
            cachedArtUrl = popup.player.trackArtUrl;
        }
        // If trackArtUrl is empty/null, keep whatever we last cached so the
        // previous frame's art keeps showing through pause/unpause flicker.
    }

    onPlayerChanged: {
        // Different player = unrelated art context; clear and re-pull.
        cachedArtUrl = "";
        _refreshArt();
    }

    Component.onCompleted: _refreshArt()

    Connections {
        target: popup.player
        enabled: popup.player !== null
        function onTrackChanged() {
            // Genuine track change in the same player — drop the old art
            // so the placeholder shows briefly until the new URL arrives.
            popup.cachedArtUrl = "";
        }
        function onTrackArtUrlChanged() {
            popup._refreshArt();
        }
    }

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
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

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
                    font.pixelSize: 14
                    font.bold: true
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
                font.pixelSize: 11
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
                    font.pixelSize: 14
                    font.bold: true
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

                    // Music note glyph (mini version of bar icon)
                    Item {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        opacity: 0.4

                        Rectangle {
                            x: 4; y: 26
                            width: 14; height: 9
                            radius: 4.5
                            color: Theme.textDim
                            transform: Rotation { origin.x: 7; origin.y: 4.5; angle: -18 }
                        }
                        Rectangle {
                            x: 18; y: 4
                            width: 3
                            height: 24
                            radius: 1.5
                            color: Theme.textDim
                        }
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
                    font.pixelSize: 13
                    font.bold: true
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
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Item { width: 1; height: 6 }   // spacer

                // ---- Progress bar ----
                Item {
                    id: progressArea
                    width: parent.width
                    height: 18
                    visible: popup.player && popup.player.length > 0

                    readonly property real ratio: {
                        if (!popup.player || popup.player.length <= 0) return 0;
                        return Math.max(0, Math.min(1, popup.player.position / popup.player.length));
                    }

                    Rectangle {
                        id: track
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 4
                        radius: 2
                        color: Theme.surfaceHi

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * progressArea.ratio
                            radius: parent.radius
                            color: Theme.text
                        }
                    }

                    // Thumb
                    Rectangle {
                        anchors.verticalCenter: track.verticalCenter
                        x: track.width * progressArea.ratio - width / 2
                        width: 10
                        height: 10
                        radius: 5
                        color: Theme.accent
                        border.color: Theme.bg
                        border.width: 1
                        visible: popup.player && popup.player.canSeek
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: popup.player && popup.player.canSeek
                            ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: popup.player && popup.player.canSeek

                        function setFromX(x) {
                            if (!popup.player || !popup.player.canSeek) return;
                            const r = Math.max(0, Math.min(1, x / track.width));
                            popup.player.position = r * popup.player.length;
                        }

                        onPressed: mouse => setFromX(mouse.x)
                        onPositionChanged: mouse => { if (pressed) setFromX(mouse.x); }
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
                    font.pixelSize: 10
                    font.family: "monospace"
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

                // Reusable transport-button style.
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
                        font.pixelSize: btn.primary ? 16 : 13
                        font.bold: true
                    }
                }

                XportButton {
                    glyph: "⏮"
                    isEnabled: popup.player && popup.player.canGoPrevious
                    onClicked: MediaService.previous()
                    anchors.verticalCenter: parent.verticalCenter
                }

                XportButton {
                    glyph: MediaService.isPlaying ? "⏸" : "▶"
                    primary: true
                    isEnabled: popup.player && popup.player.canTogglePlaying
                    onClicked: MediaService.togglePlay()
                    anchors.verticalCenter: parent.verticalCenter
                }

                XportButton {
                    glyph: "⏭"
                    isEnabled: popup.player && popup.player.canGoNext
                    onClicked: MediaService.next()
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
