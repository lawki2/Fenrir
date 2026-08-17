import QtQuick
import QtQuick.Layouts
import Caelestia.Config

// A LabelledField-styled row that opens a full-page Picker instead of an
// inline dropdown, for options lists too long to browse comfortably in a
// popup (timezones, keymaps, disks).
Rectangle {
    id: root

    property string label
    property string value
    property var options: []
    property string pickerTitle: label

    signal picked(string value)

    implicitHeight: 56
    radius: TokenConfig.appearance.rounding.small
    color: Colours.m3surfaceContainerHigh

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Colours.m3onSurface
        opacity: mouse.pressed ? 0.1 : mouse.containsMouse ? 0.08 : 0
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: TokenConfig.appearance.padding.large
        anchors.rightMargin: TokenConfig.appearance.padding.large
        spacing: TokenConfig.appearance.spacing.normal

        Text {
            text: root.label
            color: Colours.m3onSurface
            font.family: "Rubik"
            font.pointSize: TokenConfig.appearance.fontSize.normal
        }

        Item { Layout.fillWidth: true }

        Text {
            Layout.maximumWidth: 220
            text: root.value
            color: Colours.m3outline
            font.family: "Rubik"
            font.pointSize: TokenConfig.appearance.fontSize.normal
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
        }

        Text {
            text: "›"
            color: Colours.m3outline
            font.family: "Rubik"
            font.pointSize: TokenConfig.appearance.fontSize.large
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Picker.open(root.pickerTitle, root.options, root.value, val => root.picked(val))
    }
}
