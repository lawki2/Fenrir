import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import "../"

Item {
    id: root

    property string selectedLayout: root.defaultLayout
    readonly property string defaultLayout: "us"

    ColumnLayout {
        anchors.fill: parent
        spacing: TokenConfig.appearance.spacing.large

        Text {
            text: "Keyboard layout"
            color: Colours.m3outline
            font.family: "Rubik"
            font.pointSize: TokenConfig.appearance.fontSize.normal
        }

        SelectField {
            label: "Layout"
            value: root.selectedLayout
            options: layoutProc.exited ? layoutProc.lines : [root.defaultLayout]
            Layout.fillWidth: true
            onPicked: value => root.selectedLayout = value
        }

        Item { Layout.fillHeight: true }
    }

    Process {
        id: layoutProc
        command: ["localectl", "list-keymaps"]
        property var lines: []
        property bool exited: false
        stdout: StdioCollector {
            onStreamFinished: {
                layoutProc.lines = text.split("\n").filter(l => l.length > 0);
                layoutProc.exited = true;
            }
        }
        Component.onCompleted: running = true
    }
}
