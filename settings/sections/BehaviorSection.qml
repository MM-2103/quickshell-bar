// BehaviorSection.qml
// Settings tab content for assorted non-visual overrides:
//   - `volumeFeedbackEnabled` (audible cue on volume change)
//   - `idleLockSeconds` / `idleDpmsSeconds` (IdleService stage timeouts)
//   - `activeWindowEnabled` / `activeWindowMaxWidth` (focused-title widget)
//   - `nightLightTemperature` (blue-light filter warmth; the on/off state
//     lives on the Control Center tile, not here)
//   - `searchUrl` / `searchName` (launcher web-search engine)
//
// `searchUrl` uses a `PresetDropdown` for one-click engine swaps; the
// dropdown's `companionKey` mechanism writes both `searchUrl` and
// `searchName` from one preset click. A separate `searchName` text row
// is shown below for users who want a custom URL via the regular
// TextRow flow (paste their own URL into the dropdown's hidden TextRow
// equivalent — actually we expose a TextRow for `searchUrl` too so
// custom values are first-class).

import QtQuick
import qs.settings.controls

Column {
    width: parent ? parent.width : 0
    spacing: 4

    SectionHeader { label: "BEHAVIOR" }
    ToggleRow {
        settingKey: "volumeFeedbackEnabled"
        label: "Volume feedback"
        defaultValue: true
    }

    // Idle timeouts. Both stages are independent and either can be turned
    // off by dragging to 0. Stepped at 30 s because a 30-minute range makes
    // per-second precision meaningless.
    SectionHeader { label: "IDLE" }
    NumberSlider {
        settingKey: "idleLockSeconds"
        label: "Lock after"
        defaultValue: 300
        minValue: 0
        maxValue: 1800
        stepValue: 30
        unitSuffix: "s"
        zeroLabel: "Off"
    }
    NumberSlider {
        settingKey: "idleDpmsSeconds"
        label: "Screens off"
        defaultValue: 360
        minValue: 0
        maxValue: 1800
        stepValue: 30
        unitSuffix: "s"
        zeroLabel: "Off"
    }

    // The width cap is a taste setting, not a layout constraint: the bar
    // already bounds the title by the gap to the clock. Some people want a
    // short label rather than one that grows to fill the whole gap.
    SectionHeader { label: "ACTIVE WINDOW" }
    ToggleRow {
        settingKey: "activeWindowEnabled"
        label: "Show window title"
        defaultValue: true
    }
    NumberSlider {
        settingKey: "activeWindowMaxWidth"
        label: "Max width"
        defaultValue: 400
        minValue: 100
        maxValue: 800
        stepValue: 20
        unitSuffix: "px"
    }

    // Only the temperature is exposed here. The on/off switch is the
    // Control Center's Night light tile -- duplicating it as a row would
    // give the same state two homes.
    SectionHeader { label: "NIGHT LIGHT" }
    NumberSlider {
        settingKey: "nightLightTemperature"
        label: "Temperature"
        defaultValue: 4000
        minValue: 2500
        maxValue: 6000
        stepValue: 100
        unitSuffix: "K"
    }

    SectionHeader { label: "LAUNCHER · WEB SEARCH" }
    // Preset dropdown — picks both URL and name in one click.
    PresetDropdown {
        settingKey: "searchUrl"
        label: "Engine preset"
        defaultValue: "https://kagi.com/search?q=%s"
        companionKey: "searchName"
        presets: [
            { label: "Kagi (default)",    value: "https://kagi.com/search?q=%s",                   companionLabel: "Kagi" },
            { label: "DuckDuckGo",        value: "https://duckduckgo.com/?q=%s",                   companionLabel: "DuckDuckGo" },
            { label: "Google",            value: "https://www.google.com/search?q=%s",             companionLabel: "Google" },
            { label: "Brave Search",      value: "https://search.brave.com/search?q=%s",           companionLabel: "Brave Search" },
            { label: "Startpage",         value: "https://www.startpage.com/do/search?q=%s",       companionLabel: "Startpage" }
        ]
    }
    // Custom URL — overrides the preset if the user types something
    // bespoke. `searchUrl` is the same key the dropdown writes to;
    // both controls stay in sync.
    TextRow {
        settingKey: "searchUrl"
        label: "Custom URL"
        defaultValue: "https://kagi.com/search?q=%s"
    }
    TextRow {
        settingKey: "searchName"
        label: "Display name"
        defaultValue: "Kagi"
    }
}
