// NetworkView.qml
// Wi-Fi and Ethernet picker, shown inside the Control Center. Pure
// content: ControlCenterPopup supplies the card, title and back arrow.
//
// Layout and behaviour follow the list-row rules in docs/STYLE.md, shared
// with BluetoothView: rows do nothing when clicked, every action is an
// always-visible IconButton, left click only.
//
// Lifecycle: the CC's Loader instantiates this view on navigation in and
// destroys it on navigation out. Component.onCompleted triggers one scan.
// There is no polling timer. NetworkService keeps the scanner on, and
// Quickshell rescans every 10 s by itself. A timer that called rescan()
// every 8 s used to destroy the row being typed into; see rescan().

import QtQuick
import Quickshell
import qs
import qs.ui

Item {
    id: view

    // SSID whose row shows the password field.
    property string passwordPromptSsid: ""
    property string passwordPromptPwd: ""

    // Hidden network form state.
    property bool hiddenFormOpen: false
    property string hiddenSsid: ""
    property string hiddenPwd: ""

    readonly property var _connected: NetworkService.wirelessNetworks.filter(n => n.inUse)
    readonly property var _saved:     NetworkService.wirelessNetworks.filter(n => !n.inUse && n.saved)
    readonly property var _available: NetworkService.wirelessNetworks.filter(n => !n.inUse && !n.saved)

    function _closePrompt() {
        view.passwordPromptSsid = "";
        view.passwordPromptPwd = "";
    }

    Component.onCompleted: {
        NetworkService.refreshAll();
        NetworkService.rescan();
    }

    // Wrong or missing password: open the field again for that network.
    Connections {
        target: NetworkService
        function onPasswordRequired(ssid) {
            view.passwordPromptPwd = "";
            view.passwordPromptSsid = ssid;
        }
    }

    // ================================================================
    // Ethernet device row.
    // ================================================================
    component EthernetRow: ListRow {
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
        readonly property bool busy:
            dev.state === "connecting" || dev.state === "deactivating"

        title: isActive ? activeConn.name : "Wired (" + dev.device + ")"
        status: {
            if (dev.state === "connecting")   return "connecting…";
            if (dev.state === "deactivating") return "disconnecting…";
            if (isActive)                     return "connected  ·  " + dev.device;
            if (cablePlugged)                 return "cable connected  ·  " + dev.device;
            return "cable unplugged  ·  " + dev.device;
        }
        emphasized: isActive
        dimmed: !cablePlugged && !isActive
        iconName: isActive ? "network-wired-activated-symbolic" : "network-wired-symbolic"
        glyph: "\uf796"

        IconButton {
            present: erow.isActive || erow.cablePlugged || erow.busy
            busy: erow.busy
            glyph: erow.isActive ? "\uf127" : "\uf0c1"
            hint: erow.isActive ? "Disconnect" : "Connect"
            onClicked: {
                if (erow.isActive) NetworkService.disconnectDevice(erow.dev.device);
                else NetworkService.connectDevice(erow.dev.device);
            }
        }
        // Wired profiles are not forgotten from here. The empty slot keeps
        // the connect button in the same column as the Wi-Fi rows.
        IconButton { present: false }
    }

    // ================================================================
    // Wi-Fi network row.
    // ================================================================
    component WifiRow: ListRow {
        id: row
        required property var net

        readonly property bool secured: net.security !== ""
        readonly property bool prompting: view.passwordPromptSsid === net.ssid
        readonly property bool busy: net.connecting || net.disconnecting

        function _signalIcon() {
            const s = net.signal;
            const tier = s >= 80 ? 100 : s >= 55 ? 75 : s >= 30 ? 50 : s > 0 ? 25 : 0;
            return "network-wireless-connected-" + (tier < 10 ? "00" : tier) + "-symbolic";
        }

        function _connect() {
            if (net.saved) {
                NetworkService.connectByName(net.ssid);
            } else if (net.pskCapable) {
                view.passwordPromptPwd = "";
                view.passwordPromptSsid = net.ssid;
            } else {
                NetworkService.connectWifi(net.ssid, "", false);
            }
        }

        function _submit() {
            if (view.passwordPromptPwd.length === 0) return;
            NetworkService.connectWifi(net.ssid, view.passwordPromptPwd, false);
            view._closePrompt();
        }

        title: net.ssid
        status: {
            if (net.connecting)    return "connecting…";
            if (net.disconnecting) return "disconnecting…";
            if (net.failure)       return net.failure;
            const parts = [];
            if (net.inUse) parts.push("connected");
            parts.push(secured ? net.security : "open");
            parts.push(net.signal + "%");
            return parts.join("  ·  ");
        }
        statusError: !busy && net.failure !== ""
        emphasized: net.inUse
        iconName: _signalIcon()
        glyph: "\uf1eb"
        expanded: prompting

        // A rescan drops unsaved networks from the list for a moment, so
        // this row can be destroyed and rebuilt mid-prompt. The typed text
        // survives in view.passwordPromptPwd; focus has to be put back.
        Component.onCompleted: {
            if (row.prompting) Qt.callLater(() => pwdField.focusInput());
        }

        IconButton {
            busy: row.busy
            // The password row has its own Connect and Cancel.
            enabled: !row.prompting
            glyph: net.inUse ? "\uf127" : "\uf0c1"
            hint: net.inUse ? "Disconnect" : "Connect"
            onClicked: {
                if (net.inUse) NetworkService.disconnectByName(net.ssid);
                else row._connect();
            }
        }

        IconButton {
            present: net.saved
            glyph: "\uf2ed"
            hint: "Forget"
            confirm: true
            confirmHint: "Click again to forget"
            onClicked: NetworkService.forgetByName(net.ssid)
        }

        expansion: Item {
            width: parent.width
            height: 24

            InputField {
                id: pwdField
                anchors.left: parent.left
                anchors.right: cancelBtn.left
                anchors.rightMargin: 4
                password: true
                placeholder: "Password"
                text: view.passwordPromptPwd
                onTextChanged: view.passwordPromptPwd = text
                onAccepted: row._submit()
                onCancelled: view._closePrompt()
                // Deferred because the row expands in the same tick as the
                // click that opened it.
                onVisibleChanged: if (visible) Qt.callLater(() => pwdField.focusInput())
            }

            IconButton {
                id: cancelBtn
                anchors.right: okBtn.left
                anchors.rightMargin: 4
                glyph: "\uf00d"
                hint: "Cancel"
                onClicked: view._closePrompt()
            }

            IconButton {
                id: okBtn
                anchors.right: parent.right
                glyph: "\uf0c1"
                hint: "Connect"
                enabled: view.passwordPromptPwd.length > 0
                onClicked: row._submit()
            }
        }
    }

    // ================================================================
    // Layout
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

            ViewHeader {
                id: header
                text: NetworkService.wiredConnected
                    ? "Wired connected"
                    : NetworkService.wifiConnected
                        ? ("Wi‑Fi  ·  " + NetworkService.currentSsid)
                        : NetworkService.wifiEnabled
                            ? "Disconnected"
                            : "Wi‑Fi off"
                scanHint: "Rescan"
                scanEnabled: NetworkService.wifiEnabled
                switchChecked: NetworkService.wifiEnabled
                switchHint: NetworkService.wifiEnabled ? "Turn Wi‑Fi off" : "Turn Wi‑Fi on"
                onScanClicked: {
                    NetworkService.rescan();
                    header.spinOnce();
                }
                onSwitchToggled: NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)
            }

            ListSection {
                label: "ETHERNET"
                // ScriptModel so a state change rebuilds only the row that
                // changed, not every row.
                model: ScriptModel {
                    values: NetworkService.ethernetDevices
                    objectProp: "device"
                }
                delegate: EthernetRow {
                    required property var modelData
                    dev: modelData
                }
            }

            EmptyState {
                visible: !NetworkService.wifiEnabled
                text: "Wi‑Fi is off. Turn it on with the switch above."
            }

            // ScriptModel on each Wi-Fi section: without it, a
            // signal-strength update reassigns the array and every row,
            // each with an IconImage, is destroyed and rebuilt.
            ListSection {
                visible: NetworkService.wifiEnabled && count > 0
                label: "CONNECTED"
                model: ScriptModel { values: view._connected; objectProp: "ssid" }
                delegate: WifiRow {
                    required property var modelData
                    net: modelData
                }
            }

            ListSection {
                visible: NetworkService.wifiEnabled && count > 0
                label: "SAVED"
                model: ScriptModel { values: view._saved; objectProp: "ssid" }
                delegate: WifiRow {
                    required property var modelData
                    net: modelData
                }
            }

            ListSection {
                visible: NetworkService.wifiEnabled && count > 0
                label: "AVAILABLE"
                model: ScriptModel { values: view._available; objectProp: "ssid" }
                delegate: WifiRow {
                    required property var modelData
                    net: modelData
                }
            }

            EmptyState {
                visible: NetworkService.wifiEnabled && NetworkService.wirelessNetworks.length === 0
                text: "No networks found. Use the rescan button above."
            }

            // Hidden network: a row like the others, with the form as its
            // expansion. nmcli errors from this path show in its status.
            ListRow {
                visible: NetworkService.wifiEnabled
                title: "Hidden network"
                status: NetworkService.lastError !== ""
                    ? NetworkService.lastError
                    : "not broadcasting its name"
                statusError: NetworkService.lastError !== ""
                glyph: "\uf070"
                expanded: view.hiddenFormOpen

                IconButton {
                    glyph: view.hiddenFormOpen ? "\uf068" : "\uf067"
                    hint: view.hiddenFormOpen ? "Close" : "Enter network details"
                    onClicked: view.hiddenFormOpen = !view.hiddenFormOpen
                }
                IconButton { present: false }

                expansion: Column {
                    id: hiddenForm
                    width: parent.width
                    spacing: 6

                    function submit() {
                        if (!view.hiddenSsid) return;
                        NetworkService.connectWifi(view.hiddenSsid, view.hiddenPwd, true);
                        view.hiddenSsid = "";
                        view.hiddenPwd = "";
                        view.hiddenFormOpen = false;
                    }

                    InputField {
                        id: hiddenSsidField
                        width: parent.width
                        placeholder: "SSID"
                        text: view.hiddenSsid
                        onTextChanged: view.hiddenSsid = text
                        onAccepted: hiddenPwdField.focusInput()
                        onCancelled: view.hiddenFormOpen = false
                        onVisibleChanged: if (visible) Qt.callLater(() => hiddenSsidField.focusInput())
                    }

                    Item {
                        width: parent.width
                        height: 24

                        InputField {
                            id: hiddenPwdField
                            anchors.left: parent.left
                            anchors.right: hiddenConnectBtn.left
                            anchors.rightMargin: 4
                            password: true
                            placeholder: "Password (optional)"
                            text: view.hiddenPwd
                            onTextChanged: view.hiddenPwd = text
                            onAccepted: hiddenForm.submit()
                            onCancelled: view.hiddenFormOpen = false
                        }

                        IconButton {
                            id: hiddenConnectBtn
                            anchors.right: parent.right
                            glyph: "\uf0c1"
                            hint: "Connect"
                            enabled: view.hiddenSsid.length > 0
                            onClicked: hiddenForm.submit()
                        }
                    }
                }
            }
        }
    }
}
