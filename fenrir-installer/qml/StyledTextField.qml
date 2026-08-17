import QtQuick
import QtQuick.Controls
import Caelestia.Config

TextField {
    id: root

    color: Colours.m3onSurface
    font.family: "Rubik"
    font.pointSize: TokenConfig.appearance.fontSize.normal
    selectionColor: Colours.m3primary
    selectedTextColor: Colours.m3onPrimary

    leftPadding: TokenConfig.appearance.padding.normal
    rightPadding: TokenConfig.appearance.padding.normal
    topPadding: TokenConfig.appearance.padding.small
    bottomPadding: TokenConfig.appearance.padding.small

    background: Rectangle {
        radius: TokenConfig.appearance.rounding.small
        color: Colours.m3surfaceContainerLow
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? Colours.m3primary : Colours.m3outlineVariant
    }
}
