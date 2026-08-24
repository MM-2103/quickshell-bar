// PolkitDialog.qml
// Authentication prompt for PolkitService. One panel per monitor, visible
// only on the focused one — same pattern as Launcher / ClipboardPopup.
//
// Overlay layer with Exclusive keyboard focus: an auth prompt must be able
// to take every keystroke, including plain letters, away from whatever was
// focused. Clicking outside deliberately does NOT dismiss — losing a
// half-typed password to a stray click is worse than having to press Escape.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs
import qs.polkit

PanelWindow {
    id: panel

    required property var modelData
    required property string focusedOutput

    screen: modelData

    readonly property bool isFocusedScreen:
        modelData && modelData.name === focusedOutput
    readonly property bool wantOpen:
        PolkitService.dialogVisible && isFocusedScreen

    visible: wantOpen || hideHold.running
    Timer { id: hideHold; interval: 180; repeat: false }
    onWantOpenChanged: {
        if (wantOpen) {
            hideHold.stop();
            // Deferred: forceActiveFocus() on an item whose window is not yet
            // mapped silently does nothing, and the binding that decides
            // whether the field exists has not settled yet either.
            Qt.callLater(() => passField.forceActiveFocus());
        } else {
            hideHold.restart();
            passField.text = "";
            panel.clearCancelConfirm();
        }
    }

    // ---- Two-step cancel ----
    //
    // Abandoning a polkit prompt is not free: polkit-agent-helper-1 has
    // already started the PAM conversation, so cancelling makes pam_unix
    // fail and pam_faillock counts it. At the default deny=3 that means
    // three stray Escapes lock you out of the machine, TTYs included, for
    // unlock_time. Nothing in the polkit API lets us avoid the strike, so
    // the least we can do is not spend one on a mistaken keypress.
    //
    // Same 3-second confirm idiom as the power menu's Reboot / Shutdown.
    property bool confirmingCancel: false
    Timer {
        id: cancelConfirm
        interval: 3000
        repeat: false
        onTriggered: panel.confirmingCancel = false
    }

    function handleEscape() {
        if (panel.confirmingCancel) {
            cancelConfirm.stop();
            panel.confirmingCancel = false;
            PolkitService.cancel();
            return;
        }
        panel.confirmingCancel = true;
        cancelConfirm.restart();
    }

    // Typing means they did not mean to cancel after all.
    function clearCancelConfirm() {
        if (!panel.confirmingCancel) return;
        cancelConfirm.stop();
        panel.confirmingCancel = false;
    }

    // Re-focus whenever PAM asks for input again (second stage, or a retry
    // after a failure took focus away).
    Connections {
        target: PolkitService
        function onResponseRequiredChanged() {
            if (PolkitService.responseRequired && panel.wantOpen)
                Qt.callLater(() => passField.forceActiveFocus());
        }
        function onFailed() {
            passField.text = "";
            panel.clearCancelConfirm();
            shake.restart();
            Qt.callLater(() => passField.forceActiveFocus());
        }
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors { top: true; bottom: true; left: true; right: true }

    // Full-screen scrim. Also swallows every click, so nothing behind the
    // prompt is reachable while it is up.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.5)
        opacity: panel.wantOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            // Refocus rather than dismiss — see the file header.
            onClicked: passField.forceActiveFocus()
        }
    }

    Item {
        id: card
        anchors.centerIn: parent
        width: 380
        height: column.implicitHeight + 40

        opacity: panel.wantOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        property real shakeOffset: 0
        transform: Translate { x: card.shakeOffset }

        SequentialAnimation {
            id: shake
            NumberAnimation { target: card; property: "shakeOffset"; to: -8; duration: 35; easing.type: Easing.OutQuad }
            NumberAnimation { target: card; property: "shakeOffset"; to:  8; duration: 50; easing.type: Easing.InOutQuad }
            NumberAnimation { target: card; property: "shakeOffset"; to:  0; duration: 55; easing.type: Easing.OutQuad }
        }

        Rectangle {
            id: cardBg
            anchors.fill: parent
            color: Theme.bg
            radius: Theme.radius
            border.width: 1
            border.color: PolkitService.errorFlash ? Theme.error : Theme.border
            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.45)
                shadowBlur: 0.6
                shadowVerticalOffset: 4
            }
        }

        Column {
            id: column
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 20; rightMargin: 20
            }
            spacing: 14

            Row {
                spacing: 12
                width: parent.width

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf023"                       // lock
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontSizeXL
                    color: PolkitService.errorFlash ? Theme.errorBright : Theme.accent
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                Column {
                    width: parent.width - 12 - 20
                    spacing: 2

                    Text {
                        text: "Authentication required"
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        text: PolkitService.message
                        color: Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }
                }
            }

            // ---- Password field ----
            Rectangle {
                width: parent.width
                height: 40
                radius: Theme.radiusSmall
                color: Theme.surface
                border.width: 1
                border.color: PolkitService.errorFlash ? Theme.error
                    : (passField.activeFocus ? Theme.accent : Theme.border)
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                opacity: PolkitService.submitted ? 0.5 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

                TextInput {
                    id: passField
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeNormal
                    echoMode: PolkitService.responseVisible
                        ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "●"
                    selectByMouse: false
                    clip: true
                    // Inert while PAM is checking and during the error flash,
                    // so a submission in flight cannot be typed into.
                    readOnly: PolkitService.submitted || PolkitService.errorFlash

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (!passField.readOnly && passField.text.length > 0) {
                                PolkitService.respond(passField.text);
                                passField.text = "";
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            // Duplicated from the key catcher below: while the
                            // field has focus that catcher never sees keys.
                            panel.handleEscape();
                            event.accepted = true;
                        } else {
                            panel.clearCancelConfirm();
                        }
                    }
                }

                Text {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: PolkitService.errorFlash ? "Authentication failed"
                        : (PolkitService.submitted ? "Checking…" : PolkitService.prompt)
                    color: PolkitService.errorFlash ? Theme.errorBright : Theme.textMuted
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeNormal
                    visible: passField.text.length === 0
                }
            }

            // Hint line. Turns into the cancel confirmation, and says why
            // rather than just asking again — "press it twice" reads as
            // pointless friction unless you know a stray Escape costs a
            // failed-login strike.
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignRight
                text: panel.confirmingCancel
                    ? "Esc again to cancel — counts as a failed attempt"
                    : "Enter to confirm · Esc to cancel"
                color: panel.confirmingCancel ? Theme.errorBright : Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }
        }

        // Catches Escape in the window that the field does not have focus —
        // most notably while PAM is checking, when focus is parked here.
        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: !passField.activeFocus
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    panel.handleEscape();
                    event.accepted = true;
                }
            }
        }
    }
}
