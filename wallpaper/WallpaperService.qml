pragma Singleton

// WallpaperService.qml
// Wallpaper state singleton. Replaces swaybg (renderer) and waypaper
// (picker GUI) — owns:
//   - per-monitor wallpaper map  (`paths[outputName]`)
//   - global fill mode           (fill/fit/stretch/center/tile)
//   - currently-scanned folder + its image and subdirectory listings
//   - last-set path              (for hot-plug fallback when a new
//                                 monitor connects with no saved entry)
//   - picker open state          (toggled by the bar widget)
//   - picker target output       (which monitor a thumbnail click applies
//                                 to; "All" = every detected screen)
//
// Persistence: state lives in `Quickshell.statePath("wallpaper.json")`.
// Folder enumeration: shells out to `find` (single Process per scan; no
// long-running watcher, since wallpaper folders change infrequently).
//
// Public surface consumed by:
//   - WallpaperLayer.qml       (renderer)
//   - WallpaperPickerPopup.qml (picker UI)
//   - Wallpaper.qml            (bar widget)
//   - lock/LockSurface.qml     (lock background — replaces waypaper INI parsing)

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    // ---- Persisted state ----

    // Per-monitor wallpaper map: { "DP-1": "/abs/path.jpg", ... }
    // Mutated only via the Object.assign + reassignment dance so QML's
    // change tracker actually fires on bindings that read paths[name].
    property var paths: ({})

    // Currently-scanned folder. Defaults to ~/Pictures/Wallpaper if not
    // present in saved state (matches user's existing waypaper layout).
    property string folder: ""

    // Global fill mode key (string for JSON portability). Mapped to Qt's
    // Image.fillMode enum at the renderer via fillModeMap below.
    property string fillMode: "fill"

    // Most-recently-set path on any output. Used as the fallback when a
    // monitor connects mid-session with no entry in `paths` — better than
    // a black screen while the user picks something for the new output.
    property string lastSetPath: ""

    // ---- Folder scan results (not persisted; recomputed each scan) ----

    property var images: []      // string[] absolute paths to images
    property var subdirs: []     // string[] basenames of immediate subdirs
    property bool scanning: false

    // ---- Picker UI state (not persisted) ----

    property bool popupOpen: false
    property string pickerTarget: "All"   // "All" | "<output-name>"

    // ---- Computed helpers ----

    // Resolve which path a given screen should display. Used by the
    // renderer's per-monitor binding. Returns "" if neither a per-monitor
    // entry nor a global last-set path exists (renderer falls back to bg).
    function pathFor(screenName) {
        if (screenName && paths && paths[screenName])
            return paths[screenName];
        return lastSetPath;
    }

    // String key (JSON-safe) → Qt Image.fillMode enum value. Read by
    // WallpaperLayer for its Image; consumers don't need to know the
    // enum codes. Defined on the service so the popup's mode selector
    // and the renderer agree on the canonical key set.
    readonly property var fillModeMap: ({
        "fill":    Image.PreserveAspectCrop,
        "fit":     Image.PreserveAspectFit,
        "stretch": Image.Stretch,
        "center":  Image.Pad,
        "tile":    Image.Tile,
    })

    // Display labels for the picker's mode pills. Parallel to fillModeMap
    // keys so the picker can iterate one and look up the other.
    readonly property var fillModeKeys: ["fill", "fit", "stretch", "center", "tile"]
    readonly property var fillModeLabels: ({
        "fill":    "Fill",
        "fit":     "Fit",
        "stretch": "Stretch",
        "center":  "Center",
        "tile":    "Tile",
    })

    // ---- Mutators ----

    // Apply `path` to a single output (its name) or every detected screen
    // when target is "All" / "" / "*". Updates lastSetPath either way so
    // future hot-plugged monitors inherit the latest choice.
    function setWallpaper(target, path) {
        if (!path) return;
        const next = Object.assign({}, paths);
        if (!target || target === "All" || target === "*") {
            const screens = Quickshell.screens || [];
            for (let i = 0; i < screens.length; i++) {
                next[screens[i].name] = path;
            }
        } else {
            next[target] = path;
        }
        root.paths = next;
        root.lastSetPath = path;
        root._persist();
    }

    function setFolder(p) {
        if (!p) return;
        root.folder = p;
        root._scan();
        root._persist();
    }

    function setFillMode(m) {
        if (!fillModeMap.hasOwnProperty(m)) return;
        root.fillMode = m;
        root._persist();
    }

    function goUpFolder() {
        if (!folder || folder === "/") return;
        // strip trailing slash, then drop last component
        let f = folder.replace(/\/+$/, "");
        const i = f.lastIndexOf("/");
        const parent = i <= 0 ? "/" : f.slice(0, i);
        setFolder(parent);
    }

    // ---- Picker open / close ----

    function openPicker() {
        if (popupOpen) return;
        PopupController.open(root, () => root.closePicker());
        root.popupOpen = true;
        // Re-scan on each open so newly-dropped images appear without a
        // shell reload (cheap: one find process, ~ms for a typical folder).
        root._scan();
    }
    function closePicker() {
        if (!popupOpen) return;
        root.popupOpen = false;
    }
    function togglePicker() {
        if (popupOpen) closePicker(); else openPicker();
    }
    onPopupOpenChanged: if (!popupOpen) PopupController.closed(root)

    // ---- Folder scan ----

    // Single-shot Process per scan. Emits two record types:
    //   DIR<TAB><basename>     (immediate subdirectories)
    //   IMG<TAB><absolute>     (image files in `folder`)
    // Buffer accumulates lines; on process exit we publish atomically so
    // the GridView sees one consistent update instead of partial growth.
    Process {
        id: scanProc
        running: false
        property var _imgBuf: []
        property var _dirBuf: []
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (!line) return;
                const tab = line.indexOf("\t");
                if (tab < 0) return;
                const kind = line.slice(0, tab);
                const value = line.slice(tab + 1);
                if (kind === "IMG") scanProc._imgBuf.push(value);
                else if (kind === "DIR") scanProc._dirBuf.push(value);
            }
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line && line.length > 0)
                    console.warn("[WallpaperService] scan:", line.trim());
            }
        }
        onRunningChanged: {
            if (!running) {
                root.images = scanProc._imgBuf.slice();
                root.subdirs = scanProc._dirBuf.slice();
                scanProc._imgBuf = [];
                scanProc._dirBuf = [];
                root.scanning = false;
            }
        }
    }

    function _scan() {
        if (!folder) return;
        root.scanning = true;
        scanProc._imgBuf = [];
        scanProc._dirBuf = [];
        // -L follows symlinks (common in wallpaper organization); maxdepth 1
        // matches the user's flat-folder preference. Subdirs and images are
        // listed in two passes piped together; both sorted for stable order.
        // Hidden entries (`.git`, `.thumbnails`, `.foo.jpg`) are excluded
        // by `-not -name '.*'` since none of them are meaningful wallpaper
        // sources and they pollute the picker.
        scanProc.command = ["sh", "-c", `
folder="$1"
find -L "$folder" -maxdepth 1 -mindepth 1 -type d -not -name '.*' \\
  -printf 'DIR\\t%f\\n' 2>/dev/null | sort
find -L "$folder" -maxdepth 1 -type f -not -name '.*' \\
  \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \\
     -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.avif' \\) \\
  -printf 'IMG\\t%p\\n' 2>/dev/null | sort
`, "sh", folder];
        scanProc.running = false;
        scanProc.running = true;
    }

    // ---- Persistence ----

    function _persist() {
        const json = JSON.stringify({
            paths:       root.paths,
            folder:      root.folder,
            fillMode:    root.fillMode,
            lastSetPath: root.lastSetPath,
        }, null, 2);
        // Re-set path each write so FileView definitely picks up the new
        // text rather than reusing a stale buffer.
        stateFile.setText(json);
    }

    FileView {
        id: stateFile
        path: Quickshell.statePath("wallpaper.json")
        printErrors: false
        // Don't use watchChanges: true — we're the only writer, and a
        // self-write watch loop could trigger a re-read storm.
        onLoaded: {
            try {
                const data = JSON.parse(stateFile.text() || "{}");
                if (data.paths       !== undefined) root.paths       = data.paths;
                if (data.folder      !== undefined) root.folder      = data.folder;
                if (data.fillMode    !== undefined) root.fillMode    = data.fillMode;
                if (data.lastSetPath !== undefined) root.lastSetPath = data.lastSetPath;
            } catch (e) {
                console.warn("[WallpaperService] state parse error:", e);
            }
            if (!root.folder) {
                // Sensible default: matches the most common waypaper layout.
                root.folder = (Quickshell.env("HOME") || "") + "/Pictures/Wallpaper";
            }
            root._scan();
        }
        onLoadFailed: function(_err) {
            // No prior state — first-run defaults.
            root.folder = (Quickshell.env("HOME") || "") + "/Pictures/Wallpaper";
            root._scan();
        }
    }

    Component.onCompleted: stateFile.reload()
}
