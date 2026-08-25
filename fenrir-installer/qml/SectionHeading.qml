import QtQuick
import QtQuick.Layouts
import Caelestia.Config

// Page-level heading: a real Material icon paired with a larger, prominent
// title - replaces the small muted (Colours.m3outline) caption every page
// used to open with. Matches how Caelestia's own Nexus treats each
// settings category (icon + real title), not a quiet caption above the
// content. Deliberately *not* bold - shell.qml's own top-level "Install
// Fenrir" title already is, and two stacked bold headings read as too
// heavy; the larger font size plus the icon are enough to establish
// hierarchy on their own.
RowLayout {
    id: root

    property string icon
    property string text

    spacing: TokenConfig.appearance.spacing.normal

    Icon {
        text: root.icon
        color: Colours.m3primary
        font.pixelSize: 24
    }

    Text {
        text: root.text
        color: Colours.m3onSurface
        font.family: Fonts.sans
        font.pointSize: TokenConfig.appearance.fontSize.large
    }
}
