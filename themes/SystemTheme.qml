pragma Singleton

// SystemTheme.qml
// Bridges the in-shell theme state to the rest of the desktop. When
// ThemePresets.currentTheme changes (any theme card click, the CC
// light/dark toggle, or a user-theme apply), this singleton runs
// gsettings to update the XDG portal's color-scheme + the gtk-theme,
// so apps outside the shell follow the same dark/light preference.
//
// Apps that respect the result (via xdg-desktop-portal):
//   - GTK4 / libadwaita apps              via color-scheme
//   - GTK3 apps (Nautilus 3.x, Inkscape)  via gtk-theme
//   - Qt6 apps                            via color-scheme on the portal
//   - Electron 14+ (Discord, VS Code, …)  via color-scheme
//   - Firefox 119+, Chromium-based        via color-scheme
//
// Apps that DON'T follow (deliberately out of scope):
//   - Qt apps via QT_QPA_PLATFORMTHEME=kde (read kdeglobals, not gsettings)
//   - Apps with custom themes (Spotify userstyles, Discord stylesheets)
//   - Apps the user has explicitly overridden via env var or per-app config
//
// Configurable keys (all live in ~/.config/quickshell-bar/config.jsonc):
//   systemThemeSync (bool, default true)  — master switch; false = no-op
//   gtkThemeDark    (string, "Adwaita-dark") — gtk-theme set on dark applies
//   gtkThemeLight   (string, "Adwaita")      — gtk-theme set on light applies
//
// Hot-reload safety: NEW singleton (gotcha #62), requires daemon restart
// the first time this file lands. Subsequent edits hot-reload normally.
//
// IMPORTANT: pragma Singleton must be line 1 (gotcha #45). Header
// comments must NOT contain curly braces — qmlscanner's brace tracker
// would silently un-singleton the file.

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.themes

Singleton {
    id: root

    // ---- State ----
    //
    // Cache the (scheme, gtkTheme) pair last sent to gsettings so we can
    // bail out on duplicate Connections fires — currentTheme can re-
    // evaluate even when the resolved system state would be identical
    // (e.g. when the user toggles between two dark themes, scheme stays
    // "prefer-dark"). Skipping the redundant gsettings spawn avoids both
    // process churn and any perceptible UI lag during rapid theme browsing.
    property string _lastScheme: ""
    property string _lastGtkTheme: ""

    // True while the gsettings process is running. Useful for diagnostic
    // IPC if we ever add one; otherwise harmless.
    property bool applying: false

    // ---- Public API ----
    //
    // bootstrap() forces this singleton to instantiate (singletons are
    // lazy in QML — Connections inside an unreferenced singleton never
    // fire). Called from shell.qml's Component.onCompleted so the
    // Connections handler below is alive before the first theme change
    // event. Also runs an initial sync so any pre-existing override in
    // ~/.config/quickshell-bar/config.jsonc gets pushed to gsettings on
    // shell startup.
    function bootstrap() {
        // Force a Connections wakeup by reading any property; calling
        // _apply() also fires the initial sync.
        root._apply();
    }

    // ---- Watch ThemePresets ----
    //
    // currentTheme is reactive on Local.data, so any theme apply (whether
    // via the Theme tab or via the CC light/dark toggle) ends with this
    // signal firing.
    Connections {
        target: ThemePresets
        function onCurrentThemeChanged() { root._apply(); }
    }

    // ---- Application logic ----

    function _apply() {
        // Master switch — user can disable system-theme orchestration
        // entirely via `"systemThemeSync": false` in config.jsonc.
        if (!Local.get("systemThemeSync", true)) return;

        const t = ThemePresets.currentTheme;
        // No matched theme (Custom state) → leave system theme alone.
        // Manual ColorRow tweaks shouldn't shove apps in/out of dark mode
        // mid-edit; only an explicit theme apply (which produces a non-
        // null currentTheme) should sync the system.
        if (!t || !t.kind) return;

        const scheme = t.kind === "light" ? "prefer-light" : "prefer-dark";
        const gtkTheme = t.kind === "light"
            ? Local.get("gtkThemeLight", "Adwaita")
            : Local.get("gtkThemeDark", "Adwaita-dark");

        // Skip duplicate calls — see _lastScheme docstring above.
        if (scheme === root._lastScheme && gtkTheme === root._lastGtkTheme) {
            return;
        }
        root._lastScheme = scheme;
        root._lastGtkTheme = gtkTheme;

        // Two gsettings calls chained with `&&` so both settle as one
        // unit; if the first fails (e.g. dconf daemon hiccup) the second
        // is skipped and the next theme change retries. Running them in
        // a single sh process avoids the overhead of two separate
        // QML Process objects and keeps stderr aggregated.
        //
        // Single-quote the values so spaces in theme names (rare but
        // possible — "Adwaita Dark" vs "Adwaita-dark") survive the
        // shell pass-through. Theme names that include single quotes
        // would break this; gsettings theme names don't, in practice.
        proc.command = ["sh", "-c",
            "gsettings set org.gnome.desktop.interface color-scheme '"
                + scheme + "' && "
            + "gsettings set org.gnome.desktop.interface gtk-theme '"
                + gtkTheme + "'"];
        root.applying = true;
        proc.running = false;
        proc.running = true;
    }

    // ---- Process ----

    Process {
        id: proc
        running: false

        // gsettings stderr surfaces "No such schema" or "Failed to commit"
        // type errors. Don't spam logs in normal operation; only warn
        // when something actually went wrong.
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line && line.length > 0) {
                    console.warn("[SystemTheme]", line.trim());
                }
            }
        }

        onRunningChanged: {
            if (!running) root.applying = false;
        }
    }
}
