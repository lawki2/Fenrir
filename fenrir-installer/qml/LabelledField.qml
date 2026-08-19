import QtQuick
import QtQuick.Layouts
import Caelestia.Config

// A single label+control row, styled like Caelestia's own SelectRow/InfoRow
// pattern in Nexus (card background, padded row, label on the left).
Rectangle {
    id: root

    default property alias content: contentSlot.children
    property string label

    implicitHeight: 56
    radius: TokenConfig.appearance.rounding.normal
    color: Colours.m3surfaceContainerLow

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

        Item {
            id: contentSlot
            Layout.preferredWidth: 260
            Layout.preferredHeight: parent.height
        }
    }
}
