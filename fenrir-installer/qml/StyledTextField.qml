import QtQuick
import QtQuick.Controls
import Caelestia.Config

// Modeled on how Caelestia's own live UI actually reads (screenshotted
// Nexus's settings panel), not the more elaborate source-only version —
// quiet/barely-tinted fill, generously rounded, no bold accent underline.
// See fenrir_design_guidelines.md's "Live-observed: Nexus settings panel"
// and "Text input" sections for the full reasoning and a rendering bug hit
// (and not fully root-caused) with a nested-Rectangle accent-line approach
// — this version deliberately avoids that shape (single flat Rectangle,
// no ternary fill colour, border only appears on focus) instead of
// re-attempting it.
TextField {
    id: root

    color: Colours.m3onSurface
    font.family: "Rubik"
    font.pointSize: TokenConfig.appearance.fontSize.normal
    renderType: echoMode === TextField.Password ? TextInput.QtRendering : TextInput.NativeRendering
    selectionColor: Qt.alpha(Colours.m3primary, 0.4)
    selectedTextColor: Colours.m3onSurface

    leftPadding: TokenConfig.appearance.padding.large
    rightPadding: TokenConfig.appearance.padding.large
    topPadding: TokenConfig.appearance.padding.normal
    bottomPadding: TokenConfig.appearance.padding.normal

    background: Rectangle {
        radius: TokenConfig.appearance.rounding.normal
        color: Colours.m3surfaceContainerHigh
        border.width: root.activeFocus ? 1 : 0
        border.color: Colours.m3primary
    }
}
