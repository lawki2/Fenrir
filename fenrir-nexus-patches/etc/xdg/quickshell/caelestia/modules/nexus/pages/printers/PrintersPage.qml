pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

// Driverless printers (network, and USB through ipp-usb) show up in CUPS on their own,
// so this page only picks the default and prints a test page. CUPS' web UI does the rest.
PageBase {
    id: root

    property list<string> printers: []
    property string defaultPrinter: ""
    property bool loaded: false
    property string status: ""

    function refresh(): void {
        listProc.running = true;
        defaultProc.running = true;
    }

    function run(command: var, message: string): void {
        root.status = message;
        actionProc.command = command;
        actionProc.running = true;
    }

    title: qsTr("Printers")

    Component.onCompleted: root.refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // -e also lists printers CUPS has only discovered, not set up.
        Process {
            id: listProc

            command: ["lpstat", "-e"]
            stdout: StdioCollector {
                onStreamFinished: {
                    root.printers = text.split("\n").map(l => l.trim()).filter(l => l);
                    root.loaded = true;
                }
            }
            onExited: code => {
                if (code !== 0)
                    root.loaded = true;
            }
        }

        Process {
            id: defaultProc

            command: ["lpstat", "-d"]
            stdout: StdioCollector {
                onStreamFinished: root.defaultPrinter = text.match(/destination:\s*(\S+)/)?.[1] ?? ""
            }
        }

        Process {
            id: actionProc

            stderr: StdioCollector {
                id: actionErr
            }
            onExited: code => {
                if (code !== 0)
                    root.status = actionErr.text.trim() || qsTr("That didn't work");
                root.refresh();
            }
        }

        // Printers come and go as they wake up or join the network.
        Timer {
            running: true
            repeat: true
            interval: 10000
            onTriggered: root.refresh()
        }

        SectionHeader {
            first: true
            text: qsTr("Printers")
        }

        StyledText {
            visible: root.loaded && root.printers.length === 0
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            text: qsTr("No printers found. Printers on your network, and most USB printers made since about 2015, appear here on their own once they're switched on.")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.printers

            RowButton {
                required property string modelData
                required property int index

                first: index === 0
                last: index === root.printers.length - 1
                icon: "print"
                text: modelData.replace(/_/g, " ")
                subtext: modelData === root.defaultPrinter ? qsTr("Default printer") : qsTr("Make this the default")
                trailingIcon: modelData === root.defaultPrinter ? "check" : ""
                onClicked: {
                    if (modelData !== root.defaultPrinter)
                        root.run(["lpoptions", "-d", modelData], "");
                }
            }
        }

        SectionHeader {
            text: qsTr("More")
        }

        RowButton {
            first: true
            icon: "description"
            text: qsTr("Print a test page")
            subtext: root.defaultPrinter ? qsTr("On %1").arg(root.defaultPrinter.replace(/_/g, " ")) : qsTr("Choose a default printer first")
            disabled: !root.defaultPrinter
            onClicked: root.run(["lp", "-d", root.defaultPrinter, "/usr/share/cups/data/testprint"], qsTr("Test page sent"))
        }

        RowButton {
            last: true
            icon: "open_in_new"
            text: qsTr("Advanced printer settings")
            subtext: qsTr("Older printers, sharing and print queues, in CUPS")
            onClicked: Qt.openUrlExternally("http://localhost:631")
        }

        StyledText {
            visible: root.status !== ""
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            text: root.status
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }
    }
}
