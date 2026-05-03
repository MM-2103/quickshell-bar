// ColorsSection.qml
// Settings tab content for all 14 colour overrides, grouped under
// sub-headings that mirror Theme.qml's organisation (Surfaces / Text /
// Accent / Error / Workspace pips).
//
// All colour rows reuse `ColorRow` which provides the hex input +
// swatch + click-to-open ColorPicker. Defaults here MUST match
// Theme.qml's hard-coded defaults — they're shown when no override is
// set, and used as the "reset to default" target.

import QtQuick
import qs.settings.controls

Column {
    width: parent ? parent.width : 0
    spacing: 4

    SectionHeader { label: "SURFACES" }
    ColorRow { settingKey: "bg";           label: "bg";           defaultValue: "#16181c" }
    ColorRow { settingKey: "surface";      label: "surface";      defaultValue: "#1e1e22" }
    ColorRow { settingKey: "surfaceHi";    label: "surfaceHi";    defaultValue: "#26262a" }
    ColorRow { settingKey: "border";       label: "border";       defaultValue: "#2a2a2e" }

    SectionHeader { label: "TEXT" }
    ColorRow { settingKey: "text";         label: "text";         defaultValue: "#fcfcfc" }
    ColorRow { settingKey: "textDim";      label: "textDim";      defaultValue: "#909090" }
    ColorRow { settingKey: "textMuted";    label: "textMuted";    defaultValue: "#5e5e5e" }

    SectionHeader { label: "ACCENT" }
    ColorRow { settingKey: "accent";       label: "accent";       defaultValue: "#ffffff" }
    ColorRow { settingKey: "accentText";   label: "accentText";   defaultValue: "#16181c" }

    SectionHeader { label: "ERROR" }
    ColorRow { settingKey: "error";        label: "error";        defaultValue: "#ff5050" }
    ColorRow { settingKey: "errorBright";  label: "errorBright";  defaultValue: "#ff7070" }

    SectionHeader { label: "WORKSPACE PIPS" }
    ColorRow { settingKey: "pipIdle";      label: "pipIdle";      defaultValue: "#2a2a2e" }
    ColorRow { settingKey: "pipActive";    label: "pipActive";    defaultValue: "#3a3a3e" }
    ColorRow { settingKey: "pipFocused";   label: "pipFocused";   defaultValue: "#ffffff" }
}
