// polkitModel.js
// Pure helpers for the polkit agent. No Qt types, no side effects — so the
// same file loads in QML (`import "polkitModel.js" as PolkitModel`, which
// ignores the export guard at the bottom) and in Node as CommonJS, which is
// what makes it testable without a compositor. See test/polkit-test.sh.
//
// Lowercase filename on purpose: Quickshell auto-generates a qmldir for
// every subdirectory, and UpperCase files there are registered as QML types.

// polkit hands us a full sentence built for a dialog that has room for it:
//
//   Authentication is needed to run `/usr/bin/foo' as the super user
//
// which is mostly boilerplate wrapping the one fact that matters. Rewrite
// the standard pkexec phrasing to something a narrow prompt can show:
//
//   Authorize running '/usr/bin/foo'
//
// Anything that doesn't match — a custom polkit action's own message, which
// is usually already short and specific — passes through untouched. Note the
// asymmetric quoting in polkit's output (backtick open, apostrophe close);
// the character class accepts either on both sides.
function authorizationLabel(message) {
    var text = String(message || "");
    var match = text.match(
        /^Authentication is (?:needed|required) to run [`']([^`']+)[`'] as /i);
    return match ? "Authorize running '" + match[1] + "'" : text;
}

// Trim a PAM prompt down to something that reads as a field label.
// pam_unix sends "Password: " — the trailing colon and space are formatting
// for a terminal, not part of the word.
function promptLabel(prompt, fallback) {
    var text = String(prompt || "").trim().replace(/\s*:\s*$/, "");
    return text.length > 0 ? text : (fallback || "Password");
}

if (typeof module !== "undefined") {
    module.exports = {
        authorizationLabel: authorizationLabel,
        promptLabel: promptLabel
    };
}
