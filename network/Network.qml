// Network.qml
// Bar icon for the network manager.
//   Left  -> toggle the network popup
//   Middle-> toggle wifi radio

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs

MouseArea {
    id: root

    implicitWidth: 22
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

    // Pick the best icon for the current state.
    function _iconName() {
        if (NetworkService.wiredConnected) return "network-wired-activated-symbolic";
        if (NetworkService.wifiConnected) {
            // Find current wifi entry for signal level
            const list = NetworkService.wirelessNetworks;
            let sig = 0;
            for (let i = 0; i < list.length; i++) {
                if (list[i].inUse) { sig = list[i].signal; break; }
            }
            const tier = sig >= 80 ? 100
                        : sig >= 55 ? 75
                        : sig >= 30 ? 50
                        : sig >  0  ? 25
                        : 0;
            return "network-wireless-connected-" + (tier < 10 ? "00" : tier) + "-symbolic";
        }
        if (!NetworkService.wifiEnabled) return "network-wireless-disabled-symbolic";
        return "network-disconnect-symbolic";
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

    // Icon (with text fallback)
    Item {
        anchors.centerIn: parent
        width: 16
        height: 16
        opacity: NetworkService.wiredConnected || NetworkService.wifiConnected
                 ? 1.0
                 : (NetworkService.wifiEnabled ? 0.7 : 0.45)
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        IconImage {
            id: nIcon
            anchors.fill: parent
            implicitSize: 16
            source: Quickshell.iconPath(root._iconName(), true)
            asynchronous: false
            visible: status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: nIcon.status !== Image.Ready
            text: NetworkService.wiredConnected ? "ETH"
                : NetworkService.wifiConnected ? "WiFi"
                : NetworkService.wifiEnabled ? "—" : "off"
            color: Theme.text
            font.pixelSize: 9
            font.bold: true
        }
    }

    NetworkPopup {
        id: popup
        anchorItem: root
    }
}
