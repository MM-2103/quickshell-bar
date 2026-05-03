// CitiesView.qml
// Embeddable city picker for the Control Center. Shown when the user
// clicks the city pill on WeatherCard or the empty-state placeholder.
// Same architecture as NetworkView / BluetoothView / PowerProfileView —
// pure content (no card chrome), instantiated by ControlCenterPopup's
// Loader when `currentView === "cities"`.
//
// Behaviour:
//   - One row per city in WeatherService.cities
//   - Currently-selected city highlighted with the accent indicator dot
//     (same visual as PowerProfileView's "selected profile" radio dot)
//   - Click row → setLocation() + goBack() to tiles view (mirrors how
//     PowerProfileView dismisses after a pick — "I made a discrete
//     choice, take me back")
//   - Scrollable when content exceeds available height (~25 cities at
//     32 px each = ~800 px content vs ~340 px CC body)

import QtQuick
import qs
import qs.controlcenter
import qs.weather

Item {
    id: view

    // ================================================================
    // Inline component: a single city row.
    // ================================================================
    component CityRow: Rectangle {
        id: row
        required property var entry  // { label, lat, lon }

        width: parent.width
        height: 32
        radius: Theme.radiusSmall
        color: rowMa.containsMouse ? Theme.surfaceHi : Theme.surface
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        // Match-by-label rather than by lat/lon so we don't get tripped
        // up by floating-point comparison weirdness if the user-saved
        // coords drift by 1e-15 from the catalogue values.
        readonly property bool isCurrent:
            WeatherService.locationLabel === row.entry.label

        Row {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            // Indicator dot — same shape PowerProfileView uses for its
            // current-profile marker. Filled accent when selected; ring
            // outline otherwise.
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 10; height: 10
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: width / 2
                    color: row.isCurrent ? Theme.accent : "transparent"
                    border.color: Theme.textDim
                    border.width: row.isCurrent ? 0 : 1
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 10 - parent.spacing
                text: row.entry.label
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeNormal
                font.weight: row.isCurrent ? Font.Bold : Font.Normal
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                WeatherService.setLocation(row.entry);
                ControlCenterService.goBack();
            }
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
