// SectionHeader.qml
// Tiny sub-section title used inside the four section files. Looks
// identical to the SECTION HEADERS used in NetworkView / BluetoothView
// ("WI-FI NETWORKS · 5", "PAIRED · 2", etc.) so the overall typography
// of the shell stays consistent.

import QtQuick
import qs

Text {
    property string label: ""

    text: label
    color: Theme.textDim
    font.family: Theme.fontMono
    font.pixelSize: Theme.fontSizeSmall
    font.weight: Font.Bold
    topPadding: 6
    bottomPadding: 4
}
