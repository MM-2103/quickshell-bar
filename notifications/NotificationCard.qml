// NotificationCard.qml
// Single notification card, used in two contexts:
//   mode = "popup"  -> floating top-right toast (slide-in, auto-dismiss timer,
//                       × on hover, no timestamp)
//   mode = "center" -> notification center entry (no animation, no timer,
//                       × always visible, shows relative timestamp)
//
// Behavior:
//   - Click body: invoke the "default" action if present, then dismiss
//     (unless `notif.resident`).
//   - Click an action button: invoke that action, then dismiss
//     (unless `notif.resident`).
//   - Click ×: immediate dismiss (drops from history).
//   - In popup mode, hover pauses the auto-dismiss timer.
//   - Auto-expire (popup mode only) calls NotificationService.removeFromPopup
//     so the card disappears from the stack but stays in history.
//   - Critical urgency: sticky + 3px accent stripe down the left edge.

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs

Rectangle {
    id: card

    required property var notif
    property string mode: "popup"   // "popup" | "center"

    readonly property bool isPopup:  mode === "popup"
    readonly property bool isCenter: mode === "center"

    width: 360
    implicitHeight: layoutColumn.implicitHeight + (isCenter ? 12 : 16)
    height: implicitHeight

    radius: Theme.radius
    color: Theme.bg
    border.color: Theme.border
    border.width: 1

    readonly property bool isCritical:
        notif && notif.urgency === NotificationUrgency.Critical
    readonly property bool isSticky:
        isCritical || (notif && notif.expireTimeout === 0)

    readonly property real timeoutSeconds: {
        if (!notif) return 5;
        if (notif.expireTimeout > 0) return notif.expireTimeout;
        return 5; // server default
    }

    readonly property string appIconSrc:
        notif && notif.appIcon ? Quickshell.iconPath(notif.appIcon, true) : ""

    readonly property string bodyImageSrc:
        notif && notif.image ? NotificationService.resolveImage(notif.image) : ""

    readonly property var defaultAction: NotificationService.defaultActionFor(notif)

    // ---- Slide-in animation (popup mode only) ----
    state: "shown"
    states: [
        State {
            name: "hidden"
            PropertyChanges { target: card; x: 60; opacity: 0 }
        },
        State {
            name: "shown"
            PropertyChanges { target: card; x: 0; opacity: 1 }
        }
    ]
    transitions: [
        Transition {
            from: "hidden"; to: "shown"
            NumberAnimation {
                properties: "x,opacity"
                duration: 220
                easing.type: Easing.OutQuad
            }
        }
    ]

    // Only animate the slide-in for popup mode. Center entries appear instantly.
    Component.onCompleted: {
        if (card.isPopup) {
            state = "hidden";
            Qt.callLater(() => card.state = "shown");
        }
    }

    // ---- Auto-dismiss timer (popup mode only) ----
    Timer {
        id: dismissTimer
        interval: card.timeoutSeconds * 1000
        running: card.isPopup && !card.isSticky && !cardHover.containsMouse
        repeat: false
        onTriggered: {
            // Drop from popup stack but keep in history.
            if (card.notif) NotificationService.removeFromPopup(card.notif.id);
        }
    }

    // ---- Click / hover area covering the whole card body ----
    MouseArea {
        id: cardHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        z: -1
        onClicked: {
            if (!card.notif) return;
            if (card.defaultAction) {
                card.defaultAction.invoke();
                if (!card.notif.resident) card.notif.dismiss();
            } else {
                card.notif.dismiss();
            }
        }
    }

    // ---- Critical urgency stripe ----
    Rectangle {
        visible: card.isCritical
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            margins: 1
        }
        width: 3
        radius: 1
        color: Theme.accent
    }

    // ---- Layout ----
    Column {
        id: layoutColumn
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 8
            leftMargin: card.isCritical ? 12 : 8
        }
        spacing: 6

        // Header row: appIcon, appName, ×
        Row {
            id: headerRow
            width: parent.width
            spacing: 6
            height: 16

            // App icon — only present (in the layout) when we have a
            // resolvable icon path. visible:false on the wrapper guarantees
            // the IconImage never gets a chance to render its broken-image
            // placeholder.
            Item {
                width: card.appIconSrc !== "" ? 14 : 0
                height: 14
                anchors.verticalCenter: parent.verticalCenter
                visible: card.appIconSrc !== ""

                IconImage {
                    anchors.fill: parent
                    implicitSize: 14
                    source: card.appIconSrc
                    asynchronous: false
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                    - (card.appIconSrc !== "" ? 14 + parent.spacing : 0)
                    - closeBtn.width - parent.spacing
                    - (timeText.visible ? timeText.implicitWidth + parent.spacing : 0)
                text: card.notif ? (card.notif.appName || "Notification") : ""
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }

            // Relative timestamp — only shown in center mode.
            Text {
                id: timeText
                anchors.verticalCenter: parent.verticalCenter
                visible: card.isCenter && card.notif !== null
                text: card.notif ? NotificationService.relativeTime(card.notif.id) : ""
                color: Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
            }

            // × close button — hover-revealed in popup mode, always shown in center.
            Rectangle {
                id: closeBtn
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                radius: 8
                color: closeMa.containsMouse ? Theme.surfaceHi : "transparent"
                opacity: card.isCenter || cardHover.containsMouse ? 1.0 : 0.4
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    // Font Awesome 7 Solid: \uf00d xmark
                    text: "\uf00d"
                    color: Theme.text
                    font.family: Theme.fontIcon
                    font.styleName: "Solid"
                    font.pixelSize: 9
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (card.notif) card.notif.dismiss();
                    }
                }
            }
        }

        // Body: summary + body text on the left, optional image on the right.
        Item {
            width: parent.width
            implicitHeight: Math.max(textColumn.implicitHeight,
                                     card.bodyImageSrc !== "" ? 48 : 0)

            Column {
                id: textColumn
                anchors {
                    left: parent.left
                    right: card.bodyImageSrc !== "" ? bodyImage.left : parent.right
                    top: parent.top
                    rightMargin: card.bodyImageSrc !== "" ? 8 : 0
                }
                spacing: 2

                Text {
                    width: parent.width
                    text: card.notif ? card.notif.summary : ""
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    visible: text.length > 0
                }
                Text {
                    width: parent.width
                    text: card.notif ? card.notif.body : ""
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeNormal
                    textFormat: Text.RichText
                    wrapMode: Text.WordWrap
                    maximumLineCount: 6
                    elide: Text.ElideRight
                    visible: text.length > 0
                    onLinkActivated: link => Qt.openUrlExternally(link)
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                        enabled: parent.hoveredLink !== ""
                    }
                }
            }

            // Body image — wrapped in a gated Item so an empty/failed
            // source can't show a broken-image placeholder.
            Item {
                id: bodyImage
                anchors.right: parent.right
                anchors.top: parent.top
                width: card.bodyImageSrc !== "" ? 48 : 0
                height: 48
                visible: card.bodyImageSrc !== ""

                IconImage {
                    anchors.fill: parent
                    implicitSize: 48
                    source: card.bodyImageSrc
                    asynchronous: true
                }
            }
        }

        // Action buttons row (excluding "default" — that's bound to body click).
        Row {
            visible: card.notif && card.notif.actions
                     && actionsRepeater.count > 0
            spacing: 6
            height: visible ? 26 : 0

            Repeater {
                id: actionsRepeater
                model: card.notif ? card.notif.actions : []

                delegate: Rectangle {
                    required property var modelData
                    visible: modelData && modelData.identifier !== "default"
                    width: actionLabel.implicitWidth + 16
                    height: visible ? 26 : 0
                    radius: Theme.radiusSmall
                    color: actionMa.containsMouse ? Theme.text : Theme.surfaceHi
                    border.color: Theme.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: parent.modelData ? parent.modelData.text : ""
                        color: actionMa.containsMouse ? Theme.bg : Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: actionMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (parent.modelData) parent.modelData.invoke();
                            if (card.notif && !card.notif.resident) {
                                card.notif.dismiss();
                            }
                        }
                    }
                }
            }
        }
    }
}
