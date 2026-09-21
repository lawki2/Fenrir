pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import qs.services
import qs.modules.nexus.common
import qs.common

InstallerPage {
    id: root

    title: qsTr("Keyboard")
    subtitle: qsTr("Pick the layout that matches your physical keyboard. You can add more later in settings.")

    property string selectedLayout: root.defaultLayout
    readonly property string defaultLayout: "us"

    ColumnLayout {
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

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

        SectionHeader {
            first: true
            text: qsTr("Layout")
        }

        NavRow {
            first: true
            last: true
            icon: "keyboard"
            text: qsTr("Keyboard layout")
            subtext: root.selectedLayout
            onClicked: Picker.open(qsTr("Keyboard layout"), layoutProc.exited ? layoutProc.lines : [root.defaultLayout], root.selectedLayout, value => root.selectedLayout = value)
        }
    }

}
