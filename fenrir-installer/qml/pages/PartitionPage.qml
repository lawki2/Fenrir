pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common
import qs.common

// The disks are a list you pick from rather than a dropdown, because this is
// the one irreversible choice in the installer and it should be visible at a
// glance which disk is selected and how big it is.
InstallerPage {
    id: root

    title: qsTr("Choose a disk")
    subtitle: qsTr("The disk you pick is erased completely and repartitioned. This cannot be undone.")

    readonly property string confirmText: "ERASE"
    // Not a hard minimum — just a sane floor above the ESP size, flagged
    // so nobody installs onto a tiny USB stick by accident.
    readonly property real minRecommendedGib: 16

    property var disks: []
    property string selectedDisk: ""
    property bool errorVisible: false

    readonly property var selectedDisk_: root.disks.find(d => d.path === root.selectedDisk) ?? null
    readonly property bool diskTooSmall: root.selectedDisk_ !== null && root.selectedDisk_.size / (1024 ** 3) < root.minRecommendedGib
    readonly property bool confirmed: root.selectedDisk !== "" && !root.diskTooSmall && confirmRow.value === root.confirmText

    function showError(): void {
        root.errorVisible = true;
    }

    function sizeLabel(disk): string {
        return `${(disk.size / (1024 ** 3)).toFixed(0)} GiB`;
    }

    ColumnLayout {
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            id: listDisksProc

            command: ["python3", "/usr/lib/fenrir-installer/cli.py", "list-disks"]
            stdout: StdioCollector {
                // A non-root preview run has nothing to parse; an empty list
                // shows the placeholder rather than throwing.
                onStreamFinished: root.disks = text.trim().length > 0 ? JSON.parse(text) : []
            }
            Component.onCompleted: running = true
        }

        SectionHeader {
            first: true
            text: qsTr("Disks")
        }

        ItemList {
            id: diskList

            first: true
            last: true
            showList: root.disks.length > 0
            placeholderIcon: "storage"
            placeholderText: qsTr("No disks found")

            model: ScriptModel {
                values: root.disks
            }

            delegate: Item {
                id: diskRow

                required property var modelData
                required property int index

                readonly property bool selected: root.selectedDisk === diskRow.modelData.path

                anchors.left: diskList.list.contentItem.left
                anchors.right: diskList.list.contentItem.right
                implicitHeight: diskLayout.implicitHeight + Tokens.padding.medium * 2

                StateLayer {
                    onClicked: root.selectedDisk = diskRow.modelData.path
                }

                RowLayout {
                    id: diskLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: diskRow.selected ? "radio_button_checked" : "radio_button_unchecked"
                        color: diskRow.selected ? Colours.palette.m3primary : Colours.palette.m3outline
                        fontStyle: Tokens.font.icon.small
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: diskRow.modelData.model || diskRow.modelData.path
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: diskRow.modelData.path
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    StyledText {
                        text: root.sizeLabel(diskRow.modelData)
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                    }
                }
            }
        }

        StyledText {
            visible: root.diskTooSmall
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.topMargin: Tokens.spacing.small
            wrapMode: Text.WordWrap
            text: qsTr("That disk is under %1 GiB, which is tight for a comfortable install.").arg(root.minRecommendedGib.toFixed(0))
            color: Colours.palette.m3error
            font: Tokens.font.body.small
        }

        SectionHeader {
            text: qsTr("Confirm")
        }

        TextFieldRow {
            id: confirmRow

            first: true
            last: true
            label: qsTr("Type %1 to continue").arg(root.confirmText)
            subtext: root.selectedDisk !== "" ? qsTr("Everything on %1 will be lost").arg(root.selectedDisk) : qsTr("Select a disk first")
            placeholderText: root.confirmText
            errorText: root.errorVisible && !root.confirmed ? qsTr("Select a disk and type %1 exactly").arg(root.confirmText) : ""
            onValueEdited: value => confirmRow.value = value
        }
    }
}
