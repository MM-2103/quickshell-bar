pragma Singleton

// LockService.qml
// Session-lock state + PAM + wallpaper-source detection. Drives the
// WlSessionLock instance defined in lock/Lock.qml. Triggered via the
// qs-IPC handler in shell.qml (which a compositor keybind like Mod+Shift+X and
// hypridle's lock_cmd both call into).
//
// Lifecycle:
//   1. lock()              → locked=true; pam.active=true; surface UIs appear
//   2. respond(text)       → pam.respond if responseRequired (called from
//                            password TextInput on Enter)
//   3. PAM completes:
//        Success → locked=false (unlock); pamError cleared
//        Failed  → pamError="Authentication failed"; pam restarted for retry
//
// Multi-monitor: one PamContext shared across all WlSessionLockSurface
// instances; password fields all point at LockService.respond().

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs

Singleton {
    id: root

    // ---- Public state ----

    // Drives WlSessionLock.locked. Stays true until PAM completes Success.
    property bool locked: false

    // Latest message from PAM (e.g. "Password:"). Surface UIs may show it.
    property string pamMessage: ""

    // Set to a human-readable string after a failed auth attempt; bound to
    // password-field error styling. Persists across the auto-restarted PAM
    // session so the user actually sees it; cleared only on the next user
    // attempt (in respond()) or on success.
    property string pamError: ""

    // True while PAM is mid-conversation (used to gate respond() calls).
    property bool pamActive: false

    // True between respond() and the PAM completion signal — i.e. while
    // pam_unix is performing its ~2 s validation. Drives the disabled +
    // dimmed state of the password field, so the user can see their input
    // was received and that they should wait.
    property bool pamChecking: false

    // Defensive: if respond() runs before PAM has called responseRequired
    // (e.g. very-early submit at lock-open before the prompt arrived),
    // park the text here and submit it on the next responseRequired edge.
    property string _pendingResponse: ""

    // Path to the wallpaper file currently set by waypaper. The lock
    // surfaces blur this image as their background. Empty = use Theme.bg.
    property string wallpaperPath: ""

    // ---- Public methods ----

    function lock() {
        if (root.locked) return;        // idempotent — hypridle may call repeatedly
        root.pamError = "";
        root.pamMessage = "";
        root.locked = true;
        // Re-read wallpaper path each time we lock so changes via waypaper
        // are picked up without a shell reload.
        wallpaperFile.reload();
        // Start PAM. Conversation will fire pamMessage / responseRequired.
        if (!pam.active) pam.active = true;
    }

    function respond(text) {
        if (!pam.active) {
            // Edge case (very fast user at lock-open): surface tried to
            // submit before PAM had its first prompt out. Queue and kick.
            root._pendingResponse = text;
            pam.active = true;
            return;
        }
        if (pam.responseRequired) {
            // PAM is ready for input — submit. Clear any lingering error
            // so the status text returns to the prompt while we validate;
            // flip pamChecking on so the surface disables/dims the input.
            root.pamError = "";
            root.pamChecking = true;
            pam.respond(text);
        } else {
            // Shouldn't happen in practice — surface disables input while
            // pamChecking, so respond() can't be called mid-validation.
            // Queue defensively in case some other path triggers it.
            root._pendingResponse = text;
        }
    }

    // ---- PAM ----

    PamContext {
        id: pam
        config: "qslock"                 // /etc/pam.d/qslock — single line `auth include login`
        // user: ""  (empty = current user, which is what we want)

        onActiveChanged:    root.pamActive = pam.active
        onMessageChanged: {
            // Track the latest prompt for surfaces that want to show it; do
            // NOT touch pamError here — the auto-restart after a failed
            // attempt fires a fresh "Password:" message microseconds later,
            // which previously erased the error text instantly.
            root.pamMessage = pam.message || "";
        }
        // Whenever PAM signals it's ready for input, drain any queued
        // response (lock-open race only — see respond() comment).
        onResponseRequiredChanged: {
            if (pam.responseRequired && root._pendingResponse.length > 0) {
                const t = root._pendingResponse;
                root._pendingResponse = "";
                root.pamError = "";
                root.pamChecking = true;
                pam.respond(t);
            }
        }
        onCompleted: result => {
            // PAM finished — re-enable the input regardless of outcome.
            root.pamChecking = false;
            if (result === PamResult.Success) {
                // Authenticated. Drop the lock; clear transient state.
                root.locked = false;
                root.pamError = "";
                root.pamMessage = "";
                root.pamActive = false;
            } else if (result === PamResult.Failed) {
                root.pamError = "Authentication failed";
                root.pamActive = false;
                // Restart PAM so the user can immediately retry. The error
                // text persists until the next respond() (i.e. until the
                // user actually attempts a new password).
                Qt.callLater(() => {
                    if (root.locked) pam.active = true;
                });
            } else {
                // PamResult.Error — config or system fault. Surface this as
                // an error and let the user retry; logging for diagnosis.
                console.warn("[LockService] PAM error result:", result);
                root.pamError = "PAM error — try again";
                root.pamActive = false;
                Qt.callLater(() => {
                    if (root.locked) pam.active = true;
                });
            }
        }
        onError: err => {
            console.warn("[LockService] PAM error:", err);
            root.pamChecking = false;
            root.pamError = "PAM error — try again";
        }
    }

    // ---- Wallpaper detection ----
    //
    // waypaper writes the user's currently-set wallpaper as a single key in
    // ~/.config/waypaper/config.ini. We re-read this file on every lock so
    // a wallpaper change is reflected without needing a shell reload.

    FileView {
        id: wallpaperFile
        path: Quickshell.env("HOME") + "/.config/waypaper/config.ini"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const t = wallpaperFile.text() || "";
            // Match: `wallpaper = /path/to/image.ext`  (with optional ~)
            const m = t.match(/^\s*wallpaper\s*=\s*(.+?)\s*$/m);
            if (m && m[1]) {
                let p = m[1];
                if (p.charAt(0) === "~") {
                    p = (Quickshell.env("HOME") || "") + p.slice(1);
                }
                root.wallpaperPath = p;
            } else {
                root.wallpaperPath = "";
            }
        }
        onLoadFailed: function(err) {
            // No waypaper config = fall back to solid background.
            root.wallpaperPath = "";
        }
    }
}
