pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Reads Caelestia's live colour scheme the same way its own shell does
// (Colours.qml's FileView, in caelestia-shell). That file isn't reusable
// across shells directly (qs.* imports are shell-relative, and
// scheme.json's own colour swatches live in shell-local QML, not the
// globally-importable Caelestia.Config plugin), so this is a small
// same-pattern reimplementation reading the identical file. Property
// names keep Caelestia's own "m3" prefix convention (m3onSurface, not
// onSurface) since a bare "on<Capital>" name is parsed by QML as a signal
// handler slot, not a property, and fails to compile.
Singleton {
    id: root

    property color m3primary: "#6750a4"
    property color m3onPrimary: "#ffffff"
    property color m3surface: "#fffbff"
    property color m3onSurface: "#1c1b1e"
    property color m3surfaceContainerLow: "#f6eefa"
    property color m3surfaceContainerHigh: "#ece6f0"
    property color m3surfaceContainerHighest: "#e6e0e9"
    property color m3outline: "#79747e"
    property color m3outlineVariant: "#cac4cf"
    property color m3error: "#ba1a1a"
    property color m3onError: "#ffffff"
    property color m3success: "#4F6354"
    property color m3onSuccess: "#ffffff"

    function load(data: string): void {
        const scheme = JSON.parse(data);
        for (const [name, value] of Object.entries(scheme.colours)) {
            const propName = name.startsWith("term") ? name : `m3${name}`;
            if (root.hasOwnProperty(propName))
                root[propName] = `#${value}`;
        }
    }

    FileView {
        path: `${Quickshell.env("HOME")}/.local/state/caelestia/scheme.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.load(text())
    }
}
