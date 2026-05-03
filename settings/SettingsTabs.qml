// SettingsTabs.qml
// Pill-row tab selector for the Settings popup. Visually identical to
// the wallpaper picker's "Apply to" / "Fill" pill rows so the tab
// idiom feels consistent across the shell.
//
// Tab selection writes to `SettingsService.activeTab`; the popup's
// Loader keys on that for content swaps.

import QtQuick
import qs
import qs.settings

Row {
    id: root

    spacing: 6

    // Each tab: { key, label }. Order is the visual order.
    readonly property var _tabs: [
        { key: "colors",     label: "Colours" },
        { key: "typography", label: "Typography" },
        { key: "layout",     label: "Layout & Motion" },
        { key: "behavior",   label: "Behaviour" }
    ]

    Repeater {
        model: root._tabs
        delegate: Rectangle {
            id: pill
            required property var modelData
            readonly property bool _selected:
                SettingsService.activeTab === pill.modelData.key

            width: pillLabel.implicitWidth + 18
            height: 24
            radius: 12
            color: pill._selected
                ? Theme.accent
                : (pillMa.containsMouse ? Theme.surfaceHi : Theme.surface)
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Text {
                id: pillLabel
                anchors.centerIn: parent
                text: pill.modelData.label
                color: pill._selected ? Theme.accentText : Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.weight: pill._selected ? Font.Bold : Font.Normal
            }

            MouseArea {
                id: pillMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: SettingsService.setTab(pill.modelData.key)
            }
        }
    }
}
