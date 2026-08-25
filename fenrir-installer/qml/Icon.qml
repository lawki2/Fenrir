import QtQuick

// Fenrir's equivalent of Caelestia's own components/MaterialIcon.qml. The
// real one builds its font through Tokens.font.icon's fluent
// size()/weight()/vaxes()/fill()/grade() API, backed by a compiled
// Caelestia.Config type this app doesn't have access to (TokenConfig has
// no equivalent) - Qt's own font.variableAxes is read-only introspection,
// not a settable API for controlling fill/weight/grade (confirmed from
// Qt's own qmltypes, not assumed). Material Symbols Rounded is still a
// real, system-wide installed font though (not scoped to caelestia-shell
// the way qs.* QML files are), so plain glyph text at the font's default
// axis values renders real, correct icons - just without per-instance
// fill/weight/grade tuning.
Text {
    id: root

    font.family: "Material Symbols Rounded"
    font.pixelSize: 20
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
