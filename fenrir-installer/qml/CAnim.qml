import QtQuick
import Caelestia.Config

// Fenrir's equivalent of Caelestia's own components/CAnim.qml - a
// ColorAnimation counterpart to Anim.qml, since NumberAnimation (what
// Anim.qml extends) cannot animate color-typed properties at all. Colour
// transitions in Caelestia consistently use the plain "standard" curve,
// not the spatial/expressive ones, matching Anim.Standard's own duration.
ColorAnimation {
    duration: TokenConfig.appearance.animDurations.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: TokenConfig.appearance.curves.standard
}
