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
        if (wantOpen)             hideHold.stop();
        else if (!_dismissing)    hideHold.restart();
    }

    // The Wi-Fi password field needs keyboard input, and niri only gives
    // an xdg_popup keyboard focus when two things hold. The popup takes a
    // grab, and the layer surface it hangs off (the bar) has keyboard
    // interactivity other than None when the grab arrives. Otherwise
    // niri hands out a pointer-only grab. See gotcha #79.
    grabFocus: true

    // Bar.qml binds its `focusable` to this. True from the click that
    // opens the CC until the surface is gone, and False the rest of the
    // time, so clicking a workspace chip never steals the keyboard.
    property bool wantsKeyboard: false

    // Quickshell applies the bar's new interactivity on its next polish
    // and commit. The popup must not map, and ask for its grab, before
    // that commit reaches niri, so the open waits a few frames.
    Timer {
        id: openDelay
        interval: 60
        onTriggered: {
            PopupController.open(popup, () => popup.wantOpen = false);
            // Reset the view so each open starts at the tile grid.
            ControlCenterService.resetView();
            popup.wantOpen = true;
        }
    }

    // Set while we sync wantOpen after an external dismissal, so the
    // fade-out hold does not map the surface again for 180 ms.
    property bool _dismissing: false
    // When the last external dismissal happened. A click on the CC bar
    // button dismisses the popup on press, then toggles on release;
    // without this the popup would close and immediately reopen.
    property real _dismissedAt: 0

    function toggle() {
        if (popup.wantOpen) {
            popup.wantOpen = false;
        } else if (openDelay.running) {
            openDelay.stop();
            popup.wantsKeyboard = false;
        } else {
            if (Date.now() - popup._dismissedAt < 300) return;
            popup.wantsKeyboard = true;
            openDelay.restart();
        }
    }
    function close() {
        popup.wantOpen = false;
        if (openDelay.running) {
            openDelay.stop();
            popup.wantsKeyboard = false;
        }
    }
    onVisibleChanged: {
        if (visible) return;
        // wantOpen still true means we did not close it ourselves: the
        // grab ended (outside click, Escape, compositor). Sync state.
        if (wantOpen) {
            _dismissedAt = Date.now();
            _dismissing = true;
            wantOpen = false;
            _dismissing = false;
        }
        wantsKeyboard = false;
        PopupController.closed(popup);
    }

    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? -((popup.width - anchorItem.width) / 2) : 0
    anchor.rect.y: anchorItem ? anchorItem.height + 6 - 12 : 0
    anchor.adjustment: PopupAdjustment.SlideX

    // 440 wide × 520 tall. Height bumped from 440 → 520 to make room
    // for the third tile row (Theme toggle added in the light/dark
    // toggle work) — 64 px tile + 12 px Column spacing = 76 px of
    // additional content that previously caused the NowPlayingCard at
    // the bottom of the Column to clip below the popup boundary.
    // Detail views (Network, Bluetooth, Cities) still scroll internally
    // when their list overflows.
    implicitWidth:  440 + 24  // 24 = shadow padding (12 each side)
    implicitHeight: 520 + 24

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
                // Horizontal margin bumped from 14 → 22 so the Now Playing
                // card (which fills the inner width) has visible breathing
                // room between its rightmost media-control button and the
                // popup card edge. Iterated up after a 18 px attempt still
                // read as cramped against the wallpaper. The tile grid
                // reflows automatically — _tileWidth in TilesView is
                // computed from the available width.
                margins: 22
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
