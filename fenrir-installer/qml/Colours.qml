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
    property color m3secondary: "#625b71"
    property color m3onSecondary: "#ffffff"
    property color m3secondaryContainer: "#e8def8"
    property color m3onSecondaryContainer: "#1e192b"
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

    // Mirrors real Caelestia's Colours.palette.m3xxx nesting (services/
    // Colours.qml's M3Palette component) so vendored/ported real components
    // that use that shape work unmodified against this shim too.
    readonly property Palette palette: Palette {}

    component Palette: QtObject {
        readonly property color m3primary: root.m3primary
        readonly property color m3onPrimary: root.m3onPrimary
        readonly property color m3secondary: root.m3secondary
        readonly property color m3onSecondary: root.m3onSecondary
        readonly property color m3secondaryContainer: root.m3secondaryContainer
        readonly property color m3onSecondaryContainer: root.m3onSecondaryContainer
        readonly property color m3surface: root.m3surface
        readonly property color m3onSurface: root.m3onSurface
        readonly property color m3surfaceContainerLow: root.m3surfaceContainerLow
        readonly property color m3surfaceContainerHigh: root.m3surfaceContainerHigh
        readonly property color m3surfaceContainerHighest: root.m3surfaceContainerHighest
        readonly property color m3outline: root.m3outline
        readonly property color m3outlineVariant: root.m3outlineVariant
        readonly property color m3error: root.m3error
        readonly property color m3onError: root.m3onError
        readonly property color m3success: root.m3success
        readonly property color m3onSuccess: root.m3onSuccess
    }

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
