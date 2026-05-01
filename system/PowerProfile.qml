// PowerProfile.qml
// Bar icon for power-profiles-daemon control.
//   Left   -> open the picker popup
//   Middle -> cycle to the next profile
//
// Visual: a single Font Awesome glyph that swaps with the current profile,
// using the universally-readable eco / gauge / lightning trio:
//   Power Saver  -> \uf06c leaf
//   Balanced     -> \uf624 gauge
//   Performance  -> \uf0e7 bolt   (Theme.accent — emphasises "max")

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs

MouseArea {
    id: root

    implicitWidth: 22
    implicitHeight: 22
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    function _glyph() {
        const p = PowerProfiles.profile;
        if (p === PowerProfile.Performance) return "\uf0e7"; // bolt
        if (p === PowerProfile.Balanced)    return "\uf624"; // gauge
        return "\uf06c";                                      // leaf (PowerSaver)
    }

    function _isPerformance() {
        return PowerProfiles.profile === PowerProfile.Performance;
    }

    function _cycle() {
        const list = [PowerProfile.PowerSaver, PowerProfile.Balanced];
        if (PowerProfiles.hasPerformanceProfile) list.push(PowerProfile.Performance);
        const cur = PowerProfiles.profile;
        const idx = list.indexOf(cur);
        const next = list[(idx + 1) % list.length];
        PowerProfiles.profile = next;
    }

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
            popup.toggle();
        } else if (mouse.button === Qt.MiddleButton) {
            root._cycle();
        }
    }

    // Hover background
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: popup.visible
            ? Theme.surfaceHi
            : (root.containsMouse ? Theme.surface : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // Profile glyph — leaf / gauge / bolt swap based on the active profile.
    // Performance gets accent color to emphasise "going hot".
    BarIcon {
        anchors.centerIn: parent
        glyph: root._glyph()
        color: root._isPerformance() ? Theme.accent : Theme.text
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    PowerProfilePopup {
        id: popup
        anchorItem: root
    }
}
