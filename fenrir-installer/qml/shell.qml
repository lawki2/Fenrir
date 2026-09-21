//@ pragma UseQApplication
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
// Quickshell's scanner only registers qs.* modules reached by a static import
// from the root config, so a Loader-loaded page cannot pull in a new one.
// These two are imported here on the pages' behalf, not used directly.
import qs.common
import qs.modules.nexus.common

// Shaped like Nexus's own window (modules/nexus/WindowFactory.qml): a real
// FloatingWindow with surfaceFormat.opaque false, which is what actually lets
// the transparent surface show through - the original installer painted an
// opaque colour and never set it, which is why it never looked translucent.
// Sized from the screen by ratio rather than a fixed pixel size, so it scales
// the way the settings window does.
FloatingWindow {
    id: root

    color: Colours.tPalette.m3surface
    surfaceFormat.opaque: false

    implicitWidth: Math.round(implicitHeight * contentItem.Tokens.sizes.nexus.ratio)
    implicitHeight: Math.round(screen.height * contentItem.Tokens.sizes.nexus.heightMult)

    minimumSize.width: contentItem.Tokens.sizes.nexus.minWidth
    minimumSize.height: contentItem.Tokens.sizes.nexus.minHeight

    // Nexus scopes both of these per screen; without them Config/Tokens warn
    // when read from a singleton and fall back to the wrong screen's values.
    contentItem.Config.screen: screen.name
    contentItem.Tokens.screen: screen.name

    title: qsTr("Install Fenrir")

    readonly property var pageOrder: [
        "welcome",
        "locale", "keyboard", "partition", "users", "progress",
    ]
    property int pageIndex: 0
    property string pickerFilter: ""

    readonly property var pickerOptions: root.pickerFilter.length > 0 ? Picker.options.filter(o => String(o).toLowerCase().includes(root.pickerFilter)) : Picker.options
    readonly property string currentPage: pageOrder[pageIndex]
    readonly property bool showHeader: currentPage !== "welcome" && currentPage !== "progress"

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
        anchors.margins: Tokens.padding.extraLarge
        spacing: TokenConfig.appearance.spacing.medium

        Loader {
            id: pageLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: `pages/${{
                welcome: "WelcomePage",
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

                function onNext(): void {
                    root.pageIndex += 1;
                }
            }
        }

        // Each page carries its own title now, so the chrome is just the two
        // buttons, sitting where a wizard expects them.
        RowLayout {
            Layout.fillWidth: true
            visible: root.showHeader
            spacing: Tokens.spacing.small

            ButtonBase {
                id: backButton

                visible: root.pageIndex > root.pageOrder.indexOf("locale")
                shapeMorph: true
                isRound: true
                type: ButtonBase.Text
                inactiveOnColour: Colours.palette.m3onSurfaceVariant
                implicitWidth: backLabel.implicitWidth + Tokens.padding.large * 2
                implicitHeight: backLabel.implicitHeight + Tokens.padding.medium * 2
                onClicked: root.pageIndex -= 1

                StyledText {
                    id: backLabel

                    anchors.centerIn: parent
                    text: qsTr("Back")
                    color: backButton.onColour
                    font: Tokens.font.body.small
                }
            }

            Item {
                Layout.fillWidth: true
            }

            ButtonBase {
                id: nextButton

                shapeMorph: true
                isRound: true
                inactiveColour: Colours.palette.m3primary
                inactiveOnColour: Colours.palette.m3onPrimary
                implicitWidth: nextLabel.implicitWidth + Tokens.padding.extraLarge * 2
                implicitHeight: nextLabel.implicitHeight + Tokens.padding.medium * 2
                onClicked: root.advance()

                StyledText {
                    id: nextLabel

                    anchors.centerIn: parent
                    text: root.currentPage === "users" ? qsTr("Install") : qsTr("Next")
                    color: nextButton.onColour
                    font: Tokens.font.body.small
                }
            }
        }
    }

    Rectangle {
        id: pickerOverlay
        anchors.fill: parent
        z: 100
        color: Colours.tPalette.m3surface

        // Unlike the page Loader above, this overlay is a persistent item
        // (never destroyed/recreated), so it gets the full show *and* hide
        // fade+scale — closer to Caelestia's launcher/dashboard drawers
        // (Behavior on offsetScale in modules/launcher/Wrapper.qml), just
        // without their directional slide-offset since this is a full
        // in-place content swap, not an edge-anchored drawer.
        onVisibleChanged: if (!visible) {
            root.pickerFilter = "";
            pickerSearch.value = "";
        }

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
            spacing: TokenConfig.appearance.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                ButtonBase {
                    id: pickerBack

                    shapeMorph: true
                    isRound: true
                    type: ButtonBase.Text
                    inactiveOnColour: Colours.palette.m3onSurfaceVariant
                    implicitWidth: pickerBackLabel.implicitWidth + Tokens.padding.large * 2
                    implicitHeight: pickerBackLabel.implicitHeight + Tokens.padding.medium * 2
                    onClicked: Picker.close()

                    StyledText {
                        id: pickerBackLabel

                        anchors.centerIn: parent
                        text: qsTr("Back")
                        color: pickerBack.onColour
                        font: Tokens.font.body.small
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Picker.title
                    font: Tokens.font.title.large
                    elide: Text.ElideRight
                }
            }

            // Hundreds of timezones and locales are unusable without this.
            TextFieldRow {
                id: pickerSearch

                first: true
                last: true
                label: qsTr("Search")
                placeholderText: Picker.title
                onValueEdited: value => root.pickerFilter = value.trim().toLowerCase()
            }

            ItemList {
                id: pickerList

                Layout.fillWidth: true
                Layout.fillHeight: true
                first: true
                last: true
                showList: root.pickerOptions.length > 0
                placeholderIcon: "search_off"
                placeholderText: qsTr("Nothing matches")

                model: ScriptModel {
                    values: root.pickerOptions
                }

                delegate: Item {
                    id: optionRow

                    required property var modelData
                    required property int index

                    readonly property bool selected: optionRow.modelData === Picker.selected

                    anchors.left: pickerList.list.contentItem.left
                    anchors.right: pickerList.list.contentItem.right
                    implicitHeight: optionLabel.implicitHeight + Tokens.padding.medium * 2

                    StateLayer {
                        onClicked: Picker.pick(optionRow.modelData)
                    }

                    StyledText {
                        id: optionLabel

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.padding.largeIncreased
                        anchors.rightMargin: Tokens.padding.largeIncreased
                        text: optionRow.modelData
                        color: optionRow.selected ? Colours.palette.m3primary : Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
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
