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
import qs.settings.controls
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

        // Esc closes — picker first if it's open, then the popup.
        Item {
            id: keyTarget
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    if (SettingsService.pickerOpen) {
                        SettingsService.closePicker();
                    } else {
                        SettingsService.closePopup();
                    }
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

        // ================================================================
        // Shared ColorPicker — one instance, owned by the card AFTER the
        // Column so it always renders on top of every settings row. Its
        // position tracks whichever swatch most recently invoked it via
        // SettingsService.openPicker().
        // ================================================================
        //
        // Why this lives here (and not inside ColorRow): in QML the z
        // property only orders SIBLINGS within the same parent. A picker
        // declared as a child of ColorRow A would be drawn before the
        // next sibling ColorRow B regardless of z, because A's full
        // subtree is rendered before B's full subtree. Hoisting the
        // picker up to be a sibling of the Column (and declaring it
        // AFTER the Column) is the only reliable way to put it visually
        // above all rows.
        //
        // Click-outside dismiss: a transparent MouseArea covers the
        // entire card *behind* the picker. Click anywhere outside the
        // picker's bounding box → close. Picker itself catches the click
        // before the MouseArea sees it (z order).
        MouseArea {
            id: pickerOutsideCatcher
            anchors.fill: parent
            visible: SettingsService.pickerOpen
            z: 999
            // Don't change cursor — make the click-to-dismiss feel like
            // an empty area, not an interactive zone.
            onPressed: function(mouse) {
                // If the click is within the picker's bounds, ignore —
                // let the picker handle it.
                const px = pickerOverlay.x;
                const py = pickerOverlay.y;
                const pw = pickerOverlay.width;
                const ph = pickerOverlay.height;
                if (mouse.x >= px && mouse.x <= px + pw
                    && mouse.y >= py && mouse.y <= py + ph) {
                    mouse.accepted = false;   // pass through
                    return;
                }
                SettingsService.closePicker();
                mouse.accepted = true;
            }
        }

        ColorPicker {
            id: pickerOverlay
            z: 1000
            // Driven entirely by SettingsService — `open` is the
            // public visibility binding, currentColor reflects the
            // active swatch's value, and `colorPicked` writes back via
            // Local.set keyed on pickerKey.
            open: SettingsService.pickerOpen
            currentColor: SettingsService.pickerColor
            onColorPicked: c => {
                if (SettingsService.pickerKey)
                    Local.set(SettingsService.pickerKey, c);
            }

            // Position: anchored under the swatch that triggered the
            // picker, in card-relative coordinates. mapToItem returns a
            // point in the target item's coordinate system; we use that
            // directly for x/y, then offset by the anchor's height + a
            // small gap. If the anchor is null (no picker open), default
            // to (0,0) — invisible anyway.
            //
            // We CLAMP the right edge so the picker never extends past
            // the card's right margin (would cut off "Done"). If the
            // swatch is far right, the picker shifts left to fit.
            x: {
                if (!SettingsService.pickerAnchor) return 0;
                const p = SettingsService.pickerAnchor.mapToItem(card, 0, 0);
                const maxX = card.width - width - 16;
                return Math.max(16, Math.min(p.x, maxX));
            }
            y: {
                if (!SettingsService.pickerAnchor) return 0;
                const p = SettingsService.pickerAnchor.mapToItem(card, 0, 0);
                const proposed = p.y + SettingsService.pickerAnchor.height + 6;
                const maxY = card.height - height - 16;
                // If the natural position pushes off the bottom, place
                // ABOVE the swatch instead. Common case for swatches near
                // the bottom of the visible area.
                if (proposed > maxY) {
                    return Math.max(16, p.y - height - 6);
                }
                return proposed;
            }
        }

        // Close the picker on any tab change OR scroll — the swatch
        // anchor's coordinates would otherwise drift relative to the
        // card and the picker would float away from where the user
        // clicked.
        Connections {
            target: SettingsService
            function onActiveTabChanged() { SettingsService.closePicker(); }
        }
        Connections {
            target: contentFlick
            function onContentYChanged() {
                // Only close if the user is actively scrolling — small
                // contentY changes from layout settling shouldn't dismiss.
                if (contentFlick.moving) SettingsService.closePicker();
            }
        }
    }
}
