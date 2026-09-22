pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    property var available: []
    property string filter: ""

    readonly property var options: FenrirNames.timezoneOptions(root.available)
    readonly property var shown: root.filter.length > 0 ? root.options.filter(tz => tz.label.toLowerCase().indexOf(root.filter) >= 0) : root.options

    title: qsTr("Time zone")
    isSubPage: true

    // Closes only once timedatectl has actually applied, so the page
    // underneath re-reads the new value rather than the old one.
    function setTimezone(tz: string): void {
        setTzProc.command = ["timedatectl", "set-timezone", tz];
        setTzProc.running = true;
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Only runs when this sub-page is opened, not on shell startup.
        Process {
            id: tzListProc

            running: true
            command: ["timedatectl", "list-timezones"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const list = [];
                    for (const line of text.trim().split("\n")) {
                        const tz = line.trim();
                        if (tz.length)
                            list.push(tz);
                    }
                    root.available = list;
                }
            }
        }

        Process {
            id: setTzProc

            onExited: root.nState.closeSubPage()
        }

        TextFieldRow {
            first: true
            last: true
            label: qsTr("Search")
            placeholderText: qsTr("Filter time zones")
            onValueEdited: value => root.filter = value.trim().toLowerCase()
        }

        SectionHeader {
            text: qsTr("All time zones")
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
                    onClicked: root.setTimezone(item.modelData.value)
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
