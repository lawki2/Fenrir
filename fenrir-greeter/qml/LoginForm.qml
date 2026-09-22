pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    property var users: []
    property var session: null
    property string sessionName: ""

    signal cycleSession

    spacing: Tokens.spacing.large

    // greetd asks for the password itself rather than us sending it blind, so
    // the field doubles as the answer box for anything else PAM wants (a
    // second factor, an expired-password prompt) once needsInput is set.
    function submit(): void {
        if (Greetd.needsInput) {
            Greetd.respond(passwordField.text);
            passwordField.text = "";
            return;
        }
        if (!root.session || userField.text.length === 0)
            return;
        Greetd.login(userField.text, passwordField.text, root.session.exec);
        passwordField.text = "";
    }

    Timer {
        id: clock

        property string time: ""
        property string date: ""

        running: true
        repeat: true
        interval: 1000
        triggeredOnStart: true
        onTriggered: {
            const now = new Date();
            clock.time = Qt.formatDateTime(now, "HH:mm");
            clock.date = Qt.formatDateTime(now, "dddd d MMMM");
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: clock.time
        font: Tokens.font.headline.large
        color: Colours.palette.m3onSurface
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: Tokens.spacing.large
        text: clock.date
        font: Tokens.font.body.large
        color: Colours.palette.m3onSurfaceVariant
    }

    StyledTextField {
        id: userField

        Layout.fillWidth: true
        type: StyledTextField.Filled
        placeholderText: qsTr("Username")
        leadingIcon: "person"
        text: Greetd.username
        enabled: !Greetd.busy
        onAccepted: passwordField.forceActiveFocus()
    }

    StyledTextField {
        id: passwordField

        Layout.fillWidth: true
        type: StyledTextField.Filled
        placeholderText: Greetd.needsInput ? Greetd.prompt : qsTr("Password")
        leadingIcon: "password"
        echoMode: Greetd.needsInput && !Greetd.secret ? TextInput.Normal : TextInput.Password
        isError: Greetd.error.length > 0
        errorText: Greetd.error
        supportingText: Greetd.message
        focus: true
        onAccepted: root.submit()
    }

    ButtonBase {
        id: signIn

        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        // ButtonBase marks both implicit sizes required; Layout.fillWidth
        // overrides the width but it still has to be set.
        implicitWidth: signInLabel.implicitWidth + Tokens.padding.extraLarge * 2
        implicitHeight: signInLabel.implicitHeight + Tokens.padding.large * 2
        shapeMorph: true
        isRound: true
        inactiveColour: Colours.palette.m3primary
        inactiveOnColour: Colours.palette.m3onPrimary
        disabled: Greetd.busy && !Greetd.needsInput
        onClicked: root.submit()

        StyledText {
            id: signInLabel

            anchors.centerIn: parent
            text: Greetd.busy && !Greetd.needsInput ? qsTr("Signing in…") : qsTr("Sign in")
            color: signIn.onColour
            font: Tokens.font.body.large
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.large
        spacing: Tokens.spacing.small

        ButtonBase {
            id: sessionButton

            implicitWidth: sessionRow.implicitWidth + Tokens.padding.large * 2
            implicitHeight: sessionRow.implicitHeight + Tokens.padding.medium * 2
            shapeMorph: true
            isRound: true
            type: ButtonBase.Text
            inactiveOnColour: Colours.palette.m3onSurfaceVariant
            onClicked: root.cycleSession()

            RowLayout {
                id: sessionRow

                anchors.centerIn: parent
                spacing: Tokens.spacing.extraSmall

                MaterialIcon {
                    text: "desktop_windows"
                    color: sessionButton.onColour
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    text: root.sessionName
                    color: sessionButton.onColour
                    font: Tokens.font.label.small
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Repeater {
            model: [
                {
                    icon: "restart_alt",
                    action: "reboot"
                },
                {
                    icon: "power_settings_new",
                    action: "poweroff"
                }
            ]

            ButtonBase {
                id: powerButton

                required property var modelData

                implicitWidth: powerIcon.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: powerIcon.implicitHeight + Tokens.padding.medium * 2
                shapeMorph: true
                isRound: true
                type: ButtonBase.Text
                inactiveOnColour: Colours.palette.m3onSurfaceVariant
                onClicked: {
                    powerProc.command = ["systemctl", powerButton.modelData.action];
                    powerProc.running = true;
                }

                MaterialIcon {
                    id: powerIcon

                    anchors.centerIn: parent
                    text: powerButton.modelData.icon
                    color: powerButton.onColour
                    fontStyle: Tokens.font.icon.small
                }
            }
        }
    }

    Process {
        id: powerProc
    }
}
