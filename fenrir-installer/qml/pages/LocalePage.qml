import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import "../"

Item {
    id: root

    property string selectedTimezone: root.defaultTimezone
    property string selectedLocale: root.defaultLocale

    readonly property string defaultTimezone: "America/New_York"
    readonly property string defaultLocale: "en_US.UTF-8"

    ColumnLayout {
        anchors.fill: parent
        spacing: TokenConfig.appearance.spacing.large

        Text {
            text: "Timezone and system language"
            color: Colours.m3outline
            font.family: Fonts.sans
            font.pointSize: TokenConfig.appearance.fontSize.normal
        }

        SelectField {
            label: "Timezone"
            value: root.selectedTimezone
            options: timezoneProc.exited ? timezoneProc.lines : [root.defaultTimezone]
            Layout.fillWidth: true
            onPicked: value => root.selectedTimezone = value
        }

        SelectField {
            label: "Language"
            value: root.selectedLocale
            options: localeFile.loaded ? root.parseLocales(localeFile.text()) : [root.defaultLocale]
            Layout.fillWidth: true
            onPicked: value => root.selectedLocale = value
        }

        Item { Layout.fillHeight: true }
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
}
