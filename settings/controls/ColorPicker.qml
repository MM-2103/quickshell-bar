// ColorPicker.qml
// Compact HSV colour picker rendered as a same-tree overlay (z-bumped
// Item, NOT a separate window) so it floats above the surrounding
// settings rows without requiring nested PopupWindow gymnastics.
//
//   ┌─────────────────────────────┐
//   │ ┌─────────────────────────┐ │
//   │ │   SV square (drag)      │ │
//   │ └─────────────────────────┘ │
//   │  ▌▌▌▌▌▌ hue slider ▌▌▌▌▌▌  │
//   │  Hex: #16181c       [Done]  │
//   └─────────────────────────────┘
//
// Click anywhere on the SV square to set saturation + value; click on
// the hue slider to set hue. The hex line stays in sync, and emits
// `colorPicked(color)` on every change so the host (`ColorRow`) can
// live-write via `Local.set()`. The "Done" button closes the picker;
// clicking outside doesn't auto-dismiss in v1 (would need a captured
// event filter; defer that polish).

import QtQuick
import qs

Rectangle {
    id: root

    // Caller binds `currentColor` to the colour-being-edited; when the
    // user picks a new value, `colorPicked(c)` fires with the result.
    property color currentColor: "#000000"
    signal colorPicked(color c)

    // Open / close. Toggle from the swatch's MouseArea.
    property bool open: false
    visible: open

    function toggle() { root.open = !root.open; }
    function close()  { root.open = false; }

    // ---- chrome ----

    width: 244
    height: 220
    radius: Theme.radius
    color: Theme.bg
    border.color: Theme.border
    border.width: 1

    // Catch-all MouseArea inside the picker — absorbs clicks landing on
    // the picker's background (margins, between widgets) so they don't
    // fall through to the settings rows underneath. SV square, hue
    // slider, and the Done button each have their own MouseAreas
    // declared LATER in the tree so they win the hit-test against this
    // catcher (later siblings render on top + intercept first). Without
    // this, a click between widgets would land on whatever's under the
    // picker — usually a row header, sometimes another swatch — and
    // produce surprising behaviour.
    MouseArea {
        anchors.fill: parent
        // hoverEnabled keeps the cursor as ArrowCursor inside the picker
        // (rather than inheriting PointingHand from the swatch that
        // launched it). Subtle but feels correct.
        hoverEnabled: true
        onClicked: { /* swallow */ }
    }

    // ---- HSV state, derived from currentColor on open ----
    //
    // We don't continuously re-derive from currentColor while open
    // because doing so would fight the user's clicks (each click would
    // round-trip through Local.set → bindings → re-derive H/S/V →
    // potentially shift cursor). Instead we derive once on `open=true`
    // and let local clicks drive H/S/V from there.
    property real hue: 0          // 0..1
    property real sat: 0          // 0..1
    property real val: 0          // 0..1

    onOpenChanged: if (open) _deriveFromColor()
    Component.onCompleted: _deriveFromColor()

    function _deriveFromColor() {
        const c = root.currentColor;
        const r = c.r, g = c.g, b = c.b;
        const max = Math.max(r, g, b), min = Math.min(r, g, b);
        const delta = max - min;
        let h = 0;
        if (delta > 0) {
            if (max === r)      h = ((g - b) / delta) % 6;
            else if (max === g) h = (b - r) / delta + 2;
            else                h = (r - g) / delta + 4;
            h = h / 6;
            if (h < 0) h += 1;
        }
        const s = max === 0 ? 0 : delta / max;
        const v = max;
        root.hue = h;
        root.sat = s;
        root.val = v;
    }

    // Compute hex for the current H/S/V.
    function _hex() {
        const h6 = root.hue * 6;
        const i = Math.floor(h6);
        const f = h6 - i;
        const p = root.val * (1 - root.sat);
        const q = root.val * (1 - f * root.sat);
        const t = root.val * (1 - (1 - f) * root.sat);
        let r, g, b;
        switch (i % 6) {
            case 0: r = root.val; g = t; b = p; break;
            case 1: r = q; g = root.val; b = p; break;
            case 2: r = p; g = root.val; b = t; break;
            case 3: r = p; g = q; b = root.val; break;
            case 4: r = t; g = p; b = root.val; break;
            case 5: r = root.val; g = p; b = q; break;
        }
        const toHex = x => {
            const s = Math.round(x * 255).toString(16);
            return s.length === 1 ? "0" + s : s;
        };
        return "#" + toHex(r) + toHex(g) + toHex(b);
    }

    // Emit on any HSV change; debounced by Local.set on the receiver.
    onHueChanged: if (open) colorPicked(root._hex())
    onSatChanged: if (open) colorPicked(root._hex())
    onValChanged: if (open) colorPicked(root._hex())

    Column {
        anchors {
            fill: parent
            margins: 8
        }
        spacing: 8

        // ---- SV square ----
        Rectangle {
            id: svBox
            width: parent.width
            height: 120
            radius: Theme.radiusSmall
            // Background = pure-hue colour (S=1, V=1 at current hue).
            // Two overlay gradients on top map S (left→right) and V
            // (top→bottom inverted).
            color: Qt.hsva(root.hue, 1, 1, 1)
            clip: true

            // Saturation gradient: pure white at S=0 (left), transparent at right.
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "white" }
                    GradientStop { position: 1; color: "#00ffffff" }
                }
            }
            // Value gradient: transparent at top, pure black at V=0 (bottom).
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0; color: "#00000000" }
                    GradientStop { position: 1; color: "black" }
                }
            }

            // Indicator: small ring at (S, 1-V).
            Rectangle {
                width: 12; height: 12; radius: 6
                color: "transparent"
                border.color: "white"
                border.width: 2
                x: root.sat * (svBox.width - width)
                y: (1 - root.val) * (svBox.height - height)
                // Inner shadow ring for contrast on light areas.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: width / 2
                    color: "transparent"
                    border.color: "black"
                    border.width: 1
                }
            }

            MouseArea {
                anchors.fill: parent
                property bool _drag: false
                function _commit(x, y) {
                    root.sat = Math.max(0, Math.min(1, x / svBox.width));
                    root.val = Math.max(0, Math.min(1, 1 - y / svBox.height));
                }
                onPressed: mouse => { _drag = true; _commit(mouse.x, mouse.y); }
                onReleased: _drag = false
                onPositionChanged: mouse => { if (_drag) _commit(mouse.x, mouse.y); }
            }
        }

        // ---- hue slider ----
        Item {
            width: parent.width
            height: 16

            // Six-stop linear gradient covers the colour wheel.
            Rectangle {
                id: hueTrack
                anchors.fill: parent
                radius: 8
                clip: true
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0;  color: "#ff0000" }
                    GradientStop { position: 0.16; color: "#ffff00" }
                    GradientStop { position: 0.33; color: "#00ff00" }
                    GradientStop { position: 0.5;  color: "#00ffff" }
                    GradientStop { position: 0.66; color: "#0000ff" }
                    GradientStop { position: 0.83; color: "#ff00ff" }
                    GradientStop { position: 1.0;  color: "#ff0000" }
                }
            }

            // Indicator: thin vertical bar at hue position.
            Rectangle {
                width: 3; height: parent.height + 4
                anchors.verticalCenter: parent.verticalCenter
                x: root.hue * (parent.width - width)
                color: "white"
                border.color: "black"
                border.width: 1
            }

            MouseArea {
                anchors.fill: parent
                property bool _drag: false
                function _commit(x) {
                    root.hue = Math.max(0, Math.min(1, x / width));
                }
                onPressed: mouse => { _drag = true; _commit(mouse.x); }
                onReleased: _drag = false
                onPositionChanged: mouse => { if (_drag) _commit(mouse.x); }
            }
        }

        // ---- hex readout + done button ----
        Row {
            width: parent.width
            spacing: 8
            height: 24

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root._hex()
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                width: 80
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 80 - doneBtn.width - parent.spacing * 2
                height: 1
            }

            Rectangle {
                id: doneBtn
                anchors.verticalCenter: parent.verticalCenter
                width: 56; height: 22
                radius: Theme.radiusSmall
                color: doneMa.containsMouse ? Theme.text : Theme.surfaceHi
                border.color: Theme.border
                border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text: "Done"
                    color: doneMa.containsMouse ? Theme.bg : Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: doneMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }
    }
}
