pragma Singleton

// PolkitService.qml
// Polkit authentication agent. Replaces hyprpolkitagent and friends.
//
// Quickshell 0.3.0 ships Quickshell.Services.Polkit, so the shell can be
// the agent itself rather than delegating to a separate GUI process.
//
// Registration is declarative: instantiating PolkitAgent registers it, and
// there is no register call to make. `path` is the D-Bus object path we
// register at. Only one agent per session can hold the seat, so if another
// is already running ours stays unregistered and silent -- see isRegistered
// below, and the README install note about removing the old autostart.
//
// Lifecycle, per request:
//   1. authenticationRequestStarted  -> beginFlow, snapshot the flow
//   2. PAM prompts                   -> isResponseRequired flips true
//   3. respond(text)                 -> flow.submit, submitted = true
//   4a. authenticationSucceeded      -> closing = true, 300ms grace, done
//   4b. authenticationFailed         -> shake + error tint, stay open
//   4c. cancelled                    -> closing = true, dismiss
//
// Three traps worth stating, all of which fail silently:
//
//   - Never cache `flow` in a property. Every request creates a NEW AuthFlow
//     object, so a cached reference goes stale and submits into the void.
//     The Connections block below targets `agent.flow` so it re-binds.
//   - `closing` guards the reset on deactivation. Without it, isActive going
//     false wipes the snapshot instantly and the close animation renders an
//     empty dialog.
//   - `flow.message` is a constant property with no change signal, so it is
//     only safe to read when a request starts.
//
// IMPORTANT: pragma Singleton must be line 1 (gotcha #45). Header comments
// must NOT contain curly braces -- the qmlscanner doesn't strip them and the
// brace tracker gets confused, silently registering this file as a regular
// type instead of a singleton.

import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import qs
import "polkitModel.js" as PolkitModel

Singleton {
    id: root

    // ---- Public state, read by PolkitDialog ----

    // Drives dialog visibility. Stays true through the close grace period so
    // the fade-out has something to render.
    readonly property bool dialogVisible: agent.isActive || root.closing

    // Rewritten polkit message, e.g. "Authorize running '/usr/bin/pacman'".
    property string message: ""

    // Field label from PAM, colon stripped.
    property string prompt: "Password"

    // PAM wants input. False while it is thinking, or between stages.
    property bool responseRequired: false

    // PAM says echo the input (rare -- a one-time code, not a password).
    property bool responseVisible: false

    // Between submit and the result. Dialog dims and blocks typing.
    property bool submitted: false

    // Set for 1.2s after a failed attempt. Drives the red tint and shake.
    property bool errorFlash: false

    // Between a terminal result and the dialog actually going away.
    property bool closing: false

    // ---- Public methods ----

    function respond(text) {
        const flow = agent.flow;
        if (!flow || !flow.isResponseRequired) return;
        root.submitted = true;
        root.errorFlash = false;
        flow.submit(text);
    }

    function cancel() {
        const flow = agent.flow;
        // Set locally BEFORE touching the flow: Escape should dismiss
        // instantly even if the backend is slow to unwind, or if the flow
        // has already been torn down underneath us.
        root.closing = true;
        root.submitted = false;
        closeTimer.restart();
        if (flow) flow.cancelAuthenticationRequest();
    }

    // ---- Internals ----

    function _syncFromFlow() {
        const flow = agent.flow;
        if (!flow) return;
        root.message = PolkitModel.authorizationLabel(flow.message);
        root.prompt = PolkitModel.promptLabel(flow.inputPrompt, "Password");
        root.responseRequired = !!flow.isResponseRequired;
        root.responseVisible = !!flow.responseVisible;
        // PAM asked again, so whatever we last sent has been consumed. This
        // is what un-sticks the "Checking..." state when PAM re-prompts for a
        // second stage without ever emitting a failure.
        if (root.responseRequired) root.submitted = false;
    }

    function _beginFlow() {
        closeTimer.stop();
        root.closing = false;
        root.submitted = false;
        root.errorFlash = false;
        root._syncFromFlow();
        // Worth logging: "why did a password prompt just appear" is otherwise
        // hard to answer after the fact, and the action id names the culprit.
        if (agent.flow) console.log("[PolkitService] request:", agent.flow.actionId);
        // An auth prompt appearing behind an open Control Center would be
        // invisible and unanswerable.
        PopupController.closeAll();
    }

    function _reset() {
        root.message = "";
        root.prompt = "Password";
        root.responseRequired = false;
        root.responseVisible = false;
        root.submitted = false;
        root.errorFlash = false;
    }

    function _onFailed() {
        root.submitted = false;
        root.errorFlash = true;
        errorTimer.restart();
        root._syncFromFlow();
        root.failed();
    }

    // Emitted on a failed attempt so the dialog can shake. A signal rather
    // than a property because the animation must retrigger on every failure,
    // including two identical ones in a row.
    signal failed()

    PolkitAgent {
        id: agent
        path: "/org/quickshell_bar/PolkitAgent"

        onAuthenticationRequestStarted: root._beginFlow()

        onIsActiveChanged: {
            if (agent.isActive) root._syncFromFlow();
            // Guarded: during the close grace period isActive drops while we
            // are still rendering, and resetting here would blank the dialog
            // mid-fade.
            else if (!root.closing) root._reset();
        }

        onIsRegisteredChanged: root._reportRegistration()
    }

    // Registration is an async D-Bus call made at component completion, and
    // `isRegistered` starts false. On failure it therefore never *changes*,
    // so onIsRegisteredChanged alone would never report the one case anyone
    // needs told about. Poll once, late enough for the call to have settled.
    Timer {
        id: registrationCheck
        interval: 2000
        repeat: false
        onTriggered: root._reportRegistration()
    }

    property bool _reported: false

    function _reportRegistration() {
        if (root._reported) return;
        root._reported = true;
        if (agent.isRegistered) {
            console.log("[PolkitService] registered at", agent.path);
            return;
        }
        console.warn("[PolkitService] NOT registered — another polkit agent "
            + "holds this session. Remove it from autostart (hyprpolkitagent, "
            + "polkit-kde-authentication-agent-1, ...) or this shell will "
            + "never show an authentication prompt.");
    }

    // Targets agent.flow, not a cached copy, so it re-binds to the new
    // AuthFlow each request.
    Connections {
        target: agent.flow

        function onIsResponseRequiredChanged() { root._syncFromFlow(); }
        function onInputPromptChanged()        { root._syncFromFlow(); }
        function onResponseVisibleChanged()    { root._syncFromFlow(); }

        function onAuthenticationFailed()      { root._onFailed(); }

        function onAuthenticationSucceeded() {
            root.closing = true;
            closeTimer.restart();
        }
        function onAuthenticationRequestCancelled() {
            root.closing = true;
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer
        interval: 300
        repeat: false
        onTriggered: {
            root.closing = false;
            root._reset();
        }
    }

    Timer {
        id: errorTimer
        interval: 1200
        repeat: false
        onTriggered: root.errorFlash = false
    }

    // Forces instantiation from shell.qml. Singletons are lazy, and a lazy
    // agent is one that never registers — same reason IdleService and
    // SystemTheme have one.
    function bootstrap() {
        registrationCheck.restart();
    }
}
