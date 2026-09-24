pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Switches for the background.* options Nexus has no UI for.
PageBase {
    id: root

    readonly property bool clockOn: Config.background.desktopClock.enabled
    readonly property bool visOn: Config.background.visualiser.enabled

    // Position is "<row>-<column>", matching the states in background/Background.qml.
    readonly property list<string> position: Config.background.desktopClock.position.split("-")
    readonly property list<string> rows: ["top", "middle", "bottom"]
    readonly property list<string> columns: ["left", "center", "right"]
    readonly property list<MenuItem> rowItems: [
        MenuItem {
            text: qsTr("Top")
        },
        MenuItem {
            text: qsTr("Middle")
        },
        MenuItem {
            text: qsTr("Bottom")
        }
    ]
    readonly property list<MenuItem> columnItems: [
        MenuItem {
            text: qsTr("Left")
        },
        MenuItem {
            text: qsTr("Centre")
        },
        MenuItem {
            text: qsTr("Right")
        }
    ]

    function setPosition(row: string, column: string): void {
        GlobalConfig.background.desktopClock.position = `${row}-${column}`;
    }

    title: qsTr("Desktop")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Desktop clock")
        }

        ToggleRow {
            first: true
            last: !root.clockOn
            text: qsTr("Show desktop clock")
            checked: root.clockOn
            onToggled: GlobalConfig.background.desktopClock.enabled = checked
        }

        SelectRow {
            visible: root.clockOn
            label: qsTr("Vertical position")
            menuItems: root.rowItems
            active: root.rowItems[root.rows.indexOf(root.position[0])] ?? null
            onSelected: item => root.setPosition(root.rows[root.rowItems.indexOf(item)], root.position[1])
        }

        SelectRow {
            visible: root.clockOn
            label: qsTr("Horizontal position")
            menuItems: root.columnItems
            active: root.columnItems[root.columns.indexOf(root.position[1])] ?? null
            onSelected: item => root.setPosition(root.position[0], root.columns[root.columnItems.indexOf(item)])
        }

        SliderRow {
            visible: root.clockOn
            icon: "format_size"
            label: qsTr("Size")
            value: (Config.background.desktopClock.scale - 0.5) / 1.5
            valueLabel: `${Math.round(Config.background.desktopClock.scale * 100)}%`
            onMoved: v => GlobalConfig.background.desktopClock.scale = Math.round((0.5 + v * 1.5) * 20) / 20
        }

        ToggleRow {
            visible: root.clockOn
            last: true
            text: qsTr("Invert colours")
            subtext: qsTr("A dark clock on a light theme, and a light one on a dark theme")
            checked: Config.background.desktopClock.invertColors
            onToggled: GlobalConfig.background.desktopClock.invertColors = checked
        }

        SectionHeader {
            visible: root.clockOn
            text: qsTr("Clock backdrop")
        }

        ToggleRow {
            visible: root.clockOn
            first: true
            last: !Config.background.desktopClock.background.enabled
            text: qsTr("Backdrop")
            subtext: qsTr("A panel behind the clock")
            checked: Config.background.desktopClock.background.enabled
            onToggled: GlobalConfig.background.desktopClock.background.enabled = checked
        }

        ToggleRow {
            visible: root.clockOn && Config.background.desktopClock.background.enabled
            text: qsTr("Blur")
            subtext: qsTr("Frost the wallpaper behind the panel")
            checked: Config.background.desktopClock.background.blur
            onToggled: GlobalConfig.background.desktopClock.background.blur = checked
        }

        SliderRow {
            visible: root.clockOn && Config.background.desktopClock.background.enabled
            last: true
            icon: "opacity"
            label: qsTr("Opacity")
            value: Config.background.desktopClock.background.opacity
            valueLabel: `${Math.round(value * 100)}%`
            onMoved: v => GlobalConfig.background.desktopClock.background.opacity = Math.round(v * 100) / 100
        }

        SectionHeader {
            visible: root.clockOn
            text: qsTr("Clock shadow")
        }

        ToggleRow {
            visible: root.clockOn
            first: true
            last: !Config.background.desktopClock.shadow.enabled
            text: qsTr("Shadow")
            checked: Config.background.desktopClock.shadow.enabled
            onToggled: GlobalConfig.background.desktopClock.shadow.enabled = checked
        }

        SliderRow {
            visible: root.clockOn && Config.background.desktopClock.shadow.enabled
            icon: "contrast"
            label: qsTr("Strength")
            value: Config.background.desktopClock.shadow.opacity
            valueLabel: `${Math.round(value * 100)}%`
            onMoved: v => GlobalConfig.background.desktopClock.shadow.opacity = Math.round(v * 100) / 100
        }

        SliderRow {
            visible: root.clockOn && Config.background.desktopClock.shadow.enabled
            last: true
            icon: "blur_on"
            label: qsTr("Softness")
            value: Config.background.desktopClock.shadow.blur
            valueLabel: `${Math.round(value * 100)}%`
            onMoved: v => GlobalConfig.background.desktopClock.shadow.blur = Math.round(v * 100) / 100
        }

        SectionHeader {
            text: qsTr("Audio visualiser")
        }

        ToggleRow {
            first: true
            last: !root.visOn
            text: qsTr("Show visualiser")
            subtext: qsTr("Bars that move with whatever is playing, behind your windows")
            checked: root.visOn
            onToggled: GlobalConfig.background.visualiser.enabled = checked
        }

        ToggleRow {
            visible: root.visOn
            text: qsTr("Only on empty workspaces")
            subtext: qsTr("Hide it while tiled windows cover the desktop")
            checked: Config.background.visualiser.autoHide
            onToggled: GlobalConfig.background.visualiser.autoHide = checked
        }

        ToggleRow {
            visible: root.visOn
            text: qsTr("Blur")
            subtext: qsTr("Frost the wallpaper behind the bars")
            checked: Config.background.visualiser.blur
            onToggled: GlobalConfig.background.visualiser.blur = checked
        }

        StepperRow {
            visible: root.visOn
            label: qsTr("Bars")
            subtext: qsTr("Also sets the dashboard's media visualiser")
            value: GlobalConfig.services.visualiserBars
            from: 10
            to: 120
            stepSize: 2
            onMoved: v => GlobalConfig.services.visualiserBars = v
        }

        SliderRow {
            visible: root.visOn
            icon: "rounded_corner"
            label: qsTr("Rounding")
            value: Config.background.visualiser.rounding / 4
            valueLabel: `${Math.round(Config.background.visualiser.rounding * 100)}%`
            onMoved: v => GlobalConfig.background.visualiser.rounding = Math.round(v * 40) / 10
        }

        SliderRow {
            visible: root.visOn
            last: true
            icon: "space_bar"
            label: qsTr("Spacing")
            value: Config.background.visualiser.spacing / 3
            valueLabel: `${Math.round(Config.background.visualiser.spacing * 100)}%`
            onMoved: v => GlobalConfig.background.visualiser.spacing = Math.round(v * 30) / 10
        }
    }
}
