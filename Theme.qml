// Theme.qml
// Single source of truth for palette + sizing.
// Pure grayscale + white accent — meant to fit any wallpaper.
//
// Every value below is overridable via `Local.get(<key>, <default>)` —
// users put a key into `~/.config/quickshell-bar/config.json` to swap
// it for their machine without touching this file. See
// `docs/CUSTOMIZATION.md` for the full key list.

pragma Singleton

import QtQuick
import Quickshell
import qs

Singleton {
    // ---- Backgrounds ----
    readonly property color bg:           Local.get("bg",         "#16181c")  // bar / popup base
    readonly property color surface:      Local.get("surface",    "#1e1e22")  // hover state, mild elevation
    readonly property color surfaceHi:    Local.get("surfaceHi",  "#26262a")  // pinned / pressed state

    // ---- Lines ----
    readonly property color border:       Local.get("border",     "#2a2a2e")

    // ---- Text ----
    readonly property color text:         Local.get("text",       "#fcfcfc")  // primary (matches breeze-dark icon foreground)
    readonly property color textDim:      Local.get("textDim",    "#909090")  // secondary
    readonly property color textMuted:    Local.get("textMuted",  "#5e5e5e")  // very subtle (separators, weekend)

    // ---- Accent (white) ----
    readonly property color accent:       Local.get("accent",     "#ffffff")  // focused / today highlight
    readonly property color accentText:   Local.get("accentText", "#16181c")  // text drawn on top of accent fill

    // ---- Error / warning (used by lock auth, low-battery, etc.) ----
    readonly property color error:        Local.get("error",       "#ff5050")  // borders, strokes
    readonly property color errorBright:  Local.get("errorBright", "#ff7070")  // text on dark backgrounds

    // ---- Workspace pip states ----
    readonly property color pipIdle:      Local.get("pipIdle",    "#2a2a2e")
    readonly property color pipActive:    Local.get("pipActive",  "#3a3a3e")  // active on output but not focused
    readonly property color pipFocused:   Local.get("pipFocused", "#ffffff")  // = accent

    // ---- Geometry ----
    readonly property int barHeight:   Local.get("barHeight",   32)
    readonly property int radius:      Local.get("radius",      6)
    readonly property int radiusSmall: Local.get("radiusSmall", 4)

    // ---- Animations ----
    readonly property int animFast: Local.get("animFast", 100)
    readonly property int animMed:  Local.get("animMed",  140)

    // ---- Fonts ----
    // Single mono typeface for the whole shell. Iosevka has a deep weight
    // ladder (Thin → Heavy + italics + Mono / Propo variants) which lets
    // us express hierarchy without switching family. Glyph widget icons
    // come from Font Awesome 7 (Free Solid for most, Brands only when a
    // glyph isn't available in Free — currently just Bluetooth).
    readonly property string fontMono:  Local.get("fontMono",  "Iosevka Nerd Font")
    readonly property string fontIcon:  Local.get("fontIcon",  "Font Awesome 7 Free")     // styleName: "Solid"
    readonly property string fontBrand: Local.get("fontBrand", "Font Awesome 7 Brands")

    // ---- Font sizes (4-step scale; replaces inline 8/9/10/11/13/14/16) ----
    readonly property int fontSizeBadge:  Local.get("fontSizeBadge",  9)    // notification count, signal-strength overlays — sub-10 chrome
    readonly property int fontSizeSmall:  Local.get("fontSizeSmall",  11)   // tooltips, dim secondary text
    readonly property int fontSizeNormal: Local.get("fontSizeNormal", 13)   // bar body text (date, time, workspace numbers)
    readonly property int fontSizeLarge:  Local.get("fontSizeLarge",  15)   // section headers in popups
    readonly property int fontSizeXL:     Local.get("fontSizeXL",     17)   // standout labels

    // Default glyph size for FA icons inside a 22 × 22 bar widget.
    readonly property int iconSize: Local.get("iconSize", 13)

    // ---- Behavior ----
    // Play freedesktop `audio-volume-change` sound on volume changes / unmute,
    // KDE-Plasma style. The sample plays through the just-changed default sink,
    // so its perceived loudness mirrors the new volume level. Requires
    // `libcanberra` (canberra-gtk-play) + a sound theme (e.g.
    // `sound-theme-freedesktop`). Silently no-ops if either is missing.
    readonly property bool volumeFeedbackEnabled: Local.get("volumeFeedbackEnabled", true)
}
