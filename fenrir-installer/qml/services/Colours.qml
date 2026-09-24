pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config

// Caelestia's Colours API for its real components. Not the real service: that needs
// Hyprland IPC, which the installer lacks running as root via pkexec.
Singleton {
    id: root

    readonly property bool light: root.m3surface.hslLightness > 0.5

    property color m3background: "#000000"
    property color m3onBackground: "#000000"
    property color m3surface: "#000000"
    property color m3surfaceDim: "#000000"
    property color m3surfaceBright: "#000000"
    property color m3surfaceContainerLowest: "#000000"
    property color m3surfaceContainerLow: "#000000"
    property color m3surfaceContainer: "#000000"
    property color m3surfaceContainerHigh: "#000000"
    property color m3surfaceContainerHighest: "#000000"
    property color m3onSurface: "#000000"
    property color m3surfaceVariant: "#000000"
    property color m3onSurfaceVariant: "#000000"
    property color m3outline: "#000000"
    property color m3outlineVariant: "#000000"
    property color m3inverseSurface: "#000000"
    property color m3inverseOnSurface: "#000000"
    property color m3shadow: "#000000"
    property color m3scrim: "#000000"
    property color m3surfaceTint: "#000000"
    property color m3primary: "#000000"
    property color m3primaryDim: "#000000"
    property color m3onPrimary: "#000000"
    property color m3primaryContainer: "#000000"
    property color m3onPrimaryContainer: "#000000"
    property color m3inversePrimary: "#000000"
    property color m3primaryFixed: "#000000"
    property color m3primaryFixedDim: "#000000"
    property color m3onPrimaryFixed: "#000000"
    property color m3onPrimaryFixedVariant: "#000000"
    property color m3secondary: "#000000"
    property color m3secondaryDim: "#000000"
    property color m3onSecondary: "#000000"
    property color m3secondaryContainer: "#000000"
    property color m3onSecondaryContainer: "#000000"
    property color m3secondaryFixed: "#000000"
    property color m3secondaryFixedDim: "#000000"
    property color m3onSecondaryFixed: "#000000"
    property color m3onSecondaryFixedVariant: "#000000"
    property color m3tertiary: "#000000"
    property color m3tertiaryDim: "#000000"
    property color m3onTertiary: "#000000"
    property color m3tertiaryContainer: "#000000"
    property color m3onTertiaryContainer: "#000000"
    property color m3tertiaryFixed: "#000000"
    property color m3tertiaryFixedDim: "#000000"
    property color m3onTertiaryFixed: "#000000"
    property color m3onTertiaryFixedVariant: "#000000"
    property color m3error: "#000000"
    property color m3errorDim: "#000000"
    property color m3onError: "#000000"
    property color m3errorContainer: "#000000"
    property color m3onErrorContainer: "#000000"
    property color m3primaryPaletteKeyColor: "#000000"
    property color m3secondaryPaletteKeyColor: "#000000"
    property color m3tertiaryPaletteKeyColor: "#000000"
    property color m3neutralPaletteKeyColor: "#000000"
    property color m3neutralVariantPaletteKeyColor: "#000000"
    property color m3errorPaletteKeyColor: "#000000"
    property color m3primary_paletteKeyColor: "#000000"
    property color m3secondary_paletteKeyColor: "#000000"
    property color m3tertiary_paletteKeyColor: "#000000"
    property color m3neutral_paletteKeyColor: "#000000"
    property color m3neutral_variant_paletteKeyColor: "#000000"
    property color term0: "#000000"
    property color term1: "#000000"
    property color term2: "#000000"
    property color term3: "#000000"
    property color term4: "#000000"
    property color term5: "#000000"
    property color term6: "#000000"
    property color term7: "#000000"
    property color term8: "#000000"
    property color term9: "#000000"
    property color term10: "#000000"
    property color term11: "#000000"
    property color term12: "#000000"
    property color term13: "#000000"
    property color term14: "#000000"
    property color term15: "#000000"
    property color m3rosewater: "#000000"
    property color m3flamingo: "#000000"
    property color m3pink: "#000000"
    property color m3mauve: "#000000"
    property color m3red: "#000000"
    property color m3maroon: "#000000"
    property color m3peach: "#000000"
    property color m3yellow: "#000000"
    property color m3green: "#000000"
    property color m3teal: "#000000"
    property color m3sky: "#000000"
    property color m3sapphire: "#000000"
    property color m3blue: "#000000"
    property color m3lavender: "#000000"
    property color m3klink: "#000000"
    property color m3klinkSelection: "#000000"
    property color m3kvisited: "#000000"
    property color m3kvisitedSelection: "#000000"
    property color m3knegative: "#000000"
    property color m3knegativeSelection: "#000000"
    property color m3kneutral: "#000000"
    property color m3kneutralSelection: "#000000"
    property color m3kpositive: "#000000"
    property color m3kpositiveSelection: "#000000"
    property color m3text: "#000000"
    property color m3subtext1: "#000000"
    property color m3subtext0: "#000000"
    property color m3overlay2: "#000000"
    property color m3overlay1: "#000000"
    property color m3overlay0: "#000000"
    property color m3surface2: "#000000"
    property color m3surface1: "#000000"
    property color m3surface0: "#000000"
    property color m3base: "#000000"
    property color m3mantle: "#000000"
    property color m3crust: "#000000"
    property color m3success: "#000000"
    property color m3onSuccess: "#000000"
    property color m3successContainer: "#000000"
    property color m3onSuccessContainer: "#000000"

    readonly property Palette palette: Palette {}
    readonly property TPalette tPalette: TPalette {}
    // Same source as Caelestia's Colours, so it matches the desktop's transparency.
    // Not Config.appearance: that is screen-scoped, and a singleton has no screen.
    readonly property Transparency transparency: Transparency {}

    component Transparency: QtObject {
        readonly property bool enabled: Tokens.transparency.enabled
        readonly property real base: Math.max(0, Math.min(1, Tokens.transparency.base - (root.light ? 0.1 : 0)))
        readonly property real layers: Math.max(0, Math.min(1, Tokens.transparency.layers))
    }

    // Caelestia's components tint themselves through this; returning the
    // colour unchanged when transparency is off matches its behaviour.
    function layer(c: color, layer: var): color {
        if (!root.transparency.enabled)
            return c;
        return layer === 0 ? Qt.alpha(c, root.transparency.base) : Qt.alpha(c, root.transparency.layers);
    }

    component Palette: QtObject {
        readonly property color m3background: root.m3background
        readonly property color m3onBackground: root.m3onBackground
        readonly property color m3surface: root.m3surface
        readonly property color m3surfaceDim: root.m3surfaceDim
        readonly property color m3surfaceBright: root.m3surfaceBright
        readonly property color m3surfaceContainerLowest: root.m3surfaceContainerLowest
        readonly property color m3surfaceContainerLow: root.m3surfaceContainerLow
        readonly property color m3surfaceContainer: root.m3surfaceContainer
        readonly property color m3surfaceContainerHigh: root.m3surfaceContainerHigh
        readonly property color m3surfaceContainerHighest: root.m3surfaceContainerHighest
        readonly property color m3onSurface: root.m3onSurface
        readonly property color m3surfaceVariant: root.m3surfaceVariant
        readonly property color m3onSurfaceVariant: root.m3onSurfaceVariant
        readonly property color m3outline: root.m3outline
        readonly property color m3outlineVariant: root.m3outlineVariant
        readonly property color m3inverseSurface: root.m3inverseSurface
        readonly property color m3inverseOnSurface: root.m3inverseOnSurface
        readonly property color m3shadow: root.m3shadow
        readonly property color m3scrim: root.m3scrim
        readonly property color m3surfaceTint: root.m3surfaceTint
        readonly property color m3primary: root.m3primary
        readonly property color m3primaryDim: root.m3primaryDim
        readonly property color m3onPrimary: root.m3onPrimary
        readonly property color m3primaryContainer: root.m3primaryContainer
        readonly property color m3onPrimaryContainer: root.m3onPrimaryContainer
        readonly property color m3inversePrimary: root.m3inversePrimary
        readonly property color m3primaryFixed: root.m3primaryFixed
        readonly property color m3primaryFixedDim: root.m3primaryFixedDim
        readonly property color m3onPrimaryFixed: root.m3onPrimaryFixed
        readonly property color m3onPrimaryFixedVariant: root.m3onPrimaryFixedVariant
        readonly property color m3secondary: root.m3secondary
        readonly property color m3secondaryDim: root.m3secondaryDim
        readonly property color m3onSecondary: root.m3onSecondary
        readonly property color m3secondaryContainer: root.m3secondaryContainer
        readonly property color m3onSecondaryContainer: root.m3onSecondaryContainer
        readonly property color m3secondaryFixed: root.m3secondaryFixed
        readonly property color m3secondaryFixedDim: root.m3secondaryFixedDim
        readonly property color m3onSecondaryFixed: root.m3onSecondaryFixed
        readonly property color m3onSecondaryFixedVariant: root.m3onSecondaryFixedVariant
        readonly property color m3tertiary: root.m3tertiary
        readonly property color m3tertiaryDim: root.m3tertiaryDim
        readonly property color m3onTertiary: root.m3onTertiary
        readonly property color m3tertiaryContainer: root.m3tertiaryContainer
        readonly property color m3onTertiaryContainer: root.m3onTertiaryContainer
        readonly property color m3tertiaryFixed: root.m3tertiaryFixed
        readonly property color m3tertiaryFixedDim: root.m3tertiaryFixedDim
        readonly property color m3onTertiaryFixed: root.m3onTertiaryFixed
        readonly property color m3onTertiaryFixedVariant: root.m3onTertiaryFixedVariant
        readonly property color m3error: root.m3error
        readonly property color m3errorDim: root.m3errorDim
        readonly property color m3onError: root.m3onError
        readonly property color m3errorContainer: root.m3errorContainer
        readonly property color m3onErrorContainer: root.m3onErrorContainer
        readonly property color m3primaryPaletteKeyColor: root.m3primaryPaletteKeyColor
        readonly property color m3secondaryPaletteKeyColor: root.m3secondaryPaletteKeyColor
        readonly property color m3tertiaryPaletteKeyColor: root.m3tertiaryPaletteKeyColor
        readonly property color m3neutralPaletteKeyColor: root.m3neutralPaletteKeyColor
        readonly property color m3neutralVariantPaletteKeyColor: root.m3neutralVariantPaletteKeyColor
        readonly property color m3errorPaletteKeyColor: root.m3errorPaletteKeyColor
        readonly property color m3primary_paletteKeyColor: root.m3primary_paletteKeyColor
        readonly property color m3secondary_paletteKeyColor: root.m3secondary_paletteKeyColor
        readonly property color m3tertiary_paletteKeyColor: root.m3tertiary_paletteKeyColor
        readonly property color m3neutral_paletteKeyColor: root.m3neutral_paletteKeyColor
        readonly property color m3neutral_variant_paletteKeyColor: root.m3neutral_variant_paletteKeyColor
        readonly property color term0: root.term0
        readonly property color term1: root.term1
        readonly property color term2: root.term2
        readonly property color term3: root.term3
        readonly property color term4: root.term4
        readonly property color term5: root.term5
        readonly property color term6: root.term6
        readonly property color term7: root.term7
        readonly property color term8: root.term8
        readonly property color term9: root.term9
        readonly property color term10: root.term10
        readonly property color term11: root.term11
        readonly property color term12: root.term12
        readonly property color term13: root.term13
        readonly property color term14: root.term14
        readonly property color term15: root.term15
        readonly property color m3rosewater: root.m3rosewater
        readonly property color m3flamingo: root.m3flamingo
        readonly property color m3pink: root.m3pink
        readonly property color m3mauve: root.m3mauve
        readonly property color m3red: root.m3red
        readonly property color m3maroon: root.m3maroon
        readonly property color m3peach: root.m3peach
        readonly property color m3yellow: root.m3yellow
        readonly property color m3green: root.m3green
        readonly property color m3teal: root.m3teal
        readonly property color m3sky: root.m3sky
        readonly property color m3sapphire: root.m3sapphire
        readonly property color m3blue: root.m3blue
        readonly property color m3lavender: root.m3lavender
        readonly property color m3klink: root.m3klink
        readonly property color m3klinkSelection: root.m3klinkSelection
        readonly property color m3kvisited: root.m3kvisited
        readonly property color m3kvisitedSelection: root.m3kvisitedSelection
        readonly property color m3knegative: root.m3knegative
        readonly property color m3knegativeSelection: root.m3knegativeSelection
        readonly property color m3kneutral: root.m3kneutral
        readonly property color m3kneutralSelection: root.m3kneutralSelection
        readonly property color m3kpositive: root.m3kpositive
        readonly property color m3kpositiveSelection: root.m3kpositiveSelection
        readonly property color m3text: root.m3text
        readonly property color m3subtext1: root.m3subtext1
        readonly property color m3subtext0: root.m3subtext0
        readonly property color m3overlay2: root.m3overlay2
        readonly property color m3overlay1: root.m3overlay1
        readonly property color m3overlay0: root.m3overlay0
        readonly property color m3surface2: root.m3surface2
        readonly property color m3surface1: root.m3surface1
        readonly property color m3surface0: root.m3surface0
        readonly property color m3base: root.m3base
        readonly property color m3mantle: root.m3mantle
        readonly property color m3crust: root.m3crust
        readonly property color m3success: root.m3success
        readonly property color m3onSuccess: root.m3onSuccess
        readonly property color m3successContainer: root.m3successContainer
        readonly property color m3onSuccessContainer: root.m3onSuccessContainer
    }

    component TPalette: QtObject {
        readonly property color m3surface: root.layer(root.palette.m3surface, 0)
        readonly property color m3surfaceContainer: root.layer(root.palette.m3surfaceContainer)
        readonly property color m3surfaceContainerHigh: root.layer(root.palette.m3surfaceContainerHigh)
        readonly property color m3surfaceContainerHighest: root.layer(root.palette.m3surfaceContainerHighest)
        readonly property color m3surfaceContainerLow: root.layer(root.palette.m3surfaceContainerLow)
        readonly property color m3background: root.layer(root.palette.m3background, 0)
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
