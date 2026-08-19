pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Reads the user's actual chosen fonts from Caelestia's own shell.json
// (~/.config/caelestia/shell.json's appearance.font.family) — the same
// file Nexus writes to when someone customises fonts. NOT
// GlobalConfig.appearance.font.family: that returns undefined in a
// standalone (non-Caelestia-shell) Quickshell instance, the same class of
// problem Colours.qml already solves for the colour scheme, worked around
// the same way — read the backing file directly instead of relying on the
// singleton. Falls back to Caelestia's real token defaults if the file
// doesn't exist yet (a fresh live/install user genuinely won't have one —
// it's created later by Caelestia's own shell/Nexus, never shipped in
// skel) or has no font section.
Singleton {
    id: root

    property string sans: "Rubik"
    property string mono: "CaskaydiaCove NF"

    FileView {
        path: `${Quickshell.env("HOME")}/.config/caelestia/shell.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const config = JSON.parse(text());
                const family = config.appearance && config.appearance.font && config.appearance.font.family;
                if (family && family.sans)
                    root.sans = family.sans;
                if (family && family.mono)
                    root.mono = family.mono;
            } catch (e) {
                // Malformed JSON, keep defaults
            }
        }
    }
}
