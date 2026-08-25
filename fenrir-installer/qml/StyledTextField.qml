pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtQuick.Templates
import Caelestia.Config

// Ported from Caelestia's own components/controls/TextFieldBase.qml +
// StyledTextField.qml's "Outlined" variant, merged into one file since
// fenrir-installer only ever needs the outlined style (no Filled variant,
// no leading/trailing icons - those depend on MaterialIcon's Tokens.font.
// icon fluent builder, unavailable standalone - and no per-field error/
// validate state, since fenrir-installer's pages already validate at the
// page level). Every Tokens.*/Colours.* reference from the real files is
// retargeted at fenrir-installer's own already-working TokenConfig/
// Colours/Anim/CAnim shims: qs.* imports and most of Tokens.* (spacing,
// font, Colours entirely) are confirmed undefined in a standalone
// Quickshell instance (tested empirically this session, not assumed) -
// only Tokens.rounding partially resolves, and even then to a generic
// fallback, not the live theme value, so TokenConfig is still the correct
// choice everywhere it covers. This is a real Shape/PathArc-drawn
// floating-label outline (the label shrinks and floats into a gap cut
// into the border on focus/text) - a previous, simpler attempt at this
// exact component hit an unresolved "renders solid black" bug (see
// fenrir_design_guidelines.md's "Text input" section); this version
// sidesteps that by following the real component's structure exactly
// rather than a hand-rolled approximation.
TextField {
    id: root

    property int radius: TokenConfig.appearance.rounding.small
    readonly property int clampedRadius: Math.min(horizontalPadding, Math.min(width, height) / 2, radius)
    readonly property int horizontalPadding: TokenConfig.appearance.padding.large

    property int smallFontSize: TokenConfig.appearance.fontSize.small
    readonly property real smallFontScale: smallFontSize / font.pointSize

    implicitWidth: contentWidth + leftPadding + rightPadding
    implicitHeight: contentHeight + topPadding + bottomPadding

    leftPadding: horizontalPadding
    rightPadding: horizontalPadding
    topPadding: TokenConfig.appearance.padding.large
    bottomPadding: TokenConfig.appearance.padding.large

    color: Colours.m3onSurface
    placeholderTextColor: Colours.m3outline
    selectionColor: Qt.alpha(Colours.m3primary, 0.4)
    selectedTextColor: color

    font.family: Fonts.sans
    font.pointSize: TokenConfig.appearance.fontSize.normal
    renderType: echoMode === TextField.Password ? TextField.QtRendering : TextField.NativeRendering
    cursorVisible: !readOnly
    verticalAlignment: TextInput.AlignVCenter

    cursorDelegate: Item {}

    onPressed: {
        if (!stateLayer.disabled)
            stateLayer.press(stateLayer.mouseX, stateLayer.mouseY);
    }

    Behavior on color {
        CAnim {}
    }

    Behavior on selectionColor {
        CAnim {}
    }

    background: StateLayer {
        id: stateLayer

        topLeftRadius: root.clampedRadius
        topRightRadius: root.clampedRadius
        bottomLeftRadius: root.clampedRadius
        bottomRightRadius: root.clampedRadius

        cursorShape: Qt.IBeamCursor
        disabled: root.activeFocus
        manualPressOverride: tapHandler.pressed
        onClicked: root.focus = true

        Shape {
            id: bg

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            asynchronous: true

            ShapePath {
                id: path

                readonly property real outlineGap: placeholder.width * root.smallFontScale + TokenConfig.appearance.spacing.small
                property real outlineGapScale: root.activeFocus || root.text ? 1 : 0
                readonly property real inset: strokeWidth / 2

                strokeWidth: root.activeFocus ? 2 : 1
                strokeColor: root.activeFocus ? Colours.m3primary : Colours.m3outline
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                startX: path.inset + root.horizontalPadding - root.clampedRadius + path.outlineGap * (1 - path.outlineGapScale) / 2 + path.outlineGap * path.outlineGapScale

                PathLine {
                    x: bg.width - path.inset - root.clampedRadius
                }
                PathArc {
                    x: bg.width - path.inset
                    y: path.inset + root.clampedRadius
                    radiusX: root.clampedRadius
                    radiusY: root.clampedRadius
                }
                PathLine {
                    x: bg.width - path.inset
                    y: bg.height - path.inset - root.clampedRadius
                }
                PathArc {
                    x: bg.width - path.inset - root.clampedRadius
                    y: bg.height - path.inset
                    radiusX: root.clampedRadius
                    radiusY: root.clampedRadius
                }
                PathLine {
                    x: path.inset + root.clampedRadius
                    y: bg.height - path.inset
                }
                PathArc {
                    x: path.inset
                    y: bg.height - path.inset - root.clampedRadius
                    radiusX: root.clampedRadius
                    radiusY: root.clampedRadius
                }
                PathLine {
                    x: path.inset
                    y: path.inset + root.clampedRadius
                }
                PathArc {
                    x: path.inset + root.clampedRadius
                    y: path.inset
                    radiusX: root.clampedRadius
                    radiusY: root.clampedRadius
                }
                PathLine {
                    x: path.inset + root.horizontalPadding - root.clampedRadius + path.outlineGap * (1 - path.outlineGapScale) / 2
                }

                Behavior on outlineGapScale {
                    Anim {}
                }

                Behavior on strokeWidth {
                    Anim {}
                }

                Behavior on strokeColor {
                    CAnim {}
                }
            }
        }
    }

    Item {
        id: contentWrapper

        anchors.fill: parent

        Text {
            id: placeholder

            font.family: root.font.family
            font.pointSize: root.font.pointSize

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: root.leftPadding
            renderType: Text.QtRendering

            text: root.placeholderText
            color: root.activeFocus ? Colours.m3primary : root.text ? Colours.m3outline : root.placeholderTextColor

            states: State {
                name: "small"
                when: root.activeFocus || root.text

                PropertyChanges {
                    placeholder.scale: root.smallFontScale
                    placeholder.anchors.leftMargin: -(1 - root.smallFontScale) * placeholder.width / 2 + root.horizontalPadding
                }
                AnchorChanges {
                    target: placeholder
                    anchors.verticalCenter: contentWrapper.top
                }
            }

            transitions: Transition {
                Anim {
                    properties: "scale,leftMargin"
                }
                AnchorAnimation {
                    duration: TokenConfig.appearance.animDurations.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: TokenConfig.appearance.curves.standard
                }
            }
        }
    }

    TapHandler {
        id: tapHandler
    }
}
