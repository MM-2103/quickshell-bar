// ColorRow.qml
// Setting row for a colour value. Three pieces, left-to-right inside
// the SettingRow content area:
//
//   ┌─────────────────────────────────────────┐
//   │ Label   #16181c        [ ▮ swatch ]  ↺  │
//   └─────────────────────────────────────────┘
//
// The hex TextInput accepts `#rrggbb` (or six chars without `#`) and
// live-applies via `Local.set()` once it parses to a valid colour. The
// swatch is a small clickable rectangle; clicking it asks the
// SettingsService to open the shared ColorPicker (anchored to the
// swatch). The picker is a single instance owned by SettingsPopup —
// embedding it per-row would lose to QML's sibling z-ordering (later-
// declared sibling Rows in the Column draw over a child popup
// extending below its parent's bounds, regardless of z).

import QtQuick
import qs
import qs.settings

SettingRow {
    id: row

    // Default colour shown when no override is present.
    property color defaultValue: "#000000"

    readonly property color currentValue:
        Local.get(row.settingKey, row.defaultValue)

    // Hex string for the input field. Computed from currentValue and
    // re-applied if the user types something invalid (so the field
    // can't drift off the current state). The QML `color` type's
    // toString() returns "#aarrggbb" — we strip the alpha byte to
    // present a plain "#rrggbb" since we don't expose alpha overrides.
    readonly property string _currentHex: {
        const s = ("" + row.currentValue).toLowerCase();
        if (s.length === 9 && s.charAt(0) === "#") {
            // "#aarrggbb" → "#rrggbb"
            return "#" + s.substr(3);
        }
        return s;
    }

    // Hex regex — accepts "#rrggbb" or "rrggbb"; case-insensitive.
    readonly property var _hexRe: /^#?([0-9a-fA-F]{6})$/

    Rectangle {
        id: hexBox
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 100
        height: 24
        radius: Theme.radiusSmall
        color: Theme.bg
        border.color: input.activeFocus ? Theme.text : Theme.border
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: TextInput.AlignVCenter
            text: row._currentHex
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            selectByMouse: true
            clip: true
            // Apply on every edit if the value parses; ignore otherwise
            // so a half-typed hex doesn't blow up. Live-applied via
            // Local.set's debounce.
            onTextChanged: {
                const m = text.match(row._hexRe);
                if (!m) return;
                const normalized = "#" + m[1].toLowerCase();
                if (normalized !== row._currentHex) {
                    Local.set(row.settingKey, normalized);
                }
            }
        }
    }

    // Swatch — visual preview + click-to-open-picker. Click delegates
    // to SettingsService.openPicker which routes through the shared
    // ColorPicker instance at SettingsPopup's root.
    Rectangle {
        id: swatch
        anchors.left: hexBox.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        radius: Theme.radiusSmall
        color: row.currentValue
        // Highlight border when the shared picker is currently bound to
        // this row's key — visual confirmation of which swatch is being
        // edited.
        border.color: SettingsService.pickerOpen
                      && SettingsService.pickerKey === row.settingKey
            ? Theme.text
            : (swatchMa.containsMouse ? Theme.text : Theme.border)
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        MouseArea {
            id: swatchMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: SettingsService.openPicker(
                row.settingKey, row.currentValue, swatch)
        }
    }
}
