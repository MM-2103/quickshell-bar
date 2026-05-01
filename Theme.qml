// Theme.qml
// Single source of truth for palette + sizing.
// Pure grayscale + white accent — meant to fit any wallpaper.

pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // ---- Backgrounds ----
    readonly property color bg:           "#16181c"  // bar / popup base
    readonly property color surface:      "#1e1e22"  // hover state, mild elevation
    readonly property color surfaceHi:    "#26262a"  // pinned / pressed state

    // ---- Lines ----
    readonly property color border:       "#2a2a2e"

    // ---- Text ----
    readonly property color text:         "#fcfcfc"  // primary (matches breeze-dark icon foreground)
    readonly property color textDim:      "#909090"  // secondary
    readonly property color textMuted:    "#5e5e5e"  // very subtle (separators, weekend)

    // ---- Accent (white) ----
    readonly property color accent:       "#ffffff"  // focused / today highlight
    readonly property color accentText:   "#16181c"  // text drawn on top of accent fill

    // ---- Error / warning (used by lock auth, low-battery, etc.) ----
    readonly property color error:        "#ff5050"  // borders, strokes
    readonly property color errorBright:  "#ff7070"  // text on dark backgrounds

    // ---- Workspace pip states ----
    readonly property color pipIdle:      "#2a2a2e"
    readonly property color pipActive:    "#3a3a3e"  // active on output but not focused
    readonly property color pipFocused:   "#ffffff"  // = accent

    // ---- Geometry ----
    readonly property int barHeight: 32
    readonly property int radius: 6
    readonly property int radiusSmall: 4

    // ---- Animations ----
    readonly property int animFast: 100
    readonly property int animMed:  140

    // ---- Fonts ----
    // Single mono typeface for the whole shell. Iosevka has a deep weight
    // ladder (Thin → Heavy + italics + Mono / Propo variants) which lets
    // us express hierarchy without switching family. Glyph widget icons
    // come from Font Awesome 7 (Free Solid for most, Brands only when a
    // glyph isn't available in Free — currently just Bluetooth).
    readonly property string fontMono:  "Iosevka Nerd Font"
    readonly property string fontIcon:  "Font Awesome 7 Free"     // styleName: "Solid"
    readonly property string fontBrand: "Font Awesome 7 Brands"

    // ---- Font sizes (4-step scale; replaces inline 8/9/10/11/13/14/16) ----
    readonly property int fontSizeBadge:  9    // notification count, signal-strength overlays — sub-10 chrome
    readonly property int fontSizeSmall:  10   // tooltips, dim secondary text
    readonly property int fontSizeNormal: 12   // bar body text (date, time, workspace numbers)
    readonly property int fontSizeLarge:  14   // section headers in popups
    readonly property int fontSizeXL:     16   // standout labels

    // Default glyph size for FA icons inside a 22 × 22 bar widget.
    readonly property int iconSize: 13
}
