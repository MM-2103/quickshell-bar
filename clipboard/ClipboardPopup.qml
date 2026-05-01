// ClipboardPopup.qml
// Full clipboard-history picker. Triggered via the qs-IPC handler in
// shell.qml (which the niri Mod+V binding calls into). One panel per
// monitor; only the focused-monitor's panel is visible.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs

PanelWindow {
    id: panel

    required property var modelData
    required property string focusedOutput

    screen: modelData

    readonly property bool isFocusedScreen:
        modelData && modelData.name === focusedOutput
    readonly property bool wantOpen:
        !!(ClipboardService && ClipboardService.popupOpen) && isFocusedScreen
    // Stay mapped briefly during fade-out so the animation can play.
    visible: wantOpen || hideHold.running
    Timer { id: hideHold; interval: 180; repeat: false }
    onWantOpenChanged: {
        if (wantOpen) hideHold.stop();
        else          hideHold.restart();
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Layer-shell: stay above normal windows + grab keyboard so the search
    // field receives input.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // No anchors → niri/wlroots horizontally and vertically centers a
    // free-floating layer surface.
    implicitWidth: 480
    implicitHeight: 460

    // ---- Filtered + ordered model ----
    property string query: ""

    readonly property var filtered: {
        const raw = ClipboardService ? ClipboardService.entries : [];
        const all = Array.isArray(raw) ? raw : [];
        const q = (query || "").trim().toLowerCase();
        if (!q) return all;
        return all.filter(e => e && e.preview
            && e.preview.toLowerCase().indexOf(q) >= 0);
    }

    property int selectedIndex: 0

    // Reset selection + query whenever the popup opens / model rebuilds.
    Connections {
        target: ClipboardService
        function onPopupOpenChanged() {
            if (ClipboardService.popupOpen) {
                panel.query = "";
                panel.selectedIndex = 0;
                Qt.callLater(() => searchInput.forceActiveFocus());
            }
        }
        function onEntriesChanged() {
            // Clamp selection to current filtered length.
            const len = panel.filtered.length;
            if (panel.selectedIndex >= len) panel.selectedIndex = Math.max(0, len - 1);
        }
    }
    onFilteredChanged: {
        if (selectedIndex >= filtered.length) selectedIndex = Math.max(0, filtered.length - 1);
    }

    // ---- Activation helpers ----
    function pasteSelected() {
        const e = filtered[selectedIndex];
        if (e) ClipboardService.paste(e.id);
    }
    function deleteSelected() {
        const e = filtered[selectedIndex];
        if (e) ClipboardService.remove(e.id, e.preview);
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

        opacity: panel.wantOpen ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        transform: Translate {
            y: panel.wantOpen ? 0 : 4
            Behavior on y {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }

        Column {
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 8

            // ---- Search input ----
            Rectangle {
                width: parent.width
                height: 32
                radius: Theme.radiusSmall
                color: Theme.surface
                border.color: searchInput.activeFocus ? Theme.text : Theme.border
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                TextInput {
                    id: searchInput
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                    }
                    verticalAlignment: TextInput.AlignVCenter
                    text: panel.query
                    onTextChanged: {
                        panel.query = text;
                        // Reset selection when filter changes.
                        panel.selectedIndex = 0;
                    }
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeNormal
                    selectByMouse: true
                    clip: true

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            ClipboardService.closePopup();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (panel.selectedIndex > 0) panel.selectedIndex--;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (panel.selectedIndex < panel.filtered.length - 1)
                                panel.selectedIndex++;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return
                                || event.key === Qt.Key_Enter) {
                            panel.pasteSelected();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Delete
                                && (event.modifiers & Qt.ShiftModifier)) {
                            panel.deleteSelected();
                            event.accepted = true;
                        }
                    }

                    // Placeholder
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: !searchInput.text && !searchInput.activeFocus
                        text: "Search clipboard…"
                        color: Theme.textMuted
                        font: searchInput.font
                    }
                }
            }

            // ---- List ----
            ListView {
                id: listView
                width: parent.width
                height: parent.height - searchInput.parent.height - footer.height - parent.spacing * 2
                clip: true
                spacing: 2
                model: panel.filtered
                interactive: true
                boundsBehavior: Flickable.StopAtBounds

                // Keep the selected item in view as the user navigates.
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                currentIndex: panel.selectedIndex
                Binding {
                    target: listView
                    property: "currentIndex"
                    value: panel.selectedIndex
                }

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 36
                    radius: Theme.radiusSmall

                    readonly property bool isSelected: index === panel.selectedIndex
                    readonly property bool isImage: modelData.isImage

                    color: isSelected
                        ? Theme.surfaceHi
                        : (rowMa.containsMouse ? Theme.surface : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    // Selected accent stripe on the left edge.
                    Rectangle {
                        visible: row.isSelected
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                            leftMargin: 1
                            topMargin: 2
                            bottomMargin: 2
                        }
                        width: 2
                        radius: 1
                        color: Theme.accent
                    }

                    // ---- Per-row image decoder ----
                    // Drops the decoded bytes into a tmp file the Image element
                    // can load. ListView reuses delegates as it scrolls — we
                    // gate via `running: isImage && needed` so non-image rows
                    // don't spawn anything.
                    property string thumbPath: ""
                    Process {
                        id: thumbProc
                        running: row.isImage && row.thumbPath === ""
                        command: row.isImage
                            ? ["sh", "-c",
                               "mkdir -p " + ClipboardService.thumbDir
                                 + " && out=" + ClipboardService.thumbDir + "/"
                                 + modelData.id + "." + modelData.ext
                                 + " ; [ -s \"$out\" ] || cliphist decode "
                                 + modelData.id + " > \"$out\" ; echo \"$out\""]
                            : ["true"]
                        stdout: StdioCollector {
                            onStreamFinished: {
                                const p = text.trim();
                                if (p) row.thumbPath = "file://" + p;
                            }
                        }
                    }

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 8
                        }
                        spacing: 10

                        // Thumbnail / icon column
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28

                            // Decoded image (Image is async, suppresses
                            // broken-icon by the visible:status==Ready guard).
                            Image {
                                id: thumb
                                anchors.fill: parent
                                visible: row.isImage
                                    && source.toString() !== ""
                                    && status === Image.Ready
                                source: row.thumbPath
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                                clip: true
                            }

                            // Placeholder while image decodes (or for text rows)
                            Rectangle {
                                anchors.fill: parent
                                visible: !thumb.visible
                                radius: 3
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    // Font Awesome 7 Solid: \uf03e image / \uf031 font
                                    text: row.isImage ? "\uf03e" : "\uf031"
                                    color: Theme.textDim
                                    font.family: Theme.fontIcon
                                    font.styleName: "Solid"
                                    font.pixelSize: 12
                                    renderType: Text.NativeRendering
                                }
                            }
                        }

                        // Preview text
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 28 - parent.spacing - delBtn.width - parent.spacing
                            text: row.isImage
                                ? ("Image · " + modelData.dimensions
                                    + (modelData.ext ? " · " + modelData.ext : ""))
                                : modelData.preview
                            color: row.isImage ? Theme.textDim : Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeNormal
                            font.italic: row.isImage
                            elide: Text.ElideRight
                        }

                        // Hover-revealed delete button.
                        Rectangle {
                            id: delBtn
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24
                            radius: Theme.radiusSmall
                            color: delMa.containsMouse ? Theme.bg : "transparent"
                            border.color: Theme.border
                            border.width: delMa.containsMouse ? 1 : 0
                            opacity: delMa.containsMouse
                                ? 1.0
                                : (rowMa.containsMouse || row.isSelected ? 0.6 : 0.0)
                            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                anchors.centerIn: parent
                                // Font Awesome 7 Solid: \uf014 trash-can
                                text: "\uf014"
                                color: Theme.text
                                font.family: Theme.fontIcon
                                font.styleName: "Solid"
                                font.pixelSize: 11
                                renderType: Text.NativeRendering
                            }

                            MouseArea {
                                id: delMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ClipboardService.remove(
                                    row.modelData.id, row.modelData.preview)
                            }
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        z: -1
                        onClicked: {
                            panel.selectedIndex = row.index;
                            ClipboardService.paste(row.modelData.id);
                        }
                    }
                }

                // Empty state
                Item {
                    anchors.centerIn: parent
                    visible: listView.count === 0
                    width: parent.width
                    height: 80
                    Text {
                        anchors.centerIn: parent
                        text: ClipboardService.loading
                            ? "Loading…"
                            : (panel.query ? "No matches" : "No clipboard history")
                        color: Theme.textMuted
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeNormal
                    }
                }
            }

            // ---- Footer hint ----
            Text {
                id: footer
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Esc · ↑↓ · Enter to copy · Shift+Del to remove"
                color: Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }
}
