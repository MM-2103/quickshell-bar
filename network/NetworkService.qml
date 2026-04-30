// NetworkService.qml
// Singleton wrapping `nmcli` for state queries + actions.
// Refreshes are triggered by `nmcli monitor` events plus an initial scan.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    // ---- Reactive state ----
    property bool wifiEnabled: false
    property string globalState: "unknown"     // connected/disconnected/...
    property var activeConnections: []          // { name, type, device, state }
    property var wirelessNetworks: []           // { ssid, security, signal, inUse, bssid }
    property var savedConnections: []           // { name, uuid, type } — type=802-11-wireless or 802-3-ethernet
    property var devices: []                    // { device, type, state, connection }
    property string lastError: ""

    // Last action result so the UI can react / clear forms.
    signal actionFinished(bool ok, string message)

    // ---- Convenience getters ----
    readonly property var primaryActive: {
        // pick the most "interesting" active connection (wifi > ethernet > vpn)
        const a = activeConnections;
        let wifi = null, eth = null, vpn = null, other = null;
        for (let i = 0; i < a.length; i++) {
            const c = a[i];
            if (c.type === "802-11-wireless") wifi = c;
            else if (c.type === "802-3-ethernet") eth = c;
            else if (c.type === "vpn") vpn = c;
            else if (c.device !== "lo" && !other) other = c;
        }
        return wifi || eth || vpn || other || null;
    }

    readonly property string currentSsid: {
        for (let i = 0; i < activeConnections.length; i++) {
            if (activeConnections[i].type === "802-11-wireless") {
                return activeConnections[i].name;
            }
        }
        return "";
    }

    readonly property bool wiredConnected: {
        for (let i = 0; i < activeConnections.length; i++) {
            if (activeConnections[i].type === "802-3-ethernet"
                && activeConnections[i].state === "activated") return true;
        }
        return false;
    }

    readonly property bool wifiConnected: currentSsid !== ""

    // Ethernet helpers ----------------------------------------------------
    // Devices of type ethernet, with cable state derived from device state:
    //   "connected"      => cable plugged + connection active
    //   "disconnected"   => cable plugged, no active connection
    //   "unavailable"    => cable unplugged
    readonly property var ethernetDevices: {
        const out = [];
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === "ethernet") out.push(devices[i]);
        }
        return out;
    }

    // Saved ethernet profiles, joined with whether they're currently active
    // and which device they're on.
    readonly property var ethernetConnections: {
        const out = [];
        const saved = savedConnections;
        for (let i = 0; i < saved.length; i++) {
            if (saved[i].type !== "802-3-ethernet") continue;
            // Find active state
            let active = null;
            for (let j = 0; j < activeConnections.length; j++) {
                if (activeConnections[j].name === saved[i].name
                    && activeConnections[j].type === "802-3-ethernet") {
                    active = activeConnections[j];
                    break;
                }
            }
            out.push({
                name: saved[i].name,
                uuid: saved[i].uuid,
                active: active !== null,
                device: active ? active.device : "",
                state: active ? active.state : "deactivated"
            });
        }
        return out;
    }

    readonly property bool hasEthernetHardware: ethernetDevices.length > 0

    // ---- Parsing helpers ----
    function _parseTerse(line) {
        // nmcli -t escapes ":" and "\\" with backslash. Split by unescaped ":".
        const out = [];
        let cur = "";
        let esc = false;
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (esc) { cur += c; esc = false; continue; }
            if (c === "\\") { esc = true; continue; }
            if (c === ":") { out.push(cur); cur = ""; continue; }
            cur += c;
        }
        out.push(cur);
        return out;
    }

    // ---- Actions ----
    function refreshAll() {
        generalProc.running = true;
        activeProc.running = true;
        savedProc.running = true;
        wifiListProc.running = true;
        deviceProc.running = true;
    }

    function rescan() {
        rescanProc.running = true;
    }

    function setWifiEnabled(on) {
        wifiToggleProc.command = ["nmcli", "radio", "wifi", on ? "on" : "off"];
        wifiToggleProc.running = true;
    }

    // Connect to a saved/known network (no password prompt).
    function connectByName(name) {
        actionProc.command = ["nmcli", "connection", "up", name];
        actionProc.running = true;
    }

    // Connect to a wifi network by SSID with optional password / hidden flag.
    function connectWifi(ssid, password, hidden) {
        const cmd = ["nmcli", "device", "wifi", "connect", ssid];
        if (password && password.length > 0) {
            cmd.push("password", password);
        }
        if (hidden) cmd.push("hidden", "yes");
        actionProc.command = cmd;
        actionProc.running = true;
    }

    // Disconnect an active connection.
    function disconnectByName(name) {
        actionProc.command = ["nmcli", "connection", "down", name];
        actionProc.running = true;
    }

    // Forget / delete a saved connection profile.
    function forgetByName(name) {
        actionProc.command = ["nmcli", "connection", "delete", name];
        actionProc.running = true;
    }

    // Device-level activate. Better than `connection up` for ethernet because
    // it auto-creates an ad-hoc profile if none exists, and doesn't depend on
    // a stable profile name. Used for ethernet rows.
    function connectDevice(device) {
        actionProc.command = ["nmcli", "device", "connect", device];
        actionProc.running = true;
    }

    // Device-level deactivate. Doesn't auto-delete the underlying profile,
    // unlike `connection down` for ad-hoc Wired-connection-N profiles.
    function disconnectDevice(device) {
        actionProc.command = ["nmcli", "device", "disconnect", device];
        actionProc.running = true;
    }

    // ---- Background processes ----

    // Long-running event monitor — triggers refresh on any state change.
    Process {
        id: monitorProc
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (!line) return;
                root.refreshAll();
            }
        }
        onRunningChanged: {
            if (!running) {
                console.warn("[NetworkService] nmcli monitor exited, restarting");
                running = true;
            }
        }
    }

    // General state: STATE:WIFI:WIFI-HW
    Process {
        id: generalProc
        command: ["nmcli", "-t", "-f", "STATE,WIFI,WIFI-HW", "general"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim().split("\n")[0] || "";
                const f = root._parseTerse(line);
                root.globalState = f[0] || "unknown";
                root.wifiEnabled = (f[1] || "") === "enabled";
            }
        }
    }

    // Active connections: NAME:TYPE:DEVICE:STATE
    Process {
        id: activeProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE,STATE", "connection", "show", "--active"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue;
                    const f = root._parseTerse(lines[i]);
                    list.push({
                        name:   f[0] || "",
                        type:   f[1] || "",
                        device: f[2] || "",
                        state:  f[3] || ""
                    });
                }
                root.activeConnections = list;
            }
        }
    }

    // Saved connections: NAME:UUID:TYPE
    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue;
                    const f = root._parseTerse(lines[i]);
                    list.push({
                        name: f[0] || "",
                        uuid: f[1] || "",
                        type: f[2] || ""
                    });
                }
                root.savedConnections = list;
            }
        }
    }

    // Devices: DEVICE:TYPE:STATE:CONNECTION
    Process {
        id: deviceProc
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue;
                    const f = root._parseTerse(lines[i]);
                    list.push({
                        device:     f[0] || "",
                        type:       f[1] || "",
                        state:      f[2] || "",
                        connection: f[3] || ""
                    });
                }
                root.devices = list;
            }
        }
    }

    // Wifi list: IN-USE:BSSID:SSID:SECURITY:SIGNAL
    Process {
        id: wifiListProc
        command: ["nmcli", "-t", "-f", "IN-USE,BSSID,SSID,SECURITY,SIGNAL", "device", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                const lines = text.trim().split("\n");
                const seen = {};
                for (let i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue;
                    const f = root._parseTerse(lines[i]);
                    const ssid = f[2] || "";
                    if (!ssid) continue;            // skip hidden APs without SSID
                    // Deduplicate by SSID, keeping the strongest signal.
                    const sig = parseInt(f[4] || "0");
                    if (seen[ssid] !== undefined) {
                        if (list[seen[ssid]].signal >= sig) continue;
                        // replace
                    }
                    const entry = {
                        inUse:    (f[0] || "") === "*",
                        bssid:    f[1] || "",
                        ssid:     ssid,
                        security: f[3] || "",
                        signal:   sig
                    };
                    if (seen[ssid] !== undefined) {
                        list[seen[ssid]] = entry;
                    } else {
                        seen[ssid] = list.length;
                        list.push(entry);
                    }
                }
                // Sort: in-use first, then by signal desc.
                list.sort((a, b) => {
                    if (a.inUse !== b.inUse) return a.inUse ? -1 : 1;
                    return b.signal - a.signal;
                });
                root.wirelessNetworks = list;
            }
        }
    }

    // Force a fresh scan (asynchronous).
    Process {
        id: rescanProc
        command: ["nmcli", "device", "wifi", "rescan"]
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.length > 0) {
                    console.warn("[NetworkService] rescan:", text.trim());
                }
            }
        }
    }

    // Wifi enable/disable. Command set dynamically by setWifiEnabled().
    Process {
        id: wifiToggleProc
        command: ["nmcli", "radio", "wifi", "on"]
        onRunningChanged: { if (!running) root.refreshAll(); }
    }

    // Generic action runner (connect/disconnect/forget). Captures stderr for errors.
    Process {
        id: actionProc
        command: ["nmcli", "general"]    // placeholder, overwritten before each call
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim();
                if (msg.length > 0) {
                    console.warn("[NetworkService] action error:", msg);
                    root.lastError = msg;
                    root.actionFinished(false, msg);
                } else {
                    root.lastError = "";
                    root.actionFinished(true, "");
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                Qt.callLater(() => root.refreshAll());
            }
        }
    }

    Component.onCompleted: {
        // Initial population.
        refreshAll();
        rescan();
    }
}
