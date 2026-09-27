// BluetoothView.qml
// Bluetooth device picker, shown inside the Control Center. Pure content:
// ControlCenterPopup supplies the card, title and back arrow.
//
// Layout and behaviour follow the list-row rules in docs/STYLE.md, shared
// with NetworkView: rows do nothing when clicked, every action is an
// always-visible IconButton, left click only.
//
// Lifecycle: instantiated on navigation in, destroyed on navigation out.
// Discovery is not started automatically; the scan button toggles it.

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.ui

Item {
    id: view

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool adapterEnabled: adapter ? adapter.enabled : false
    readonly property bool scanning: adapter ? adapter.discovering : false

    function _devicesByState() {
        const all = Bluetooth.devices.values;
        const connected = [];
        const paired = [];
        const discovered = [];
        for (let i = 0; i < all.length; i++) {
            const d = all[i];
            if (!d) continue;
            if (d.connected) connected.push(d);
            else if (d.paired || d.bonded) paired.push(d);
            else discovered.push(d);
        }
        const byName = (a, b) => {
            const an = (a.name || a.deviceName || a.address || "").toLowerCase();
            const bn = (b.name || b.deviceName || b.address || "").toLowerCase();
            return an < bn ? -1 : an > bn ? 1 : 0;
        };
        connected.sort(byName);
        paired.sort(byName);
        discovered.sort(byName);
        return { connected, paired, discovered };
    }

    // The per-device flags DO re-trigger this: QML registers binding
    // dependencies per property *read*, so `d.connected` inside
    // _devicesByState() tracks that device's property.
    readonly property var _grouped: _devicesByState()
    readonly property int _deviceCount:
        _grouped.connected.length + _grouped.paired.length + _grouped.discovered.length

    // ================================================================
    // Device row.
    // ================================================================
    component DeviceRow: ListRow {
        id: row
        required property var device

        readonly property bool isConnected: !!device && device.connected
        readonly property bool isPaired: !!device && (device.paired || device.bonded)
        readonly property bool isPairing: !!device && device.pairing
        readonly property bool isConnecting:
            !!device && device.state === BluetoothDeviceState.Connecting
        readonly property bool isDisconnecting:
            !!device && device.state === BluetoothDeviceState.Disconnecting
        readonly property bool hasBattery: !!device && device.batteryAvailable
        readonly property int batteryPct: hasBattery ? Math.round(device.battery * 100) : 0
        readonly property bool batteryLow: hasBattery && batteryPct <= 20

        title: device ? (device.name || device.deviceName || device.address || "(unknown)") : ""
        status: {
            if (isPairing)       return "pairing…";
            if (isConnecting)    return "connecting…";
            if (isDisconnecting) return "disconnecting…";
            const parts = [isConnected ? "connected" : isPaired ? "paired" : "not paired"];
            if (hasBattery) parts.push(batteryPct + "%");
            return parts.join("  ·  ");
        }
        statusError: batteryLow && !isPairing && !isConnecting && !isDisconnecting
        emphasized: isConnected
        iconName: device && device.icon ? device.icon : ""
        fallbackText: title.charAt(0).toUpperCase() || "?"

        IconButton {
            busy: row.isConnecting || row.isDisconnecting
            glyph: row.isPairing ? "\uf00d" : row.isConnected ? "\uf127" : "\uf0c1"
            hint: row.isPairing ? "Cancel pairing"
                : row.isConnected ? "Disconnect"
                : row.isPaired ? "Connect"
                : "Pair"
            onClicked: {
                if (!row.device) return;
                if (row.isPairing)        row.device.cancelPair();
                else if (row.isConnected) row.device.disconnect();
                else if (row.isPaired)    row.device.connect();
                else                      row.device.pair();
            }
        }

        IconButton {
            present: row.isPaired
            glyph: "\uf2ed"
            hint: "Forget"
            confirm: true
            confirmHint: "Click again to forget"
            onClicked: if (row.device) row.device.forget()
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
                text: view.adapter
                    ? (view.adapterEnabled ? view.adapter.name : "Bluetooth off")
                    : "No adapter"
                scanHint: view.scanning ? "Stop scanning" : "Scan for devices"
                scanEnabled: view.adapterEnabled
                scanning: view.scanning
                switchChecked: view.adapterEnabled
                switchEnabled: view.adapter !== null
                switchHint: view.adapterEnabled ? "Turn Bluetooth off" : "Turn Bluetooth on"
                onScanClicked: {
                    if (view.adapter) view.adapter.discovering = !view.adapter.discovering;
                }
                onSwitchToggled: {
                    if (view.adapter) view.adapter.enabled = !view.adapter.enabled;
                }
            }

            EmptyState {
                visible: !view.adapterEnabled
                text: view.adapter
                    ? "Bluetooth is off. Turn it on with the switch above."
                    : "No Bluetooth adapter found."
            }

            ListSection {
                visible: view.adapterEnabled && count > 0
                label: "CONNECTED"
                model: ScriptModel { values: view._grouped.connected }
                delegate: DeviceRow {
                    required property var modelData
                    device: modelData
                }
            }

            ListSection {
                visible: view.adapterEnabled && count > 0
                label: "PAIRED"
                model: ScriptModel { values: view._grouped.paired }
                delegate: DeviceRow {
                    required property var modelData
                    device: modelData
                }
            }

            ListSection {
                visible: view.adapterEnabled && count > 0
                label: "AVAILABLE"
                model: ScriptModel { values: view._grouped.discovered }
                delegate: DeviceRow {
                    required property var modelData
                    device: modelData
                }
            }

            EmptyState {
                visible: view.adapterEnabled && view._deviceCount === 0
                text: view.scanning
                    ? "Scanning…"
                    : "No devices found. Use the scan button above."
            }
        }
    }
}
