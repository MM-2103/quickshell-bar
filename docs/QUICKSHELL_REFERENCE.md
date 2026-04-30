> **Derivative work notice.** This document is largely derived from the official
> Quickshell documentation at <https://quickshell.org/docs/v0.2.1/>, reorganized
> for AI agent consumption and annotated with original observations. The
> "Gotchas & quirks" section (entries #1 through #53+) represents original
> work accumulated while building the surrounding shell project. The author
> has not verified Quickshell's documentation license — if you intend to
> substantially redistribute this file, check the upstream license first.

---

# Quickshell Reference (v0.2.1) — AI Agent Guide

A comprehensive reference for building Quickshell applications, optimized for AI agent consumption. Sourced from <https://quickshell.org/docs/v0.2.1/>.

---

## Table of Contents

1. [Overview](#overview)
2. [Getting Started](#getting-started)
3. [Core Concepts](#core-concepts)
4. [Item Sizing & Layout](#item-sizing--layout)
5. [QML Language Cheat Sheet](#qml-language-cheat-sheet)
6. [Modules](#modules)
7. [Types Reference](#types-reference)
   - [`Quickshell` module](#quickshell-module)
   - [`Quickshell.Io`](#quickshellio)
   - [`Quickshell.Wayland`](#quickshellwayland)
   - [`Quickshell.Hyprland`](#quickshellhyprland)
   - [`Quickshell.I3`](#quickshelli3)
   - [`Quickshell.Services.SystemTray`](#quickshellservicessystemtray)
   - [`Quickshell.Services.Mpris`](#quickshellservicesmpris)
   - [`Quickshell.Services.Notifications`](#quickshellservicesnotifications)
   - [`Quickshell.Services.Pipewire`](#quickshellservicespipewire)
   - [`Quickshell.Services.UPower`](#quickshellservicesupower)
   - [`Quickshell.Services.Pam`](#quickshellservicespam)
   - [`Quickshell.Services.Greetd`](#quickshellservicesgreetd)
   - [`Quickshell.Widgets`](#quickshellwidgets)
   - [`Quickshell.DBusMenu` / `Quickshell.Bluetooth`](#quickshelldbusmenu--quickshellbluetooth)
8. [Common Patterns / Recipes](#common-patterns--recipes)
9. [Tips for AI Agents](#tips-for-ai-agents)

---

## Overview

**Quickshell** is a toolkit for building Linux desktop shell components: status bars/panels, widgets, OSDs, application launchers, lockscreens, notification daemons, etc. It is configured using **QML** (Qt Modeling Language) and runs on top of **QtQuick**.

### Core ideas

- A Quickshell config is a tree of QML objects. The entry file is `shell.qml`.
- **Reactive bindings**: assigning an expression to a property automatically re-evaluates when its dependencies change.
- **Live reloading**: edit a QML file and Quickshell automatically reloads, attempting to reuse existing windows.
- **Wayland-first** but supports X11 in some scenarios. Provides Wayland-layer-shell (`PanelWindow`/`WlrLayershell`) for bars/overlays and `ext-session-lock-v1` (`WlSessionLock`) for lockscreens.
- **No process per widget** — keep everything in one QML config; use `Process`, `FileView`, sockets, DBus services, etc. for I/O.
- Compositor-agnostic where possible (`Quickshell.screens`, `ToplevelManager`), with optional compositor-specific modules (`Quickshell.Hyprland`, `Quickshell.I3`).

### Architecture

```
shell.qml                ← entry point (root QML object: usually ShellRoot or Scope)
├─ Variants {            ← create a window per screen/value
│    model: Quickshell.screens
│    PanelWindow { ... } ← layer-shell bar
│  }
├─ Singleton singletons  ← shared state (e.g. clock, audio, sysinfo)
├─ Process / FileView    ← I/O
└─ Service singletons    ← Mpris, SystemTray, Notifications, UPower, Pipewire …
```

---

## Getting Started

### Installation

Install via your distro: `pacman -S quickshell` (Arch), `dnf install quickshell` (Fedora), `apt install quickshell` (Ubuntu PPA), `nix` flake `git+https://git.outfoxxed.me/outfoxxed/quickshell`. See <https://quickshell.org/docs/v0.2.1/guide/install-setup>.

Useful optional Qt packages:
- `qtsvg` — SVG image loading
- `qtimageformats` — WEBP and other formats
- `qtmultimedia` — audio/video playback
- `qt5compat` — Gaussian blur (or use `MultiEffect`)

### Project structure

Quickshell scans `$XDG_CONFIG_HOME/quickshell` (usually `~/.config/quickshell`) for configs:

```
~/.config/quickshell/
├─ shell.qml               # default config (if no subfolders)
└─ <name>/                 # named configs, run with: qs -c <name>
   ├─ shell.qml            # entry point (REQUIRED)
   ├─ Bar.qml              # uppercase = type, importable
   ├─ ClockWidget.qml
   ├─ singletons/
   │  └─ Time.qml          # use `pragma Singleton`
   └─ .qmlls.ini           # leave empty; Quickshell fills in for LSP
```

### CLI usage

| Command | Purpose |
|---|---|
| `qs` | Launch the default config |
| `qs -c <name>` | Launch a named config (subfolder of `quickshell` dir) |
| `qs -p /path/to/dir-or-shell.qml` | Launch from arbitrary path |
| `qs ipc show` | List registered `IpcHandler` targets |
| `qs ipc call <target> <fn> [args…]` | Call an IPC function |
| `qs ipc prop get <target> <prop>` | Read an IPC-exposed property |

### Editor / LSP

- Install `qmlls` (Qt's QML language server).
- Place an empty `.qmlls.ini` next to `shell.qml` — Quickshell rewrites it with the right import paths. **Gitignore it.**
- Caveats: `qmlls` cannot resolve `PanelWindow` and similar Quickshell types; use it as a hint, not gospel.

### Pragmas

Place at the top of your root `shell.qml` to override paths/themes:

```qml
//@ pragma DataDir $BASE/myshell        // overrides Quickshell.dataDir
//@ pragma StateDir $BASE/myshell       // overrides Quickshell.stateDir
//@ pragma IconTheme Papirus            // override icon theme (also QS_ICON_THEME)
```

For singleton files:

```qml
pragma Singleton
import Quickshell
Singleton { ... }
```

---

## Core Concepts

### `ShellRoot` and `Scope`

- `ShellRoot` (`import Quickshell`): an optional root with a `settings: QuickshellSettings`. Inherits from `Scope`.
- `Scope`: a non-visual container with a `default` `children: list<QtObject>` property. It also acts as a *reload scope* — descendants share a `reloadableId` namespace.
- Either can serve as the root of `shell.qml`. `Scope` is preferred for minimalism.

### Variants & screens

`Variants` instantiates a `Component` (the `delegate`, default property) once per item in `model`. Each instance gets a `modelData` property. Common pattern:

```qml
Variants {
    model: Quickshell.screens
    PanelWindow {
        required property var modelData
        screen: modelData
        // bar contents...
    }
}
```

### Reloading & `Reloadable`

When QML files change, Quickshell hot-reloads, attempting to *reuse* windows by matching `Reloadable.reloadableId`. Types that subclass `Reloadable` (PanelWindow, FloatingWindow, PopupWindow, LazyLoader, Variants, PersistentProperties, WlSessionLock, ...) can be reused.

- `LazyLoader` always loads synchronously during reload to allow window reuse.
- Use `PersistentProperties { reloadableId: "..."; property bool foo: false }` to keep stateful flags across reloads.
- `Quickshell.reload(hard: bool)` triggers a reload programmatically (`hard=true` recreates windows).
- `Quickshell.watchFiles` (defaults to `true`) controls auto-reload on file change.

### Singletons

- File-level: `pragma Singleton` at top, root must be a `Singleton {}` (which is a `Scope`). Reference globally as `MyType.prop`.
- Connect to a singleton's signals from elsewhere via `Connections { target: MyType; function onSomeSignal() {} }`.

### IPC (`IpcHandler`)

Each `IpcHandler` registers under a unique `target`. Methods with at most 10 args of `string`/`int`/`bool`/`real`/`color` (and matching return type) are callable from the CLI:

```qml
IpcHandler {
    target: "rect"
    function setColor(color: color): void { rect.color = color }
}
```

```bash
qs ipc call rect setColor "#ff0000"
qs ipc prop get rect someProperty
```

### Reactive bindings & avoiding loops

- A property assignment `text: foo + bar` is reactive — re-evaluates when `foo` or `bar` change.
- Avoid `childrenRect.width` for sizing parent — that's a binding loop. See [Item Sizing](#item-sizing--layout).
- Use `Component.onCompleted: text = expr` if you need a one-off non-reactive assignment.
- Use `Qt.binding(() => expr)` to *create* a binding from imperative code.

### Retainable

Some types (e.g. `Notification`) are *retainable*: they can be kept alive in QML even after the underlying object is destroyed by attaching a `RetainableLock`. Useful for fade-out animations on removal.

### LazyLoader vs Loader

- `Loader` (QtQuick) — only for `Item` (visual) components.
- `LazyLoader` (Quickshell) — for non-Item components (e.g. windows, scopes). Loads asynchronously between frames if `loading: true` or `activeAsync: true`. Set `active: true` to force synchronous load. Read `loader.item` to get the loaded object.

---

## Item Sizing & Layout

> **Critical**: implicit size flows **child → parent**, actual size flows **parent → child**.

Every `Item` has:
- `implicitWidth` / `implicitHeight` — *desired* size.
- `width` / `height` — *actual* size.

If an item is inside a container (Layout, WrapperItem, etc.), **set `implicitWidth/Height`, not `width/height`**.

### Common pitfalls

- **Zero-sized items**: many QtQuick `Item`s default to size 0 — set `implicitWidth/Height` or you'll see a "phantom" widget.
- **`childrenRect` causes binding loops** — never use `childrenRect.width` to size a container; use the child's `implicitWidth` instead, or use a `WrapperItem`/`MarginWrapperManager`.
- **Anchors**: prefer `anchors.fill: parent` + `anchors.margins: 5` over manual x/y/width/height.
- **`Row`/`Column` vs `RowLayout`/`ColumnLayout`**: prefer `*Layout` types — they pixel-align children and support the `Layout.*` attached object. `Row`/`Column` use `spacing` and don't pixel-align.

### Wrapper components (`Quickshell.Widgets`)

- `WrapperItem` — adds margins around a single child Item.
- `WrapperRectangle` — same, but the wrapper is a `Rectangle` (border/background).
- `WrapperMouseArea` — wrapper that's a `MouseArea`.
- `ClippingRectangle` / `ClippingWrapperRectangle` — clipping `Rectangle` (e.g. for rounded images).
- `MarginWrapperManager` — attached helper that automates the size/margin relationship.

---

## QML Language Cheat Sheet

### Imports

```qml
import QtQuick                              // QtQuick types (Rectangle, Text, Image, …)
import QtQuick.Layouts                      // RowLayout, ColumnLayout, GridLayout
import Quickshell                           // PanelWindow, ShellRoot, Variants, …
import Quickshell.Io                        // Process, FileView, IpcHandler, Socket, …
import Quickshell.Wayland                   // WlSessionLock, ToplevelManager, …
import Quickshell.Hyprland                  // Hyprland, HyprlandWorkspace, GlobalShortcut
import Quickshell.Services.Mpris            // Mpris, MprisPlayer
import Quickshell.Services.SystemTray
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Pam
import Quickshell.Services.Greetd
import Quickshell.Widgets                   // IconImage, WrapperRectangle, …

import qs.modules.bar     // Quickshell module path: relative to shell.qml dir (v0.2+)
import qs as Root         // import the entire shell folder under namespace `Root`
```

### Property definitions

```qml
[required] [readonly] [default] property <type> <name>[: <binding>]
```

- `required` — instantiator must set it.
- `readonly` — no assignment after definition (binding still re-evaluates).
- `default` — assignment without explicit name binds here.

```qml
property int count: 0
required property var modelData
readonly property string greet: "Hello, " + name
property alias inner: child   // bidirectional alias
```

### Signals & handlers

```qml
signal foo(bar: int)            // declaration

onFoo: console.log(bar)         // implicit handler (function `onSignal`)

onWidthChanged: console.log(width)  // every property has a `<name>Changed` signal

Connections {                   // indirect handler
    target: someSingleton
    function onSomeSignal() {}
}

Component.onCompleted: { ... }  // attached signal handler — runs once on init
```

### Functions and lambdas

```qml
function dub(x: int): int { return x * 2 }
property var op: x => x * 2
property var op2: (a, b) => { return a + b }
```

### Inline components & singletons

```qml
component MyText: Text {        // inline-only type, scoped to file
    color: "red"
}

// singletons.qml
pragma Singleton
import Quickshell
Singleton {
    property string foo: "hi"
}
```

### Default property assignment

`Variants.delegate`, `LazyLoader.component`, `Scope.children`, `WlSessionLock.surface`, `IconImage.implicitSize`, etc. are *default* properties; you can omit the name:

```qml
Variants {              // delegate is default
    model: Quickshell.screens
    PanelWindow { ... } // implicitly assigned to delegate
}
```

---

## Modules

| Module | Import | Purpose |
|---|---|---|
| `Quickshell` | `import Quickshell` | Core: windows, scopes, screens, reloading, settings |
| `Quickshell.Io` | `import Quickshell.Io` | Process exec, file I/O, sockets, IPC, JSON |
| `Quickshell.Wayland` | `import Quickshell.Wayland` | wlr-layer-shell, session lock, foreign toplevels, screencopy |
| `Quickshell.Hyprland` | `import Quickshell.Hyprland` | Hyprland IPC, workspaces, monitors, global shortcuts, focus grab |
| `Quickshell.I3` | `import Quickshell.I3` | i3/Sway IPC |
| `Quickshell.Bluetooth` | `import Quickshell.Bluetooth` | Bluetooth devices and adapters |
| `Quickshell.DBusMenu` | `import Quickshell.DBusMenu` | DBusMenu (system tray context menus) |
| `Quickshell.Services.Mpris` | … | Media player control / metadata |
| `Quickshell.Services.SystemTray` | … | StatusNotifierItem tray |
| `Quickshell.Services.Notifications` | … | XDG notifications daemon implementation |
| `Quickshell.Services.Pipewire` | … | PipeWire audio (sinks/sources/streams/volume) |
| `Quickshell.Services.UPower` | … | Battery / AC / display device |
| `Quickshell.Services.Pam` | … | PAM authentication for lockscreens/greeters |
| `Quickshell.Services.Greetd` | … | greetd display manager integration |
| `Quickshell.Widgets` | … | Bundled wrapper widgets (IconImage, ClippingRectangle, …) |

---

## Types Reference

> **Notation**: `inherits → Parent`. `singleton` means accessed by type name, no instantiation. `uncreatable` means produced internally; you can't `new` one but you read references from other APIs.

### `Quickshell` module

`import Quickshell`

#### `ShellRoot` *(inherits `Scope`)*
Optional root of a config. Adds `settings: QuickshellSettings` (readonly).

#### `Scope` *(inherits `Reloadable`)*
Non-visual container. Default property: `children: list<QtObject>`. Acts as a reload scope so children share `reloadableId` lookup with the scope.

#### `Singleton` *(inherits `Scope`)*
Use as the root of any `pragma Singleton` file.

#### `Variants` *(inherits `Reloadable`)*
Creates a delegate per `model` value. Properties:

| Property | Type | Description |
|---|---|---|
| `model` | `list<variant>` | values to produce instances for |
| `delegate` *(default)* | `Component` | template; gets a `modelData` property per instance |
| `instances` *(readonly)* | `list<QtObject>` | live instances |

#### `Quickshell` *(singleton)*
Global object — main entry to engine info.

| Property | Type | Description |
|---|---|---|
| `screens` *(readonly)* | `list<ShellScreen>` | live list of monitors |
| `shellDir` *(readonly)* | `string` | folder containing `shell.qml` |
| `dataDir` / `cacheDir` / `stateDir` *(readonly)* | `string` | per-shell XDG dirs |
| `workingDirectory` | `string` | CWD of qs process |
| `clipboardText` | `string` | system clipboard (Wayland: only when a qs window is focused) |
| `processId` *(readonly)* | `int` | qs PID |
| `watchFiles` | `bool` | auto-reload (default `true`) |

| Function | Returns | Description |
|---|---|---|
| `iconPath(icon: string)` | `string` | Image source for a system icon |
| `iconPath(icon, check: bool)` | `string` | empty string if missing (avoids purple/black square) |
| `iconPath(icon, fallback: string)` | `string` | use fallback if missing |
| `shellPath(path)` / `cachePath(path)` / `dataPath(path)` / `statePath(path)` | `string` | join with respective dir |
| `env(name: string)` | `variant` | env var or null |
| `execDetached(ctx)` | `void` | fire-and-forget process; ctx = list or `{command, environment, clearEnvironment, workingDirectory}` |
| `reload(hard: bool)` | `void` | reload shell |
| `inhibitReloadPopup()` | `void` | call from `reloadCompleted`/`reloadFailed` to suppress popup |

| Signal | Description |
|---|---|
| `reloadCompleted()` | reload succeeded |
| `reloadFailed(errorString: string)` | reload failed |
| `lastWindowClosed()` | last window closed (use `Qt.quit()` to exit) |

#### `QsWindow` *(uncreatable, inherits `Reloadable`)*
Base class for all Quickshell windows. Attached to any `Item`: `QsWindow.window` and `QsWindow.contentItem` are available.

| Property | Type | Description |
|---|---|---|
| `screen` | `ShellScreen` | which monitor |
| `color` | `color` | background color (default white) |
| `visible` | `bool` | shown/hidden |
| `width` / `height` | `int` | actual window size (deprecated to *set* — use `implicitWidth/Height`) |
| `implicitWidth` / `implicitHeight` | `int` | desired size |
| `mask` | `Region` | clickthrough mask |
| `surfaceFormat` | `{opaque: bool}` | request opaque/transparent surface (set before window shown) |
| `devicePixelRatio` *(readonly)* | `real` | logical→physical pixels |
| `contentItem` *(readonly)* | `Item` | root child item container |

| Function | Returns | Description |
|---|---|---|
| `itemPosition(item)` | `point` | item pos in window coords (non-reactive) |
| `itemRect(item)` | `rect` | |
| `mapFromItem(item, x, y)` / `(item, point)` / `(item, rect)` / `(item, x, y, w, h)` | `point`/`rect` | coordinate map |

| Signal | Description |
|---|---|
| `closed()` | window closed by user/server (NOT when `visible = false`) |
| `resourcesLost()` | typically OOM/VRAM; `closed()` follows |
| `windowConnected()` | window has been connected to display server |

#### `PanelWindow` *(inherits `QsWindow`)*
Decorationless layer-shell window for bars/overlays. **Most common window type.**

```qml
PanelWindow {
    anchors { top: true; left: true; right: true }
    implicitHeight: 30
    color: "#222"
    Text { anchors.centerIn: parent; text: "Hello" }
}
```

| Property | Type | Description |
|---|---|---|
| `anchors` | `{top, bottom, left, right: bool}` | which edges to attach (default all `false`). Two opposite anchors → that dimension matches the screen. |
| `aboveWindows` | `bool` | render above normal windows (default `true`). On Wayland, maps to `WlrLayershell.layer`. |
| `focusable` | `bool` | accept keyboard focus (default `false`). On Wayland, maps to `WlrLayershell.keyboardFocus`. |
| `exclusiveZone` | `int` | reserved space (sets `exclusionMode = Normal` automatically). Need 1 or 3 anchors. |
| `margins` | `{top, bottom, left, right: int}` | offsets from anchored sides only |
| `exclusionMode` | `ExclusionMode` | `Auto` (default), `Normal`, `Ignore` |

#### `FloatingWindow` *(inherits `QsWindow`)*
Standard application-style window with title bar.

| Property | Type | Description |
|---|---|---|
| `title` | `string` | window title |
| `minimumSize` / `maximumSize` | `size` | size constraints |

#### `PopupWindow` *(inherits `QsWindow`)*
Popup positioned relative to another window/item via `anchor`.

```qml
PanelWindow {
    id: bar
    PopupWindow {
        anchor.window: bar
        anchor.rect.x: bar.width / 2 - width/2
        anchor.rect.y: bar.height
        width: 300; height: 200
        visible: trigger.opened
    }
}
```

| Property | Type | Description |
|---|---|---|
| `anchor` *(readonly)* | `PopupAnchor` | positioner |
| `visible` | `bool` | shown only when also valid anchor |
| `screen` *(readonly)* | `ShellScreen` | |

#### `PopupAnchor` *(uncreatable)*
Configures a popup's position relative to a `window` or `item`.

| Property | Type | Description |
|---|---|---|
| `window` | `QtObject` | parent window (mutually exclusive with `item`) |
| `item` | `Item` | item to anchor to (sets `window` automatically) |
| `rect` | `{x, y, width, height: int}` | anchor rect (relative) |
| `edges` | `Edges` | which corner of rect to anchor at (default `Top \| Left`) |
| `gravity` | `Edges` | direction to expand (default `Bottom \| Right`) |
| `margins` | `{left, top, right, bottom: int}` | inset from rect |
| `adjustment` | `PopupAdjustment` | repositioning strategy if won't fit on screen |

| Function / Signal | Description |
|---|---|
| `updateAnchor()` | recompute anchor (e.g. after item moved) |
| `anchoring()` *signal* | emitted right before showing — modify `rect` here using coordinate-mapping |

#### `LazyLoader` *(inherits `Reloadable`)*
Loads a `Component`/source asynchronously between frames.

| Property | Type | Description |
|---|---|---|
| `loading` | `bool` | currently loading async |
| `active` | `bool` | force *synchronous* load; setting false destroys |
| `activeAsync` | `bool` | start loading async; reading is same as `active` |
| `component` *(default)* | `Component` | inline component to load |
| `source` | `string` | URI to load from (mutually exclusive with `component`) |
| `item` *(readonly)* | `QtObject` | loaded object (or null). Reading while loading blocks! |

⚠ `LazyLoader` does NOT start loading until the first window has been created. ⚠ `Variants` inside `LazyLoader` blocks (no async support).

#### `Singleton`
See above. Use as root of `pragma Singleton` files.

#### `SystemClock`
A reactive view of the system clock. Cheaper than `Date`-based polling.

| Property | Type | Description |
|---|---|---|
| `enabled` | `bool` | pause if false |
| `precision` | `enum` | `SystemClock.Hours` / `Minutes` / `Seconds` (default `Seconds`) |
| `date` *(readonly)* | `date` | current date/time |
| `hours` / `minutes` / `seconds` *(readonly)* | `int` | individual fields |

```qml
SystemClock { id: clock; precision: SystemClock.Minutes }
Text { text: Qt.formatDateTime(clock.date, "HH:mm") }
```

#### `PersistentProperties` *(inherits `Reloadable`)*
Keeps custom property values across hot reloads.

```qml
PersistentProperties {
    id: persist
    reloadableId: "uiState"
    property bool expanderOpen: false
}
```

| Signal | Description |
|---|---|
| `loaded()` | every reload (initial too) |
| `reloaded()` | only when a previous instance was reused |

#### `ShellScreen` *(uncreatable)*
A monitor. Properties: `name` (e.g. `"DP-1"`), `model`, `serialNumber`, `width`/`height`/`x`/`y` (logical px), `devicePixelRatio`, `physicalPixelDensity`, `logicalPixelDensity`, `orientation`, `primaryOrientation`. Function: `toString()`.

#### `DesktopEntries` *(singleton)*
Index of `.desktop` files.

| Property | Type | Description |
|---|---|---|
| `applications` *(readonly)* | `ObjectModel<DesktopEntry>` | non-Hidden, non-NoDisplay Application entries |

| Function | Returns | Description |
|---|---|---|
| `byId(id: string)` | `DesktopEntry` | exact match (incl. NoDisplay) — may be `null` |
| `heuristicLookup(name: string)` | `DesktopEntry` | fuzzy match |

#### `DesktopEntry` *(uncreatable)*
Properties: `id`, `name`, `genericName`, `comment`, `icon`, `command` (parsed `Exec` as list), `execString` (raw, **don't run**), `workingDirectory`, `runInTerminal`, `noDisplay`, `categories: list<string>`, `keywords: list<string>`, `startupClass`, `actions: list<DesktopAction>`. Method: `execute()`.

#### `DesktopAction`
A sub-action of a `DesktopEntry`. Has `name`, `icon`, `command`, and `execute()`.

#### `Edges`
Bitfield enum: `Edges.Left`, `Edges.Right`, `Edges.Top`, `Edges.Bottom`. Combine with `|`.

#### `ExclusionMode`
Enum: `ExclusionMode.Auto`, `ExclusionMode.Normal`, `ExclusionMode.Ignore`.

#### `PopupAdjustment`
Enum controlling how popups reposition if they don't fit. Values include `None`, `SlideX`, `SlideY`, `FlipX`, `FlipY`, `Resize`, `All` (combined). See docs.

#### `Region` / `RegionShape` / `Intersection`
Used for `QsWindow.mask` to control click-through and shaping.

```qml
mask: Region { item: rect; intersection: Intersection.Xor }
```

`Intersection` values: `Combine` (default — region is mask), `Subtract`, `Xor`, `Intersect`.

#### `ObjectModel<T>` *(uncreatable)*
A typed list-like model used everywhere (e.g. `Mpris.players`, `SystemTray.items`, `ToplevelManager.toplevels`). Has:

| Property / Function / Signal | Description |
|---|---|
| `values: list<T>` *(readonly)* | underlying list (use this for reactive index access) |
| `indexOf(object): int` | |
| `objectInsertedPre/Post(object, index)` | |
| `objectRemovedPre/Post(object, index)` | |

Note: `model[3]` is **not** reactive — use `model.values[3]`.

#### `ObjectRepeater`
Like QtQuick's `Repeater`, but for non-Item objects.

#### `Reloadable` *(uncreatable)*
Base for everything that participates in hot-reload. Has `reloadableId: string` — set this on items you want reused across reloads.

#### `Retainable` / `RetainableLock`
Mixin for objects (notably `Notification`) that can be kept alive after being "destroyed". Add `RetainableLock { object: notif; locked: true }` to defer destruction.

#### `Other useful types`
- `BoundComponent` — like `Component` but auto-binds passed properties.
- `ColorQuantizer` — extract dominant colors from an image.
- `EasingCurve` — easing curves usable for animations.
- `ElapsedTimer` — high-resolution stopwatch.
- `ScriptModel` — JS-array-backed `QAbstractListModel` for use with `Repeater`/`ListView`.
- `TransformWatcher` — observe geometry transform changes of an item.
- `QuickshellSettings` — `lastWindowClosedAction`: `Qt.QuitOnLastWindowClosed` or similar.

#### `QsMenuAnchor`, `QsMenuOpener`, `QsMenuEntry`, `QsMenuHandle`, `QsMenuButtonType`
Generic menu types used with `SystemTrayItem.menu`.

```qml
QsMenuOpener {
    id: opener
    menu: trayItem.menu
}
// then iterate opener.children which are QsMenuEntry
```

`QsMenuEntry` has `text`, `icon`, `enabled`, `buttonType` (`None`/`CheckBox`/`RadioButton`), `checkState`, `hasChildren`, `isSeparator`. Call `entry.triggered()` to invoke.

---

### `Quickshell.Io`

`import Quickshell.Io`

#### `Process`
Run a command. **Does NOT run via shell** — pass each arg separately or use `["sh", "-c", "..."]`.

```qml
Process {
    command: ["pamixer", "--get-volume"]
    running: true
    stdout: StdioCollector { onStreamFinished: console.log(text) }
}
```

| Property | Type | Description |
|---|---|---|
| `command` | `list<string>` | argv |
| `running` | `bool` | start/stop process; setting false sends SIGTERM |
| `processId` *(readonly)* | `variant` | PID or null |
| `workingDirectory` | `string` | |
| `environment` | `object` | env overrides; `key: null` removes |
| `clearEnvironment` | `bool` | start from empty env (default false) |
| `stdout` | `DataStreamParser` | parser to attach (`StdioCollector` or `SplitParser`); set `null` to close |
| `stderr` | `DataStreamParser` | as above |
| `stdinEnabled` | `bool` | enable `write()` (default false) |

| Function | Description |
|---|---|
| `exec(ctx)` | restart with new args/env (ctx = `{command, environment, clearEnvironment, workingDirectory}`) |
| `signal(sig: int)` | send a Unix signal |
| `startDetached()` | fork-detach a copy (not tracked); same as `Quickshell.execDetached` |
| `write(data: string)` | write to stdin (needs `stdinEnabled: true`) |

| Signal | Description |
|---|---|
| `started()` | |
| `exited(exitCode: int, exitStatus)` | |

To poll: `Timer { running: true; repeat: true; interval: 1000; onTriggered: proc.running = true }` (relies on `onRunningChanged` rerun pattern).

#### `StdioCollector` *(inherits `DataStreamParser`)*
Buffers all output until end-of-stream.

| Property | Type | Description |
|---|---|---|
| `text` *(readonly)* | `string` | buffered text |
| `data` *(readonly)* | `ArrayBuffer` | buffered bytes |
| `waitForEnd` | `bool` | only update on stream end (default true) |

| Signal | Description |
|---|---|
| `streamFinished()` | EOF reached |

#### `SplitParser` *(inherits `DataStreamParser`)*
Emits each chunk delimited by `splitMarker` (default `\n`).

```qml
Process {
    command: ["hyprctl", "events"]
    running: true
    stdout: SplitParser { onRead: line => console.log(line) }
}
```

`DataStreamParser`'s base signal: `read(data: string)`.

#### `FileView`
Read or write a file (small/medium, no seeking).

```qml
FileView {
    path: Qt.resolvedUrl("./config.json")
    blockLoading: true   // OK only at startup
    onLoaded: console.log(text())
}
```

| Property | Type | Description |
|---|---|---|
| `path` | `string` | path (or empty to unload) |
| `preload` | `bool` | start loading immediately (default true) |
| `blockLoading` | `bool` | block UI on `text()`/`data()` if not yet loaded |
| `blockAllReads` | `bool` | block on every `path` change too — rarely needed |
| `blockWrites` | `bool` | block on `setText`/`setData` |
| `atomicWrites` | `bool` | rename-over-target on save (default true) |
| `watchChanges` | `bool` | emit `fileChanged` on disk modification |
| `printErrors` | `bool` | log read/write errors (default true) |
| `loaded` *(readonly)* | `bool` | a file is currently loaded |
| `adapter` *(default)* | `FileViewAdapter` | e.g. `JsonAdapter` |

| Function | Returns | Description |
|---|---|---|
| `text()` | `string` | full file as text (reactive — `textChanged` fires) |
| `data()` | `ArrayBuffer` | full file as bytes |
| `setText(s)` / `setData(buf)` | `void` | write |
| `reload()` | `void` | re-read same path |
| `writeAdapter()` | `void` | save adapter state to disk |
| `waitForJob()` | `bool` | block on current async load |

| Signal | Description |
|---|---|
| `loaded()` / `loadFailed(err: FileViewError)` | |
| `saved()` / `saveFailed(err)` | |
| `fileChanged()` | (only if `watchChanges`) |
| `adapterUpdated()` | |

#### `JsonAdapter` / `JsonObject`
Adapter that exposes JSON as a tree of `JsonObject`s (sub-`property` notation). Combine with `FileView` for typed config files.

#### `IpcHandler`
See [Core Concepts → IPC](#ipc-ipchandler).

| Property | Type | Description |
|---|---|---|
| `target` | `string` | unique key to address (required) |
| `enabled` | `bool` | accept calls (default true) |

Functions: any QML function with `int`/`bool`/`string`/`real`/`color` args (≤10) and matching return type. **Type annotations are required** or the function isn't registered.

#### `Socket` *(inherits `DataStream`)*
Unix socket client. Useful for compositor IPC (e.g. Hyprland event socket).

| Property | Type | Description |
|---|---|---|
| `path` | `string` | unix path |
| `connected` | `bool` | get/set target connection state |

| Function | Description |
|---|---|
| `write(data: string)` | queue data |
| `flush()` | flush queued writes |

| Signal | Description |
|---|---|
| `error(error)` | socket error |

`DataStream` adds a `parser: DataStreamParser` property and inherits standard IO semantics.

#### `SocketServer`
Unix socket listener that emits `Socket` connections via a `handler: Component`.

#### `DataStream` / `DataStreamParser`
Base IO types. Use `SplitParser` or `StdioCollector` as concrete parsers.

---

### `Quickshell.Wayland`

`import Quickshell.Wayland`

#### `WlrLayershell` *(inherits `PanelWindow`)*
Wayland-specific extension of `PanelWindow`. **Use as an attached object** to keep code platform-portable:

```qml
PanelWindow {
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "myshell-bar"
}
```

| Property | Type | Description |
|---|---|---|
| `layer` | `WlrLayer` | `Background` / `Bottom` / `Top` (default) / `Overlay` |
| `keyboardFocus` | `WlrKeyboardFocus` | `None` (default) / `Exclusive` / `OnDemand` |
| `namespace` | `string` | wlr namespace (cannot change after `windowConnected`) |

#### `WlSessionLock` *(inherits `Reloadable`)*
Implements `ext_session_lock_v1` for full lockscreens.

```qml
WlSessionLock {
    id: lock
    locked: true
    WlSessionLockSurface {
        Rectangle { anchors.fill: parent; color: "black" }
        Button { text: "unlock"; onClicked: lock.locked = false }
    }
}
```

| Property | Type | Description |
|---|---|---|
| `locked` | `bool` | request lock/unlock |
| `secure` *(readonly)* | `bool` | compositor confirmed all screens are covered |
| `surface` *(default)* | `Component` | must produce a `WlSessionLockSurface` |

⚠ **If qs dies while locked, conformant compositors keep the screen locked**. That's the security guarantee.

#### `WlSessionLockSurface` *(inherits `Reloadable`)*
Surface displayed by `WlSessionLock` per screen.

| Property | Type | Description |
|---|---|---|
| `screen` *(readonly)* | `ShellScreen` | |
| `width` / `height` *(readonly)* | `int` | |
| `color` | `color` | bg color (default white). Transparent is buggy; layer your own opaque content. |
| `contentItem` *(readonly)* | `Item` | |
| `visible` *(readonly)* | `bool` | |

#### `ToplevelManager` *(singleton)*
Lists windows from other apps via `zwlr-foreign-toplevel-management-v1`.

| Property | Type | Description |
|---|---|---|
| `toplevels` *(readonly)* | `ObjectModel<Toplevel>` | all open windows |
| `activeToplevel` *(readonly)* | `Toplevel` | currently focused (or null) |

#### `Toplevel` *(uncreatable)*
A foreign window.

| Property | Type | Description |
|---|---|---|
| `appId` *(readonly)* | `string` | |
| `title` *(readonly)* | `string` | |
| `activated` *(readonly)* | `bool` | focused |
| `maximized` / `minimized` / `fullscreen` | `bool` | request changes |
| `parent` *(readonly)* | `Toplevel` | parent if modal/dialog |
| `screens` *(readonly)* | `list<ShellScreen>` | |

| Function | Description |
|---|---|
| `activate()` | request focus |
| `close()` | request close |
| `fullscreenOn(screen)` | |
| `setRectangle(window, rect)` / `unsetRectangle()` | hint for minimize animations |

#### `WlrKeyboardFocus`
Enum for `WlrLayershell.keyboardFocus`: `None`, `Exclusive`, `OnDemand`.

#### `WlrLayer`
Enum: `Background`, `Bottom`, `Top`, `Overlay`.

#### `ScreencopyView`
Live screen capture. Use as an `Item` showing screen contents.

---

### `Quickshell.Hyprland`

`import Quickshell.Hyprland`

#### `Hyprland` *(singleton)*
Top-level Hyprland integration.

| Property | Type | Description |
|---|---|---|
| `monitors` *(readonly)* | `ObjectModel<HyprlandMonitor>` | |
| `focusedMonitor` *(readonly)* | `HyprlandMonitor` | |
| `workspaces` *(readonly)* | `ObjectModel<HyprlandWorkspace>` | sorted by id |
| `focusedWorkspace` *(readonly)* | `HyprlandWorkspace` | |
| `toplevels` *(readonly)* | `ObjectModel<HyprlandToplevel>` | |
| `activeToplevel` *(readonly)* | `HyprlandToplevel` | |
| `requestSocketPath` *(readonly)* | `string` | `.socket.sock` |
| `eventSocketPath` *(readonly)* | `string` | `.socket2.sock` |

| Function | Description |
|---|---|
| `dispatch(request: string)` | run any Hyprland dispatcher (e.g. `"workspace 1"`, `"exec firefox"`) |
| `monitorFor(screen: ShellScreen)` | get HyprlandMonitor by screen |
| `refreshMonitors()` / `refreshWorkspaces()` / `refreshToplevels()` | force-refresh state |

| Signal | Description |
|---|---|
| `rawEvent(event: HyprlandEvent)` | every event from socket2; see Hyprland Wiki: IPC |

#### `HyprlandWorkspace` *(uncreatable)*
| Property | Type | Description |
|---|---|---|
| `id`, `name` | `int`, `string` | named workspaces have negative ids |
| `active` *(readonly)* | `bool` | active on its monitor |
| `focused` *(readonly)* | `bool` | active *and* monitor is focused |
| `urgent` *(readonly)* | `bool` | has urgent client |
| `hasFullscreen` *(readonly)* | `bool` | |
| `monitor` *(readonly)* | `HyprlandMonitor` | |
| `toplevels` *(readonly)* | `ObjectModel` | windows on this ws |
| `lastIpcObject` *(readonly)* | `var` | raw JSON dump (call `Hyprland.refreshWorkspaces()` to update) |

| Function | Description |
|---|---|
| `activate()` | switch to this workspace (≡ `Hyprland.dispatch("workspace " + name)`) |

#### `HyprlandMonitor` *(uncreatable)*
Properties: `id`, `name`, `description`, `x`, `y`, `width`, `height`, `scale`, `focused`, `activeWorkspace`, `lastIpcObject`.

#### `HyprlandToplevel` / `HyprlandWindow` / `HyprlandEvent` / `HyprlandFocusGrab`
- `HyprlandWindow` — class info (similar to `Toplevel`).
- `HyprlandEvent` — has `name: string`, `data: string`, `parse()` to extract args.
- `HyprlandFocusGrab` — captures clicks/keys outside a window for popup-dismiss behavior.

#### `GlobalShortcut`
Register a Hyprland global shortcut bindable in `hyprland.conf` as `bind = MOD, KEY, global, <appid>:<name>`.

```qml
GlobalShortcut {
    name: "togglePanel"
    description: "Show/hide the panel"
    onPressed: panel.visible = !panel.visible
}
```

| Property | Type | Description |
|---|---|---|
| `name` | `string` | required, no spaces |
| `description` | `string` | shown in `hyprctl globalshortcuts` |
| `appid` | `string` | default `"quickshell"` |
| `triggerDescription` | `string` | unused, included for completeness |
| `pressed` *(readonly)* | `bool` | currently held |

| Signals | |
|---|---|
| `pressed()` | |
| `released()` | |

---

### `Quickshell.I3`

`import Quickshell.I3`

#### `I3` *(singleton)*
Equivalent to `Hyprland` but for i3/Sway.

| Property | Type | Description |
|---|---|---|
| `socketPath` *(readonly)* | `string` | |
| `monitors` *(readonly)* | `ObjectModel<I3Monitor>` | |
| `focusedMonitor` *(readonly)* | `I3Monitor` | |
| `workspaces` *(readonly)* | `ObjectModel<I3Workspace>` | |
| `focusedWorkspace` *(readonly)* | `I3Workspace` | |

| Function | Description |
|---|---|
| `dispatch(cmd: string)` | run i3/Sway command |
| `findMonitorByName(name)` / `findWorkspaceByName(name)` | lookup helpers |
| `monitorFor(screen)` | `I3Monitor` for a `ShellScreen` |
| `refreshMonitors()` / `refreshWorkspaces()` | |

| Signal | |
|---|---|
| `connected()` | |
| `rawEvent(event: I3Event)` | |

#### `I3Workspace` / `I3Monitor` / `I3Event`
Analogous to Hyprland equivalents.

---

### `Quickshell.Services.SystemTray`

`import Quickshell.Services.SystemTray`

#### `SystemTray` *(singleton)*
Referencing this singleton starts the StatusNotifierWatcher service.

| Property | Type | Description |
|---|---|---|
| `items` *(readonly)* | `ObjectModel<SystemTrayItem>` | |

#### `SystemTrayItem` *(uncreatable)*
| Property | Type | Description |
|---|---|---|
| `id` *(readonly)* | `string` | unique app name |
| `title` *(readonly)* | `string` | |
| `icon` *(readonly)* | `string` | image source |
| `tooltipTitle` / `tooltipDescription` *(readonly)* | `string` | |
| `category` *(readonly)* | `Category` | `ApplicationStatus`, `Communications`, `SystemServices`, `Hardware` |
| `status` *(readonly)* | `Status` | `Passive`, `Active`, `NeedsAttention` |
| `menu` *(readonly)* | `QsMenuHandle` | use with `QsMenuAnchor`/`QsMenuOpener` |
| `hasMenu` / `onlyMenu` *(readonly)* | `bool` | |

| Function | Description |
|---|---|
| `activate()` | left-click |
| `secondaryActivate()` | middle-click |
| `scroll(delta: int, horizontal: bool)` | wheel |
| `display(parentWindow, relativeX, relativeY)` | show platform menu at point |

| Signal | |
|---|---|
| `ready()` | item finished loading metadata |

---

### `Quickshell.Services.Mpris`

`import Quickshell.Services.Mpris`

#### `Mpris` *(singleton)*
| Property | Type | Description |
|---|---|---|
| `players` *(readonly)* | `ObjectModel<MprisPlayer>` | all DBus MPRIS players |

#### `MprisPlayer` *(uncreatable)*
**Always check the `canX` / `xSupported` properties before relying on a feature.**

Track info (readonly): `trackTitle`, `trackArtist`, `trackAlbum`, `trackAlbumArtist`, `trackArtUrl`, `metadata` (raw map), `length` (sec), `uniqueId` (int), `dbusName`, `identity`, `desktopEntry`.

State:
| Property | Type | Description |
|---|---|---|
| `playbackState` | `MprisPlaybackState` | `Playing`/`Paused`/`Stopped` |
| `isPlaying` | `bool` | shorthand setter (calls play/pause) |
| `position` | `real` | seconds (millisecond precision); ⚠ NOT reactive — emit `positionChanged()` manually with a `FrameAnimation` or `Timer` if needed |
| `volume` | `real` | 0.0–1.0 |
| `loopState` | `MprisLoopState` | `None`/`Track`/`Playlist` |
| `shuffle` | `bool` | |
| `rate` / `minRate` / `maxRate` | `real` | playback speed |
| `fullscreen` | `bool` | |

Capabilities (readonly bools): `canControl`, `canPlay`, `canPause`, `canTogglePlaying`, `canSeek`, `canGoNext`, `canGoPrevious`, `canQuit`, `canRaise`, `canSetFullscreen`, `lengthSupported`, `positionSupported`, `volumeSupported`, `loopSupported`, `shuffleSupported`.

| Function | Description |
|---|---|
| `play()` / `pause()` / `togglePlaying()` / `stop()` | |
| `next()` / `previous()` | |
| `seek(offset: real)` | relative seek |
| `openUri(uri: string)` | request play of URI |
| `raise()` / `quit()` | window-management |

| Signal | |
|---|---|
| `trackChanged()` | new track; metadata updates *follow* this signal |
| `postTrackChanged()` | metadata done updating (artUrl may still be late) |

#### `MprisPlaybackState`, `MprisLoopState`
Enums.

---

### `Quickshell.Services.Notifications`

`import Quickshell.Services.Notifications`

#### `NotificationServer`
Implements the freedesktop notifications spec. **Most capability flags default to `false`** — you must opt in to advertise them.

```qml
NotificationServer {
    id: nserver
    bodySupported: true
    actionsSupported: true
    imageSupported: true
    keepOnReload: true

    onNotification: notif => {
        notif.tracked = true       // call to keep the notification
        // display logic...
    }
}
```

| Property | Type | Description |
|---|---|---|
| `trackedNotifications` *(readonly)* | `ObjectModel<Notification>` | currently tracked |
| `bodySupported` | `bool` | default true |
| `bodyMarkupSupported` / `bodyHyperlinksSupported` / `bodyImagesSupported` | `bool` | default false |
| `imageSupported` | `bool` | default false |
| `actionsSupported` / `actionIconsSupported` | `bool` | default false |
| `inlineReplySupported` | `bool` | default false |
| `persistenceSupported` | `bool` | default false |
| `keepOnReload` | `bool` | re-emit notifications across qs reloads (default true) |
| `extraHints` | `list<string>` | |

| Signal | |
|---|---|
| `notification(notification: Notification)` | new notification — set `notification.tracked = true` to keep |

#### `Notification` *(uncreatable, retainable)*
| Property | Type | Description |
|---|---|---|
| `id` *(readonly)* | `int` | server id |
| `appName`, `appIcon`, `desktopEntry` *(readonly)* | `string` | sender |
| `summary`, `body` *(readonly)* | `string` | title + body text |
| `image` *(readonly)* | `string` | image (e.g. avatar) source |
| `urgency` *(readonly)* | `NotificationUrgency` | `Low`/`Normal`/`Critical` |
| `expireTimeout` *(readonly)* | `real` | seconds (0 = no timeout, -1 = default) |
| `transient` *(readonly)* | `bool` | skip persistence |
| `resident` *(readonly)* | `bool` | don't auto-close on action |
| `lastGeneration` *(readonly)* | `bool` | from previous reload (if `keepOnReload`) |
| `actions` *(readonly)* | `list<NotificationAction>` | |
| `hasInlineReply` *(readonly)* | `bool` | |
| `inlineReplyPlaceholder` *(readonly)* | `string` | |
| `hasActionIcons` *(readonly)* | `bool` | |
| `hints` *(readonly)* | `var` | raw map |
| `tracked` | `bool` | set false to dismiss |

| Function | |
|---|---|
| `dismiss()` | user-dismissed (calls server) |
| `expire()` | timeout-expired (calls server) |
| `sendInlineReply(text: string)` | only if `hasInlineReply` |

| Signal | |
|---|---|
| `closed(reason: NotificationCloseReason)` | object destroyed after handlers exit |

#### `NotificationAction`
`identifier: string`, `text: string`, `invoke()` method.

#### `NotificationUrgency`, `NotificationCloseReason`
Enums.

---

### `Quickshell.Services.Pipewire`

`import Quickshell.Services.Pipewire`

#### `Pipewire` *(singleton)*
| Property | Type | Description |
|---|---|---|
| `ready` *(readonly)* | `bool` | initial sync done |
| `nodes` *(readonly)* | `ObjectModel<PwNode>` | every node |
| `links` / `linkGroups` *(readonly)* | `ObjectModel<PwLink>` / `<PwLinkGroup>` | |
| `defaultAudioSink` *(readonly)* | `PwNode` | currently chosen output |
| `defaultAudioSource` *(readonly)* | `PwNode` | currently chosen input |
| `preferredDefaultAudioSink` | `PwNode` | hint for default sink |
| `preferredDefaultAudioSource` | `PwNode` | hint for default source |

#### `PwNode` *(uncreatable)*
| Property | Type | Description |
|---|---|---|
| `id` *(readonly)* | `int` | pipewire id |
| `name`, `description`, `nickname` *(readonly)* | `string` | |
| `type` *(readonly)* | `PwNodeType` | reflects `media.class` |
| `isSink` / `isStream` *(readonly)* | `bool` | sink vs source / stream vs hardware |
| `audio` *(readonly)* | `PwNodeAudio` | non-null iff audio node |
| `properties` *(readonly)* | `var` | full property map (only valid if bound via `PwObjectTracker`) |
| `ready` *(readonly)* | `bool` | |

#### `PwNodeAudio` *(uncreatable)*
Has `volume: real`, `muted: bool`, `channels: list<PwAudioChannel>`, `volumes: list<real>`, etc. Read/write to control device volume:

```qml
property var sink: Pipewire.defaultAudioSink
PwObjectTracker { objects: [sink] }   // ensure properties bind
Slider { value: sink?.audio.volume ?? 0; onMoved: sink.audio.volume = value }
```

#### `PwObjectTracker`
Binds full property data of pipewire objects (otherwise `properties` is empty).

#### `PwNodeLinkTracker`, `PwLink`, `PwLinkGroup`, `PwLinkState`, `PwAudioChannel`, `PwNodeType`
Helpers for graph topology.

---

### `Quickshell.Services.UPower`

`import Quickshell.Services.UPower`

#### `UPower` *(singleton)*
| Property | Type | Description |
|---|---|---|
| `devices` *(readonly)* | `ObjectModel<UPowerDevice>` | physical devices |
| `displayDevice` *(readonly)* | `UPowerDevice` | aggregate display device (always exists; check `.ready`) |
| `onBattery` *(readonly)* | `bool` | running on battery |

#### `UPowerDevice` *(uncreatable)*
| Property | Type | Description |
|---|---|---|
| `ready` *(readonly)* | `bool` | |
| `type` *(readonly)* | `UPowerDeviceType` | `Battery`/`Mouse`/`Keyboard`/etc. |
| `state` *(readonly)* | `UPowerDeviceState` | `Charging`/`Discharging`/`Empty`/`FullyCharged`/`PendingCharge`/`PendingDischarge` |
| `percentage` *(readonly)* | `real` | 0–100 |
| `energy` / `energyCapacity` *(readonly)* | `real` | watt-hours |
| `changeRate` *(readonly)* | `real` | watts (positive=charging, negative=discharging) |
| `timeToFull` / `timeToEmpty` *(readonly)* | `real` | seconds |
| `healthSupported` / `healthPercentage` *(readonly)* | `bool`, `real` | |
| `iconName` *(readonly)* | `string` | icon recommendation |
| `model` / `nativePath` *(readonly)* | `string` | |
| `isLaptopBattery` *(readonly)* | `bool` | shorthand |
| `isPresent` *(readonly)* | `bool` | only valid if `type == Battery` |
| `powerSupply` *(readonly)* | `bool` | provides charge to system |

#### `PowerProfiles` *(singleton)*
Read/control performance profiles.

#### `PowerProfile`, `UPowerDeviceType`, `UPowerDeviceState`, `PerformanceDegradationReason`
Enums.

---

### `Quickshell.Services.Pam`

`import Quickshell.Services.Pam`

#### `PamContext`
Authenticate against PAM (use for lockscreens / greeters).

```qml
PamContext {
    id: pam
    config: "login"
    user: "alice"
    onPamMessage: passwordField.placeholder = message
    onCompleted: result => {
        if (result === PamResult.Success) lock.locked = false
    }
}
// Start auth:
pam.active = true
// Respond to prompts:
function submit() { pam.respond(passwordField.text) }
```

| Property | Type | Description |
|---|---|---|
| `config` | `string` | name of PAM config file (default `"login"`) |
| `configDirectory` | `string` | default `"/etc/pam.d"` |
| `user` | `string` | empty = current user |
| `active` | `bool` | start/stop auth — equivalent to `start()` / `abort()` |
| `message` *(readonly)* | `string` | last PAM prompt |
| `messageIsError` *(readonly)* | `bool` | |
| `responseRequired` *(readonly)* | `bool` | call `respond()` |
| `responseVisible` *(readonly)* | `bool` | echo response in clear text |

| Function | |
|---|---|
| `start(): bool` | |
| `abort()` | |
| `respond(response: string)` | |

| Signal | |
|---|---|
| `pamMessage()` | new prompt; check `message` etc. |
| `completed(result: PamResult)` | success/failure (`Success`/`Failed`/`Error`) |
| `error(error: PamError)` | |

#### `PamResult`, `PamError`
Enums.

---

### `Quickshell.Services.Greetd`

`import Quickshell.Services.Greetd`

#### `Greetd` *(singleton)*
For implementing a greeter on top of `greetd`.

| Property | Type | Description |
|---|---|---|
| `available` *(readonly)* | `bool` | greetd socket reachable |
| `state` *(readonly)* | `GreetdState` | `Inactive`/`Authenticating`/`ReadyToLaunch`/`Launching` |
| `user` *(readonly)* | `string` | current authenticating user |

| Function | Description |
|---|---|
| `createSession(user: string)` | start auth flow |
| `respond(response: string)` | answer auth message |
| `cancelSession()` | cancel |
| `launch(command: list)` / `launch(command, env)` / `launch(command, env, quit: bool)` | launch session — qs exits unless `quit == false` |

| Signal | |
|---|---|
| `authMessage(message, error, responseRequired, echoResponse)` | recoverable prompt |
| `authFailure(message: string)` | bad password etc. |
| `readyToLaunch()` | |
| `launched()` | greetd accepted session |
| `error(error: string)` | |

⚠ greetd expects greeter to **terminate ASAP** after `launch()`. Don't run animations after.

---

### `Quickshell.Widgets`

`import Quickshell.Widgets`

#### `IconImage` *(inherits `Item`)*
A specialized `Image` for icons. Adds 1:1 aspect ratio padding.

| Property | Type | Description |
|---|---|---|
| `source` | `string` | image URI |
| `implicitSize` | `real` | suggested side length |
| `actualSize` *(readonly)* | `real` | actually rendered size |
| `mipmap` | `bool` | mipmap filter (default false) |
| `asynchronous` | `bool` | (default false) |
| `backer` | `Image` | underlying `Image` for advanced access |
| `status` | `Image.Status` | |

#### `WrapperItem` *(inherits `Item`)*
Wraps a single child with margins.

#### `WrapperRectangle` *(inherits `Rectangle`)*
Wraps a single child with margins **and** a `Rectangle` background/border.

| Property | Type | Description |
|---|---|---|
| `child` | `Item` | the wrapped item (auto-detected, or set explicitly) |
| `margin` | `real` | default for all 4 sides |
| `topMargin` / `bottomMargin` / `leftMargin` / `rightMargin` | `real` | per-side; default `margin`; assign `undefined` to reset |
| `extraMargin` | `real` | added on top of all sides |
| `contentInsideBorder` | `bool` | add `border.width` to `extraMargin` (default true) |
| `resizeChild` | `bool` | stretch child if wrapper is larger than its implicit size (default true) |
| `implicitWidth` / `implicitHeight` | `real` | overrides; assign `undefined` to reset |

⚠ Don't set `child.x`/`y`/`width`/`height`/`anchors` — those are managed.

#### `WrapperMouseArea` *(inherits `MouseArea`)*
Same idea, but the wrapper is a `MouseArea`.

#### `ClippingRectangle` *(inherits `Rectangle`)*
A `Rectangle` that clips its children to its rounded shape.

#### `ClippingWrapperRectangle`
Combines `WrapperRectangle` + clipping (so e.g. `IconImage` inside is rounded).

```qml
ClippingWrapperRectangle {
    radius: 10
    IconImage { source: "..."; implicitSize: 48 }
}
```

#### `MarginWrapperManager` *(attached helper)*
Inside any `Item` you can drop `MarginWrapperManager { margin: 5 }` to make it a margin-wrapper around its single child.

#### `WrapperManager` / `WrapperItem`
Lower-level managers; `MarginWrapperManager` is built on `WrapperManager`.

---

### `Quickshell.DBusMenu` / `Quickshell.Bluetooth`

#### `Quickshell.DBusMenu`
- `DBusMenuHandle` — handle to a menu (returned from system tray items).
- `DBusMenuItem` — entry; iterate via `QsMenuOpener`.

#### `Quickshell.Bluetooth`
- `Bluetooth` *(singleton)* — `adapters: ObjectModel<BluetoothAdapter>`, `defaultAdapter`.
- `BluetoothAdapter` — `enabled`, `discovering`, `discoverable`, `pairable`, `name`, `address`, `state: BluetoothAdapterState`, `devices: ObjectModel<BluetoothDevice>`. Methods: `setEnabled()`, `setDiscovering()`, …
- `BluetoothDevice` — `name`, `address`, `paired`, `connected`, `bonded`, `trusted`, `blocked`, `batteryAvailable`, `battery`, `state: BluetoothDeviceState`, `icon`, …. Methods: `pair()`, `connect()`, `disconnect()`, `forget()`.
- `BluetoothAdapterState`, `BluetoothDeviceState` — enums.

---

## Common Patterns / Recipes

### A basic per-screen bar

```qml
// shell.qml
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true }
            implicitHeight: 32
            color: "#1e1e2e"
            exclusiveZone: implicitHeight

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                Text { text: Time.text; color: "white" }
                Item { Layout.fillWidth: true }       // spacer
                Text { text: "right"; color: "white" }
            }
        }
    }
}
```

### A clock singleton

```qml
// Time.qml
pragma Singleton
import Quickshell
import QtQuick
Singleton {
    readonly property string text: Qt.formatDateTime(clock.date, "HH:mm:ss")
    SystemClock { id: clock; precision: SystemClock.Seconds }
}
```

Then in any other QML: `Text { text: Time.text }` (auto-imported as a sibling).

### Reading once-off process output

```qml
Process {
    command: ["uname", "-r"]
    running: true
    stdout: StdioCollector {
        onStreamFinished: kernel.text = this.text.trim()
    }
}
Text { id: kernel }
```

### Streaming a long-running process

```qml
// Listen to Hyprland events
Process {
    command: ["socat", "-U", "-", "UNIX-CONNECT:" + Hyprland.eventSocketPath]
    running: true
    stdout: SplitParser {
        splitMarker: "\n"
        onRead: line => console.log("evt:", line)
    }
}
```

…or just use `Hyprland.rawEvent`.

### Periodic refresh

```qml
Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: cpuProc.running = true
}
Process {
    id: cpuProc
    command: ["sh", "-c", "echo $(cat /proc/loadavg | cut -d' ' -f1)"]
    stdout: StdioCollector { onStreamFinished: cpuLabel.text = this.text }
}
```

### File watching

```qml
FileView {
    path: "/sys/class/backlight/intel_backlight/brightness"
    watchChanges: true
    onFileChanged: this.reload()
    onLoaded: brightnessLabel.text = text().trim()
}
```

### Popup attached to a bar item

```qml
PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }
    implicitHeight: 32

    Rectangle {
        id: button
        width: 80; height: parent.height
        color: ma.containsMouse ? "#444" : "transparent"
        Text { anchors.centerIn: parent; text: "Menu"; color: "white" }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: pop.visible = !pop.visible }
    }

    PopupWindow {
        id: pop
        anchor.window: bar
        anchor.item: button
        anchor.rect.y: button.height
        width: 200; height: 200
        visible: false
        Rectangle { anchors.fill: parent; color: "#222" }
    }
}
```

### System tray rendering

```qml
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick.Layouts

RowLayout {
    Repeater {
        model: SystemTray.items
        delegate: MouseArea {
            required property SystemTrayItem modelData
            implicitWidth: 24; implicitHeight: 24
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton) modelData.activate()
                else if (mouse.button === Qt.MiddleButton) modelData.secondaryActivate()
                else if (modelData.hasMenu) modelData.display(QsWindow.window, mouse.x, mouse.y)
            }
            onWheel: wheel => modelData.scroll(wheel.angleDelta.y, false)
            IconImage {
                anchors.fill: parent
                source: modelData.icon
            }
        }
    }
}
```

### Mpris media controls

```qml
import Quickshell.Services.Mpris

Repeater {
    model: Mpris.players
    delegate: RowLayout {
        required property MprisPlayer modelData
        Text { text: modelData.trackTitle || "—" }
        Button {
            text: modelData.isPlaying ? "⏸" : "▶"
            enabled: modelData.canTogglePlaying
            onClicked: modelData.togglePlaying()
        }
        Slider {
            from: 0; to: modelData.length || 1
            value: modelData.position
            onMoved: if (modelData.canSeek) modelData.position = value
        }
        FrameAnimation {
            running: modelData.playbackState === MprisPlaybackState.Playing
            onTriggered: modelData.positionChanged()  // force reactive update
        }
    }
}
```

### Hyprland workspaces widget

```qml
import Quickshell.Hyprland
import QtQuick.Layouts

RowLayout {
    Repeater {
        model: Hyprland.workspaces
        delegate: Rectangle {
            required property HyprlandWorkspace modelData
            implicitWidth: 24; implicitHeight: 24
            radius: 4
            color: modelData.focused ? "#89b4fa"
                 : modelData.active  ? "#45475a"
                 : modelData.urgent  ? "#f38ba8"
                 : "transparent"
            border.color: "#585b70"
            Text {
                anchors.centerIn: parent
                text: modelData.name
                color: "white"
            }
            MouseArea { anchors.fill: parent; onClicked: modelData.activate() }
        }
    }
}
```

### Notification daemon (minimal)

```qml
import Quickshell.Services.Notifications
import QtQuick.Layouts

NotificationServer {
    id: server
    bodySupported: true
    bodyMarkupSupported: true
    actionsSupported: true
    imageSupported: true
    onNotification: n => { n.tracked = true }
}

PanelWindow {
    anchors { top: true; right: true }
    implicitWidth: 360; implicitHeight: contentColumn.height + 16
    color: "transparent"
    ColumnLayout {
        id: contentColumn
        anchors.right: parent.right
        spacing: 4
        Repeater {
            model: server.trackedNotifications
            delegate: Rectangle {
                required property Notification modelData
                Layout.preferredWidth: 350
                implicitHeight: title.height + body.height + 16
                radius: 8
                color: "#1e1e2e"
                border.color: "#585b70"
                Text { id: title; text: modelData.summary; color: "white"; x: 8; y: 8 }
                Text { id: body; text: modelData.body; color: "#cdd6f4"; x: 8; anchors.top: title.bottom; wrapMode: Text.Wrap; width: parent.width - 16 }
                Timer { interval: 5000; running: true; onTriggered: modelData.expire() }
            }
        }
    }
}
```

### Lockscreen with PAM

**Quickstart** — single-screen, minimum viable:

```qml
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Controls

WlSessionLock {
    id: lock
    locked: true

    PamContext {
        id: pam
        onCompleted: result => {
            if (result === PamResult.Success) lock.locked = false
            else { passField.text = ""; passField.placeholderText = "Wrong password" }
        }
    }

    WlSessionLockSurface {
        Rectangle {
            anchors.fill: parent
            color: "black"
            TextField {
                id: passField
                anchors.centerIn: parent
                width: 300
                echoMode: TextInput.Password
                placeholderText: pam.message || "Password"
                onAccepted: {
                    if (!pam.active) pam.active = true
                    else if (pam.responseRequired) pam.respond(text)
                }
            }
        }
    }
}
```

**Production-grade pattern.** The quickstart loses the error message instantly (gotcha #49), looks frozen during PAM's 2 s validation (gotcha #50), and only handles a single screen. A robust lock has four layers:

1. **Service singleton** (`LockService.qml`) — owns lock state, PAM, error/checking flags. Survives hot-reload and is shared across all surfaces.
2. **Lock root** (`Lock.qml`) — `WlSessionLock { surface: Component { LockSurface { } } }`. One instance, fans out per-screen via Component (gotcha #48).
3. **LockSurface** (`LockSurface.qml`) — per-screen UI: background + clock + password input. Disables itself while `LockService.pamChecking` is true.
4. **IPC trigger** — `IpcHandler { target: "lock"; function open(): void { LockService.lock() } }` so niri keybinds and idle daemons (`hypridle`/`swayidle`) trigger lock via `qs ipc call lock open`.

```qml
// LockService.qml — singleton
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pam

Singleton {
    id: root
    property bool   locked:       false
    property string pamMessage:   ""
    property string pamError:     ""    // persistent — cleared only on respond() or success
    property bool   pamChecking:  false  // true while pam_unix is validating (~2 s)
    property string _pendingResponse: ""  // queue for early submits (lock-open race)

    function lock() {
        if (root.locked) return                  // idempotent — hypridle may call repeatedly
        root.pamError = ""
        root.locked = true
        if (!pam.active) pam.active = true
    }

    function respond(text) {
        if (!pam.active)              { root._pendingResponse = text; pam.active = true; return }
        if (pam.responseRequired)     { root.pamError = ""; root.pamChecking = true; pam.respond(text) }
        else                          { root._pendingResponse = text }   // surface should disable input; defensive
    }

    PamContext {
        id: pam
        config: "qslock"                          // /etc/pam.d/qslock = "auth include login"
        onMessageChanged: root.pamMessage = pam.message || ""
                                                 // do NOT clear pamError here — see gotcha #49
        onResponseRequiredChanged: {
            if (pam.responseRequired && root._pendingResponse.length > 0) {
                const t = root._pendingResponse
                root._pendingResponse = ""
                root.pamError = ""
                root.pamChecking = true
                pam.respond(t)
            }
        }
        onCompleted: result => {
            root.pamChecking = false
            if (result === PamResult.Success)    { root.locked = false; root.pamError = ""; root.pamMessage = "" }
            else if (result === PamResult.Failed) { root.pamError = "Authentication failed"
                                                    Qt.callLater(() => { if (root.locked) pam.active = true }) }
            else                                  { root.pamError = "PAM error — try again"
                                                    Qt.callLater(() => { if (root.locked) pam.active = true }) }
        }
    }
}
```

```qml
// LockSurface.qml — per-screen UI
import QtQuick
import QtQuick.Effects
import Quickshell.Wayland

WlSessionLockSurface {
    color: "black"

    // Optional blurred wallpaper background (see gotcha #51 for layer.enabled).
    // Read the path from somewhere — e.g. ~/.config/waypaper/config.ini (gotcha #53).
    Image {
        anchors.fill: parent
        source: LockService.wallpaperPath
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: parent.width; sourceSize.height: parent.height
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
    }
    Rectangle { anchors.fill: parent; color: "#16181c"; opacity: 0.45 }   // dark overlay

    // Centered clock + input.
    Column {
        anchors.centerIn: parent; spacing: 18; width: 360

        SystemClock { id: clk; precision: SystemClock.Minutes }
        Text { anchors.horizontalCenter: parent.horizontalCenter
               text: Qt.formatDateTime(clk.date, "HH:mm")
               color: "white"; font.pixelSize: 96; font.family: "monospace" }

        Rectangle {
            width: parent.width; height: 44; radius: 4
            color: Qt.rgba(0, 0, 0, 0.55)
            opacity: LockService.pamChecking ? 0.45 : 1.0     // dim while validating
            Behavior on opacity { NumberAnimation { duration: 100 } }
            border.width: 1
            border.color: LockService.pamError.length > 0 ? "#ff5050"
                        : (passField.activeFocus ? "white" : "#2a2a2e")

            TextInput {
                id: passField
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                color: "white"; font.pixelSize: 16
                echoMode: TextInput.Password; passwordCharacter: "●"
                readOnly: LockService.pamChecking            // input locked during the 2 s wait
                Component.onCompleted: forceActiveFocus()
                Keys.onPressed: event => {
                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            && !LockService.pamChecking && passField.text.length > 0) {
                        LockService.respond(passField.text)
                        // do NOT clear field here — let dots stay visible; clear on error
                        event.accepted = true
                    }
                }
            }
        }

        Text { anchors.horizontalCenter: parent.horizontalCenter
               text: LockService.pamError.length > 0 ? LockService.pamError
                                                     : (LockService.pamMessage || "Locked")
               color: LockService.pamError.length > 0 ? "#ff7070" : "white"
               font.pixelSize: 12 }
    }

    // On rejected attempt: clear the field so the user can immediately retype.
    Connections {
        target: LockService
        function onPamErrorChanged() {
            if (LockService.pamError.length > 0) {
                passField.text = ""
                Qt.callLater(() => passField.forceActiveFocus())
            }
        }
    }
}
```

**PAM service file** (`/etc/pam.d/qslock`, root install):

```
auth include login
```

(Or, for instant feedback at the cost of fail-rate-limiting, `auth required pam_unix.so nodelay` — see gotcha #50.)

**Recovery if your shell crashes while locked.** `WlSessionLock` is secure-by-design (see gotcha at `WlSessionLock` API): if Quickshell dies while locked, the screen STAYS locked. Your unlock path is:

```
Ctrl+Alt+F2          # switch to TTY 2
<login as your user>
loginctl unlock-session $XDG_SESSION_ID
Ctrl+Alt+F1          # back to your graphical session
```

Test this rehearsal before you ever need it.

### Application launcher (fuzzy)

```qml
import Quickshell

ListView {
    model: search.length > 0
        ? DesktopEntries.applications.values.filter(a =>
            a.name.toLowerCase().includes(search.toLowerCase()))
        : DesktopEntries.applications.values
    delegate: MouseArea {
        required property DesktopEntry modelData
        width: parent.width; height: 32
        onClicked: { modelData.execute(); root.visible = false }
        Row {
            spacing: 8
            IconImage { source: Quickshell.iconPath(modelData.icon, true); implicitSize: 24 }
            Text { text: modelData.name; color: "white"; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
```

### Compositor integration without a built-in module (e.g. Niri)

For compositors that ship a JSON event stream (Niri, River with `riverctl`-style integrations, etc.), build a service Scope around a long-running `Process` + `SplitParser`. Pattern adapted from a working Niri integration:

```qml
// Niri.qml — non-singleton Scope so it can hold child Process objects
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var workspaces: []
    property string focusedOutput: ""

    function _handleEvent(event) {
        if (event.WorkspacesChanged) {
            root.workspaces = event.WorkspacesChanged.workspaces;
            const focused = root.workspaces.find(w => w.is_focused);
            if (focused) root.focusedOutput = focused.output;
        } else if (event.WorkspaceActivated) {
            const id = event.WorkspaceActivated.id;
            const focused = event.WorkspaceActivated.focused;
            root.workspaces = root.workspaces.map(w => Object.assign({}, w, {
                is_active:  w.output === root.workspaces.find(x => x.id === id)?.output
                            ? (w.id === id) : w.is_active,
                is_focused: focused ? (w.id === id) : w.is_focused,
            }));
            if (focused) root.focusedOutput = root.workspaces.find(w => w.id === id)?.output ?? "";
        }
    }

    Process {
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (!line) return;
                try { root._handleEvent(JSON.parse(line)); }
                catch (e) { console.warn("[Niri] parse:", e, line); }
            }
        }
        // Auto-restart on compositor restart
        onRunningChanged: { if (!running) running = true; }
    }
}
```

Use as `Niri { id: niriService }` from `shell.qml`; share via `property var niri: niriService` to children. Same pattern works for any compositor that emits line-delimited JSON events.

### Custom icons drawn with QtQuick.Shapes

Theme icons aren't always available, render dark, or simply don't fit the visual language. For small symbolic glyphs, draw inline:

```qml
import QtQuick
import QtQuick.Shapes

Item {
    id: bell
    width: 14; height: 14
    readonly property color stroke: Theme.text

    Shape {
        anchors.fill: parent
        antialiasing: true
        layer.enabled: true
        layer.samples: 4   // 4x MSAA — required for crisp curves at 14-16px

        // Bell body (rounded path with quadratic curves)
        ShapePath {
            strokeColor: bell.stroke
            strokeWidth: 1.4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            startX: 2; startY: 11
            PathQuad { x: 7; y: 2; controlX: 1; controlY: 6 }
            PathQuad { x: 12; y: 11; controlX: 13; controlY: 6 }
            PathLine { x: 2; y: 11 }
        }
    }
}
```

Notes:
- `layer.enabled: true; layer.samples: 4` is essential — without MSAA, curves look jagged at small sizes.
- `ShapePath` lives inside `Shape`. Inside `ShapePath`, `parent.parent` doesn't resolve to the wrapping Item — assign `id: bell` and reference directly.
- Each `Shape` block can hold multiple `ShapePath`s (cup body + handle + steam are 3 paths in one Shape).
- For a rotating element (gauge needle, spinner), apply `transform: Rotation { origin.x:...; origin.y:...; angle: bell.someAngle }` to a child Rectangle and animate `someAngle` with a `Behavior on someAngle`.

### Project organization with subdirectory modules

For configs beyond ~10 files, group by feature. Each subdir auto-registers as a Quickshell module (no `qmldir`):

```
shell-root/
├── shell.qml                ← entry; sees siblings + must `import qs.<subdir>` for subdirs
├── Theme.qml                ← root-level singleton (auto-import to root files only)
├── Bar.qml                  ← root-level chrome
│
├── workspaces/Workspaces.qml, Niri.qml
├── volume/Volume.qml, VolumePopup.qml
├── network/Network.qml, NetworkPopup.qml, NetworkService.qml      ← service is a sibling
└── notifications/Notifications.qml, NotificationService.qml, ...
```

Imports:
- `shell.qml` and `Bar.qml` (root): `import qs.workspaces`, `import qs.volume`, etc., one per consumed subdir.
- Files inside each subdir: `import qs` (gives access to root-level singletons like `Theme`).
- Within a subdir: no imports needed — files are siblings.

```qml
// Bar.qml
import QtQuick
import Quickshell
import qs.workspaces
import qs.volume
import qs.network
// ...

PanelWindow { /* uses Workspaces, Volume, Network types */ }
```

```qml
// network/Network.qml
import QtQuick
import Quickshell
import qs                          // for Theme

MouseArea { Rectangle { color: Theme.bg } /* uses NetworkService (sibling) */ }
```

### Save state across reloads

```qml
PersistentProperties {
    id: state
    reloadableId: "appState"
    property bool sidebarExpanded: false
    property real volume: 0.5
}
```

### IPC remote control

```qml
import Quickshell.Io

PanelWindow {
    id: bar
    visible: true
    IpcHandler {
        target: "bar"
        function show(): void   { bar.visible = true }
        function hide(): void   { bar.visible = false }
        function toggle(): void { bar.visible = !bar.visible }
        function getVisible(): bool { return bar.visible }
    }
}
```

```bash
qs ipc call bar toggle
qs ipc call bar show
qs ipc call bar getVisible    # → true
```

### Detached process launch

```qml
Button {
    text: "Open Firefox"
    onClicked: Quickshell.execDetached(["firefox"])
}

// or with full env
Quickshell.execDetached({
    command: ["myapp", "--flag"],
    workingDirectory: "/tmp",
    environment: { DISPLAY: ":0", PATH: null /* removes */ }
})
```

### Rounded transparent window

```qml
PanelWindow {
    color: "transparent"
    surfaceFormat.opaque: false           // only needed if going transparent later
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "#cc1e1e2e"
        border.width: 0                    // workaround for QTBUG-137166
    }
}
```

### Pipewire volume control

```qml
import Quickshell.Services.Pipewire

PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

Slider {
    enabled: Pipewire.defaultAudioSink?.audio
    from: 0; to: 1
    value: Pipewire.defaultAudioSink?.audio?.volume ?? 0
    onMoved: Pipewire.defaultAudioSink.audio.volume = value
}
Button {
    text: Pipewire.defaultAudioSink?.audio?.muted ? "🔇" : "🔊"
    onClicked: Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
}
```

### Battery widget

```qml
import Quickshell.Services.UPower

Text {
    visible: UPower.displayDevice.ready
    text: {
        const d = UPower.displayDevice
        const pct = Math.round(d.percentage)
        const charging = d.state === UPowerDeviceState.Charging
        return (charging ? "⚡ " : "🔋 ") + pct + "%"
    }
}
```

---

## Tips for AI Agents

### Conventions & gotchas

1. **Always set `anchors` *before* properties that depend on the resulting size.** For `PanelWindow`, you usually want `anchors { top: true; left: true; right: true }` *and* `implicitHeight`.
2. **`PanelWindow.exclusiveZone` requires 1 or 3 anchors.** With both top *and* bottom anchored, the zone has no effect.
3. **When using `Variants`, declare `required property var modelData`.** Forgetting this gives a warning and the property isn't injected.
4. **Inside a `Variants` over `Quickshell.screens`, set `screen: modelData`.** Otherwise the window won't reliably go to the intended monitor.
5. **Don't access ids defined inside `Variants` from outside.** Use a `Singleton` or a property on the root `Scope` for shared state.
6. **Don't set `width`/`height`/`x`/`y`/`anchors` on the child of a `WrapperItem`/`WrapperRectangle`.** It's managed; set `implicitWidth`/`implicitHeight` instead.
7. **Use `RowLayout`/`ColumnLayout` over `Row`/`Column`.** Layouts pixel-align, preventing fractional offsets that blur subsequent items.
8. **`childrenRect` ⇒ binding loop.** Don't size a parent to it; use `implicitWidth`/`implicitHeight` of the child or a wrapper component.
9. **Type your `IpcHandler` functions.** `function foo(x: int): void {}` — without annotations, the function isn't registered.
10. **Hot reload preserves windows by `reloadableId`.** Set it on long-lived windows you want reused.
11. **Most service capability flags default to `false`.** `NotificationServer.actionsSupported` etc. must be opted into.
12. **`MprisPlayer.position` is NOT reactive on its own.** Drive a `FrameAnimation`/`Timer` that emits `positionChanged()` while playing.
13. **`process.running = true` while already running does nothing.** Toggle via `onRunningChanged: if (!running) running = true` to restart after exit.
14. **`Process.command` does not run via shell.** `["echo hello"]` won't work; use `["echo", "hello"]` or `["sh", "-c", "echo hello"]`.
15. **`Quickshell.iconPath(name, true)` returns empty string if missing.** Use this variant to avoid the purple/black "missing icon" square.
16. **`Quickshell.clipboardText` on Wayland is empty unless a qs window is focused.** Listen via change signal once focused.
17. **Singletons must use `pragma Singleton` AND root with `Singleton {}` type.** Without `pragma`, it's a normal type.
18. **Implicit imports**: any UpperCase neighboring `.qml` file is auto-importable. `qs.path.to.module` (v0.2+) is preferred over `"path/to/module"` for LSP-friendliness.
19. **Don't use root-imports (`import "root:/..."`)** — they break the LSP and singletons. Use `qs.foo.bar`.
20. **`.qmlls.ini`**: leave as an empty file next to `shell.qml`; Quickshell rewrites it. Gitignore it.
21. **`LazyLoader` doesn't start loading until a window has been created.** If your entire shell is in lazy loaders, nothing loads.
22. **Reading `LazyLoader.item` while it's loading blocks the UI thread.** Use the `activeAsync` + `activeChanged` signal pattern instead.
23. **`WlSessionLock`'s session lock is *secure* by design**: if your config crashes, the screen stays locked and inoperable. Test carefully.
24. **`PopupAnchor.item` snapshot**: if the anchor item moves, popup won't follow. Call `anchor.updateAnchor()` or anchor to the window with custom logic in the `anchoring` signal.
25. **`Notification` is `Retainable`**: to animate-out, wrap it in a `RetainableLock { object: notif; locked: true }`.

### Hard-won gotchas (project-tested in v0.2.1)

These are non-obvious failures that cost real debugging time and aren't surfaced clearly elsewhere.

26. **Property names starting with `on` collide with QML's signal-handler syntax.** A property called `onAccent` parses as a (non-existent) signal handler for an `accent` signal and produces:
    > `Cannot assign a value to a signal (expecting a script to be run)`

    Rename to `accentText` / `onAccentColor` / etc. — anything that doesn't start with `on` followed by a word boundary.

27. **`required property X` whose name matches an `id` in the parent scope shadows the id at binding time.**

    ```qml
    // shell.qml
    Niri { id: niri }                       // singleton-like service
    Bar { niri: niri }                      // ← right-hand `niri` resolves to Bar's
                                            //   own (uninitialized) property, not the id.
    ```

    Symptom: `TypeError: Cannot read property 'foo' of undefined` from inside `Bar.qml`. Disambiguate by renaming either the id (`niriService`) or the property.

28. **Inline self-referential `Component` is rejected at parse time.** This fails:

    ```qml
    // TrayMenu.qml
    Component { id: subComp; TrayMenu {} } // → "TrayMenu is instantiated recursively"
    ```

    Use `Qt.createComponent("TrayMenu.qml")` for runtime resolution if a type needs to spawn instances of itself (recursive submenus, tree views, etc.).

29. **`PopupAnchor::setItem(nullptr)` crashes Quickshell when an item was previously set.** In v0.2.1 (and master) the internal `onItemWindowChanged` slot dereferences `mItem` after it's been nulled:

    ```cpp
    void PopupAnchor::setItem(QQuickItem* item) {
        ...
        this->mItem = item;            // can be nullptr
        this->onItemWindowChanged();   // calls mItem->window() → SIGSEGV
    }
    ```

    Workaround: **never explicitly assign `null` to a popup's `anchor.item`** while it currently holds a valid item. Hide via `visible: false` instead. Natural destruction of the anchor item (the `destroyed` signal path) is handled correctly.

30. **Don't mutate popup state during event delivery — use `Qt.callLater`.** Tearing down a popup (or clearing references that propagate to a popup's `anchor.item`) inside a `MouseArea` `onClicked` can crash via Quickshell's PopupAnchor reading items mid-destruction. Wrap the teardown:

    ```qml
    onClicked: Qt.callLater(() => {
        trayMenu.closeSubmenus();
        root.activeItem = null;
    })
    ```

    The click event finishes propagating cleanly before any destruction.

31. **`IconImage.source` does NOT auto-resolve theme icon names.** Passing `"audio-volume-high-symbolic"` is interpreted as a relative file path under the QML import dir and fails. Always wrap:

    ```qml
    IconImage { source: Quickshell.iconPath("audio-volume-high-symbolic", true) }
    ```

32. **`IconImage`'s broken-image placeholder leaks through `visible: status === Image.Ready`.** A "random checkerboard grid" briefly renders before status changes. Wrap the IconImage in an `Item` gated on the source string itself:

    ```qml
    Item {                                  // gate at the wrapper, not the IconImage
        width: src !== "" ? 14 : 0
        height: 14
        visible: src !== ""
        IconImage { anchors.fill: parent; source: src; asynchronous: false }
    }
    ```

33. **`asynchronous: true` on small icons risks a SIGSEGV with thread-safety races.** The async `QQuickPixmapReader` thread can deliver to a destroyed parent Item. For ≤48px icons (tray, notifications, menu entries) prefer `asynchronous: false`.

34. **`Behavior` on a `readonly property` is rejected.** ("Invalid property assignment: ... is a read-only property"). Apply the `Behavior` on the consumer (the actual property being animated), not on the readonly source:

    ```qml
    readonly property color stroke: active ? Theme.accent : Theme.text
    Rectangle { color: parent.stroke; Behavior on color { ColorAnimation {} } }
    ```

35. **`pragma Singleton` only auto-imports to siblings.** A singleton at the root of the qs namespace is auto-available to other root files but **NOT** to files in subdirectories. Subdir files need `import qs` (for root-level singletons) or `import qs.<subdir>` (for singletons in another subdir).

36. **Each subdirectory of the shell automatically becomes a Quickshell module.** No `qmldir` files needed. `import qs.foo` exposes everything in `<shell>/foo/`. Within a single subdir, files are siblings to each other and need no internal imports.

37. **`Repeater.model` bound to a function call doesn't always track inner property reads.** Read a model's `.values` directly inside the binding to be safe:

    ```qml
    Repeater {
        model: {
            const ids = NotificationService.popupIds;     // touch the dependency
            return NotificationService.trackedNotifications.values
                .filter(n => ids.indexOf(n.id) >= 0);
        }
    }
    ```

38. **Singletons are lazy.** A `pragma Singleton` file containing a long-running `Process { running: true }` won't actually start the process until the singleton is referenced from another file. Reading any property triggers initialization.

39. **`ObjectModel<T>` cleanup signals are signals on the model, not on items.** Connect via `Connections`:

    ```qml
    Connections {
        target: server.trackedNotifications
        function onObjectRemovedPost(obj, index) { /* purge id from auxiliary maps */ }
    }
    ```

### Compositor / system gotchas

40. **NetworkManager auto-deletes ad-hoc `Wired connection N` profiles on `nmcli connection down`.** Use `nmcli device disconnect <device>` instead, and `nmcli device connect <device>` to reactivate. Device-level commands don't touch the underlying profile.

41. **StatusNotifierItem icon path extension `name?path=<dir>` is not auto-resolved by Quickshell** in v0.2.1 (logs `Searching custom icon paths is not yet supported`). You'll see the warning for Steam tray icons specifically. Manually parse the URL and build a `file://...` path:

    ```js
    function resolveTrayIcon(s) {
        if (!s || s.indexOf("?path=") < 0) return s;
        let name = s.substring(0, s.indexOf("?"));
        if (name.startsWith("image://icon/")) name = name.substring(13);
        const path = decodeURIComponent(s.substring(s.indexOf("?path=") + 6));
        return "file://" + path + "/" + name + ".png";
    }
    ```

42. **Adwaita symbolic SVGs hardcode `fill="#222222"`**, NOT `currentColor`. They render dark on dark themes via Qt's SVG renderer. breeze-dark icons use `fill="currentColor"` + a CSS `.ColorScheme-Text { color: #fcfcfc }` and DO render in the right color. If you need an Adwaita-only icon in a dark bar, copy the SVG locally and replace the fill with `#fcfcfc`.

43. **Only one daemon can own `org.freedesktop.Notifications` on D-Bus.** If swaync/dunst/mako is running, Quickshell's `NotificationServer` will log:

    > `Could not register notification server at org.freedesktop.Notifications, presumably because one is already registered.`

    `pkill swaync` (etc.) and Quickshell will auto-claim the name on the next D-Bus owner change.

44. **System tray host coexistence**: Quickshell registers a `StatusNotifierHost-<pid>-<n>` per shell. Multiple hosts can coexist (waybar + qs both showing trays). Items broadcast to all. To fully transition off another bar, kill its tray host explicitly.

45. **`pragma Singleton` MUST be the first non-blank, non-comment statement — and the qmlscanner does NOT strip `//` line comments before tracking braces.** A `{` anywhere in a file-header `//` comment (e.g. `// returns array<{ id, preview }>`) makes the scanner think you're already inside a QML object, so the pragma is silently ignored. The synthesized qmldir then registers your file as a regular type, not a singleton:

    ```text
    # broken: ClipboardService 1.0 ClipboardService.qml
    # working: singleton ClipboardService 1.0 ClipboardService.qml
    ```

    At runtime, references to the "singleton" resolve to the type name (an opaque object whose `Object.keys(...)` returns `[]`); calls like `ClipboardService.openPopup()` throw `TypeError: Property 'openPopup' of object ClipboardService is not a function`. The `}` in the same comment does NOT rebalance — once the brace count goes off, the scanner is lost.

    **Fix**: put `pragma Singleton` on the very first non-blank line of the file (above the header comment block), or rewrite any `{`/`}` in pre-pragma comments. Diagnose with `qs -p <path> -vv 2>&1 | grep "intercept.*qmldir"` and look for the missing `singleton` keyword.

46. **niri's `WindowFocusChanged` event fires with `id: null` when one of YOUR layer-shell surfaces takes keyboard focus.** If you're naively using this event to dismiss popups (e.g. "close popup when user focuses an app"), opening a `PanelWindow` with `WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand` will immediately self-dismiss the popup you just opened: niri reports "no toplevel focused" right after the layer surface grabs focus, and a moment later it bounces back to the previously-focused toplevel.

    Workaround: filter `id === null` in your event handler so only real toplevel focus changes trigger dismissal:

    ```qml
    } else if (event.WindowFocusChanged) {
        const id = event.WindowFocusChanged.id;
        if (id !== null && id !== undefined) root.windowFocused(id);
    }
    ```

    Tradeoff: you also lose dismissal on "user switched to a truly empty workspace" (which also reports `id: null`), but in practice popups overlap the bar and the bar is anchored on every workspace anyway.

47. **`qs ipc call` connects to the *oldest* matching instance unless you pass `-n`/`--newest`.** During development you'll often have stale sockets/by-pid symlinks left over from killed processes; `/run/user/$UID/quickshell/by-pid/<pid>` symlinks aren't auto-cleaned. The `qs ipc -vv ...` log shows which instance it picked.

    Diagnose: `ls /run/user/$UID/quickshell/by-pid/` — any pids that aren't running are stale. Clean with:

    ```bash
    for link in /run/user/$UID/quickshell/by-pid/*; do
        pid=$(basename "$link")
        kill -0 "$pid" 2>/dev/null || rm -f "$link" "$(readlink "$link")"
    done
    ```

48. **`WlSessionLock` instantiates per-screen surfaces via its `surface: Component { ... }`, NOT a `Variants { model: Quickshell.screens }` block.** `WlSessionLock` is itself per-shell (one instance owns the protocol-level lock); the compositor asks for one surface per output and Quickshell instantiates the Component for each. Wrapping `WlSessionLock` in `Variants` gets you N independent locks racing each other for the protocol; only one wins, the others log errors.

    ```qml
    WlSessionLock {
        locked: LockService.locked
        surface: Component { LockSurface { } }   // <-- one Component, fans out
    }
    ```

49. **`PamContext` auto-restarts the conversation after a `Failed` result, firing a fresh `onMessageChanged` with `"Password:"` within microseconds.** If your lock UI clears its error state inside `onMessageChanged` ("a fresh prompt means the previous error is no longer relevant"), the red "Authentication failed" label vanishes faster than the eye can register. Two viable patterns:

    - Store the error in service-level state and clear it only when the user submits a new attempt (in `respond()`); the error is a property of "the most recent attempt" and persists until superseded.
    - Hold the error in a Timer-bound transient state for ~1.5 s before clearing.

    The first pattern is cleaner.

50. **`pam_unix.so` enforces a ~2 s delay on every auth failure** (`FAIL_DELAY` in `/etc/login.defs`, applied via `pam_faildelay.so` or `pam_unix`'s own jitter). Your lock UI MUST acknowledge this — if you clear the password field on Enter and show no other feedback, users see a frozen-looking screen for 2 s and assume the lock is broken. Two acceptable patterns:

    - Lock the input (`readOnly: pamChecking` + dim opacity) until `onCompleted` fires. The user can clearly see their input was received and the result is pending.
    - Add `nodelay` to your PAM service file (replace `auth include login` with `auth required pam_unix.so nodelay`). Removes the delay entirely. Mild security trade-off — physical attacker can brute-force faster — usually acceptable for a screen lock since physical access already breaks most assumptions.

51. **`MultiEffect` (and any `layer.effect`) requires `layer.enabled: true` on its source item.** The shader samples a texture; without `layer.enabled` there's no offscreen render-target to sample from, and the effect silently no-ops. Easy to miss because the source still renders normally — just unblurred.

    ```qml
    Image {
        source: "..."
        layer.enabled: true                    // <-- required
        layer.effect: MultiEffect {
            blurEnabled: true; blur: 1.0; blurMax: 64
        }
    }
    ```

52. **`WlSessionLock` automatically updates systemd-logind's `LockedHint` property when `locked` toggles.** No manual `loginctl lock-session` call needed; system tools that respect lock state (notification daemons that suppress display when locked, dbus-monitor watchers, MPRIS hints, etc.) will see the change. Verify with `loginctl show-session $XDG_SESSION_ID -p LockedHint`. The reverse is NOT true: a manual `loginctl lock-session` invocation from elsewhere will NOT trigger your `WlSessionLock` — they're sibling APIs both feeding into the same logind state. To honor external `lock-session` requests, subscribe to logind's `Lock` D-Bus signal separately.

53. **`waypaper` writes the active wallpaper as a single line in `~/.config/waypaper/config.ini`** under the `[Settings]` section: `wallpaper = /absolute/path/to/image.ext` (`~`-relative paths are NOT expanded by waypaper itself but appear as-typed if you set them via the GUI). Useful for any shell component that needs to know the desktop wallpaper (lock screen blur background, color sampler, MPRIS art fallback, etc.). Re-read on demand via `FileView` with `watchChanges: true`. If waypaper isn't installed, fall back to parsing `pgrep -af 'swaybg|swww|hyprpaper'` arguments — fragile but works.

### Style & best practices

- **Singletons for shared state** (clock, audio, theme, system info). Namespace them clearly.
- **Split files when a single file exceeds ~150 lines.** UpperCase filenames become types; lowercase filenames are JS modules.
- **Cache process output, don't re-spawn per refresh.** Reuse a single `Process { running: true }` driven by a `Timer`.
- **Prefer the included service singletons** (`Mpris`, `SystemTray`, `Notifications`, `Pipewire`, `UPower`) over manually shelling out.
- **For unsupported compositors**, build IPC via `Socket` or `Process` + `SplitParser`.

### Required QML imports cheat-sheet

```qml
import QtQuick                               // base visuals
import QtQuick.Layouts                       // RowLayout/ColumnLayout
import QtQuick.Controls                      // Button, Slider, TextField
import QtQuick.Effects                       // MultiEffect, RectangularShadow
import Qt5Compat.GraphicalEffects            // (if qt5compat installed) older effects
import Quickshell                            // PanelWindow, Variants, ShellRoot, ...
import Quickshell.Io                         // Process, FileView, IpcHandler, ...
import Quickshell.Wayland                    // WlSessionLock, ToplevelManager, WlrLayershell
import Quickshell.Hyprland                   // Hyprland.*
import Quickshell.I3                         // I3.*
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Pam
import Quickshell.Services.Greetd
import Quickshell.Bluetooth
import Quickshell.DBusMenu
import Quickshell.Widgets                    // IconImage, WrapperRectangle, ...
```

### Useful environment variables

| Var | Purpose |
|---|---|
| `QS_NO_RELOAD_POPUP=1` | suppress the after-reload notification popup |
| `QS_ICON_THEME=<name>` | force icon theme (or use `//@ pragma IconTheme`) |

### Distribution targets

If shipping a config:

- Pin a Quickshell version (Nix: revision in flake input; Arch: package alongside).
- Put the config in `$XDG_CONFIG_HOME/quickshell/<your-name>/`. Run with `qs -c <your-name>`.
- For system-wide distribution: `/etc/xdg/quickshell/<name>/`.

---

*Generated from <https://quickshell.org/docs/v0.2.1/>. Quickshell is pre-1.0 — APIs may break between versions; consult the upstream changelog.*
