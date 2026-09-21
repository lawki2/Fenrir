pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

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
    property string pendingLog: ""

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
        spacing: Tokens.spacing.large

        StyledText {
            Layout.fillWidth: true
            text: root.statusText
            color: root.failed ? Colours.palette.m3error : Colours.palette.m3onSurface
            font: Tokens.font.title.large
            wrapMode: Text.WordWrap
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            Repeater {
                model: root.stepLabels

                RowLayout {
                    id: stepRow

                    required property string modelData
                    required property int index

                    readonly property bool done: !root.failed && stepRow.index < root.currentStep
                    readonly property bool active: !root.failed && stepRow.index === root.currentStep

                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: stepRow.done ? "check_circle" : stepRow.active ? "radio_button_checked" : "radio_button_unchecked"
                        color: stepRow.done || stepRow.active ? Colours.palette.m3primary : Colours.palette.m3outline
                        fontStyle: Tokens.font.icon.small
                        opacity: stepRow.active ? pulseAnim.value : 1

                        SequentialAnimation {
                            id: pulseAnim

                            property real value: 1

                            running: stepRow.active
                            loops: Animation.Infinite

                            NumberAnimation {
                                target: pulseAnim
                                property: "value"
                                from: 1
                                to: 0.35
                                duration: Tokens.anim.durations.large
                            }

                            NumberAnimation {
                                target: pulseAnim
                                property: "value"
                                from: 0.35
                                to: 1
                                duration: Tokens.anim.durations.large
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: stepRow.modelData
                        color: stepRow.done || stepRow.active ? Colours.palette.m3onSurface : Colours.palette.m3outline
                        font: Tokens.font.body.medium
                    }
                }
            }
        }

        // Layout.alignment rather than anchors: this sits inside a layout,
        // and anchoring a layout-managed item is undefined behaviour.
        RowButton {
            Layout.fillWidth: true
            first: true
            last: true
            icon: root.detailsVisible ? "expand_less" : "expand_more"
            text: root.detailsVisible ? qsTr("Hide details") : qsTr("Show details")
            onClicked: root.detailsVisible = !root.detailsVisible
        }

        ConnectedRect {
            visible: root.detailsVisible
            Layout.fillWidth: true
            Layout.fillHeight: true
            first: true
            last: true

            Flickable {
                id: flick

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                contentWidth: width
                contentHeight: logText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                StyledText {
                    id: logText

                    width: flick.width
                    wrapMode: Text.Wrap
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.mono.small
                }

                onContentHeightChanged: flick.contentY = Math.max(0, contentHeight - height)
            }
        }
    }

    Process {
        id: installProc
        stdout: SplitParser {
            onRead: data => {
                root.pendingLog += data + "\n";
                root.checkStep(data);
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (root.pendingLog.length > 0) {
                logText.text += root.pendingLog;
                root.pendingLog = "";
            }
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
