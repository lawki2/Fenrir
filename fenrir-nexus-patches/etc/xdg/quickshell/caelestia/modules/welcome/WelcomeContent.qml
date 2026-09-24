pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

Item {
    id: root

    // Wording and icons only; what each extra installs comes from fenrir-pkg.
    readonly property var extraInfo: ({
            gaming: {
                title: qsTr("Gaming"),
                text: qsTr("Steam, Lutris, Heroic, MangoHud, Gamescope and the 32-bit libraries games need"),
                icon: "sports_esports"
            },
            flatpak: {
                title: qsTr("Flatpak apps"),
                text: qsTr("Install apps from Flathub that aren't in the Arch repositories"),
                icon: "apps"
            },
            printers: {
                title: qsTr("Older printer drivers"),
                text: qsTr("For printers that need a driver, mostly models from before about 2015"),
                icon: "print"
            },
            codecs: {
                title: qsTr("Extra media codecs"),
                text: qsTr("Play more audio and video formats in media apps"),
                icon: "movie"
            },
            devtools: {
                title: qsTr("Developer tools"),
                text: qsTr("Compilers and build tools, needed to build packages from the AUR"),
                icon: "code"
            },
            graphics: {
                title: qsTr("Graphics drivers"),
                text: qsTr("Detects your graphics card and installs the best driver for it; older NVIDIA cards need this"),
                icon: "developer_board"
            }
        })

    readonly property list<var> tourSteps: [
        {
            title: qsTr("The launcher"),
            body: qsTr("Tap the Super key on its own, without holding anything else. Search for an app, like \"firefox\" or \"files\", and press Enter to open it. Give it a try before moving on.")
        },
        {
            title: qsTr("Workspaces"),
            body: qsTr("Workspaces are extra desktops for grouping windows. Press Super and a number from 1 to 9 to jump to one. Windows don't close when you switch; they wait on their workspace until you come back.")
        },
        {
            title: qsTr("Floating windows"),
            body: qsTr("Windows normally tile, filling the screen without overlapping. Press Super + Alt + Space to lift one out of the tiling so it floats, and again to put it back.")
        },
        {
            title: qsTr("Moving and resizing"),
            body: qsTr("Hold Super and drag with the left mouse button to move a window, or with the right mouse button to resize it from wherever your cursor is.")
        },
        {
            title: qsTr("Closing a window"),
            body: qsTr("Press Super + Q to close the window you're in. There's no X to hunt for; every window closes the same way.")
        }
    ]

    property bool touring: false
    property int tourStep: 0

    function statusOf(name: string): string {
        const job = `install ${name}`;
        if (PkgJob.isRunning(job))
            return PkgJob.log.trim().split("\n").pop() || qsTr("Waiting for your password…");
        if (PkgJob.pending === job && PkgJob.startError)
            return PkgJob.startError;
        if (PkgJob.job === job && PkgJob.state !== "running" && PkgJob.state !== "")
            return PkgJob.state === "0" ? qsTr("Done") : qsTr("Didn't finish: %1").arg(PkgJob.log.trim().split("\n").pop());
        if (Welcome.installed.includes(name))
            return qsTr("Installed");
        return root.extraInfo[name]?.text ?? "";
    }

    NexusState {
        id: st

        onSubPageClosed: root.touring = false
    }

    PageBase {
        id: hub

        anchors.fill: parent
        visible: !root.touring
        nState: st
        title: qsTr("Welcome to Fenrir")

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: hub.cappedWidth
            spacing: Tokens.spacing.extraSmall / 2

            StyledText {
                Layout.fillWidth: true
                Layout.bottomMargin: Tokens.spacing.large
                text: qsTr("Fenrir runs on keyboard shortcuts and tiling windows. The tour shows the few you need; the extras below are optional and can be added now or any time from Welcome in the app launcher.")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
                wrapMode: Text.WordWrap
            }

            RowButton {
                first: true
                last: true
                icon: "school"
                text: qsTr("Take the tour")
                subtext: qsTr("Five short steps for getting around")
                trailingIcon: "chevron_right"
                onClicked: {
                    root.tourStep = 0;
                    root.touring = true;
                    st.openSubPage(1);
                }
            }

            SectionHeader {
                text: qsTr("Extras")
            }

            Repeater {
                model: Welcome.extraNames

                RowButton {
                    required property string modelData
                    required property int index

                    readonly property bool isInstalled: Welcome.installed.includes(modelData)

                    first: index === 0
                    last: index === Welcome.extraNames.length - 1
                    icon: root.extraInfo[modelData]?.icon ?? "extension"
                    text: root.extraInfo[modelData]?.title ?? modelData
                    subtext: root.statusOf(modelData)
                    trailingIcon: isInstalled ? "check" : PkgJob.isRunning(`install ${modelData}`) ? "hourglass_empty" : "download"
                    disabled: isInstalled || PkgJob.running
                    onClicked: Welcome.install(modelData)
                }
            }

            SectionHeader {
                text: qsTr("More")
            }

            RowButton {
                first: true
                icon: "settings"
                text: qsTr("Open Settings")
                onClicked: WindowFactory.create(null, {})
            }

            RowButton {
                icon: "open_in_new"
                text: qsTr("Fenrir on GitHub")
                onClicked: Qt.openUrlExternally("https://github.com/lawki2/Fenrir")
            }

            RowButton {
                last: true
                icon: "bug_report"
                text: qsTr("Report a problem")
                onClicked: Qt.openUrlExternally("https://github.com/lawki2/Fenrir/issues")
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.large
                first: true
                last: true
                text: qsTr("Show at startup")
                subtext: qsTr("Welcome is always in the app launcher")
                checked: Welcome.showAtStartup
                onToggled: Welcome.setShowAtStartup(checked)
            }
        }
    }

    PageBase {
        id: tour

        anchors.fill: parent
        visible: root.touring
        nState: st
        isSubPage: true
        title: qsTr("Tour · %1 of %2").arg(root.tourStep + 1).arg(root.tourSteps.length)

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: tour.cappedWidth
            spacing: Tokens.spacing.large

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.large
                text: root.tourSteps[root.tourStep].title
                font: Tokens.font.headline.medium
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                text: root.tourSteps[root.tourStep].body
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.large
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.topMargin: Tokens.spacing.large
                spacing: Tokens.spacing.small

                IconTextButton {
                    visible: root.tourStep > 0
                    icon: "arrow_back"
                    text: qsTr("Back")
                    type: IconTextButton.Tonal
                    isRound: true
                    horizontalPadding: Tokens.padding.extraLarge
                    verticalPadding: Tokens.padding.medium
                    onClicked: root.tourStep--
                }

                IconTextButton {
                    readonly property bool lastStep: root.tourStep === root.tourSteps.length - 1

                    icon: lastStep ? "check" : "arrow_forward"
                    text: lastStep ? qsTr("Done") : qsTr("Next")
                    type: IconTextButton.Filled
                    isRound: true
                    horizontalPadding: Tokens.padding.extraLarge
                    verticalPadding: Tokens.padding.medium
                    onClicked: {
                        if (lastStep)
                            st.closeSubPage();
                        else
                            root.tourStep++;
                    }
                }
            }
        }
    }
}
