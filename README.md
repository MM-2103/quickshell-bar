# quickshell-bar

A complete personal Wayland desktop shell built on
[Quickshell](https://quickshell.org/), with first-class support for
**niri**, **Hyprland**, and **Sway / i3** out of the box.

Replaces (in one configurable QML codebase):
**waybar** · **swaync / mako / dunst** · **swayosd** ·
**nm-applet** · **blueman-applet** · **KDE media controls** ·
**wlogout** · **fuzzel** · **hyprlock**.

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
- Notification collapser
- Network · Bluetooth · Volume · MPRIS media controls
- Power profile · Power menu · Idle inhibitor toggle
- System tray (StatusNotifierHost)

**Popups** (mutex-managed; auto-dismiss on app focus)
- Volume mixer · Network picker · Bluetooth picker
- Notification center
- Power profile / power menu
- Calendar · Media · Tray menus
- Clipboard history (Mod+V) — image-thumbnail aware
- App launcher (Mod+P) — apps + calculator + web search + emoji
- Emoji picker shortcut (Mod+;)

**Notifications & OSD**
- Native NotificationServer (replaces external daemons)
- Per-monitor pinned cards
- Volume / brightness / keyboard-layout OSDs

**Session lock** (Mod+Shift+X)
- `WlSessionLock` + PAM auth via `/etc/pam.d/qslock`
- Blurred wallpaper background (auto-detected from waypaper)
- Multi-monitor surfaces, persistent error state, dim-while-validating
- Hot-reload safe (survives `qs` config reloads)
- `LockedHint` propagation to systemd-logind

---

## Status

Personal config shared as a reference. Primary development setup:
**Arch Linux · niri 26.04 · Quickshell 0.2.1 · Qt 6.11**. Hyprland and
Sway support is implemented but tested less extensively; report any
breakage. Pre-1.0 Quickshell APIs may break between versions.

---

## Dependencies

### Required

| Arch package           | Purpose                                         |
|------------------------|-------------------------------------------------|
| `quickshell` (AUR)     | The QML shell framework (≥ 0.2.1)               |
| One of: `niri` / `hyprland` / `sway` | Wayland compositor                |
| `qt6-base`             | ≥ 6.5 for `MultiEffect` (used by lock blur)     |
| `qt6-declarative`      | QML runtime                                     |
| `noto-fonts-emoji`     | Or any color-emoji font                         |
| `wl-clipboard`         | `wl-copy` for launcher's calc/emoji copy        |
| `cliphist`             | Backend for the clipboard history popup         |
| `brightnessctl`        | Backlight control (laptops only)                |
| Linux PAM              | Standard on any modern distro                   |

### Optional

| Arch package    | What it enables                                                        |
|-----------------|------------------------------------------------------------------------|
| `waypaper`      | Lock screen reads `~/.config/waypaper/config.ini` for blur background. Without it, lock falls back to a solid background. |
| `hypridle` *(niri / Hyprland)* | Idle daemon. Triggers our lock IPC on timeout / before-suspend. Quickshell has no built-in idle notifier yet, so this stays external. See `examples/hypridle.conf`. |
| `swayidle` *(Sway / i3)*       | Equivalent idle daemon. See `examples/swayidle.service` for the command snippet. |

---

## Installation

### 1. Clone the repo

```bash
git clone https://github.com/<you>/quickshell-bar ~/.config/quickshell/quickshell-bar
```

(Or anywhere else — substitute the path in the niri / hypridle snippets below.)

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

### 4. (Optional) Wire an idle daemon for lock + DPMS

Pick the daemon for your compositor:

- **Hyprland / niri** → `hypridle`. Sample at `examples/hypridle.conf`.
  Restart with `pkill hypridle && setsid hypridle </dev/null >/dev/null 2>&1 &`.
- **Sway / i3** → `swayidle`. Sample command at `examples/swayidle.service`.
  Add to your Sway autostart (`exec swayidle ...`).

Both samples lock at 5 min, DPMS off at 5.5 min, and lock before suspend.

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

| What                   | Where                                                             |
|------------------------|-------------------------------------------------------------------|
| Colors, sizes, radii   | `Theme.qml` — single source of truth                              |
| Web-search engine      | `searchUrl` and `searchName` constants at top of `launcher/LauncherService.qml` (defaults to DuckDuckGo) |
| Lock-screen wallpaper  | `lock/LockService.qml` — `_refreshWallpaper()` reads `~/.config/waypaper/config.ini`; edit to change source |
| Idle / dim / suspend timings | `~/.config/hypr/hypridle.conf` or `swayidle` invocation (see `examples/`) |
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
├── network/                  — NM widget + connection picker
├── bluetooth/                — BT widget + device picker
├── volume/                   — volume widget + mixer popup (incl. per-app)
├── media/                    — MPRIS widget + media popup
├── system/                   — power profile / menu / idle inhibitor / battery / brightness
├── tray/                     — StatusNotifierHost + tray menus
│
├── clipboard/                — clipboard history (Mod+V), cliphist-backed
├── launcher/                 — app launcher (Mod+P): apps / calc / web / emoji
│   └── emoji.json            — bundled gemoji catalog (MIT — see NOTICE)
├── lock/                     — WlSessionLock + PAM (Mod+Shift+X)
│
├── examples/                 — copy-pasteable compositor + idle-daemon configs
│   ├── niri-config.kdl
│   ├── hyprland-bindings.conf
│   ├── sway-bindings.conf
│   ├── hypridle.conf
│   └── swayidle.service
│
├── docs/QUICKSHELL_REFERENCE.md  — annotated Quickshell reference + 60+ gotchas
├── NOTICE                    — third-party attribution
└── README.md                 — this file
```

---

## What's deliberately NOT replaced

| External tool       | Why it stays                                                                                     |
|---------------------|--------------------------------------------------------------------------------------------------|
| `hypridle`          | Quickshell lacks `ext-idle-notifier-v1` client. Future direction: replace via systemd-logind DBus. |
| `swaybg`            | No wallpaper component yet. Planned future addition.                                             |
| `waypaper`          | Wallpaper picker UI lives outside; same future direction would replace.                          |
| `hyprpolkitagent`   | No polkit replacement yet (~2 h follow-up if desired).                                           |
| `udiskie`, `kwalletd6`, etc. | Out of shell scope by design (USB mount, secret store, etc.).                          |

---

## Documentation

Internal reference at [`docs/QUICKSHELL_REFERENCE.md`](docs/QUICKSHELL_REFERENCE.md) — a comprehensive Quickshell guide annotated with **60+ gotchas** accumulated from real bugs while building this shell. Useful for anyone writing their own Quickshell config. Style + repo conventions for this project are in [`docs/STYLE.md`](docs/STYLE.md).

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

---

## License

*See `LICENSE` (TBD — to be added before publishing widely).*
