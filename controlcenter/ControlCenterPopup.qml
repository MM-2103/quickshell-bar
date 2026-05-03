// ControlCenterPopup.qml
// The single anchored popup behind the bar's CC trigger. Hosts a fixed-
// size 440 × 440 card whose interior is a Loader keyed on
// ControlCenterService.currentView. Detail views (network/bluetooth/
// powerprofile/cities) get a back-arrow header that returns to the
// tiles view.
//
// Why fixed size: detail views (especially Network) can grow tall; we
// scroll inside the view rather than animating popup height per swap
// — animated height changes feel janky during fast tile clicking, and
// also ripple into the anchor positioning.

import QtQuick
import QtQuick.Effects
import Quickshell
import qs
import qs.controlcenter
import qs.network
import qs.bluetooth
import qs.system
import qs.weather
import qs.settings

PopupWindow {
    id: popup

    required property Item anchorItem

    color: "transparent"

    // Standard popup recipe — wantOpen lives per-popup (matches
    // BrightnessPopup, NetworkPopup, etc.) so on multi-monitor setups
    // only the bar instance the user actually clicked shows the CC.
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
            // Reset the view so each open starts at the tile grid.
            ControlCenterService.resetView();
            popup.wantOpen = true;
        }
    }
    function close() { popup.wantOpen = false; }
    onVisibleChanged: if (!visible) PopupController.closed(popup)

    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? -((popup.width - anchorItem.width) / 2) : 0
    anchor.rect.y: anchorItem ? anchorItem.height + 6 - 12 : 0
    anchor.adjustment: PopupAdjustment.SlideX

    // 440 wide × 440 tall. Width still gives tile state strings room to
    // breathe; the extra 40 px of height (was 400) makes room for the
    // weather card sitting between the tile grid and NowPlayingCard.
    // Detail views (Network, Bluetooth, Cities) still scroll internally
    // when their list overflows.
    implicitWidth:  440 + 24  // 24 = shadow padding (12 each side)
    implicitHeight: 440 + 24

    // ---- Card surface ----
    Rectangle {
        id: card
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

        // ---- Header ----
        //
        // In tiles view: just the title "Control Center".
        // In a detail view: back arrow + view title.
        Item {
            id: header
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 14
            }
            height: 22

            // Back button — only visible when in a detail view.
            Rectangle {
                id: backBtn
                visible: ControlCenterService.currentView !== "tiles"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 26; height: 22
                radius: Theme.radiusSmall
                color: backMa.containsMouse ? Theme.surfaceHi : Theme.surface
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    // FA Solid \uf060 arrow-left
                    text: "\uf060"
                    color: Theme.text
                    font.family: Theme.fontIcon
                    font.styleName: "Solid"
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: backMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ControlCenterService.goBack()
                }
            }

            Text {
                anchors {
                    left: backBtn.visible ? backBtn.right : parent.left
                    leftMargin: backBtn.visible ? 8 : 0
                    verticalCenter: parent.verticalCenter
                }
                text: {
                    switch (ControlCenterService.currentView) {
                    case "network":      return "Wi-Fi";
                    case "bluetooth":    return "Bluetooth";
                    case "powerprofile": return "Power Profile";
                    case "cities":       return "Choose city";
                    default:             return "Control Center";
                    }
                }
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeNormal
                font.weight: Font.Bold
            }

            // ---- Settings gear (top-right of header) ----
            //
            // Visible only on the tiles view — when the user has drilled
            // into a detail view, the right-edge real estate is for view-
            // specific actions (none currently, but keeping the slot
            // available avoids cluttering the back-arrow flow). Click
            // closes CC and opens the Settings popup.
            Rectangle {
                id: settingsBtn
                visible: ControlCenterService.currentView === "tiles"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 26; height: 22
                radius: Theme.radiusSmall
                color: settingsMa.containsMouse ? Theme.surfaceHi : Theme.surface
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                // FA Solid \uf013 cog
                Text {
                    anchors.centerIn: parent
                    text: "\uf013"
                    color: Theme.text
                    font.family: Theme.fontIcon
                    font.styleName: "Solid"
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: settingsMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SettingsService.openPopup()
                }
            }
        }

        // ---- View body ----
        //
        // Loader keyed on a separate `_appliedView` property rather than
        // ControlCenterService.currentView directly. This indirection lets
        // us drive a SequentialAnimation (fade-out → swap → fade-in) when
        // the user navigates between views, while still re-using the
        // current view's content immediately on a fresh open (no flicker).
        //
        // `Behavior on sourceComponent` doesn't work — Component is not a
        // numeric type. The script-action animation is the standard
        // workaround for view-stack crossfades.
        Loader {
            id: viewLoader
            anchors {
                top: header.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 14
                topMargin: 10
            }

            // Mirrors currentView, but only updates inside the transition
            // animation's ScriptAction so the swap happens at opacity 0.
            property string _appliedView: ControlCenterService.currentView

            sourceComponent: {
                switch (_appliedView) {
                case "network":      return networkViewC;
                case "bluetooth":    return bluetoothViewC;
                case "powerprofile": return powerProfileViewC;
                case "cities":       return citiesViewC;
                default:             return tilesViewC;
                }
            }

            opacity: 1.0

            // Cross-fade swap when the user navigates. Skipped if the
            // popup isn't open (e.g. resetView() called by toggle()
            // before fade-in starts) — in that case sync immediately
            // so the next open shows the right view from the first frame.
            Connections {
                target: ControlCenterService
                function onCurrentViewChanged() {
                    if (ControlCenterService.currentView === viewLoader._appliedView)
                        return;
                    if (!popup.wantOpen) {
                        viewLoader._appliedView = ControlCenterService.currentView;
                        return;
                    }
                    transition.restart();
                }
            }

            SequentialAnimation {
                id: transition
                NumberAnimation {
                    target: viewLoader; property: "opacity"
                    to: 0.0; duration: 100; easing.type: Easing.InCubic
                }
                ScriptAction {
                    script: viewLoader._appliedView = ControlCenterService.currentView
                }
                NumberAnimation {
                    target: viewLoader; property: "opacity"
                    to: 1.0; duration: 140; easing.type: Easing.OutCubic
                }
            }
        }

        Component { id: tilesViewC;        TilesView { } }
        Component { id: networkViewC;      NetworkView { } }
        Component { id: bluetoothViewC;    BluetoothView { } }
        Component { id: powerProfileViewC; PowerProfileView { } }
        Component { id: citiesViewC;       CitiesView { } }
    }
}
