// Network.qml
// Bar icon for the network manager.
//   Left  -> toggle the network popup
//   Middle-> toggle wifi radio

import QtQuick
import Quickshell
import qs

MouseArea {
    id: root

    // Widget grows when wifi is connected to fit a small signal-strength
    // % overlay next to the glyph; collapses to the standard 22 px when
    // wired / disconnected / disabled. Bar layout already accommodates
    // variable-width children (Media widget hides itself), so no surprise.
    implicitWidth: root._showSignal ? 36 : 22
    implicitHeight: 22
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
            popup.toggle();
        } else if (mouse.button === Qt.MiddleButton) {
            NetworkService.setWifiEnabled(!NetworkService.wifiEnabled);
        }
    }

    // ---- State helpers ----

    // Resolve the active wifi network's signal strength (0-100). Returns
    // -1 when not on wifi (so we can hide the overlay cleanly).
    readonly property int _signal: {
        if (!NetworkService.wifiConnected) return -1;
        const list = NetworkService.wirelessNetworks;
        for (let i = 0; i < list.length; i++) {
            if (list[i].inUse) return list[i].signal;
        }
        return -1;
    }
    readonly property bool _showSignal: _signal >= 0

    // Pick the FA glyph for the current state. Font Awesome only has one
    // wifi glyph (no signal-bar variants), so signal strength is shown
    // numerically in the overlay rather than encoded in the icon shape.
    function _glyph() {
        if (NetworkService.wiredConnected)        return "\uf796"; // ethernet
        if (NetworkService.wifiConnected)         return "\uf1eb"; // wifi
        if (!NetworkService.wifiEnabled)          return "\uf127"; // link-slash
        return "\uf1eb";                                            // wifi (greyed)
    }

    // Hover background
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: popup.visible
            ? Theme.surfaceHi
            : (root.containsMouse ? Theme.surface : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // Glyph + (optional) signal-strength readout, side-by-side.
    Row {
        anchors.centerIn: parent
        spacing: 4

        BarIcon {
            anchors.verticalCenter: parent.verticalCenter
            glyph: root._glyph()
            opacity: NetworkService.wiredConnected || NetworkService.wifiConnected
                ? 1.0
                : (NetworkService.wifiEnabled ? 0.7 : 0.45)
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        }

        // Signal strength % — visible only on wifi connected, shown in
        // the shell's mono font so it sits cleanly next to the glyph.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root._showSignal
            text: root._signal + ""
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            opacity: 0.85
        }
    }

    NetworkPopup {
        id: popup
        anchorItem: root
    }

    BarTooltip {
        anchorItem: root
        show: root.containsMouse && !popup.visible
        text: NetworkService.wiredConnected
            ? "Wired connected"
            : NetworkService.wifiConnected
                ? ("WiFi · " + (NetworkService.currentSsid || "")
                    + " · " + root._signal + "%")
                : NetworkService.wifiEnabled
                    ? "Disconnected"
                    : "WiFi off"
    }
}
