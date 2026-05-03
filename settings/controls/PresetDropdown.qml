// PresetDropdown.qml
// Setting row backed by a small dropdown of preset values. Used for the
// launcher's `searchUrl` (Kagi / DuckDuckGo / Google / Brave / Startpage),
// where free-form text via TextRow.qml is also possible but most users
// just want a known engine.
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

    // ---- collapsed dropdown button ----
    Rectangle {
        id: trigger
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 24
        radius: Theme.radiusSmall
        color: triggerMa.containsMouse ? Theme.surfaceHi : Theme.surface
        border.color: Theme.border
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

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
            onClicked: dropdown.visible = !dropdown.visible
        }
    }

    // ---- dropdown list ----
    //
    // Rendered as a same-tree Item with high z so it floats over the
    // sections below without pushing them. Click any preset to apply
    // and close.
    Rectangle {
        id: dropdown
        z: 200
        visible: false
        anchors.top: trigger.bottom
        anchors.left: trigger.left
        anchors.right: trigger.right
        anchors.topMargin: 4
        height: presetCol.implicitHeight + 8
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radiusSmall

        Column {
            id: presetCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 4
            }
            spacing: 2

            Repeater {
                model: row.presets
                delegate: Rectangle {
                    required property var modelData
                    width: parent.width
                    height: 26
                    radius: Theme.radiusSmall
                    readonly property bool _isSelected:
                        row._matchedPreset && row._matchedPreset.value === modelData.value
                    color: presetMa.containsMouse
                        ? Theme.surfaceHi
                        : (_isSelected ? Theme.surface : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8
                        text: modelData.label
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: parent._isSelected ? Font.Bold : Font.Normal
                    }

                    MouseArea {
                        id: presetMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Local.set(row.settingKey, modelData.value);
                            if (row.companionKey && modelData.companionLabel !== undefined) {
                                Local.set(row.companionKey, modelData.companionLabel);
                            }
                            dropdown.visible = false;
                        }
                    }
                }
            }
        }
    }
}
