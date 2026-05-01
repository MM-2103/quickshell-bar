// NetworkPopup.qml
// Replaces nm-applet. Shows current state, scans for wifi, lets the user
// connect to known/new/hidden networks and forget saved ones.

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs

PopupWindow {
    id: popup

    required property Item anchorItem

    color: "transparent"

    property bool wantOpen: false
    visible: wantOpen || hideHold.running
    Timer { id: hideHold; interval: 180; repeat: false }
    onWantOpenChanged: {
        if (wantOpen) hideHold.stop();
        else          hideHold.restart();
    }

    function toggle() {
        if (popup.wantOpen) {
            popup.wantOpen = false;
        } else {
            PopupController.open(popup, () => popup.wantOpen = false);
            popup.wantOpen = true;
            NetworkService.refreshAll();
            NetworkService.rescan();
        }
    }
    onVisibleChanged: if (!visible) PopupController.closed(popup)

    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? -((popup.width - anchorItem.width) / 2) : 0
    anchor.rect.y: anchorItem ? anchorItem.height + 6 : 0
    anchor.adjustment: PopupAdjustment.SlideX

    implicitWidth: 380
    implicitHeight: contentColumn.implicitHeight + 16

    // SSID currently being prompted for a password (inline expansion).
    property string passwordPromptSsid: ""
    property string passwordPromptPwd: ""

    // Hidden network form state.
    property bool hiddenFormOpen: false
    property string hiddenSsid: ""
    property string hiddenPwd: ""

    // Periodically rescan + refresh while open (covers signal-strength changes).
    Timer {
        running: popup.wantOpen
        interval: 8000
        repeat: true
        onTriggered: {
            NetworkService.refreshAll();
            NetworkService.rescan();
        }
    }

    // ================================================================
    // Inline component: an ethernet device row (one per adapter).
    // Driven by the device list, not saved connections, because NM
    // auto-deletes ad-hoc "Wired connection N" profiles on disconnect.
    // ================================================================
    component EthernetRow: Rectangle {
        id: erow
        required property var dev  // { device, type, state, connection }

        // Active wired connection on this device, if any.
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
            // else: cable unplugged — no-op
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

            // Wired icon
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
        required property var net  // { ssid, security, signal, inUse, bssid }

        width: parent.width
        height: 36 + (popup.passwordPromptSsid === net.ssid ? 36 : 0)
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
            // New network
            if (row.secured) {
                // Open inline password prompt
                popup.passwordPromptPwd = "";
                popup.passwordPromptSsid = net.ssid;
            } else {
                NetworkService.connectWifi(net.ssid, "", false);
            }
        }

        // Top row
        Row {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            height: 36
            spacing: 8

            // Signal icon
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

            // SSID + status
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

            // Right tags (forget button on hover for saved)
            Row {
                id: rightTags
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                // Lock indicator — Font Awesome 7 Solid \uf023.
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

                // Forget button (saved only, hover-revealed)
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
                        // Font Awesome 7 Solid: \uf00d xmark
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

        // Inline password prompt
        Row {
            visible: popup.passwordPromptSsid === net.ssid
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
                    text: popup.passwordPromptPwd
                    onTextChanged: popup.passwordPromptPwd = text
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    echoMode: TextInput.Password
                    selectByMouse: true
                    focus: visible
                    Keys.onReturnPressed: okBtn.activate()
                    Keys.onEnterPressed: okBtn.activate()
                    Keys.onEscapePressed: { popup.passwordPromptSsid = ""; popup.passwordPromptPwd = ""; }

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
                    // Font Awesome 7 Solid: \uf00d xmark
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
                    onClicked: { popup.passwordPromptSsid = ""; popup.passwordPromptPwd = ""; }
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
                    NetworkService.connectWifi(net.ssid, popup.passwordPromptPwd, false);
                    popup.passwordPromptSsid = "";
                    popup.passwordPromptPwd = "";
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

        // Underlying click area
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

    // ================================================================
    // Inline component: section header
    // ================================================================
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
    // Layout
    // ================================================================
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

        opacity: popup.wantOpen ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        transform: Translate {
            y: popup.wantOpen ? 0 : 4
            Behavior on y {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }

        Column {
            id: contentColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 10
            }
            spacing: 10

            // ---- Header ----
            Row {
                width: parent.width
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Network"
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: Font.Bold
                }

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
                    width: parent.width - 60 - rescanBtn.width - wifiToggleBtn.width - parent.spacing * 3
                }

                // Rescan button
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
                        // Font Awesome 7 Solid: \uf021 arrows-rotate.
                        // Click triggers a brief one-revolution spin so the
                        // user sees their action registered (NetworkService
                        // doesn't expose a "currently scanning" flag).
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

                // Wifi toggle (pill switch)
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

            // 1 px divider between header and content (matches VolumePopup).
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            // ---- Ethernet section ----
            // One row per ethernet adapter. Driven by devices, not saved
            // connections, so an adapter doesn't disappear when its
            // ad-hoc profile is deleted on disconnect.
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

            // ---- Wifi disabled placeholder ----
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

            // ---- Wifi list ----
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

                // Empty state
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

            // ---- Last error (if any) ----
            Text {
                visible: NetworkService.lastError.length > 0
                width: parent.width
                text: NetworkService.lastError
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            // ---- Hidden network form (collapsed) ----
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

                    // Toggle row
                    Row {
                        width: parent.width
                        spacing: 6
                        height: 22

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            // Font Awesome 7 Solid: \uf068 minus / \uf067 plus
                            text: popup.hiddenFormOpen ? "\uf068" : "\uf067"
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
                            onClicked: popup.hiddenFormOpen = !popup.hiddenFormOpen
                        }
                    }

                    // SSID field
                    Rectangle {
                        visible: popup.hiddenFormOpen
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
                            text: popup.hiddenSsid
                            onTextChanged: popup.hiddenSsid = text
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

                    // Password field + connect button
                    Row {
                        visible: popup.hiddenFormOpen
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
                                text: popup.hiddenPwd
                                onTextChanged: popup.hiddenPwd = text
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
                                if (!popup.hiddenSsid) return;
                                NetworkService.connectWifi(popup.hiddenSsid, popup.hiddenPwd, true);
                                popup.hiddenSsid = "";
                                popup.hiddenPwd = "";
                                popup.hiddenFormOpen = false;
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
