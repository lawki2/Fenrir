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

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Colours.m3onSurface
        opacity: mouse.pressed ? 0.1 : mouse.containsMouse ? 0.08 : 0
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.accent ? Colours.m3onPrimary : Colours.m3onSurface
        font.family: Fonts.sans
        font.pointSize: TokenConfig.appearance.fontSize.normal
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
