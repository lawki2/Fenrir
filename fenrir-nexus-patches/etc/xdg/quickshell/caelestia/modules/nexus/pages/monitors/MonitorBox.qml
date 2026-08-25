pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.modules.nexus.common

Rectangle {
    id: root

    required property string monitorName
    property string label
    property bool primary
    property bool selected
    property bool overlapping

    signal tapped
    signal dragFinished(real x, real y)

    radius: Tokens.rounding.small
    color: root.overlapping ? Colours.tPalette.m3errorContainer : root.selected ? Colours.tPalette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHigh
    border.width: root.primary ? 2 : 0
    border.color: Colours.palette.m3primary

    Behavior on x {
        enabled: !dragHandler.active
        Anim {
            type: Anim.DefaultSpatial
        }
    }
    Behavior on y {
        enabled: !dragHandler.active
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    StyledText {
        anchors.centerIn: parent
        width: parent.width - Tokens.padding.small * 2
        text: root.label
        color: root.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.small
        elide: Text.ElideMiddle
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }

    MaterialIcon {
        visible: root.primary
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Tokens.padding.extraSmall
        text: "star"
        color: Colours.palette.m3primary
        fontStyle: Tokens.font.icon.small
    }

    TapHandler {
        onTapped: root.tapped()
    }

    DragHandler {
        id: dragHandler

        onActiveChanged: {
            if (!active)
                root.dragFinished(root.x, root.y);
        }
    }
}
