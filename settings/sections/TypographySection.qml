// TypographySection.qml
// Settings tab content for fonts (3 family names) and font sizes
// (5-step scale + iconSize). Font rows render a preview line in the
// chosen family so visual confirmation doesn't require a shell reload.
//
// Defaults must mirror Theme.qml's hard-coded values.

import QtQuick
import qs.settings.controls

Column {
    width: parent ? parent.width : 0
    spacing: 4

    SectionHeader { label: "FONTS" }
    TextRow {
        settingKey: "fontMono"
        label: "fontMono"
        defaultValue: "Iosevka Nerd Font"
        showPreview: true
        previewSample: "Aa Bb Cc · 0123 — the quick brown fox"
    }
    TextRow {
        settingKey: "fontIcon"
        label: "fontIcon"
        defaultValue: "Font Awesome 7 Free"
        // FA Solid is sized for icons, not body text — preview without
        // sample text since arbitrary chars don't render meaningfully.
    }
    TextRow {
        settingKey: "fontBrand"
        label: "fontBrand"
        defaultValue: "Font Awesome 7 Brands"
    }

    SectionHeader { label: "FONT SIZES (px)" }
    NumberSlider {
        settingKey: "fontSizeBadge"
        label: "fontSizeBadge"
        minValue: 6; maxValue: 14; defaultValue: 9
    }
    NumberSlider {
        settingKey: "fontSizeSmall"
        label: "fontSizeSmall"
        minValue: 8; maxValue: 16; defaultValue: 11
    }
    NumberSlider {
        settingKey: "fontSizeNormal"
        label: "fontSizeNormal"
        minValue: 10; maxValue: 18; defaultValue: 13
    }
    NumberSlider {
        settingKey: "fontSizeLarge"
        label: "fontSizeLarge"
        minValue: 12; maxValue: 22; defaultValue: 15
    }
    NumberSlider {
        settingKey: "fontSizeXL"
        label: "fontSizeXL"
        minValue: 14; maxValue: 26; defaultValue: 17
    }

    SectionHeader { label: "ICONS" }
    NumberSlider {
        settingKey: "iconSize"
        label: "iconSize"
        minValue: 9; maxValue: 20; defaultValue: 13
    }
}
