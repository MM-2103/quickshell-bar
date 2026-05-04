// ThemeSection.qml
// Settings tab content for the Theme picker. A "Current: X" status line
// followed by two grouped Flows of ThemeCard items — DARK THEMES first,
// then LIGHT THEMES, each preceded by a SectionHeader divider.
//
// Cards apply their palette on click, writing all 14 colour keys via
// ThemePresets.applyTheme. The selected indicator on each card and
// the "Current:" label both read ThemePresets.currentTheme, which is
// reactive on Local.data — so manual ColorRow edits flip the selection
// to "Custom" without explicit wiring.
//
// Each Flow filters ThemePresets.all by the `kind` field on each theme
// record. User-defined themes drop into whichever group their `kind`
// declares ("dark" by default if omitted from the JSONC). The filter
// re-runs reactively when ThemePresets.all changes (e.g. on user-theme
// rescan), so newly-dropped theme files appear in the right group
// without any extra wiring.
//
// Layout: Flow auto-wraps cards based on available width. At the
// popup's 808 px content width with 8 px gaps, four cards fit per row
// (4 × 188 + 3 × 8 = 776, plus padding). 10 built-in dark + 10 light
// take three rows each, so the section overflows the ~466 px Flickable
// content area and scrolls — handled cleanly by SettingsPopup's
// Flickable wrapper.

import QtQuick
import qs
import qs.settings.controls
import qs.themes

Column {
    width: parent ? parent.width : 0
    spacing: 12

    // ---- Status line ----
    //
    // "Current: <label>" or "Current: Custom" depending on whether
    // ThemePresets.currentTheme matches anything. Visually mirrors a
    // SectionHeader but with a normal-weight body trailing the label,
    // so it reads as informational rather than a section divider.
    Item {
        width: parent.width
        height: 22

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Current"
            color: Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 64
            anchors.verticalCenter: parent.verticalCenter
            text: ThemePresets.currentTheme
                ? ThemePresets.currentTheme.label
                : "Custom"
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    // ---- Dark themes ----
    SectionHeader { label: "DARK THEMES" }

    Flow {
        width: parent.width
        spacing: 8

        Repeater {
            // Filter is reactive on ThemePresets.all — Repeater re-renders
            // when user themes load. JS Array.filter creates a new array
            // each evaluation; cheap at this scale (20+ entries) and the
            // resulting model is iterated by Repeater synchronously.
            model: ThemePresets.all.filter(t => t.kind !== "light")

            delegate: ThemeCard {
                required property var modelData
                theme: modelData
            }
        }
    }

    // ---- Light themes ----
    SectionHeader { label: "LIGHT THEMES" }

    Flow {
        width: parent.width
        spacing: 8

        Repeater {
            // Themes whose kind is explicitly "light". User themes that
            // omit kind default to "dark" (per ThemePresets._parseUserThemes)
            // and so don't land here unless explicitly opted in.
            model: ThemePresets.all.filter(t => t.kind === "light")

            delegate: ThemeCard {
                required property var modelData
                theme: modelData
            }
        }
    }
}
