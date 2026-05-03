// NumberSlider.qml
// Setting row backed by a horizontal slider with a numeric readout to
// the right. Used for ints (font sizes, geometry, animation durations).
//
// The Slider component this project ships with works in 0..1 range; we
// map to the configured min/max here and write the rounded integer back
// via `Local.set(key, value)`. Each user drag triggers Local's debounce.

import QtQuick
import qs
import qs.settings

SettingRow {
    id: row

    // Min / max of the input range (inclusive). e.g., 24..48 for barHeight.
    property int minValue: 0
    property int maxValue: 100

    // Optional unit suffix shown after the number ("px", "ms", or empty).
    property string unitSuffix: ""

    // Default value for this key — reflected back into the slider when
    // no override is present, and used by `Local.get(...)`.
    property int defaultValue: 0

    // Current value shown by the slider. Read-only from the binding's
    // perspective; user drags update via `userChanged → Local.set(...)`.
    readonly property int currentValue: Local.get(row.settingKey, row.defaultValue)

    // Map currentValue (int in min..max) to slider position (0..1).
    readonly property real _ratio: {
        const span = row.maxValue - row.minValue;
        if (span <= 0) return 0;
        return Math.max(0, Math.min(1,
            (row.currentValue - row.minValue) / span));
    }

    Slider {
        id: slider
        anchors.left: parent.left
        anchors.right: readout.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 10
        value: row._ratio
        wheelStep: 0.05
        onUserChanged: v => {
            const next = Math.round(row.minValue + v * (row.maxValue - row.minValue));
            // Avoid redundant writes when the user drags within the
            // same integer cell (slider is 0..1, but we round to int).
            if (next !== row.currentValue) {
                Local.set(row.settingKey, next);
            }
        }
    }

    Text {
        id: readout
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 60
        horizontalAlignment: Text.AlignRight
        text: row.currentValue + (row.unitSuffix ? " " + row.unitSuffix : "")
        color: Theme.text
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeSmall
    }
}
