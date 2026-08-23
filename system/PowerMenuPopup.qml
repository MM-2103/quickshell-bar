// PowerMenuPopup.qml
// wlogout-style horizontal row of round buttons.
// Shutdown and Reboot require a second click to confirm (3 s timeout);
// Lock, Suspend, and Logout fire immediately. Clicking any non-confirm
// button while confirming cancels the pending confirm.

import QtQuick
import QtQuick.Effects
import Quickshell
import qs
import qs.compositor
import qs.lock

PopupWindow {
    id: popup

    required property Item anchorItem

    color: "transparent"

    property bool wantOpen: false
    visible: wantOpen || hideHold.running
    Timer { id: hideHold; interval: 180; repeat: false }
    onWantOpenChanged: {
        if (wantOpen) hideHold.stop();
        else          hideHold.restart();
    }

    function toggle() {
        if (popup.wantOpen) {
            popup.wantOpen = false;
        } else {
            PopupController.open(popup, () => popup.wantOpen = false);
            popup.wantOpen = true;
        }
    }
    function close()  { popup.wantOpen = false; }
    onVisibleChanged: if (!visible) PopupController.closed(popup)

    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? -((popup.width - anchorItem.width) / 2) : 0
    anchor.rect.y: anchorItem ? anchorItem.height + 6 - 12 : 0
    anchor.adjustment: PopupAdjustment.SlideX

    implicitWidth: container.implicitWidth + 24
    implicitHeight: container.implicitHeight + 24

    // Centralized action runner: fires the command and closes the popup.
    function _run(args) {
        Quickshell.execDetached(args);
        popup.close();
    }

    // ---- Confirmation state (Shutdown / Reboot) ----
    // Only one action can be in confirm state at a time. A 3-second timer
    // resets it; clicking any other button also cancels.
    property string confirmingAction: ""
    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: popup.confirmingAction = ""
    }

    Rectangle {
        id: container
        anchors.fill: parent
        anchors.margins: 12
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

        opacity: popup.wantOpen ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        transform: Translate {
            y: popup.wantOpen ? 0 : 4
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

        implicitWidth: row.implicitWidth + 16
        implicitHeight: row.implicitHeight + 16

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            // ============================================================
            // Inline button component — round disk + Font Awesome glyph
            // + label. The disk inverts on hover (white fill, dark glyph)
            // for a clear "primary action" feel.
            // ============================================================
            component PowerButton: MouseArea {
                id: btn
                property string label
                property string glyph         // Font Awesome 7 Solid codepoint
                property var onActivate       // function to call
                property string confirmAction: ""  // set to "reboot"/"shutdown" for two-step

                readonly property bool isConfirming:
                    btn.confirmAction !== "" && popup.confirmingAction === btn.confirmAction

                width: 56
                height: 64
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    if (btn.isConfirming) {
                        // Second click — execute.
                        btn.onActivate();
                    } else if (btn.confirmAction !== "") {
                        // First click — enter confirm state.
                        popup.confirmingAction = btn.confirmAction;
                        confirmTimer.restart();
                    } else {
                        // Non-confirm button — execute immediately,
                        // cancelling any pending confirm.
                        popup.confirmingAction = "";
                        btn.onActivate();
                    }
                }

                Column {
                    anchors.fill: parent
                    spacing: 4

                    // Round icon disk — turns red when confirming.
                    Item {
                        width: 44
                        height: 44
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: btn.isConfirming ? Theme.error
                                 : (btn.containsMouse ? Theme.text : Theme.surface)
                            border.color: Theme.border
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }

                        // Glyph — Font Awesome 7 Solid. Inverts to dark on
                        // hover so it stays readable on the white disk.
                        Text {
                            anchors.centerIn: parent
                            text: btn.glyph
                            color: (btn.isConfirming || btn.containsMouse) ? Theme.bg : Theme.text
                            font.family: Theme.fontIcon
                            font.styleName: "Solid"
                            font.pixelSize: 18
                            renderType: Text.NativeRendering
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: btn.isConfirming ? "Confirm?" : btn.label
                        color: btn.isConfirming ? Theme.errorBright : Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }
                }
            }

            // ============================================================
            // The five buttons. Glyphs (Font Awesome 7 Solid):
            //   \uf023 lock          \uf186 moon       \uf2f5 right-from-bracket
            //   \uf021 arrows-rotate \uf011 power-off
            // ============================================================
            PowerButton {
                label: "Lock"
                glyph: "\uf023"
                // Calls the service directly rather than shelling out to
                // `loginctl lock-session`. That command only flips logind's
                // LockedHint; WlSessionLock doesn't subscribe to the Lock
                // signal, so it never locked us on its own — it worked only
                // because hypridle happened to bridge the signal back into
                // our lock IPC. With hypridle gone that bridge went with it.
                //
                // Nothing is lost by going direct: WlSessionLock sets
                // LockedHint itself when `locked` flips, so logind still
                // learns the session is locked. SleepService separately
                // honours the inbound Lock signal for external callers.
                onActivate: () => { LockService.lock(); popup.close(); }
            }
            PowerButton {
                label: "Suspend"
                glyph: "\uf186"
                onActivate: () => popup._run(["systemctl", "suspend"])
            }
            PowerButton {
                label: "Logout"
                glyph: "\uf2f5"
                onActivate: () => {
                    // Default is whatever ending the session means to the
                    // running compositor. That is wrong when a session manager
                    // owns the lifecycle — uwsm needs `uwsm stop`, since
                    // killing the compositor directly skips its ordered
                    // shutdown — so allow an override rather than guessing.
                    const cmd = Local.get("logoutCommand", "");
                    if (cmd.length > 0) {
                        popup._run(["sh", "-c", cmd]);
                        return;
                    }
                    Compositor.dispatchLogout();
                    popup.close();
                }
            }
            PowerButton {
                label: "Reboot"
                glyph: "\uf021"
                confirmAction: "reboot"
                onActivate: () => popup._run(["systemctl", "reboot"])
            }
            PowerButton {
                label: "Shutdown"
                glyph: "\uf011"
                confirmAction: "shutdown"
                onActivate: () => popup._run(["systemctl", "poweroff"])
            }
        }
    }
}
