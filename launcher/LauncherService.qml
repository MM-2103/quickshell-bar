pragma Singleton

// LauncherService.qml
// App launcher state + frecency + multi-mode router. Replaces fuzzel.
//
// Modes (chosen by query prefix):
//   (default)  apps           — fuzzy substring on name+genericName+keywords
//   "="        calculator     — eval arithmetic; Enter copies result
//   "?"        web search     — Enter opens SEARCH_URL in default browser
//   ";"        emoji picker   — substring on description+aliases+tags; Enter copies char
//
// Public surface used by Launcher.qml + shell.qml IpcHandler:
//   popupOpen: bool
//   query: string
//   openPopup() / closePopup() / togglePopup()
//   openPopupWithQuery(prefix)            — opens with prefilled query (used by Mod+Semicolon → ";")
//   filtered: array<row>                  — see row schema below
//   launch(row)                           — switches on row.kind
//
// Row schemas:
//   { kind:"app",   entry:<DesktopEntry> }
//   { kind:"calc",  text:"<formatted result>", query:"<original>" }
//   { kind:"web",   text:"<query without prefix>" }
//   { kind:"emoji", char:"😀", name:"grinning face", category:"Smileys & Emotion" }
//
// Frecency (one map, polymorphic key):
//   <entry.id>          — apps
//   "emoji:" + <char>   — emoji
// Score = count * exp(-(now - lastUsed) / 30days_ms). Empty query in any
// mode: pure frecency desc, alphabetic tiebreak.

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    // ---- Web-search engine config ----
    //
    // To swap engines, change searchUrl + searchName below. `%s` is replaced
    // by URI-encoded query at search time. Some common alternatives:
    //
    //   DuckDuckGo:    "https://duckduckgo.com/?q=%s"           "DuckDuckGo"
    //   Google:        "https://www.google.com/search?q=%s"     "Google"
    //   Brave Search:  "https://search.brave.com/search?q=%s"   "Brave Search"
    //   Kagi:          "https://kagi.com/search?q=%s"           "Kagi"          (requires login)
    //
    // Both are routed through `Local.get()` so users can override per-machine
    // by setting "searchUrl" / "searchName" in
    // ~/.config/quickshell-bar/config.json without touching this file.
    readonly property string searchUrl:  Local.get("searchUrl",  "https://duckduckgo.com/?q=%s")
    readonly property string searchName: Local.get("searchName", "DuckDuckGo")

    // ---- Public state ----

    property bool popupOpen: false
    property string query: ""

    // Frecency map: { id -> {count, lastUsed} } where id may be a desktop-entry
    // id ("firefox") or "emoji:<char>" ("emoji:😀").
    property var frecency: ({})

    // Loaded emoji catalog: array<{emoji, description, category, aliases, tags}>
    property var _emoji: []

    // 30 days in ms — half-life-ish for the exponential decay.
    readonly property real _halfLifeMs: 30 * 24 * 60 * 60 * 1000

    // Cap emoji result list so empty `;` queries (1870 entries) stay snappy.
    readonly property int _emojiResultCap: 80

    // ---- Popup control (mutex-aware) ----

    function openPopup() {
        PopupController.open(root, () => root.popupOpen = false);
        root.popupOpen = true;
        root.query = "";
    }

    function openPopupWithQuery(prefix) {
        PopupController.open(root, () => root.popupOpen = false);
        root.popupOpen = true;
        root.query = prefix || "";
    }

    function closePopup() {
        root.popupOpen = false;
        PopupController.closed(root);
    }

    function togglePopup() {
        if (root.popupOpen) closePopup();
        else                openPopup();
    }

    // ---- Frecency persistence ----

    FileView {
        id: frecencyFile
        path: Quickshell.statePath("launcher-frecency.json")
        watchChanges: false
        printErrors: true
        onLoaded: {
            try {
                const t = frecencyFile.text();
                root.frecency = (t && t.length > 0) ? JSON.parse(t) : ({});
            } catch (e) {
                console.warn("[LauncherService] frecency parse error:", e);
                root.frecency = ({});
            }
        }
        onLoadFailed: function(err) {
            // No existing file is the normal case on first run. Start empty.
            root.frecency = ({});
        }
    }

    // ---- Emoji catalog (loaded at startup) ----

    FileView {
        id: emojiFile
        path: Qt.resolvedUrl("emoji.json")
        // We want this ready by the time the popup opens. ~10 ms parse cost.
        blockLoading: true
        printErrors: true
        onLoaded: {
            try {
                const arr = JSON.parse(emojiFile.text());
                if (Array.isArray(arr)) {
                    root._emoji = arr;
                } else {
                    console.warn("[LauncherService] emoji.json: unexpected shape, not an array");
                    root._emoji = [];
                }
            } catch (e) {
                console.warn("[LauncherService] emoji.json parse error:", e);
                root._emoji = [];
            }
        }
        onLoadFailed: function(err) {
            console.warn("[LauncherService] emoji.json load failed; emoji mode disabled");
            root._emoji = [];
        }
    }

    // ---- Frecency helpers ----

    function _saveFrecency() {
        try {
            frecencyFile.setText(JSON.stringify(root.frecency));
        } catch (e) {
            console.warn("[LauncherService] frecency save error:", e);
        }
    }

    function _bump(key) {
        if (!key) return;
        const m = root.frecency || {};
        const cur = m[key] || { count: 0, lastUsed: 0 };
        cur.count    = (cur.count || 0) + 1;
        cur.lastUsed = Date.now();
        m[key] = cur;
        root.frecency = m;
        _saveFrecency();
    }

    function _scoreKey(key) {
        if (!key) return 0;
        const r = root.frecency ? root.frecency[key] : null;
        if (!r || !r.count) return 0;
        const ageMs = Date.now() - (r.lastUsed || 0);
        return r.count * Math.exp(-ageMs / root._halfLifeMs);
    }

    function _scoreApp(entry)  { return entry ? _scoreKey(entry.id) : 0; }
    function _scoreEmoji(char) { return _scoreKey("emoji:" + char); }

    // ---- App matching ----

    function _appHaystack(e) {
        let s = (e.name || "");
        if (e.genericName) s += " " + e.genericName;
        if (e.keywords && e.keywords.length) s += " " + e.keywords.join(" ");
        return s.toLowerCase();
    }

    function _appMatches(entry, terms) {
        if (!terms.length) return true;
        const h = _appHaystack(entry);
        for (let i = 0; i < terms.length; i++) {
            if (h.indexOf(terms[i]) < 0) return false;
        }
        return true;
    }

    function _filterApps(q) {
        const apps = DesktopEntries && DesktopEntries.applications
            ? DesktopEntries.applications.values
            : [];
        const all = Array.isArray(apps) ? apps.slice() : Array.from(apps || []);
        const qq = (q || "").trim().toLowerCase();
        const terms = qq ? qq.split(/\s+/) : [];
        const matched = qq
            ? all.filter(e => e && _appMatches(e, terms))
            : all;
        // Force frecency to be a dependency by reading it.
        const _ = root.frecency;
        matched.sort((a, b) => {
            const sa = _scoreApp(a), sb = _scoreApp(b);
            if (sa !== sb) return sb - sa;
            return (a.name || "").localeCompare(b.name || "");
        });
        return matched.map(e => ({ kind: "app", entry: e }));
    }

    // ---- Calculator ----
    //
    // Strict allowlist: only digits, basic operators, parens, decimal, percent,
    // and whitespace. No identifiers → no eval-injection surface even though
    // we use `Function()`. Returns a formatted string, or null if invalid.

    readonly property var _calcAllow: /^[0-9+\-*/().,%\s]+$/

    function _evalCalc(expr) {
        if (!expr) return null;
        const e = expr.trim().replace(/,/g, ".");   // accept European decimals
        if (!e.length) return null;
        if (!_calcAllow.test(e)) return null;
        let v;
        try {
            // Wrap in parens so leading sign etc. parses as expression, not statement.
            v = (new Function("return (" + e + ")"))();
        } catch (err) {
            return null;
        }
        if (typeof v !== "number" || !isFinite(v)) return null;
        return _formatNumber(v);
    }

    function _formatNumber(n) {
        if (Number.isInteger(n)) {
            return n.toString();
        }
        // Avoid scientific notation for "normal" numbers; switch when we have to.
        const abs = Math.abs(n);
        if (abs !== 0 && (abs < 1e-6 || abs >= 1e15)) {
            return n.toExponential(6);
        }
        // Up to 10 significant figures, strip trailing zeros.
        let s = n.toPrecision(10);
        // Strip trailing zeros after a dot, then a dangling dot.
        if (s.indexOf(".") >= 0) {
            s = s.replace(/0+$/, "").replace(/\.$/, "");
        }
        return s;
    }

    // ---- Emoji ----

    function _filterEmoji(q) {
        const list = root._emoji || [];
        const qq = (q || "").trim().toLowerCase();
        const terms = qq ? qq.split(/\s+/) : [];

        // Build matched array once.
        const matched = [];
        for (let i = 0; i < list.length; i++) {
            const e = list[i];
            if (!e || !e.emoji) continue;
            if (terms.length) {
                const hay = (e.description || "")
                    + " " + ((e.aliases || []).join(" "))
                    + " " + ((e.tags || []).join(" "));
                const lower = hay.toLowerCase();
                let ok = true;
                for (let t = 0; t < terms.length; t++) {
                    if (lower.indexOf(terms[t]) < 0) { ok = false; break; }
                }
                if (!ok) continue;
            }
            matched.push(e);
        }

        // Force frecency reactivity.
        const _ = root.frecency;
        matched.sort((a, b) => {
            const sa = _scoreEmoji(a.emoji), sb = _scoreEmoji(b.emoji);
            if (sa !== sb) return sb - sa;
            return (a.description || "").localeCompare(b.description || "");
        });

        const cap = root._emojiResultCap;
        const top = matched.length > cap ? matched.slice(0, cap) : matched;
        return top.map(e => ({
            kind: "emoji",
            char: e.emoji,
            name: e.description || "",
            category: e.category || ""
        }));
    }

    // ---- Mode router ----

    readonly property var filtered: {
        const q = root.query || "";

        if (q.length > 0 && q.charAt(0) === "?") {
            const rest = q.slice(1);
            if (rest.length === 0) return [];
            return [{ kind: "web", text: rest }];
        }

        if (q.length > 0 && q.charAt(0) === ";") {
            return _filterEmoji(q.slice(1));
        }

        if (q.length > 0 && q.charAt(0) === "=") {
            const result = _evalCalc(q.slice(1));
            return result !== null
                ? [{ kind: "calc", text: result, query: q }]
                : [];
        }

        return _filterApps(q);
    }

    // ---- Clipboard helper ----
    //
    // Use wl-copy (daemonizes, holds the selection regardless of which surface
    // is focused) instead of mutating Quickshell.clipboardText, which on Wayland
    // requires a focused qs window — we'd race against the popup closing.

    function _setClipboard(text) {
        if (text === null || text === undefined) return;
        try {
            Quickshell.execDetached(["wl-copy", "--", String(text)]);
        } catch (e) {
            console.warn("[LauncherService] wl-copy failed:", e);
        }
    }

    // ---- Launch ----

    function launch(row) {
        if (!row || !row.kind) return;

        switch (row.kind) {
        case "app": {
            const entry = row.entry;
            if (!entry) return;
            _bump(entry.id);
            try {
                entry.execute();
            } catch (e) {
                console.warn("[LauncherService] entry.execute() failed:", e,
                    "— falling back to execDetached");
                try { if (entry.command) Quickshell.execDetached(entry.command); }
                catch (e2) { console.warn("[LauncherService] fallback also failed:", e2); }
            }
            break;
        }
        case "calc": {
            _setClipboard(row.text);
            break;
        }
        case "web": {
            const url = root.searchUrl.replace("%s", encodeURIComponent(row.text || ""));
            try { Quickshell.execDetached(["xdg-open", url]); }
            catch (e) { console.warn("[LauncherService] xdg-open failed:", e); }
            break;
        }
        case "emoji": {
            _setClipboard(row.char);
            _bump("emoji:" + row.char);
            break;
        }
        default:
            console.warn("[LauncherService] unknown row kind:", row.kind);
        }

        closePopup();
    }
}
