// WeatherCard.qml
// Compact two-row weather card for the Control Center, sitting between
// the tile grid and NowPlayingCard.
//
// Three states:
//   1. No location set      → "Set location" placeholder; whole card
//                             clickable, opens the cities detail view.
//   2. Loading first fetch  → temperature blank, "Loading…" description.
//   3. Loaded               → icon + temp + city pill + refresh button
//                             (top row) and description + feels + wind
//                             (bottom row). Hi/Lo on the right.
//
// City pill click → CC navigates to "cities" detail view (5th view in
// the existing view-stack — same pattern as Wi-Fi / BT / PowerProfile).
// Refresh button → WeatherService.refresh(); spins while loading.

import QtQuick
import qs
import qs.controlcenter
import qs.weather

Rectangle {
    id: card

    // Card chrome — matches the surface tone the tiles use, slightly
    // raised from the popup background so the section reads as its
    // own block.
    color: Theme.surface
    border.color: Theme.border
    border.width: 1
    radius: Theme.radiusSmall

    height: 64

    readonly property bool _loaded:
        WeatherService.hasLocation
        && WeatherService.lastUpdated !== null
        && WeatherService.lastError === ""

    readonly property bool _empty: !WeatherService.hasLocation

    // ================================================================
    // Empty state — "Set location" prompt
    // ================================================================
    //
    // Whole-card click area opens the cities detail view. Single MouseArea
    // covers the full card; nested controls (refresh, city pill) only
    // exist in the loaded state.
    MouseArea {
        id: emptyMa
        anchors.fill: parent
        visible: card._empty
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ControlCenterService.setView("cities")

        // Hover lift — same idiom Tile uses
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            color: emptyMa.containsMouse ? Theme.surfaceHi : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Row {
            anchors.centerIn: parent
            spacing: 10

            // \uf3c5 location-dot
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf3c5"
                color: Theme.textDim
                font.family: Theme.fontIcon
                font.styleName: "Solid"
                font.pixelSize: 16
                renderType: Text.NativeRendering
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    text: "Set location"
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: Font.Bold
                }
                Text {
                    text: "Choose your city to see weather"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }

    // ================================================================
    // Loaded state — two-row weather display
    // ================================================================
    //
    // Body MouseArea sits at z = -1 so the city pill and refresh button
    // (default z = 0) win their sub-regions; clicks anywhere else on the
    // card open the detail popup. Same body-vs-region pattern Tile.qml
    // uses for body-vs-chevron clicks.
    MouseArea {
        id: bodyMa
        anchors.fill: parent
        visible: !card._empty
        z: -1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: WeatherService.openDetail()

        // Subtle hover indicator on the whole card. Using border tone shift
        // rather than fill so the temperature numbers don't get a box around
        // them on hover.
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            color: bodyMa.containsMouse ? Theme.surfaceHi : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 10
        visible: !card._empty

        // ---- Top row: icon + temp + city pill + refresh + hi/lo ----
        Row {
            id: topRow
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: 22
            spacing: 8

            // Weather icon — large enough to read at a glance.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: WeatherService.iconForCode(WeatherService.weatherCode)
                color: Theme.text
                font.family: Theme.fontIcon
                font.styleName: "Solid"
                font.pixelSize: 18
                renderType: Text.NativeRendering
                width: 22
                horizontalAlignment: Text.AlignHCenter
            }

            // Current temperature — bold, prominent.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: card._loaded
                    ? Math.round(WeatherService.currentTemp) + "°"
                    : "—"
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
            }

            // City pill — clickable, opens cities view. Shows current
            // location label + a chevron-down hint that this is a picker.
            Rectangle {
                id: cityPill
                anchors.verticalCenter: parent.verticalCenter
                width: cityRow.implicitWidth + 14
                height: 22
                radius: 11
                color: cityMa.containsMouse ? Theme.surfaceHi : Theme.bg
                border.color: Theme.border
                border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Row {
                    id: cityRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: WeatherService.locationLabel
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    // \uf078 chevron-down — small "click to change" hint.
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u25BE"   // unicode triangle, no FA dep needed
                        color: Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                    }
                }

                MouseArea {
                    id: cityMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ControlCenterService.setView("cities")
                }
            }

            // Spacer — fills space between city pill and right-side controls.
            Item {
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                width: Math.max(0, parent.width
                    - 22 - 8                                  // icon + spacing
                    - tempLabel.implicitWidth - parent.spacing
                    - cityPill.width - parent.spacing
                    - refreshBtn.width - parent.spacing
                    - hiloText.implicitWidth)
            }

            // Hidden Text used only for width measurement of the temperature
            // (it changes width as the value changes, breaking spacer math
            // unless we pin it). Keep it cheap.
            Text {
                id: tempLabel
                visible: false
                text: card._loaded
                    ? Math.round(WeatherService.currentTemp) + "°"
                    : "—"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
            }

            // Refresh button — spins while loading; click forces a new
            // fetch even if the timer hasn't fired yet.
            Rectangle {
                id: refreshBtn
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 22
                radius: Theme.radiusSmall
                color: refreshMa.containsMouse ? Theme.surfaceHi : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                // \uf021 arrows-rotate
                Text {
                    id: refreshGlyph
                    anchors.centerIn: parent
                    text: "\uf021"
                    color: Theme.textDim
                    font.family: Theme.fontIcon
                    font.styleName: "Solid"
                    font.pixelSize: 11
                    renderType: Text.NativeRendering

                    // Continuous spin while the fetch is in flight; one-shot
                    // spin on manual click for tactile feedback even when
                    // the network responds before the user releases the mouse.
                    RotationAnimation on rotation {
                        running: WeatherService.loading
                        from: 0; to: 360
                        duration: 900
                        loops: Animation.Infinite
                    }
                }

                MouseArea {
                    id: refreshMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: WeatherService.refresh()
                }
            }

            // Hi/Lo on the far right.
            Text {
                id: hiloText
                anchors.verticalCenter: parent.verticalCenter
                text: card._loaded
                    ? ("H " + Math.round(WeatherService.tempMax) + "°  "
                       + "L " + Math.round(WeatherService.tempMin) + "°")
                    : ""
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        // ---- Bottom row: description · feels · wind ----
        Text {
            anchors {
                left: parent.left
                right: parent.right
                top: topRow.bottom
                topMargin: 4
            }
            text: {
                if (WeatherService.lastError !== "")
                    return WeatherService.lastError;
                if (!card._loaded && WeatherService.loading)
                    return "Loading…";
                if (!card._loaded)
                    return "—";
                const desc = WeatherService.descriptionForCode(WeatherService.weatherCode);
                const feels = "feels " + Math.round(WeatherService.apparentTemp) + "°";
                const wind = Math.round(WeatherService.windSpeed) + " km/h";
                return desc + " · " + feels + " · " + wind;
            }
            color: WeatherService.lastError !== "" ? Theme.errorBright : Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }
    }
}
