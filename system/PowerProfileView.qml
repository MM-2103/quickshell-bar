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
import qs.ui

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

    // A pick-one list, so unlike the Wi-Fi and Bluetooth rows the whole
    // row is the click target (ListRow clickable). See docs/STYLE.md.
    component ProfileRow: ListRow {
        id: pr
        required property var entry

        readonly property bool isCurrent: PowerProfiles.profile === entry.profile

        title: entry.label
        status: entry.note
        emphasized: isCurrent
        radio: true
        radioChecked: isCurrent
        clickable: true
        onClicked: {
            PowerProfiles.profile = pr.entry.profile;
            // Drop the user back to the tiles view after a pick — feels
            // like a discrete settings action ("I picked one, done").
            ControlCenterService.goBack();
        }
    }

    Column {
        anchors.fill: parent
        spacing: 4

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
