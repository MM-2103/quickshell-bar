// PowerProfileView.qml
// Embeddable power-profile picker. Extracted from the old PowerProfilePopup
// so the Control Center can host the same 3-radio UI as a sub-view.
//
// Composition: title + one ProfileRow per available profile (Performance
// is omitted on systems where power-profiles-daemon doesn't expose it),
// plus an optional degradation-cause line. Card chrome is supplied by
// ControlCenterPopup.

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.controlcenter

Item {
    id: view

    readonly property var options: {
        const arr = [
            { profile: PowerProfile.PowerSaver,
              label: "Power Saver",
              note: "Minimize power use" },
            { profile: PowerProfile.Balanced,
              label: "Balanced",
              note: "Default profile" }
        ];
        if (PowerProfiles.hasPerformanceProfile) {
            arr.push({ profile: PowerProfile.Performance,
                       label: "Performance",
                       note: "Max performance" });
        }
        return arr;
    }

    component ProfileRow: Rectangle {
        id: pr
        required property var entry

        width: parent.width
        height: 36
        radius: Theme.radiusSmall
        color: rowMa.containsMouse ? Theme.surfaceHi : Theme.surface
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        readonly property bool isCurrent: PowerProfiles.profile === entry.profile

        Row {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            // Indicator dot — same visual as the old popup.
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 10; height: 10
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: width / 2
                    color: pr.isCurrent ? Theme.accent : "transparent"
                    border.color: Theme.textDim
                    border.width: pr.isCurrent ? 0 : 1
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 10 - parent.spacing
                spacing: 1

                Text {
                    text: pr.entry.label
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: pr.isCurrent ? Font.Bold : Font.Normal
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text: pr.entry.note
                    color: Theme.textMuted
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }

        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                PowerProfiles.profile = pr.entry.profile;
                // Drop the user back to the tiles view after a pick — feels
                // like a discrete settings action ("I picked one, done").
                ControlCenterService.goBack();
            }
        }
    }

    Column {
        anchors.fill: parent
        spacing: 6

        Repeater {
            model: view.options
            delegate: ProfileRow {
                required property var modelData
                entry: modelData
            }
        }

        // Surface degradation cause if power-profiles-daemon reports one.
        Text {
            visible: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
            width: parent.width
            wrapMode: Text.Wrap
            text: {
                const r = PowerProfiles.degradationReason;
                if (r === PerformanceDegradationReason.LapDetected) return "Throttled — laptop on lap";
                if (r === PerformanceDegradationReason.HighOperatingTemperature) return "Throttled — high temperature";
                return "Performance throttled";
            }
            color: Theme.textMuted
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            topPadding: 4
        }
    }
}
