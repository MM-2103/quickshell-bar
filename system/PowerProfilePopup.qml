// PowerProfilePopup.qml
// Picker for the system power profile via power-profiles-daemon.

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs

PopupWindow {
    id: popup

    required property Item anchorItem

    visible: false
    color: "transparent"

    function toggle() {
        if (popup.visible) {
            popup.visible = false;
        } else {
            PopupController.open(popup, () => popup.visible = false);
            popup.visible = true;
        }
    }
    onVisibleChanged: if (!visible) PopupController.closed(popup)

    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? -((popup.width - anchorItem.width) / 2) : 0
    anchor.rect.y: anchorItem ? anchorItem.height + 6 : 0
    anchor.adjustment: PopupAdjustment.SlideX

    implicitWidth: 220
    implicitHeight: contentColumn.implicitHeight + 16

    // Build the option list dynamically (omit Performance if unsupported).
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
        required property var entry  // { profile, label, note }

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

            // Indicator dot
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
                    font.pixelSize: 12
                    font.bold: pr.isCurrent
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text: pr.entry.note
                    color: Theme.textMuted
                    font.pixelSize: 10
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
                popup.visible = false;
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

        Column {
            id: contentColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 8
            }
            spacing: 6

            Text {
                text: "POWER PROFILE"
                color: Theme.textDim
                font.pixelSize: 10
                font.bold: true
            }

            Repeater {
                model: popup.options
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
                font.pixelSize: 10
                topPadding: 4
            }
        }
    }
}
