// BackendStub.qml
// Fallback backend for compositors we don't have an adapter for (river,
// Wayfire, Cosmic, …). Every property reports an empty / no-op value —
// the shell still loads, every compositor-agnostic widget (audio, network,
// bluetooth, notifications, tray, media, clock, …) still works. Only the
// workspaces module appears empty.

import QtQuick

QtObject {
    readonly property var    workspaces:    []
    readonly property string focusedOutput: ""
    readonly property string currentLayout: ""

    signal windowFocused(var id)

    function dispatchFocusWorkspace(idx) { /* no-op */ }
    function dispatchLogout()            { /* no-op */ }
}
