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

    title: qsTr("Region and language")
    subtitle: qsTr("Used for your clock, date format and the language the system is displayed in.")

    property string selectedTimezone: root.defaultTimezone
    property string selectedLocale: root.defaultLocale

    readonly property string defaultTimezone: "America/New_York"
    readonly property string defaultLocale: "en_US.UTF-8"

    ColumnLayout {
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            id: timezoneProc
            command: ["timedatectl", "list-timezones"]
            property var lines: []
            property bool exited: false
            stdout: StdioCollector {
                onStreamFinished: {
                    timezoneProc.lines = text.split("\n").filter(l => l.length > 0);
                    timezoneProc.exited = true;
                }
            }
            Component.onCompleted: running = true
        }

        FileView {
            id: localeFile
            path: "/etc/locale.gen"
            property bool loaded: false
            onLoaded: loaded = true
        }

        SectionHeader {
            first: true
            text: qsTr("Region")
        }

        NavRow {
            first: true
            icon: "schedule"
            text: qsTr("Time zone")
            subtext: root.selectedTimezone
            onClicked: Picker.open(qsTr("Time zone"), timezoneProc.exited ? timezoneProc.lines : [root.defaultTimezone], root.selectedTimezone, value => root.selectedTimezone = value)
        }

        NavRow {
            last: true
            icon: "translate"
            text: qsTr("Language")
            subtext: root.selectedLocale
            onClicked: Picker.open(qsTr("Language"), localeFile.loaded ? root.parseLocales(localeFile.text()) : [root.defaultLocale], root.selectedLocale, value => root.selectedLocale = value)
        }
    }

    function parseLocales(text: string): var {
        const locales = [];
        for (const line of text.split("\n")) {
            const trimmed = line.trim();
            if (trimmed.startsWith("#") && trimmed.includes("UTF-8"))
                locales.push(trimmed.slice(1).trim().split(/\s+/)[0]);
        }
        return locales.length > 0 ? locales : [root.defaultLocale];
    }

}
