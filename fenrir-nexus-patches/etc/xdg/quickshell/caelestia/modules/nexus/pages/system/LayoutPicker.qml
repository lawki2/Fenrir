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

    property var available: []
    property string filter: ""

    readonly property var options: FenrirNames.layoutOptions(root.available)
    readonly property var shown: root.filter.length > 0 ? root.options.filter(l => l.label.toLowerCase().indexOf(root.filter) >= 0) : root.options

    title: qsTr("Add layout")
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

    function addLayout(code: string): void {
        const data = root.parseHyprVars(hyprVarsFile.text());
        const current = (data["kbLayout"] ?? "us").split(",").filter(l => l.length > 0);
        if (current.indexOf(code) < 0) {
            current.push(code);
            data["kbLayout"] = current.join(",");
            hyprVarsFile.setText(root.serializeHyprVars(data));
            Hypr.extras.batchMessage(["reload"]);
        }
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

        // Only runs when this sub-page is opened, not on shell startup.
        Process {
            id: layoutListProc

            running: true
            command: ["localectl", "list-x11-keymap-layouts"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const list = [];
                    for (const line of text.trim().split("\n")) {
                        const code = line.trim();
                        if (code.length)
                            list.push(code);
                    }
                    root.available = list;
                }
            }
        }

        TextFieldRow {
            first: true
            last: true
            label: qsTr("Search")
            placeholderText: qsTr("Filter layouts")
            onValueEdited: value => root.filter = value.trim().toLowerCase()
        }

        SectionHeader {
            text: qsTr("Available layouts")
        }

        Repeater {
            id: list

            model: root.shown

            ConnectedRect {
                id: item

                required property var modelData
                required property int index

                Layout.fillWidth: true
                first: index === 0
                last: index === list.count - 1
                implicitHeight: itemRow.implicitHeight + Tokens.padding.medium * 2

                StateLayer {
                    onClicked: root.addLayout(item.modelData.value)
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
