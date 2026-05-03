// SettingRow.qml
// Base row layout shared by every control type in the Settings page.
//
//   ┌────────────────────────────────────────────────────┐
//   │ Label                  [control content]      [↺]  │
//   └────────────────────────────────────────────────────┘
//
// The label sits at a fixed width on the left, the control content
// fills the middle, and a reset arrow on the right is shown when the
// key has an explicit override (i.e. when `Local.data[key]` is set —
// distinct from the default returned by `Local.get(key, default)`).
//
// Concrete row components (ColorRow, NumberSlider, TextRow, ToggleRow,
// PresetDropdown) populate the `content` default property with their
// specific widgets.

import QtQuick
import qs
import qs.settings

Item {
    id: row

    // The configuration key being edited. Used by the reset button to
    // call `Local.reset(key)` and by `_isOverridden` to decide if the
    // reset arrow should be shown.
    property string settingKey: ""

    // Visible label at the row's left edge.
    property string label: ""

    // Where the row's main control lives. Concrete controls populate
    // this via the default-property convention (children of the row
    // become children of `contentArea`).
    default property alias content: contentArea.data

    // Width of the label column. Tweak per-section if the longest label
    // in a section needs more / less room. Default fits "fontSizeNormal"
    // and similar 16-char keys comfortably.
    property int labelWidth: 130

    // Width reserved for the reset arrow column at the right edge.
    readonly property int resetWidth: 24

    // True when the key has an explicit override in `Local.data`. Drives
    // visibility of the reset arrow.
    readonly property bool _isOverridden:
        row.settingKey
        && Local.data
        && Local.data[row.settingKey] !== undefined

    width: parent ? parent.width : 0
    height: 32

    // ---- label ----
    Text {
        id: labelText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: row.labelWidth
        text: row.label
        color: Theme.textDim
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideRight
    }

    // ---- control content area ----
    Item {
        id: contentArea
        anchors.left: labelText.right
        anchors.right: resetButton.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 8
        anchors.rightMargin: 8
    }

    // ---- reset arrow ----
    //
    // Visible only when this key has an explicit override. Click drops
    // the override; row reverts to the default value next paint.
    Rectangle {
        id: resetButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: row.resetWidth
        height: 22
        radius: Theme.radiusSmall
        visible: row._isOverridden
        color: resetMa.containsMouse ? Theme.surfaceHi : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        // FA Solid \uf0e2 rotate-left — universal "undo" pictogram.
        Text {
            anchors.centerIn: parent
            text: "\uf0e2"
            color: Theme.textDim
            font.family: Theme.fontIcon
            font.styleName: "Solid"
            font.pixelSize: 11
            renderType: Text.NativeRendering
        }

        MouseArea {
            id: resetMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (row.settingKey) Local.reset(row.settingKey);
            }
        }
    }
}
