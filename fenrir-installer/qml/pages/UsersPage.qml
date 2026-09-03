import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import "../"

Item {
    id: root

    readonly property string hostname: hostnameField.text.trim()
    readonly property string fullName: fullNameField.text.trim() || username
    readonly property string username: usernameField.text.trim()
    readonly property string password: passwordField.text

    // Loose supersets of useradd/hostnamectl's real rules, just enough
    // to catch typos before they cost a full install run.
    readonly property bool hostnameValid: /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/.test(hostname)
    readonly property bool usernameValid: /^[a-z_][a-z0-9_-]*$/.test(username)
    readonly property bool fullNameValid: !fullName.includes(":")

    readonly property bool valid: hostname.length > 0 && hostnameValid
        && username.length > 0 && usernameValid && fullNameValid
        && password.length > 0 && password === confirmField.text

    property bool errorVisible: false

    function showError(): void {
        root.errorVisible = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: TokenConfig.appearance.spacing.large

        SectionHeading {
            Layout.topMargin: TokenConfig.appearance.spacing.large
            Layout.bottomMargin: TokenConfig.appearance.spacing.large
            icon: "person"
            text: "Hostname and user account"
        }

        StyledTextField {
            id: hostnameField
            Layout.fillWidth: true
            placeholderText: "Hostname"
            text: "fenrir"
            onTextChanged: root.errorVisible = false
        }

        StyledTextField {
            id: fullNameField
            Layout.fillWidth: true
            placeholderText: "Full name"
            onTextChanged: root.errorVisible = false
        }

        StyledTextField {
            id: usernameField
            Layout.fillWidth: true
            placeholderText: "Username"
            onTextChanged: root.errorVisible = false
        }

        StyledTextField {
            id: passwordField
            Layout.fillWidth: true
            placeholderText: "Password"
            echoMode: TextInput.Password
            onTextChanged: root.errorVisible = false
        }

        StyledTextField {
            id: confirmField
            Layout.fillWidth: true
            placeholderText: "Confirm password"
            echoMode: TextInput.Password
            onTextChanged: root.errorVisible = false
        }

        Text {
            Layout.topMargin: TokenConfig.appearance.spacing.small
            visible: root.errorVisible
            text: "Fill in every field; the two passwords must match. Hostname and username can only use letters, numbers, and hyphens (username lowercase, starting with a letter or underscore); full name can't contain a colon."
            color: Colours.m3error
            font.family: Fonts.sans
            font.pointSize: TokenConfig.appearance.fontSize.small
        }

        Item { Layout.fillHeight: true }
    }
}
