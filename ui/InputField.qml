// InputField.qml
// Single-line text field used inside list rows (Wi-Fi password, hidden
// network SSID). 24 px tall to match IconButton. Enter emits accepted(),
// Escape emits cancelled().
//
// The text property aliases the input, so the usual two-way pattern
// works: bind text to view state and write it back in onTextChanged.

import QtQuick
import qs

Rectangle {
    id: field

    property alias text: input.text
    property string placeholder: ""
    property bool password: false
    readonly property bool inputFocused: input.activeFocus

    signal accepted()
    signal cancelled()

    function focusInput() { input.forceActiveFocus(); }

    height: 24
    radius: Theme.radiusSmall
    color: Theme.bg
    border.color: input.activeFocus ? Theme.text : Theme.border
    border.width: 1

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeSmall
        echoMode: field.password ? TextInput.Password : TextInput.Normal
        selectByMouse: true
        clip: true
        Keys.onReturnPressed: field.accepted()
        Keys.onEnterPressed: field.accepted()
        Keys.onEscapePressed: field.cancelled()

        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: !input.text && !input.activeFocus
            text: field.placeholder
            color: Theme.textMuted
            font: input.font
        }
    }
}
