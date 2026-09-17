pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    // xkb only accepts its own fixed grp: options, so this is a closed list
    // rather than a key capture like the other keybinds.
    readonly property list<var> options: [
        {
            value: "",
            label: qsTr("None")
        },
        {
            value: "grp:ctrl_space_toggle",
            label: qsTr("Ctrl + Space")
        },
        {
            value: "grp:alt_shift_toggle",
            label: qsTr("Alt + Shift")
        },
        {
            value: "grp:ctrl_shift_toggle",
            label: qsTr("Ctrl + Shift")
        },
        {
            value: "grp:ctrl_alt_toggle",
            label: qsTr("Ctrl + Alt")
        },
        {
            value: "grp:win_space_toggle",
            label: qsTr("Super + Space")
        },
        {
            value: "grp:caps_toggle",
            label: qsTr("Caps Lock")
        }
    ]

    title: qsTr("Switch layout")
    isSubPage: true

    function parseHyprVars(text: string): var {
        const result = {};
        const re = /(\w+)\s*=\s*"((?:[^"\\]|\\.)*)"/g;
        let match;
        while ((match = re.exec(text)) !== null)
            result[match[1]] = match[2];
        return result;
    }

    function serializeHyprVars(data: var): string {
        const keys = Object.keys(data);
        if (!keys.length)
            return "return {}\n";
        const lines = keys.map(k => `    ${k} = "${data[k]}",`);
        return `return {\n${lines.join("\n")}\n}\n`;
    }

    function choose(value: string): void {
        const data = root.parseHyprVars(hyprVarsFile.text());
        data["kbOptions"] = value;
        hyprVarsFile.setText(root.serializeHyprVars(data));
        Hypr.extras.batchMessage(["reload"]);
        root.nState.closeSubPage();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        FileView {
            id: hyprVarsFile

            path: `${Quickshell.env("HOME")}/.config/caelestia/hypr-vars.lua`
            printErrors: false
            onLoadFailed: error => {
                if (error === FileViewError.FileNotFound)
                    Qt.callLater(() => setText("return {}\n"));
            }
        }

        SectionHeader {
            first: true
            text: qsTr("Shortcut")
        }

        Repeater {
            id: list

            model: root.options

            ConnectedRect {
                id: item

                required property var modelData
                required property int index

                Layout.fillWidth: true
                first: index === 0
                last: index === list.count - 1
                implicitHeight: itemRow.implicitHeight + Tokens.padding.medium * 2

                StateLayer {
                    onClicked: root.choose(item.modelData.value)
                }

                RowLayout {
                    id: itemRow

                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased

                    StyledText {
                        Layout.fillWidth: true
                        text: item.modelData.label
                        font: Tokens.font.body.small
                    }
                }
            }
        }
    }
}
