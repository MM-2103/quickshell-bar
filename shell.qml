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
import qs.weather           // for WeatherDetailPopup + WeatherService singleton
import qs.settings          // for SettingsPopup + SettingsService singleton
import qs.themes            // for SystemTheme singleton (system-theme orchestration)
import qs.system            // for IdleService + SleepService singletons
import qs.polkit           // for PolkitDialog + PolkitService singleton (auth agent)
import qs.nightlight       // for NightLightService singleton (hyprsunset blue-light filter)

ShellRoot {
    id: root

    // Tell NotificationService which monitor to anchor new notifications to.
    // We keep this updated as focus moves; the service stamps each incoming
    // notification with the value of currentScreen at that moment, so once
    // it spawns it stays put regardless of later focus changes.
    //
    // Also keep OsdService.layoutName in sync with the compositor's
    // currentLayout so the layout OSD has something to render.
    //
    // SystemTheme.bootstrap() forces the system-theme singleton to
    // instantiate (singletons are lazy in QML — Connections inside an
    // unreferenced singleton never fire) and runs an initial gsettings
    // sync against whatever theme override is loaded from config.jsonc.
    //
    // IdleService.bootstrap() exists for the same reason: an unreferenced
    // singleton never instantiates, and an IdleService that never
    // instantiates is an IdleMonitor that never arms. SleepService likewise —
    // unbootstrapped it never takes its logind delay inhibitor, and suspend
    // silently goes back to racing the lock.
    //
    // NightLightService.bootstrap() likewise: it probes for hyprsunset,
    // adopts or starts the daemon, and re-applies the persisted filter
    // state. Without it a shell restart would leave the filter off despite
    // the config saying otherwise.
    Component.onCompleted: {
        NotificationService.currentScreen = Qt.binding(() => Compositor.focusedOutput);
        OsdService.layoutName            = Qt.binding(() => Compositor.currentLayout);
        // The lock surface refuses input while the screens are dark; see
        // LockService.inputBlocked. Wired here because this is the one file
        // that legitimately imports both modules — qs.system already depends
        // on qs.lock, so the lock module cannot look the other way itself.
        LockService.screensBlanked       = Qt.binding(() => IdleService.monitorsBlanked);
        SystemTheme.bootstrap();
        IdleService.bootstrap();
        SleepService.bootstrap();
        PolkitService.bootstrap();
        NightLightService.bootstrap();
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
                    // ScriptModel, not the bare array. A JS array handed
                    // straight to a Repeater makes it destroy and recreate
                    // EVERY delegate on each reassignment — and this array is
                    // rebuilt on every arrival, expiry and dismissal. Because
                    // NotificationCard restarts its slide-in animation in
                    // Component.onCompleted, the visible symptom was every
                    // card on screen re-animating whenever any other one
                    // appeared or disappeared.
                    //
                    // ScriptModel diffs instead, so only genuinely new cards
                    // are built. No objectProp: the values are Notification
                    // QObjects, already unique.
                    model: ScriptModel {
                        // Show only notifications that:
                        //   1) are currently in the popup stack (popupIds), AND
                        //   2) were spawned on THIS panel's screen.
                        values: {
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

    // Weather detail popup — centered Overlay layer surface showing the
    // 24-hour and 7-day forecast. Triggered by clicking the body of the
    // weather card inside the Control Center.
    Variants {
        model: Quickshell.screens

        WeatherDetailPopup {
            focusedOutput: Compositor.focusedOutput
        }
    }

    // Settings page — centered Overlay layer surface for visually
    // editing ~/.config/quickshell-bar/config.jsonc. Triggered by the
    // gear icon in the Control Center header or via IPC keybind.
    Variants {
        model: Quickshell.screens

        SettingsPopup {
            focusedOutput: Compositor.focusedOutput
        }
    }

    // Polkit authentication prompt. Appears whenever anything on the system
    // asks polkit for authorization (pkexec, systemctl, GParted, ...).
    // Driven entirely by PolkitService — no IPC, no keybind.
    Variants {
        model: Quickshell.screens

        PolkitDialog {
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

    // IPC for the idle service. `status` is the diagnostic to reach for when
    // the screen locks at the wrong time — it reports the armed timeout, both
    // stage timeouts, and whether we're currently idle.
    //
    //   qs ipc call idle status    -> "armed at 300s | lock 300s | dpms 360s | active"
    //   qs ipc call idle disable   -> stay awake (same effect as Caffeine)
    //   qs ipc call idle blank     -> blank monitors now, without waiting
    IpcHandler {
        target: "idle"
        function status(): string { return IdleService.statusText(); }
        function enable(): void   { IdleService.setEnabled(true); }
        function disable(): void  { IdleService.setEnabled(false); }
        function toggle(): void   { IdleService.toggle(); }
        function blank(): void    { IdleService.blankNow(); }
    }

    // Diagnostic IPC for suspend-time locking. Reach for this when the
    // machine came back from suspend unlocked — it reports whether the
    // logind delay inhibitor is held and whether the gdbus watcher is alive.
    //
    //   qs ipc call sleep status
    //     -> "inhibitor held | watcher alive | session /org/.../session/_33"
    //
    // Cross-check against `systemd-inhibit --list`, where our entry should
    // sit next to the compositor's own.
    IpcHandler {
        target: "sleep"
        function status(): string { return SleepService.statusText(); }
    }

    // IPC: `qs ipc call nightlight toggle` flips the blue-light filter, so
    // it can sit on a compositor keybind next to the Control Center tile.
    // `status` reports why the feature is unavailable when it is, which is
    // otherwise invisible — the tile simply doesn't render.
    // IPC: `qs ipc call mic toggle` mutes/unmutes the default source, for
    // binding to XF86AudioMicMute. Optional — the mic OSD watches Pipewire
    // directly, so an existing `wpctl set-mute` bind already triggers it.
    IpcHandler {
        target: "mic"
        function status(): string {
            if (!OsdService.source) return "no input device";
            return (OsdService.micMuted ? "muted" : "unmuted")
                + ", " + Math.round(OsdService.micRatio * 100) + "%";
        }
        function toggle(): void {
            if (OsdService.source && OsdService.source.audio)
                OsdService.source.audio.muted = !OsdService.source.audio.muted;
        }
        function mute(): void {
            if (OsdService.source && OsdService.source.audio)
                OsdService.source.audio.muted = true;
        }
        function unmute(): void {
            if (OsdService.source && OsdService.source.audio)
                OsdService.source.audio.muted = false;
        }
    }

    IpcHandler {
        target: "nightlight"
        function status(): string { return NightLightService.statusText(); }
        function on(): void       { NightLightService.setEnabled(true); }
        function off(): void      { NightLightService.setEnabled(false); }
        function toggle(): void   { NightLightService.toggle(); }
    }

    // IPC: `qs ipc call settings open` opens the Settings page. Bind to
    // a compositor keybind (Mod+, by convention) for keyboard access.
    IpcHandler {
        target: "settings"
        function open(): void   { SettingsService.openPopup(); }
        function close(): void  { SettingsService.closePopup(); }
        function toggle(): void { SettingsService.togglePopup(); }
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
