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

## Tile recipe

For the Control Center grid (`controlcenter/Tile.qml`). Tiles encode three
things at once: a primary toggle/cycle action (the **body**), a state read-
out, and an optional secondary action via a chevron in the top-right corner
(opens a CC detail view).

### Two-zone click pattern

Tiles use **two stacked `MouseArea`s**:

```qml
Rectangle {
    id: root
    // ... visual ...

    // Body click — primary action (toggle, cycle, etc.). Declared FIRST,
    // which puts it lower in z-order so the chevron MouseArea below wins
    // its 32×32 corner region.
    MouseArea {
        id: bodyMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // Chevron click — secondary action (open detail view). Declared SECOND,
    // sits on top in its top-right corner. Only rendered/active when the
    // tile's `showChevron` is true.
    MouseArea {
        id: chevronMa
        visible: root.showChevron
        enabled: root.showChevron
        anchors.right: parent.right
        anchors.top: parent.top
        width: 32
        height: 32
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.chevronClicked()
    }
}
```

The same body-vs-region pattern shows up in `weather/WeatherCard.qml`
(body → openDetail; city pill / refresh button = sub-regions) but with the
body MouseArea at `z: -1` and child sub-region MouseAreas at default z.
Both ordering tricks work; pick whichever reads clearer for a given file.

### Tile properties contract

```qml
Tile {
    icon: "\uf1eb"                  // FA Solid glyph (or Brands if `brand: true`)
    brand: false
    label: "Wi-Fi"                  // bold top-row label
    stateText: "MyNetwork"          // dim bottom-row state value
    active: NetworkService.wifiEnabled  // accent fill when true
    showChevron: true                   // shows ">" + enables chevron click zone
    iconColor: Theme.text               // optional override
    onClicked:        NetworkService.toggleWifi()
    onChevronClicked: ControlCenterService.setView("network")
}
```

### Active-state colour invert

When `active`, the tile fills with `Theme.accent` and label/state colour
flip to `Theme.accentText`. This matches the same pattern the wallpaper
picker's selector pills use — consistent muscle-memory across the shell
("filled = on").

### When to add a chevron

| Tile type | Body action | Chevron? |
|---|---|---|
| Pure toggle (Caffeine, DND) | toggle on/off | no |
| Pure picker (Wallpaper) | open external popup | no |
| Toggle + has detail list (Wi-Fi, Bluetooth) | toggle radio/adapter | yes (opens detail view) |
| Cycle + has explicit picker (Power Profile) | cycle through values | yes (opens 3-radio view) |

If the tile *only* opens a detail view (no in-place primary action), give
the body that action and skip the chevron entirely — fewer affordances.

---

## Card recipe

The card shape — `Rectangle` with `Theme.surface` fill, `Theme.border`
border, `Theme.radiusSmall` rounded corners — recurs in 3+ places:

| File | Card |
|---|---|
| `weather/WeatherCard.qml` | weather summary inside CC |
| `lock/NowPlayingCard.qml` | MPRIS card on lock screen + inside CC |
| `lock/LockSurface.qml` | password input glassy panel |
| `notifications/NotificationCard.qml` | notification stack item |

### Standard card

```qml
Rectangle {
    id: card

    color: Theme.surface
    border.color: Theme.border
    border.width: 1
    radius: Theme.radiusSmall

    height: 64                       // pick a fixed height per content shape

    // Content goes inside, anchored with `anchors.margins: 10` typically
    Item {
        anchors.fill: parent
        anchors.margins: 10
        // ...
    }
}
```

### Glassy variant (lock screen)

When sitting over a blurred wallpaper rather than `Theme.bg`, swap to
white-tint translucent fill so the underlying blur shows through:

```qml
Rectangle {
    color: Qt.rgba(1, 1, 1, 0.10)
    border.color: Qt.rgba(1, 1, 1, 0.18)
    border.width: 1
    radius: 14                       // larger radius reads as "glassy"
}
```

### Click semantics

If the card is clickable as a whole, wrap with a body `MouseArea` (z=-1)
and let nested controls (buttons, pills) win their sub-regions at default
z — same as the Tile recipe above.

```qml
MouseArea {
    id: bodyMa
    anchors.fill: parent
    z: -1                            // sub-region MouseAreas at default z=0 win
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: someService.openDetail()
}
```

### Auto-hide pattern

Cards that show contextual data (Now Playing, weather pre-set-location)
can hide themselves cleanly:

```qml
visible: SomeService.hasData    // collapses to 0 height inside a Column
```

Inside a parent `Column`, an invisible card takes 0 vertical space — the
popup naturally compacts when the card is hidden.

---

## View-stack recipe

For popups that swap between multiple "screens" with back-navigation —
e.g. tile grid → Wi-Fi detail → back. Used by `controlcenter/ControlCenterPopup.qml`.

### Architecture

The state lives on a singleton:

```qml
// Singleton
Singleton {
    property string currentView: "tiles"     // "tiles" | "network" | …
    function setView(name) { currentView = name; }
    function goBack() { currentView = "tiles"; }
}
```

The popup renders a `Loader` keyed on a *mirror* of `currentView`, swapped
mid-animation so the visible content fades out before changing:

```qml
Loader {
    id: viewLoader

    // Mirror, not the singleton property directly. Updated by the
    // animation's ScriptAction when opacity is 0 — that's how we get
    // a clean fade-out → swap → fade-in sequence.
    property string _appliedView: SomeService.currentView

    sourceComponent: switch (_appliedView) {
        case "network":   return networkViewC;
        case "bluetooth": return bluetoothViewC;
        default:          return tilesViewC;
    }

    opacity: 1.0

    Connections {
        target: SomeService
        function onCurrentViewChanged() {
            if (SomeService.currentView === viewLoader._appliedView) return;
            if (!popup.wantOpen) {
                // Popup not open — sync immediately so the next open
                // shows the right view from frame 0.
                viewLoader._appliedView = SomeService.currentView;
                return;
            }
            transition.restart();
        }
    }

    SequentialAnimation {
        id: transition
        NumberAnimation { target: viewLoader; property: "opacity"; to: 0.0; duration: 100; easing.type: Easing.InCubic }
        ScriptAction { script: viewLoader._appliedView = SomeService.currentView }
        NumberAnimation { target: viewLoader; property: "opacity"; to: 1.0; duration: 140; easing.type: Easing.OutCubic }
    }
}

Component { id: tilesViewC;     TilesView { } }
Component { id: networkViewC;   NetworkView { } }
Component { id: bluetoothViewC; BluetoothView { } }
```

### Why the mirror

`Behavior on sourceComponent` does NOT fire — Component isn't an
interpolatable type (gotcha #65). The mirror property + ScriptAction
swap is the canonical workaround.

### Header back-arrow

When `currentView !== "tiles"`, surface a back arrow in the popup's header
that calls `goBack()`. Pair the arrow's visibility with a title text that
swaps to match the current view:

```qml
Item {
    Rectangle {
        id: backBtn
        visible: SomeService.currentView !== "tiles"
        // ... arrow glyph + click → SomeService.goBack() ...
    }
    Text {
        anchors.left: backBtn.visible ? backBtn.right : parent.left
        text: {
            switch (SomeService.currentView) {
                case "network":   return "Wi-Fi";
                case "bluetooth": return "Bluetooth";
                default:          return "Settings";
            }
        }
    }
}
```

### Reset on (re)open

The popup's `toggle()` should call `SomeService.resetView()` (or set
currentView = "tiles" directly) before flipping `wantOpen` on, so each
open starts at the predictable default view.

---

## Extracted view recipe

When a popup's content needs to be **embedded inside another popup**
(typically the CC's view-stack), extract the content into a pure Item that
takes the parent surface's chrome on faith. Used by `network/NetworkView.qml`,
`bluetooth/BluetoothView.qml`, `system/PowerProfileView.qml`,
`weather/CitiesView.qml`.

### What stays, what goes

| In the original Popup | Extracted view |
|---|---|
| `PopupWindow { ... }` outer | dropped (host supplies the surface) |
| Card chrome (Rectangle, border, radius, MultiEffect shadow) | dropped (host supplies the chrome) |
| Header (title text, refresh button) | dropped (host's header has its own switch on `currentView`) |
| `wantOpen` / `hideHold` / `toggle()` | dropped (host owns visibility) |
| The actual content `Column` / `Flickable` | **kept** — this is the extracted view |
| Inline `component XxxRow: Rectangle { ... }` | **kept** |

### Skeleton

```qml
import QtQuick
import qs

Item {
    id: view

    // Per-instance state (e.g. password-prompt SSID, expansion flags)
    property string somePromptKey: ""

    // Lifecycle hooks: this view is constructed when navigated *to*,
    // destroyed on `goBack()`. Use Component.onCompleted for "do this
    // once when the view appears" (e.g. trigger a fresh scan).
    Component.onCompleted: {
        SomeService.refreshAll();
    }

    Timer {
        running: true
        interval: 8000
        repeat: true
        onTriggered: SomeService.refreshAll()
    }

    // Inline components (rows, headers) live here — they're now
    // package-private to this view file.
    component RowItem: Rectangle { ... }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentColumn
            width: parent.width
            spacing: 10
            // ... actual content ...
        }
    }
}
```

### Hosting the view

The view-stack popup's Loader treats `View.qml` files as Components:

```qml
Component { id: networkViewC; NetworkView { } }
```

The Loader instantiates with `anchors.fill: parent` (set on the Loader
itself) so the view fills the popup body. View files don't anchor
themselves — they assume their host did.

### Width assumption

Extracted views are bound to the host popup's inner width. CC views fit
the 412 px width they get; popups smaller than the original popup width
(BluetoothPopup was 360, NetworkPopup was 380) get cramped — be willing
to widen the host or compress the content.

---

## Hoisted overlay recipe

Pattern for any "popup-within-popup" — a colour picker, a dropdown
list, a context menu, a search-result flyout. The overlay needs to
visually float above the row that triggered it without being clipped or
buried by sibling rows declared later in the same parent Column.

### The problem this solves

In QML, the `z` property only orders **siblings within the same
parent**. Consider the natural-feeling architecture:

```qml
Column {
    Row { id: rowA
        Rectangle { id: triggerA }
        Rectangle {            // overlay declared inside the row
            visible: someState
            z: 100
            anchors.top: triggerA.bottom
        }
    }
    Row { id: rowB }            // a later sibling row
    Row { id: rowC }            // another later sibling row
}
```

The overlay is a child of `rowA`. Its `z: 100` only puts it above
*siblings within rowA*. It is **not** above `rowB` or `rowC` — those
are later siblings of `rowA` in the Column, so QML draws their
subtrees after rowA's subtree, regardless of any z value inside rowA.
The overlay extends visually below rowA and is clipped / overdrawn by
rowB, rowC, and so on.

This bites every nested popup attempt. We hit it twice in the Settings
page (`ColorPicker` + `PresetDropdownList`), and the symptom is
identical both times: the overlay first appears partially obscured by
later rows, and clicks land on those rows rather than reaching the
overlay's controls.

### The architecture

The overlay must be hoisted out of the row entirely and rendered as a
child of a much wider container — typically the popup's outermost
Rectangle or Item. The trigger that opens it stays inside the row.
Communication routes through a service singleton that holds the open
state + payload + anchor reference.

```
┌── Popup card (Rectangle) ──────────────────────────┐
│                                                     │
│  Column {                                           │
│      Row { trigger A }                              │
│      Row { trigger B }      ← rows live here       │
│      Row { trigger C }                              │
│  }                                                  │
│                                                     │
│  Overlay {                  ← overlay lives HERE,  │
│      visible: service.open  ← as a sibling of      │
│      x: anchor.mapToItem(   ← the Column, declared │
│          card, 0, 0).x      ← AFTER it. z=1000 for │
│      ...                    ← extra safety.        │
│  }                                                  │
└────────────────────────────────────────────────────┘
```

### Components in the pattern

**Service singleton state** (one set per overlay kind):

```qml
// SomeService.qml
property bool overlayOpen: false
property var  overlayAnchor: null     // the trigger Item
property var  overlayPayload: null    // whatever the overlay needs

function openOverlay(payload, anchor) {
    if (overlayOpen && overlayPayload === payload) {
        closeOverlay();      // toggle on same-trigger click
        return;
    }
    overlayPayload = payload;
    overlayAnchor = anchor;
    overlayOpen = true;
}
function closeOverlay() {
    overlayOpen = false;
    overlayAnchor = null;
}
```

**Trigger inside the row** — delegates to the service, never embeds the
overlay itself:

```qml
// SomeRow.qml
Rectangle {
    id: trigger
    MouseArea {
        anchors.fill: parent
        onClicked: SomeService.openOverlay(rowPayload, trigger)
    }
}
```

**Overlay component** — purely presentational, never writes to its own
visibility (gotcha #68):

```qml
// SomeOverlay.qml
Rectangle {
    id: overlay
    width: 240
    height: 180
    radius: Theme.radius
    color: Theme.bg
    border.color: Theme.border
    border.width: 1

    // Catch-all so clicks on the overlay's chrome don't pass through.
    MouseArea { anchors.fill: parent; onClicked: { /* swallow */ } }

    signal closeRequested
    signal somethingPicked(var value)

    // ... actual controls (with their own MouseAreas declared LATER
    //     so they win the hit-test in their regions)
}
```

**Hosting at the popup root** — declared AFTER the Column / Flickable
of rows so it draws on top:

```qml
// SomePopup.qml
Rectangle {
    id: card

    Column { ... rows ... }           // declared FIRST

    SomeOverlay {                     // declared SECOND
        id: overlay
        z: 1000                       // belt + braces
        visible: SomeService.overlayOpen   // bound, never assigned
        onCloseRequested: SomeService.closeOverlay()
        onSomethingPicked: v => Local.set(...)

        x: {
            if (!SomeService.overlayAnchor) return 0;
            const p = SomeService.overlayAnchor.mapToItem(card, 0, 0);
            const maxX = card.width - width - 16;
            return Math.max(16, Math.min(p.x, maxX));
        }
        y: {
            if (!SomeService.overlayAnchor) return 0;
            const p = SomeService.overlayAnchor.mapToItem(card, 0, 0);
            const proposed = p.y + SomeService.overlayAnchor.height + 6;
            const maxY = card.height - height - 16;
            // Flip above the trigger if natural position pushes off
            // the bottom — common for triggers near the popup's
            // bottom edge.
            if (proposed > maxY) {
                return Math.max(16, p.y - height - 6);
            }
            return proposed;
        }
    }
}
```

The two clamps in the position bindings (`Math.max(16, Math.min(...))`
on the X and the natural-vs-flipped check on the Y) keep the overlay
inside the card's painted area so the user always sees the whole
thing.

### Dismiss strategies (in order of preference)

1. **Done button inside the overlay**. Emits `closeRequested`; the host
   calls `Service.closeOverlay()`. Never write to `visible` from the
   overlay component.
2. **Esc key**. The popup's existing `Keys.onPressed` handler closes
   the innermost overlay first, then falls through to closing the
   popup. Layered close.
3. **Same-trigger click toggles closed**. Built into `openOverlay`'s
   first check (see service singleton above).
4. **Different-trigger click switches**. `openOverlay` updates anchor +
   payload; the position bindings re-evaluate via `mapToItem`.
5. **Tab change / active scroll auto-closes**. The anchor's
   coordinates would otherwise drift relative to the card; close so
   the overlay doesn't float away from the trigger:

   ```qml
   Connections {
       target: someService
       function onActiveTabChanged() { someService.closeOverlay(); }
   }
   Connections {
       target: contentFlick
       function onContentYChanged() {
           if (contentFlick.moving) someService.closeOverlay();
       }
   }
   ```

### What NOT to do

- **Don't add a transparent "click outside" `MouseArea` over the whole
  popup**. It catches clicks meant for sibling triggers (other
  swatches, other dropdowns) and consumes them, so the click that
  should switch the overlay just dismisses it instead. The user has
  to click twice. We tried this; it's the bug behind the original
  ColorPicker "doesn't reopen until shell reload" report.
- **Don't write to a bound visibility property** (`open: false` or
  `visible: false`) from inside the overlay component. Gotcha #68 —
  the assignment silently breaks the binding. Emit a signal instead.
- **Don't use `parent.parent.parent` to reach the host**. Gotcha #66 —
  `Repeater` delegate parent chains are fragile. Use an `id` and
  reference it directly.
- **Don't put the overlay inside a `Flickable`'s clipped content**.
  The Flickable's `clip: true` will cut the overlay if it extends past
  the visible content area. Hoist OUT of the Flickable, into the popup
  card directly.

### Real-world references in this repo

- `settings/controls/ColorPicker.qml` — overlay component (HSV picker)
- `settings/controls/ColorRow.qml` — trigger (swatch click delegates to service)
- `settings/controls/PresetDropdownList.qml` — overlay component (preset list)
- `settings/controls/PresetDropdown.qml` — trigger (button click delegates to service)
- `settings/SettingsService.qml` — `openPicker` / `closePicker` / `openDropdown` / `closeDropdown` + state
- `settings/SettingsPopup.qml` — both overlays hoisted at the card root, position bindings, dismiss connections

Both follow the recipe to the letter.

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
