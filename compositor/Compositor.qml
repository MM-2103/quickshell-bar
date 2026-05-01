// Compositor.qml
// Cross-compositor abstraction. Detects the running Wayland compositor
// at startup, instantiates the matching `Backend*.qml` adapter, and
// re-exports a uniform surface that the rest of the shell consumes.
//
// Public surface (read by Workspaces, shell.qml, PowerMenuPopup, etc.):
//
//   workspaces         : array of { id, idx, output, is_focused, is_active, name? }
//   focusedOutput      : string  (name of currently-focused monitor)
//   currentLayout      : string  (current keyboard layout, e.g. "English (US)";
//                                empty on backends that can't surface it)
//   windowFocused(id)  : signal  (emitted when the user focuses an app —
//                                consumers use it to dismiss popups)
//   dispatchFocusWorkspace(idx) : function (click-to-focus a chip)
//   dispatchLogout()            : function (power menu's Logout button)
//
// Detection priority, first match wins:
//   1. $QS_COMPOSITOR override     (niri / hyprland / sway / i3 / stub)
//   2. $HYPRLAND_INSTANCE_SIGNATURE → hyprland
//   3. $SWAYSOCK                    → sway
//   4. $NIRI_SOCKET                 → niri
//   5. $XDG_CURRENT_DESKTOP fuzzy match
//   6. fallback                     → stub (empty workspaces; everything
//                                    else in the shell still works)

pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // ---- Detection ----

    readonly property string detectedKind: {
        const env = (k) => Quickshell.env(k) || "";
        const override = env("QS_COMPOSITOR").toLowerCase();
        const valid = ["niri", "hyprland", "sway", "i3", "stub"];
        if (valid.indexOf(override) >= 0) return override;

        if (env("HYPRLAND_INSTANCE_SIGNATURE")) return "hyprland";
        if (env("SWAYSOCK"))                   return "sway";
        if (env("NIRI_SOCKET"))                return "niri";

        const xdg = env("XDG_CURRENT_DESKTOP").toLowerCase();
        if (xdg.indexOf("hyprland") >= 0) return "hyprland";
        if (xdg.indexOf("sway") >= 0)     return "sway";
        if (xdg.indexOf("niri") >= 0)     return "niri";
        if (xdg.indexOf("i3") >= 0)       return "i3";

        return "stub";
    }

    Component.onCompleted: {
        console.log("[Compositor] detected backend:", detectedKind);
    }

    // ---- Backend instantiation ----
    //
    // Loader picks exactly one backend at startup. We use Component objects
    // (rather than direct properties) so unused backend QML files don't get
    // initialized — this saves startup work and avoids spurious imports
    // failing on systems missing the relevant Quickshell.* sub-module.

    Loader {
        id: backendLoader
        active: true
        sourceComponent: {
            switch (root.detectedKind) {
                case "niri":     return niriComp;
                case "hyprland": return hyprComp;
                case "sway":
                case "i3":       return swayComp;
                default:         return stubComp;
            }
        }
    }

    Component { id: niriComp;  BackendNiri     { } }
    Component { id: hyprComp;  BackendHyprland { } }
    Component { id: swayComp;  BackendSway     { } }
    Component { id: stubComp;  BackendStub     { } }

    readonly property var backend: backendLoader.item

    // ---- Public surface ----

    readonly property var workspaces:    backend ? backend.workspaces    : []
    readonly property string focusedOutput: backend ? backend.focusedOutput : ""
    readonly property string currentLayout: backend ? backend.currentLayout : ""

    signal windowFocused(var id)

    Connections {
        target: root.backend
        enabled: root.backend !== null
        function onWindowFocused(id) { root.windowFocused(id); }
    }

    function dispatchFocusWorkspace(idx) {
        if (backend) backend.dispatchFocusWorkspace(idx);
    }

    function dispatchLogout() {
        if (backend) backend.dispatchLogout();
    }
}
