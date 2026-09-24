pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The only reader and writer of ~/.config/caelestia/hypr-vars.lua, the user's overrides of
// Fenrir's Hyprland variables (merged over /usr/share/fenrir/hypr/variables.lua on load).
Singleton {
    id: root

    // Flat string/number/bool entries only; variables.lua entries built from expressions are skipped.
    property var defaults: ({})
    property var overrides: ({})

    function value(key: string): var {
        return key in root.overrides ? root.overrides[key] : root.defaults[key];
    }

    // Built on the in-memory copy, which a write updates at once; re-reading the file straight
    // after a write can still return the old text and drop the earlier change.
    function set(changes: var): void {
        root.write(Object.assign({}, root.overrides, changes));
    }

    function reset(keys: var): void {
        const data = Object.assign({}, root.overrides);
        for (const key of keys)
            delete data[key];
        root.write(data);
    }

    function parse(text: string): var {
        const result = {};
        const re = /(\w+)\s*=\s*("(?:[^"\\]|\\.)*"|-?\d+(?:\.\d+)?|true|false)(?=\s*[,}\n])/g;
        let match;
        while ((match = re.exec(text)) !== null) {
            const raw = match[2];
            if (raw.startsWith('"'))
                result[match[1]] = raw.slice(1, -1).replace(/\\(.)/g, "$1");
            else if (raw === "true" || raw === "false")
                result[match[1]] = raw === "true";
            else
                result[match[1]] = Number(raw);
        }
        return result;
    }

    function serialize(data: var): string {
        const keys = Object.keys(data);
        if (!keys.length)
            return "return {}\n";
        const lines = keys.map(k => {
            const v = data[k];
            return `    ${k} = ${typeof v === "string" ? `"${v.replace(/(["\\])/g, "\\$1")}"` : v},`;
        });
        return `return {\n${lines.join("\n")}\n}\n`;
    }

    function write(data: var): void {
        overridesFile.setText(root.serialize(data));
        root.overrides = data;
        Hypr.extras.batchMessage(["reload"]);
        // A reload puts back everything game mode had switched off.
        if (GameMode.enabled)
            GameMode.setDynamicConfs();
    }

    FileView {
        id: overridesFile

        path: `${Quickshell.env("HOME")}/.config/caelestia/hypr-vars.lua`
        printErrors: false
        // Picks up hand edits, so the in-memory copy stays the file's.
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.overrides = root.parse(text())
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                Qt.callLater(() => setText("return {}\n"));
        }
    }

    FileView {
        path: "/usr/share/fenrir/hypr/variables.lua"
        printErrors: false
        onLoaded: root.defaults = root.parse(text())
    }
}
