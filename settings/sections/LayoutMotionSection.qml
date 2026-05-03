// LayoutMotionSection.qml
// Settings tab content for geometry (bar height, corner radii) and
// animation durations (animFast / animMed). Both are simple numeric
// sliders.

import QtQuick
import qs.settings.controls

Column {
    width: parent ? parent.width : 0
    spacing: 4

    SectionHeader { label: "GEOMETRY (px)" }
    NumberSlider {
        settingKey: "barHeight"
        label: "barHeight"
        minValue: 24; maxValue: 48; defaultValue: 32
        unitSuffix: "px"
    }
    NumberSlider {
        settingKey: "radius"
        label: "radius"
        minValue: 0; maxValue: 14; defaultValue: 6
        unitSuffix: "px"
    }
    NumberSlider {
        settingKey: "radiusSmall"
        label: "radiusSmall"
        minValue: 0; maxValue: 10; defaultValue: 4
        unitSuffix: "px"
    }

    SectionHeader { label: "ANIMATION (ms)" }
    NumberSlider {
        settingKey: "animFast"
        label: "animFast"
        minValue: 0; maxValue: 300; defaultValue: 100
        unitSuffix: "ms"
    }
    NumberSlider {
        settingKey: "animMed"
        label: "animMed"
        minValue: 0; maxValue: 400; defaultValue: 140
        unitSuffix: "ms"
    }
}
