pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls

Item {
    id: root

    property alias text: label.text
    property color primaryColour
    property color secondaryColour
    property color tertiaryColour
    property color surfaceColour
    property alias radius: swatchWrapper.radius
    property bool selected

    signal clicked

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.small

        StyledClippingRect {
            id: swatchWrapper

            Layout.fillWidth: true
            implicitHeight: width
            radius: Tokens.rounding.largeIncreased
            color: root.surfaceColour

            border.width: root.selected ? 2 : 0
            border.color: Colours.palette.m3primary

            GridLayout {
                anchors.fill: parent
                anchors.margins: root.selected ? 2 : 0
                columns: 2
                rows: 2
                columnSpacing: 0
                rowSpacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.primaryColour
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.secondaryColour
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.tertiaryColour
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.surfaceColour
                }
            }
        }

        StyledText {
            id: label

            Layout.bottomMargin: Tokens.padding.small
            Layout.fillWidth: true
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.builders.small.weight(Font.Medium).build()
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    StateLayer {
        onClicked: root.clicked()
    }
}
