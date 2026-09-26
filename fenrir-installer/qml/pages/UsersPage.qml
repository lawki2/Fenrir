pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import qs.services
import qs.modules.nexus.common
import qs.common

// Nexus rows, so creating the account looks like editing a setting later.
InstallerPage {
    id: root

    title: qsTr("Create your account")
    subtitle: qsTr("This is the account you'll sign in with, and the name this computer uses on your network.")

    readonly property string hostname: hostnameRow.value.trim()
    readonly property string username: usernameRow.value.trim()
    readonly property string fullName: fullNameRow.value.trim() || username
    readonly property string password: passwordRow.value

    // The install clones this system's accounts (liveuser is deleted), and useradd would only refuse a clash after the wipe.
    readonly property var takenNames: passwdFile.loaded && groupFile.loaded ? root.accountNames(passwdFile.text()).concat(root.accountNames(groupFile.text())).filter(n => n !== "liveuser") : []

    readonly property string hostnameError: {
        if (root.hostname.length === 0)
            return qsTr("Required");
        return /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/.test(root.hostname) ? "" : qsTr("Letters, numbers and hyphens only");
    }
    readonly property string usernameError: {
        if (root.username.length === 0)
            return qsTr("Required");
        if (!/^[a-z_][a-z0-9_-]*$/.test(root.username))
            return qsTr("Lowercase letters, digits, - and _, starting with a letter or _");
        if (root.username.length > 32)
            return qsTr("At most 32 characters");
        if (root.takenNames.includes(root.username))
            return qsTr("%1 is already a system account or group").arg(root.username);
        return "";
    }
    readonly property string fullNameError: root.fullName.includes(":") ? qsTr("Can't contain a colon") : ""
    readonly property string passwordError: root.password.length === 0 ? qsTr("Required") : ""
    readonly property string confirmError: root.password === confirmRow.value ? "" : qsTr("Passwords don't match")

    readonly property bool valid: !root.hostnameError && !root.usernameError && !root.fullNameError && !root.passwordError && !root.confirmError

    function accountNames(text: string): var {
        return text.split("\n").filter(l => l.includes(":")).map(l => l.split(":")[0]);
    }

    // Flags the invalid rows the way Nexus does; typing in a row clears its flag.
    function showError(): void {
        hostnameRow.field.isError = root.hostnameError !== "";
        fullNameRow.field.isError = root.fullNameError !== "";
        usernameRow.field.isError = root.usernameError !== "";
        passwordRow.field.isError = root.passwordError !== "";
        confirmRow.field.isError = root.confirmError !== "";
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        FileView {
            id: passwdFile

            property bool loaded: false

            path: "/etc/passwd"
            onLoaded: loaded = true
        }

        FileView {
            id: groupFile

            property bool loaded: false

            path: "/etc/group"
            onLoaded: loaded = true
        }

        SectionHeader {
            first: true
            text: qsTr("This computer")
        }

        TextFieldRow {
            id: hostnameRow

            first: true
            last: true
            label: qsTr("Device name")
            subtext: qsTr("How this machine appears on your network")
            placeholderText: "fenrir"
            errorText: root.hostnameError
            validate: () => !root.hostnameError
            onValueEdited: value => hostnameRow.value = value
        }

        SectionHeader {
            text: qsTr("You")
        }

        TextFieldRow {
            id: fullNameRow

            first: true
            label: qsTr("Full name")
            placeholderText: "Full name"
            subtext: qsTr("Optional, shown on the login screen")
            errorText: root.fullNameError
            validate: () => !root.fullNameError
            onValueEdited: value => fullNameRow.value = value
        }

        TextFieldRow {
            id: usernameRow

            label: qsTr("Username")
            subtext: qsTr("Lowercase, also the name of your home folder")
            placeholderText: "user"
            errorText: root.usernameError
            validate: () => !root.usernameError
            onValueEdited: value => usernameRow.value = value
        }

        TextFieldRow {
            id: passwordRow

            label: qsTr("Password")
            subtext: qsTr("Also used for administrator tasks")
            placeholderText: "Password"
            field.echoMode: TextInput.Password
            errorText: root.passwordError
            onValueEdited: value => passwordRow.value = value
        }

        TextFieldRow {
            id: confirmRow

            last: true
            label: qsTr("Confirm password")
            subtext: qsTr("Type the password again")
            placeholderText: "Confirm password"
            field.echoMode: TextInput.Password
            errorText: root.confirmError
            validate: () => !root.confirmError
            onValueEdited: value => confirmRow.value = value
        }
    }
}
