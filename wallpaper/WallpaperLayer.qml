// WallpaperLayer.qml
// Per-monitor wallpaper renderer. Replaces swaybg.
//
// This is a layer-shell PanelWindow on the `Background` layer (below
// `Bottom` / `Top` / `Overlay`), spanning the full output. Two stacked
// Image elements provide a 400 ms cross-fade on wallpaper change:
// the new image loads into the back buffer, then opacities are animated
// in parallel so the swap appears as a smooth crossfade rather than a
// hard cut. Initial load on shell start does NOT animate (would feel
// like a flash from black on every reload).

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.wallpaper

PanelWindow {
    id: panel

    required property var modelData
    screen: modelData

    // Solid black under the Image so the brief moment between layout and
    // first-frame doesn't show whatever was on the compositor's clear color.
    color: "black"
    exclusionMode: ExclusionMode.Ignore

    // Render BELOW everything else. Bar is `Top` (default), popups are
    // `Top` / `Overlay`. Background is the lowest tier — exactly where
    // a wallpaper belongs.
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell-wallpaper"

    // Cover the whole output. Anchoring all four sides + ExclusionMode.Ignore
    // means the wallpaper extends behind the bar and any other layer-shell
    // surfaces we might add later, without reserving any screen real estate.
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Reactive: re-evaluates whenever WallpaperService.paths / lastSetPath
    // change (both observable). Empty string means "no wallpaper available
    // for this output" — fall through to the black fallback.
    readonly property string targetSource:
        WallpaperService.pathFor(modelData ? modelData.name : "")

    // Track which Image is currently showing so we can swap the OTHER one
    // for the next change. Avoids flicker that would happen if we always
    // wrote the new source over the visible Image.
    QtObject {
        id: dbl
        property bool _waitingForReady: false
    }

    // ---- Cross-fade stage ----

    Item {
        id: stage
        anchors.fill: parent

        // Back buffer: holds the OUTGOING image during a fade. At rest its
        // opacity is 0 and source is empty / stale. Visible only mid-fade.
        Image {
            id: back
            anchors.fill: parent
            asynchronous: true
            cache: true
            sourceSize.width: parent.width
            sourceSize.height: parent.height
            fillMode: WallpaperService.fillModeMap[WallpaperService.fillMode]
                      || Image.PreserveAspectCrop
            opacity: 0.0
            visible: source.toString() !== "" && status === Image.Ready
        }

        // Front buffer: holds the CURRENT image. At rest its opacity is 1.
        // On a wallpaper change we copy its current source into `back`,
        // load the new source here, and animate the cross-fade once
        // `front.status` reaches Image.Ready.
        Image {
            id: front
            anchors.fill: parent
            asynchronous: true
            cache: true
            sourceSize.width: parent.width
            sourceSize.height: parent.height
            fillMode: WallpaperService.fillModeMap[WallpaperService.fillMode]
                      || Image.PreserveAspectCrop
            opacity: 1.0
            visible: source.toString() !== "" && status === Image.Ready

            // When a queued change finishes loading, kick off the parallel
            // opacity animation. Without this gate we'd cross-fade to a
            // momentarily-blank front buffer and then snap to the image.
            onStatusChanged: {
                if (status === Image.Ready && dbl._waitingForReady) {
                    dbl._waitingForReady = false;
                    crossFade.restart();
                }
            }
        }

        ParallelAnimation {
            id: crossFade
            NumberAnimation {
                target: back; property: "opacity"
                from: 1.0; to: 0.0
                duration: 400; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: front; property: "opacity"
                from: 0.0; to: 1.0
                duration: 400; easing.type: Easing.OutCubic
            }
        }
    }

    // ---- Apply target → buffers ----

    onTargetSourceChanged: _applyTarget()
    Component.onCompleted: _applyTarget()

    function _applyTarget() {
        const next = panel.targetSource || "";
        const cur  = front.source.toString();
        if (next === cur) return;

        if (cur === "") {
            // Initial load (or post-restart). Skip the cross-fade — there's
            // nothing meaningful to fade FROM, and animating from solid
            // black on every shell reload feels like a stutter.
            front.opacity = 1.0;
            back.opacity = 0.0;
            front.source = next;
            return;
        }

        // Subsequent change: copy current to back, load new into front,
        // arm the fade for when `front.status` reaches Ready.
        back.source = front.source;
        back.opacity = 1.0;
        front.opacity = 0.0;
        front.source = next;
        dbl._waitingForReady = true;
    }
}
