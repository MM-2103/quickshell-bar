# Style & Conventions

Single source of truth for the visual + structural conventions used
throughout this repo. New components / popups / widgets should follow
these patterns to keep the shell visually and architecturally consistent.

If you find yourself wanting to deviate, document why in a comment and
flag it in your commit message — the next contributor (or future-you)
will thank you.

> See also: [`QUICKSHELL_REFERENCE.md`](QUICKSHELL_REFERENCE.md) for
> Quickshell API reference and 60+ gotchas accumulated from real bugs.

---

## Theme tokens (the only allowed magic numbers)

Every color, size, and animation duration goes through `Theme.qml`.
Inline hex / pixel values are a **code-review smell** — replace with the
matching token, OR add a new token and document it in `Theme.qml`.

### Colors

| Token | Hex | Use for |
|---|---|---|
| `Theme.bg` | `#16181c` | Bar / popup base background |
| `Theme.surface` | `#1e1e22` | Hover state, mild elevation |
| `Theme.surfaceHi` | `#26262a` | Pinned / pressed state, elevated card |
| `Theme.border` | `#2a2a2e` | 1 px borders, dividers |
| `Theme.text` | `#fcfcfc` | Primary text + active icons |
| `Theme.textDim` | `#909090` | Secondary text, dim icons |
| `Theme.textMuted` | `#5e5e5e` | Very subtle (separators, weekend dates) |
| `Theme.accent` | `#ffffff` | Focused workspace, today, slider thumb |
| `Theme.accentText` | `#16181c` | Text on top of accent fill |
| `Theme.error` | `#ff5050` | Error borders, low-battery glyph |
| `Theme.errorBright` | `#ff7070` | Error text on dark backgrounds |

**Rule of thumb**: backgrounds elevate from bg → surface → surfaceHi.
Text dimmability goes text → textDim → textMuted. Never use raw hex
for any of these — if your case isn't covered, add a token.

### Fonts

| Token | Resolves to | Use for |
|---|---|---|
| `Theme.fontMono` | `Iosevka Nerd Font` | All shell text — date, time, labels, workspace numbers, tooltips |
| `Theme.fontIcon` | `Font Awesome 7 Free` (Solid) | Every monochrome glyph icon |
| `Theme.fontBrand` | `Font Awesome 7 Brands` | Brand sigils (Bluetooth) |

**Always set `font.family` explicitly** on every `Text` element. Without
it, Qt falls back to the system default sans (DejaVu / Noto Sans), which
clashes hard with the rest of the shell. See gotcha #45 in the reference
doc for why this matters.

For Font Awesome glyphs, also set:
```qml
font.styleName: "Solid"        // for fontIcon; "Regular" for fontBrand
renderType: Text.NativeRendering
```

### Font sizes (5-step scale)

| Token | Pixels | Use for |
|---|---|---|
| `Theme.fontSizeBadge` | 9 | Notification count, signal-strength overlay |
| `Theme.fontSizeSmall` | 11 | Tooltips, secondary text, dim labels |
| `Theme.fontSizeNormal` | 13 | Body text, workspace numbers, date, time |
| `Theme.fontSizeLarge` | 15 | Section headers in popups |
| `Theme.fontSizeXL` | 17 | Standout labels (rare) |

**Off-scale sizes are allowed for very specific cases**: the lock-screen
clock at 144 px, the Calendar header arrows. Comment why.

### Geometry

| Token | Pixels | Use for |
|---|---|---|
| `Theme.barHeight` | 32 | Top bar height (one source) |
| `Theme.radius` | 6 | Popup outer corners |
| `Theme.radiusSmall` | 4 | Bar widget hover pill, slider track ends, button corners |
| `Theme.iconSize` | 13 | Default Font Awesome glyph size in 22 × 22 widgets |

### Animations

| Token | ms | Use for |
|---|---|---|
| `Theme.animFast` | 100 | Color transitions on hover (icons, backgrounds) |
| `Theme.animMed` | 140 | Slightly more deliberate transitions (workspace chips) |

Popup fade-in / fade-out has its own constant: **150 ms `Easing.OutCubic`**
with a 4 px slide-up. See "Popup recipe" below.

---

## Bar widget anatomy

Every right-cluster bar widget follows the same skeleton:

```qml
MouseArea {
    id: root

    implicitWidth: 22                            // standard hit area
    implicitHeight: 22
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton               // | Qt.MiddleButton | Qt.RightButton when used

    onClicked: popup.toggle()                    // most widgets toggle a popup

    // Hover / active background pill — uniform across the cluster.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: popup.visible
            ? Theme.surfaceHi
            : (root.containsMouse ? Theme.surface : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // The glyph — Font Awesome via the BarIcon helper.
    BarIcon {
        anchors.centerIn: parent
        glyph: "\uf0f3"                          // bell
    }

    // Optional tooltip — see "Tooltip recipe" below.
    BarTooltip {
        anchorItem: root
        show: root.containsMouse && !popup.visible
        text: "Notifications"
    }

    // Companion popup, if any.
    SomePopup {
        id: popup
        anchorItem: root
    }
}
```

**Hard-and-fast rules**:

- **22 × 22 hit area** for every bar widget. Exceptions need a comment.
- **Hover Rectangle is identical across widgets** — copy-paste the snippet.
- **`BarIcon` for monochrome glyphs**, never inline `Text { font.family: "Font Awesome..." }`.
- **Tooltip drives off `containsMouse && !popup.visible`** so the tooltip vanishes when the popup opens.
- **Use `Brightness.qml` / `Battery.qml` as templates** for "may-be-hidden" widgets — they collapse to `width: 0` when their data source is absent (`!OsdService.hasBrightness` / `!UPower.displayDevice.isPresent`).

---

## Popup recipe (animated)

Every `PopupWindow` and free-floating `PanelWindow` in this repo follows
the same fade-in / shadow / shape contract.

```qml
PopupWindow {
    id: popup
    color: "transparent"

    // Fade-aware visibility.
    property bool wantOpen: false
    visible: wantOpen || hideHold.running
    Timer { id: hideHold; interval: 180; repeat: false }
    onWantOpenChanged: {
        if (wantOpen) hideHold.stop();
        else          hideHold.restart();
    }

    function toggle() {
        if (popup.wantOpen) {
            popup.wantOpen = false;
        } else {
            PopupController.open(popup, () => popup.wantOpen = false);
            popup.wantOpen = true;
        }
    }
    onVisibleChanged: if (!visible) PopupController.closed(popup)

    // Surface adds 24 px in each axis for shadow padding.
    implicitWidth: 320 + 24
    implicitHeight: container.implicitHeight + 24

    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? -((popup.width - anchorItem.width) / 2) : 0
    anchor.rect.y: anchorItem ? anchorItem.height + 6 - 12 : 0   // -12 compensates the shadow padding
    anchor.adjustment: PopupAdjustment.SlideX

    Rectangle {
        id: container
        anchors.fill: parent
        anchors.margins: 12                          // shadow padding
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

        // Snappy fade-in + 4 px slide-up.
        opacity: popup.wantOpen ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        transform: Translate {
            y: popup.wantOpen ? 0 : 4
            Behavior on y {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }

        // Drop shadow for depth + masks the rounded-corner-on-wallpaper
        // "torn corners" appearance on dark wallpapers.
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
            shadowBlur: 0.6
        }

        // ... popup content here ...
    }
}
```

**Required imports**: `import QtQuick; import QtQuick.Effects; import Quickshell; import qs`

**Why each part exists**:

- **`wantOpen` + `hideHold` Timer**: `PopupWindow` is a real Wayland surface; `visible: false` unmaps instantly, cutting the fade tween. The 180 ms hold keeps it mapped while the 150 ms fade plays. See gotcha #56.
- **`+24` size + `anchors.margins: 12`**: gives the drop shadow room to render outside the visible body.
- **`-12` on `anchor.rect.y`**: compensates so the body still lands 6 px below the bar widget (which is what the bar visually expects).
- **Drop shadow values are universal**: opacity 0.5, vOffset 4, hOffset 0, blur 0.6. Never tune these per-popup; consistency matters.

For hover-driven popups (Calendar etc.), add a "linger" timer per gotcha #57.

---

## Tooltip recipe

Use the `BarTooltip` helper for all bar widgets:

```qml
BarTooltip {
    anchorItem: root              // typically the widget's MouseArea
    show: root.containsMouse && !popup.visible
    text: "..."                   // dynamic text is fine
    delay: 350                    // optional; default is 350 ms
}
```

Tooltip text:

- **Verb-first or noun-first, sentence case** ("Volume 75%", "Bluetooth: 2 devices connected", "Keep system awake: ON")
- **Include current state numerically** when relevant (battery %, signal %)
- **Hide when the popup is open** (`!popup.visible`) — redundant info while the popup is showing the same state
- **Use mono font implicitly** — BarTooltip already sets `font.family: Theme.fontMono`

---

## Sliders & progress bars

Two shared components live at the repo root: `Slider.qml` (interactive)
and `ProgressBar.qml` (passive). Use these everywhere instead of
hand-rolling Rectangle stacks.

### Interactive slider

```qml
Slider {
    width: 160
    value: someService.ratio          // 0..1
    dimmed: someService.muted         // greys the fill
    enabled: someService.ready
    onUserChanged: v => someService.setRatio(v)
}
```

**Standard size**: 4 px track, 12 px round thumb. `Slider` enforces this;
don't hand-tune.

### Passive progress bar

```qml
ProgressBar {
    width: 160
    value: brightnessRatio
    lowAt: 0.20                       // optional; turns fill `Theme.error` below this
}
```

Used by the OSD overlays and any read-only fill. **No thumb**, just a
4 px filled bar.

---

## Glyph conventions (Font Awesome)

This shell uses Font Awesome 7 Solid for nearly every icon. Codepoints
referenced (kept in sync with the shell's actual usage):

### Bar widgets

| Glyph | Codepoint | Used in |
|---|---|---|
| Bell / bell-slash | `\uf0f3` / `\uf1f6` | `notifications/Notifications.qml` |
| Mug-saucer / mug-hot | `\uf0f4` / `\uf7b6` | `system/IdleInhibit.qml` |
| Music | `\uf001` | `media/Media.qml` |
| Power-off | `\uf011` | `system/Power.qml` |
| Sun (brightness) | `\uf185` | `system/Brightness.qml` |
| Volume xmark / low / high | `\uf6a9` / `\uf027` / `\uf028` | `volume/Volume.qml`, `osd/Osd.qml` |
| WiFi / ethernet / link-slash | `\uf1eb` / `\uf796` / `\uf127` | `network/Network.qml` |
| Bluetooth (Brands) | `\uf293` | `bluetooth/Bluetooth.qml` |
| Battery full → empty | `\uf240` → `\uf244` | `system/Battery.qml`, `bluetooth/BluetoothPopup.qml` |
| Bolt (charging) | `\uf0e7` | `system/Battery.qml`, `system/PowerProfile.qml` |
| Leaf / gauge / bolt (power profile) | `\uf06c` / `\uf624` / `\uf0e7` | `system/PowerProfile.qml` |

### Popup chrome

| Glyph | Codepoint | Used in |
|---|---|---|
| Xmark (close, forget) | `\uf00d` | network, bluetooth, notifications popups |
| Chevron-left / right | `\uf053` / `\uf054` | calendar, tray menu, media popup, tray collapser |
| Plus / minus | `\uf067` / `\uf068` | network hidden form |
| Lock | `\uf023` | network secured indicator, power menu |
| Trash-can | `\uf014` | clipboard delete |
| Image / font | `\uf03e` / `\uf031` | clipboard kind glyph |
| Arrows-rotate | `\uf021` | network rescan, bluetooth scan, power menu reboot |
| Moon | `\uf186` | power menu suspend |
| Right-from-bracket | `\uf2f5` | power menu logout |
| Keyboard | `\uf11c` | OSD layout |
| Arrow-up / hashtag | `\uf062` / `\uf292` | OSD caps lock / num lock |

### Power menu (transport-button style)

`\uf048` backward-step, `\uf04b` play, `\uf04c` pause, `\uf051` forward-step

**Adding a new icon**: verify the codepoint exists in `/usr/share/fonts/OTF/Font Awesome 7 Free-Solid-900.otf` (or Brands) before wiring it in. The `fontTools.ttLib` Python pattern from earlier sessions works:

```bash
python3 -c "
from fontTools.ttLib import TTFont
f = TTFont('/usr/share/fonts/OTF/Font Awesome 7 Free-Solid-900.otf')
for cp, name in sorted(f.getBestCmap().items()):
    if 'YOUR_KEYWORD' in name.lower():
        print(f'  U+{cp:04X} -> {name}')
"
```

Always pick the **private-use codepoint** (U+E000-U+F8FF range), never the
unicode-base codepoint that some glyphs also map to (those alias to
Noto Color Emoji on most Linux setups).

---

## File organization & naming

### Directory layout

| Path | Contents |
|---|---|
| `<root>/*.qml` | Top-level types: `Bar.qml`, `Theme.qml`, helpers (`BarIcon`, `BarTooltip`, `Slider`, `ProgressBar`), `PopupController.qml`, `shell.qml` |
| `<root>/<subdir>/` | Per-feature directory; auto-becomes a `qs.<subdir>` module |
| `<root>/<subdir>/*Service.qml` | `pragma Singleton` — shared state, no UI |
| `<root>/<subdir>/<Feature>.qml` | The bar widget OR top-level visible component |
| `<root>/<subdir>/<Feature>Popup.qml` | Companion popup |
| `<root>/<subdir>/<Feature>Card.qml` | Embeddable card sub-component |
| `<root>/compositor/` | Compositor abstraction (singleton + per-backend files) |
| `<root>/examples/` | Copy-pasteable user configs (compositor keybinds, idle-daemon snippets) |
| `<root>/docs/` | Reference + style docs |

### Naming

- **PascalCase QML file** = a type that can be instantiated. `Bar.qml` → `Bar { }`.
- **`*Service.qml` suffix** = `pragma Singleton`. `MediaService`, `NotificationService`, `LockService`, `OsdService`, `LauncherService`, `ClipboardService`, `NetworkService`, `SystemMonitorService` (when added).
- **`*Popup.qml` suffix** = a `PopupWindow` triggered by a sibling widget.
- **`*Card.qml` suffix** = an embeddable visual unit (e.g. `NotificationCard`, `NowPlayingCard`).
- **`Backend*.qml`** lives in `compositor/` and conforms to the `Compositor` singleton's interface.
- **Avoid `_`-prefixed properties** unless they're truly private. QML signal handlers (`on_PropertyChanged`) work but are visually noisy.
- **Avoid lowercase QML filenames** unless you're writing a JS module (which is rare).

### File header comment

Every QML file should start with a 1-3 line top comment explaining what
it does and how it integrates. Standard format:

```qml
// Filename.qml
// One-line description. What does this do? When is it used?
//
// Optional: relevant gotchas / caveats / extra context.

import QtQuick
// ...
```

For singletons (`pragma Singleton`), the `pragma` MUST be line 1 — the
header comment goes BELOW it. **The header comment must NOT contain
`{` or `}` characters** (gotcha #45 — qmlscanner gets confused).

---

## Compositor abstraction

When working on anything that touches per-compositor state (workspaces,
focused output, current keyboard layout, window-focus events, dispatch
commands), go through the `Compositor` singleton:

```qml
import qs.compositor

// Reading state:
Compositor.workspaces                // array of {id, idx, output, is_focused, is_active, name}
Compositor.focusedOutput             // string (monitor name)
Compositor.currentLayout             // string (empty on Sway / i3)

// Reacting to events:
Connections {
    target: Compositor
    function onWindowFocused(id) { /* dismiss popups etc. */ }
    function onCurrentLayoutChanged() { OsdService.show("layout"); }
}

// Dispatching:
Compositor.dispatchFocusWorkspace(idx)
Compositor.dispatchLogout()
```

**Never reference compositor-specific globals directly** (`Hyprland.*`,
`I3.*`, `niri msg ...`) outside of the `compositor/Backend*.qml` files.
That's the whole point of the abstraction.

To add a new compositor (river, Wayfire, Cosmic, …):

1. Create `compositor/Backend<Name>.qml` exposing the same interface as
   the existing backends (workspaces, focusedOutput, currentLayout,
   windowFocused signal, dispatchFocusWorkspace, dispatchLogout).
2. Add a detection branch + Component declaration in `Compositor.qml`.
3. Drop a sample keybind config into `examples/`.
4. Test on the target compositor; update gotcha #59 if you hit any
   edge cases.

---

## Comment style

- **Files**: top comment explains purpose + integration in 1-3 lines (see above).
- **Sections**: separate logical regions of a long file with a `// ---- Section name ----` divider.
- **Gotchas inline**: when working around a Quickshell bug or weird Qt
  behavior, link the relevant gotcha number from `QUICKSHELL_REFERENCE.md`:
  ```qml
  // Gotcha #46: niri's WindowFocusChanged fires with id=null for layer-shell focus.
  if (id !== null && id !== undefined) root.windowFocused(id);
  ```
- **Magic numbers**: every non-token literal needs a justification comment.
  ```qml
  // 80 px = standard distance from screen bottom for OSD positioning.
  margins.bottom: 68 + 12   // 80 - shadow padding
  ```
- **Don't comment what the code does** (the code does that). Comment
  why it does it that way, what alternative was tried and why it failed,
  what assumption it depends on.

---

## Testing & smoke checks

After any change, run a smoke test before committing:

```bash
qs -p /path/to/quickshell-bar > /tmp/qs-smoke.log 2>&1 &
PID=$!
sleep 4
kill $PID 2>/dev/null
wait 2>/dev/null
grep -E "(WARN|ERROR|TypeError|caused by|ReferenceError)" /tmp/qs-smoke.log | \
    grep -v "QSettings\|already registered\|Registration will\|propertyCache\|qt.svg.draw\|QThreadStorage"
echo "(empty = clean)"
```

A clean run = empty output. The filter strips:
- `QSettings::value: Empty key passed` — Qt-internal noise
- `Could not register notification server ... already registered` — expected when swaync/mako is running
- `Registration will be attempted again` — companion to the above
- `qt.qml.propertyCache.append: Member implicitWidth ... overrides` — Quickshell wrapper-component warnings, harmless
- `qt.svg.draw` — Adwaita-icon warnings, harmless
- `QThreadStorage` — Qt-internal teardown messages

For visual changes, take a screenshot with:

```bash
grim -o DP-2 /tmp/screenshot.png
# crop the bar (top 36 px) for inspection:
python3 -c "from PIL import Image; img = Image.open('/tmp/screenshot.png'); w,h = img.size; img.crop((0,0,w,36)).save('/tmp/bar-crop.png')"
```

---

## Commit message style

The repo's history uses lowercase prefix-style messages:

```
<area>: <imperative summary, lowercase>
```

Examples:

```
theme: add font tokens and size scale
notifications: bell uses Font Awesome
popup: drop shadows on all popups
docs: gotchas #56-#58 (popup fade pattern, hover linger, corner alpha)
compositor: BackendHyprland using Quickshell.Hyprland
```

Areas seen in this repo: `theme`, `bar`, `popup`, `lock`, `media`,
`volume`, `network`, `bluetooth`, `system`, `notifications`, `clipboard`,
`launcher`, `osd`, `tray`, `workspaces`, `clock`, `compositor`, `docs`,
`polish`. New areas as the shell grows.

Keep messages short — one line is plenty for the kind of changes that
land here. The `git log` should read like a changelog.

---

## When in doubt

- Match what's already in the codebase before inventing something new.
- The `BarIcon`, `BarTooltip`, `Slider`, `ProgressBar` helpers exist for
  a reason — use them; don't roll your own.
- `Theme.qml` is the single source of truth for visual tokens — don't
  inline values, add tokens.
- The compositor abstraction is the single source of truth for
  per-compositor behavior — don't shell out to `niri msg` / `hyprctl` /
  `swaymsg` outside of `compositor/Backend*.qml`.
- If a pattern feels awkward to repeat, extract it into a helper
  component or a service singleton. The repo trends toward fewer, more
  composable helpers rather than copy-paste.
