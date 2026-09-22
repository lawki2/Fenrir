pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Turns the raw codes the system hands us ("sv_SE.UTF-8", "se",
// "Europe/Stockholm") into something a person can read, from the system's own
// data rather than a hand-written table: iso-codes for language and country
// names, xkeyboard-config for layout descriptions, tzdata's zone.tab for
// timezones. Shared by the Nexus settings pages and the installer, which
// symlinks this directory in.
//
// zone.tab doubles as the timezone whitelist. `timedatectl list-timezones`
// returns 598 entries, ~180 of which are deprecated aliases (US/Eastern,
// Canada/Atlantic, EST, Asia/Calcutta) or technical Etc/GMT offsets. zone.tab
// lists only the 418 real ones and drops every alias - without losing genuine
// cities like Africa/Accra, which the stricter zone1970.tab merges away.
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

    // iso-639-2 covers only 183 languages by 2-letter code, which leaves half
    // of locale.gen unlabelled; -3 adds the 3-letter ones (anp, yue, szl) and
    // -5 the collections (ber). Together they name every locale glibc ships.
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

    // "custom" is not a layout, it is a placeholder for people who hand-write
    // their own xkb symbols file; picking it yields a dead keyboard.
    readonly property var hiddenLayouts: ["custom"]

    // iso-639-3 types every language: L living, H historical, C constructed,
    // E extinct, S special. Anything but living is a curiosity here (Sanskrit,
    // Toki Pona, Geez), and hiding it costs nobody their own language. Codes
    // we have no type for, like the "ber" collection, are kept.
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
        const kept = known ? codes.filter(tz => root.zoneCountry.hasOwnProperty(tz)) : codes;
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
