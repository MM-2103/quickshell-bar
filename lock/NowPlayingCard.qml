// NowPlayingCard.qml
// Compact MPRIS now-playing card used on the lock surface. Visible only
// when at least one MPRIS player has a track. Plays/pauses/skips work
// without unlocking — MPRIS DBus calls do not require PAM.
//
// Reuses MediaService (qs.media) for the player wiring; styling matches
// the glassy card around the password input in LockSurface.qml.

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.media

Rectangle {
    id: card

    // Convenience handle to the currently-foregrounded MPRIS player.
    readonly property var player: MediaService.currentPlayer

    // Hide entirely unless we have a player AND it has at least a title or
    // an artist. Empty placeholder cards on a lock screen feel awkward.
    readonly property bool _shouldShow:
        MediaService.hasPlayers
        && card.player
        && ((card.player.trackTitle && card.player.trackTitle.length > 0)
            || (card.player.trackArtist && card.player.trackArtist.length > 0))
    visible: _shouldShow

    // Album-art URL: read from MediaService.cachedArtUrl (shell-wide cache).
    // Putting the cache there rather than here ensures the lock surface —
    // which is rebuilt on every lock cycle — picks up the URL that was
    // observed earlier in the shell's lifetime, instead of waiting for
    // the next trackArtUrl change to fire (which may never happen
    // mid-track for some MPRIS sources).
    readonly property string cachedArtUrl: MediaService.cachedArtUrl

    // Glassy panel: semi-transparent white over the already-blurred
    // wallpaper, with a 1 px highlight border. Matches the input card's
    // alpha intensity (0.10) for visual consistency.
    width: 360
    height: 64
    radius: 14
    color: Qt.rgba(1, 1, 1, 0.10)
    border.color: Qt.rgba(1, 1, 1, 0.18)
    border.width: 1

    // ---- Album art availability ----
    //
    // The slot expands as soon as we have a *URL*. We do NOT additionally
    // gate on `Image.status === Ready` because:
    //   1. The Image element only starts fetching its source once it's in
    //      a non-collapsed scene branch — gating the parent's width on
    //      Image.Ready creates a chicken-and-egg where status never
    //      progresses past Loading.
    //   2. While the Image is fetching, the underlying Rectangle gives us
    //      a dark rounded square that doubles as a placeholder, so the
    //      transient state is acceptable.
    //   3. If the load ultimately fails (Image.status === Error), we let
    //      the placeholder rectangle stay visible — it's preferable to
    //      a layout flash mid-track.
    readonly property bool _hasArt: card.cachedArtUrl !== ""

    // Layout constants used in two places.
    readonly property int _padding: 12
    readonly property int _artSize: 48
    readonly property int _artGap: 12

    Row {
        anchors.fill: parent
        anchors.margins: card._padding
        spacing: 0

        // ---- Album art slot (collapses to 0 width if no URL) ----
        Rectangle {
            id: artSlot
            anchors.verticalCenter: parent.verticalCenter
            visible: card._hasArt
            width: visible ? card._artSize : 0
            height: card._artSize
            radius: 8
            color: Qt.rgba(0, 0, 0, 0.35)   // dark placeholder behind image
            clip: true

            Image {
                id: artImage
                anchors.fill: parent
                source: card.cachedArtUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                sourceSize.width: card._artSize * 2
                sourceSize.height: card._artSize * 2
            }
        }

        // Spacer between art and title (zero width when art slot is collapsed).
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: card._hasArt ? card._artGap : 0
            height: 1
        }

        // ---- Title + artist column ----
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            // Fill the space between the art slot and the controls Row.
            width: parent.width - artSlot.width
                - (card._hasArt ? card._artGap : 0)
                - controls.width - 8

            Text {
                width: parent.width
                text: card.player ? (card.player.trackTitle || "Unknown title") : ""
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: card.player ? (card.player.trackArtist || "") : ""
                color: Theme.text
                opacity: 0.7
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }

        // ---- Controls (previous · play/pause · next) ----
        Row {
            id: controls
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            // Reusable button factory — small Rectangle + MouseArea + Font
            // Awesome glyph. Using FA Solid (private-use codepoints) bypasses
            // Qt's font fallback to Noto Color Emoji entirely; we get clean
            // monochrome icons that respect Theme.text.
            component CtlButton: Rectangle {
                id: btn
                property string glyph: ""
                property int diameter: 24
                property real glyphScale: 1.0
                signal activated()

                width: diameter
                height: diameter
                radius: diameter / 2
                color: ma.containsMouse
                    ? Qt.rgba(1, 1, 1, 0.14)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text: btn.glyph
                    color: Theme.text
                    font.family: Theme.fontIcon
                    font.styleName: "Solid"
                    font.pixelSize: btn.diameter * 0.50 * btn.glyphScale
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: btn.activated()
                }
            }

            // Font Awesome 7 Solid codepoints:
            //   \uf048 = backward-step  (prev)
            //   \uf04b = play
            //   \uf04c = pause
            //   \uf051 = forward-step   (next)
            CtlButton {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "\uf048"
                diameter: 26
                onActivated: MediaService.previous()
            }

            CtlButton {
                anchors.verticalCenter: parent.verticalCenter
                // Play / pause swaps based on actual playback state.
                glyph: MediaService.isPlaying ? "\uf04c" : "\uf04b"
                diameter: 32
                onActivated: MediaService.togglePlay()
            }

            CtlButton {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "\uf051"
                diameter: 26
                onActivated: MediaService.next()
            }
        }
    }
}
