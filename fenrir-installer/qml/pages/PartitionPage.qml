import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import "../"

Item {
    id: root

    readonly property string confirmText: "ERASE"
    // Not a hard minimum — just a sane floor above the ESP size, flagged
    // here instead of failing deep in backend.py later.
    readonly property real minRecommendedGib: 16
    readonly property var selectedDisk_: {
        const i = root.diskLabels.indexOf(root.selectedDiskLabel);
        return i >= 0 ? root.disks[i] : null;
    }
    readonly property bool diskTooSmall: root.selectedDisk_ !== null
        && (root.selectedDisk_.size / (1024 ** 3)) < root.minRecommendedGib
    readonly property bool confirmed: root.selectedDiskLabel !== "" && !root.diskTooSmall && confirmField.text === confirmText
    readonly property var diskLabels: root.disks.map(root.diskLabel)
    readonly property string selectedDisk: root.selectedDisk_ !== null ? root.selectedDisk_.path : ""

    property var disks: []
    property string selectedDiskLabel: ""
    property bool errorVisible: false

    function showError(): void {
        root.errorVisible = true;
    }

    function diskLabel(disk): string {
        const gib = disk.size / (1024 ** 3);
        const model = disk.model ? ` (${disk.model})` : "";
        return `${disk.path}${model} — ${gib.toFixed(0)} GiB`;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: TokenConfig.appearance.spacing.large

        SectionHeading {
            Layout.topMargin: TokenConfig.appearance.spacing.large
            icon: "storage"
            text: "Disk setup"
        }

        Text {
            Layout.fillWidth: true
            Layout.bottomMargin: TokenConfig.appearance.spacing.large
            wrapMode: Text.WordWrap
            text: "The selected disk will be completely erased and repartitioned. This cannot be undone."
            color: Colours.m3error
            font.family: Fonts.sans
            font.pointSize: TokenConfig.appearance.fontSize.normal
        }

        SelectField {
            label: "Target disk"
            value: root.selectedDiskLabel
            options: root.diskLabels
            Layout.fillWidth: true
            onPicked: value => root.selectedDiskLabel = value
        }

        Text {
            visible: root.diskTooSmall
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: `This disk is too small for a comfortable install (under ${root.minRecommendedGib.toFixed(0)} GiB) — pick a different one.`
            color: Colours.m3error
            font.family: Fonts.sans
            font.pointSize: TokenConfig.appearance.fontSize.small
        }

        StyledTextField {
            id: confirmField
            Layout.fillWidth: true
            placeholderText: `Type "${root.confirmText}" to confirm`
            onTextChanged: root.errorVisible = false
        }

        Text {
            visible: root.errorVisible
            text: "Select a large enough disk and type ERASE to confirm."
            color: Colours.m3error
            font.family: Fonts.sans
            font.pointSize: TokenConfig.appearance.fontSize.small
        }

        Item { Layout.fillHeight: true }
    }

    Process {
        id: listDisksProc
        command: ["python3", "/usr/lib/fenrir-installer/cli.py", "list-disks"]
        stdout: StdioCollector {
            onStreamFinished: root.disks = JSON.parse(text)
        }
        Component.onCompleted: running = true
    }
}
