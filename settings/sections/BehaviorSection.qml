// BehaviorSection.qml
// Settings tab content for assorted non-visual overrides:
//   - `volumeFeedbackEnabled` (audible cue on volume change)
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
