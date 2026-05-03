// ToggleRow.qml
// Setting row backed by a switch-style pill toggle. Used for booleans
// (currently just `volumeFeedbackEnabled`).
//
// Visual is the same pill switch BluetoothView / NetworkView use for
// adapter / radio toggles — accent fill when on, surface when off,
// 16 × 16 thumb sliding between left and right ends.

import QtQuick
import qs
import qs.settings

SettingRow {
    id: row

    // Default boolean value when no override is set.
    property bool defaultValue: false

    readonly property bool currentValue:
        Local.get(row.settingKey, row.defaultValue)

    Rectangle {
        id: pill
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 22
        radius: 11
        color: row.currentValue ? Theme.accent : Theme.surface
        border.color: Theme.border
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.animMed } }

        Rectangle {
            width: 16
            height: 16
            radius: 8
            anchors.verticalCenter: parent.verticalCenter
            x: row.currentValue ? parent.width - width - 3 : 3
            color: row.currentValue ? Theme.bg : Theme.text
            Behavior on x { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Local.set(row.settingKey, !row.currentValue)
        }
    }
}
