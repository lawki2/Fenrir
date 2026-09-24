import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services

// Template for each tour step; the Tour*.qml files override stepTitle and body,
// so a host can listen for "next" on the step itself.
Item {
    id: root

    property string stepTitle
    property string body
    signal next()

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width * 0.75
        spacing: TokenConfig.appearance.spacing.large

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.stepTitle
            color: Colours.m3onSurface
            font.family: Fonts.sans
            font.pointSize: TokenConfig.appearance.fontSize.extraLarge
            font.bold: true
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.body
            color: Colours.m3outline
            font.family: Fonts.sans
            font.pointSize: TokenConfig.appearance.fontSize.normal
        }

        NavButton {
            Layout.alignment: Qt.AlignHCenter
            text: "Next"
            accent: true
            onClicked: root.next()
        }
    }
}
