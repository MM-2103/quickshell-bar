// TextRow.qml
// Setting row backed by a free-form text input. Used for fonts and the
// launcher's `searchUrl` / `searchName` (when the user wants something
// not in the preset dropdown).
//
// Live-applies on every keystroke via `Local.set(key, value)` — the
// 500 ms debounce in Local coalesces fast typing into a single write.
// For URL fields users probably finish typing before the debounce fires,
// but the live-preview-on-each-char behaviour keeps the UI honest about
// what's about to be saved.

import QtQuick
import qs
import qs.settings

SettingRow {
    id: row

    // Default value for this key — used when no override is present and
    // shown as placeholder text when the input is empty.
    property string defaultValue: ""

    // Optional preview Text displayed under the input (e.g. for fonts:
    // "Aa Bb Cc 0123" rendered in the typed font family). Off by default;
    // sections set `showPreview: true` for font rows.
    property bool showPreview: false
    property string previewSample: "Aa Bb 0123 — the quick brown fox"

    // Override the row's default 32 px height when preview is on so the
    // sample fits under the input.
    height: row.showPreview ? 56 : 32

    readonly property string currentValue: Local.get(row.settingKey, row.defaultValue)

    Rectangle {
        id: inputBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
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
            text: row.currentValue
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            selectByMouse: true
            clip: true
            // Live-apply: each edit goes through Local.set; the debounce
            // there ensures we don't write per-keystroke. Avoid redundant
            // writes when text matches current value (which can happen
            // during binding round-trips).
            onTextChanged: {
                if (text !== row.currentValue) {
                    Local.set(row.settingKey, text);
                }
            }
        }
    }

    // Optional preview label — shown in the typed value (font, etc.)
    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: row.showPreview ? 22 : 0
        visible: row.showPreview
        text: row.previewSample
        color: Theme.textMuted
        font.family: row.currentValue || row.defaultValue
        font.pixelSize: Theme.fontSizeNormal
        elide: Text.ElideRight
    }
}
