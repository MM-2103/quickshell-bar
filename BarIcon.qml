// BarIcon.qml
// Renders a Font Awesome glyph at the standard bar-icon size in the
// shell's primary text color. The widget's hover/active state is
// signalled by its parent (typically via a background Rectangle that
// fades between transparent / surface / surfaceHi) — the glyph itself
// stays at full brightness so the icon remains legible at all times.
//
// Set `brand: true` for glyphs that only exist in Font Awesome Brands
// (currently just the Bluetooth logos). Override `color`, `pixelSize`,
// `glyphSize`, or `font.styleName` if you need to deviate.
//
// Usage:
//
//   MouseArea {
//       width: 22; height: 22
//       hoverEnabled: true
//       Rectangle { anchors.fill: parent; color: containsMouse ? Theme.surface : "transparent" }
//       BarIcon { anchors.centerIn: parent; glyph: "\uf0f3" }   // bell
//   }

import QtQuick
import qs

Text {
    id: icon

    property string glyph: ""
    property bool brand: false
    // Convenience: rebrand `pixelSize` so callers don't have to dig into
    // `font.pixelSize`. The default matches Theme.iconSize (13 px) which
    // is calibrated for the standard 22 × 22 hit area.
    property int glyphSize: Theme.iconSize

    text: glyph
    color: Theme.text
    font.family: brand ? Theme.fontBrand : Theme.fontIcon
    font.styleName: brand ? "Regular" : "Solid"
    font.pixelSize: glyphSize
    renderType: Text.NativeRendering

    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
