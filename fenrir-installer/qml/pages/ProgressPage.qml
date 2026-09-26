pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

Item {
    id: root

    property string statusText: qsTr("Installing Fenrir…")
    property string detailText: ""
    property bool finished: false
    property bool failed: false
    property bool detailsVisible: false
    property bool closeRefused: false
    readonly property bool running: installProc.running

    property string errorMessage: ""
    // Kept for errors that only name the command that failed.
    property var recentLines: []

    readonly property list<string> stepLabels: [
        "Partitioning the disk",
        "Installing packages",
        "Setting up package sources",
        "Configuring the system",
        "Installing the bootloader",
        "Finishing up"
    ]
    readonly property list<string> stepTriggers: [
        "Clearing any leftover mounts",
        "Installing packages",
        "Initializing the pacman keyring",
        "Setting timezone",
        "Writing kernel command line",
        "Enabling NetworkManager"
    ]

    property int currentStep: 0
    property string pendingLog: ""

    // A long install emits far more than anyone scrolls back through, and
    // Text relayout cost grows with the string, so keep the tail only.
    readonly property int maxLogChars: 60000

    function flushLog(): void {
        if (root.pendingLog.length === 0)
            return;
        let merged = logText.text + root.pendingLog;
        root.pendingLog = "";
        if (merged.length > root.maxLogChars) {
            const cut = merged.indexOf("\n", merged.length - root.maxLogChars);
            merged = merged.slice(cut < 0 ? merged.length - root.maxLogChars : cut + 1);
        }
        logText.text = merged;
    }

    function remember(line: string): void {
        if (line.trim().length === 0 || /^\s*[\d,]+\s+\d+%/.test(line) || line.startsWith("INSTALL_"))
            return;
        root.recentLines = root.recentLines.concat([line]).slice(-5);
    }

    function warnClose(): void {
        root.closeRefused = true;
    }

    function checkStep(line: string): void {
        for (let i = root.currentStep; i < root.stepTriggers.length; i++) {
            if (line.startsWith(root.stepTriggers[i])) {
                root.currentStep = i;
                break;
            }
        }
    }

    function start(plan): void {
        // In the environment, not argv: argv is readable by every user via ps.
        installProc.environment = { FENRIR_INSTALL_PLAN: JSON.stringify(plan) };
        installProc.command = ["python3", "/usr/lib/fenrir-installer/cli.py", "install"];
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

        StyledText {
            Layout.fillWidth: true
            visible: root.detailText.length > 0
            text: root.detailText
            color: Colours.palette.m3onSurfaceVariant
            font: root.failed ? Tokens.font.mono.small : Tokens.font.body.medium
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.closeRefused && root.running
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "warning"
                color: Colours.palette.m3error
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("The installer stays open until it finishes. Closing it now would leave the disk half-written.")
                color: Colours.palette.m3error
                font: Tokens.font.body.medium
                wrapMode: Text.WordWrap
            }
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

                    readonly property bool done: stepRow.index < root.currentStep
                    readonly property bool active: !root.failed && stepRow.index === root.currentStep
                    readonly property bool broke: root.failed && stepRow.index === root.currentStep

                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: stepRow.done ? "check_circle" : stepRow.broke ? "error" : stepRow.active ? "radio_button_checked" : "radio_button_unchecked"
                        color: stepRow.broke ? Colours.palette.m3error : stepRow.done || stepRow.active ? Colours.palette.m3primary : Colours.palette.m3outline
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
                        color: stepRow.done || stepRow.active || stepRow.broke ? Colours.palette.m3onSurface : Colours.palette.m3outline
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

        Item {
            Layout.fillHeight: true
            visible: !root.detailsVisible
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.finished || root.failed
            spacing: Tokens.spacing.small

            Item {
                Layout.fillWidth: true
            }

            TextButton {
                type: TextButton.Text
                isRound: true
                shapeMorph: true
                inactiveOnColour: Colours.palette.m3onSurfaceVariant
                horizontalPadding: Tokens.padding.large
                verticalPadding: Tokens.padding.medium
                text: qsTr("Close")
                onClicked: Qt.quit()
            }

            // Root via pkexec, so systemctl needs no prompt.
            IconTextButton {
                visible: root.finished
                isRound: true
                shapeMorph: true
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                icon: "restart_alt"
                text: qsTr("Restart now")
                onClicked: Quickshell.execDetached(["systemctl", "reboot"])
            }
        }
    }

    // Appending every line straight to logText.text forces a full text
    // relayout each time; buffer and flush a few times a second instead.
    Timer {
        interval: 150
        repeat: true
        running: installProc.running
        onTriggered: root.flushLog()
    }

    Process {
        id: installProc
        stdout: SplitParser {
            onRead: data => {
                root.pendingLog += data + "\n";
                if (data.startsWith("INSTALL_ERROR: "))
                    root.errorMessage = data.slice("INSTALL_ERROR: ".length);
                root.remember(data);
                root.checkStep(data);
            }
        }
        // A crash before cli.py can report (a traceback) only reaches stderr.
        stderr: SplitParser {
            onRead: data => {
                root.pendingLog += data + "\n";
                root.remember(data);
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.flushLog();
            if (exitCode === 0) {
                root.finished = true;
                root.currentStep = root.stepLabels.length;
                root.statusText = qsTr("Fenrir is installed");
                root.detailText = qsTr("Restart to start using it. Remove the install USB once the screen goes dark.");
                return;
            }
            root.failed = true;
            root.detailsVisible = true;
            const message = root.errorMessage || qsTr("the installer stopped unexpectedly (exit code %1)").arg(exitCode);
            root.statusText = qsTr("Install failed: %1").arg(message);
            if (!root.errorMessage || /exited with status \d+$|non-zero exit status/.test(message))
                root.detailText = root.recentLines.join("\n");
        }
    }
}
