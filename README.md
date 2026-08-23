# quickshell-bar

A complete personal Wayland desktop shell built on
[Quickshell](https://quickshell.org/), with first-class support for
**niri**, **Hyprland**, and **Sway / i3** out of the box.

Replaces (in one configurable QML codebase):
**waybar** · **swaync / mako / dunst** · **swayosd** ·
**nm-applet** · **blueman-applet** · **KDE media controls** ·
**wlogout** · **fuzzel** · **hyprlock** ·
**swaybg / waypaper** · **hypridle / swayidle**.

## Supported compositors

| Compositor       | Workspaces | Click-to-focus | Window focus | Layout OSD | Logout action       |
|------------------|:----------:|:--------------:|:------------:|:----------:|---------------------|
| **niri**         | yes        | yes            | yes          | yes        | `niri msg action quit` |
| **Hyprland**     | yes        | yes            | yes          | yes        | `hyprctl dispatch exit` |
| **Sway / i3**    | yes        | yes            | yes          | —          | `swaymsg exit` / `i3-msg exit` |
| Other (river, Wayfire, Cosmic, …) | — | — | — | — | — |

The shell auto-detects which compositor is running at startup
(`$HYPRLAND_INSTANCE_SIGNATURE` / `$SWAYSOCK` / `$NIRI_SOCKET` /
`$XDG_CURRENT_DESKTOP`). On unsupported compositors the bar still
loads — only the workspace indicator goes blank, every other widget
keeps working. Override detection with `QS_COMPOSITOR=niri|hyprland|sway`.

---

## Features

**Bar** (32 px top, one per monitor)
- Workspaces with focused / active / idle chip indicators (compositor-aware)
- Clock + Calendar (popup, pinnable)
- Notifications · Tray · Media · Battery · Brightness · Volume
- Control Center (drawer for less-frequent toggles)
- Power menu

**Control Center** (drawer behind the sliders icon)
- Volume + brightness sliders
- 3 × 2 tile grid: Wi-Fi · Bluetooth · Power Profile · Caffeine · DND · Wallpaper
- Tiles with chevrons drill into in-place detail views (Network list, Bluetooth devices, 3-radio profile picker)
- Tiles without chevrons toggle in place (Caffeine, DND) or open the standalone wallpaper picker
- Weather card with KNMI HARMONIE-AROME 2 km Dutch model data (via Open-Meteo)
- Now Playing card (auto-hides when no MPRIS player)

**Popups** (mutex-managed; auto-dismiss on app focus)
- Volume mixer · Notification center · Calendar · Media · Tray menus
- Power menu (lock / suspend / logout / reboot / shutdown)
- Clipboard history (Mod+V) — image-thumbnail aware
- App launcher (Mod+P) — apps + calculator + web search + emoji
- Emoji picker shortcut (Mod+;)
- Wallpaper picker (folder browse + thumbnails + per-monitor)
- Settings page — visual editor for all 33 overridable keys (colours, fonts, sizes, animations, search engine, behaviour) with live preview; opens via the gear icon in the Control Center or `qs ipc call settings open`

**Notifications & OSD**
- Native NotificationServer (replaces external daemons)
- Per-monitor pinned cards
- Volume / brightness / keyboard-layout OSDs (overlay-layer; visible over fullscreen apps)

**Wallpaper** (replaces swaybg + waypaper)
- Per-monitor wallpaper, persisted across reloads
- Background-layer surface with 400 ms cross-fade on change
- Picker: folder browse, fill-mode selector, per-monitor or "All" target
- Lock screen reads from the same source — single source of truth

**Weather** (KNMI via Open-Meteo)
- Current temperature + today's high/low + feels-like + wind + humidity
- Pinned to KNMI HARMONIE-AROME 2 km Netherlands model (`models=knmi_seamless`) — authentic KNMI data without the GRIB / NetCDF / API-key tax
- 25-city NL picker baked in; first run shows "Set location"
- 15-minute auto-refresh + manual refresh button
- Click the card body to open the detail popup: scrollable 24-hour strip, 7-day forecast, sunrise/sunset

**Session lock** (Mod+Shift+X)
- `WlSessionLock` + PAM auth via `/etc/pam.d/qslock`
- Blurred wallpaper background (per-monitor, from the in-shell wallpaper module)
- Multi-monitor surfaces, persistent error state, dim-while-validating
- Hot-reload safe (survives `qs` config reloads)
- `LockedHint` propagation to systemd-logind

**Idle** (replaces hypridle / swayidle)
- Native `ext-idle-notifier-v1` via Quickshell's `IdleMonitor` — no second daemon
- Two independent stages: lock, then blank the monitors. Either can be disabled
- Honours `idle-inhibit-v1`, so video playback suppresses both stages
- Caffeine tile / `qs ipc call idle disable` to stay awake

---

## Screenshots

The bar — full width across one monitor (8 widgets after the Control Center declutter):

![Bar overview](docs/screenshots/01-bar.png)

Right cluster zoomed (3× nearest-neighbor for clarity — actual rendering is sharper):

![Right-cluster zoom](docs/screenshots/02-bar-right.png)

Control Center — sliders, 3 × 2 tile grid, weather card, and the optional Now Playing card:

![Control Center](docs/screenshots/09-control-center.png)

Weather detail popup — current conditions, sunrise/sunset, the next 12 hours, and a 7-day forecast (KNMI HARMONIE-AROME 2 km Dutch model via Open-Meteo):

![Weather detail](docs/screenshots/10-weather-detail.png)

Wallpaper picker — folder browse + thumbnail grid + per-monitor target + fill-mode selector (replaces waypaper):

![Wallpaper picker](docs/screenshots/11-wallpaper-picker.png)

Settings page — visual editor for `~/.config/quickshell-bar/config.jsonc`. Tabs for Colours / Typography / Layout & Motion / Behaviour; sliders, hex inputs, custom HSV colour picker, search-engine presets. Live preview, debounced auto-save, `.bak` on first save:

![Settings page](docs/screenshots/12-settings.png)

Lock screen with the now-playing card:

![Lock screen](docs/screenshots/03-lock.png)

App launcher — apps mode (default), with frecency-sorted results and footer hint:

![Launcher: apps](docs/screenshots/04-launcher-apps.png)

Launcher in calculator mode (`=` prefix) — copies the result on Enter:

![Launcher: calculator](docs/screenshots/05-launcher-calc.png)

Launcher in web-search mode (`?` prefix) — opens DuckDuckGo on Enter:

![Launcher: web search](docs/screenshots/06-launcher-web.png)

Launcher in emoji mode (`;` prefix or Mod+;) — copies the glyph on Enter:

![Launcher: emoji](docs/screenshots/07-launcher-emoji.png)

Clipboard history (Mod+V) — text + image previews, hover-revealed delete:

![Clipboard popup](docs/screenshots/08-clipboard.png)

---

## Status

Personal config shared as a reference. Primary development setup:
**Arch Linux · niri 26.04 · Quickshell 0.2.1 · Qt 6.11**. Hyprland and
Sway support is implemented but tested less extensively; report any
breakage. Pre-1.0 Quickshell APIs may break between versions.

Built largely with the assistance of an LLM. Bug reports especially
welcome — a second pair of eyes from real users on Hyprland and Sway
will catch things our test pass on niri couldn't.

---

## Known limitations

- **Sway / i3**: keyboard-layout OSD silently never triggers — i3/Sway's
  IPC has no layout-changed event. Other OSDs (volume, brightness,
  caps/num lock) work normally.
- **Locking on suspend** is the one piece of idle handling still done
  outside the shell — catching it means listening for logind's
  `PrepareForSleep` DBus signal, and Quickshell has no generic DBus
  client. Ship `examples/quickshell-lock.service` if you want it.
  Inactivity timeouts, locking and screen blanking are all native now
  (see [Idle handling](#idle-handling)).
- **Screen blanking needs a supported compositor.** Hyprland, niri and
  Sway are wired up via `Compositor.dispatchDpms()`; on i3 (X11) and the
  stub backend the blank stage is a silent no-op and only the lock stage
  runs.
- **Polkit agent**: not provided. Use `hyprpolkitagent` /
  `polkit-kde-authentication-agent-1` / etc.
- **Hyprland & Sway are lightly tested.** Edge cases possible around
  named workspaces (Hyprland), multi-monitor focus tracking, and
  per-window event payloads. Bug reports very welcome.

---

## Dependencies

### Required

| Arch package           | Purpose                                         |
|------------------------|-------------------------------------------------|
| `quickshell` (AUR)     | The QML shell framework (≥ 0.3.0 — `IdleMonitor`) |
| One of: `niri` / `hyprland` / `sway` | Wayland compositor                |
| `qt6-base`             | ≥ 6.5 for `MultiEffect` (used by lock blur)     |
| `qt6-declarative`      | QML runtime                                     |
| `noto-fonts-emoji`     | Or any color-emoji font                         |
| `wl-clipboard`         | `wl-copy` for launcher's calc/emoji copy        |
| `cliphist`             | Backend for the clipboard history popup         |
| `brightnessctl`        | Backlight control (laptops only)                |
| `curl`                 | Used by the weather widget to fetch Open-Meteo  |
| Linux PAM              | Standard on any modern distro                   |

### Optional

| Arch package    | What it enables                                                        |
|-----------------|------------------------------------------------------------------------|
| `libcanberra`   | KDE-style audible cue on volume change / unmute. Plays the freedesktop `audio-volume-change` sample through the just-changed sink, so its loudness mirrors the new level. Disable via `volumeFeedbackEnabled: false` in `Theme.qml`. |
| `sound-theme-freedesktop` | Provides the actual `audio-volume-change` sample that `libcanberra` plays. Without it, canberra silently no-ops. |

---

## Installation

### 1. Clone the repo

```bash
git clone https://github.com/<you>/quickshell-bar ~/.config/quickshell/quickshell-bar
```

(Or anywhere else — substitute the path in the keybind snippets below.)

### 2. Install the PAM service file (root, one-time)

The lock screen needs its own PAM stack:

```bash
sudo install -m 644 /dev/stdin /etc/pam.d/qslock <<< 'auth include login'
```

Verify:

```bash
cat /etc/pam.d/qslock          # → auth include login
```

### 3. Wire it into your compositor

Sample configs are in `examples/` — copy the relevant snippet, replace
`/path/to/quickshell-bar` with your clone path, and reload your
compositor's config.

#### niri
Copy `examples/niri-config.kdl` into `~/.config/niri/config.kdl`. niri
auto-reloads on save.

#### Hyprland
Copy `examples/hyprland-bindings.conf` into `~/.config/hypr/hyprland.conf`
(or `source = ` it). Hyprland auto-reloads on save.

#### Sway / i3
Copy `examples/sway-bindings.conf` into `~/.config/sway/config` (or i3's
config). Reload with `swaymsg reload` / `i3-msg reload`.

### 4. (Optional) Lock on suspend

Idle timeouts need no setup — the shell locks at 5 min and blanks the
screens at 6 min out of the box. See [Idle handling](#idle-handling) to
change or disable that.

Locking *on suspend* is separate, because it hangs off logind rather
than off inactivity. If you want it:

```sh
mkdir -p ~/.config/systemd/user
sed "s|/path/to/quickshell-bar|$PWD|" examples/quickshell-lock.service \
    > ~/.config/systemd/user/quickshell-lock.service
systemctl --user daemon-reload
systemctl --user enable quickshell-lock.service
```

---

## Idle handling

Inactivity is watched in-shell via `ext-idle-notifier-v1`
(`qs.system`'s `IdleService`). There is no idle daemon to install and no
second config file to keep in sync — both stages are ordinary keys in
`config.jsonc`, and both are also sliders on the Settings page's
**Behaviour** tab:

| Key | Default | Meaning |
|-----|---------|---------|
| `idleLockSeconds` | `300` | Seconds of inactivity before the session locks. `0` disables. |
| `idleDpmsSeconds` | `360` | Seconds before the monitors blank. `0` disables. |

Both stages are driven by a single `IdleMonitor` armed at the earlier of
the two timeouts; the later stage runs off a delay measured from there.
Any activity cancels pending stages and wakes the monitors — it does
**not** unlock, since waking a screen isn't authentication.

`respectInhibitors` is on, so anything holding `idle-inhibit-v1` — mpv,
browsers playing video, Steam — suppresses both stages automatically.

Runtime control:

```sh
qs ipc call idle status     # what's armed, and are we idle right now
qs ipc call idle disable    # stay awake (same as the Caffeine tile)
qs ipc call idle enable
qs ipc call idle toggle
qs ipc call idle blank      # blank the screens now
```

The Control Center's **Caffeine** tile is the GUI for the same switch.
It additionally holds a `systemd-inhibit` against logind's suspend timer
and lid switch, which are systemd's business rather than the shell's.

---

## Keybinds

| Keybind         | Action                                  |
|-----------------|-----------------------------------------|
| `Mod+P`         | App launcher                            |
| `Mod+;`         | Launcher pre-filled into emoji mode     |
| `Mod+V`         | Clipboard history                       |
| `Mod+Shift+X`   | Lock session                            |

### Launcher prefixes

| Prefix | Mode                | Example         | On Enter                       |
|--------|---------------------|-----------------|--------------------------------|
| (none) | Apps                | `firefox`       | Launches the app               |
| `=`    | Calculator          | `=2+3*4`        | Copies result (`14`) via `wl-copy` |
| `?`    | Web search          | `?how to foo`   | `xdg-open` the search URL      |
| `;`    | Emoji               | `;heart`        | Copies the emoji char          |

### Lock surface

| Key      | Action                                 |
|----------|----------------------------------------|
| (typing) | Enter password                         |
| `Enter`  | Submit                                 |
| `Esc`    | Clear field                            |

---

## Lock screen recovery

`WlSessionLock` is **secure by design**: if `qs` crashes while locked, the
screen STAYS locked (compositor enforces this — it's the Wayland
`ext-session-lock-v1` guarantee). To unlock without a working shell:

```
Ctrl+Alt+F2                                # switch to TTY 2
<login at TTY>
loginctl unlock-session $XDG_SESSION_ID
Ctrl+Alt+F1                                # back to graphical
```

Rehearse this once before you ever need it for real.

---

## Customization

### Per-machine overrides (no edits to tracked files)

Two ways to edit, both writing to the same `~/.config/quickshell-bar/config.jsonc`:

**Visual editor** — open the Control Center, click the gear icon in the
header (or run `qs ipc call settings open` for a keybind). Tabs for
Colours / Typography / Layout & Motion / Behaviour with sliders,
hex-input + colour picker, dropdowns. Live preview; auto-saves after
500 ms of idle. First save per session creates `config.jsonc.bak`.

**Hand-edit** the JSONC file directly. Hot-reloaded on save; missing
keys keep their defaults; `//` and `/* */` comments allowed.

Fastest path for hand-editing — copy the bundled example (every key at
its current default, so an unmodified copy changes nothing) and edit
what you want:

```bash
mkdir -p ~/.config/quickshell-bar
cp examples/config.jsonc ~/.config/quickshell-bar/config.jsonc
```

Or write a minimal one with just your overrides:

```jsonc
{
  // Tokyo Night-inspired accent
  "accent": "#7aa2f7",
  "fontMono": "JetBrains Mono Nerd Font",
  "barHeight": 36,

  // Switch web search to DuckDuckGo
  "searchUrl": "https://duckduckgo.com/?q=%s",
  "searchName": "DuckDuckGo",

  // Quieter shell
  "volumeFeedbackEnabled": false
}
```

See [`docs/CUSTOMIZATION.md`](docs/CUSTOMIZATION.md) for the full
reference of all 33 overridable keys (Theme tokens, fonts, sizes,
animations, launcher search engine).

### Things that still require touching tracked files

| What                   | Where                                                             |
|------------------------|-------------------------------------------------------------------|
| Colors, sizes, radii   | Override per-machine via `config.json` above (see CUSTOMIZATION.md). Defaults live in `Theme.qml`. |
| Web-search engine      | Override per-machine via `config.json` (`searchUrl` / `searchName`). |
| Wallpaper folder       | Open the Control Center (sliders icon, just before Power) → click the **Wallpaper** tile → folder browser opens. Use the up-arrow / subfolder pills to navigate. Persisted to `~/.local/state/quickshell/by-shell/<id>/wallpaper.json`. |
| Weather location       | Open the Control Center → click the weather card body → "Choose city" view opens with 25 NL cities. Persisted to `~/.local/state/quickshell/by-shell/<id>/weather.json`. |
| Idle lock / screen-blank timings | `idleLockSeconds` / `idleDpmsSeconds` in `config.jsonc`, or the Settings page's Behaviour tab. See [Idle handling](#idle-handling). |
| Compositor keybinds    | `examples/<compositor>-bindings.<ext>`                            |
| Force-pick a backend   | `QS_COMPOSITOR=niri\|hyprland\|sway\|stub` env var                |

---

## Architecture

- **Subdir = QML module.** Each subdirectory under the project root is automatically a `qs.<subdir>` module.
- **Singleton service + visual component split.** Every popup splits state (`*Service.qml` singleton) from rendering (`*Popup.qml`/`*.qml`). Easy to test, trivial to restyle.
- **PopupController mutex.** `PopupController.qml` is a root singleton; only one popup is open at a time, all participate via `PopupController.open(self, closer)` / `PopupController.closed(self)`.
- **IPC-only triggering.** All keybinds spawn `qs ipc call <target> <fn>` instead of separate processes — single source of truth, hot-reload safe.
- **Per-screen panels with focused-output gating.** `visible: !!Service.popupOpen && isFocusedScreen` prevents init-race flashes.
- **Compositor abstraction in `compositor/`.** A `Compositor` singleton auto-detects the running compositor (`niri` / `hyprland` / `sway` / `i3`) and instantiates the matching `Backend*.qml` adapter. The rest of the shell only knows about `Compositor.workspaces`, `Compositor.focusedOutput`, etc. Adding a new compositor is a single file.
- **Frecency persistence in `Quickshell.statePath()`.** Per-shell JSON files under `~/.local/state/quickshell/by-shell/<id>/`.

---

## Project layout

```
.
├── shell.qml                 — entry point; instantiates everything per-screen
├── Bar.qml                   — bar chrome (per-monitor PanelWindow)
├── Theme.qml                 — palette + sizing singleton
├── PopupController.qml       — mutex for popups
│
├── compositor/               — cross-compositor abstraction layer
│   ├── Compositor.qml        — singleton: auto-detects + delegates to backend
│   ├── BackendNiri.qml       — niri IPC bridge
│   ├── BackendHyprland.qml   — Quickshell.Hyprland adapter
│   ├── BackendSway.qml       — Quickshell.I3 adapter (Sway / i3)
│   └── BackendStub.qml       — no-op fallback for unknown compositors
│
├── workspaces/Workspaces.qml — workspace chip strip (consumes Compositor)
├── clock/                    — clock widget + calendar popup
├── notifications/            — NotificationServer + cards + center popup
├── osd/                      — volume / brightness / layout overlay
├── network/                  — NM service + NetworkView (embedded in CC)
├── bluetooth/                — BT helpers + BluetoothView (embedded in CC)
├── volume/                   — volume widget + mixer popup (incl. per-app)
├── media/                    — MPRIS widget + media popup
├── system/                   — battery, brightness, power menu, PowerProfileView
├── tray/                     — StatusNotifierHost + tray menus
│
├── controlcenter/            — drawer hosting moved widgets (Wi-Fi/BT/Profile/Caffeine/DND/Wallpaper)
├── weather/                  — weather widget (KNMI via Open-Meteo)
├── clipboard/                — clipboard history (Mod+V), cliphist-backed
├── launcher/                 — app launcher (Mod+P): apps / calc / web / emoji
│   └── emoji.json            — bundled gemoji catalog (MIT — see NOTICE)
├── wallpaper/                — wallpaper renderer + picker (replaces swaybg + waypaper)
├── lock/                     — WlSessionLock + PAM (Mod+Shift+X)
│
├── examples/                 — copy-pasteable compositor configs
│   ├── niri-config.kdl
│   ├── hyprland-bindings.conf
│   ├── sway-bindings.conf
│   └── quickshell-lock.service   — lock-on-suspend systemd user unit
│
├── docs/AGENTS.md            — orientation for contributors and AI agents
├── docs/STYLE.md             — visual + structural conventions
├── docs/QUICKSHELL_REFERENCE.md  — annotated Quickshell reference + 60+ gotchas
├── docs/screenshots/         — gallery referenced in this README
├── NOTICE                    — third-party attribution
├── LICENSE                   — MIT
└── README.md                 — this file
```

---

## What's deliberately NOT replaced

| External tool       | Why it stays                                                                                     |
|---------------------|--------------------------------------------------------------------------------------------------|
| `hyprpolkitagent`   | No polkit replacement yet (~2 h follow-up if desired).                                           |
| `udiskie`, `kwalletd6`, etc. | Out of shell scope by design (USB mount, secret store, etc.).                          |

---

## Documentation

| Doc | Purpose |
|---|---|
| [`README.md`](README.md) (this file) | Install, dependencies, customization, project overview |
| [`docs/AGENTS.md`](docs/AGENTS.md) | Orientation for contributors and AI agents — start here for "where things live", architecture, common tasks, AI-specific traps |
| [`docs/STYLE.md`](docs/STYLE.md) | Visual + structural conventions: theme tokens, popup recipe, naming, glyph index, smoke-test pattern |
| [`docs/QUICKSHELL_REFERENCE.md`](docs/QUICKSHELL_REFERENCE.md) | Annotated Quickshell API reference + **60+ gotchas** accumulated from real bugs while building this shell |
| [`examples/`](examples/) | Copy-pasteable compositor + idle-daemon configs (niri, Hyprland, Sway) |

---

## Project status

- **Personal config**, not actively soliciting contributions.
- Bug reports welcome via GitHub Issues.
- PRs may or may not be merged depending on scope and direction.
- Pinned to Quickshell 0.2.1 — pre-1.0 APIs may break.

---

## Credits

- [**Quickshell**](https://quickshell.org/) ([source](https://git.outfoxxed.me/outfoxxed/quickshell)) — the QML-based shell framework. `docs/QUICKSHELL_REFERENCE.md` is a derivative of upstream Quickshell documentation.
- [**github/gemoji**](https://github.com/github/gemoji) — emoji metadata bundled at `launcher/emoji.json`. MIT-licensed; full attribution in [`NOTICE`](NOTICE).
- [**niri**](https://github.com/YaLTeR/niri) — the scrollable-tiling Wayland compositor this shell was originally built on.
- [**Hyprland**](https://hyprland.org/) — supported via `Quickshell.Hyprland`.
- [**Sway**](https://swaywm.org/) — supported via `Quickshell.I3`.
- An LLM coding collaborator — most QML and docs in this repo were written under human direction and review with LLM assistance.

---

## License

Released under the MIT License — see [`LICENSE`](LICENSE). Fork, modify,
ship — no credit required.
