import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

// Keyboard-layout and date/time sections, kept out of the upstream Language &
// region copy so that file stays a small diff.
ColumnLayout {
    id: root

    required property NexusState nState

    property string timezone: ""
    property bool ntpEnabled: false
    property string timeError: ""

    readonly property string layouts: String(HyprVars.value("kbLayout") ?? "us")
    readonly property list<string> layoutList: root.layouts.split(",").filter(l => l.length > 0)

    function removeLayout(code: string): void {
        const current = root.layoutList.filter(l => l !== code);
        // Hyprland needs at least one layout.
        if (current.length)
            HyprVars.set({
                kbLayout: current.join(",")
            });
    }

    Layout.fillWidth: true
    spacing: Tokens.spacing.extraSmall / 2

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall / 2

        // Picks up a time zone chosen in the picker without waiting for the page to be rebuilt.
        Connections {
            target: root.nState

            function onSubPageClosed(): void {
                timeStateProc.running = true;
            }
        }

        // timedatectl talks to systemd-timedated over D-Bus, which has its
        // own polkit actions - so it prompts on its own, no pkexec needed.
        Process {
            id: timeStateProc

            running: true
            command: ["timedatectl", "show", "--property=Timezone", "--property=NTP"]
            stdout: StdioCollector {
                onStreamFinished: {
                    for (const line of text.trim().split("\n")) {
                        const eq = line.indexOf("=");
                        if (eq < 0)
                            continue;
                        const key = line.substring(0, eq);
                        const value = line.substring(eq + 1);
                        if (key === "Timezone") {
                            root.timezone = value;
                        } else if (key === "NTP") {
                            root.ntpEnabled = value === "yes";
                            ntpToggle.checked = root.ntpEnabled;
                        }
                    }
                }
            }
        }

        Process {
            id: timeActionProc

            onExited: exitCode => {
                root.timeError = exitCode === 0 ? "" : qsTr("Couldn't apply that — the password prompt may have been cancelled, or the value was rejected.");
                timeStateProc.running = true;
            }
        }

        SectionHeader {
            first: true
            text: qsTr("Keyboard layouts")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.spacing.small
            wrapMode: Text.WordWrap
            text: qsTr("Cycle between these with the shortcut set on the Keybinds page.")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }

        Repeater {
            id: layoutRepeater

            model: root.layoutList

            ConnectedRect {
                id: layoutItem

                required property var modelData
                required property int index

                Layout.fillWidth: true
                first: index === 0
                last: false
                implicitHeight: layoutRow.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: layoutRow

                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        text: FenrirNames.layoutLabel(layoutItem.modelData)
                        font: Tokens.font.body.small
                    }

                    StyledText {
                        visible: layoutItem.index === 0
                        text: qsTr("Primary")
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                    }

                    StyledRect {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: height / 2
                        color: "transparent"
                        // Last layout can't be removed; Hyprland needs one.
                        opacity: layoutRepeater.count > 1 ? 1 : 0.4

                        StateLayer {
                            disabled: layoutRepeater.count < 2
                            onClicked: root.removeLayout(layoutItem.modelData)
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "close"
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }
        }

        NavRow {
            last: true
            icon: "add"
            text: qsTr("Add layout")
            subtext: qsTr("Choose from all available layouts")
            onClicked: root.nState.openSubPage(1)
        }

        SectionHeader {
            text: qsTr("Date & time")
        }

        // checked is assigned, never bound: toggling it would break the binding.
        ToggleRow {
            id: ntpToggle

            first: true
            text: qsTr("Set time automatically")
            subtext: qsTr("Sync the clock over the network")
            onToggled: {
                timeActionProc.command = ["timedatectl", "set-ntp", checked ? "true" : "false"];
                timeActionProc.running = true;
            }
        }

        NavRow {
            icon: "schedule"
            text: qsTr("Time zone")
            subtext: FenrirNames.timezoneLabel(root.timezone)
            onClicked: root.nState.openSubPage(2)
        }

        TextFieldRow {
            last: true
            label: qsTr("Set date & time")
            subtext: root.ntpEnabled ? qsTr("Turn off automatic time to set this manually") : qsTr("Format: YYYY-MM-DD HH:MM:SS")
            enabled: !root.ntpEnabled
            placeholderText: "2026-01-31 13:45:00"
            onEditingFinished: value => {
                const trimmed = value.trim();
                if (trimmed.length > 0) {
                    timeActionProc.command = ["timedatectl", "set-time", trimmed];
                    timeActionProc.running = true;
                }
            }
        }

        StyledText {
            visible: root.timeError.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            wrapMode: Text.WordWrap
            text: root.timeError
            color: Colours.palette.m3error
            font: Tokens.font.body.small
        }
    }
}
