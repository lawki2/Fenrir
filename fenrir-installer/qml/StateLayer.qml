import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import Caelestia.Config

// Ported from Caelestia's own components/StateLayer.qml (the real Material
// ripple + hover/press state-layer behaviour every button/switch/row in
// Caelestia's own shell uses) - not reusable as a direct cross-app import,
// since qs.* imports are shell-relative (same story as Colours.qml/
// Anim.qml: qs.services.Colours and the real Anim/Tokens types aren't
// reachable from a standalone Quickshell instance). This is a faithful
// port of the same ripple algorithm (press-point radial gradient expanding
// to fill the control, state-layer opacity for hover/press), retargeted at
// Fenrir's own already-working TokenConfig/Anim/Colours shims instead of
// Tokens/qs.services. Simplified from the real version in one way: the
// real StateLayer draws its own PathArc-based rounded-rect outline to mask
// the ripple to each corner's radius individually (top-left/right/bottom-
// left/right can differ there); every Fenrir control this is used on has a
// single uniform radius, so this clips via a plain ClippingRectangle
// (Quickshell.Widgets, globally available, the same primitive Caelestia's
// own StyledClippingRect wraps) instead of re-deriving that per-corner
// path math.
MouseArea {
    id: root

    property bool disabled
    property bool manualPressOverride
    property bool manualHoverOverride

    property real stateOpacity: containsMouse || manualHoverOverride ? 0.08 : 0

    property real pressX: width / 2
    property real pressY: height / 2
    property real circleRadius

    property alias color: base.color
    property alias radius: clipper.radius
    property alias topLeftRadius: clipper.topLeftRadius
    property alias topRightRadius: clipper.topRightRadius
    property alias bottomLeftRadius: clipper.bottomLeftRadius
    property alias bottomRightRadius: clipper.bottomRightRadius

    readonly property real endRadius: {
        const d1 = distSq(0, 0);
        const d2 = distSq(width, 0);
        const d3 = distSq(0, height);
        const d4 = distSq(width, height);
        return Math.sqrt(Math.max(d1, d2, d3, d4)) * 1.3;
    }
    property real endRadiusAtPress

    function distSq(x: real, y: real): real {
        return (pressX - x) ** 2 + (pressY - y) ** 2;
    }

    function press(x: real, y: real): void {
        pressX = x;
        pressY = y;
        fadeAnim.complete();
        circleRadius = 0;
        circle.opacity = 0.1;
        rippleAnim.restart();
        endRadiusAtPress = endRadius;
    }

    anchors.fill: parent
    enabled: !disabled
    cursorShape: disabled ? undefined : Qt.PointingHandCursor
    hoverEnabled: true

    onPressed: e => press(e.x, e.y)

    onPressedChanged: {
        if (!(pressed || manualPressOverride) && !rippleAnim.running && circle.opacity > 0)
            fadeAnim.start();
    }

    onCircleRadiusChanged: {
        if (!(pressed || manualPressOverride) && circleRadius > endRadiusAtPress * 0.99 && !fadeAnim.running)
            fadeAnim.start();
    }

    Anim {
        id: rippleAnim

        target: root
        property: "circleRadius"
        to: root.endRadius
        type: Anim.SlowEffects
        duration: TokenConfig.appearance.animDurations.expressiveSlowEffects * 2
    }

    Anim {
        id: fadeAnim

        target: circle
        property: "opacity"
        to: 0
        type: Anim.SlowEffects
    }

    Rectangle {
        id: base

        anchors.fill: parent
        radius: clipper.radius
        topLeftRadius: clipper.topLeftRadius
        topRightRadius: clipper.topRightRadius
        bottomLeftRadius: clipper.bottomLeftRadius
        bottomRightRadius: clipper.bottomRightRadius
        opacity: root.stateOpacity
        color: Colours.palette.m3onSurface

        Behavior on opacity {
            Anim {}
        }
    }

    ClippingRectangle {
        id: clipper

        anchors.fill: parent
        color: "transparent"

        Shape {
            id: circle

            anchors.fill: parent
            opacity: 0
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: root.pressX
                    centerY: root.pressY
                    centerRadius: root.circleRadius
                    focalX: centerX
                    focalY: centerY

                    GradientStop {
                        position: 0
                        color: Qt.alpha(base.color, 1)
                    }
                    GradientStop {
                        position: Math.max(0.01, Math.min(0.99, 1 - 0.2 * root.endRadius / root.circleRadius))
                        color: Qt.alpha(base.color, 1)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(base.color, Math.max(0, Math.min(1, (root.circleRadius / root.endRadius - 0.9) / 0.1)))
                    }
                }

                startX: 0
                startY: 0

                PathLine {
                    x: root.width
                    y: 0
                }
                PathLine {
                    x: root.width
                    y: root.height
                }
                PathLine {
                    x: 0
                    y: root.height
                }
                PathLine {
                    x: 0
                    y: 0
                }
            }
        }
    }

    Behavior on stateOpacity {
        Anim {}
    }
}
