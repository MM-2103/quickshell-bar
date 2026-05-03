// PresetDropdownList.qml
// The floating list portion of a PresetDropdown — owned by
// SettingsPopup at root level so it renders above all rows. Driven
// entirely by SettingsService.dropdown* properties and writes via
// Local.set on selection.
//
// VISIBILITY IS OWNED BY THE PARENT. Same hard-won lesson as
// ColorPicker: never write to `visible` from inside the component
// when the parent has it bound, or the binding silently breaks. Here
// we expose a `dismissRequested` signal for the host to call
// SettingsService.closeDropdown() on selection or other dismiss paths.

import QtQuick
import qs
import qs.settings

Rectangle {
    id: root

    // Caller binds `presets` + `selectedValue` (for highlighting the
    // current pick) + `settingKey` / `companionKey` (where to write).
    property var presets: []
    property string selectedValue: ""
    property string settingKey: ""
    property string companionKey: ""

    signal dismissRequested

    // Width matches the trigger; SettingsPopup adjusts via a binding.
    // Height grows with the content (Repeater fills `listCol`).
    width: 280
    height: listCol.implicitHeight + 8
    radius: Theme.radiusSmall
    color: Theme.bg
    border.color: Theme.border
    border.width: 1

    // Catch-all to swallow clicks on the list's empty/border area so
    // they don't pass through to rows beneath. Inner row MouseAreas are
    // declared later so they win the hit-test in their regions.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: { /* swallow */ }
    }

    Column {
        id: listCol
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 4
        }
        spacing: 2

        Repeater {
            model: root.presets
            delegate: Rectangle {
                required property var modelData
                width: parent.width
                height: 26
                radius: Theme.radiusSmall
                readonly property bool _isSelected:
                    modelData.value === root.selectedValue
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
                        if (!root.settingKey) return;
                        Local.set(root.settingKey, modelData.value);
                        if (root.companionKey
                            && modelData.companionLabel !== undefined) {
                            Local.set(root.companionKey, modelData.companionLabel);
                        }
                        root.dismissRequested();
                    }
                }
            }
        }
    }
}
