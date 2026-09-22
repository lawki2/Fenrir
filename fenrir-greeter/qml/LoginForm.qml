pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.lock.center
import qs.services

// Laid out like Caelestia's lock screen centre column (modules/lock/Center.qml)
// so signing in looks like waking the machine up, not like a separate app. Its
// Clock and ProfilePic are imported directly; the password field and status
// line are local because the originals require a Pam object, and Pam requires
// a real WlSessionLock the greeter has no way to produce.
ColumnLayout {
    id: root

    required property real screenHeight
    property var users: []
    property int userIndex: 0
    property var session: null
    property string sessionName: ""

    readonly property var user: root.users[root.userIndex] ?? null
    readonly property real centerScale: Math.min(1, root.screenHeight / 1440)
    readonly property int centerWidth: Tokens.sizes.lock.centerWidth * root.centerScale

    signal cycleSession

    // Anchored inside the window rather than driven by a parent layout, so it
    // has to state its own width.
    implicitWidth: root.centerWidth
    spacing: Tokens.spacing.largeIncreased

    function submit(password: string): void {
        if (Greetd.needsInput) {
            Greetd.respond(password);
            return;
        }
        if (root.session && root.user)
            Greetd.login(root.user.name, password, root.session.exec);
    }

    function cycleUser(): void {
        if (root.users.length > 1)
            root.userIndex = (root.userIndex + 1) % root.users.length;
    }

    Clock {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tokens.padding.large
        centerScale: root.centerScale
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter

        text: Time.format("dddd • d MMM").toUpperCase()
        color: Colours.palette.m3onSurface
        font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
    }

    ProfilePic {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tokens.spacing.extraExtraLarge * root.centerScale
        Layout.bottomMargin: Tokens.spacing.large * root.centerScale
        centerWidth: root.centerWidth
    }

    // The lock screen knows who it locked; a greeter doesn't, so this is the
    // one thing the centre column gains. Click to cycle when there's a choice.
    StyledText {
        id: userLabel

        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: Tokens.spacing.small

        text: root.user ? root.user.fullName : qsTr("No accounts found")
        color: Colours.palette.m3onSurface
        font: Tokens.font.title.small

        StateLayer {
            radius: Tokens.rounding.small
            disabled: root.users.length < 2
            onClicked: root.cycleUser()
        }
    }

    GreetInput {
        Layout.alignment: Qt.AlignHCenter
        centerScale: Math.max(0.8, root.centerScale)
        centerWidth: root.centerWidth
        onAccepted: password => root.submit(password)
    }

    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small

        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: Greetd.error || Greetd.prompt || Greetd.message
        color: Greetd.error ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tokens.spacing.large
        spacing: Tokens.spacing.small

        RowButton {
            icon: "desktop_windows"
            label: root.sessionName
            onClicked: root.cycleSession()
        }

        RowButton {
            icon: "restart_alt"
            onClicked: powerProc.exec(["systemctl", "reboot"])
        }

        RowButton {
            icon: "power_settings_new"
            onClicked: powerProc.exec(["systemctl", "poweroff"])
        }
    }

    Process {
        id: powerProc

        function exec(cmd: var): void {
            powerProc.command = cmd;
            powerProc.running = true;
        }
    }

    component RowButton: ButtonBase {
        id: button

        property string icon
        property string label

        implicitWidth: buttonRow.implicitWidth + Tokens.padding.large * 2
        implicitHeight: buttonRow.implicitHeight + Tokens.padding.medium * 2
        shapeMorph: true
        isRound: true
        type: ButtonBase.Text
        inactiveOnColour: Colours.palette.m3onSurfaceVariant

        RowLayout {
            id: buttonRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                text: button.icon
                color: button.onColour
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                visible: button.label.length > 0
                text: button.label
                color: button.onColour
                font: Tokens.font.label.small
            }
        }
    }
}
