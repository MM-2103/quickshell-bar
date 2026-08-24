pragma Singleton

// NetworkService.qml
// NetworkManager state + actions, via Quickshell.Networking.
//
// Previously this shelled out to nmcli: a long-running `nmcli monitor` plus
// five terse queries re-run on every event, and a hand-rolled parser for
// nmcli's escaped-colon output. All of that is gone -- the native module is
// reactive, so there is no process, no polling, and no parsing.
//
// The public surface below is deliberately UNCHANGED from the nmcli version:
// same property names, same object shapes, same function signatures. The
// native types are richer, but translating at this boundary keeps
// NetworkView.qml and controlcenter/TilesView.qml working untouched. The
// translation is the point of this file, not an accident of it.
//
// Native quirks this file absorbs, all verified against real hardware:
//
//   - signalStrength is 0.0-1.0, not 0-100. The view's tier thresholds
//     and percent suffix assume 0-100, so it is scaled here.
//   - WifiDevice.scannerEnabled must be true or `networks` holds a single
//     entry instead of the visible APs. It is not a one-shot rescan; it is
//     a continuous mode.
//   - NetworkDevice.address is the MAC, not the IP.
//   - Property changes on individual Network objects do NOT invalidate a
//     binding that reads the model's `values` list, because the list
//     identity is unchanged. Hence the watcher Instantiators below.
//
// Known limitation: a saved HIDDEN network reports known=false and
// nmSettings=0 even though NetworkManager has the profile -- the AP that
// carries the resolved SSID is not linked to the hidden profile. It still
// appears in the list and still connects, because connect() lets NM use its
// own stored secrets; only the "saved" label and the forget button are
// affected. Creating a hidden profile is impossible natively (NMSettings is
// not constructible from QML), so connectWifi() keeps an nmcli path for
// that one case.
//
// IMPORTANT: pragma Singleton must be line 1 (gotcha #45). Header comments
// must NOT contain curly braces -- the qmlscanner doesn't strip them and the
// brace tracker gets confused, silently registering this file as a regular
// type instead of a singleton.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Singleton {
    id: root

    // ================= Public contract =================
    // Consumed by network/NetworkView.qml and controlcenter/TilesView.qml.

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property string globalState: {
        switch (Networking.connectivity) {
        case NetworkConnectivity.Full:    return "connected";
        case NetworkConnectivity.Limited: return "connected (local only)";
        case NetworkConnectivity.Portal:  return "connected (captive portal)";
        case NetworkConnectivity.None:    return "disconnected";
        default:                          return "unknown";
        }
    }

    property string lastError: ""
    signal actionFinished(bool ok, string message)

    // These four are PLAIN properties assigned by _recompute(), not bindings.
    //
    // As bindings they were reassigned ~114 times in the first second: every
    // dependency change recomputed them, and every reassignment makes the
    // view's Repeaters destroy and rebuild all ~20 delegates, each doing an
    // icon lookup. That is ~2300 delegate creations on open, and it showed up
    // as a visible stall when entering the Wi-Fi view. Recomputing explicitly
    // on a coalescing tick makes it one rebuild per burst instead.

    property var wirelessNetworks: []   // { ssid, security, signal, inUse, bssid }
    property var devices: []            // { device, type, state, connection }
    property var activeConnections: []  // { name, type, device, state }
    property var savedConnections: []   // { name, uuid, type }

    function _recompute() {
        const devs = root._deviceList;

        const devOut = [];
        const activeOut = [];
        const savedOut = [];
        for (let i = 0; i < devs.length; i++) {
            const d = devs[i];
            if (!d) continue;
            const net = root._activeNetworkOf(d);
            const connType = root._connectionTypeString(d);

            devOut.push({
                device: d.name,
                type: root._deviceTypeString(d),
                state: root._deviceStateString(d),
                connection: net ? net.name : ""
            });

            if (d.connected) {
                activeOut.push({
                    name: net ? net.name : d.name,
                    type: connType,
                    device: d.name,
                    state: "activated"
                });
            }

            // savedConnections is synthesised from networks reporting
            // known=true. uuid is always "" -- not exposed natively, and
            // nothing reads it. The view uses this only to decide whether a
            // row renders as "saved".
            const nets = d.networks ? d.networks.values : [];
            for (let j = 0; j < nets.length; j++) {
                const n = nets[j];
                if (!n || !n.known || !n.name || n.name.length === 0) continue;
                savedOut.push({ name: n.name, uuid: "", type: connType });
            }
        }

        const wifiOut = [];
        const dev = root._wifiDevice;
        const wnets = (dev && dev.networks) ? dev.networks.values : [];
        for (let i = 0; i < wnets.length; i++) {
            const n = wnets[i];
            // Unnamed rows are hidden APs beaconing without an SSID. The
            // nmcli version skipped them too; there is nothing to show and
            // nothing to connect to.
            if (!n || !n.name || n.name.length === 0) continue;
            wifiOut.push({
                inUse: n.connected,
                bssid: "",                           // not exposed natively; unused by the view
                ssid: n.name,
                security: root._securityLabel(n.security),
                signal: Math.round(n.signalStrength * 100)
            });
        }
        // The native model already dedupes by SSID, so unlike the nmcli
        // version there is no strongest-wins pass -- only the ordering.
        wifiOut.sort((a, b) => a.inUse !== b.inUse ? (a.inUse ? -1 : 1) : b.signal - a.signal);

        // Assign only on real change. Repeaters rebuild every delegate on
        // reassignment, so an identical array is not a free no-op.
        if (JSON.stringify(devOut)    !== JSON.stringify(root.devices))            root.devices = devOut;
        if (JSON.stringify(activeOut) !== JSON.stringify(root.activeConnections))  root.activeConnections = activeOut;
        if (JSON.stringify(savedOut)  !== JSON.stringify(root.savedConnections))   root.savedConnections = savedOut;
        if (JSON.stringify(wifiOut)   !== JSON.stringify(root.wirelessNetworks))   root.wirelessNetworks = wifiOut;
    }

    readonly property var primaryActive: {
        const a = activeConnections;
        let wifi = null, eth = null, other = null;
        for (let i = 0; i < a.length; i++) {
            const c = a[i];
            if (c.type === "802-11-wireless") wifi = c;
            else if (c.type === "802-3-ethernet") eth = c;
            else if (c.device !== "lo" && !other) other = c;
        }
        return wifi || eth || other || null;
    }

    readonly property string currentSsid: {
        for (let i = 0; i < activeConnections.length; i++) {
            if (activeConnections[i].type === "802-11-wireless") return activeConnections[i].name;
        }
        return "";
    }

    readonly property bool wifiConnected: currentSsid !== ""

    readonly property bool wiredConnected: {
        for (let i = 0; i < activeConnections.length; i++) {
            if (activeConnections[i].type === "802-3-ethernet"
                && activeConnections[i].state === "activated") return true;
        }
        return false;
    }

    readonly property var ethernetDevices: {
        const out = [];
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === "ethernet") out.push(devices[i]);
        }
        return out;
    }

    readonly property var ethernetConnections: {
        const out = [];
        for (let i = 0; i < savedConnections.length; i++) {
            const s = savedConnections[i];
            if (s.type !== "802-3-ethernet") continue;
            let active = null;
            for (let j = 0; j < activeConnections.length; j++) {
                if (activeConnections[j].name === s.name
                    && activeConnections[j].type === "802-3-ethernet") { active = activeConnections[j]; break; }
            }
            out.push({
                name: s.name, uuid: s.uuid,
                active: active !== null,
                device: active ? active.device : "",
                state: active ? active.state : "deactivated"
            });
        }
        return out;
    }

    readonly property bool hasEthernetHardware: ethernetDevices.length > 0

    // ---- Actions ----

    function setWifiEnabled(on) { Networking.wifiEnabled = !!on; }

    // Kept for API compatibility: five call sites still invoke these, and
    // the native module is reactive so there is nothing to refresh.
    function refreshAll() { /* reactive; no-op */ }

    // scannerEnabled is a continuous mode, not a one-shot. Cycling it is the
    // closest equivalent to `nmcli device wifi rescan`.
    function rescan() {
        const dev = root._wifiDevice;
        if (!dev) return;
        dev.scannerEnabled = false;
        dev.scannerEnabled = true;
    }

    function connectByName(name) {
        const n = root._findNetwork(name);
        if (n) n.connect();
    }

    function disconnectByName(name) {
        const n = root._findNetwork(name);
        if (n) n.disconnect();
    }

    function forgetByName(name) {
        const n = root._findNetwork(name);
        if (n) n.forget();
    }

    function connectWifi(ssid, password, hidden) {
        const n = root._findNetwork(ssid);

        // A hidden SSID that is not already saved never appears in a scan,
        // so there is no Network object to act on -- and NMSettings cannot be
        // constructed from QML to make one. nmcli is the only route.
        if (!n) {
            hiddenConnectProc.command = ["nmcli", "device", "wifi", "connect", ssid]
                .concat(password && password.length > 0 ? ["password", password] : [])
                .concat(hidden ? ["hidden", "yes"] : []);
            hiddenConnectProc.running = true;
            return;
        }

        // Try without secrets first even when a password was supplied: the
        // backend may already hold one, and connect() failing with NoSecrets
        // is how we learn it does not. Recommended by the Quickshell docs.
        if (password && password.length > 0) n.connectWithPsk(password);
        else n.connect();
    }

    function connectDevice(device) {
        const d = root._findDevice(device);
        if (!d) return;
        // Wired devices expose their single profile directly.
        if (d.network) { d.network.connect(); return; }
        const nets = d.networks ? d.networks.values : [];
        for (let i = 0; i < nets.length; i++) {
            if (nets[i] && nets[i].known) { nets[i].connect(); return; }
        }
    }

    function disconnectDevice(device) {
        const d = root._findDevice(device);
        if (d) d.disconnect();
    }

    // ================= Internals =================

    readonly property var _deviceList: Networking.devices ? Networking.devices.values : []

    readonly property var _wifiDevice: {
        const d = root._deviceList;
        for (let i = 0; i < d.length; i++) if (d[i] && d[i].type === DeviceType.Wifi) return d[i];
        return null;
    }

    // Recompute counter, exposed for diagnostics.
    property int _rev: 0

    // Watchers call _bump() on every observed property change. A scan update
    // produces one per changed network, so they arrive in bursts of 10-15;
    // this collapses a burst into a single recompute.
    //
    // Leading-edge window rather than Timer.restart(): the first bump opens a
    // 120 ms window and everything inside it is absorbed. restart() would push
    // the deadline forward on each bump, so a steady stream of changes could
    // starve the update indefinitely.
    Timer {
        id: coalesce
        interval: 120
        repeat: false
        onTriggered: {
            root._rev++;
            root._recompute();
        }
    }
    function _bump() { if (!coalesce.running) coalesce.start(); }

    // Structural changes (a device appearing, the wifi radio coming up) must
    // recompute too, not just per-network property changes.
    on_DeviceListChanged: root._bump()
    on_WifiDeviceChanged: {
        root._syncScanner();
        root._bump();
    }

    function _deviceTypeString(d) {
        if (d.type === DeviceType.Wifi) return "wifi";
        if (d.type === DeviceType.Wired) return "ethernet";
        return "";
    }

    function _connectionTypeString(d) {
        // NM's *connection* vocabulary, which differs from its device
        // vocabulary. The view matches on both, in different places.
        if (d.type === DeviceType.Wifi) return "802-11-wireless";
        if (d.type === DeviceType.Wired) return "802-3-ethernet";
        return "";
    }

    function _deviceStateString(d) {
        // Reconstructs the nmcli device-state strings the view branches on.
        // hasLink is a genuine improvement: the nmcli version inferred cable
        // state from a device string that did not really mean that.
        if (!d.nmManaged) return "unmanaged";
        if (d.type === DeviceType.Wired && !d.hasLink) return "unavailable";
        if (d.connected) return "connected";
        if (d.state === ConnectionState.Connecting) return "connecting";
        if (d.state === ConnectionState.Disconnecting) return "deactivating";
        return "disconnected";
    }

    function _securityLabel(sec) {
        switch (sec) {
        case WifiSecurityType.Open:          return "";
        case WifiSecurityType.Owe:           return "OWE";
        case WifiSecurityType.WpaPsk:        return "WPA1";
        case WifiSecurityType.Wpa2Psk:       return "WPA2";
        case WifiSecurityType.Sae:           return "WPA3";
        case WifiSecurityType.Wpa3SuiteB192: return "WPA3";
        case WifiSecurityType.WpaEap:        return "WPA1 802.1X";
        case WifiSecurityType.Wpa2Eap:       return "WPA2 802.1X";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep:    return "WEP";
        case WifiSecurityType.Leap:          return "LEAP";
        default:                             return "";
        }
    }

    function _activeNetworkOf(d) {
        if (!d) return null;
        if (d.network) return d.network;             // WiredDevice
        const nets = d.networks ? d.networks.values : [];
        for (let i = 0; i < nets.length; i++) if (nets[i] && nets[i].connected) return nets[i];
        return null;
    }

    function _findDevice(name) {
        const d = root._deviceList;
        for (let i = 0; i < d.length; i++) if (d[i] && d[i].name === name) return d[i];
        return null;
    }

    function _findNetwork(name) {
        const d = root._deviceList;
        for (let i = 0; i < d.length; i++) {
            const nets = d[i] && d[i].networks ? d[i].networks.values : [];
            for (let j = 0; j < nets.length; j++) if (nets[j] && nets[j].name === name) return nets[j];
        }
        return null;
    }

    function _failureMessage(reason) {
        switch (reason) {
        case ConnectionFailReason.NoSecrets:              return "Wrong password";
        case ConnectionFailReason.WifiAuthTimeout:        return "Authentication timed out";
        case ConnectionFailReason.WifiNetworkLost:        return "Network out of range";
        case ConnectionFailReason.WifiClientDisconnected: return "Disconnected by the network";
        case ConnectionFailReason.WifiClientFailed:       return "Connection failed";
        default:                                          return "Connection failed";
        }
    }

    // ---- Watchers ----
    //
    // One delegate per device and per network, existing purely to observe
    // property changes and bump _rev. Without these the derived arrays never
    // recompute: `values` only notifies on structural change.

    Instantiator {
        model: Networking.devices
        delegate: QtObject {
            required property var modelData
            readonly property bool connected: modelData ? modelData.connected : false
            readonly property int  devState:  modelData ? modelData.state : 0
            readonly property bool managed:   modelData ? modelData.nmManaged : false
            onConnectedChanged: root._bump()
            onDevStateChanged:  root._bump()
            onManagedChanged:   root._bump()
        }
    }

    Instantiator {
        model: root._wifiDevice ? root._wifiDevice.networks : null
        delegate: QtObject {
            id: netWatch
            required property var modelData
            readonly property real strength: modelData ? modelData.signalStrength : 0
            readonly property bool connected: modelData ? modelData.connected : false
            readonly property bool known:     modelData ? modelData.known : false
            readonly property int  netState:  modelData ? modelData.state : 0
            onStrengthChanged:  root._bump()
            onConnectedChanged: root._bump()
            onKnownChanged:     root._bump()
            onNetStateChanged:  root._bump()

            property Connections _fail: Connections {
                target: netWatch.modelData
                function onConnectionFailed(reason) {
                    const msg = root._failureMessage(reason);
                    console.warn("[NetworkService] connection failed:", msg);
                    root.lastError = msg;
                    root.actionFinished(false, msg);
                }
            }
        }
    }

    // Wired devices carry a single Network rather than a scanned list; watch
    // it separately so an ethernet cable event updates the derived arrays.
    Instantiator {
        model: Networking.devices
        delegate: QtObject {
            required property var modelData
            readonly property bool link: (modelData && modelData.type === DeviceType.Wired)
                ? modelData.hasLink : false
            onLinkChanged: root._bump()
        }
    }

    // Only used for a hidden SSID with no saved profile; see connectWifi().
    Process {
        id: hiddenConnectProc
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim();
                if (msg.length > 0) {
                    console.warn("[NetworkService] hidden connect:", msg);
                    root.lastError = msg;
                    root.actionFinished(false, msg);
                } else {
                    root.lastError = "";
                    root.actionFinished(true, "");
                }
            }
        }
    }

    // The scanner is off by default, and without it `networks` holds a
    // single entry instead of the visible APs.
    onWifiEnabledChanged: {
        root._syncScanner();
        root._bump();
    }
    function _syncScanner() {
        const dev = root._wifiDevice;
        if (dev && Networking.wifiEnabled && !dev.scannerEnabled) dev.scannerEnabled = true;
    }

    Component.onCompleted: {
        root._syncScanner();
        root._recompute();
    }
}
