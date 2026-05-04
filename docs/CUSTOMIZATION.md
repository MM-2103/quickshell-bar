# Customization

Per-machine overrides without touching tracked files.

## Three ways to edit

| Method | When to use |
|---|---|
| **Pick a pre-made theme** — open the Settings page (gear icon in Control Center, or `qs ipc call settings open`) and click a card on the Theme tab. | Easiest. One click sets all 14 colour keys to a curated palette. Built-in themes: Default, Gruvbox Dark, Catppuccin Mocha, Tokyo Night Storm, Nord, Rosé Pine, Dracula, Everforest Dark, Kanagawa Wave, Solarized Dark. User-defined themes loaded from `~/.config/quickshell-bar/themes/*.jsonc` appear alongside. |
| **Visual settings page (other tabs)** — same Settings popup, Colours / Typography / Layout & Motion / Behaviour tabs. | Casual tweaking on top of (or independent of) a theme. Sliders, hex-input + colour picker, dropdowns. Live preview as you change values; auto-saves to disk after 500 ms idle. |
| **Hand-edit `~/.config/quickshell-bar/config.jsonc`** | Power users, scripting, copying configs between machines, dotfiles repos. JSONC syntax with comments allowed. |

All three write to the same `config.jsonc`. The settings page rewrites
the file in canonical format (header comment + minimal JSON of
overridden keys); the first save of each session backs up the
existing content to `config.jsonc.bak` so manual edits with custom
comments aren't lost. Theme-card clicks write all 14 colour keys at
once via the same debounced flush, so a theme switch is one
`config.jsonc` write, not 14.

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

JSONC-style comments are supported — both `//` line comments (anywhere
on a line, including trailing after a value) and `/* ... */` block
comments are stripped before parsing. `//` and `/*` inside quoted
string values (e.g. URLs like `"https://..."`) are preserved correctly
— the strip logic is string-aware.

If the JSON is malformed, a warning is logged via `console.warn` and the
shell keeps running with whatever was last successfully parsed (or
defaults if nothing has been). Your shell will not crash from a typo.

## Themes

The Settings popup's Theme tab is the fastest way to recolour the
shell. Click a card and all 14 colour keys are written at once;
the rest of the customization keys (fonts, sizes, behaviour) are
unaffected, so your typography and layout choices stay intact across
theme swaps.

### Built-in catalogue

Twenty themes ship in the catalogue: ten dark themes followed by their
ten light variants, in the same order. Cards appear in the Theme tab
all-darks first, then all-lights.

#### Dark variants

| Theme | Notes |
|---|---|
| **Default** | The shipped monochrome with white accent. One-click revert. |
| **Gruvbox Dark** | morhetz/gruvbox dark0 base, bright_yellow accent. |
| **Catppuccin Mocha** | catppuccin/palette Mocha flavour, mauve accent. |
| **Tokyo Night Storm** | folke/tokyonight.nvim Storm variant, blue accent. |
| **Nord** | Arctic Ice Studio's nord0..nord15, frost (nord8) accent. |
| **Rosé Pine** | rose-pine.io main palette, iris accent (purple). |
| **Dracula** | draculatheme.com canonical palette, purple accent. |
| **Everforest Dark** | sainnhe/everforest medium variant, green accent. |
| **Kanagawa Wave** | rebelot/kanagawa.nvim Wave variant, crystalBlue accent. |
| **Solarized Dark** | Ethan Schoonover's classic, blue accent. |

#### Light variants

| Theme | Notes |
|---|---|
| **Default Light** | Synthesised inversion of the monochrome Default; warm off-white bg, near-black accent. No upstream reference. |
| **Gruvbox Light** | morhetz/gruvbox light0 base, mustard yellow accent. |
| **Catppuccin Latte** | catppuccin/palette Latte flavour, mauve accent. |
| **Tokyo Night Day** | folke/tokyonight.nvim Day variant, "blueprint paper" feel with deep-blue text. |
| **Nord Light** | Community-derived inversion using Snow Storm tones (`nord4..nord6`), frost dark blue (`nord10`) accent. Not canonical Nord. |
| **Rosé Pine Dawn** | rose-pine.io Dawn flavour, soft purple accent. |
| **Dracula Light** | Community-derived inversion; darkened purple accent for legibility on light bg. Not canonical Dracula. |
| **Everforest Light** | sainnhe/everforest medium light variant, mustard-green accent. |
| **Kanagawa Lotus** | rebelot/kanagawa.nvim Lotus variant, ocean teal on parchment bg. |
| **Solarized Light** | Ethan Schoonover's classic, blue accent (same as the dark variant). |

The "Current: <theme name>" label above the grid identifies which
theme (if any) your current state matches. If you tweak any colour
manually after applying a theme, the label flips to "Current: Custom"
and the card's selected indicator clears — apply the same theme card
again to reset back to its palette.

### Light/dark toggle

The Control Center has a **Theme** tile (third row, first column) that
toggles between the light and dark variants of the currently-applied
theme. So if you're on Catppuccin Mocha, one click swaps to Catppuccin
Latte; click again, back to Mocha. The icon shows a sun when on a dark
theme (toggling FROM dark) and a moon when on a light theme — pointing
at the destination, mirroring the convention in mainstream OS dark-mode
toggles.

The tile renders **disabled** in three cases:
- No current theme matches (you're in "Custom" state — apply any theme
  first to enable the toggle).
- Your current theme has no `siblingId` set (typically a user-defined
  theme without a paired variant).
- The `siblingId` points at an id that doesn't exist (a sibling file
  was deleted or failed validation).

### User-defined themes

Drop a JSONC file into `~/.config/quickshell-bar/themes/` to add your
own theme. Each file holds one theme:

```jsonc
// ~/.config/quickshell-bar/themes/my-custom.jsonc
{
  "id":        "my-custom",
  "label":     "My Custom Theme",
  "kind":      "dark",                 // optional; defaults to "dark"
  "siblingId": "my-custom-light",      // optional; omit if no sibling
  "palette": {
    "bg":          "#1a1a1a",
    "surface":     "#2a2a2a",
    "surfaceHi":   "#3a3a3a",
    "border":      "#404040",
    "text":        "#ffffff",
    "textDim":     "#a0a0a0",
    "textMuted":   "#606060",
    "accent":      "#ff6b6b",
    "accentText":  "#1a1a1a",
    "error":       "#ff4444",
    "errorBright": "#ff6666",
    "pipIdle":     "#404040",
    "pipActive":   "#606060",
    "pipFocused":  "#ff6b6b"
  }
}
```

A copy-pasteable template lives at [`examples/theme.jsonc`](../examples/theme.jsonc).

**Required** top-level keys: `id` (stable slug, used for current-theme
matching and `siblingId` references), `label` (display text), `palette`
(record of the 14 overridable colour keys).

**Optional** top-level keys: `kind` (`"dark"` or `"light"`; default
`"dark"`) and `siblingId` (id of the paired light/dark variant; default
omitted = toggle disabled on this theme).

To pair two of your own themes, set their `siblingId` fields to point
at each other:

```jsonc
// my-theme.jsonc
{ "id": "my-theme", "siblingId": "my-theme-light", "kind": "dark", ... }

// my-theme-light.jsonc
{ "id": "my-theme-light", "siblingId": "my-theme", "kind": "light", ... }
```

Files with malformed JSON or missing required fields are skipped
silently with a `console.warn`.

The directory is rescanned on shell start and on every Settings popup
open — drop a theme file in, open Settings, and your card appears
right after the built-ins. No daemon restart needed.

> **First-time setup**: when you first pull the branch that introduces
> `ThemePresets`, you need to restart `qs` once for the new singleton
> to register (per gotcha #62 — hot-reload picks up file content but
> not new qmldir entries). `pkill qs && qs -p /path/to/repo -d &`.
> After that, edits to your theme files hot-reload normally.

## Quick start

The repo ships an example config at [`examples/config.jsonc`](../examples/config.jsonc)
with **every overridable key set to its current default**. Copy it
verbatim and the shell behaves identically — no visible change. Then
edit just the keys you want to override; delete or comment out the rest.

```bash
mkdir -p ~/.config/quickshell-bar
cp examples/config.jsonc ~/.config/quickshell-bar/config.jsonc
# now edit ~/.config/quickshell-bar/config.jsonc
```

Or, if you only want a few overrides without the full reference, drop in
just the keys you care about:

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

> Tokyo Night Storm and Solarized Dark are now both built-in themes;
> click them on the Theme tab and the 14 colour keys are written for
> you. The recipes below show how to **layer extra tweaks on top of**
> a theme — typography, geometry, animation — that the theme system
> deliberately doesn't touch.

### Tokyo Night Storm + JetBrains font

Pick the **Tokyo Night Storm** card on the Theme tab, then add to
`~/.config/quickshell-bar/config.jsonc`:

```jsonc
{
  "fontMono": "JetBrains Mono Nerd Font"
}
```

### Solarized Dark with custom accent

Pick the **Solarized Dark** card, then override just the accent in
`config.jsonc` if you want to deviate (this flips the Theme card to
"Custom" until you reset the accent):

```jsonc
{
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
