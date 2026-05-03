pragma Singleton

// WeatherService.qml
// Weather state singleton. Fetches current conditions + today's high/low
// from Open-Meteo, pinning the model to KNMI HARMONIE-AROME 2km Dutch
// data via `models=knmi_seamless` — meaning the numbers we display are
// authentic KNMI output (the same data KNMI publishes as research-grade
// GRIB files), but served as friendly JSON with no API key, no User-
// Agent gymnastics, and a 10k-call/day rate limit that we'll never
// approach (we fetch every 15 minutes = 96 calls/day).
//
// Architecture mirrors NetworkService.qml exactly:
//   - Process { command: ["curl", ...] } + StdioCollector for the fetch
//   - Timer for periodic auto-refresh
//   - JsonAdapter on a FileView at Quickshell.statePath() for persistence
//
// First-run UX: lat/lon start empty. The service does NOT auto-fetch
// until the user picks a city via the in-CC city picker. WeatherCard
// renders a "Set location" placeholder while location is unset.

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    // ---- Persisted location ----
    //
    // Empty until the user picks a city via CitiesView. Persisted to
    // ~/.local/state/quickshell/by-shell/<id>/weather.json so the choice
    // survives shell reloads.
    property real lat: 0
    property real lon: 0
    property string locationLabel: ""

    readonly property bool hasLocation: locationLabel !== ""

    // ---- Current conditions (populated by the fetch) ----
    property real currentTemp: 0
    property real apparentTemp: 0       // "feels like"
    property int  weatherCode: 0        // WMO weather interpretation code
    property real windSpeed: 0          // km/h
    property int  humidity: 0           // %
    property real tempMin: 0            // today's low
    property real tempMax: 0            // today's high
    property var  lastUpdated: null     // Date | null

    // ---- Fetch state ----
    property bool loading: false
    property string lastError: ""

    // ================================================================
    // Public actions
    // ================================================================

    // Trigger a fresh fetch. No-op if no location yet (the curl URL would
    // be malformed with lat=0, lon=0 — actually it'd succeed with weather
    // for the Atlantic Ocean off the coast of Africa, which is funny but
    // not what we want).
    function refresh() {
        if (!root.hasLocation) return;
        if (fetchProc.running) return;   // single-flight; ignore overlapping clicks
        root.loading = true;
        root.lastError = "";
        // -sf  = silent + fail-on-HTTP-error (curl returns non-zero, stderr
        //        carries the message)
        // --max-time 10 = bound the wait so a stalled connection doesn't
        //        leave the spinner spinning forever
        fetchProc.command = [
            "curl", "-sf", "--max-time", "10",
            "https://api.open-meteo.com/v1/forecast"
                + "?latitude=" + root.lat
                + "&longitude=" + root.lon
                + "&current=temperature_2m,apparent_temperature,weather_code,"
                + "wind_speed_10m,relative_humidity_2m"
                + "&daily=temperature_2m_max,temperature_2m_min"
                + "&timezone=auto"
                + "&models=knmi_seamless"
        ];
        fetchProc.running = true;
    }

    // Set the user's location. `entry` is one of the objects in `cities`
    // (or any { lat, lon, label } shape). Persists, then refreshes.
    function setLocation(entry) {
        if (!entry || typeof entry.lat !== "number") return;
        root.lat = entry.lat;
        root.lon = entry.lon;
        root.locationLabel = entry.label || "";
        _persist();
        refresh();
    }

    // ================================================================
    // WMO weather code → Font Awesome 7 Solid glyph + human description
    // ================================================================
    //
    // Every glyph below was verified present in FA 7 Free Solid via
    // fontTools before commit, so no \uf737-style invisible icons.
    // Codes from https://open-meteo.com/en/docs (WMO 4677 weather codes).

    function iconForCode(code) {
        if (code === 0)                       return "\uf185"; // sun (clear)
        if (code === 1 || code === 2)         return "\uf6c4"; // cloud-sun (partly cloudy)
        if (code === 3)                       return "\uf0c2"; // cloud (overcast)
        if (code === 45 || code === 48)       return "\uf75f"; // smog (fog)
        if (code >= 51 && code <= 57)         return "\uf73d"; // cloud-rain (drizzle)
        if (code >= 61 && code <= 67)         return "\uf73d"; // cloud-rain (rain)
        if (code >= 71 && code <= 77)         return "\uf2dc"; // snowflake (snow)
        if (code >= 80 && code <= 82)         return "\uf740"; // cloud-showers-heavy
        if (code === 85 || code === 86)       return "\uf2dc"; // snowflake (snow showers)
        if (code >= 95 && code <= 99)         return "\uf76c"; // cloud-bolt (thunderstorm)
        return "\uf0c2";                                       // fallback: cloud
    }

    function descriptionForCode(code) {
        if (code === 0)                       return "Clear";
        if (code === 1)                       return "Mainly clear";
        if (code === 2)                       return "Partly cloudy";
        if (code === 3)                       return "Overcast";
        if (code === 45)                      return "Fog";
        if (code === 48)                      return "Rime fog";
        if (code === 51)                      return "Light drizzle";
        if (code === 53)                      return "Drizzle";
        if (code === 55)                      return "Heavy drizzle";
        if (code === 56 || code === 57)       return "Freezing drizzle";
        if (code === 61)                      return "Light rain";
        if (code === 63)                      return "Rain";
        if (code === 65)                      return "Heavy rain";
        if (code === 66 || code === 67)       return "Freezing rain";
        if (code === 71)                      return "Light snow";
        if (code === 73)                      return "Snow";
        if (code === 75)                      return "Heavy snow";
        if (code === 77)                      return "Snow grains";
        if (code === 80)                      return "Light showers";
        if (code === 81)                      return "Showers";
        if (code === 82)                      return "Violent showers";
        if (code === 85)                      return "Light snow showers";
        if (code === 86)                      return "Snow showers";
        if (code === 95)                      return "Thunderstorm";
        if (code === 96 || code === 99)       return "Thunderstorm w/ hail";
        return "Unknown";
    }

    // ================================================================
    // City catalogue
    // ================================================================
    //
    // 25 NL cities — covers the largest population centers + a few
    // smaller-but-distinctive ones (Maastricht, Leeuwarden) so the user
    // has near-everywhere-in-NL coverage. Coordinates are city-center
    // approximations from public sources (OpenStreetMap node centroids).
    // KNMI HARMONIE-AROME is a 2 km grid, so sub-km precision is moot.
    readonly property var cities: [
        { label: "Amsterdam",   lat: 52.3676, lon:  4.9041 },
        { label: "Rotterdam",   lat: 51.9244, lon:  4.4777 },
        { label: "Den Haag",    lat: 52.0705, lon:  4.3007 },
        { label: "Utrecht",     lat: 52.0907, lon:  5.1214 },
        { label: "Eindhoven",   lat: 51.4416, lon:  5.4697 },
        { label: "Groningen",   lat: 53.2194, lon:  6.5665 },
        { label: "Tilburg",     lat: 51.5555, lon:  5.0913 },
        { label: "Almere",      lat: 52.3508, lon:  5.2647 },
        { label: "Breda",       lat: 51.5719, lon:  4.7683 },
        { label: "Nijmegen",    lat: 51.8126, lon:  5.8372 },
        { label: "Apeldoorn",   lat: 52.2112, lon:  5.9699 },
        { label: "Haarlem",     lat: 52.3874, lon:  4.6462 },
        { label: "Enschede",    lat: 52.2215, lon:  6.8937 },
        { label: "Arnhem",      lat: 51.9851, lon:  5.8987 },
        { label: "Amersfoort",  lat: 52.1561, lon:  5.3878 },
        { label: "Zaanstad",    lat: 52.4391, lon:  4.8294 },
        { label: "Den Bosch",   lat: 51.6978, lon:  5.3037 },
        { label: "Zwolle",      lat: 52.5168, lon:  6.0830 },
        { label: "Maastricht",  lat: 50.8514, lon:  5.6909 },
        { label: "Leiden",      lat: 52.1601, lon:  4.4970 },
        { label: "Dordrecht",   lat: 51.8133, lon:  4.6901 },
        { label: "Alkmaar",     lat: 52.6324, lon:  4.7534 },
        { label: "Delft",       lat: 52.0116, lon:  4.3571 },
        { label: "Leeuwarden",  lat: 53.2012, lon:  5.7999 },
        { label: "Hilversum",   lat: 52.2233, lon:  5.1719 }
    ]

    // ================================================================
    // Internals — fetch + parse
    // ================================================================

    Process {
        id: fetchProc
        running: false

        // stdout: full JSON body. Parse once stream finishes (single chunk
        // expected; the Open-Meteo response is ~1.5 KB).
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    // Open-Meteo top-level: current.{...}, daily.{...} arrays.
                    const c = data.current || {};
                    const d = data.daily || {};
                    root.currentTemp   = (c.temperature_2m ?? 0) * 1.0;
                    root.apparentTemp  = (c.apparent_temperature ?? 0) * 1.0;
                    root.weatherCode   = (c.weather_code ?? 0) | 0;
                    root.windSpeed     = (c.wind_speed_10m ?? 0) * 1.0;
                    root.humidity      = (c.relative_humidity_2m ?? 0) | 0;
                    // Daily arrays — index 0 is "today" given timezone=auto.
                    if (d.temperature_2m_max && d.temperature_2m_max.length > 0)
                        root.tempMax = d.temperature_2m_max[0] * 1.0;
                    if (d.temperature_2m_min && d.temperature_2m_min.length > 0)
                        root.tempMin = d.temperature_2m_min[0] * 1.0;
                    root.lastUpdated = new Date();
                    root.lastError = "";
                } catch (e) {
                    console.warn("[WeatherService] JSON parse error:", e);
                    root.lastError = "Bad response";
                }
            }
        }

        // stderr: curl error message on non-zero exit (network down, DNS
        // failure, HTTP error from Open-Meteo, timeout, etc.). Surfaced in
        // WeatherCard as `lastError`.
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.length > 0) {
                    const msg = text.trim();
                    console.warn("[WeatherService] fetch error:", msg);
                    // Keep the user-facing message short; the full thing
                    // is in qs log for debugging.
                    root.lastError = "Network error";
                }
            }
        }

        onRunningChanged: {
            if (!running) {
                root.loading = false;
                // Don't auto-restart — fetch is on a Timer below + manual
                // refresh button. A failed fetch shouldn't spin forever.
            }
        }
    }

    // 15-minute auto-refresh. Open-Meteo updates the `current` block
    // every ~15 minutes, so faster polling buys nothing. Disabled until
    // a location is set (the early-return in refresh() keeps it safe
    // even if the timer fires during a transient empty-location state).
    Timer {
        running: root.hasLocation
        interval: 15 * 60 * 1000
        repeat: true
        onTriggered: root.refresh()
    }

    // ================================================================
    // Persistence — { lat, lon, label } in weather.json
    // ================================================================

    function _persist() {
        const json = JSON.stringify({
            lat:   root.lat,
            lon:   root.lon,
            label: root.locationLabel
        }, null, 2);
        stateFile.setText(json);
    }

    FileView {
        id: stateFile
        path: Quickshell.statePath("weather.json")
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(stateFile.text() || "{}");
                if (typeof data.lat === "number") root.lat = data.lat;
                if (typeof data.lon === "number") root.lon = data.lon;
                if (typeof data.label === "string") root.locationLabel = data.label;
            } catch (e) {
                console.warn("[WeatherService] state parse error:", e);
            }
            // First fetch as soon as we have a saved location. If the file
            // exists but has no/zero coords (corrupted state), hasLocation
            // gates the fetch from going out.
            if (root.hasLocation) root.refresh();
        }
        onLoadFailed: function(_err) {
            // No prior state → first run; user must pick a city.
        }
    }

    Component.onCompleted: stateFile.reload()
}
