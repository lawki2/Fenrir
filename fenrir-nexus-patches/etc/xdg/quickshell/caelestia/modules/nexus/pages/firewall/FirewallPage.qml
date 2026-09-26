pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// firewall-cmd talks D-Bus as the user; polkit gates it (see configure_polkit()).
// Writes are --permanent, then --reload to apply them live.
PageBase {
    id: root

    title: qsTr("Firewall")

    readonly property string zone: "public"

    property bool running: false
    // Nothing about the service's state is shown until firewall-cmd has answered once.
    property bool statusKnown: false
    property bool loading: true
    property string loadError: ""
    property string actionError: ""
    property var services: []
    property var ports: []
    property string newPortSpec: ""

    // No "default policy" row: blocking incoming is the zone target, i.e. the toggle.
    readonly property var allRows: [
        ...root.services.map(s => ({
                    kind: "service",
                    label: s,
                    sublabel: qsTr("Service"),
                    action: "ALLOW",
                    value: s
                })),
        ...root.ports.map(p => ({
                    kind: "port",
                    label: p,
                    sublabel: qsTr("Port"),
                    action: "ALLOW",
                    value: p
                }))
    ]

    // --list-all gets services and ports in one D-Bus call.
    function refresh(): void {
        root.loading = true;
        root.loadError = "";
        infoProc.running = true;
    }

    function parseZoneInfo(text: string): void {
        const fields = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^\s+(services|ports|target):\s*(.*)$/);
            if (m)
                fields[m[1]] = m[2].trim();
        }
        const split = v => (v ?? "").split(/\s+/).filter(s => s.length);
        root.services = split(fields.services);
        root.ports = split(fields.ports);
    }

    // Every change chains into a reload, or it wouldn't apply until reboot. args
    // is `var` because spreading a QML list<string> through the proxy is unreliable.
    function applyChange(args: var): void {
        if (changeProc.running || reloadProc.running)
            return;
        root.actionError = "";
        changeProc.command = ["firewall-cmd", "--permanent", `--zone=${root.zone}`, ...args];
        changeProc.running = true;
    }

    // A literal enable/disable of the service, not a zone swap. systemctl
    // reaches PID 1 over D-Bus, so polkit gates it - no pkexec needed.
    function setEnabled(on: bool): void {
        if (toggleProc.running)
            return;
        root.actionError = "";
        toggleProc.command = ["systemctl", on ? "enable" : "disable", "--now", "firewalld"];
        toggleProc.running = true;
    }

    function addPort(spec: string): void {
        const trimmed = spec.trim();
        if (!trimmed.length)
            return;
        root.newPortSpec = "";
        root.applyChange([`--add-port=${trimmed}`]);
    }

    function removeRow(row: var): void {
        if (row.kind === "service")
            root.applyChange([`--remove-service=${row.value}`]);
        else if (row.kind === "port")
            root.applyChange([`--remove-port=${row.value}`]);
    }

    Component.onCompleted: root.refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Non-Items live here: PageBase's default property takes a single Item. Logic
        // hangs off onExited, since streamFinished and exited arrive in either order.
        Process {
            id: toggleProc

            property string err: ""

            stderr: StdioCollector {
                onStreamFinished: toggleProc.err = text.trim()
            }
            onExited: exitCode => {
                if (exitCode !== 0)
                    root.actionError = toggleProc.err || qsTr("Couldn't start or stop the firewall (exit %1).").arg(exitCode);
                root.refresh();
            }
        }

        Process {
            id: infoProc

            property string out: ""

            command: ["firewall-cmd", "--permanent", `--zone=${root.zone}`, "--list-all"]
            stdout: StdioCollector {
                onStreamFinished: infoProc.out = text
            }
            stderr: StdioCollector {
                onStreamFinished: if (text.trim().length)
                    root.loadError = text.trim()
            }
            // --permanent still goes through the daemon, so a non-zero exit
            // here is also how we know firewalld isn't running.
            onExited: exitCode => {
                root.loading = false;
                root.running = exitCode === 0;
                root.statusKnown = true;
                enableToggle.checked = root.running;
                if (exitCode === 0) {
                    root.parseZoneInfo(infoProc.out);
                } else {
                    root.services = [];
                    root.ports = [];
                }
            }
        }

        Process {
            id: changeProc

            property string err: ""

            stderr: StdioCollector {
                onStreamFinished: changeProc.err = text.trim()
            }
            onExited: exitCode => {
                if (exitCode === 0) {
                    reloadProc.running = true;
                } else {
                    root.actionError = changeProc.err || qsTr("That change was rejected (exit %1).").arg(exitCode);
                    root.refresh();
                }
            }
        }

        Process {
            id: reloadProc

            property string err: ""

            command: ["firewall-cmd", "--reload"]
            stderr: StdioCollector {
                onStreamFinished: reloadProc.err = text.trim()
            }
            onExited: exitCode => {
                if (exitCode !== 0)
                    root.actionError = reloadProc.err || qsTr("Couldn't reload the firewall (exit %1).").arg(exitCode);
                root.refresh();
            }
        }

        SectionHeader {
            first: true
            text: qsTr("Firewall")
        }

        // checked is assigned imperatively, never bound - the first toggle
        // would destroy a binding for good.
        ToggleRow {
            id: enableToggle

            first: true
            last: true
            indicator.visible: root.statusKnown
            disabled: !root.statusKnown || toggleProc.running || changeProc.running || reloadProc.running
            text: qsTr("Enable firewall")
            subtext: qsTr("Blocks unsolicited incoming connections; outgoing traffic is unaffected")
            onToggled: root.setEnabled(checked)
        }

        StyledText {
            visible: root.statusKnown && !root.running
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.topMargin: Tokens.spacing.small
            wrapMode: Text.WordWrap
            text: qsTr("The firewalld service isn't running — start it with “systemctl enable --now firewalld”.")
            color: Colours.palette.m3error
            font: Tokens.font.body.small
        }

        StyledText {
            visible: root.actionError.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.topMargin: Tokens.spacing.small
            wrapMode: Text.WordWrap
            text: root.actionError
            color: Colours.palette.m3error
            font: Tokens.font.body.small
        }

        SectionHeader {
            text: qsTr("Rules")
        }

        StyledText {
            visible: root.loadError.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.spacing.small
            wrapMode: Text.WordWrap
            text: root.loadError
            color: Colours.palette.m3error
            font: Tokens.font.body.small
        }

        ItemList {
            id: ruleList

            showList: root.allRows.length > 0
            first: true
            last: true
            placeholderIcon: "rule"
            placeholderText: root.loading ? qsTr("Loading…") : qsTr("No rules yet")

            model: ScriptModel {
                values: root.allRows
            }

            delegate: Item {
                id: ruleRow

                required property var modelData
                required property int index

                anchors.left: ruleList.list.contentItem.left
                anchors.right: ruleList.list.contentItem.right
                implicitHeight: ruleRowLayout.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: ruleRowLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: ruleRow.modelData.label
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: ruleRow.modelData.sublabel
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    StyledText {
                        text: ruleRow.modelData.action
                        color: ruleRow.modelData.action === "ALLOW" ? Colours.palette.m3primary : Colours.palette.m3error
                        font: Tokens.font.label.small
                    }

                    // Default policies are changed with the toggle above, so they get no delete button.
                    // StateLayer fills its parent, so this Item keeps it to the button's size.
                    Item {
                        visible: ruleRow.modelData.kind !== "default"
                        implicitWidth: 32
                        implicitHeight: 32

                        StateLayer {
                            radius: height / 2
                            disabled: changeProc.running || reloadProc.running
                            onClicked: root.removeRow(ruleRow.modelData)

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "delete"
                                color: Colours.palette.m3error
                                fontStyle: Tokens.font.icon.small
                            }
                        }
                    }
                }
            }
        }

        SectionHeader {
            text: qsTr("Allow a port")
        }

        TextFieldRow {
            first: true
            last: true
            label: qsTr("Port / protocol")
            subtext: qsTr("e.g. \"22/tcp\", \"1000-2000/udp\"")
            placeholderText: qsTr("22/tcp")
            value: root.newPortSpec
            onValueEdited: value => root.newPortSpec = value
        }

        ButtonRow {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            ButtonBase {
                id: allowBtn

                fillWidth: true
                shapeMorph: true
                isRound: true
                disabled: changeProc.running || reloadProc.running
                inactiveColour: Colours.palette.m3primaryContainer
                inactiveOnColour: Colours.palette.m3onPrimaryContainer
                implicitHeight: allowLabel.implicitHeight + Tokens.padding.medium * 2
                implicitWidth: allowLabel.implicitWidth + Tokens.padding.large * 2
                onClicked: root.addPort(root.newPortSpec)

                StyledText {
                    id: allowLabel

                    anchors.centerIn: parent
                    text: qsTr("Allow")
                    color: allowBtn.onColour
                    font: Tokens.font.body.small
                }
            }
        }
    }
}
