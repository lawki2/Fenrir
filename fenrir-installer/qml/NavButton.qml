import QtQuick
import QtQuick.Layouts
import Caelestia.Config

Rectangle {
    id: root

    property string text
    property bool accent: false
    signal clicked()

    Layout.preferredHeight: 36
    Layout.preferredWidth: label.implicitWidth + TokenConfig.appearance.padding.large * 2
    radius: TokenConfig.appearance.rounding.small
    color: accent ? Colours.m3primary : "transparent"

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.accent ? Colours.m3onPrimary : Colours.m3onSurface
        font.family: Fonts.sans
        font.pointSize: TokenConfig.appearance.fontSize.normal
    }

    StateLayer {
        radius: root.radius
        color: root.accent ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
        onClicked: root.clicked()
    }
}
