pragma ComponentBehavior: Bound

import QtQuick
import M3Shapes
import Caelestia.Config
import qs.components
import qs.services

// Stands in for modules/lock/center/PasswordInput, which can't be imported:
// it reads lock.pam throughout, and Pam requires a real WlSessionLock. Same
// pill shape and one dot per character, without reimplementing InputField's
// 236 lines of per-character enter/exit animation.
StyledRect {
    id: root

    required property real centerScale
    required property int centerWidth

    readonly property string buffer: input.text
    readonly property bool busy: Greetd.busy && !Greetd.needsInput

    signal accepted(password: string)

    function submit(): void {
        if (root.buffer.length === 0)
            return;
        const password = root.buffer;
        input.clear();
        root.accepted(password);
    }

    implicitWidth: root.centerWidth
    implicitHeight: Math.round(Tokens.font.body.medium.pointSize * 4 * root.centerScale)
    radius: implicitHeight / 2
    color: Colours.tPalette.m3surfaceContainerHigh

    // The window takes keyboard focus exclusively, so the field has to claim
    // it or there is nowhere for typing to land.
    Component.onCompleted: input.forceActiveFocus()

    TextInput {
        id: input

        anchors.fill: parent
        echoMode: TextInput.Password
        // The dots below are the visible readout; this only captures keys.
        color: "transparent"
        enabled: !root.busy
        focus: true
        onAccepted: root.submit()
    }

    MaterialIcon {
        id: lockIcon

        anchors.left: parent.left
        anchors.leftMargin: Tokens.padding.large
        anchors.verticalCenter: parent.verticalCenter

        text: Greetd.error ? "lock_open" : "lock"
        color: Greetd.error ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
        fontStyle: Tokens.font.icon.small
    }

    Row {
        id: dots

        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        Repeater {
            model: Math.min(root.buffer.length, 24)

            MaterialShape {
                required property int index

                implicitSize: Tokens.font.body.medium.pointSize * root.centerScale
                shape: MaterialShape.Circle
                color: Colours.palette.m3primary

                scale: 0
                Component.onCompleted: scale = 1

                Behavior on scale {
                    Anim {}
                }
            }
        }
    }

    StyledText {
        anchors.centerIn: parent
        visible: root.buffer.length === 0
        text: root.busy ? qsTr("Signing in…") : Greetd.needsInput ? Greetd.prompt : qsTr("Enter password")
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    MaterialShape {
        id: enter

        anchors.right: parent.right
        anchors.rightMargin: Tokens.padding.medium
        anchors.verticalCenter: parent.verticalCenter

        implicitSize: root.implicitHeight - Tokens.padding.medium * 2
        shape: root.buffer ? MaterialShape.Arrow : MaterialShape.Circle
        color: root.buffer ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
        scale: !root.buffer ? 1 : mouse.pressed ? 0.6 : mouse.containsMouse ? 0.8 : 0.7

        Behavior on scale {
            Anim {}
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.buffer ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.submit()
        }
    }
}
