// EmptyState.qml
// Centred message that stands in for an empty or disabled list:
// "Wi-Fi is off", "No devices found".

import QtQuick
import qs

Text {
    width: parent ? parent.width : 0
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.Wrap
    color: Theme.textDim
    font.family: Theme.fontMono
    font.pixelSize: Theme.fontSizeSmall
    topPadding: 16
    bottomPadding: 16
}
