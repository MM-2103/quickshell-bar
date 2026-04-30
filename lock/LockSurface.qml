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
        source: LockService.wallpaperPath
        visible: source !== ""
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

    Column {
        anchors.centerIn: parent
        spacing: 18
        width: 360

        // Clock — large, monospace so digits don't shift width as time changes.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.text
            font.pixelSize: 96
            font.family: "monospace"
            font.weight: Font.Light
        }

        // Date — secondary, dim.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
            color: Theme.text
            opacity: 0.85
            font.pixelSize: 16
        }

        // Spacer.
        Item { width: 1; height: 14 }

        // Password input box. Whole row dims to 0.45 opacity while PAM is
        // validating — the user can clearly see their input was received
        // and that no further typing will register until validation ends.
        Rectangle {
            id: pwBox
            width: parent.width
            height: 44
            radius: Theme.radiusSmall
            color: Qt.rgba(0, 0, 0, 0.55)

            opacity: LockService.pamChecking ? 0.45 : 1.0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

            // Border colour: red while there's an active error message,
            // accent while focused, otherwise the standard border tone.
            // Error persists until the user submits a new attempt.
            border.width: 1
            border.color: LockService.pamError.length > 0
                ? "#ff5050"
                : (passField.activeFocus ? Theme.text : Theme.border)
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
                font.pixelSize: 16
                echoMode: TextInput.Password
                passwordCharacter: "●"
                selectByMouse: false
                clip: true
                // Lock the input while PAM is validating. Using readOnly
                // (vs. enabled:false) keeps the cursor and visual styling
                // intact — combined with the parent's opacity dim, this
                // reads as "input is paused, please wait".
                readOnly: LockService.pamChecking
                // Always grab focus when this surface becomes visible.
                Component.onCompleted: forceActiveFocus()

                // Submit on Enter; Esc clears the field; everything else
                // types as normal. Field is NOT cleared on submit — the
                // dots stay visible while PAM validates so the user knows
                // exactly what they sent. Field clears on PAM result
                // (failure → error handler below; success → surface goes
                // away when locked drops to false).
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
        // PAM auto-restart until the user attempts a new password), else
        // the current PAM prompt ("Password:") or "Locked" as fallback.
        // No "Checking…" state: PAM's blocking validation can be retried
        // mid-flight (response is queued in LockService), so showing a
        // wait state would mislead users into thinking they had to wait.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: LockService.pamError.length > 0
                ? LockService.pamError
                : (LockService.pamMessage || "Locked")
            color: LockService.pamError.length > 0
                ? "#ff7070"
                : Theme.text
            opacity: LockService.pamError.length > 0 ? 1.0 : 0.7
            font.pixelSize: 12
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
