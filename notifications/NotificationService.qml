// NotificationService.qml
// Notification daemon + state for popups and the notification center.
//
// Design:
//   - All received notifications are tracked (history). The
//     `trackedNotifications` model is the source of truth for the center.
//   - The popup stack is rendered from `popupIds` — only ids in that list
//     get a floating card. Auto-expiring a popup just removes the id from
//     `popupIds`; the underlying Notification object stays in history
//     until the user explicitly dismisses it (× / action click / Clear).
//   - DND suppresses adding new notifications to popupIds (Critical urgency
//     bypasses this — Critical is meant to be unmissable).
//
// Replaces swaync. Only one daemon can own org.freedesktop.Notifications
// at a time, so swaync must be killed before this registers.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs

Singleton {
    id: root

    // ---- Public reactive state ----
    readonly property var trackedNotifications: server.trackedNotifications

    // Ids currently visible as floating popups.
    property var popupIds: []

    // Toggleable do-not-disturb. Doesn't persist across reloads (by design).
    property bool dndEnabled: false

    // Map: notificationId -> Date.now() when it arrived (used for "X min ago").
    property var notificationTimestamps: ({})

    // Map: notificationId -> screen name where the popup should appear.
    // Set at receive time (= currentScreen at that moment) and never changes,
    // so a notification stays anchored to the monitor it spawned on even
    // when the user moves focus to another monitor.
    property var notificationScreens: ({})

    // Bound externally (in shell.qml) to the currently focused output. Used
    // as the "spawn screen" for new notifications.
    property string currentScreen: ""

    // Internal "tick" — incremented every minute so relativeTime() is reactive.
    property int _tick: 0

    // ---- Helpers ----

    function defaultActionFor(notif) {
        if (!notif || !notif.actions) return null;
        const list = notif.actions;
        for (let i = 0; i < list.length; i++) {
            if (list[i].identifier === "default") return list[i];
        }
        return null;
    }

    // Resolve a notification image: pass URLs/paths through, look up bare
    // names via the icon theme.
    function resolveImage(src) {
        if (!src) return "";
        if (src.indexOf("://") >= 0 || src.startsWith("data:") || src.startsWith("/")) {
            return src;
        }
        return Quickshell.iconPath(src, true);
    }

    // Relative-time string like "just now", "5 min ago", "3 hr ago", or a date.
    function relativeTime(id) {
        const _ = root._tick; // reactivity dependency
        const ts = root.notificationTimestamps[id];
        if (!ts) return "";
        const diff = (Date.now() - ts) / 1000;
        if (diff < 60)         return "just now";
        if (diff < 3600)       return Math.floor(diff / 60) + " min ago";
        if (diff < 86400)      return Math.floor(diff / 3600) + " hr ago";
        if (diff < 604800)     return Math.floor(diff / 86400) + "d ago";
        return new Date(ts).toLocaleDateString();
    }

    // Auto-expire path — drops from popup stack but keeps in history.
    function removeFromPopup(id) {
        const next = root.popupIds.filter(x => x !== id);
        if (next.length !== root.popupIds.length) root.popupIds = next;
    }

    // Hard-dismiss every tracked notification (calls server CloseNotification).
    function clearAll() {
        const list = root.trackedNotifications.values.slice();
        for (let i = 0; i < list.length; i++) {
            if (list[i]) list[i].dismiss();
        }
        root.popupIds = [];
    }

    function toggleDnd() {
        root.dndEnabled = !root.dndEnabled;
    }

    // ---- Internals ----

    NotificationServer {
        id: server

        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: false
        persistenceSupported: true        // we keep history
        inlineReplySupported: false

        keepOnReload: true

        onNotification: function(notif) {
            notif.tracked = true;

            // Record timestamp
            const stamps = Object.assign({}, root.notificationTimestamps);
            stamps[notif.id] = Date.now();
            root.notificationTimestamps = stamps;

            // Pin to the screen that's focused at the moment of arrival.
            // Fall back to the first screen if nothing is focused yet.
            const screens = Object.assign({}, root.notificationScreens);
            const fallback = Quickshell.screens.length > 0
                ? Quickshell.screens[0].name : "";
            screens[notif.id] = root.currentScreen || fallback;
            root.notificationScreens = screens;

            // Decide if it should also pop. Critical bypasses DND.
            const isCritical = notif.urgency === NotificationUrgency.Critical;
            if (!root.dndEnabled || isCritical) {
                const ids = root.popupIds.slice();
                ids.push(notif.id);
                root.popupIds = ids;
            }
        }
    }

    // Cleanup popup ids and timestamps when notifications are removed
    // (user dismissed / action invoked / clearAll / app retracted).
    Connections {
        target: server.trackedNotifications
        function onObjectRemovedPost(obj, index) {
            if (!obj) return;
            const ids = root.popupIds.filter(x => x !== obj.id);
            if (ids.length !== root.popupIds.length) root.popupIds = ids;

            if (root.notificationTimestamps[obj.id] !== undefined) {
                const stamps = Object.assign({}, root.notificationTimestamps);
                delete stamps[obj.id];
                root.notificationTimestamps = stamps;
            }

            if (root.notificationScreens[obj.id] !== undefined) {
                const screens = Object.assign({}, root.notificationScreens);
                delete screens[obj.id];
                root.notificationScreens = screens;
            }
        }
    }

    // 1-min tick driving reactive relative-time strings.
    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root._tick++
    }
}
