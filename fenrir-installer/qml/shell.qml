//@ pragma UseQApplication
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Caelestia.Config

FloatingWindow {
    id: root

    implicitWidth: 780
    implicitHeight: 560
    title: "Install Fenrir"
    color: Colours.m3surface

    readonly property var pageOrder: ["locale", "keyboard", "partition", "users", "progress"]
    property int pageIndex: 0
    readonly property string currentPage: pageOrder[pageIndex]

    // Collected as the user moves forward through the pages, sent to
    // cli.py's install command as JSON once they hit Install.
    property var plan: ({
        disk: "",
        esp_mib: 4096,
        timezone: "",
        locale: "",
        keyboard: "",
        hostname: "",
        full_name: "",
        username: "",
        password: ""
    })

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: TokenConfig.appearance.spacing.large
        spacing: TokenConfig.appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Install Fenrir"
                color: Colours.m3onSurface
                font.family: "Rubik"
                font.pointSize: TokenConfig.appearance.fontSize.large
                font.bold: true
                Layout.fillWidth: true
            }

            NavButton {
                text: "Back"
                visible: root.pageIndex > 0 && root.currentPage !== "progress"
                onClicked: root.pageIndex -= 1
            }

            NavButton {
                id: nextButton
                text: root.currentPage === "users" ? "Install" : "Next"
                visible: root.currentPage !== "progress"
                accent: true
                onClicked: root.advance()
            }
        }

        Loader {
            id: pageLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: `pages/${{
                locale: "LocalePage",
                keyboard: "KeyboardPage",
                partition: "PartitionPage",
                users: "UsersPage",
                progress: "ProgressPage",
            }[root.currentPage]}.qml`

            // A plain Loader destroys the outgoing page synchronously on
            // source change (no true crossfade possible without a
            // StackView), so this only animates the incoming page: jump
            // instantly back to the "just appeared" state (Behavior
            // disabled while resetting), then animate up to full
            // opacity/scale, the same fade+scale-in Caelestia's own
            // StackView content uses (Anim.Standard, driven by
            // StackView.onActivating in TrayMenu.qml's SubMenu).
            property bool resetting: false
            opacity: 1
            scale: 1

            onSourceChanged: {
                resetting = true;
                opacity = 0;
                scale = 0.96;
                resetting = false;
                opacity = 1;
                scale = 1;
            }

            Behavior on opacity {
                enabled: !pageLoader.resetting
                Anim {}
            }

            Behavior on scale {
                enabled: !pageLoader.resetting
                Anim {}
            }
        }
    }

    Rectangle {
        id: pickerOverlay
        anchors.fill: parent
        z: 100
        color: Colours.m3surface

        // Unlike the page Loader above, this overlay is a persistent item
        // (never destroyed/recreated), so it gets the full show *and* hide
        // fade+scale — closer to Caelestia's launcher/dashboard drawers
        // (Behavior on offsetScale in modules/launcher/Wrapper.qml), just
        // without their directional slide-offset since this is a full
        // in-place content swap, not an edge-anchored drawer.
        opacity: Picker.visible ? 1 : 0
        scale: Picker.visible ? 1 : 0.96
        visible: opacity > 0

        Behavior on opacity {
            Anim {}
        }

        Behavior on scale {
            Anim {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: TokenConfig.appearance.spacing.large
            spacing: TokenConfig.appearance.spacing.normal

            RowLayout {
                Layout.fillWidth: true

                NavButton {
                    text: "Back"
                    onClicked: Picker.close()
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Picker.title
                    color: Colours.m3onSurface
                    font.family: "Rubik"
                    font.pointSize: TokenConfig.appearance.fontSize.large
                    font.bold: true
                }

                Item { Layout.preferredWidth: 68 }
            }

            ListView {
                id: pickerList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: TokenConfig.appearance.spacing.small
                model: Picker.options
                ScrollBar.vertical: ScrollBar {}

                delegate: Rectangle {
                    id: optionDelegate
                    required property string modelData

                    width: pickerList.width
                    height: 48
                    radius: TokenConfig.appearance.rounding.small
                    color: optionDelegate.modelData === Picker.selected ? Colours.m3primary : Colours.m3surfaceContainerHigh

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Colours.m3onSurface
                        visible: optionDelegate.modelData !== Picker.selected
                        opacity: optionMouse.pressed ? 0.1 : optionMouse.containsMouse ? 0.08 : 0
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: TokenConfig.appearance.padding.large
                        anchors.rightMargin: TokenConfig.appearance.padding.large
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: optionDelegate.modelData
                        color: optionDelegate.modelData === Picker.selected ? Colours.m3onPrimary : Colours.m3onSurface
                        font.family: "Rubik"
                        font.pointSize: TokenConfig.appearance.fontSize.normal
                    }

                    MouseArea {
                        id: optionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Picker.pick(optionDelegate.modelData)
                    }
                }
            }
        }
    }

    function advance(): void {
        const page = pageLoader.item;
        if (root.currentPage === "partition" && !page.confirmed) {
            page.showError();
            return;
        }
        if (root.currentPage === "users" && !page.valid) {
            page.showError();
            return;
        }

        if (root.currentPage === "locale") {
            root.plan.timezone = page.selectedTimezone;
            root.plan.locale = page.selectedLocale;
        } else if (root.currentPage === "keyboard") {
            root.plan.keyboard = page.selectedLayout;
        } else if (root.currentPage === "partition") {
            root.plan.disk = page.selectedDisk;
        } else if (root.currentPage === "users") {
            root.plan.hostname = page.hostname;
            root.plan.full_name = page.fullName;
            root.plan.username = page.username;
            root.plan.password = page.password;
            root.pageIndex += 1;
            pageLoader.item.start(root.plan);
            return;
        }

        root.pageIndex += 1;
    }

    component NavButton: Rectangle {
        id: btn

        property string text
        property bool accent: false
        signal clicked()

        Layout.preferredHeight: 36
        Layout.preferredWidth: label.implicitWidth + TokenConfig.appearance.padding.large * 2
        radius: TokenConfig.appearance.rounding.small
        color: accent ? Colours.m3primary : "transparent"

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Colours.m3onSurface
            opacity: mouse.pressed ? 0.1 : mouse.containsMouse ? 0.08 : 0
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: btn.text
            color: btn.accent ? Colours.m3onPrimary : Colours.m3onSurface
            font.family: "Rubik"
            font.pointSize: TokenConfig.appearance.fontSize.normal
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: btn.clicked()
        }
    }
}
