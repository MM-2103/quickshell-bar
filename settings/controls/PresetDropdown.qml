// PresetDropdown.qml
// Setting row backed by a small dropdown of preset values. The TRIGGER
// (the labelled button users click) lives here; the FLOATING LIST is
// owned by SettingsPopup and rendered at the popup root via
// SettingsService.openDropdown(...). Splitting the two pieces is
// necessary because the inline list — declared as a child of this row
// — would render under any subsequent row in the same Column (z-order
// only works between siblings; later-declared sibling rows render
// after earlier ones, regardless of z values inside the row's subtree).
//
// `presets` is `[{ label, value, companionLabel? }]`:
//   - `value` is what gets written to Local for `settingKey`
//   - `companionLabel` is optionally written to a secondary key (e.g.
//      writing both `searchUrl` AND `searchName` from one click)
//   - `companionKey` (row property) names that secondary key
//
// If the current value matches one of the presets, that preset is shown
// as selected. Otherwise the dropdown shows "Custom" — users can still
// edit via the corresponding TextRow.qml without breaking the UX here.

import QtQuick
import qs
import qs.settings

SettingRow {
    id: row

    // Default value for the primary key when no override is set.
    property string defaultValue: ""

    // List of preset entries. See file header for shape.
    property var presets: []

    // Optional secondary key written alongside the primary one when a
    // preset has `companionLabel`. Both writes hit Local.set; the
    // debounce coalesces into one file write.
    property string companionKey: ""

    readonly property string currentValue:
        Local.get(row.settingKey, row.defaultValue)

    // Find the preset matching the current value; null if user has a
    // custom value that doesn't match any preset.
    readonly property var _matchedPreset: {
        for (let i = 0; i < row.presets.length; i++) {
            if (row.presets[i].value === row.currentValue) {
                return row.presets[i];
            }
        }
        return null;
    }

    readonly property string _displayLabel:
        row._matchedPreset ? row._matchedPreset.label : "Custom"

    // Visual highlight when this row's dropdown is currently the open
    // one — same idea as ColorRow's swatch border highlight.
    readonly property bool _isActiveDropdown:
        SettingsService.dropdownOpen
        && SettingsService.dropdownKey === row.settingKey

    // ---- collapsed dropdown trigger ----
    Rectangle {
        id: trigger
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 24
        radius: Theme.radiusSmall
        color: triggerMa.containsMouse ? Theme.surfaceHi : Theme.surface
        border.color: row._isActiveDropdown ? Theme.text : Theme.border
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 0

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - chevron.width
                text: row._displayLabel
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }

            // FA Solid \uf078 chevron-down
            Text {
                id: chevron
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                horizontalAlignment: Text.AlignRight
                text: "\uf078"
                color: Theme.textDim
                font.family: Theme.fontIcon
                font.styleName: "Solid"
                font.pixelSize: 9
                renderType: Text.NativeRendering
            }
        }

        MouseArea {
            id: triggerMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: SettingsService.openDropdown(
                row.settingKey,
                row.presets,
                row.currentValue,
                row.companionKey,
                trigger)
        }
    }
}
