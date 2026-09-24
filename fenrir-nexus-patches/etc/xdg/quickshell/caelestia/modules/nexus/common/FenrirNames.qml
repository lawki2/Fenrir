pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Readable names for locale, layout and timezone codes from the system's own data
// (iso-codes, xkeyboard-config, zone.tab). zone.tab doubles as the tz whitelist.
Singleton {
    id: root

    // code -> display name, filled in by the FileViews below
    property var languages: ({})
    property var languages3: ({})
    property var languages5: ({})
    property var countries: ({})
    property var languageTypes: ({})
    property var layouts: ({})
    property var zoneCountry: ({})

    // 639-2 alone leaves half of locale.gen unnamed; -3 and -5 cover the rest.
    function languageName(code: string): string {
        return root.languages[code] ?? root.languages3[code] ?? root.languages5[code] ?? code;
    }

    // iso-639 names can carry alternates ("Catalan; Valencian"); the first is
    // the one people recognise.
    function primaryName(s: string): string {
        return s.split(";")[0].trim();
    }

    // "ca_ES@valencia" and "sr_RS@latin" differ from their base locale only by
    // the modifier, so it has to survive into the label or they read as dupes.
    function localeLabel(locale: string): string {
        let base = locale.split(".")[0];
        let modifier = "";
        if (base.includes("@")) {
            const split = base.split("@");
            base = split[0];
            modifier = split[1];
        }
        const parts = base.split("_");
        const lang = root.primaryName(root.languageName(parts[0]));
        const country = parts.length > 1 ? root.countries[parts[1]] : undefined;
        const named = country ? `${lang} (${country})` : lang;
        return modifier ? `${named} — ${modifier}` : named;
    }

    function layoutLabel(code: string): string {
        return root.layouts[code] ?? code;
    }

    function timezoneLabel(tz: string): string {
        const city = tz.split("/").pop().replace(/_/g, " ");
        const country = root.countries[root.zoneCountry[tz]];
        return country ? `${city} (${country})` : city;
    }

    // "custom" is a placeholder that yields a dead keyboard; "epo" is constructed.
    readonly property var hiddenLayouts: ["custom", "epo"]

    // Antarctica's ten zones are research stations with no civilian
    // population. Inhabited remote places (Norfolk, St Helena, Pitcairn) stay.
    readonly property var hiddenZoneCountries: ["AQ"]

    // Hide anything iso-639-3 doesn't type as living; untyped codes are kept.
    function isObscureLanguage(code: string): bool {
        const type = root.languageTypes[code];
        return type !== undefined && type !== "L";
    }

    function sortedByLabel(options: var): var {
        return options.sort((a, b) => a.label.localeCompare(b.label));
    }

    function localeOptions(codes: var): var {
        const known = Object.keys(root.languageTypes).length > 0;
        const kept = known ? codes.filter(c => !root.isObscureLanguage(c.split(/[._@]/)[0])) : codes;
        return root.sortedByLabel(kept.map(c => ({
                        label: root.localeLabel(c),
                        value: c
                    })));
    }

    function layoutOptions(codes: var): var {
        return root.sortedByLabel(codes.filter(c => !root.hiddenLayouts.includes(c)).map(c => ({
                        label: root.layoutLabel(c),
                        value: c
                    })));
    }

    // Drops the deprecated aliases, but only once zone.tab has actually
    // loaded - filtering against an empty map would blank the whole list.
    function timezoneOptions(codes: var): var {
        const known = Object.keys(root.zoneCountry).length > 0;
        const kept = known ? codes.filter(tz => root.zoneCountry.hasOwnProperty(tz) && !root.hiddenZoneCountries.includes(root.zoneCountry[tz])) : codes;
        return root.sortedByLabel(kept.map(tz => ({
                        label: root.timezoneLabel(tz),
                        value: tz
                    })));
    }

    FileView {
        path: "/usr/share/iso-codes/json/iso_639-2.json"
        onLoaded: {
            const out = {};
            for (const e of JSON.parse(text())["639-2"])
                if (e.alpha_2)
                    out[e.alpha_2] = e.name;
            root.languages = out;
        }
    }

    FileView {
        path: "/usr/share/iso-codes/json/iso_639-3.json"
        onLoaded: {
            const out = {};
            const types = {};
            for (const e of JSON.parse(text())["639-3"]) {
                out[e.alpha_3] = e.name;
                types[e.alpha_3] = e.type;
                if (e.alpha_2)
                    types[e.alpha_2] = e.type;
            }
            root.languages3 = out;
            root.languageTypes = types;
        }
    }

    FileView {
        path: "/usr/share/iso-codes/json/iso_639-5.json"
        onLoaded: {
            const out = {};
            for (const e of JSON.parse(text())["639-5"])
                out[e.alpha_3] = e.name;
            root.languages5 = out;
        }
    }

    FileView {
        path: "/usr/share/iso-codes/json/iso_3166-1.json"
        onLoaded: {
            const out = {};
            for (const e of JSON.parse(text())["3166-1"])
                out[e.alpha_2] = e.name;
            root.countries = out;
        }
    }

    // The "! layout" block of evdev.lst is "code<whitespace>description".
    FileView {
        path: "/usr/share/X11/xkb/rules/evdev.lst"
        onLoaded: {
            const out = {};
            let inLayouts = false;
            for (const line of text().split("\n")) {
                if (line.startsWith("!")) {
                    inLayouts = line.startsWith("! layout");
                    continue;
                }
                if (!inLayouts || !line.trim())
                    continue;
                const m = line.match(/^\s*(\S+)\s+(.*\S)\s*$/);
                if (m)
                    out[m[1]] = m[2];
            }
            root.layouts = out;
        }
    }

    // Tab-separated: country code, coordinates, zone name, optional comment.
    FileView {
        path: "/usr/share/zoneinfo/zone.tab"
        onLoaded: {
            const out = {};
            for (const line of text().split("\n")) {
                if (line.startsWith("#") || !line.trim())
                    continue;
                const cols = line.split("\t");
                if (cols.length >= 3)
                    out[cols[2].trim()] = cols[0].trim();
            }
            root.zoneCountry = out;
        }
    }
}
