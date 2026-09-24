pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    signal next

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(Tokens.sizes.nexus.maxContentWidth, parent.width)
        spacing: Tokens.spacing.large

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Welcome to Fenrir")
            font: Tokens.font.headline.large
            horizontalAlignment: Text.AlignHCenter
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.large
            text: qsTr("A few questions and this machine is yours. Nothing is written to disk until you confirm.")
            color: Colours.palette.m3outline
            font: Tokens.font.body.large
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        ButtonBase {
            id: startButton

            Layout.alignment: Qt.AlignHCenter
            shapeMorph: true
            isRound: true
            inactiveColour: Colours.palette.m3primary
            inactiveOnColour: Colours.palette.m3onPrimary
            implicitWidth: startLabel.implicitWidth + Tokens.padding.extraLarge * 2
            implicitHeight: startLabel.implicitHeight + Tokens.padding.large * 2
            onClicked: root.next()

            StyledText {
                id: startLabel

                anchors.centerIn: parent
                text: qsTr("Get started")
                color: startButton.onColour
                font: Tokens.font.body.large
            }
        }
    }
}
