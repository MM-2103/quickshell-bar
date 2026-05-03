// SettingsPopup.qml
// Centered Overlay-layer popup that visually edits the user's
// `~/.config/quickshell-bar/config.jsonc` overrides. Triggered by the
// gear icon in the Control Center header (and via `qs ipc call settings
// open|toggle`).
//
// Per-monitor Variants pattern (mirrors WallpaperPickerPopup): one
// instance per screen, gated visible on
// `SettingsService.popupOpen && isFocusedScreen`. Esc closes. Standard
// popup recipe (wantOpen + hideHold + fade + MultiEffect shadow).
//
// Layout: header (title + actions) → tabs → scrolling content area
// keyed on `SettingsService.activeTab`. Sections that overflow scroll
// internally; the popup itself stays at fixed 840 × 600.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs
import qs.settings
import qs.settings.sections

PanelWindow {
    id: panel

    required property var modelData
    required property string focusedOutput

    screen: modelData

    readonly property bool isFocusedScreen:
        modelData && modelData.name === focusedOutput
    readonly property bool wantOpen:
        SettingsService.popupOpen && isFocusedScreen

    visible: wantOpen || hideHold.running
    Timer { id: hideHold; interval: 180; repeat: false }
    onWantOpenChanged: {
        if (wantOpen) hideHold.stop();
        else          hideHold.restart();
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    implicitWidth:  840 + 24    // 24 = shadow padding
    implicitHeight: 600 + 24

    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: 12

        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

        opacity: panel.wantOpen ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        transform: Translate {
            y: panel.wantOpen ? 0 : 4
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

        // Esc closes.
        Item {
            id: keyTarget
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    SettingsService.closePopup();
                    event.accepted = true;
                }
            }
        }
        onVisibleChanged: if (visible) Qt.callLater(() => keyTarget.forceActiveFocus())

        // ================================================================
        // Body
        // ================================================================
        Column {
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 12

            SettingsHeader {
                width: parent.width
            }

            // 1 px divider under header
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
                opacity: 0.5
            }

            SettingsTabs {
                anchors.left: parent.left
            }

            // 1 px divider under tabs
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
                opacity: 0.5
            }

            // ---- scrollable section content ----
            Flickable {
                id: contentFlick
                width: parent.width
                // Fill remaining vertical space inside the Column. Computed
                // as: card height (600) - margins (32) - header (28) -
                // divider (1) - tabs (24) - divider (1) - 4 × spacing (12)
                // ≈ 466. Use a binding so it stays correct if the popup
                // is resized later.
                height: card.height - 16 * 2 - 28 - 24 - 1 - 1 - 12 * 4
                contentWidth: width
                contentHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Loader {
                    id: contentLoader
                    width: parent.width
                    sourceComponent: {
                        switch (SettingsService.activeTab) {
                            case "typography": return typographyComp;
                            case "layout":     return layoutComp;
                            case "behavior":   return behaviorComp;
                            default:           return colorsComp;
                        }
                    }
                    // Reset scroll to top on tab change so each section
                    // starts at its first row (otherwise scrolling deep
                    // in Colours and switching to Behaviour leaves a
                    // confusing offset).
                    onSourceComponentChanged: contentFlick.contentY = 0
                }
            }
        }

        Component { id: colorsComp;     ColorsSection { } }
        Component { id: typographyComp; TypographySection { } }
        Component { id: layoutComp;     LayoutMotionSection { } }
        Component { id: behaviorComp;   BehaviorSection { } }
    }
}
