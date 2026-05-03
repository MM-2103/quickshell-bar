// WeatherDetailPopup.qml
// Centered Overlay-layer popup showing the full forecast: current
// conditions (with sunrise/sunset), a horizontally-scrollable 24-hour
// strip, and a 7-day list. Triggered by clicking anywhere on the body
// of WeatherCard (the city pill and refresh button keep their own
// click semantics).
//
// Architecture mirrors WallpaperPickerPopup: per-monitor Variants in
// shell.qml, gated on `WeatherService.detailOpen && isFocusedScreen`,
// Esc-to-close via Exclusive keyboard focus, standard popup recipe
// (wantOpen + hideHold + fade + MultiEffect shadow).

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs
import qs.weather

PanelWindow {
    id: panel

    required property var modelData
    required property string focusedOutput

    screen: modelData

    readonly property bool isFocusedScreen:
        modelData && modelData.name === focusedOutput
    readonly property bool wantOpen:
        WeatherService.detailOpen && isFocusedScreen

    // Same fade-out trick as the launcher / wallpaper picker: keep the
    // surface mapped for 180 ms after wantOpen drops so the opacity
    // Behavior actually has time to play.
    visible: wantOpen || hideHold.running
    Timer { id: hideHold; interval: 180; repeat: false }
    onWantOpenChanged: {
        if (wantOpen) hideHold.stop();
        else          hideHold.restart();
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Above bar + fullscreen apps; Exclusive keyboard so Esc reaches us.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // No anchors → wlroots horizontally + vertically centers the surface.
    // 24 px padding on each side for the drop shadow.
    //
    // Height math (with 16 px outer margins + 16 px Column spacing):
    //   header(24) + divider(1) + current(80) + divider(1) + label(16) +
    //   hourly(110) + divider(1) + label(16) + daily(7×28 + 6×4 = 220)
    //   = 469 px content + 8 × 16 = 128 px gaps = ~597 px.
    // 620 inner gives ~23 px breathing room so the last day row never
    // clips when the section labels render at their natural height.
    implicitWidth:  720 + 24
    implicitHeight: 620 + 24

    // ---- Card ----
    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: 12

        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

        opacity: panel.wantOpen ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        transform: Translate {
            y: panel.wantOpen ? 0 : 4
            Behavior on y {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
            shadowBlur: 0.6
        }

        // Esc closes. Same focus-on-show idiom WallpaperPickerPopup uses.
        Item {
            id: keyTarget
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    WeatherService.closeDetail();
                    event.accepted = true;
                }
            }
        }
        onVisibleChanged: if (visible) Qt.callLater(() => keyTarget.forceActiveFocus())

        Column {
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 16

            // ================================================================
            // 1. Header — title (with city) + refresh
            // ================================================================
            Item {
                width: parent.width
                height: 24

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: WeatherService.locationLabel
                        ? "Weather · " + WeatherService.locationLabel
                        : "Weather"
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                }

                // Refresh button — top-right, matches WeatherCard's button
                // visually so the affordance is consistent across surfaces.
                Rectangle {
                    id: refreshBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 24
                    radius: Theme.radiusSmall
                    color: refreshMa.containsMouse ? Theme.surfaceHi : Theme.surface
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    // \uf021 arrows-rotate
                    Text {
                        id: refreshGlyph
                        anchors.centerIn: parent
                        text: "\uf021"
                        color: Theme.text
                        font.family: Theme.fontIcon
                        font.styleName: "Solid"
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
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
            }

            // Divider
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
                opacity: 0.5
            }

            // ================================================================
            // 2. Current conditions — large icon + temp + readout column
            // ================================================================
            Row {
                width: parent.width
                spacing: 24
                height: 80

                // Big weather icon (left)
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 80; height: 80

                    Text {
                        anchors.centerIn: parent
                        text: WeatherService.iconForCode(WeatherService.weatherCode)
                        color: Theme.text
                        font.family: Theme.fontIcon
                        font.styleName: "Solid"
                        font.pixelSize: 56
                        renderType: Text.NativeRendering
                    }
                }

                // Temp + description (middle, fills space)
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 80 - rightStats.width - parent.spacing * 2
                    spacing: 4

                    Row {
                        spacing: 12
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(WeatherService.currentTemp) + "°"
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: 44
                            font.weight: Font.Bold
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                text: WeatherService.descriptionForCode(WeatherService.weatherCode)
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeNormal
                                font.weight: Font.Bold
                            }
                            Text {
                                text: "feels " + Math.round(WeatherService.apparentTemp) + "°"
                                color: Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }

                    // Sunrise / sunset row — formatted via Qt.formatDateTime
                    // because Open-Meteo returns full ISO timestamps.
                    Text {
                        text: {
                            const sr = WeatherService.sunrise
                                ? Qt.formatDateTime(new Date(WeatherService.sunrise), "HH:mm")
                                : "—";
                            const ss = WeatherService.sunset
                                ? Qt.formatDateTime(new Date(WeatherService.sunset), "HH:mm")
                                : "—";
                            return "Sunrise " + sr + " · Sunset " + ss;
                        }
                        color: Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                // Right-side stats (H/L, wind, humidity)
                Column {
                    id: rightStats
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    width: 140

                    Text {
                        text: "H " + Math.round(WeatherService.tempMax) + "°  ·  "
                            + "L " + Math.round(WeatherService.tempMin) + "°"
                        color: Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    Text {
                        text: "Wind " + Math.round(WeatherService.windSpeed) + " km/h"
                        color: Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    Text {
                        text: "Humidity " + WeatherService.humidity + "%"
                        color: Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            // Divider + section label
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
                opacity: 0.5
            }
            Text {
                text: "NEXT 24 HOURS"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
            }

            // ================================================================
            // 3. Hourly strip — horizontally scrollable, 24 cells
            // ================================================================
            //
            // Each cell stacks: hour label / icon / temp / precip%. Cells
            // are 64 px wide × 110 px tall; 24 of them = 1536 px content,
            // exceeding the 688 px popup inner width — Flickable handles
            // the horizontal scrolling. boundsBehavior keeps it from
            // bouncing past the ends.
            Flickable {
                id: hourlyFlick
                width: parent.width
                height: 110
                contentWidth: hourlyRow.implicitWidth
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick

                // Mouse-wheel → horizontal scroll. A horizontal Flickable
                // doesn't translate vertical wheel ticks to contentX changes
                // on its own; this MouseArea intercepts wheel events without
                // stealing clicks (acceptedButtons: NoButton) and converts
                // both wheel axes into a contentX delta. Touchpad two-finger
                // scrolls report on the relevant axis directly.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => {
                        const delta = wheel.angleDelta.y !== 0
                            ? wheel.angleDelta.y
                            : wheel.angleDelta.x;
                        const next = hourlyFlick.contentX - delta;
                        hourlyFlick.contentX = Math.max(
                            0,
                            Math.min(
                                hourlyFlick.contentWidth - hourlyFlick.width,
                                next
                            )
                        );
                        wheel.accepted = true;
                    }
                }

                Row {
                    id: hourlyRow
                    spacing: 0
                    Repeater {
                        model: WeatherService.hourlyTimes.length
                        delegate: Item {
                            required property int index
                            width: 64
                            height: 110

                            // Subtle background on every other cell so the
                            // strip reads as discrete time-buckets rather
                            // than a single blob.
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: Theme.radiusSmall
                                color: index % 2 === 0 ? "transparent" : Theme.surface
                                opacity: 0.7
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: WeatherService.hourlyTimes[index]
                                        ? Qt.formatDateTime(new Date(WeatherService.hourlyTimes[index]), "HH")
                                        : "—"
                                    color: Theme.textDim
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: WeatherService.iconForCode(WeatherService.hourlyCodes[index] || 0)
                                    color: Theme.text
                                    font.family: Theme.fontIcon
                                    font.styleName: "Solid"
                                    font.pixelSize: 18
                                    renderType: Text.NativeRendering
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Math.round(WeatherService.hourlyTemps[index] || 0) + "°"
                                    color: Theme.text
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeNormal
                                    font.weight: Font.Bold
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    // 0% precipitation reads as visual noise; suppress it
                                    // and only show actual probabilities.
                                    visible: (WeatherService.hourlyPrecip[index] || 0) > 0
                                    text: (WeatherService.hourlyPrecip[index] || 0) + "%"
                                    color: Theme.textDim
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeBadge
                                }
                            }
                        }
                    }
                }
            }

            // Divider + section label
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
                opacity: 0.5
            }
            Text {
                text: "7 DAYS"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
            }

            // ================================================================
            // 4. 7-day forecast list
            // ================================================================
            //
            // Pre-computed today/tomorrow names; everything else as
            // weekday short name. Each row: name / icon / hi-lo / precip%.
            Column {
                width: parent.width
                spacing: 4

                Repeater {
                    model: WeatherService.dailyTimes.length
                    delegate: Rectangle {
                        id: dayRow
                        required property int index
                        width: parent.width
                        height: 28
                        radius: Theme.radiusSmall
                        color: index === 0 ? Theme.surface : "transparent"

                        function _dayLabel() {
                            const iso = WeatherService.dailyTimes[index];
                            if (!iso) return "";
                            const date = new Date(iso);
                            if (index === 0) return "Today";
                            if (index === 1) return "Tomorrow";
                            return Qt.formatDateTime(date, "ddd");
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 12

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 90
                                text: dayRow._dayLabel()
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeNormal
                                font.weight: index === 0 ? Font.Bold : Font.Normal
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24
                                text: WeatherService.iconForCode(WeatherService.dailyCodes[index] || 0)
                                color: Theme.text
                                font.family: Theme.fontIcon
                                font.styleName: "Solid"
                                font.pixelSize: 14
                                renderType: Text.NativeRendering
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 120
                                text: Math.round(WeatherService.dailyTempMax[index] || 0) + "°  /  "
                                    + Math.round(WeatherService.dailyTempMin[index] || 0) + "°"
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeNormal
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: (WeatherService.dailyPrecip[index] || 0) > 0
                                text: (WeatherService.dailyPrecip[index] || 0) + "%"
                                color: Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }
            }
        }
    }
}
