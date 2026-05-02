// NetworkView.qml
// Embeddable network picker. Extracted from the old NetworkPopup so the
// Control Center can host the same UI as a sub-view.
//
// Composition: a Flickable wrapping the existing NetworkPopup content
// column (header row, ethernet section, wifi list, hidden form). The
// surrounding card chrome (Rectangle, border, drop shadow) is supplied
// by ControlCenterPopup; this file is pure content.
//
// Lifecycle: the CC's Loader instantiates this view on navigation in and
// destroys it on navigation out. We use Component.onCompleted to trigger
// an initial refresh + scan and a Timer to poll while shown — same
// behaviour the old popup had via wantOpen.

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs

Item {
    id: view

    // SSID currently being prompted for a password (inline expansion).
    property string passwordPromptSsid: ""
    property string passwordPromptPwd: ""

    // Hidden network form state.
    property bool hiddenFormOpen: false
    property string hiddenSsid: ""
    property string hiddenPwd: ""

    Component.onCompleted: {
        NetworkService.refreshAll();
        NetworkService.rescan();
    }

    // Periodically rescan + refresh while shown (signal-strength changes).
    // Same 8s cadence as the old popup.
    Timer {
        running: true
        interval: 8000
        repeat: true
        onTriggered: {
            NetworkService.refreshAll();
            NetworkService.rescan();
        }
    }

    // ================================================================
    // Inline component: an ethernet device row.
    // ================================================================
    component EthernetRow: Rectangle {
        id: erow
        required property var dev

        readonly property var activeConn: {
            const acts = NetworkService.activeConnections;
            for (let i = 0; i < acts.length; i++) {
                if (acts[i].type === "802-3-ethernet" && acts[i].device === erow.dev.device) {
                    return acts[i];
                }
            }
            return null;
        }

        readonly property bool isActive: activeConn !== null
        readonly property bool cablePlugged:
            dev.state !== "unavailable" && dev.state !== "unmanaged"

        function _title() {
            if (isActive && activeConn) return activeConn.name;
            return "Wired (" + erow.dev.device + ")";
        }
        function _statusText() {
            if (isActive) return "connected · " + erow.dev.device;
            if (!cablePlugged) return "cable unplugged · " + erow.dev.device;
            return "available · click to connect";
        }
        function _primaryAction() {
            if (isActive) {
                NetworkService.disconnectDevice(erow.dev.device);
            } else if (cablePlugged) {
                NetworkService.connectDevice(erow.dev.device);
            }
        }

        width: parent.width
        height: 36
        radius: Theme.radiusSmall
        color: rowMa.containsMouse && (isActive || cablePlugged)
            ? Theme.surfaceHi
            : Theme.surface
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        opacity: cablePlugged || isActive ? 1.0 : 0.5

        Row {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16
                IconImage {
                    id: ethIcon
                    anchors.fill: parent
                    implicitSize: 16
                    source: Quickshell.iconPath(
                        erow.isActive ? "network-wired-activated-symbolic"
                                      : "network-wired-symbolic", true)
                    asynchronous: false
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: ethIcon.status !== Image.Ready
                    text: "ETH"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: 8
                    font.weight: Font.Bold
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 16 - parent.spacing
                spacing: 1
                Text {
                    text: erow._title()
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: erow.isActive ? Font.Bold : Font.Normal
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text: erow._statusText()
                    color: erow.isActive ? Theme.textDim : Theme.textMuted
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }

        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: (erow.isActive || erow.cablePlugged)
                ? Qt.PointingHandCursor
                : Qt.ArrowCursor
            z: -1
            acceptedButtons: Qt.LeftButton
            onClicked: erow._primaryAction()
        }
    }

    // ================================================================
    // Inline component: a wifi list entry row.
    // ================================================================
    component WifiRow: Rectangle {
        id: row
        required property var net

        width: parent.width
        height: 36 + (view.passwordPromptSsid === net.ssid ? 36 : 0)
        radius: Theme.radiusSmall
        color: rowMa.containsMouse ? Theme.surfaceHi : Theme.surface
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }
        clip: true

        readonly property bool secured: net.security && net.security !== ""
        readonly property bool saved: {
            const list = NetworkService.savedConnections;
            for (let i = 0; i < list.length; i++) {
                if (list[i].type === "802-11-wireless" && list[i].name === net.ssid) return true;
            }
            return false;
        }

        function _signalIcon() {
            const s = net.signal;
            const tier = s >= 80 ? 100 : s >= 55 ? 75 : s >= 30 ? 50 : s > 0 ? 25 : 0;
            return "network-wireless-connected-" + (tier < 10 ? "00" : tier) + "-symbolic";
        }

        function _primaryAction() {
            if (net.inUse) {
                NetworkService.disconnectByName(net.ssid);
                return;
            }
            if (row.saved) {
                NetworkService.connectByName(net.ssid);
                return;
            }
            if (row.secured) {
                view.passwordPromptPwd = "";
                view.passwordPromptSsid = net.ssid;
            } else {
                NetworkService.connectWifi(net.ssid, "", false);
            }
        }

        Row {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            height: 36
            spacing: 8

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16
                IconImage {
                    id: sigIcon
                    anchors.fill: parent
                    implicitSize: 16
                    source: Quickshell.iconPath(row._signalIcon(), true)
                    asynchronous: false
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: sigIcon.status !== Image.Ready
                    text: net.signal + ""
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: 8
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 16 - parent.spacing - rightTags.width
                spacing: 1

                Text {
                    text: net.ssid
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: net.inUse ? Font.Bold : Font.Normal
                    elide: Text.ElideRight
                    width: parent.width
                }

                Text {
                    text: {
                        const parts = [];
                        if (net.inUse)              parts.push("connected");
                        else if (row.saved)         parts.push("saved");
                        if (row.secured)            parts.push(net.security);
                        else                        parts.push("open");
                        parts.push(net.signal + "%");
                        return parts.join("  ·  ");
                    }
                    color: net.inUse ? Theme.textDim : Theme.textMuted
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            Row {
                id: rightTags
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    visible: row.secured
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf023"
                    color: Theme.textDim
                    font.family: Theme.fontIcon
                    font.styleName: "Solid"
                    font.pixelSize: 9
                    renderType: Text.NativeRendering
                }

                Rectangle {
                    visible: row.saved
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 20
                    radius: Theme.radiusSmall
                    opacity: forgetMa.containsMouse ? 1.0 : (rowMa.containsMouse ? 0.7 : 0.0)
                    color: forgetMa.containsMouse ? Theme.bg : "transparent"
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        color: forgetMa.containsMouse ? Theme.text : Theme.textDim
                        font.family: Theme.fontIcon
                        font.styleName: "Solid"
                        font.pixelSize: 11
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: forgetMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NetworkService.forgetByName(net.ssid)
                    }
                }
            }
        }

        // Inline password prompt row.
        Row {
            visible: view.passwordPromptSsid === net.ssid
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.bottomMargin: 4
            height: 28
            spacing: 6

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - cancelBtn.width - okBtn.width - parent.spacing * 2
                height: 24
                radius: Theme.radiusSmall
                color: Theme.bg
                border.color: pwdInput.activeFocus ? Theme.text : Theme.border
                border.width: 1

                TextInput {
                    id: pwdInput
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    verticalAlignment: TextInput.AlignVCenter
                    text: view.passwordPromptPwd
                    onTextChanged: view.passwordPromptPwd = text
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    echoMode: TextInput.Password
                    selectByMouse: true
                    focus: visible
                    Keys.onReturnPressed: okBtn.activate()
                    Keys.onEnterPressed: okBtn.activate()
                    Keys.onEscapePressed: { view.passwordPromptSsid = ""; view.passwordPromptPwd = ""; }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 0
                        verticalAlignment: Text.AlignVCenter
                        visible: !pwdInput.text && !pwdInput.activeFocus
                        text: "Password"
                        color: Theme.textMuted
                        font: pwdInput.font
                    }
                }
            }

            Rectangle {
                id: cancelBtn
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24
                radius: Theme.radiusSmall
                color: cancelMa.containsMouse ? Theme.bg : "transparent"
                border.color: Theme.border
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "\uf00d"
                    color: Theme.text
                    font.family: Theme.fontIcon
                    font.styleName: "Solid"
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }
                MouseArea {
                    id: cancelMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { view.passwordPromptSsid = ""; view.passwordPromptPwd = ""; }
                }
            }

            Rectangle {
                id: okBtn
                anchors.verticalCenter: parent.verticalCenter
                width: 60; height: 24
                radius: Theme.radiusSmall
                color: okMa.containsMouse ? Theme.text : Theme.surfaceHi
                border.color: Theme.border
                border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                function activate() {
                    NetworkService.connectWifi(net.ssid, view.passwordPromptPwd, false);
                    view.passwordPromptSsid = "";
                    view.passwordPromptPwd = "";
                }

                Text {
                    anchors.centerIn: parent
                    text: "Connect"
                    color: okMa.containsMouse ? Theme.bg : Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: okMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: okBtn.activate()
                }
            }
        }

        MouseArea {
            id: rowMa
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 36
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            z: -1
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton) {
                    row._primaryAction();
                } else if (mouse.button === Qt.RightButton && row.saved) {
                    NetworkService.forgetByName(net.ssid);
                }
            }
        }
    }

    component SectionHeader: Text {
        property string label
        property int count: 0
        text: count > 0 ? (label + "  ·  " + count) : label
        color: Theme.textDim
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Bold
    }

    // ================================================================
    // Layout: Flickable scrolls the content column. Header is OUT of the
    // CC popup chrome (the CC supplies its own header with back arrow).
    // ================================================================
    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentColumn
            width: parent.width
            spacing: 10

            // Header (status string + rescan + wifi switch).
            Row {
                width: parent.width
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: NetworkService.wiredConnected
                        ? "Wired connected"
                        : NetworkService.wifiConnected
                            ? ("Wi‑Fi · " + NetworkService.currentSsid)
                            : NetworkService.wifiEnabled
                                ? "Disconnected"
                                : "Wi‑Fi off"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    width: parent.width - rescanBtn.width - wifiToggleBtn.width - parent.spacing * 2
                }

                Rectangle {
                    id: rescanBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 22
                    radius: Theme.radiusSmall
                    color: rescanMa.containsMouse ? Theme.surfaceHi : Theme.surface
                    enabled: NetworkService.wifiEnabled
                    opacity: enabled ? 1.0 : 0.4

                    Text {
                        id: rescanGlyph
                        anchors.centerIn: parent
                        text: "\uf021"
                        color: Theme.text
                        font.family: Theme.fontIcon
                        font.styleName: "Solid"
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: rescanMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: parent.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            NetworkService.rescan();
                            rescanSpin.restart();
                        }
                    }

                    RotationAnimation {
                        id: rescanSpin
                        target: rescanGlyph
                        from: 0; to: 360
                        duration: 700
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    id: wifiToggleBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38; height: 22
                    radius: 11
                    color: NetworkService.wifiEnabled ? Theme.accent : Theme.surface
                    border.color: Theme.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animMed } }

                    Rectangle {
                        width: 16; height: 16
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        x: NetworkService.wifiEnabled ? parent.width - width - 3 : 3
                        color: NetworkService.wifiEnabled ? Theme.bg : Theme.text
                        Behavior on x { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            // Ethernet section.
            Column {
                visible: NetworkService.hasEthernetHardware
                width: parent.width
                spacing: 4

                SectionHeader {
                    label: "ETHERNET"
                    count: NetworkService.ethernetDevices.length
                }

                Repeater {
                    model: NetworkService.ethernetDevices
                    delegate: EthernetRow {
                        required property var modelData
                        dev: modelData
                    }
                }
            }

            // Wifi-disabled placeholder.
            Text {
                visible: !NetworkService.wifiEnabled
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Wi‑Fi is off. Toggle the switch above to enable."
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                topPadding: 16
                bottomPadding: 16
                wrapMode: Text.Wrap
            }

            // Wifi list.
            Column {
                visible: NetworkService.wifiEnabled
                width: parent.width
                spacing: 4

                SectionHeader {
                    label: "WI‑FI NETWORKS"
                    count: NetworkService.wirelessNetworks.length
                }

                Repeater {
                    model: NetworkService.wirelessNetworks
                    delegate: WifiRow {
                        required property var modelData
                        net: modelData
                    }
                }

                Text {
                    visible: NetworkService.wirelessNetworks.length === 0
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "No networks found. Click the rescan button above."
                    color: Theme.textMuted
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    topPadding: 8
                    bottomPadding: 8
                }
            }

            // Last error display.
            Text {
                visible: NetworkService.lastError.length > 0
                width: parent.width
                text: NetworkService.lastError
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            // Hidden network form (collapsible).
            Rectangle {
                visible: NetworkService.wifiEnabled
                width: parent.width
                height: hiddenContent.implicitHeight + 12
                radius: Theme.radiusSmall
                color: "transparent"
                border.color: Theme.border
                border.width: 1
                Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }
                clip: true

                Column {
                    id: hiddenContent
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 6
                    }
                    spacing: 6

                    Row {
                        width: parent.width
                        spacing: 6
                        height: 22

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: view.hiddenFormOpen ? "\uf068" : "\uf067"
                            color: Theme.text
                            font.family: Theme.fontIcon
                            font.styleName: "Solid"
                            font.pixelSize: 10
                            renderType: Text.NativeRendering
                            width: 14
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Connect to hidden network"
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            width: parent.width
                            height: parent.height
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.hiddenFormOpen = !view.hiddenFormOpen
                        }
                    }

                    Rectangle {
                        visible: view.hiddenFormOpen
                        width: parent.width
                        height: 24
                        radius: Theme.radiusSmall
                        color: Theme.bg
                        border.color: hiddenSsidIn.activeFocus ? Theme.text : Theme.border
                        border.width: 1

                        TextInput {
                            id: hiddenSsidIn
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            verticalAlignment: TextInput.AlignVCenter
                            text: view.hiddenSsid
                            onTextChanged: view.hiddenSsid = text
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            selectByMouse: true

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: !hiddenSsidIn.text && !hiddenSsidIn.activeFocus
                                text: "SSID"
                                color: Theme.textMuted
                                font: hiddenSsidIn.font
                            }
                        }
                    }

                    Row {
                        visible: view.hiddenFormOpen
                        width: parent.width
                        height: 24
                        spacing: 6

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - hConnectBtn.width - parent.spacing
                            height: 24
                            radius: Theme.radiusSmall
                            color: Theme.bg
                            border.color: hiddenPwdIn.activeFocus ? Theme.text : Theme.border
                            border.width: 1

                            TextInput {
                                id: hiddenPwdIn
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                verticalAlignment: TextInput.AlignVCenter
                                text: view.hiddenPwd
                                onTextChanged: view.hiddenPwd = text
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall
                                echoMode: TextInput.Password
                                selectByMouse: true

                                Keys.onReturnPressed: hConnectBtn.activate()
                                Keys.onEnterPressed: hConnectBtn.activate()

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: !hiddenPwdIn.text && !hiddenPwdIn.activeFocus
                                    text: "Password (optional)"
                                    color: Theme.textMuted
                                    font: hiddenPwdIn.font
                                }
                            }
                        }

                        Rectangle {
                            id: hConnectBtn
                            anchors.verticalCenter: parent.verticalCenter
                            width: 60; height: 24
                            radius: Theme.radiusSmall
                            color: hConnectMa.containsMouse ? Theme.text : Theme.surfaceHi
                            border.color: Theme.border
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            function activate() {
                                if (!view.hiddenSsid) return;
                                NetworkService.connectWifi(view.hiddenSsid, view.hiddenPwd, true);
                                view.hiddenSsid = "";
                                view.hiddenPwd = "";
                                view.hiddenFormOpen = false;
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "Connect"
                                color: hConnectMa.containsMouse ? Theme.bg : Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                id: hConnectMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: hConnectBtn.activate()
                            }
                        }
                    }
                }
            }
        }
    }
}
