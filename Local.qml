pragma Singleton

// Local.qml
// User-local configuration overrides. Reads JSON from
// `$HOME/.config/quickshell-bar/config.json` and exposes a single
// `get(key, defaultValue)` method that consumers (Theme, services)
// route through to allow per-machine tweaks without touching the
// repo files. The override file is created by the user and never
// committed; if it doesn't exist, `get()` returns the default.
//
// Hot-reload: the FileView watches the config path. Edit the JSON,
// save, and most values update live in the running shell (Theme
// bindings are reactive). Long-running Timers (e.g. weather refresh
// interval) re-arm only on their next fire.
//
// JSONC comments: lines starting with `//` (after optional whitespace)
// are stripped before JSON.parse, so users can annotate their config.
// `//` *inside* values (URLs etc.) is untouched — only line-leading
// `//` patterns get stripped.
//
// Malformed JSON: `console.warn`-logged. The shell keeps running with
// whatever was last successfully parsed (or defaults if nothing has
// been). No crash.
//
// See `docs/CUSTOMIZATION.md` for the full list of overridable keys.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Raw parsed JSON object. Initially `{}` so `get()` returns its
    // default during the brief window before FileView fires `onLoaded`.
    property var data: ({})

    // Returns `data[key]` if the user overrode it, else `defaultValue`.
    // Caller supplies the default at the call site, keeping defaults
    // visible inline and minimising the refactor.
    function get(key, defaultValue) {
        if (root.data && root.data[key] !== undefined)
            return root.data[key];
        return defaultValue;
    }

    FileView {
        id: configFile
        // XDG-compliant location, outside the repo so it's portable
        // across re-clones and survives `git clean`. Users `mkdir -p`
        // the directory and create the file themselves.
        //
        // .jsonc extension (not .json) because we accept JSONC-style
        // line comments — tells editors like VS Code / nvim-cmp to load
        // the JSONC parser, which understands `//` comments natively.
        path: Quickshell.env("HOME") + "/.config/quickshell-bar/config.jsonc"
        watchChanges: true
        printErrors: false      // missing-file is normal
        onFileChanged: reload()

        onLoaded: {
            try {
                // Strip JSONC comments (line `//...` and block `/* ... */`)
                // while preserving `//` and `/*` that appear inside string
                // values. The regex matches three alternatives in order:
                //   1. A complete quoted string (with escape handling) —
                //      preserved verbatim by the replacer.
                //   2. A `//` line-comment to end-of-line.
                //   3. A `/* ... */` block-comment (non-greedy, multi-line).
                // Alternatives 2 and 3 are replaced with empty strings;
                // alternative 1 is returned as-is. Net effect: URLs like
                // "https://example.com" stay intact while
                //   "key": "value", // trailing comment
                // becomes
                //   "key": "value",
                // which JSON.parse accepts cleanly.
                const cleaned = (configFile.text() || "")
                    .replace(/"(?:\\.|[^"\\])*"|\/\/.*$|\/\*[\s\S]*?\*\//gm,
                             m => m.charAt(0) === '"' ? m : "");
                const parsed = JSON.parse(cleaned || "{}");
                root.data = parsed;
            } catch (e) {
                console.warn("[Local] config parse error:", e);
                // Keep `data` at its previous (good) value rather than
                // wiping to `{}` — a typo mid-edit shouldn't reset
                // everything to defaults until the user fixes the JSON.
            }
        }

        onLoadFailed: function(_err) {
            // No file at the expected path = no overrides; defaults stand.
            // Don't log — most users won't have a config and the warning
            // would be noise.
        }
    }

    Component.onCompleted: configFile.reload()
}
