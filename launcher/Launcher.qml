// Launcher.qml
// App launcher popup. Triggered via the qs-IPC handler in shell.qml
// (which the niri Mod+P binding calls into). One panel per monitor;
// only the focused-monitor's panel is visible.

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
    visible: !!(LauncherService && LauncherService.popupOpen) && isFocusedScreen

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Layer-shell: above normal windows; Exclusive keyboard so every
    // keystroke (including space/letters) goes to our search field.
    // niri compositor-keybinds (Mod+anything) still take precedence.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // No anchors → wlroots horizontally and vertically centers a
    // free-floating layer surface.
    implicitWidth: 540
    implicitHeight: 520

    // ---- Convenience handles ----
    readonly property var filtered:
        LauncherService ? LauncherService.filtered : []

    property int selectedIndex: 0

    // Reset selection + search input when the popup opens.
    Connections {
        target: LauncherService
        function onPopupOpenChanged() {
            if (LauncherService.popupOpen) {
                panel.selectedIndex = 0;
                Qt.callLater(() => searchInput.forceActiveFocus());
            }
        }
    }
    onFilteredChanged: {
        if (selectedIndex >= filtered.length) {
            selectedIndex = Math.max(0, filtered.length - 1);
        }
    }

    function launchSelected() {
        const e = filtered[selectedIndex];
        if (e) LauncherService.launch(e);
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

        Column {
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 8

            // ---- Search input ----
            Rectangle {
                width: parent.width
                height: 36
                radius: Theme.radiusSmall
                color: Theme.surface
                border.color: searchInput.activeFocus ? Theme.text : Theme.border
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                TextInput {
                    id: searchInput
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 12
                    }
                    verticalAlignment: TextInput.AlignVCenter
                    text: LauncherService ? LauncherService.query : ""
                    onTextChanged: {
                        if (LauncherService) LauncherService.query = text;
                        panel.selectedIndex = 0;
                    }
                    color: Theme.text
                    font.pixelSize: 13
                    selectByMouse: true
                    clip: true

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            LauncherService.closePopup();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (panel.selectedIndex > 0) panel.selectedIndex--;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (panel.selectedIndex < panel.filtered.length - 1)
                                panel.selectedIndex++;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageUp) {
                            panel.selectedIndex = Math.max(0, panel.selectedIndex - 8);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageDown) {
                            panel.selectedIndex = Math.min(
                                panel.filtered.length - 1,
                                panel.selectedIndex + 8);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Home) {
                            panel.selectedIndex = 0;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_End) {
                            panel.selectedIndex = Math.max(0, panel.filtered.length - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return
                                || event.key === Qt.Key_Enter) {
                            panel.launchSelected();
                            event.accepted = true;
                        }
                    }

                    // Placeholder
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: !searchInput.text && !searchInput.activeFocus
                        text: "Search apps…"
                        color: Theme.textMuted
                        font: searchInput.font
                    }
                }
            }

            // ---- Results ----
            ListView {
                id: listView
                width: parent.width
                height: parent.height - searchInput.parent.height - footer.height - parent.spacing * 2
                clip: true
                spacing: 2
                // Only build delegates when the popup is actually visible —
                // avoids spawning ~hundreds of IconImages (and the noisy
                // "buffer too big" SVG warnings) at shell-load time.
                model: panel.visible ? panel.filtered : []
                interactive: true
                boundsBehavior: Flickable.StopAtBounds

                currentIndex: panel.selectedIndex
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
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
                    height: 52
                    radius: Theme.radiusSmall

                    readonly property bool isSelected: index === panel.selectedIndex
                    readonly property string kind: modelData && modelData.kind ? modelData.kind : "app"

                    // Per-kind derived strings (computed once per row).
                    readonly property string title: {
                        switch (kind) {
                            case "app":   return modelData.entry ? (modelData.entry.name || "") : "";
                            case "calc":  return modelData.text || "";
                            case "web":   return modelData.text || "";
                            case "emoji": return modelData.name || "";
                        }
                        return "";
                    }
                    readonly property string subtitle: {
                        switch (kind) {
                            case "app":
                                if (!modelData.entry) return "";
                                return modelData.entry.genericName
                                    || modelData.entry.comment
                                    || "";
                            case "calc":  return "Press Enter to copy";
                            case "web":   return "Search " + (LauncherService ? LauncherService.searchName : "");
                            case "emoji": return modelData.category || "";
                        }
                        return "";
                    }
                    readonly property string appIconSrc: {
                        if (kind !== "app") return "";
                        if (!modelData.entry || !modelData.entry.icon) return "";
                        return Quickshell.iconPath(modelData.entry.icon, true);
                    }
                    readonly property string webIconSrc:
                        kind === "web" ? Quickshell.iconPath("system-search", true) : ""

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
                            topMargin: 4
                            bottomMargin: 4
                        }
                        width: 2
                        radius: 1
                        color: Theme.accent
                    }

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 12
                        }
                        spacing: 12

                        // ---- Icon area (32px square, contents vary by kind) ----
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 32

                            // App icon (or fallback square if it doesn't resolve).
                            IconImage {
                                anchors.fill: parent
                                source: row.appIconSrc
                                visible: row.kind === "app" && row.appIconSrc !== ""
                                asynchronous: true
                                smooth: true
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: row.kind === "app" && row.appIconSrc === ""
                                radius: Theme.radiusSmall
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: row.title.length
                                        ? row.title.charAt(0).toUpperCase()
                                        : "?"
                                    color: Theme.textDim
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }

                            // Calc glyph (= sign).
                            Rectangle {
                                anchors.fill: parent
                                visible: row.kind === "calc"
                                radius: Theme.radiusSmall
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "="
                                    color: Theme.text
                                    font.pixelSize: 18
                                    font.bold: true
                                }
                            }

                            // Web search icon (with text fallback if theme misses it).
                            IconImage {
                                anchors.fill: parent
                                source: row.webIconSrc
                                visible: row.kind === "web" && row.webIconSrc !== ""
                                asynchronous: true
                                smooth: true
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: row.kind === "web" && row.webIconSrc === ""
                                radius: Theme.radiusSmall
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "?"
                                    color: Theme.text
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                            }

                            // Emoji glyph (rendered as text via Noto Color Emoji fallback).
                            Text {
                                anchors.centerIn: parent
                                visible: row.kind === "emoji"
                                text: row.modelData && row.modelData.char ? row.modelData.char : ""
                                font.pixelSize: 24
                            }
                        }

                        // ---- Title + subtitle ----
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: row.width - 32 - 12 - 24    // minus icon + spacing + side margins
                            spacing: 2

                            Text {
                                width: parent.width
                                text: row.title
                                color: Theme.text
                                font.pixelSize: 13
                                font.family: row.kind === "calc" ? "monospace" : font.family
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: row.subtitle
                                color: Theme.textDim
                                font.pixelSize: 11
                                elide: Text.ElideRight
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
                            LauncherService.launch(row.modelData);
                        }
                    }
                }

                // Empty state — message depends on which mode the user is in.
                Item {
                    anchors.centerIn: parent
                    visible: listView.count === 0
                    width: parent.width
                    height: 80
                    Text {
                        anchors.centerIn: parent
                        readonly property string q:
                            LauncherService ? LauncherService.query : ""
                        text: {
                            if (q.length === 0) return "Loading apps…";
                            const head = q.charAt(0);
                            if (head === "?") return q.length === 1
                                ? "Type to search the web"
                                : "No matches";
                            if (head === ";") return q.length === 1
                                ? "Type to search emoji"
                                : "No matching emoji";
                            if (head === "=") return q.length === 1
                                ? "Type a math expression"
                                : "Invalid expression";
                            return "No matches";
                        }
                        color: Theme.textMuted
                        font.pixelSize: 12
                    }
                }
            }

            // ---- Footer hint (mode-aware based on selected row) ----
            Text {
                id: footer
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: {
                    const r = panel.filtered[panel.selectedIndex];
                    if (!r) return "Esc · ↑↓ · Enter";
                    switch (r.kind) {
                        case "calc":  return "Esc · Enter to copy result";
                        case "web":   return "Esc · Enter to search";
                        case "emoji": return "Esc · ↑↓ · Enter to copy";
                        default:      return "Esc · ↑↓ · Enter to launch";
                    }
                }
                color: Theme.textMuted
                font.pixelSize: 10
            }
        }
    }
}
