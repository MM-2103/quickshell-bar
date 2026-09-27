// IconButton.qml
// Square icon button for row actions and view-header controls in the
// Control Center detail views. Left click only: right and middle clicks
// fall through to nothing.
//
// An icon alone does not say what it does, so `hint` names the action.
// While the pointer is over the button, the enclosing ListRow or
// ViewHeader shows the hint in place of its status text. Nothing new
// appears on hover; existing text changes.
//
// confirm: true makes the first click arm the button for 3 s (check
// glyph, error colour, confirmHint shown without hover). Only a second
// click emits clicked(). Used for Forget.
//
// present: false hides the button but keeps its 24 px, so the buttons of
// every row stay in the same columns.

import QtQuick
import qs

Item {
    id: btn

    property string glyph: ""
    property string hint: ""
    property bool present: true
    // In-progress state: spinner glyph, not clickable, full opacity.
    property bool busy: false
    // Rotate the glyph continuously (scan in progress).
    property bool spinning: false
    // Glyph in the accent colour.
    property bool active: false
    property bool confirm: false
    property string confirmHint: "Click again to confirm"

    signal clicked()

    readonly property bool armed: confirmTimer.running
    readonly property bool hovered: ma.containsMouse
    readonly property bool interactive: present && enabled && !busy

    // One full turn, for actions with no lasting state (Wi-Fi rescan).
    function spinOnce() { spinOnceAnim.restart(); }

    // ---- Hint protocol ----
    // The nearest ancestor with acceptsHints shows shownHint.
    readonly property string shownHint:
        !present ? "" : armed ? confirmHint : (ma.containsMouse && interactive ? hint : "")
    readonly property var hintTarget: {
        for (let p = btn.parent; p; p = p.parent) if (p.acceptsHints === true) return p;
        return null;
    }
    onShownHintChanged: if (hintTarget) hintTarget.setHint(btn, shownHint)

    width: 24
    height: 24
    opacity: !present ? 0.0 : (enabled || busy ? 1.0 : 0.4)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: btn.armed ? Theme.bg
             : (ma.containsMouse && btn.interactive ? Theme.surfaceHi : "transparent")
        border.width: 1
        border.color: btn.armed ? Theme.error : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    Text {
        id: glyphText
        anchors.centerIn: parent
        text: btn.busy ? "\uf1ce" : (btn.armed ? "\uf00c" : btn.glyph)
        color: btn.armed ? Theme.error
             : btn.active ? Theme.accent
             : (ma.containsMouse && btn.interactive ? Theme.text : Theme.textDim)
        font.family: Theme.fontIcon
        font.styleName: "Solid"
        font.pixelSize: 11
        renderType: Text.NativeRendering

        // alwaysRunToEnd finishes the current turn on stop, so the glyph
        // never freezes at an angle.
        RotationAnimation on rotation {
            running: btn.busy || btn.spinning
            from: 0; to: 360
            duration: 1000
            loops: Animation.Infinite
            alwaysRunToEnd: true
        }
    }

    RotationAnimation {
        id: spinOnceAnim
        target: glyphText
        from: 0; to: 360
        duration: 700
        easing.type: Easing.OutCubic
    }

    Timer { id: confirmTimer; interval: 3000 }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: btn.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (btn.confirm && !confirmTimer.running) {
                confirmTimer.restart();
                return;
            }
            confirmTimer.stop();
            btn.clicked();
        }
    }
}
