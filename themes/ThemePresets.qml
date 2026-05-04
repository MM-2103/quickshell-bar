pragma Singleton

// ThemePresets.qml
// Catalogue of pre-made colour themes plus the apply / current-theme
// machinery used by the Settings page Theme tab.
//
// A "theme" is a palette of the 14 user-overridable colour keys
// (bg, surface, surfaceHi, border, text, textDim, textMuted, accent,
// accentText, error, errorBright, pipIdle, pipActive, pipFocused).
// applyTheme writes them all via Local.set; the 500 ms write debounce
// in Local.qml coalesces 14 sets into a single config.jsonc flush.
//
// currentTheme reactively identifies which theme (if any) the user's
// current Local state matches, so the Theme tab can highlight the
// active card. When any of the 14 keys diverges from every catalogued
// palette, currentTheme is null and the UI shows "Custom".
//
// User-defined themes (this file ships built-ins only; user themes
// loaded from ~/.config/quickshell-bar/themes are added in a later
// commit) get concatenated onto builtIn via the `all` property —
// consumers iterate `all`, never `builtIn` directly.
//
// IMPORTANT: pragma Singleton must be line 1 (gotcha #45). Header
// comments must NOT contain curly braces — qmlscanner's brace tracker
// treats them as object boundaries and silently un-singletons the file.
// Hot-reload also doesn't refresh qmldir cache for new singletons
// (gotcha #62), so first install requires a daemon restart.

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    // ---- Palette schema ----
    //
    // Every theme's palette must populate these 14 keys. _paletteMatches
    // and applyTheme iterate the list to stay in sync with this contract.
    // Adding a new overridable colour means appending here AND adding a
    // value to every theme palette below; otherwise that theme would
    // leave the new key at its Theme.qml default while changing the
    // others, producing a half-applied look.
    readonly property var paletteKeys: [
        "bg", "surface", "surfaceHi", "border",
        "text", "textDim", "textMuted",
        "accent", "accentText",
        "error", "errorBright",
        "pipIdle", "pipActive", "pipFocused"
    ]

    // ---- Built-in catalogue ----
    //
    // Visual order in the Theme tab is "all darks first, then all lights"
    // — preserves the existing dark-theme ordering (Default first, then
    // warm-to-cool grouping) and stacks the light variants beneath in
    // the same order. Each dark theme's lightId field cross-references
    // its sibling, so toggleLightDark can flip between paired themes.
    //
    // Each entry has FIVE fields:
    //   id        — stable slug, used for user-theme references and the
    //               currentTheme/_paletteMatches identity check
    //   label     — display text on the card
    //   kind      — "dark" or "light"; used by the toggle tile to pick
    //               its icon (sun ↔ moon)
    //   siblingId — id of the paired light/dark variant, or null when
    //               no sibling exists (currently every built-in has a
    //               sibling; nullability is for user themes)
    //   palette   — record of the 14 colour keys
    //
    // Sources:
    //   - Default            : Theme.qml's hardcoded defaults
    //   - Default Light      : synthesised inversion (no upstream)
    //   - Gruvbox            : morhetz/gruvbox dark0 / light0 medium
    //   - Catppuccin         : catppuccin/palette flavors.json (Mocha + Latte)
    //   - Tokyo Night        : folke/tokyonight.nvim (Storm + Day)
    //   - Nord               : Arctic Ice Studio nord0..nord15 (dark
    //                          canonical; light is community-derived
    //                          inversion using Snow Storm tones)
    //   - Rosé Pine          : rose-pine.io (Main + Dawn)
    //   - Dracula            : draculatheme.com (dark canonical; light
    //                          is community-derived; both synthesise
    //                          surface/border mid-tones)
    //   - Everforest         : sainnhe/everforest medium variant (dark + light)
    //   - Kanagawa           : rebelot/kanagawa.nvim (Wave + Lotus)
    //   - Solarized          : Ethan Schoonover's canonical specification
    //                          (light surfaceHi/border synthesised between
    //                          base2 and base1)
    readonly property var builtIn: [
        // ---- Dark themes ----
        {
            id: "default",
            label: "Default",
            kind: "dark",
            siblingId: "default-light",
            palette: {
                bg:          "#16181c",
                surface:     "#1e1e22",
                surfaceHi:   "#26262a",
                border:      "#2a2a2e",
                text:        "#fcfcfc",
                textDim:     "#909090",
                textMuted:   "#5e5e5e",
                accent:      "#ffffff",
                accentText:  "#16181c",
                error:       "#ff5050",
                errorBright: "#ff7070",
                pipIdle:     "#2a2a2e",
                pipActive:   "#3a3a3e",
                pipFocused:  "#ffffff"
            }
        },
        {
            id: "gruvbox-dark",
            label: "Gruvbox Dark",
            kind: "dark",
            siblingId: "gruvbox-light",
            palette: {
                bg:          "#282828",
                surface:     "#32302f",
                surfaceHi:   "#3c3836",
                border:      "#504945",
                text:        "#ebdbb2",
                textDim:     "#a89984",
                textMuted:   "#7c6f64",
                accent:      "#fabd2f",
                accentText:  "#282828",
                error:       "#cc241d",
                errorBright: "#fb4934",
                pipIdle:     "#504945",
                pipActive:   "#665c54",
                pipFocused:  "#fabd2f"
            }
        },
        {
            id: "catppuccin-mocha",
            label: "Catppuccin Mocha",
            kind: "dark",
            siblingId: "catppuccin-latte",
            palette: {
                bg:          "#1e1e2e",
                surface:     "#313244",
                surfaceHi:   "#45475a",
                border:      "#585b70",
                text:        "#cdd6f4",
                textDim:     "#a6adc8",
                textMuted:   "#7f849c",
                accent:      "#cba6f7",
                accentText:  "#1e1e2e",
                error:       "#f38ba8",
                errorBright: "#eba0ac",
                pipIdle:     "#45475a",
                pipActive:   "#585b70",
                pipFocused:  "#cba6f7"
            }
        },
        {
            id: "tokyo-night-storm",
            label: "Tokyo Night Storm",
            kind: "dark",
            siblingId: "tokyo-night-day",
            palette: {
                bg:          "#24283b",
                surface:     "#292e42",
                surfaceHi:   "#3b4261",
                border:      "#414868",
                text:        "#c0caf5",
                textDim:     "#a9b1d6",
                textMuted:   "#565f89",
                accent:      "#7aa2f7",
                accentText:  "#24283b",
                error:       "#f7768e",
                errorBright: "#ff7a93",
                pipIdle:     "#3b4261",
                pipActive:   "#545c7e",
                pipFocused:  "#7aa2f7"
            }
        },
        {
            id: "nord",
            label: "Nord",
            kind: "dark",
            siblingId: "nord-light",
            palette: {
                bg:          "#2e3440",
                surface:     "#3b4252",
                surfaceHi:   "#434c5e",
                border:      "#4c566a",
                text:        "#eceff4",
                textDim:     "#d8dee9",
                textMuted:   "#4c566a",
                accent:      "#88c0d0",
                accentText:  "#2e3440",
                error:       "#bf616a",
                errorBright: "#d08770",
                pipIdle:     "#3b4252",
                pipActive:   "#4c566a",
                pipFocused:  "#88c0d0"
            }
        },
        {
            id: "rose-pine",
            label: "Rosé Pine",
            kind: "dark",
            siblingId: "rose-pine-dawn",
            palette: {
                bg:          "#191724",
                surface:     "#1f1d2e",
                surfaceHi:   "#26233a",
                border:      "#403d52",
                text:        "#e0def4",
                textDim:     "#908caa",
                textMuted:   "#6e6a86",
                accent:      "#c4a7e7",
                accentText:  "#191724",
                error:       "#eb6f92",
                errorBright: "#f4849b",
                pipIdle:     "#26233a",
                pipActive:   "#403d52",
                pipFocused:  "#c4a7e7"
            }
        },
        {
            id: "dracula",
            label: "Dracula",
            kind: "dark",
            siblingId: "dracula-light",
            palette: {
                bg:          "#282a36",
                surface:     "#343746",
                surfaceHi:   "#44475a",
                border:      "#525469",
                text:        "#f8f8f2",
                textDim:     "#b4b6c8",
                textMuted:   "#6272a4",
                accent:      "#bd93f9",
                accentText:  "#282a36",
                error:       "#ff5555",
                errorBright: "#ff79c6",
                pipIdle:     "#44475a",
                pipActive:   "#6272a4",
                pipFocused:  "#bd93f9"
            }
        },
        {
            id: "everforest-dark",
            label: "Everforest Dark",
            kind: "dark",
            siblingId: "everforest-light",
            palette: {
                bg:          "#2e383c",
                surface:     "#374145",
                surfaceHi:   "#414b50",
                border:      "#495156",
                text:        "#d3c6aa",
                textDim:     "#9da9a0",
                textMuted:   "#7a8478",
                accent:      "#a7c080",
                accentText:  "#2e383c",
                error:       "#e67e80",
                errorBright: "#e69875",
                pipIdle:     "#414b50",
                pipActive:   "#495156",
                pipFocused:  "#a7c080"
            }
        },
        {
            id: "kanagawa",
            label: "Kanagawa Wave",
            kind: "dark",
            siblingId: "kanagawa-lotus",
            palette: {
                bg:          "#1f1f28",
                surface:     "#2a2a37",
                surfaceHi:   "#363646",
                border:      "#54546d",
                text:        "#dcd7ba",
                textDim:     "#c8c093",
                textMuted:   "#727169",
                accent:      "#7e9cd8",
                accentText:  "#1f1f28",
                error:       "#c34043",
                errorBright: "#e82424",
                pipIdle:     "#2a2a37",
                pipActive:   "#363646",
                pipFocused:  "#7e9cd8"
            }
        },
        {
            id: "solarized-dark",
            label: "Solarized Dark",
            kind: "dark",
            siblingId: "solarized-light",
            palette: {
                bg:          "#002b36",
                surface:     "#073642",
                surfaceHi:   "#08404d",
                border:      "#0d4a55",
                text:        "#fdf6e3",
                textDim:     "#93a1a1",
                textMuted:   "#586e75",
                accent:      "#268bd2",
                accentText:  "#fdf6e3",
                error:       "#dc322f",
                errorBright: "#cb4b16",
                pipIdle:     "#073642",
                pipActive:   "#586e75",
                pipFocused:  "#268bd2"
            }
        },

        // ---- Light themes ----
        {
            id: "default-light",
            label: "Default Light",
            kind: "light",
            siblingId: "default",
            palette: {
                bg:          "#fafafa",
                surface:     "#f0f0f0",
                surfaceHi:   "#e0e0e0",
                border:      "#d0d0d0",
                text:        "#16181c",
                textDim:     "#6e6e6e",
                textMuted:   "#a0a0a0",
                accent:      "#16181c",
                accentText:  "#fafafa",
                error:       "#d32f2f",
                errorBright: "#b71c1c",
                pipIdle:     "#d0d0d0",
                pipActive:   "#a0a0a0",
                pipFocused:  "#16181c"
            }
        },
        {
            id: "gruvbox-light",
            label: "Gruvbox Light",
            kind: "light",
            siblingId: "gruvbox-dark",
            palette: {
                bg:          "#fbf1c7",
                surface:     "#ebdbb2",
                surfaceHi:   "#d5c4a1",
                border:      "#bdae93",
                text:        "#282828",
                textDim:     "#504945",
                textMuted:   "#665c54",
                accent:      "#b57614",
                accentText:  "#fbf1c7",
                error:       "#cc241d",
                errorBright: "#9d0006",
                pipIdle:     "#bdae93",
                pipActive:   "#a89984",
                pipFocused:  "#b57614"
            }
        },
        {
            id: "catppuccin-latte",
            label: "Catppuccin Latte",
            kind: "light",
            siblingId: "catppuccin-mocha",
            palette: {
                bg:          "#eff1f5",
                surface:     "#e6e9ef",
                surfaceHi:   "#ccd0da",
                border:      "#bcc0cc",
                text:        "#4c4f69",
                textDim:     "#6c6f85",
                textMuted:   "#8c8fa1",
                accent:      "#8839ef",
                accentText:  "#eff1f5",
                error:       "#d20f39",
                errorBright: "#e64553",
                pipIdle:     "#ccd0da",
                pipActive:   "#bcc0cc",
                pipFocused:  "#8839ef"
            }
        },
        {
            id: "tokyo-night-day",
            label: "Tokyo Night Day",
            kind: "light",
            siblingId: "tokyo-night-storm",
            palette: {
                bg:          "#e1e2e7",
                surface:     "#d0d5e1",
                surfaceHi:   "#c4c8da",
                border:      "#a8aecb",
                text:        "#3760bf",
                textDim:     "#6172b0",
                textMuted:   "#848cb5",
                accent:      "#2e7de9",
                accentText:  "#e1e2e7",
                error:       "#f52a65",
                errorBright: "#d20065",
                pipIdle:     "#c4c8da",
                pipActive:   "#8990b3",
                pipFocused:  "#2e7de9"
            }
        },
        {
            id: "nord-light",
            label: "Nord Light",
            kind: "light",
            siblingId: "nord",
            palette: {
                bg:          "#eceff4",
                surface:     "#e5e9f0",
                surfaceHi:   "#d8dee9",
                border:      "#b9c4d4",
                text:        "#2e3440",
                textDim:     "#3b4252",
                textMuted:   "#4c566a",
                accent:      "#5e81ac",
                accentText:  "#eceff4",
                error:       "#bf616a",
                errorBright: "#d08770",
                pipIdle:     "#d8dee9",
                pipActive:   "#b9c4d4",
                pipFocused:  "#5e81ac"
            }
        },
        {
            id: "rose-pine-dawn",
            label: "Rosé Pine Dawn",
            kind: "light",
            siblingId: "rose-pine",
            palette: {
                bg:          "#faf4ed",
                surface:     "#f2e9e1",
                surfaceHi:   "#dfdad9",
                border:      "#cecacd",
                text:        "#575279",
                textDim:     "#797593",
                textMuted:   "#9893a5",
                accent:      "#907aa9",
                accentText:  "#faf4ed",
                error:       "#b4637a",
                errorBright: "#d7827e",
                pipIdle:     "#dfdad9",
                pipActive:   "#cecacd",
                pipFocused:  "#907aa9"
            }
        },
        {
            id: "dracula-light",
            label: "Dracula Light",
            kind: "light",
            siblingId: "dracula",
            palette: {
                bg:          "#f8f8f2",
                surface:     "#ebebe5",
                surfaceHi:   "#dcdcd6",
                border:      "#b8b8b2",
                text:        "#282a36",
                textDim:     "#44475a",
                textMuted:   "#6272a4",
                accent:      "#8a4ad9",
                accentText:  "#f8f8f2",
                error:       "#dc2626",
                errorBright: "#d33682",
                pipIdle:     "#dcdcd6",
                pipActive:   "#b8b8b2",
                pipFocused:  "#8a4ad9"
            }
        },
        {
            id: "everforest-light",
            label: "Everforest Light",
            kind: "light",
            siblingId: "everforest-dark",
            palette: {
                bg:          "#fdf6e3",
                surface:     "#f4f0d9",
                surfaceHi:   "#efebd4",
                border:      "#e0dcc7",
                text:        "#5c6a72",
                textDim:     "#829181",
                textMuted:   "#a6b0a0",
                accent:      "#8da101",
                accentText:  "#fdf6e3",
                error:       "#f85552",
                errorBright: "#f57d26",
                pipIdle:     "#efebd4",
                pipActive:   "#e0dcc7",
                pipFocused:  "#8da101"
            }
        },
        {
            id: "kanagawa-lotus",
            label: "Kanagawa Lotus",
            kind: "light",
            siblingId: "kanagawa",
            palette: {
                bg:          "#f2ecbc",
                surface:     "#e7dba0",
                surfaceHi:   "#dcd5ac",
                border:      "#afb1bb",
                text:        "#545464",
                textDim:     "#43443a",
                textMuted:   "#836f4a",
                accent:      "#4e8ca2",
                accentText:  "#f2ecbc",
                error:       "#c84053",
                errorBright: "#e82424",
                pipIdle:     "#dcd5ac",
                pipActive:   "#afb1bb",
                pipFocused:  "#4e8ca2"
            }
        },
        {
            id: "solarized-light",
            label: "Solarized Light",
            kind: "light",
            siblingId: "solarized-dark",
            palette: {
                bg:          "#fdf6e3",
                surface:     "#eee8d5",
                surfaceHi:   "#d7d0bd",
                border:      "#c5beac",
                text:        "#586e75",
                textDim:     "#657b83",
                textMuted:   "#93a1a1",
                accent:      "#268bd2",
                accentText:  "#fdf6e3",
                error:       "#dc322f",
                errorBright: "#cb4b16",
                pipIdle:     "#eee8d5",
                pipActive:   "#93a1a1",
                pipFocused:  "#268bd2"
            }
        }
    ]

    // ---- User-defined themes ----
    //
    // Populated from ~/.config/quickshell-bar/themes/*.jsonc on shell
    // start and on every rescan() call (the SettingsService wires the
    // latter to popup-open). Each file is a single JSONC document of
    // shape: id, label, palette as a record of the 14 colour keys.
    // Files whose JSON is malformed or which lack id/label/palette are
    // skipped silently with a console.warn — same forgiveness Local.qml
    // gives malformed config.jsonc, since theme files are user-edited.
    property var userThemes: []

    // ---- Surfaced to the UI ----
    //
    // Theme tab iterates `all` so built-ins always appear before user
    // themes. Both ThemeSection (the grid) and currentTheme matching
    // read this property.
    readonly property var all: builtIn.concat(userThemes)

    // ---- Apply ----
    //
    // Writes all 14 keys via Local.set. Each set calls flushTimer.restart()
    // inside Local; since restarts are "interval ms from now", only the
    // FINAL restart actually fires — net result is one config.jsonc flush
    // 500 ms after this loop returns. Intermediate Local.data states are
    // visible to bindings but the 14 set calls happen synchronously in a
    // single JS turn, so QML coalesces them into one render frame.
    function applyTheme(theme) {
        if (!theme || !theme.palette) return;
        const keys = root.paletteKeys;
        const pal = theme.palette;
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i];
            if (pal[k] !== undefined) {
                Local.set(k, pal[k]);
            }
        }
    }

    // ---- Selection-state matching ----
    //
    // currentTheme is the first theme in `all` whose palette matches
    // every one of the user's effective 14-key values, or null if no
    // theme matches (i.e. the user has a custom configuration).
    // Reactive on Local.data — flips to null the moment any key
    // diverges, flips back to a theme the moment the user (re-)applies
    // a matching palette.
    //
    // "Effective value" = the user's explicit override if present,
    // otherwise the Theme.qml default. By contract, the Default theme's
    // palette mirrors Theme.qml's defaults, so we resolve unset keys
    // against builtIn's "default" entry rather than passing the
    // candidate palette as the get() fallback (which would falsely
    // match every theme for keys the user hasn't overridden).
    readonly property var currentTheme: {
        // Bare reference makes this property reactive on Local.data.
        const _ = Local.data;
        const list = root.all;
        for (let i = 0; i < list.length; i++) {
            if (root._paletteMatches(list[i].palette)) return list[i];
        }
        return null;
    }

    // The Default theme's palette doubles as the Theme.qml-defaults
    // lookup for any key the user hasn't overridden. Resolved by id
    // rather than by index so reordering builtIn doesn't silently
    // break matching.
    readonly property var _defaultPalette: {
        for (let i = 0; i < root.builtIn.length; i++) {
            if (root.builtIn[i].id === "default") return root.builtIn[i].palette;
        }
        return null;
    }

    function _paletteMatches(palette) {
        const keys = root.paletteKeys;
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i];
            if (palette[k] === undefined) continue;
            const cur = root._effectiveValue(k);
            if (root._normalizeHex(cur) !== root._normalizeHex(palette[k])) {
                return false;
            }
        }
        return true;
    }

    function _effectiveValue(key) {
        if (Local.data && Local.data[key] !== undefined) {
            return Local.data[key];
        }
        return root._defaultPalette ? root._defaultPalette[key] : null;
    }

    function _normalizeHex(c) {
        // Qt's `color` type, when round-tripped through JSON.stringify
        // (e.g. by ColorPicker's writes via Local.set), serialises as
        // a record of r/g/b/a floats plus hsv/hsl mirrors. Re-derive a
        // canonical "#rrggbb" so we can compare against palette hex
        // strings on equal footing.
        if (c && typeof c === "object" && typeof c.r === "number") {
            const r = Math.round(Math.max(0, Math.min(1, c.r)) * 255);
            const g = Math.round(Math.max(0, Math.min(1, c.g)) * 255);
            const b = Math.round(Math.max(0, Math.min(1, c.b)) * 255);
            return "#" + root._byteHex(r) + root._byteHex(g) + root._byteHex(b);
        }
        const s = ("" + c).toLowerCase();
        // Qt's color toString() returns "#aarrggbb" — strip the alpha
        // byte so we compare the rgb portion against the palette's
        // canonical "#rrggbb" form.
        if (s.length === 9 && s.charAt(0) === "#") return "#" + s.substr(3);
        return s;
    }

    function _byteHex(n) {
        const h = Math.max(0, Math.min(255, n)).toString(16);
        return h.length === 1 ? "0" + h : h;
    }

    // ---- User-theme directory scan ----
    //
    // Single Process running a small shell loop that cats each
    // *.jsonc in ~/.config/quickshell-bar/themes, separated by a
    // sentinel line so the parser can split chunks back out. The
    // sentinel is unlikely to appear inside a real palette file, and
    // the parser tolerates either CRLF or LF.
    //
    // Pattern lifted from WallpaperService._scan but with file CONTENT
    // collected via StdioCollector instead of file LISTINGS streamed
    // via SplitParser — themes need their full bodies parsed as JSONC,
    // not enumerated line by line.
    //
    // We don't use FileView here because FileView is per-file and we
    // want to enumerate a directory; one Process per scan is the
    // accepted cost (cheap — under a millisecond for a handful of
    // small theme files; runs on shell start + on Settings popup open).

    readonly property string _userThemeSentinel: "###QS-THEME-SEP###"

    Process {
        id: scanProc
        running: false

        stdout: StdioCollector { id: scanCollector }

        onRunningChanged: {
            if (running) return;
            const text = scanCollector.text || "";
            root.userThemes = root._parseUserThemes(text);
        }
    }

    function rescan() {
        // Re-running an already-running Process is a no-op; flip false
        // first so the next true edge actually re-triggers the scan.
        // Cheap enough that we don't bother debouncing — even on a
        // rapid open/close/open of the Settings popup, the scan is sub-
        // millisecond and the StdioCollector swap is atomic.
        scanProc.command = ["sh", "-c", `
d="$HOME/.config/quickshell-bar/themes"
if [ -d "$d" ]; then
    for f in "$d"/*.jsonc; do
        [ -f "$f" ] && {
            cat "$f"
            printf '\\n${root._userThemeSentinel}\\n'
        }
    done
fi
`];
        scanProc.running = false;
        scanProc.running = true;
    }

    function _parseUserThemes(text) {
        const out = [];
        if (!text) return out;
        const sep = root._userThemeSentinel;
        const chunks = text.split(sep);
        for (let i = 0; i < chunks.length; i++) {
            const chunk = chunks[i].trim();
            if (!chunk) continue;
            try {
                // JSONC comment strip — string-aware regex copied from
                // Local.qml so URLs like "https://..." inside palette
                // strings stay intact while // and /* */ comments are
                // dropped before JSON.parse.
                const cleaned = chunk.replace(
                    /"(?:\\.|[^"\\])*"|\/\/.*$|\/\*[\s\S]*?\*\//gm,
                    m => m.charAt(0) === '"' ? m : ""
                );
                const parsed = JSON.parse(cleaned);
                if (!parsed
                    || typeof parsed.id !== "string"
                    || typeof parsed.label !== "string"
                    || !parsed.palette
                    || typeof parsed.palette !== "object") {
                    console.warn(
                        "[ThemePresets] skipping user theme: missing id/label/palette");
                    continue;
                }
                out.push({
                    id: parsed.id,
                    label: parsed.label,
                    palette: parsed.palette
                });
            } catch (e) {
                console.warn("[ThemePresets] user theme parse error:", e);
            }
        }
        return out;
    }

    Component.onCompleted: rescan()
}
