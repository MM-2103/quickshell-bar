// TrayMenu.qml
// Custom-themed PopupWindow rendering a SystemTrayItem's DBusMenu via QsMenuOpener.
// Recursive: any entry with hasChildren spawns another TrayMenu anchored to its row.
//
// Inputs:
//   menuHandle  : QsMenuHandle (root menu = trayItem.menu, submenu = a QsMenuEntry)
//   anchorItem  : the item to position under/next to
//   parentMenu  : null for root, or the parent TrayMenu for a submenu
//
// Usage: parent sets `visible = true` on the root menu. Selecting an entry calls
//        rootMenu.requestClose() which closes the whole chain.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs

PopupWindow {
    id: menu

    required property var menuHandle
    property Item anchorItem
    property TrayMenu parentMenu: null

    // The currently-open submenu of this menu (so we can close it when navigating).
    property var _activeChild: null

    // Emitted on the root by entry-trigger; the owner (Tray.qml) is responsible for
    // setting visibility off (visibility is bound, never assigned imperatively).
    signal closeRequested()

    color: "transparent"

    // Submenus open to the right of their anchor row; root menus open below.
    // Y/X compensate for the 12 px shadow padding so the visible body lands
    // at the same screen position as before.
    anchor.item: anchorItem
    anchor.rect.x: parentMenu
        ? (anchorItem ? anchorItem.width - 4 - 12 : 0)
        : (anchorItem ? -((menu.width - anchorItem.width) / 2) : 0)
    anchor.rect.y: parentMenu
        ? -12
        : (anchorItem ? anchorItem.height + 4 - 12 : 0)
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipY

    implicitWidth: 240 + 24
    implicitHeight: contentColumn.implicitHeight + 8 + 24

    // ---- API for chain control ----
    function requestClose() {
        // Walk to the root, then defer cleanup to after the click event finishes.
        // Doing teardown inside the click handler leads to PopupAnchor accessing
        // destroyed delegates during the same event delivery (SIGSEGV).
        let m = menu;
        while (m.parentMenu) m = m.parentMenu;
        Qt.callLater(() => {
            m._destroyChildren();
            m.closeRequested();
        });
    }

    function _destroyChildren() {
        if (menu._activeChild) {
            menu._activeChild._destroyChildren();
            const child = menu._activeChild;
            menu._activeChild = null;
            // Hide and destroy. DO NOT set anchorItem = null — Quickshell's
            // PopupAnchor::setItem crashes on explicit nullptr while the
            // current item is still valid (calls window() on null mItem).
            // Natural destruction of the anchor row is handled correctly by
            // PopupAnchor's destroyed-signal connection.
            child.visible = false;
            Qt.callLater(() => child.destroy());
        }
    }

    // Public wrapper so Tray.qml can force cleanup before clearing activeItem.
    function closeSubmenus() {
        _destroyChildren();
    }

    // If the root menu hides for any reason (toggle, item disappears, ...), drop
    // any open submenus too so they don't become orphans.
    onVisibleChanged: {
        if (!visible) menu._destroyChildren();
    }

    // Loaded lazily on first submenu open. QML disallows declaring a self-
    // referential Component inline, so we resolve at runtime.
    property var _subComp: null

    function _openSubmenu(entry, anchorRow) {
        if (menu._activeChild) {
            const old = menu._activeChild;
            menu._activeChild = null;
            // Same Quickshell bug avoidance as above — never null anchorItem.
            old.visible = false;
            Qt.callLater(() => old.destroy());
        }
        if (!menu._subComp) {
            menu._subComp = Qt.createComponent("TrayMenu.qml");
            if (menu._subComp.status === Component.Error) {
                console.error("[TrayMenu] subcomp error:", menu._subComp.errorString());
                return;
            }
        }
        const sub = menu._subComp.createObject(menu, {
            menuHandle: entry,
            anchorItem: anchorRow,
            parentMenu: menu,
            visible: true
        });
        if (sub) menu._activeChild = sub;
    }

    QsMenuOpener {
        id: opener
        menu: menu.menuHandle
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
            shadowBlur: 0.6
        }

        Column {
            id: contentColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 4
            }
            spacing: 0

            Repeater {
                model: opener.children
                delegate: Item {
                    id: entryRoot
                    required property QsMenuEntry modelData
                    width: contentColumn.width
                    height: modelData.isSeparator ? 8 : 28

                    // ---- Separator ----
                    Rectangle {
                        visible: entryRoot.modelData.isSeparator
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 6
                            rightMargin: 6
                        }
                        height: 1
                        color: Theme.border
                    }

                    // ---- Entry row ----
                    Rectangle {
                        visible: !entryRoot.modelData.isSeparator
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: (rowMouse.containsMouse && entryRoot.modelData.enabled)
                            ? Theme.surfaceHi
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        // checkmark or radio indicator
                        Text {
                            id: checkMark
                            anchors {
                                left: parent.left
                                leftMargin: 6
                                verticalCenter: parent.verticalCenter
                            }
                            visible: entryRoot.modelData.buttonType !== QsMenuButtonType.None
                            width: 12
                            text: {
                                const m = entryRoot.modelData;
                                if (m.buttonType === QsMenuButtonType.None) return "";
                                if (m.checkState === Qt.Checked) {
                                    return m.buttonType === QsMenuButtonType.RadioButton ? "●" : "✓";
                                }
                                return "";
                            }
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // icon (hidden if it fails to load — theme name unknown, etc.)
                        IconImage {
                            id: entryIcon
                            anchors {
                                left: checkMark.visible ? checkMark.right : parent.left
                                leftMargin: checkMark.visible ? 4 : 8
                                verticalCenter: parent.verticalCenter
                            }
                            visible: entryRoot.modelData.icon !== "" && status !== Image.Error
                            implicitSize: 14
                            source: entryRoot.modelData.icon
                            asynchronous: false
                        }

                        // label
                        Text {
                            anchors {
                                left: entryIcon.visible
                                    ? entryIcon.right
                                    : (checkMark.visible ? checkMark.right : parent.left)
                                leftMargin: 8
                                right: arrow.visible ? arrow.left : parent.right
                                rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            text: entryRoot.modelData.text
                            color: entryRoot.modelData.enabled ? Theme.text : Theme.textMuted
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeNormal
                            elide: Text.ElideRight
                        }

                        // submenu arrow — Font Awesome 7 Solid \uf054 chevron-right.
                        Text {
                            id: arrow
                            anchors {
                                right: parent.right
                                rightMargin: 6
                                verticalCenter: parent.verticalCenter
                            }
                            visible: entryRoot.modelData.hasChildren
                            text: "\uf054"
                            color: Theme.textDim
                            font.family: Theme.fontIcon
                            font.styleName: "Solid"
                            font.pixelSize: 9
                            renderType: Text.NativeRendering
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: entryRoot.modelData.enabled
                            cursorShape: entryRoot.modelData.enabled
                                ? Qt.PointingHandCursor
                                : Qt.ArrowCursor

                            // Hovering an entry with a submenu opens it; hovering one
                            // without closes any open submenu. Defer to avoid
                            // mutating popup state during hover/click delivery.
                            onContainsMouseChanged: {
                                if (!containsMouse) return;
                                Qt.callLater(() => {
                                    if (entryRoot.modelData.hasChildren) {
                                        menu._openSubmenu(entryRoot.modelData, entryRoot);
                                    } else {
                                        menu._destroyChildren();
                                    }
                                });
                            }

                            onClicked: {
                                if (entryRoot.modelData.hasChildren) {
                                    Qt.callLater(() => {
                                        if (menu._activeChild) {
                                            menu._destroyChildren();
                                        } else {
                                            menu._openSubmenu(entryRoot.modelData, entryRoot);
                                        }
                                    });
                                } else {
                                    // entry.triggered() is safe (it's a DBus call out);
                                    // requestClose already defers internally.
                                    entryRoot.modelData.triggered();
                                    menu.requestClose();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
