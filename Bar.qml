// Bar.qml
// PanelWindow rendered once per monitor (instantiated by Variants in shell.qml).
//
// Auto-hide (BarService.autoHide): the window stays mapped at full height
// but is transparent, and the visible bar is the inner `panel`, which
// slides up out of view when hidden and stops rendering. While hidden the
// input mask is a 2 px strip along the top edge, so the rest of the bar's
// area clicks through to the windows underneath. The bar reserves no
// space then, so windows reach the top edge and the revealed bar draws
// over them. A pinned bar reserves space as usual.
//
// The bar is revealed while any of these hold:
//   - auto-hide is off, or the bar is pinned (qs ipc call bar toggle)
//   - the pointer rested on it for revealDelay ms, until hideDelay ms
//     after it leaves
//   - a popup opened from this bar is still open
//   - the compositor overview is open
//   - this monitor just switched workspace (a short peek)

import QtQuick
import Quickshell
import qs.compositor
import qs.workspaces
import qs.clock
import qs.volume
import qs.tray
import qs.system
import qs.notifications
import qs.media
import qs.controlcenter
import qs.window

PanelWindow {
    id: bar

    required property var modelData // injected by Variants — the ShellScreen

    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight
    // Always transparent: the panel below paints the background. A window
    // that is opaque when first shown cannot turn transparent later
    // (gotcha #80), and auto-hide needs it transparent.
    color: "transparent"
    // The first value has to be the right one. A change that lands just
    // after the surface maps never reaches the compositor, which keeps
    // reserving the old zone (gotcha #82). Local reads the config
    // synchronously so autoHide is already final here.
    exclusiveZone: BarService.autoHide && !BarService.pinned ? 0 : implicitHeight

    // OnDemand only while the Control Center is opening or open. niri
    // gives a popup keyboard focus only if its parent layer surface can
    // take focus (gotcha #79). Permanently OnDemand would let every bar
    // click steal the keyboard from the focused window.
    focusable: controlCenter.wantsKeyboard

    // ---- Auto-hide ----

    readonly property bool revealed: !BarService.autoHide
        || BarService.pinned
        || bar._hoverRevealed
        || bar._popupHold
        || Compositor.overviewOpen
        || peekTimer.running

    // Input region. Explicit geometry rather than `item:`: an item-based
    // region does not always follow its item, and a null item can leave
    // the whole surface taking input (gotcha #81).
    mask: Region {
        width: bar.width
        height: bar.revealed ? bar.implicitHeight : 2
    }

    // Set after the pointer rests on the bar for revealDelay ms, cleared
    // hideDelay ms after it leaves.
    property bool _hoverRevealed: false

    function _onHoveredChanged(hovered) {
        if (hovered) {
            hideTimer.stop();
            if (bar._hoverRevealed) return;
            // Already on screen for another reason (peek, popup, overview):
            // no dwell needed, just keep it.
            if (bar.revealed || BarService.revealDelay === 0) {
                bar._hoverRevealed = true;
                return;
            }
            revealTimer.restart();
        } else {
            revealTimer.stop();
            if (!bar._hoverRevealed) return;
            if (BarService.hideDelay === 0) bar._hoverRevealed = false;
            else hideTimer.restart();
        }
    }

    Timer {
        id: revealTimer
        interval: BarService.revealDelay
        onTriggered: bar._hoverRevealed = true
    }

    Timer {
        id: hideTimer
        interval: BarService.hideDelay
        onTriggered: bar._hoverRevealed = false
    }

    // A popup anchored in this bar keeps it revealed, or the popup would
    // hang under an empty strip. PopupController holds either the popup
    // window (anchored to one of our items) or, for the tray, the tray
    // item itself. Centred popups register their service singleton and
    // never match.
    readonly property bool _popupHold: {
        if (centerSection.popupOpen) return true;
        const p = PopupController.activePopup;
        if (!p) return false;
        const item = p.anchor !== undefined && p.anchor.item ? p.anchor.item : p;
        for (let q = item; q; q = q.parent) if (q === content) return true;
        return false;
    }

    // Workspace peek: reveal for a moment when this monitor's active
    // workspace changes, so you can see where you landed. The first value
    // after startup is not a switch.
    readonly property int _activeWorkspaceId: {
        const list = Compositor.workspaces;
        for (let i = 0; i < list.length; i++) {
            if (list[i].output === bar.modelData.name && list[i].is_active) return list[i].id;
        }
        return -1;
    }
    property int _lastWorkspaceId: -1
    on_ActiveWorkspaceIdChanged: {
        const previous = bar._lastWorkspaceId;
        bar._lastWorkspaceId = bar._activeWorkspaceId;
        if (previous === -1 || bar._activeWorkspaceId === -1) return;
        if (BarService.autoHide && BarService.peekOnWorkspaceSwitch) peekTimer.restart();
    }

    Timer {
        id: peekTimer
        interval: 1500
    }

    // ---- Content ----

    // Hover detection for the whole window. A parent MouseArea stays
    // containsMouse while the pointer is over the widgets' own hover-enabled
    // MouseAreas, which is the pattern illogical-impulse ships for its
    // auto-hiding bar. Qt.NoButton so it never takes a click.
    MouseArea {
        id: content
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onContainsMouseChanged: bar._onHoveredChanged(containsMouse)

        Rectangle {
            id: panel
            width: parent.width
            height: bar.implicitHeight
            y: bar.revealed ? 0 : -height
            // Fully slid out: stop rendering, so the strip is transparent.
            visible: y > -height
            color: Theme.bg
            Behavior on y { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

            // Bottom border
            Rectangle {
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                }
                height: 1
                color: Theme.border
            }

            // Left section
            Workspaces {
                id: leftSection
                output: bar.screen.name
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 12
                }
            }

            // Center section
            Clock {
                id: centerSection
                anchors.centerIn: parent
            }

            // Focused window title, filling whatever is left between the workspaces
            // and the centred clock. Anchored on both sides rather than given a
            // width: that gap is what bounds the elide, and it differs per monitor.
            ActiveWindow {
                anchors {
                    left: leftSection.right
                    right: centerSection.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 14
                    rightMargin: 14
                }
            }

            // Right section. Flat layout: every widget has the same gap to its
            // neighbour. No groups, no separators.
            Row {
                id: rightSection
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: 12
                }
                spacing: 14

                // Five widgets (IdleInhibit, PowerProfile, Network, Bluetooth,
                // Wallpaper) moved into the Control Center to declutter the bar.
                // Their interactions live behind the CC tile grid; their state
                // is still surfaced via the same underlying services.
                Notifications  { anchors.verticalCenter: parent.verticalCenter }
                TrayCollapser  { anchors.verticalCenter: parent.verticalCenter }
                Media          { anchors.verticalCenter: parent.verticalCenter }
                Battery        { anchors.verticalCenter: parent.verticalCenter }
                Brightness     { anchors.verticalCenter: parent.verticalCenter }
                // Left of Volume deliberately: Microphone is intermittent, so the
                // always-present Volume icon would shift sideways if it sat after it.
                Microphone     { anchors.verticalCenter: parent.verticalCenter }
                Volume            { anchors.verticalCenter: parent.verticalCenter }
                CaffeineIndicator { anchors.verticalCenter: parent.verticalCenter }
                ControlCenter     { id: controlCenter; anchors.verticalCenter: parent.verticalCenter }
                Power             { anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
}
