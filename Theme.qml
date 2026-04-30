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
}
