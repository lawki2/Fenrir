import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import "../"

// Was a raw scrolling monospace log of cli.py's stdout - replaced with a
// discrete named-step list (backend.py already emits a fixed, ordered
// sequence of human-readable progress messages, see the stepTriggers
// list below, one per real phase of the install) plus a collapsible
// "Show details" log underneath for anyone who wants to see the raw
// output, auto-expanded on failure. Parallel string arrays (labels +
// trigger prefixes), matched by index via a plain loop - deliberately
// avoids storing functions in a list<var>, unconfirmed safe in this QML
// engine (see fenrir_installer_status.md's spread-syntax gotcha for why
// this codebase treats "unconfirmed JS feature" with real caution).
Item {
    id: root

    property string statusText: "Installing Fenrir…"
    property bool failed: false
    property bool detailsVisible: false

    readonly property list<string> stepLabels: [
        "Partitioning the disk",
        "Installing packages",
        "Copying configuration",
        "Configuring the system",
        "Installing the bootloader",
        "Finishing up"
    ]
    readonly property list<string> stepTriggers: [
        "Clearing any leftover mounts",
        "Installing packages",
        "Copying Caelestia configuration",
        "Setting timezone",
        "Writing kernel command line",
        "Enabling "
    ]

    property int currentStep: 0

    function checkStep(line: string): void {
        for (let i = root.currentStep; i < root.stepTriggers.length; i++) {
            if (line.startsWith(root.stepTriggers[i])) {
                root.currentStep = i;
                break;
            }
        }
    }

    function start(plan): void {
        installProc.command = ["python3", "/usr/lib/fenrir-installer/cli.py", "install", JSON.stringify(plan)];
        installProc.running = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: TokenConfig.appearance.spacing.large

        Text {
            Layout.topMargin: TokenConfig.appearance.spacing.large
            text: root.statusText
            color: root.failed ? Colours.m3error : Colours.m3onSurface
            font.family: Fonts.sans
            font.pointSize: TokenConfig.appearance.fontSize.large
        }

        ColumnLayout {
            spacing: TokenConfig.appearance.spacing.normal

            Repeater {
                model: root.stepLabels

                RowLayout {
                    id: stepRow

                    required property string modelData
                    required property int index

                    readonly property bool done: !root.failed && stepRow.index < root.currentStep
                    readonly property bool active: !root.failed && stepRow.index === root.currentStep

                    Layout.fillWidth: true
                    spacing: TokenConfig.appearance.spacing.normal

                    Icon {
                        text: stepRow.done ? "check_circle" : (stepRow.active ? "radio_button_checked" : "radio_button_unchecked")
                        color: stepRow.done ? Colours.m3primary : (stepRow.active ? Colours.m3primary : Colours.m3outline)
                        font.pixelSize: 20

                        opacity: stepRow.active ? pulseAnim.value : 1

                        SequentialAnimation {
                            id: pulseAnim
                            property real value: 1
                            running: stepRow.active
                            loops: Animation.Infinite

                            NumberAnimation { target: pulseAnim; property: "value"; from: 1; to: 0.35; duration: 700 }
                            NumberAnimation { target: pulseAnim; property: "value"; from: 0.35; to: 1; duration: 700 }
                        }
                    }

                    Text {
                        text: stepRow.modelData
                        color: stepRow.done || stepRow.active ? Colours.m3onSurface : Colours.m3outline
                        font.family: Fonts.sans
                        font.pointSize: TokenConfig.appearance.fontSize.normal
                    }
                }
            }
        }

        RowLayout {
            spacing: TokenConfig.appearance.spacing.small

            StateLayer {
                implicitWidth: detailsRow.implicitWidth + TokenConfig.appearance.padding.small * 2
                implicitHeight: detailsRow.implicitHeight + TokenConfig.appearance.padding.small * 2
                radius: TokenConfig.appearance.rounding.small
                onClicked: root.detailsVisible = !root.detailsVisible

                RowLayout {
                    id: detailsRow
                    anchors.centerIn: parent
                    spacing: TokenConfig.appearance.spacing.small

                    Icon {
                        text: root.detailsVisible ? "expand_less" : "expand_more"
                        font.pixelSize: 16
                        color: Colours.m3outline
                    }

                    Text {
                        text: root.detailsVisible ? "Hide details" : "Show details"
                        color: Colours.m3outline
                        font.family: Fonts.sans
                        font.pointSize: TokenConfig.appearance.fontSize.small
                    }
                }
            }
        }

        Rectangle {
            visible: root.detailsVisible
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: TokenConfig.appearance.rounding.small
            color: Colours.m3surfaceContainerLow

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: TokenConfig.appearance.padding.large
                contentWidth: width
                contentHeight: logText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    id: logText
                    width: flick.width
                    wrapMode: Text.Wrap
                    color: Colours.m3onSurface
                    font.family: Fonts.mono
                    font.pointSize: TokenConfig.appearance.fontSize.small
                }

                onContentHeightChanged: flick.contentY = Math.max(0, contentHeight - height)
            }
        }
    }

    Process {
        id: installProc
        stdout: SplitParser {
            onRead: data => {
                logText.text += data + "\n";
                root.checkStep(data);
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.currentStep = root.stepLabels.length;
                root.statusText = "Install complete. You can reboot now.";
            } else {
                root.failed = true;
                root.detailsVisible = true;
                root.statusText = "Install failed — see the details below.";
            }
        }
    }
}
