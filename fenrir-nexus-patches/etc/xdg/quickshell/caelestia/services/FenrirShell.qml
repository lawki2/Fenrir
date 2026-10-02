pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// The only reader and writer of ~/.config/caelestia/fenrir.json, Fenrir's shell settings that Caelestia's config has no keys for.
Singleton {
    id: root

    // Read up front, so a taskbar user's windows don't lay out for the dock first.
    property var data: root.parse(file.text())

    // "dock": the clock and status group at the bottom left; "taskbar": Caelestia's full-height bar.
    readonly property string barStyle: data.barStyle === "taskbar" ? "taskbar" : "dock"
    readonly property bool dock: barStyle === "dock"

    function parse(text: string): var {
        try {
            return JSON.parse(text) ?? {};
        } catch (e) {
            return {};
        }
    }

    function set(changes: var): void {
        root.data = Object.assign({}, root.data, changes);
        file.setText(JSON.stringify(root.data, null, 4) + "\n");
    }

    FileView {
        id: file

        path: `${Paths.config}/fenrir.json`
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.data = root.parse(text())
    }
}
