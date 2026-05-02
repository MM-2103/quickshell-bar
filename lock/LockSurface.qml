// LockSurface.qml
// Per-screen lock UI: blurred wallpaper background + centered clock,
// date and password input. Quickshell instantiates one per ShellScreen
// via the `surface: Component { LockSurface { } }` in Lock.qml.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs
import qs.lock
import qs.wallpaper

WlSessionLockSurface {
    id: surface

    // Solid-black fallback for the brief moment before the Image actually
    // lays out — guards against transparent flicker (per Quickshell docs:
    // transparent WlSessionLockSurface backgrounds are buggy).
    color: "black"

    // Live ticking clock for the centered display.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ---- Background: wallpaper + blur + darkening overlay ----

    Image {
        id: wallpaper
        anchors.fill: parent
        // Per-monitor wallpaper from the in-shell module. Falls back to
        // WallpaperService.lastSetPath inside pathFor() for hot-plugged
        // monitors with no saved entry. Empty string → solid bg.
        source: WallpaperService.pathFor(surface.screen ? surface.screen.name : "")
        visible: source.toString() !== ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // Downscale at decode time so a 4K JPEG doesn't keep its full pixel
        // buffer in memory just to be blurred for a small screen.
        sourceSize.width: surface.width
        sourceSize.height: surface.height

        // MultiEffect requires the source item to be layered (rendered to an
        // offscreen FBO) before the shader can sample it.
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0          // 0..1 normalized strength
            blurMax: 64        // max kernel radius in px
            blurMultiplier: 1.0
        }
    }

    // Solid background if no wallpaper resolved (parses missing, file gone).
    Rectangle {
        anchors.fill: parent
        visible: !wallpaper.visible
        color: Theme.bg
    }

    // Darkening overlay — pushes contrast for the centered text without
    // hiding the wallpaper entirely. 40 % is a reasonable balance.
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: 0.45
    }

    // ---- Centered content ----
    //
    // Centered Column laid out top-to-bottom:
    //   1. Clock cluster (HH : MM split into 3 Texts; colon dimmed for visual
    //      rhythm; whole cluster drop-shadowed for depth on busy wallpapers).
    //   2. Date.
    //   3. Glassy panel: password input + status text.
    //   4. NowPlayingCard (auto-hides when no MPRIS player).

    Column {
        anchors.centerIn: parent
        spacing: 16

        // ---- Clock cluster ----
        //
        // Wrapped in an Item with explicit size so MultiEffect can layer it
        // and the drop shadow has a fixed bounding box. Three Texts share
        // the shell-wide mono typeface (Iosevka via Theme.fontMono).
        Item {
            id: clockBox
            anchors.horizontalCenter: parent.horizontalCenter
            width: clockRow.width
            height: clockRow.height

            Row {
                id: clockRow
                spacing: 0

                Text {
                    text: Qt.formatDateTime(clock.date, "HH")
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 144
                }
                Text {
                    text: ":"
                    color: Theme.text
                    opacity: 0.35
                    font.family: Theme.fontMono
                    font.pixelSize: 144
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "mm")
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 144
                }
            }

            // Drop shadow under the whole HH:MM cluster. Adds depth on busy
            // wallpapers without darkening the text itself.
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowVerticalOffset: 4
                shadowHorizontalOffset: 0
                shadowBlur: 1.0
                shadowOpacity: 0.45
            }
        }

        // ---- Date ----
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd · MMMM d")
            color: Theme.text
            opacity: 0.85
            font.family: Theme.fontMono
            font.pixelSize: 18
            font.letterSpacing: 0.5
        }

        // ---- Glassy panel: input + status ----
        //
        // Semi-transparent white over the already-blurred wallpaper gives a
        // genuine glass feel; the darker input rectangle inside provides
        // contrast. 360 px wide to match NowPlayingCard below.
        Rectangle {
            id: inputCard
            anchors.horizontalCenter: parent.horizontalCenter
            width: 360
            height: inputCol.height + 32     // 16 px top + bottom padding
            radius: 14
            color: Qt.rgba(1, 1, 1, 0.10)
            border.color: Qt.rgba(1, 1, 1, 0.18)
            border.width: 1

            Column {
                id: inputCol
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 16
                    rightMargin: 16
                }
                spacing: 10

                // Password input box. Dims while PAM is validating so the
                // user can clearly see input was received and no further
                // typing registers until validation finishes.
                Rectangle {
                    id: pwBox
                    width: parent.width
                    height: 40
                    radius: Theme.radiusSmall
                    color: Qt.rgba(0, 0, 0, 0.45)

                    opacity: LockService.pamChecking ? 0.45 : 1.0
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

                    // Border: red while there's an active error message,
                    // accent while focused, otherwise standard border tone.
                    border.width: 1
                    border.color: LockService.pamError.length > 0
                        ? Theme.error
                        : (passField.activeFocus ? Theme.text : Qt.rgba(1, 1, 1, 0.20))
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                    TextInput {
                        id: passField
                        anchors {
                            fill: parent
                            leftMargin: 14
                            rightMargin: 14
                        }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeXL
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        selectByMouse: false
                        clip: true
                        readOnly: LockService.pamChecking
                        Component.onCompleted: forceActiveFocus()

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (!LockService.pamChecking && passField.text.length > 0) {
                                    LockService.respond(passField.text);
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                if (!LockService.pamChecking) passField.text = "";
                                event.accepted = true;
                            }
                        }
                    }
                }

                // Status line — error in red if present (persists across the
                // PAM auto-restart until the user attempts a new password),
                // else the current PAM prompt ("Password:") or "Locked".
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: LockService.pamError.length > 0
                        ? LockService.pamError
                        : (LockService.pamMessage || "Locked")
                    color: LockService.pamError.length > 0
                        ? Theme.errorBright
                        : Theme.text
                    opacity: LockService.pamError.length > 0 ? 1.0 : 0.7
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeNormal
                }
            }
        }

        // ---- Now-playing card (only when MPRIS has an active track) ----
        NowPlayingCard {
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ---- Lifecycle wiring ----
    Connections {
        target: LockService

        // Refocus the input on lock open (covers wake-from-suspend etc.).
        // The compositor will route keys to whichever surface actually
        // holds keyboard focus among the multi-monitor surfaces.
        function onLockedChanged() {
            if (LockService.locked) {
                Qt.callLater(() => passField.forceActiveFocus());
            }
        }

        // PAM rejected the attempt — clear the failed password from the
        // field so the user can immediately type a fresh one. (On success
        // the surface goes away when locked drops to false, so no clear
        // needed there.)
        function onPamErrorChanged() {
            if (LockService.pamError.length > 0) {
                passField.text = "";
                Qt.callLater(() => passField.forceActiveFocus());
            }
        }
    }
}
