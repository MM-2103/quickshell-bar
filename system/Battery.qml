// Battery.qml
// Bar widget for the laptop battery. Hidden entirely on machines without
// a primary battery (e.g. desktops) — `UPower.displayDevice.isPresent`
// is `false` when no battery hardware is attached, and the widget
// collapses to width 0 in that case.
//
// Visual: 5-tier Font Awesome battery glyph + percentage. A small bolt
// overlay marks the charging state. Tooltip shows time-to-full /
// time-to-empty in human-readable form.

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs

MouseArea {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool _present:
        dev && dev.ready && dev.isPresent && dev.type === UPowerDeviceType.Battery
    readonly property real _pct: _present ? dev.percentage : 0
    readonly property bool _charging:
        _present && (dev.state === UPowerDeviceState.Charging
                     || dev.state === UPowerDeviceState.FullyCharged)
    readonly property bool _low: _present && !_charging && _pct < 20

    visible: _present
    implicitWidth: visible ? 38 : 0
    implicitHeight: 22
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    hoverEnabled: true
    cursorShape: Qt.ArrowCursor

    // Hover background pill (matches every other bar widget).
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: root.containsMouse ? Theme.surface : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // 5-tier glyph ramp.
    function _glyph() {
        if (root._pct >= 80) return "\uf240"; // battery-full
        if (root._pct >= 60) return "\uf241"; // battery-three-quarters
        if (root._pct >= 40) return "\uf242"; // battery-half
        if (root._pct >= 20) return "\uf243"; // battery-quarter
        return "\uf244";                       // battery-empty
    }

    Row {
        anchors.centerIn: parent
        spacing: 3

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 14

            BarIcon {
                anchors.centerIn: parent
                glyph: root._glyph()
                color: root._low ? Theme.error : Theme.text
                glyphSize: 12
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            // Charging overlay — small bolt in the bottom-right corner.
            // (\uf0e7 bolt) Only visible when actually charging or topped up.
            BarIcon {
                visible: root._charging
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -3
                anchors.bottomMargin: -1
                glyph: "\uf0e7"
                glyphSize: 7
                color: Theme.accent
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root._pct) + ""
            color: root._low ? Theme.errorBright : Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            opacity: 0.85
        }
    }

    function _formatTime(secs) {
        if (!secs || secs < 60) return "";
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    BarTooltip {
        anchorItem: root
        show: root.containsMouse
        text: {
            if (!root._present) return "";
            const pct = Math.round(root._pct) + "%";
            if (root._charging) {
                if (root.dev.state === UPowerDeviceState.FullyCharged) return "Full · " + pct;
                const t = root._formatTime(root.dev.timeToFull);
                return t ? ("Charging · " + pct + " · " + t + " to full")
                         : ("Charging · " + pct);
            }
            const t = root._formatTime(root.dev.timeToEmpty);
            return t ? (pct + " · " + t + " remaining") : pct;
        }
    }
}
