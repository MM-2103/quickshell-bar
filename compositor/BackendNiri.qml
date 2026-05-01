// BackendNiri.qml
// Niri compositor adapter. Minimal stub — full implementation lands in
// Phase 2 of the cross-compositor port.

import QtQuick

QtObject {
    readonly property var    workspaces:    []
    readonly property string focusedOutput: ""
    readonly property string currentLayout: ""

    signal windowFocused(var id)

    function dispatchFocusWorkspace(idx) { /* TODO */ }
    function dispatchLogout()            { /* TODO */ }
}
