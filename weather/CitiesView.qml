// CitiesView.qml
// Embeddable city picker for the Control Center. Shown when the user
// clicks the city pill on WeatherCard or the empty-state placeholder.
// Same architecture as NetworkView / BluetoothView / PowerProfileView —
// pure content (no card chrome), instantiated by ControlCenterPopup's
// Loader when `currentView === "cities"`.
//
// Behaviour:
//   - One row per city in WeatherService.cities
//   - One ListRow per city; the current one has the filled radio dot
//     and a bold name, the same as PowerProfileView
//   - Click row → setLocation() + goBack() to tiles view (mirrors how
//     PowerProfileView dismisses after a pick — "I made a discrete
//     choice, take me back")
//   - Scrollable when content exceeds available height (~25 cities at
//     40 px each = ~1100 px content vs ~340 px CC body)

import QtQuick
import qs
import qs.controlcenter
import qs.ui
import qs.weather

Item {
    id: view

    // ================================================================
    // Inline component: a single city row.
    // ================================================================
    // A pick-one list, so the whole row is the click target (ListRow
    // clickable), like PowerProfileView. See docs/STYLE.md.
    component CityRow: ListRow {
        id: row
        required property var entry  // { label, lat, lon }

        // Match-by-label rather than by lat/lon so we don't get tripped
        // up by floating-point comparison weirdness if the user-saved
        // coords drift by 1e-15 from the catalogue values.
        readonly property bool isCurrent:
            WeatherService.locationLabel === row.entry.label

        title: entry.label
        emphasized: isCurrent
        radio: true
        radioChecked: isCurrent
        clickable: true
        onClicked: {
            WeatherService.setLocation(row.entry);
            ControlCenterService.goBack();
        }
    }

    // ================================================================
    // Layout — Flickable wrapping a Column of rows.
    // ================================================================
    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: cityCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: cityCol
            width: parent.width
            spacing: 4

            Repeater {
                model: WeatherService.cities
                delegate: CityRow {
                    required property var modelData
                    entry: modelData
                }
            }
        }
    }
}
