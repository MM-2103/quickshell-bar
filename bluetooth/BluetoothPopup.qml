// BluetoothPopup.qml
// Plasma-like Bluetooth manager. Sections:
//   - Connected   (paired & connected)
//   - Paired      (paired but not connected)
//   - Available   (found via scan, not paired)
//
// Header has:
//   - Title with adapter status text
//   - Power toggle (turn the adapter on/off)
//   - Scan toggle (start/stop discovery)
//
// Row click action depends on device state:
//   connected     -> disconnect
//   paired        -> connect
//   not paired    -> pair
//   pairing       -> cancel pair
// Right-click on a paired row -> forget

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets
import qs

PopupWindow {
    id: popup

    required property Item anchorItem

    visible: false
    color: "transparent"

    function toggle() {
        if (popup.visible) {
            popup.visible = false;
        } else {
            PopupController.open(popup, () => popup.visible = false);
            popup.visible = true;
        }
    }
    function close() { popup.visible = false; }
    onVisibleChanged: if (!visible) PopupController.closed(popup)

    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? -((popup.width - anchorItem.width) / 2) : 0
    anchor.rect.y: anchorItem ? anchorItem.height + 6 : 0
    anchor.adjustment: PopupAdjustment.SlideX

    implicitWidth: 360
    implicitHeight: contentColumn.implicitHeight + 16

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool adapterEnabled: adapter ? adapter.enabled : false
    readonly property bool scanning: adapter ? adapter.discovering : false

    // Sort: connected first, then paired, then by name.
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

    readonly property var _grouped: _devicesByState()

    // Re-evaluate _grouped when relevant signals fire. Reading the function above
    // tracks Bluetooth.devices.values, but inner connected/paired flags aren't
    // listened to without explicit observation. Use a Connections object on each
    // device to nudge the grouping.
    // Simpler approach: a small Timer that re-runs the grouping while the popup
    // is open (cheap; few devices).
    Timer {
        running: popup.visible
        interval: 1000
        repeat: true
        onTriggered: popup._groupedRefresh = !popup._groupedRefresh
    }
    property bool _groupedRefresh: false

    // ================================================================
    // Inline component: a single device row.
    // ================================================================
    component DeviceRow: Rectangle {
        id: row
        required property var device

        width: parent.width
        height: 40
        radius: Theme.radiusSmall
        color: rowMa.containsMouse ? Theme.surfaceHi : Theme.surface
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        readonly property string label: device
            ? (device.name || device.deviceName || device.address || "(unknown)")
            : ""
        readonly property bool isConnected: device && device.connected
        readonly property bool isPaired: device && (device.paired || device.bonded)
        readonly property bool isPairing: device && device.pairing
        readonly property bool hasBattery: device && device.batteryAvailable
        readonly property real battery: device && device.batteryAvailable ? device.battery : 0

        function _primaryAction() {
            if (!device) return;
            if (isPairing) { device.cancelPair(); return; }
            if (isConnected) { device.disconnect(); return; }
            if (isPaired)    { device.connect(); return; }
            // Not paired -> pair (which usually also connects).
            device.pair();
        }

        function _statusText() {
            if (isPairing)            return "pairing…";
            if (isConnected)          return "connected";
            if (device && device.state) {
                // BluetoothDeviceState may give details (Connecting, Disconnecting).
                const s = device.state;
                if (s === BluetoothDeviceState.Connecting) return "connecting…";
                if (s === BluetoothDeviceState.Disconnecting) return "disconnecting…";
            }
            if (isPaired)             return "paired";
            return "tap to pair";
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 10

            // Device icon
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20

                IconImage {
                    id: devIcon
                    anchors.fill: parent
                    implicitSize: 20
                    source: row.device && row.device.icon
                        ? Quickshell.iconPath(row.device.icon, true)
                        : ""
                    asynchronous: false
                    visible: status === Image.Ready
                }

                // Letter fallback
                Rectangle {
                    visible: !devIcon.visible
                    anchors.fill: parent
                    radius: 3
                    color: Theme.bg
                    border.color: Theme.border
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: row.label.charAt(0).toUpperCase() || "?"
                        color: Theme.text
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }

            // Name + status
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 80 - 30 - 20 - parent.spacing * 3
                spacing: 1

                Text {
                    text: row.label
                    color: row.isConnected ? Theme.text : Theme.text
                    font.pixelSize: 12
                    font.bold: row.isConnected
                    elide: Text.ElideRight
                    width: parent.width
                }

                Text {
                    text: row._statusText()
                    color: row.isConnected ? Theme.textDim : Theme.textMuted
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            // Battery indicator (if available)
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 14
                visible: row.hasBattery

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 10
                    radius: 1
                    color: "transparent"
                    border.color: Theme.textDim
                    border.width: 1

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 1
                        width: (parent.width - 2) * row.battery
                        color: row.battery > 0.2 ? Theme.text : Theme.accent
                    }
                }

                // Battery cap
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 21
                    width: 1
                    height: 6
                    color: Theme.textDim
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(row.battery * 100)
                    color: Theme.textDim
                    font.pixelSize: 9
                    font.family: "monospace"
                }
            }

            // Forget button (paired only, hover-revealed)
            Rectangle {
                id: forgetBtn
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                radius: Theme.radiusSmall
                visible: row.isPaired
                opacity: forgetMa.containsMouse ? 1.0 : (rowMa.containsMouse ? 0.7 : 0.0)
                color: forgetMa.containsMouse ? Theme.bg : "transparent"
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: forgetMa.containsMouse ? Theme.text : Theme.textDim
                    font.pixelSize: 14
                    font.bold: true
                }

                MouseArea {
                    id: forgetMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (row.device) row.device.forget();
                    }
                }
            }
        }

        // Row-wide click area (under the forget button via z order)
        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            z: -1

            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton) {
                    row._primaryAction();
                } else if (mouse.button === Qt.RightButton) {
                    if (row.isPaired && row.device) row.device.forget();
                }
            }
        }
    }

    // ================================================================
    // Inline component: a section header.
    // ================================================================
    component SectionHeader: Text {
        property string label
        property int count
        text: count > 0 ? (label + "  ·  " + count) : label
        color: Theme.textDim
        font.pixelSize: 10
        font.bold: true
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
                    text: "Bluetooth"
                    color: Theme.text
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: popup.adapter
                        ? (popup.adapterEnabled ? popup.adapter.name : "off")
                        : "no adapter"
                    color: Theme.textDim
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    width: parent.width
                        - 75 // power btn + scan btn approx
                        - 60 // title
                        - parent.spacing * 3
                }

                // Scan toggle
                Rectangle {
                    id: scanBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 22
                    radius: Theme.radiusSmall
                    color: scanMa.containsMouse ? Theme.surfaceHi : Theme.surface
                    enabled: popup.adapterEnabled
                    opacity: enabled ? 1.0 : 0.4
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: popup.scanning ? "⟳" : "↻"
                        color: popup.scanning ? Theme.accent : Theme.text
                        font.pixelSize: 13
                        font.bold: true
                        RotationAnimation on rotation {
                            running: popup.scanning
                            from: 0; to: 360
                            duration: 1000
                            loops: Animation.Infinite
                        }
                    }

                    MouseArea {
                        id: scanMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: parent.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (popup.adapter) {
                                popup.adapter.discovering = !popup.adapter.discovering;
                            }
                        }
                    }
                }

                // Power toggle (switch-style pill)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    height: 22
                    radius: 11
                    color: popup.adapterEnabled ? Theme.accent : Theme.surface
                    border.color: Theme.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animMed } }

                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        x: popup.adapterEnabled ? parent.width - width - 3 : 3
                        color: popup.adapterEnabled ? Theme.bg : Theme.text
                        Behavior on x { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (popup.adapter) popup.adapter.enabled = !popup.adapter.enabled;
                        }
                    }
                }
            }

            // ---- Disabled-state placeholder ----
            Text {
                visible: !popup.adapterEnabled
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: popup.adapter
                    ? "Bluetooth is off. Toggle the switch to enable."
                    : "No bluetooth adapter found."
                color: Theme.textDim
                font.pixelSize: 11
                wrapMode: Text.Wrap
                topPadding: 16
                bottomPadding: 16
            }

            // ---- Connected ----
            Column {
                visible: popup.adapterEnabled && popup._grouped.connected.length > 0
                width: parent.width
                spacing: 4

                SectionHeader {
                    label: "CONNECTED"
                    count: popup._grouped.connected.length
                }

                Repeater {
                    model: popup._grouped.connected
                    delegate: DeviceRow {
                        required property var modelData
                        device: modelData
                    }
                }
            }

            // ---- Paired (not connected) ----
            Column {
                visible: popup.adapterEnabled && popup._grouped.paired.length > 0
                width: parent.width
                spacing: 4

                SectionHeader {
                    label: "PAIRED"
                    count: popup._grouped.paired.length
                }

                Repeater {
                    model: popup._grouped.paired
                    delegate: DeviceRow {
                        required property var modelData
                        device: modelData
                    }
                }
            }

            // ---- Discovered (during scan) ----
            Column {
                visible: popup.adapterEnabled && popup._grouped.discovered.length > 0
                width: parent.width
                spacing: 4

                SectionHeader {
                    label: "AVAILABLE"
                    count: popup._grouped.discovered.length
                }

                Repeater {
                    model: popup._grouped.discovered
                    delegate: DeviceRow {
                        required property var modelData
                        device: modelData
                    }
                }
            }

            // Empty-state message when scanning but no devices found yet.
            Text {
                visible: popup.adapterEnabled
                    && popup._grouped.connected.length === 0
                    && popup._grouped.paired.length === 0
                    && popup._grouped.discovered.length === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: popup.scanning ? "Scanning…" : "No devices. Click the scan button to find some."
                color: Theme.textDim
                font.pixelSize: 11
                topPadding: 8
                bottomPadding: 8
            }
        }
    }
}
