// SectionHeader.qml
// Small bold caption above a group of rows, with an optional count:
// "PAIRED  ·  3".

import QtQuick
import qs

Text {
    property string label: ""
    property int count: 0

    text: count > 0 ? (label + "  ·  " + count) : label
    color: Theme.textDim
    font.family: Theme.fontMono
    font.pixelSize: Theme.fontSizeSmall
    font.weight: Font.Bold
}
