// BluetoothView.qml
// Embeddable bluetooth picker. Extracted from the old BluetoothPopup so
// the Control Center can host the same UI as a sub-view.
//
// Composition: a Flickable wrapping the original BluetoothPopup content
// column (header row, three sections: connected / paired / available).
// Card chrome supplied by ControlCenterPopup.
//
// Lifecycle: instantiated on navigation in, destroyed on navigation out.
// The 1 s grouping-refresh Timer runs only while the view exists.

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets
import qs

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

    readonly property var _grouped: _devicesByState()
    property bool _groupedRefresh: false

    // Per-device connected/paired flags don't trigger _grouped re-evaluation
    // automatically; nudge it periodically while the view is visible.
    Timer {
        running: true
        interval: 1000
        repeat: true
        onTriggered: view._groupedRefresh = !view._groupedRefresh
    }

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
            device.pair();
        }

        function _statusText() {
            if (isPairing)            return "pairing…";
            if (isConnected)          return "connected";
            if (device && device.state) {
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
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 80 - 30 - 20 - parent.spacing * 3
                spacing: 1

                Text {
                    text: row.label
                    color: row.isConnected ? Theme.text : Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: row.isConnected ? Font.Bold : Font.Normal
                    elide: Text.ElideRight
                    width: parent.width
                }

                Text {
                    text: row._statusText()
                    color: row.isConnected ? Theme.textDim : Theme.textMuted
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 14
                visible: row.hasBattery

                function _glyph() {
                    const p = row.battery;
                    if (p >= 0.80) return "\uf240";
                    if (p >= 0.60) return "\uf241";
                    if (p >= 0.40) return "\uf242";
                    if (p >= 0.20) return "\uf243";
                    return "\uf244";
                }

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent._glyph()
                    color: row.battery > 0.2 ? Theme.textDim : Theme.error
                    font.family: Theme.fontIcon
                    font.styleName: "Solid"
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(row.battery * 100)
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeBadge
                }
            }

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
                    onClicked: {
                        if (row.device) row.device.forget();
                    }
                }
            }
        }

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

    component SectionHeader: Text {
        property string label
        property int count
        text: count > 0 ? (label + "  ·  " + count) : label
        color: Theme.textDim
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Bold
    }

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

            // Header (status + scan button + power switch).
            Row {
                width: parent.width
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: view.adapter
                        ? (view.adapterEnabled ? view.adapter.name : "off")
                        : "no adapter"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    width: parent.width - scanBtn.width - powerBtn.width - parent.spacing * 2
                }

                Rectangle {
                    id: scanBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 22
                    radius: Theme.radiusSmall
                    color: scanMa.containsMouse ? Theme.surfaceHi : Theme.surface
                    enabled: view.adapterEnabled
                    opacity: enabled ? 1.0 : 0.4
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf021"
                        color: view.scanning ? Theme.accent : Theme.text
                        font.family: Theme.fontIcon
                        font.styleName: "Solid"
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                        RotationAnimation on rotation {
                            running: view.scanning
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
                            if (view.adapter) {
                                view.adapter.discovering = !view.adapter.discovering;
                            }
                        }
                    }
                }

                Rectangle {
                    id: powerBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    height: 22
                    radius: 11
                    color: view.adapterEnabled ? Theme.accent : Theme.surface
                    border.color: Theme.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animMed } }

                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        x: view.adapterEnabled ? parent.width - width - 3 : 3
                        color: view.adapterEnabled ? Theme.bg : Theme.text
                        Behavior on x { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (view.adapter) view.adapter.enabled = !view.adapter.enabled;
                        }
                    }
                }
            }

            Text {
                visible: !view.adapterEnabled
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: view.adapter
                    ? "Bluetooth is off. Toggle the switch to enable."
                    : "No bluetooth adapter found."
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
                topPadding: 16
                bottomPadding: 16
            }

            Rectangle {
                visible: view.adapterEnabled
                    && (view._grouped.connected.length > 0
                        || view._grouped.paired.length > 0
                        || view._grouped.discovered.length > 0)
                width: parent.width
                height: 1
                color: Theme.border
            }

            Column {
                visible: view.adapterEnabled && view._grouped.connected.length > 0
                width: parent.width
                spacing: 4

                SectionHeader {
                    label: "CONNECTED"
                    count: view._grouped.connected.length
                }

                Repeater {
                    model: view._grouped.connected
                    delegate: DeviceRow {
                        required property var modelData
                        device: modelData
                    }
                }
            }

            Column {
                visible: view.adapterEnabled && view._grouped.paired.length > 0
                width: parent.width
                spacing: 4

                SectionHeader {
                    label: "PAIRED"
                    count: view._grouped.paired.length
                }

                Repeater {
                    model: view._grouped.paired
                    delegate: DeviceRow {
                        required property var modelData
                        device: modelData
                    }
                }
            }

            Column {
                visible: view.adapterEnabled && view._grouped.discovered.length > 0
                width: parent.width
                spacing: 4

                SectionHeader {
                    label: "AVAILABLE"
                    count: view._grouped.discovered.length
                }

                Repeater {
                    model: view._grouped.discovered
                    delegate: DeviceRow {
                        required property var modelData
                        device: modelData
                    }
                }
            }

            Text {
                visible: view.adapterEnabled
                    && view._grouped.connected.length === 0
                    && view._grouped.paired.length === 0
                    && view._grouped.discovered.length === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: view.scanning ? "Scanning…" : "No devices. Click the scan button to find some."
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                topPadding: 8
                bottomPadding: 8
            }
        }
    }
}
