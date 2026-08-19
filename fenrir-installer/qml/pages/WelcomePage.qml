import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import "../"

Item {
    id: root

    signal tour()
    signal skip()

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width * 0.75
        spacing: TokenConfig.appearance.spacing.large

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Welcome to Fenrir"
            color: Colours.m3onSurface
            font.family: Fonts.sans
            font.pointSize: TokenConfig.appearance.fontSize.extraLarge
            font.bold: true
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Fenrir uses a tiling window manager — windows arrange themselves instead of overlapping, and almost everything is a keybind rather than a menu. New to this? A minute-long tour covers what you need to get around."
            color: Colours.m3outline
            font.family: Fonts.sans
            font.pointSize: TokenConfig.appearance.fontSize.normal
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: TokenConfig.appearance.spacing.normal

            NavButton {
                text: "Skip"
                onClicked: root.skip()
            }

            NavButton {
                text: "Take the tour"
                accent: true
                onClicked: root.tour()
            }
        }
    }
}
