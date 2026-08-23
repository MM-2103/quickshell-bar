#!/usr/bin/env bash
# Pure-logic tests for polkit/polkitModel.js
source "$(dirname "$0")/lib.sh"

run_node_test <<'JS'
const m = requireFromRoot("polkit/polkitModel.js");

// --- authorizationLabel: the standard pkexec phrasing -------------------
// polkit's real output uses backtick-then-apostrophe quoting.
assertEqual(
  m.authorizationLabel("Authentication is needed to run `/usr/bin/true' as the super user"),
  "Authorize running '/usr/bin/true'",
  "rewrites the pkexec message");

assertEqual(
  m.authorizationLabel("Authentication is required to run `/usr/bin/pacman' as the super user"),
  "Authorize running '/usr/bin/pacman'",
  "accepts 'required' as well as 'needed'");

assertEqual(
  m.authorizationLabel("Authentication is needed to run '/usr/bin/foo' as the super user"),
  "Authorize running '/usr/bin/foo'",
  "accepts symmetric apostrophe quoting");

// --- authorizationLabel: everything else passes through -----------------
// A custom polkit action supplies its own message, usually already short.
assertEqual(
  m.authorizationLabel("Authentication is required to change system settings"),
  "Authentication is required to change system settings",
  "passes through a non-matching message verbatim");

assertEqual(m.authorizationLabel(""), "", "empty message stays empty");
assertEqual(m.authorizationLabel(null), "", "null message becomes empty string");
assertEqual(m.authorizationLabel(undefined), "", "undefined message becomes empty string");

// Must anchor at the start, or a message merely containing the phrase
// would be truncated to whatever followed it.
assertEqual(
  m.authorizationLabel("Note: Authentication is needed to run `/bin/x' as root"),
  "Note: Authentication is needed to run `/bin/x' as root",
  "does not rewrite when the phrase is not at the start");

// --- promptLabel --------------------------------------------------------
assertEqual(m.promptLabel("Password: "), "Password", "strips PAM's trailing colon and space");
assertEqual(m.promptLabel("Password:"), "Password", "strips a bare trailing colon");
assertEqual(m.promptLabel("  PIN  "), "PIN", "trims surrounding whitespace");
assertEqual(m.promptLabel(""), "Password", "falls back when the prompt is empty");
assertEqual(m.promptLabel(null), "Password", "falls back when the prompt is null");
assertEqual(m.promptLabel("", "Passphrase"), "Passphrase", "honours a custom fallback");
assertEqual(m.promptLabel("Enter passphrase for key"), "Enter passphrase for key",
  "leaves a prompt without a trailing colon alone");
JS

finish
