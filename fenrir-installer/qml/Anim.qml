import QtQuick
import Caelestia.Config

// Fenrir's equivalent of Caelestia's own shell-local components/Anim.qml —
// that file isn't reusable outside caelestia-shell (it's shell-relative
// "qs.components", not part of the globally-importable Caelestia.Config
// plugin), so this reimplements the same idea against the same real tokens:
// a NumberAnimation whose duration/curve come from TokenConfig rather than
// being hardcoded per Behavior. Real Material 3 easing curves are bezier
// splines (6 numbers = 2 control points + an end point), not CSS-style
// two-point cubic-beziers, hence the explicit Easing.BezierSpline.
NumberAnimation {
    id: root

    enum Type {
        Standard,
        DefaultSpatial
    }

    property int type: Anim.Standard

    duration: root.type === Anim.DefaultSpatial
        ? TokenConfig.appearance.animDurations.expressiveDefaultSpatial
        : TokenConfig.appearance.animDurations.normal

    easing.type: Easing.BezierSpline
    easing.bezierCurve: root.type === Anim.DefaultSpatial
        ? TokenConfig.appearance.curves.expressiveDefaultSpatial
        : TokenConfig.appearance.curves.standard
}
