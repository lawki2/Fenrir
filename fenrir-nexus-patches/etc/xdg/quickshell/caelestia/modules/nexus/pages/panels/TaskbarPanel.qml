pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    // Fenrir: FenrirShell.barStyle values, in menu order.
    readonly property list<string> styles: ["dock", "taskbar"]
    readonly property list<MenuItem> styleItems: [
        MenuItem {
            icon: "position_bottom_left"
            text: qsTr("Dock")
        },
        MenuItem {
            icon: "dock_to_left"
            text: qsTr("Taskbar")
        }
    ]

    title: qsTr("Dock")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SelectRow {
            id: styleRow

            first: true
            last: true
            label: qsTr("Style")
            subtext: FenrirShell.dock ? qsTr("Clock, status icons and tray at the bottom left") : qsTr("The full-height bar with workspaces")
            menuItems: root.styleItems
            onSelected: item => FenrirShell.set({
                    barStyle: root.styles[root.styleItems.indexOf(item)]
                })

            // Fenrir: a pick assigns active directly, which would drop a plain binding.
            Binding {
                target: styleRow
                property: "active"
                value: root.styleItems[root.styles.indexOf(FenrirShell.barStyle)]
            }
        }

        // Behaviour
        SectionHeader {
            text: qsTr("Behaviour")
        }

        ToggleRow {
            first: true
            text: qsTr("Persistent")
            subtext: FenrirShell.dock ? qsTr("Keep the dock visible at all times") : qsTr("Keep the bar visible at all times")
            checked: Config.bar.persistent
            onToggled: GlobalConfig.bar.persistent = checked
        }

        ToggleRow {
            text: qsTr("Show on hover")
            subtext: FenrirShell.dock ? qsTr("Reveal the dock when the cursor touches the left edge beside it") : qsTr("Reveal the bar when the cursor reaches the screen edge")
            checked: Config.bar.showOnHover
            onToggled: GlobalConfig.bar.showOnHover = checked
        }

        StepperRow {
            last: true
            label: qsTr("Drag threshold")
            subtext: FenrirShell.dock ? qsTr("Pixels dragged before the dock reveals") : qsTr("Pixels dragged before the bar reveals")
            value: Config.bar.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.bar.dragThreshold = v
        }

        // Components
        SectionHeader {
            text: qsTr("Components")
        }

        NavRow {
            first: true
            icon: "workspaces"
            text: qsTr("Workspaces")
            subtext: FenrirShell.dock ? qsTr("Shown at the top while switching or holding Super") : qsTr("Indicators, window icons")
            onClicked: root.nState.openSubPage(6)
        }

        NavRow {
            visible: !FenrirShell.dock
            icon: "web_asset"
            text: qsTr("Active window")
            subtext: qsTr("Title display, popout")
            onClicked: root.nState.openSubPage(7)
        }

        NavRow {
            icon: "widgets"
            text: qsTr("Tray")
            subtext: qsTr("System tray icons")
            onClicked: root.nState.openSubPage(8)
        }

        NavRow {
            icon: "signal_cellular_alt"
            text: qsTr("Status icons")
            subtext: qsTr("Visible indicators")
            onClicked: root.nState.openSubPage(9)
        }

        NavRow {
            last: true
            icon: "schedule"
            text: qsTr("Clock")
            subtext: qsTr("Date, icon, background")
            onClicked: root.nState.openSubPage(10)
        }

        // Scroll actions
        SectionHeader {
            text: qsTr("Scroll actions")
        }

        ToggleRow {
            visible: !FenrirShell.dock
            first: true
            text: qsTr("Workspaces")
            subtext: qsTr("Scroll over the workspace indicator to switch workspaces")
            checked: Config.bar.scrollActions.workspaces
            onToggled: GlobalConfig.bar.scrollActions.workspaces = checked
        }

        ToggleRow {
            first: FenrirShell.dock
            text: qsTr("Volume")
            subtext: FenrirShell.dock ? qsTr("Scroll on the upper half of the dock to adjust volume") : qsTr("Scroll on the top half of the bar to adjust volume")
            checked: Config.bar.scrollActions.volume
            onToggled: GlobalConfig.bar.scrollActions.volume = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Brightness")
            subtext: FenrirShell.dock ? qsTr("Scroll on the lower half of the dock to adjust brightness") : qsTr("Scroll on the bottom half of the bar to adjust brightness")
            checked: Config.bar.scrollActions.brightness
            onToggled: GlobalConfig.bar.scrollActions.brightness = checked
        }
    }
}
