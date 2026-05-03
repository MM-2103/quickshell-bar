# Customization

Per-machine overrides without touching tracked files.

## How it works

The shell reads `~/.config/quickshell-bar/config.jsonc` (an XDG-compliant
location, **outside the repo**) at startup and on every save. Anything
listed below can be overridden by adding a key to that file. Unspecified
keys keep their defaults. The override file is created by you — it
doesn't exist by default.

> The `.jsonc` extension is intentional: we accept JSONC-style `//`
> line comments. Editors like VS Code, nvim-cmp, and Helix recognise
> the extension and use the JSONC parser, which won't flag your
> comments as syntax errors. A plain `.json` file at the same path is
> NOT loaded — the extension is part of the contract.

Hot-reload is enabled: edit the JSON, save, and most values update live
in the running shell. Theme bindings are reactive; long-running Timers
re-arm on their next fire.

JSONC-style line comments are supported — lines starting with `//`
(after optional whitespace) are stripped before parsing. Inline `//`
inside string values (e.g. URLs) is untouched.

If the JSON is malformed, a warning is logged via `console.warn` and the
shell keeps running with whatever was last successfully parsed (or
defaults if nothing has been). Your shell will not crash from a typo.

## Quick start

```bash
mkdir -p ~/.config/quickshell-bar
cat > ~/.config/quickshell-bar/config.jsonc <<'EOF'
{
  // Visual overrides
  "accent": "#7aa2f7",
  "fontMono": "JetBrains Mono Nerd Font",

  // Switch web search to DuckDuckGo
  "searchUrl": "https://duckduckgo.com/?q=%s",
  "searchName": "DuckDuckGo",

  // Quieter shell
  "volumeFeedbackEnabled": false
}
EOF
```

Save the file and your running shell picks the changes up immediately.

> **First-time setup**: if you've just pulled / merged the branch that
> introduces `Local.qml`, you need to restart `qs` once for the new
> singleton to register (per gotcha #62 — hot-reload picks up file
> content but not new singleton entries in the qmldir cache).
> `pkill qs && qs -p /path/to/repo -d &` does it. Subsequent edits to
> your `config.jsonc` hot-reload normally.

## Overridable keys (Phase 1)

### Colors — surfaces

| Key | Type | Default | What it controls |
|---|---|---|---|
| `bg` | color | `"#16181c"` | Bar / popup base background |
| `surface` | color | `"#1e1e22"` | Hover state, mild elevation (rows, tile body) |
| `surfaceHi` | color | `"#26262a"` | Pinned / pressed / active state |
| `border` | color | `"#2a2a2e"` | Lines, popup borders, dividers |

### Colors — text

| Key | Type | Default | What it controls |
|---|---|---|---|
| `text` | color | `"#fcfcfc"` | Primary text (matches breeze-dark icon foreground) |
| `textDim` | color | `"#909090"` | Secondary text (status lines, % readouts) |
| `textMuted` | color | `"#5e5e5e"` | Tertiary text (separators, weekend dates) |

### Colors — accent

| Key | Type | Default | What it controls |
|---|---|---|---|
| `accent` | color | `"#ffffff"` | Focused-day on calendar, slider thumb, today-row highlight, active tile fill, etc. |
| `accentText` | color | `"#16181c"` | Text drawn on top of accent fill |

### Colors — error / warning

| Key | Type | Default | What it controls |
|---|---|---|---|
| `error` | color | `"#ff5050"` | Error borders / strokes (lock auth fail, low battery) |
| `errorBright` | color | `"#ff7070"` | Error text on dark backgrounds |

### Colors — workspace pips

| Key | Type | Default | What it controls |
|---|---|---|---|
| `pipIdle` | color | `"#2a2a2e"` | Workspace pip when idle |
| `pipActive` | color | `"#3a3a3e"` | Workspace pip when active on output but not focused |
| `pipFocused` | color | `"#ffffff"` | Workspace pip when focused (typically = accent) |

### Geometry

| Key | Type | Default | What it controls |
|---|---|---|---|
| `barHeight` | int (px) | `32` | Bar height. Reasonable values: 24-48. |
| `radius` | int (px) | `6` | Corner radius for popups, cards, tiles |
| `radiusSmall` | int (px) | `4` | Corner radius for chips, pills, hover backgrounds |

### Animations

| Key | Type | Default | What it controls |
|---|---|---|---|
| `animFast` | int (ms) | `100` | Hover transitions (color flips on tiles, buttons) |
| `animMed` | int (ms) | `140` | Switch / slider thumb / pill animations |

### Fonts

| Key | Type | Default | What it controls |
|---|---|---|---|
| `fontMono` | string | `"Iosevka Nerd Font"` | Mono font used everywhere — bar text, popups, lock clock |
| `fontIcon` | string | `"Font Awesome 7 Free"` | Icon font (Solid style) for most glyphs |
| `fontBrand` | string | `"Font Awesome 7 Brands"` | Brands font (currently only the Bluetooth glyph) |

### Font sizes

| Key | Type | Default | What it controls |
|---|---|---|---|
| `fontSizeBadge` | int (px) | `9` | Notification count, signal-strength overlays |
| `fontSizeSmall` | int (px) | `11` | Tooltips, dim secondary text, status lines |
| `fontSizeNormal` | int (px) | `13` | Bar body text, time, workspace numbers |
| `fontSizeLarge` | int (px) | `15` | Section headers in popups, Now Playing title |
| `fontSizeXL` | int (px) | `17` | Standout labels (lock password input) |
| `iconSize` | int (px) | `13` | Default Font Awesome glyph size in 22 × 22 bar widgets |

### Behavior

| Key | Type | Default | What it controls |
|---|---|---|---|
| `volumeFeedbackEnabled` | bool | `true` | KDE-style audible cue on volume change. Set `false` for a silent shell. Requires `libcanberra` + `sound-theme-freedesktop`. |

### Launcher

| Key | Type | Default | What it controls |
|---|---|---|---|
| `searchUrl` | string | `"https://kagi.com/search?q=%s"` | Web-search URL template for `?` mode. `%s` is replaced with the URL-encoded query. |
| `searchName` | string | `"Kagi"` | Footer label shown next to the search query in `?` mode |

#### Search-engine examples

```jsonc
"searchUrl": "https://duckduckgo.com/?q=%s",          "searchName": "DuckDuckGo"
"searchUrl": "https://www.google.com/search?q=%s",    "searchName": "Google"
"searchUrl": "https://search.brave.com/search?q=%s",  "searchName": "Brave Search"
"searchUrl": "https://www.startpage.com/do/search?q=%s", "searchName": "Startpage"
```

## Recipes

### "Tokyo Night"-ish accent + JetBrains font

```jsonc
{
  "accent":     "#7aa2f7",   // soft blue
  "accentText": "#1a1b26",   // dark text on accent
  "fontMono":   "JetBrains Mono Nerd Font"
}
```

### Solarized Dark surfaces

```jsonc
{
  "bg":        "#002b36",
  "surface":   "#073642",
  "surfaceHi": "#08404d",
  "border":    "#0d4a55",
  "text":      "#fdf6e3",
  "textDim":   "#93a1a1",
  "textMuted": "#586e75",
  "accent":    "#268bd2",
  "accentText": "#fdf6e3"
}
```

### Compact bar (for high-DPI displays)

```jsonc
{
  "barHeight":      26,
  "fontSizeNormal": 11,
  "fontSizeSmall":  9,
  "iconSize":       11
}
```

### Snappier animations

```jsonc
{
  "animFast": 60,
  "animMed":  90
}
```

## What is NOT overridable here

These require code changes (not a value tweak):

- Bar widget order or which widgets are present (edit `Bar.qml`)
- Control Center tile order or content (edit `controlcenter/TilesView.qml`)
- The 5-step font scale itself (Badge / Small / Normal / Large / XL — adding a 6th step is structural)
- The popup recipe (animation pattern, shadow params) — global change, not per-machine
- IPC handler names (public API)
- Compositor backends, weather API choice, lock screen layout

If you want any of those tweakable too, that's a Phase 2 conversation.

## Phase 2 candidates (not yet wired through `Local`)

These are additional service-level values that could be added to the
override system on demand. None work today via `config.json`; tracked
here so future passes know what's worth promoting:

- Wallpaper default folder (currently `$HOME/Pictures/Wallpaper`)
- Wallpaper default fill mode
- Weather refresh interval (currently 15 min)
- Weather Open-Meteo `models=` parameter (currently `knmi_seamless`)
- Weather cities catalogue (NL-only by default)
- OSD dismiss interval (1500 ms)
- Slider wheel step (5%)
- Lock screen blur strength, dim opacity, clock pixel size
- Notification card slide-in duration

If any of these are blocking your tweaks, ask and we'll promote them.

## Troubleshooting

### My override isn't taking effect

1. **Make sure the file is `.jsonc`, not `.json`.** The shell reads
   `~/.config/quickshell-bar/config.jsonc` literally — a plain `.json`
   at the same path is silently ignored. `mv config.json config.jsonc`
   if you started with the wrong extension.
2. **Restart `qs` once after pulling the `Local` singleton for the
   first time.** New singletons require a daemon restart per gotcha
   #62 — hot-reload picks up file content but not new qmldir entries.
   `pkill qs && qs -p <path> -d &`.
3. Verify the JSON parses. Most likely cause: trailing comma, missing
   quote, single quotes instead of double. JSONC line comments (`//`)
   are stripped before parsing — but everything else must be valid
   JSON. `python3 -c 'import json,sys,re; t=sys.stdin.read(); t="\n".join(l for l in t.splitlines() if not l.lstrip().startswith("//")); json.loads(t)' < ~/.config/quickshell-bar/config.jsonc`
   will validate.
4. Check `qs log` for `[Local] config parse error:` — logged on any
   parse failure, with the JSON.parse exception attached.
5. Make sure the key name matches exactly (case-sensitive).
6. Some values (font family changes especially) need a full shell
   restart to repaint everything. Hot-reload covers most cases but not
   all. `pkill qs && qs -p <path> -d &`.

### My override broke something

Delete or rename `~/.config/quickshell-bar/config.jsonc` and restart.
You're back to defaults instantly. The override file is purely additive
— there's no destructive state stored in it.

### Where else can I look?

- `Theme.qml` — every default lives here as the second argument to
  `Local.get(<key>, <default>)`. Authoritative reference.
- `launcher/LauncherService.qml` — same pattern for `searchUrl` /
  `searchName`.
- `Local.qml` — the override loader itself (~50 lines).
