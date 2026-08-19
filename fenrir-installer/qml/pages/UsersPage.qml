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

    readonly property bool valid: hostname.length > 0 && username.length > 0
        && password.length > 0 && password === confirmField.text

    property bool errorVisible: false

    function showError(): void {
        root.errorVisible = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: TokenConfig.appearance.spacing.normal

        Text {
            text: "Hostname and user account"
            color: Colours.m3outline
            font.family: Fonts.sans
            font.pointSize: TokenConfig.appearance.fontSize.normal
        }

        LabelledField {
            label: "Hostname"
            Layout.fillWidth: true
            StyledTextField { id: hostnameField; anchors.fill: parent; text: "fenrir"; onTextChanged: root.errorVisible = false }
        }

        LabelledField {
            label: "Full name"
            Layout.fillWidth: true
            StyledTextField { id: fullNameField; anchors.fill: parent; onTextChanged: root.errorVisible = false }
        }

        LabelledField {
            label: "Username"
            Layout.fillWidth: true
            StyledTextField { id: usernameField; anchors.fill: parent; onTextChanged: root.errorVisible = false }
        }

        LabelledField {
            label: "Password"
            Layout.fillWidth: true
            StyledTextField { id: passwordField; anchors.fill: parent; echoMode: TextInput.Password; onTextChanged: root.errorVisible = false }
        }

        LabelledField {
            label: "Confirm password"
            Layout.fillWidth: true
            StyledTextField { id: confirmField; anchors.fill: parent; echoMode: TextInput.Password; onTextChanged: root.errorVisible = false }
        }

        Text {
            visible: root.errorVisible
            text: "Fill in every field; the two passwords must match."
            color: Colours.m3error
            font.family: Fonts.sans
            font.pointSize: TokenConfig.appearance.fontSize.small
        }

        Item { Layout.fillHeight: true }
    }
}
