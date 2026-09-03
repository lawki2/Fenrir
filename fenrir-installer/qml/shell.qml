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
    title: root.currentPage === "welcome" || root.currentPage.startsWith("tour") ? "Welcome to Fenrir" : "Install Fenrir"
    color: Colours.m3surface

    readonly property var pageOrder: [
        "welcome",
        "tour-launcher", "tour-close", "tour-float", "tour-move", "tour-workspaces",
        "locale", "keyboard", "partition", "users", "progress",
    ]
    property int pageIndex: 0
    readonly property string currentPage: pageOrder[pageIndex]
    readonly property bool showHeader: currentPage !== "welcome" && !currentPage.startsWith("tour") && currentPage !== "progress"

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
            visible: root.showHeader

            Text {
                text: "Install Fenrir"
                color: Colours.m3onSurface
                font.family: Fonts.sans
                font.pointSize: TokenConfig.appearance.fontSize.large
                font.bold: true
                Layout.fillWidth: true
            }

            NavButton {
                text: "Back"
                // Nothing before "locale" should offer Back — welcome and
                // every tour step have their own dedicated buttons instead,
                // and their pages are hidden via showHeader anyway.
                visible: root.pageIndex > root.pageOrder.indexOf("locale")
                onClicked: root.pageIndex -= 1
            }

            NavButton {
                id: nextButton
                text: root.currentPage === "users" ? "Install" : "Next"
                accent: true
                onClicked: root.advance()
            }
        }

        Loader {
            id: pageLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: `pages/${{
                welcome: "WelcomePage",
                "tour-launcher": "TourLauncher",
                "tour-close": "TourClose",
                "tour-float": "TourFloat",
                "tour-move": "TourMove",
                "tour-workspaces": "TourWorkspaces",
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

            // The Loader recreates each page on every navigation, so
            // restore Locale/Keyboard selections here or Back silently resets them.
            onLoaded: {
                if (root.currentPage === "locale") {
                    if (root.plan.timezone)
                        pageLoader.item.selectedTimezone = root.plan.timezone;
                    if (root.plan.locale)
                        pageLoader.item.selectedLocale = root.plan.locale;
                } else if (root.currentPage === "keyboard") {
                    if (root.plan.keyboard)
                        pageLoader.item.selectedLayout = root.plan.keyboard;
                }
            }

            Behavior on opacity {
                enabled: !pageLoader.resetting
                Anim {}
            }

            Behavior on scale {
                enabled: !pageLoader.resetting
                Anim {}
            }

            Connections {
                target: pageLoader.item
                ignoreUnknownSignals: true

                // WelcomePage's "skip" jumps straight past every tour step.
                // WelcomePage's "tour" and every TourStepBase's "next" both
                // just advance one step — since the tour steps are a
                // contiguous run in pageOrder immediately followed by
                // "locale", the last step's "next" naturally spills over
                // into the real installer flow with no special-casing.
                function onSkip(): void {
                    root.pageIndex = root.pageOrder.indexOf("locale");
                }

                function onTour(): void {
                    root.pageIndex += 1;
                }

                function onNext(): void {
                    root.pageIndex += 1;
                }
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
                    font.family: Fonts.sans
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

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: TokenConfig.appearance.padding.large
                        anchors.rightMargin: TokenConfig.appearance.padding.large
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: optionDelegate.modelData
                        color: optionDelegate.modelData === Picker.selected ? Colours.m3onPrimary : Colours.m3onSurface
                        font.family: Fonts.sans
                        font.pointSize: TokenConfig.appearance.fontSize.normal
                    }

                    StateLayer {
                        visible: optionDelegate.modelData !== Picker.selected
                        radius: parent.radius
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
}
