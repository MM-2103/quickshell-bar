pragma Singleton

// SystemTheme.qml
// Bridges the in-shell theme state to the rest of the desktop. When
// ThemePresets.currentTheme changes (any theme card click, the CC
// light/dark toggle, or a user-theme apply), this singleton runs three
// commands to push the dark/light preference outward:
//
//   1. gsettings color-scheme  — XDG portal preference, picked up by
//                                GTK4/libadwaita, Qt6 via portal,
//                                Electron 14+, Firefox 119+, Chromium
//   2. gsettings gtk-theme     — GTK3 apps that don't use libadwaita
//   3. plasma-apply-colorscheme — KDE/Qt apps using QT_QPA_PLATFORMTHEME=kde
//                                (Dolphin, Kate, Konsole, etc.) — writes
//                                kdeglobals + emits the DBus signal so
//                                running KDE apps re-theme live
//
// Step 3 is gracefully skipped if plasma-apply-colorscheme isn't on
// PATH (non-KDE installs). The shell command uses `command -v` so the
// absence is not an error.
//
// Apps that DON'T follow (deliberately out of scope):
//   - Apps with custom themes (Spotify userstyles, Discord stylesheets)
//   - Apps the user has explicitly overridden via env var or per-app config
//   - Qt5 apps with neither QPA-kde nor portal support (rare)
//
// Configurable keys (all live in ~/.config/quickshell-bar/config.jsonc):
//   systemThemeSync     (bool, default true)  — master switch; false = no-op
//   gtkThemeDark        (string, "Adwaita-dark")  — gtk-theme on dark
//   gtkThemeLight       (string, "Adwaita")       — gtk-theme on light
//   kdeColorSchemeDark  (string, "BreezeDark")    — KDE scheme on dark
//   kdeColorSchemeLight (string, "BreezeLight")   — KDE scheme on light
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
    // Cache the (scheme, gtkTheme, kdeScheme) tuple last sent so we can
    // bail out on duplicate Connections fires — currentTheme can re-
    // evaluate even when the resolved system state would be identical
    // (e.g. when the user toggles between two dark themes, scheme stays
    // "prefer-dark"). Skipping the redundant external calls avoids both
    // process churn and any perceptible UI lag during rapid theme
    // browsing.
    property string _lastScheme: ""
    property string _lastGtkTheme: ""
    property string _lastKdeScheme: ""

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
        const kdeScheme = t.kind === "light"
            ? Local.get("kdeColorSchemeLight", "BreezeLight")
            : Local.get("kdeColorSchemeDark", "BreezeDark");

        // Skip duplicate calls — see _lastScheme docstring above.
        if (scheme === root._lastScheme
            && gtkTheme === root._lastGtkTheme
            && kdeScheme === root._lastKdeScheme) {
            return;
        }
        root._lastScheme = scheme;
        root._lastGtkTheme = gtkTheme;
        root._lastKdeScheme = kdeScheme;

        // Three external calls chained in a single sh process:
        //   1. gsettings color-scheme  (portal preference)
        //   2. gsettings gtk-theme     (GTK3 apps)
        //   3. plasma-apply-colorscheme (KDE/Qt apps via kdeglobals + DBus)
        //
        // The plasma-apply-colorscheme step is gated on `command -v` so
        // non-KDE installs (where the binary doesn't exist) skip it
        // silently rather than spamming stderr. The trailing `|| true`
        // makes failures non-fatal so the chain doesn't break and the
        // next theme change still gets the gsettings calls fresh.
        //
        // Single-quote the values so spaces in theme names (rare but
        // possible — "Adwaita Dark" vs "Adwaita-dark") survive the
        // shell pass-through. Theme names that include single quotes
        // would break this; in practice they don't.
        proc.command = ["sh", "-c",
            "gsettings set org.gnome.desktop.interface color-scheme '"
                + scheme + "' && "
            + "gsettings set org.gnome.desktop.interface gtk-theme '"
                + gtkTheme + "' ; "
            + "command -v plasma-apply-colorscheme >/dev/null 2>&1 && "
            + "plasma-apply-colorscheme '" + kdeScheme + "' "
            + "|| true"];
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
