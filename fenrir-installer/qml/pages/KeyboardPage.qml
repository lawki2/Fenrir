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

    // Bound rather than built in onClicked, so the list re-labels itself
    // once FenrirNames has finished loading its tables.
    readonly property var layoutOptions: FenrirNames.layoutOptions(layoutProc.exited ? layoutProc.lines : [root.defaultLayout])

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // X11 layouts: what Hyprland and Nexus use, and the namespace with readable
        // names. backend.py derives the console keymap from it.
        Process {
            id: layoutProc
            command: ["localectl", "list-x11-keymap-layouts"]
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
            subtext: FenrirNames.layoutLabel(root.selectedLayout)
            onClicked: Picker.open(qsTr("Keyboard layout"), root.layoutOptions, root.selectedLayout, value => root.selectedLayout = value)
        }
    }

}
