import QtQuick
import QtQuick.Layouts
import Caelestia.Config

// A card-styled row that opens a full-page Picker instead of an inline
// dropdown, for options lists too long to browse comfortably in a popup
// (timezones, keymaps, disks). `first`/`last` (ported from Caelestia's real
// ConnectedRect grouping convention) let adjacent SelectField rows share
// one seamless grouped panel instead of each being its own floating card.
//
// Value display ported from Caelestia's real Nexus common/InfoRow.qml
// (label + right-aligned elided value, capped via a plain
// `Layout.maximumWidth: root.width / 2` - a real pixel value at layout
// time, not dependent on any nested component's implicit size) combined
// with common/NavRow.qml's click/chevron affordance (StateLayer + a real
// trailing `chevron_right` icon instead of a literal "›" character). This
// replaces an earlier SplitButton-chip attempt: SplitButton is Caelestia's
// real component for *short* inline-toggle labels (on/off, a scheme name),
// not arbitrarily long values - a full IANA timezone name
// ("America/Argentina/ComodRivadavia") blew straight past the chip's
// width and off the edge of the window, since Layout.maximumWidth on the
// inner Text didn't actually constrain the chip's own implicit-width
// calculation. InfoRow's plain-text-with-a-real-width-cap approach doesn't
// have that failure mode at all - see fenrir_design_guidelines.md for the
// full story.
Rectangle {
    id: root

    property string label
    property string value
    property var options: []
    property string pickerTitle: label
    property bool first: true
    property bool last: true

    signal picked(string value)

    implicitHeight: 56
    color: Colours.m3surfaceContainerLow
    // Outer corners now match StyledTextField.qml's own radius exactly
    // (TokenConfig.appearance.rounding.small) - the previous .normal value
    // read as barely-rounded/square next to the text fields' visibly
    // curved outline, which looked inconsistent.
    topLeftRadius: root.first ? TokenConfig.appearance.rounding.small : TokenConfig.appearance.rounding.extraSmall
    topRightRadius: root.first ? TokenConfig.appearance.rounding.small : TokenConfig.appearance.rounding.extraSmall
    bottomLeftRadius: root.last ? TokenConfig.appearance.rounding.small : TokenConfig.appearance.rounding.extraSmall
    bottomRightRadius: root.last ? TokenConfig.appearance.rounding.small : TokenConfig.appearance.rounding.extraSmall

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: TokenConfig.appearance.padding.large
        anchors.rightMargin: TokenConfig.appearance.padding.large
        spacing: TokenConfig.appearance.spacing.normal

        Text {
            text: root.label
            color: Colours.m3onSurface
            font.family: Fonts.sans
            font.pointSize: TokenConfig.appearance.fontSize.normal
        }

        Item { Layout.fillWidth: true }

        Text {
            Layout.maximumWidth: root.width / 2
            text: root.value
            horizontalAlignment: Text.AlignRight
            color: Colours.m3outline
            font.family: Fonts.sans
            font.pointSize: TokenConfig.appearance.fontSize.normal
            elide: Text.ElideRight
        }

        Icon {
            text: "chevron_right"
            font.pixelSize: 20
            color: Colours.m3outline
        }
    }

    StateLayer {
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        onClicked: Picker.open(root.pickerTitle, root.options, root.value, val => root.picked(val))
    }
}
