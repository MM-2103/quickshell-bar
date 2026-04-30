// Tray.qml
// Renders StatusNotifierItems (system tray icons).
// Left  -> activate
// Middle-> secondaryActivate
// Right -> toggle a custom-themed TrayMenu (KDE-style)
// Wheel -> scroll

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs

Row {
    id: root
    spacing: 4

    // Currently-open menu state (one menu visible at a time).
    property var activeItem: null    // SystemTrayItem
    property Item activeAnchor: null // the icon's MouseArea

    function openMenuFor(item, anchor) {
        if (!item || !item.hasMenu) return;
        if (root.activeItem === item) {
            root.closeMenu();
        } else {
            // Tell the popup mutex we're opening (closes any other popup)
            // BEFORE the deferred mutation so there's no flicker of two
            // popups on screen.
            PopupController.open(root, () => root.closeMenu());
            // Defer state changes to AFTER the current click event has fully
            // unwound. Tearing down menu state during event delivery causes
            // use-after-free crashes in PopupAnchor.
            Qt.callLater(() => {
                trayMenu.closeSubmenus();
                root.activeAnchor = anchor;
                root.activeItem = item;
            });
        }
    }

    function closeMenu() {
        Qt.callLater(() => {
            trayMenu.closeSubmenus();
            root.activeItem = null;
            PopupController.closed(root);
            // NOTE: activeAnchor intentionally NOT cleared. Setting it to null
            // would propagate to anchor.item = null, triggering a Quickshell
            // bug (PopupAnchor::setItem(nullptr) crashes via onItemWindowChanged
            // dereferencing a null mItem). Natural destruction of the anchor
            // (e.g. tray app exits) is handled by Quickshell's destroyed-signal
            // connection. Visibility gating uses activeItem only.
        });
    }

    // Resolve `iconname?path=/dir` (XDG StatusNotifierItem custom-path extension)
    // into a real file URL. Quickshell wraps theme icons as `image://icon/<name>`,
    // so strip that prefix before assembling the file path.
    function resolveIcon(icon) {
        if (!icon || icon.indexOf("?path=") < 0) return icon;
        const q = icon.indexOf("?");
        let name = icon.substring(0, q);
        if (name.startsWith("image://icon/")) {
            name = name.substring("image://icon/".length);
        } else if (name.indexOf("/") >= 0) {
            name = name.substring(name.lastIndexOf("/") + 1);
        }
        const query = icon.substring(q + 1);
        for (const pair of query.split("&")) {
            const eq = pair.indexOf("=");
            if (eq < 0) continue;
            const k = pair.substring(0, eq);
            const v = decodeURIComponent(pair.substring(eq + 1));
            if (k === "path" && v) {
                return "file://" + v + "/" + name + ".png";
            }
        }
        return icon;
    }

    // The single shared root menu — its handle/anchor follow the active item.
    TrayMenu {
        id: trayMenu
        menuHandle: root.activeItem ? root.activeItem.menu : null
        anchorItem: root.activeAnchor
        // Visibility on activeItem alone — activeAnchor is never re-nulled
        // (avoids the PopupAnchor::setItem(nullptr) crash).
        visible: root.activeItem !== null
        onCloseRequested: root.closeMenu()
    }

    Repeater {
        model: SystemTray.items

        delegate: MouseArea {
            id: trayItem
            required property SystemTrayItem modelData

            implicitWidth: 22
            implicitHeight: 22
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton) {
                    if (modelData.onlyMenu) {
                        root.openMenuFor(modelData, trayItem);
                    } else {
                        modelData.activate();
                    }
                } else if (mouse.button === Qt.MiddleButton) {
                    modelData.secondaryActivate();
                } else if (mouse.button === Qt.RightButton) {
                    root.openMenuFor(modelData, trayItem);
                }
            }

            onWheel: wheel => modelData.scroll(wheel.angleDelta.y, false)

            // Hover background
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: trayItem.containsMouse ? Theme.surface : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            // Icon (with letter fallback if the theme can't resolve it)
            Item {
                anchors.centerIn: parent
                width: 16
                height: 16

                IconImage {
                    id: trayIcon
                    anchors.fill: parent
                    implicitSize: 16
                    source: root.resolveIcon(trayItem.modelData.icon)
                    asynchronous: true
                    visible: status !== Image.Error
                }

                Rectangle {
                    anchors.fill: parent
                    visible: trayIcon.status === Image.Error
                    radius: 3
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: {
                            const t = trayItem.modelData.title || trayItem.modelData.id || "?";
                            return t.charAt(0).toUpperCase();
                        }
                        color: Theme.text
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }

            // Tooltip (delayed appearance, hides immediately on leave)
            Timer {
                id: tipDelay
                interval: 350
                onTriggered: tip.visible = true
            }

            onContainsMouseChanged: {
                if (containsMouse) {
                    tipDelay.restart();
                } else {
                    tipDelay.stop();
                    tip.visible = false;
                }
            }

            PopupWindow {
                id: tip

                readonly property string label: {
                    const m = trayItem.modelData;
                    if (!m) return "";
                    return m.tooltipTitle || m.title || m.id || "";
                }

                visible: false
                anchor.item: trayItem
                anchor.rect.x: (trayItem.width - tip.width) / 2
                anchor.rect.y: trayItem.height + 6
                color: "transparent"
                implicitWidth: Math.max(40, tipText.implicitWidth + 16)
                implicitHeight: tipText.implicitHeight + 8

                Rectangle {
                    anchors.fill: parent
                    color: Theme.bg
                    border.color: Theme.border
                    border.width: 1
                    radius: Theme.radiusSmall

                    Text {
                        id: tipText
                        anchors.centerIn: parent
                        text: tip.label
                        color: Theme.text
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
