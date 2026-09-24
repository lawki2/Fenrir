pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

// Everything here is plain pacman -Syu underneath, so updating from a terminal does the same.
PageBase {
    id: root

    readonly property int maxListed: 50

    readonly property string headline: {
        if (Updates.running)
            return qsTr("Updating…");
        if (Updates.busy)
            return qsTr("Waiting for another install to finish…");
        if (Updates.finished && !Updates.succeeded)
            return qsTr("The update stopped");
        if (Updates.checking)
            return qsTr("Checking for updates…");
        if (Updates.checkFailed)
            return qsTr("Couldn't check for updates");
        if (Updates.packages.length > 0)
            return Updates.packages.length === 1 ? qsTr("1 update available") : qsTr("%1 updates available").arg(Updates.packages.length);
        return Updates.succeeded ? qsTr("Updated") : qsTr("Up to date");
    }

    title: qsTr("Updates")

    Component.onCompleted: {
        if (!Updates.lastChecked.getTime())
            Updates.check();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StyledText {
            text: root.headline
            font: Tokens.font.title.small
        }

        StyledText {
            Layout.bottomMargin: Tokens.spacing.medium
            visible: Updates.lastChecked.getTime() > 0
            text: qsTr("Last checked %1").arg(Qt.formatTime(Updates.lastChecked, "hh:mm"))
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }

        RowButton {
            first: true
            icon: "system_update"
            text: qsTr("Update now")
            subtext: qsTr("Asks for your password, then installs everything below")
            disabled: Updates.busy || Updates.packages.length === 0
            onClicked: Updates.update()
        }

        RowButton {
            last: !(Updates.finished && !Updates.succeeded) && !Updates.restartNeeded
            icon: "refresh"
            text: qsTr("Check again")
            disabled: Updates.busy || Updates.checking
            onClicked: Updates.check()
        }

        // pacman only stops like this when it needs a person to decide, e.g. a file conflict.
        RowButton {
            visible: Updates.finished && !Updates.succeeded
            last: true
            icon: "terminal"
            text: qsTr("Continue in terminal")
            subtext: qsTr("pacman needs you to answer something it won't guess")
            onClicked: Updates.updateInTerminal()
        }

        RowButton {
            visible: Updates.restartNeeded
            last: true
            icon: "restart_alt"
            text: qsTr("Restart now")
            subtext: qsTr("The kernel or a core system part was updated")
            onClicked: Quickshell.execDetached(["systemctl", "reboot"])
        }

        StyledText {
            visible: Updates.startError !== ""
            Layout.topMargin: Tokens.spacing.small
            text: Updates.startError
            color: Colours.palette.m3error
            font: Tokens.font.body.small
        }

        StyledRect {
            visible: Updates.running || Updates.finished
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            implicitHeight: logText.implicitHeight + Tokens.padding.large * 2
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            StyledText {
                id: logText

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                text: Updates.log.trim().split("\n").slice(-12).join("\n") || qsTr("Waiting for your password…")
                font: Tokens.font.mono.small
                color: Colours.palette.m3onSurfaceVariant
                wrapMode: Text.WrapAnywhere
            }
        }

        SectionHeader {
            visible: Updates.packages.length > 0
            text: qsTr("Software")
        }

        Repeater {
            model: Updates.packages.slice(0, root.maxListed)

            InfoRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === Math.min(Updates.packages.length, root.maxListed) - 1
                label: modelData.name
                value: `${modelData.from} → ${modelData.to}`
            }
        }

        StyledText {
            visible: Updates.packages.length > root.maxListed
            Layout.topMargin: Tokens.spacing.small
            text: qsTr("and %1 more").arg(Updates.packages.length - root.maxListed)
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }

        SectionHeader {
            visible: Updates.firmware.length > 0
            text: qsTr("Firmware")
        }

        Repeater {
            model: Updates.firmware

            InfoRow {
                required property var modelData
                required property int index

                first: index === 0
                label: modelData.name
                value: `${modelData.from} → ${modelData.to}`
            }
        }

        // Firmware flashing can need a reboot or a charger, which fwupdmgr asks about itself.
        RowButton {
            visible: Updates.firmware.length > 0
            last: true
            icon: "memory"
            text: qsTr("Update firmware")
            subtext: qsTr("Opens a terminal, where fwupd explains each step")
            onClicked: Updates.updateFirmware()
        }
    }
}
