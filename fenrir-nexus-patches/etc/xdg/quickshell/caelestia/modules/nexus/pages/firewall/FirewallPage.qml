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

// ufw itself requires root for every subcommand, including plain `status`
// (confirmed: ufw's own _do_checks() runs unconditionally) - reading
// /etc/ufw/ufw.conf's ENABLED= line directly instead avoids prompting for
// auth just to open this page (the file is world-readable, 644 root:root).
// The rule list has no such shortcut (ufw has no machine-readable output
// mode, and /etc/ufw/user.rules is raw iptables-restore syntax not worth
// hand-parsing/writing when ufw's own CLI already does that safely), so
// listing/adding/removing rules goes through `pkexec ufw status numbered`/
// `allow`/`deny`/`delete` - polkit's default org.freedesktop.policykit.exec
// action already prompts wheel-group users for their own password, no
// extra polkit/sudoers rule needed (confirmed empirically).
PageBase {
    id: root

    title: qsTr("Firewall")

    property bool ufwEnabled: false
    property bool rulesLoading: true
    property bool rulesLoadFailed: false
    property var rules: []
    property string newRuleSpec: ""
    // Shared across toggle/add/delete since the busy-guards below mean at
    // most one of those can ever be in flight at a time - a cancelled
    // pkexec prompt or an invalid rule spec used to just silently refresh
    // back to the unchanged state with nothing telling the user their
    // click didn't do what they expected.
    property string actionError: ""

    function refreshStatus(): void {
        statusProc.running = true;
    }

    function refreshRules(): void {
        root.rulesLoading = true;
        root.rulesLoadFailed = false;
        rulesProc.running = true;
    }

    function setEnabled(on: bool): void {
        if (toggleProc.running)
            return;
        toggleProc.command = ["pkexec", "ufw", "--force", on ? "enable" : "disable"];
        toggleProc.running = true;
    }

    function addRule(spec: string, allow: bool): void {
        if (ruleActionProc.running)
            return;
        const trimmed = spec.trim();
        if (!trimmed.length)
            return;
        root.newRuleSpec = "";
        ruleActionProc.command = ["pkexec", "ufw", "--force", allow ? "allow" : "deny", trimmed];
        ruleActionProc.running = true;
    }

    function deleteRule(number: int): void {
        if (ruleActionProc.running)
            return;
        ruleActionProc.command = ["pkexec", "ufw", "--force", "delete", String(number)];
        ruleActionProc.running = true;
    }

    // `ufw status numbered` has no machine-readable mode - each rule line
    // looks like "[ 1] 22/tcp                     ALLOW IN    Anywhere",
    // padded with runs of spaces between columns, so split on 2+ spaces
    // rather than a single one. Best-effort display parsing: a line this
    // doesn't match (the "Status:" line, the "To ... Action ... From"
    // header, blank lines) is simply skipped, never a wrong rule.
    function parseRules(text: string): void {
        const result = [];
        for (const line of text.split("\n")) {
            const m = line.match(/^\[\s*(\d+)\]\s+(.*)$/);
            if (!m)
                continue;
            const cols = m[2].trim().split(/\s{2,}/);
            // A future ufw version reflowing its column widths (e.g.
            // single-space padding for a long port range) could otherwise
            // silently produce a wrong to/action/from split instead of
            // just dropping the row - requiring the expected column count
            // and a real ufw action keyword in the action slot turns that
            // into "skip this line" instead of "display wrong data".
            if (cols.length < 3 || !/^(ALLOW|DENY|REJECT|LIMIT)/.test(cols[1]))
                continue;
            result.push({
                number: parseInt(m[1], 10),
                to: cols[0],
                action: cols[1],
                from: cols[2]
            });
        }
        root.rules = result;
    }

    Component.onCompleted: {
        root.refreshStatus();
        root.refreshRules();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // PageBase's default property is a single Item (its scrollable
        // page content), not a generic child list - a Process placed as
        // a direct PageBase child fails with "Cannot assign object of
        // type Process to property of type QQuickItem*" (confirmed via
        // serial.log). ColumnLayout, being a plain Item underneath, has
        // no such restriction, so these live nested in here instead -
        // same fix as KeybindsPage.qml's FileView already being nested
        // in its own ColumnLayout rather than a direct PageBase child.
        Process {
            id: statusProc
            command: ["cat", "/etc/ufw/ufw.conf"]
            stdout: StdioCollector {
                onStreamFinished: root.ufwEnabled = text.includes("ENABLED=yes")
            }
        }

        Process {
            id: toggleProc
            onExited: exitCode => {
                root.actionError = exitCode === 0 ? "" : qsTr("Couldn't change the firewall state — the password prompt may have been cancelled.");
                root.refreshStatus();
            }
        }

        Process {
            id: rulesProc
            command: ["pkexec", "ufw", "status", "numbered"]
            stdout: StdioCollector {
                id: rulesCollector
            }
            onExited: exitCode => {
                root.rulesLoading = false;
                if (exitCode === 0) {
                    root.rulesLoadFailed = false;
                    root.parseRules(rulesCollector.text);
                } else {
                    root.rulesLoadFailed = true;
                    root.rules = [];
                }
            }
        }

        Process {
            id: ruleActionProc
            onExited: exitCode => {
                root.actionError = exitCode === 0 ? "" : qsTr("Couldn't apply that — check the port/service format, or the password prompt may have been cancelled.");
                root.refreshRules();
            }
        }

        SectionHeader {
            first: true
            text: qsTr("Firewall")
        }

        ToggleRow {
            first: true
            last: true
            disabled: toggleProc.running
            text: qsTr("Enable firewall")
            subtext: qsTr("Blocks unsolicited incoming connections; outgoing traffic is unaffected")
            checked: root.ufwEnabled
            onToggled: root.setEnabled(checked)
        }

        StyledText {
            visible: root.actionError.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            wrapMode: Text.WordWrap
            text: root.actionError
            color: Colours.palette.m3error
            font: Tokens.font.body.small
        }

        SectionHeader {
            text: qsTr("Default policy")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            wrapMode: Text.WordWrap
            text: qsTr("Deny incoming, allow outgoing — the standard ufw policy, enabled by default on install.")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }

        SectionHeader {
            text: qsTr("Rules")
        }

        ItemList {
            id: ruleList

            showList: root.rules.length > 0
            first: true
            last: true
            placeholderIcon: root.rulesLoadFailed ? "error" : "rule"
            placeholderText: root.rulesLoading ? qsTr("Loading…") : root.rulesLoadFailed ? qsTr("Couldn't load rules — try reopening this page") : qsTr("No rules yet")

            model: ScriptModel {
                values: root.rules
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
                            text: ruleRow.modelData.to
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: ruleRow.modelData.from
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    StyledText {
                        text: ruleRow.modelData.action
                        color: ruleRow.modelData.action.startsWith("ALLOW") ? Colours.palette.m3primary : Colours.palette.m3error
                        font: Tokens.font.label.small
                    }

                    StateLayer {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: height / 2
                        disabled: ruleActionProc.running
                        onClicked: root.deleteRule(ruleRow.modelData.number)

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

        SectionHeader {
            text: qsTr("Add rule")
        }

        TextFieldRow {
            first: true
            last: true
            label: qsTr("Port / service")
            subtext: qsTr("e.g. \"22/tcp\", \"80\", \"1000:2000/udp\"")
            placeholderText: qsTr("22/tcp")
            value: root.newRuleSpec
            onValueEdited: value => root.newRuleSpec = value
        }

        ButtonRow {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            ActionButton {
                disabled: ruleActionProc.running
                text: qsTr("Allow")
                bg: Colours.palette.m3primaryContainer
                fg: Colours.palette.m3onPrimaryContainer
                onClicked: root.addRule(root.newRuleSpec, true)
            }

            ActionButton {
                disabled: ruleActionProc.running
                text: qsTr("Deny")
                bg: Colours.palette.m3errorContainer
                fg: Colours.palette.m3onErrorContainer
                onClicked: root.addRule(root.newRuleSpec, false)
            }
        }
    }

    component ActionButton: ButtonBase {
        id: btn

        property alias text: label.text
        property color bg
        property color fg

        fillWidth: true
        shapeMorph: true
        isRound: true
        inactiveColour: btn.bg
        inactiveOnColour: btn.fg
        implicitHeight: label.implicitHeight + Tokens.padding.medium * 2
        implicitWidth: label.implicitWidth + Tokens.padding.large * 2

        StyledText {
            id: label

            anchors.centerIn: parent
            color: btn.onColour
            font: Tokens.font.body.small
        }
    }
}
