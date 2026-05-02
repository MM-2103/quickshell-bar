// shell.qml
// Quickshell entry point. Spawns one Bar per monitor, a notification stack
// pinned per spawn-screen, an OSD that shows on whichever monitor currently
// has focus, and a clipboard popup triggered via IPC from a compositor
// keybind. Compositor-specific state (focused monitor, workspaces, layout)
// goes through the `Compositor` singleton in qs.compositor.

import QtQuick
import Quickshell
import Quickshell.Io        // for IpcHandler
import qs.compositor        // for Compositor singleton (auto-detects niri/Hyprland/Sway)
import qs.notifications     // for NotificationService + NotificationCard
import qs.osd               // for Osd panel + OsdService singleton
import qs.clipboard         // for ClipboardPopup + ClipboardService singleton
import qs.launcher          // for Launcher + LauncherService singleton
import qs.lock              // for Lock + LockService singleton
import qs.wallpaper         // for WallpaperLayer + WallpaperPickerPopup + WallpaperService

ShellRoot {
    id: root

    // Tell NotificationService which monitor to anchor new notifications to.
    // We keep this updated as focus moves; the service stamps each incoming
    // notification with the value of currentScreen at that moment, so once
    // it spawns it stays put regardless of later focus changes.
    //
    // Also keep OsdService.layoutName in sync with the compositor's
    // currentLayout so the layout OSD has something to render.
    Component.onCompleted: {
        NotificationService.currentScreen = Qt.binding(() => Compositor.focusedOutput);
        OsdService.layoutName            = Qt.binding(() => Compositor.currentLayout);
    }

    // Trigger a layout OSD whenever the compositor reports a new layout
    // selection. OsdService.show() ignores calls during the initialization
    // grace period, so the very first event (delivered at startup) doesn't
    // flash an OSD.
    //
    // Also dismiss any open popup when the user focuses an app window —
    // each compositor backend filters its windowFocused signal so layer-
    // shell surfaces of OUR shell (e.g. ClipboardPopup with OnDemand
    // keyboard focus) don't self-dismiss.
    Connections {
        target: Compositor
        function onCurrentLayoutChanged() {
            OsdService.show("layout");
        }
        function onWindowFocused(id) {
            PopupController.closeAll();
        }
    }

    // Wallpaper — one Background-layer surface per monitor. Declared FIRST
    // so it sits at the bottom of the layer-shell Z order. WlrLayer.Background
    // already guarantees this (below Bar's Top), but declaring it first keeps
    // the visual stack obvious when reading the file.
    Variants {
        model: Quickshell.screens

        WallpaperLayer { }
    }

    // Bar — one per monitor.
    Variants {
        model: Quickshell.screens

        Bar { }
    }

    // Notification stack — one PanelWindow per monitor, ALWAYS visible.
    // Each panel filters to notifications that spawned on its own screen,
    // so notifications stay pinned to whichever monitor was focused at the
    // moment they arrived (no jank when the user moves focus elsewhere).
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: notifPanel
            required property var modelData
            screen: modelData

            anchors {
                top: true
                right: true
            }
            // Push the stack below the bar (Theme.barHeight + small gap).
            margins {
                top: Theme.barHeight + 4
                right: 8
            }

            implicitWidth: 376
            implicitHeight: notifColumn.implicitHeight + 8

            color: "transparent"
            // Don't reserve screen space for this panel; it should float
            // above content rather than push it.
            exclusionMode: ExclusionMode.Ignore

            Column {
                id: notifColumn
                anchors {
                    top: parent.top
                    right: parent.right
                    margins: 4
                }
                spacing: 8

                Repeater {
                    // Show only notifications that:
                    //   1) are currently in the popup stack (popupIds), AND
                    //   2) were spawned on THIS panel's screen.
                    model: {
                        const all = NotificationService.trackedNotifications.values;
                        const ids = NotificationService.popupIds;
                        const screens = NotificationService.notificationScreens;
                        const myScreen = notifPanel.modelData
                            ? notifPanel.modelData.name : "";
                        const out = [];
                        for (let i = 0; i < all.length; i++) {
                            const n = all[i];
                            if (ids.indexOf(n.id) >= 0 && screens[n.id] === myScreen) {
                                out.push(n);
                            }
                        }
                        return out;
                    }

                    delegate: NotificationCard {
                        required property var modelData
                        notif: modelData
                        mode: "popup"
                    }
                }
            }
        }
    }

    // OSD layer — one PanelWindow per monitor; the panel renders the OSD
    // pill only on the focused monitor. Layer-shell is bottom-anchored,
    // horizontally centered, 80px from the bottom edge.
    Variants {
        model: Quickshell.screens

        Osd {
            focusedOutput: Compositor.focusedOutput
        }
    }

    // Clipboard picker — one PanelWindow per monitor, only visible on the
    // focused one. Triggered via the IPC handler below (called from a
    // compositor keybind, e.g. niri's Mod+V).
    Variants {
        model: Quickshell.screens

        ClipboardPopup {
            focusedOutput: Compositor.focusedOutput
        }
    }

    // App launcher — same architecture as the clipboard picker. Triggered
    // via the IPC handler below (called from a compositor keybind).
    Variants {
        model: Quickshell.screens

        Launcher {
            focusedOutput: Compositor.focusedOutput
        }
    }

    // Wallpaper picker — same per-monitor pattern as Launcher / Clipboard.
    // Triggered by clicking the Wallpaper bar widget (no IPC keybind, per
    // the user's preference; the widget toggles WallpaperService.popupOpen
    // directly).
    Variants {
        model: Quickshell.screens

        WallpaperPickerPopup {
            focusedOutput: Compositor.focusedOutput
        }
    }

    // Session lock. NOT inside a Variants block — WlSessionLock is itself
    // per-shell; per-screen surfaces fan out via its `surface` Component.
    // Triggered via the IPC handler below (called from a compositor keybind
    // and/or an idle daemon's lock_cmd — see examples/ for snippets).
    Lock { }

    // IPC: `qs ipc call clipboard open` toggles the popup.
    IpcHandler {
        target: "clipboard"
        function open(): void  { ClipboardService.openPopup(); }
        function close(): void { ClipboardService.closePopup(); }
        function toggle(): void { ClipboardService.togglePopup(); }
    }

    // IPC: `qs ipc call launcher open` opens the launcher.
    // `openEmoji` opens with ";" prefilled to jump straight into emoji mode.
    // `openWith <prefix>` opens with arbitrary text prefilled (general-purpose;
    // also handy for scripting `qs ipc call launcher openWith "?weather"`).
    IpcHandler {
        target: "launcher"
        function open(): void                 { LauncherService.openPopup(); }
        function close(): void                { LauncherService.closePopup(); }
        function toggle(): void               { LauncherService.togglePopup(); }
        function openEmoji(): void            { LauncherService.openPopupWithQuery(";"); }
        function openWith(prefix: string): void { LauncherService.openPopupWithQuery(prefix); }
    }

    // IPC: `qs ipc call lock open` locks the session. Idempotent (calling
    // open while already locked is a no-op).
    IpcHandler {
        target: "lock"
        function open(): void  { LockService.lock(); }
    }

    // Diagnostic IPC for the popup mutex/controller.
    //   qs ipc call popups status     -> "active: ..." or "no popup active"
    //   qs ipc call popups closeAll   -> dismiss whatever's open
    IpcHandler {
        target: "popups"
        function status(): string {
            return PopupController.activePopup
                ? ("active: " + PopupController.activePopup)
                : "no popup active";
        }
        function closeAll(): void { PopupController.closeAll(); }
    }
}
