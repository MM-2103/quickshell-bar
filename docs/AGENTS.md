# Agents Guide

Orientation for new contributors — human or AI — picking up this repo.
The fastest path from "git clone" to productive change is reading this
file end-to-end. ~10 minutes.

> Companion docs:
> - [`STYLE.md`](STYLE.md) — visual + structural conventions, recipes
> - [`QUICKSHELL_REFERENCE.md`](QUICKSHELL_REFERENCE.md) — Quickshell API + 67+ gotchas
> - [`README.md`](../README.md) — install + user-facing overview

---

## 1. Read this first

**What this repo is.** A complete personal Wayland desktop shell built on
[Quickshell](https://quickshell.org/) (QML-based shell framework on top of
Qt 6). It replaces ~10 typical desktop daemons (waybar, swaync, swayosd,
nm-applet, blueman, wlogout, fuzzel, hyprlock, KDE media controls,
clipboard manager) with one configurable QML codebase.

**Primary compositor**: niri (the scrollable-tiling Wayland compositor).
Hyprland and Sway/i3 are also supported via a compositor abstraction
layer. Other wlroots-based compositors get a stub backend (bar still
loads, workspaces module is empty).

**Tech stack**:
- Quickshell ≥ 0.2.1 (AUR `quickshell`)
- Qt 6.5+ (`qt6-base`, `qt6-declarative`, `qt6-effects` for `MultiEffect`)
- PAM (`/etc/pam.d/qslock` for the lock screen)
- Pipewire (audio), NetworkManager (`nmcli`), BlueZ (`bluetoothctl` via DBus)
- MPRIS (media), UPower (battery + power profiles), SystemNotifierItem (tray)
- `cliphist` (clipboard history backend), `wl-copy` (clipboard write)
- `brightnessctl` (backlight, laptops only)
- `curl` (weather widget HTTP fetches; project idiom for HTTP since Quickshell has no built-in network module)
- Optional: `libcanberra` + `sound-theme-freedesktop` (KDE-style audible cue on volume change)
- `grim` for screenshots; the in-shell wallpaper module replaces both `swaybg` and `waypaper`

**To run it**:
```bash
qs -p /path/to/quickshell-bar -d        # daemon mode, detaches
```

**To check it's running**:
```bash
qs -p /path/to/quickshell-bar log -t 30 | grep -iE "compositor|backend"
# Should show: [Compositor] detected backend: niri (or hyprland/sway)
```

**To smoke-test after a change**:
```bash
qs -p /path/to/quickshell-bar > /tmp/qs-smoke.log 2>&1 &
PID=$!
sleep 4
kill $PID 2>/dev/null
wait 2>/dev/null
grep -iE "warn|error|TypeError|caused by|ReferenceError" /tmp/qs-smoke.log | \
    grep -v "QSettings\|already registered\|Registration will\|launcher-frecency\|propertyCache\|qt.svg.draw\|QThreadStorage"
echo "(empty = clean)"
```
Empty output = clean run. Filtered noise is documented in [`STYLE.md`](STYLE.md).

**To recover if the running daemon misbehaves**:
```bash
qs kill --shell <id>                    # graceful
# OR
pkill qs                                # nuclear
qs -p /path/to/quickshell-bar -d &      # restart
```

**NEVER `kill -HUP`** — SIGHUP terminates the daemon, it does NOT trigger reload.

---

## 2. Architecture overview

### Top-down flow

```
shell.qml (entry point)
├── Compositor singleton            ← qs.compositor.Compositor (auto-detects + delegates)
├── Theme singleton                 ← visual tokens (colors, fonts, sizes, animations)
├── PopupController singleton       ← popup mutex (only one popup open at a time)
│
├── Variants × Quickshell.screens
│   ├── WallpaperLayer              ← Background-layer surface, per monitor (replaces swaybg)
│   ├── Bar { screen: modelData }   ← per-monitor bar
│   │   ├── Workspaces (left)       ← reads Compositor.workspaces filtered by output
│   │   ├── Clock (center)
│   │   └── Right cluster:          ← 8 widgets after the CC declutter
│   │       Notifications, TrayCollapser, Media, Battery, Brightness,
│   │       Volume, ControlCenter, Power
│   │
│   ├── PanelWindow (notification stack, top-right)
│   ├── Osd                         ← bottom-center, focused-monitor only (Overlay layer)
│   ├── ClipboardPopup              ← centered, focused-monitor only
│   ├── Launcher                    ← centered, focused-monitor only
│   ├── WallpaperPickerPopup        ← centered, focused-monitor only
│   └── WeatherDetailPopup          ← centered, focused-monitor only (hourly + 7-day)
│
├── Lock { }                        ← WlSessionLock (NOT in Variants — single instance)
│
└── IpcHandler × 4                  ← clipboard, launcher, lock, popups
```

The **ControlCenter** bar widget owns its anchored `ControlCenterPopup`,
which contains a Loader-driven view stack: a 3 × 2 tile grid plus four
detail views (NetworkView, BluetoothView, PowerProfileView, CitiesView)
extracted from what used to be standalone bar-widget popups.

### Per-screen pattern

Anything visible "per monitor" lives inside a `Variants { model: Quickshell.screens }`
block. Each iteration receives `modelData` (a `ShellScreen`) and binds
`screen: modelData`. Components inside read their own `modelData`.

For "show only on the focused monitor" components (OSD, Launcher, Clipboard),
the panel is created on every screen but `visible` is gated on
`isFocusedScreen = modelData.name === Compositor.focusedOutput`.

### Service singletons vs visual components

The shell separates **state** (singletons) from **rendering** (regular types):

| Service singleton | Owns |
|---|---|
| `Theme` | colors, font tokens, sizes, animation durations, `volumeFeedbackEnabled` flag |
| `Compositor` | workspaces, focusedOutput, currentLayout, windowFocused signal, dispatch helpers |
| `MediaService` | currentPlayer, playback state, cachedArtUrl, transport actions |
| `NotificationService` | tracked notifications, popup queue, DND state, current screen |
| `OsdService` | currentKind, brightness/volume/layout/caps state, show()/setBrightness() |
| `LockService` | locked state, PAM context (wallpaper now read from WallpaperService) |
| `LauncherService` | popupOpen, query, filtered, frecency |
| `ClipboardService` | popupOpen, entries (cliphist-backed) |
| `NetworkService` | wired/wifi state, networks list, connect/forget actions |
| `WallpaperService` | per-monitor wallpaper map, fillMode, picker open state, scan/persistence |
| `WeatherService` | location, current/hourly/daily forecast (KNMI via Open-Meteo), city catalogue, detail-popup open state |
| `ControlCenterService` | view-stack (`currentView`), idle-inhibit toggle (no bar widget owns it now) |
| `PopupController` | activePopup, mutex helpers |

Visual components consume singletons (`Compositor.workspaces`,
`MediaService.currentPlayer.trackTitle`, etc.) but never create their
own state singletons mid-tree. State always belongs in a singleton.

### Compositor abstraction

`compositor/Compositor.qml` is a singleton that auto-detects which
Wayland compositor is running (env vars: `$HYPRLAND_INSTANCE_SIGNATURE`,
`$SWAYSOCK`, `$NIRI_SOCKET`, `$XDG_CURRENT_DESKTOP`) and instantiates
exactly one `Backend*.qml` adapter via a `Loader { sourceComponent }`.

Public surface (consumed by Workspaces.qml, shell.qml, PowerMenuPopup.qml):
```qml
Compositor.workspaces                    // [{id, idx, output, is_focused, is_active, name}, ...]
Compositor.focusedOutput                 // string (monitor name)
Compositor.currentLayout                 // string ("" on Sway/i3)
Compositor.windowFocused(id) signal      // for popup auto-dismiss
Compositor.dispatchFocusWorkspace(idx)   // click-to-focus a chip
Compositor.dispatchLogout()              // power-menu Logout button
```

**RULE**: never reference `Hyprland.*`, `I3.*`, or shell out to
`niri msg` outside `compositor/Backend*.qml`. The whole point of the
abstraction is that the rest of the shell stays compositor-agnostic.

### Popup mutex

`PopupController.qml` enforces "only one popup open at a time". Every
popup that wants to participate calls:

```qml
function toggle() {
    if (popup.wantOpen) {
        popup.wantOpen = false;
    } else {
        PopupController.open(popup, () => popup.wantOpen = false);
        popup.wantOpen = true;
    }
}
onVisibleChanged: if (!visible) PopupController.closed(popup)
```

Opening a new popup automatically calls the previous popup's `closer`
callback. The `Compositor.windowFocused` signal also triggers
`PopupController.closeAll()` when the user focuses an app.

### IPC for external triggers

Compositor keybinds and idle daemons communicate with the running shell
via `qs ipc call <target> <fn>`. The shell registers `IpcHandler` blocks
in `shell.qml`. **Never spawn separate processes per keybind** — IPC
keeps a single source of truth and survives hot-reload.

### Hot-reload semantics

When you save a `.qml` file, the daemon hot-reloads:
- ✓ File content changes pick up immediately
- ✓ Property additions/removals reflect in subsequent bindings
- ✓ New visible components appear
- ✗ Newly-added `pragma Singleton` files DON'T register correctly until daemon restart (qmldir cache, gotcha #62)
- ✗ Moving `pragma Singleton` from line N to line 1 (fixing gotcha #45) ALSO requires a daemon restart

When in doubt about whether a change took effect: smoke-test with a fresh
`qs` invocation. If it works there but not in the running daemon, restart.

---

## 3. Where things live

| Want to... | Start by reading | Recipe |
|---|---|---|
| Add a bar widget (clickable icon) | `volume/Volume.qml` or `system/Brightness.qml` | [STYLE.md "Bar widget anatomy"](STYLE.md#bar-widget-anatomy) |
| Add a popup | `volume/VolumePopup.qml` or `system/BrightnessPopup.qml` | [STYLE.md "Popup recipe"](STYLE.md#popup-recipe-animated) |
| Add a service singleton | `media/MediaService.qml` | gotcha #45 (pragma must be line 1, no `{}` in header comments!) |
| Add a compositor backend | `compositor/BackendNiri.qml` | gotcha #59 |
| Add an IPC handler | `shell.qml` (search `IpcHandler`) | gotcha #9 (typed signatures) |
| Add a tooltip | any bar widget — search `BarTooltip` | [STYLE.md "Tooltip recipe"](STYLE.md#tooltip-recipe) |
| Add a slider/progress bar | `Slider.qml` / `ProgressBar.qml` | [STYLE.md "Sliders & progress bars"](STYLE.md#sliders--progress-bars) |
| Add a tile to the Control Center | `controlcenter/Tile.qml` + `controlcenter/TilesView.qml` | [STYLE.md "Tile recipe"](STYLE.md#tile-recipe) — body click vs chevron click pattern |
| Add a CC detail view | `network/NetworkView.qml` (or any `*View.qml`) + register in `controlcenter/ControlCenterPopup.qml` Loader switch | [STYLE.md "View-stack recipe"](STYLE.md#view-stack-recipe), [STYLE.md "Extracted view recipe"](STYLE.md#extracted-view-recipe) |
| Add a card (Weather / NowPlaying-style) | `weather/WeatherCard.qml` or `lock/NowPlayingCard.qml` | [STYLE.md "Card recipe"](STYLE.md#card-recipe) |
| Fetch HTTP data (no Quickshell module exists) | `weather/WeatherService.qml` for the canonical pattern | `Process { command: ["curl", "-sf", "--max-time", "10", url] }` + `StdioCollector` + `JSON.parse`; matches NetworkService's `nmcli` shape exactly |
| Tune visuals (color, size, animation) | `Theme.qml` | always add a token, never inline |
| Add a Font Awesome glyph | verify codepoint via `fontTools` first | [STYLE.md "Glyph conventions"](STYLE.md#glyph-conventions-font-awesome) |
| Document a new gotcha | `docs/QUICKSHELL_REFERENCE.md` (currently #67) | append numbered, update header range |
| Add a screenshot | see "Common-task recipes" below — never `mcp_Read` raw |
| Modify the lock screen | `lock/LockSurface.qml` + `lock/NowPlayingCard.qml` | gotcha #48 (Component-based per-screen fan-out), gotcha #64 (use Timer + Date, not SystemClock) |

### File layout summary

| Directory | Contents |
|---|---|
| `<root>/*.qml` | top-level: `shell.qml`, `Bar.qml`, `Theme.qml`, helpers (`BarIcon`, `BarTooltip`, `Slider`, `ProgressBar`), `PopupController.qml` |
| `compositor/` | `Compositor.qml` singleton + per-backend adapters |
| `workspaces/` | `Workspaces.qml` chip strip (consumes Compositor) |
| `clock/` | `Clock.qml` widget + `Calendar.qml` popup |
| `notifications/` | `NotificationService.qml`, `Notifications.qml` (bell), `NotificationCard.qml`, `NotificationCenterPopup.qml` |
| `osd/` | `OsdService.qml` + `Osd.qml` panel (`Overlay` layer — visible over fullscreen) |
| `volume/`, `media/`, `tray/` | bar widgets + popups + services that stayed in the bar after the CC declutter |
| `network/`, `bluetooth/` | services + `*View.qml` files (no bar widgets — accessed via the Control Center) |
| `system/` | bar widgets that stayed (`Battery`, `Brightness`, `Power`, `PowerMenuPopup`, `BrightnessPopup`) + `PowerProfileView` (used by CC; no bar widget) |
| `controlcenter/` | `ControlCenter` bar widget, `ControlCenterPopup`, `ControlCenterService` singleton, `Tile`, `TilesView`, `SlidersBlock` |
| `wallpaper/` | `WallpaperService` singleton, `WallpaperLayer` (Background-layer surface, replaces swaybg), `WallpaperPickerPopup` (replaces waypaper) |
| `weather/` | `WeatherService` singleton (KNMI via Open-Meteo), `WeatherCard` (in CC), `WeatherDetailPopup` (centered, hourly + 7-day), `CitiesView` (CC detail view) |
| `clipboard/`, `launcher/`, `lock/` | popup-only features |
| `docs/` | `QUICKSHELL_REFERENCE.md`, `STYLE.md`, this file (`AGENTS.md`), `screenshots/` |
| `examples/` | copy-pasteable compositor + idle-daemon configs |

---

## 4. IPC handler reference

Every `qs ipc call` command currently registered in `shell.qml`:

```
qs ipc call lock open                   # lock the session (idempotent)
qs ipc call clipboard open              # open clipboard popup
qs ipc call clipboard close
qs ipc call clipboard toggle
qs ipc call launcher open               # apps mode
qs ipc call launcher close
qs ipc call launcher toggle
qs ipc call launcher openEmoji          # pre-fills ";" prefix → emoji mode
qs ipc call launcher openWith <prefix>  # pre-fill arbitrary text
qs ipc call popups status               # diagnostic: "active: X" or "no popup active"
qs ipc call popups closeAll             # dismiss whatever's open
```

**To add a new IPC handler**: add an `IpcHandler { target: "<name>"; ... }`
block to `shell.qml`. Functions need typed signatures (gotcha #9):

```qml
IpcHandler {
    target: "myfeature"
    function open(): void  { MyService.openPopup(); }
    function withArg(s: string): void { MyService.doThing(s); }
}
```

Without the type annotations the function isn't registered.

---

## 5. AI-specific traps

These bit during agent-driven development. Not general Quickshell
gotchas — those are in `QUICKSHELL_REFERENCE.md`.

### Don't `mcp_Read` raw full-monitor screenshots

A 2560×1440 PNG can be **3-5 MB**. Even though Anthropic's per-image API
limit accommodates this, accumulating multiple multi-MB images in a
single conversation pushes past the practical context window. The
conversation gets truncated or sluggish.

**Pattern that works**:
1. `grim -o DP-2 /tmp/raw.png` (full capture, never `mcp_Read`'d)
2. Process via Python + PIL: crop, resize to ≤1280px wide, save with `optimize=True, compress_level=9`
3. Save final to `docs/screenshots/NN-name.png` (typically 50-250 KB)
4. For visual confirmation: generate a separate 640×wide thumbnail to `/tmp/`, `mcp_Read` THAT, then discard
5. Never `mcp_Read` the raw `/tmp/raw.png` or any file > 500 KB

### `SIGHUP` kills the qs daemon

`kill -HUP <pid>` does NOT trigger reload — it terminates. The daemon
has no signal-driven reload. Use `qs kill --shell <id>` for graceful
shutdown, or just save a file (which triggers hot-reload).

### Hot-reload doesn't refresh qmldir cache

When you add a new `pragma Singleton` file (or fix the pragma's placement
per gotcha #45), the running daemon's qmldir cache stays stale. Symptom:
`import qs.subdir` resolves but the singleton's properties come back
`undefined`. Smoke-test on a fresh `qs` invocation to prove the code's
correct, then restart the user's daemon. Documented as gotcha #62 in
the reference.

### Stale `qs log` entries

`qs log -t N` reads the LAST N lines from an append-only log. Old debug
messages persist forever. Lines like `[Lock] all screens covered —
secure=true` may be from minutes ago. Use timestamps (the log records
them when `--log-times` is set) or trigger a known event to confirm
current state.

### `wl-copy` leaves a persistent process per invocation

Each `wl-copy` keeps a daemon process running until something else takes
the clipboard. Sequential `wl-copy` calls stack up. Usually harmless;
verify with `pgrep wl-copy | wc -l` if you suspect issues.

### The cliphist + `wl-copy` preload pattern (for screenshot demos)

```bash
cliphist wipe
echo "Hello world" | wl-copy ; sleep 0.3
echo "https://example.com" | wl-copy ; sleep 0.3
echo "function example() { return 42; }" | wl-copy ; sleep 0.3
echo "$(date '+%H:%M:%S'): demo entry" | wl-copy ; sleep 0.3
```

The `sleep 0.3` between copies gives cliphist time to capture each. Skip
the sleep and you may see only the last entry.

### Niri's `WindowFocusChanged id=null` is niri-specific

Gotcha #46 in the reference. Each compositor backend filters its own
focus events according to its quirks. Don't assume the niri filter logic
applies to Hyprland or Sway — they have different event payload shapes.

### `pragma Singleton` brace-counting bug (gotcha #45)

The single most common AI-introduced regression in this repo. ALWAYS:
1. `pragma Singleton` on the very first non-blank line
2. Header comments BELOW the pragma
3. Header comments must NOT contain `{` or `}` characters

The qmlscanner doesn't strip `//` comments before brace-tracking. A `{`
in your docstring ("array of `{ id, idx, output }`") makes it think
you're already inside a QML object, and the pragma gets silently
ignored. The file then registers as a regular type, not a singleton.

Symptom: `Cannot read property 'foo' of undefined` from consumers.

### Cumulative image context burden across long conversations

Even individually-small images accumulate. After ~20 small thumbnails
in one session, the conversation gets noticeably sluggish. Be selective
about which captures actually need visual confirmation. Text-only
verification (`PIL.Image.size`, `os.path.getsize()`) costs nothing.

---

## 6. Common-task recipes

Each links to the full template in `STYLE.md`. Cliff notes here:

### Adding a bar widget

1. Copy `volume/Volume.qml` or `system/Brightness.qml` as a starting point
2. Replace the FA glyph (`BarIcon { glyph: "\u..." }`)
3. Wire any state to a service singleton (don't put state in the widget)
4. Add a `BarTooltip` with descriptive text
5. Register the widget in `Bar.qml`'s right cluster
6. Smoke-test, screenshot, commit

### Adding a popup

1. Copy `system/BrightnessPopup.qml` as a starting point
2. Adjust `implicitWidth`/`implicitHeight` for content (always `+24` for shadow padding)
3. Adjust `anchor.rect.y` (always `anchorItem.height + 6 - 12`)
4. Wire `wantOpen` + `hideHold` Timer + opacity Behavior + transform Translate
5. Add `MultiEffect` shadow with the standard parameters (see [STYLE.md](STYLE.md))
6. Register with the bar widget that triggers it
7. Smoke-test

### Adding a compositor backend

1. Copy `compositor/BackendNiri.qml` as a starting point
2. Replace the IPC mechanism (Process+SplitParser for niri-style, `Quickshell.<Compositor>` for built-in modules)
3. Conform to the interface: `workspaces`, `focusedOutput`, `currentLayout`, `windowFocused` signal, `dispatchFocusWorkspace(idx)`, `dispatchLogout()`
4. Add a detection branch in `Compositor.qml`'s `detectedKind` getter + a `Component` declaration in the Loader switch
5. Add a sample keybind config to `examples/<name>-bindings.<ext>`
6. Update the README's compatibility matrix

### Adding a gotcha to the reference doc

1. Append to the bottom of the gotchas list in `docs/QUICKSHELL_REFERENCE.md`
2. Use the next sequential number
3. Update the header range (`#1 through #N+`)
4. Bold the lead sentence
5. Show a code example if applicable

### Updating screenshots

1. Capture with `grim -o DP-2 /tmp/raw.png`
2. Process via Python + PIL (crop or resize as appropriate)
3. Save to `docs/screenshots/NN-name.png` with `optimize=True`
4. **Never `mcp_Read` the raw file** — only thumbnails ≤640px wide for verification
5. Reference in README's Screenshots section

### Bumping a Theme token

1. Edit `Theme.qml`, change the value
2. Smoke-test
3. Visually inspect (screenshot if appropriate)
4. Commit with `theme: <description>` prefix

---

## 7. Workflow conventions

### The cycle

1. **Plan** — for non-trivial changes, propose the approach and ask clarifying questions before touching files. Especially important for cross-cutting changes (theme, abstractions, conventions).
2. **Confirm** — let the user pick options where there are real tradeoffs.
3. **Implement** — small, atomic file edits. One logical change at a time.
4. **Smoke-test** — every change. Empty smoke output = clean.
5. **Commit** — small commits, lowercase area-prefix message (`<area>: <imperative>`).
6. **Visually verify** — screenshot for visual changes, IPC for behavioral.

### Commit message style

```
theme: add font tokens and size scale
notifications: bell uses Font Awesome
popup: drop shadows on all popups
docs: gotchas #56-#58
compositor: BackendHyprland using Quickshell.Hyprland
```

Areas seen so far: `theme`, `bar`, `popup`, `lock`, `media`, `volume`,
`network`, `bluetooth`, `system`, `notifications`, `clipboard`, `launcher`,
`osd`, `tray`, `workspaces`, `clock`, `compositor`, `docs`, `polish`, `chore`.
New areas as the shell grows.

### Granularity

- ~10 files modified across 5-10 commits is typical for a feature-sized change
- Don't merge smoke-untested code
- Don't claim cross-compositor support without testing on the user's machine at minimum (niri = primary, Hyprland/Sway are lightly tested)

---

## 8. Don't touch without explicit ask

These are settled decisions, sensitive to user preferences, or have legal
implications. ALWAYS ask before modifying.

### Legal / attribution
- `LICENSE` — MIT, copyright `mm-2103`
- `NOTICE` — third-party attribution (gemoji MIT, derivative-doc notice)

### Settled user preferences
- `Theme.qml` color tokens (the dark grayscale palette + white accent)
- `Theme.qml` font sizes (the 9/11/13/15/17 scale was iterated on per user feedback; don't re-tune)
- `Theme.qml` font families (Iosevka Nerd Font for mono, Font Awesome 7 for icons)
- The 5-step font scale shape itself (Badge/Small/Normal/Large/XL) — adding a new step requires asking
- Animation durations (`animFast: 100`, `animMed: 140`, popup fade 150ms)
- Drop shadow parameters (color, opacity, offset, blur)

### Architectural contracts
- The `compositor/Compositor.qml` interface (workspaces shape, signal names, dispatch helpers) — changing it means updating all 4 backends
- The `Slider.qml` / `ProgressBar.qml` API — many popups consume them
- The `BarIcon.qml` / `BarTooltip.qml` API — every bar widget uses them
- The `wantOpen` / `hideHold` popup pattern — changing it requires updating ~12 popup files
- The CC view-stack keys (`"tiles"` / `"network"` / `"bluetooth"` / `"powerprofile"` / `"cities"`) — strings appear in `ControlCenterService.setView()` calls, the Loader switch, and the header-title switch in `ControlCenterPopup.qml`. Adding a key means touching all three.
- The CC tile order (Wi-Fi · Bluetooth · Profile / Caffeine · DND · Wallpaper) — fixed in `controlcenter/TilesView.qml` for muscle-memory stability; reordering requires user sign-off
- The `Tile.qml` API (`icon`, `brand`, `label`, `stateText`, `active`, `showChevron`, `iconColor`, `clicked`, `chevronClicked`) — used by all 6 tiles
- The `WeatherService` URL shape and the `models=knmi_seamless` pin — changing the model loses the user's "I want KNMI" preference even if the data still shows up

### Tooling / conventions
- `examples/*` — these are copy-paste targets for users; format matters
- The IPC handler names — `qs ipc call lock open`, etc. are public API; renaming breaks user keybind configs
- Commit message style (`<area>: <imperative>`)
- The smoke-test recipe (filter list)

If you're not sure, ask. The user has final say on visual + UX decisions;
your role is to implement well, not to redesign.
