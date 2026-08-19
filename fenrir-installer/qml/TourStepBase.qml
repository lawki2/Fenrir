import QtQuick
import QtQuick.Layouts
import Caelestia.Config

// Shared visual template for each tour step — pages/Tour*.qml files are
// just this with stepTitle/body overridden, so they ARE a TourStepBase at
// the root (not wrapping one), meaning shell.qml's Connections can listen
// for "next" directly without any signal-forwarding boilerplate per step.
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
