// MediaService.qml
// Singleton wrapper around Quickshell.Services.Mpris that picks one
// "current" player to show in the bar/popup, plus action helpers and a
// time formatter used by the popup.
//
// Player precedence:
//   1. Whichever player the user explicitly pinned (pickNext/pickPrev), or
//   2. Any player in MprisPlaybackState.Playing, or
//   3. Any player in MprisPlaybackState.Paused, or
//   4. The first player in the list, or
//   5. null (the bar icon hides itself).

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: Mpris.players

    // Filter out proxy daemons that duplicate real players. Right now this
    // means `playerctld`, which publishes a virtual MPRIS player mirroring
    // whichever real player is currently active — so without this filter
    // the popup shows every real player twice.
    readonly property var visiblePlayers: {
        const all = players.values;
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const p = all[i];
            if (!p) continue;
            const name = p.dbusName || "";
            if (name.indexOf("playerctld") >= 0) continue;
            out.push(p);
        }
        return out;
    }

    // -1 means "auto-pick"; >= 0 is the user-selected index in visiblePlayers.
    // We don't reset this on player list changes — currentIndex below clamps
    // it to a sensible value if it falls out of range.
    property int pinnedIndex: -1

    // Reactive: re-evaluates when the visible-player list grows/shrinks or
    // when any player's playbackState changes (since the function reads
    // playbackState for each player it considers, the binding tracker
    // registers them).
    readonly property int currentIndex: {
        const list = visiblePlayers;
        if (list.length === 0) return -1;
        if (pinnedIndex >= 0 && pinnedIndex < list.length) return pinnedIndex;

        for (let i = 0; i < list.length; i++) {
            if (list[i].playbackState === MprisPlaybackState.Playing) return i;
        }
        for (let i = 0; i < list.length; i++) {
            if (list[i].playbackState === MprisPlaybackState.Paused) return i;
        }
        return 0;
    }

    readonly property var currentPlayer: {
        const list = visiblePlayers;
        return currentIndex >= 0 && currentIndex < list.length ? list[currentIndex] : null;
    }

    readonly property bool hasPlayers: visiblePlayers.length > 0
    readonly property bool isPlaying:
        currentPlayer && currentPlayer.playbackState === MprisPlaybackState.Playing
    readonly property bool isPaused:
        currentPlayer && currentPlayer.playbackState === MprisPlaybackState.Paused

    // ---- Action helpers (operate on currentPlayer; no-op when missing) ----

    function togglePlay() {
        if (currentPlayer && currentPlayer.canTogglePlaying) currentPlayer.togglePlaying();
    }
    function next() {
        if (currentPlayer && currentPlayer.canGoNext) currentPlayer.next();
    }
    function previous() {
        if (currentPlayer && currentPlayer.canGoPrevious) currentPlayer.previous();
    }

    // ---- Player switching ----

    function pickNext() {
        const n = visiblePlayers.length;
        if (n <= 1) return;
        const cur = currentIndex >= 0 ? currentIndex : 0;
        pinnedIndex = (cur + 1) % n;
    }
    function pickPrev() {
        const n = visiblePlayers.length;
        if (n <= 1) return;
        const cur = currentIndex >= 0 ? currentIndex : 0;
        pinnedIndex = (cur - 1 + n) % n;
    }

    // ---- Misc helpers ----

    function formatTime(seconds) {
        if (!seconds || seconds < 0 || isNaN(seconds)) return "0:00";
        const total = Math.floor(seconds);
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        const pad = n => n < 10 ? "0" + n : "" + n;
        if (h > 0) return h + ":" + pad(m) + ":" + pad(s);
        return m + ":" + pad(s);
    }

    // Friendly display name for a player.
    function playerName(p) {
        if (!p) return "";
        return p.identity || p.dbusName || "Unknown";
    }
}
