# AGENTS.md

Quickshell-bar — a QML-based Wayland desktop shell (no compile, no lint, no test suite). Built on [Quickshell](https://quickshell.org/) ≥ 0.3.0. Full contributor guide at [`docs/AGENTS.md`](docs/AGENTS.md); companion files: [`docs/STYLE.md`](docs/STYLE.md) (visual conventions + recipes) and [`docs/QUICKSHELL_REFERENCE.md`](docs/QUICKSHELL_REFERENCE.md) (API + gotchas).

## Verification (smoke-test)

```
qs -p /path/to/quickshell-bar > /tmp/qs-smoke.log 2>&1 &
PID=$!; sleep 4; kill $PID 2>/dev/null; wait 2>/dev/null
grep -iE "warn|error|TypeError|caused by|ReferenceError" /tmp/qs-smoke.log | \
  grep -v "QSettings\|already registered\|Registration will\|launcher-frecency\|propertyCache\|qt.svg.draw\|QThreadStorage"
```

Empty = clean. Filtered noise is expected Quickshell/Qt startup chatter.

## Architecture rules agents commonly break

- **Subdir = QML module.** Every subdirectory under root is automatically a `qs.<subdir>` module.
- **State always in singleton services, never in visual components.** Service → `${dir}/${Name}Service.qml` (singleton). Popup → `${dir}/${Name}Popup.qml`. Widget → `${dir}/${Name}.qml`.
- **`pragma Singleton` MUST be line 1** of the file. Header comments below it MUST NOT contain `{` or `}` — the qmlscanner doesn't strip comments before brace-counting, and a brace in a comment silently breaks singleton registration. Symptom: `Cannot read property 'foo' of undefined`.
- **Hot-reload does NOT refresh qmldir cache.** Adding a new singleton or moving pragma placement requires daemon restart. When in doubt, smoke-test on a fresh `qs` invocation.
- **Never reference compositor-specific APIs** (`Hyprland.*`, `I3.*`, `niri msg`) outside `compositor/Backend*.qml`. Everything goes through `Compositor.*`.
- **`kill -HUP` terminates the daemon** — it does NOT trigger reload. Use `qs kill --shell <id>` or just save a file.
- **Every Theme token must route through `Local.get(key, default)`** so it's overridable via `~/.config/quickshell-bar/config.jsonc` and visible in the Settings page.
- **IPC handlers need typed signatures**: `function open(): void { ... }` — without `: void` the function is silently not registered.

## Popup recipe

```
function toggle() {
    if (popup.wantOpen) { popup.wantOpen = false; }
    else { PopupController.open(popup, () => popup.wantOpen = false); popup.wantOpen = true; }
}
onVisibleChanged: if (!visible) PopupController.closed(popup)
```

Every popup participates in the PopupController mutex — only one open at a time.

## Git workflow

- **Never commit on master.** Always `git checkout -b <area>/<topic>` first. See [`docs/GIT_WORKFLOW.md`](docs/GIT_WORKFLOW.md).
- Commit style: `<area>: <imperative summary>` (e.g. `notifications: bell uses Font Awesome`).
- Areas: `theme`, `bar`, `popup`, `lock`, `media`, `volume`, `network`, `bluetooth`, `system`, `notifications`, `clipboard`, `launcher`, `osd`, `tray`, `workspaces`, `clock`, `compositor`, `docs`, `settings`, `themes`, `wallpaper`, `weather`, `controlcenter`, `polish`, `chore`.
- Smoke-test every change before committing.

## Default do-not-touch without asking

- `LICENSE`, `NOTICE`, `Theme.qml` color/font/animation defaults
- The compositor abstraction interface (`Compositor.workspaces` shape, signal names)
- IPC handler names (`qs ipc call lock open`, etc.) — public API
- `Slider.qml`, `ProgressBar.qml`, `BarIcon.qml`, `BarTooltip.qml` APIs
- CC tile order and view-stack keys
- `examples/*` formatting — copy-paste targets for users
