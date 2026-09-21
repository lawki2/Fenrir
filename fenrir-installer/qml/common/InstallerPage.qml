pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

// Caelestia's Nexus PageBase minus NexusState: same header, same capped
// content width, same fading flickable, so installer pages and settings
// pages are laid out identically. The installer has its own navigation, so
// the sub-page back button is dropped.
ColumnLayout {
    id: root

    required property string title
    property string subtitle

    readonly property int cappedWidth: Math.min(Tokens.sizes.nexus.maxContentWidth, width)
    readonly property alias flickable: flickable

    default property Item contentChild

    spacing: Tokens.spacing.extraLargeIncreased

    ColumnLayout {
        spacing: Tokens.spacing.extraSmall

        StyledText {
            Layout.fillWidth: true
            text: root.title
            font: Tokens.font.title.large
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.subtitle.length > 0
            text: root.subtitle
            color: Colours.palette.m3outline
            font: Tokens.font.body.medium
            wrapMode: Text.WordWrap
        }
    }

    VerticalFadeFlickable {
        id: flickable

        Layout.fillWidth: true
        Layout.fillHeight: true

        Layout.topMargin: -topMargin
        topMargin: Tokens.padding.large
        bottomMargin: Tokens.padding.extraLarge

        contentHeight: root.contentChild?.implicitHeight ?? 0
        contentItem.children: [root.contentChild]

        TapHandler {
            onTapped: flickable.focus = true
        }
    }
}
