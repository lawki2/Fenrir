pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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

    // Loose supersets of useradd/hostnamectl's real rules, just enough
    // to catch typos before they cost a full install run.
    readonly property bool hostnameValid: /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/.test(hostname)
    readonly property bool usernameValid: /^[a-z_][a-z0-9_-]*$/.test(username)
    readonly property bool fullNameValid: !fullName.includes(":")
    readonly property bool passwordsMatch: password.length > 0 && password === confirmRow.value

    readonly property bool valid: hostname.length > 0 && hostnameValid && username.length > 0 && usernameValid && fullNameValid && passwordsMatch

    // Set when the user tries to advance, so empty fields aren't flagged
    // red before they've had a chance to type anything.
    property bool errorVisible: false

    function showError(): void {
        root.errorVisible = true;
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

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
            errorText: root.errorVisible && !root.hostnameValid ? qsTr("Letters, numbers and hyphens only") : ""
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
            errorText: root.errorVisible && !root.fullNameValid ? qsTr("Can't contain a colon") : ""
            onValueEdited: value => fullNameRow.value = value
        }

        TextFieldRow {
            id: usernameRow

            label: qsTr("Username")
            placeholderText: "user"
            errorText: root.errorVisible && !root.usernameValid ? qsTr("Lowercase, starting with a letter or underscore") : ""
            onValueEdited: value => usernameRow.value = value
        }

        TextFieldRow {
            id: passwordRow

            label: qsTr("Password")
            placeholderText: "Password"
            field.echoMode: TextInput.Password
            errorText: root.errorVisible && root.password.length === 0 ? qsTr("Required") : ""
            onValueEdited: value => passwordRow.value = value
        }

        TextFieldRow {
            id: confirmRow

            last: true
            label: qsTr("Confirm password")
            placeholderText: "Confirm password"
            field.echoMode: TextInput.Password
            errorText: root.errorVisible && !root.passwordsMatch ? qsTr("Passwords don't match") : ""
            onValueEdited: value => confirmRow.value = value
        }
    }
}
