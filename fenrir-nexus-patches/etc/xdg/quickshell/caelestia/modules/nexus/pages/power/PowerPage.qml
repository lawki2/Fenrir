pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Edits general.idle, which modules/IdleMonitors.qml runs; Nexus has no UI for it.
PageBase {
    id: root

    readonly property var timeouts: GlobalConfig.general.idle.timeouts
    // 0 means never.
    readonly property list<int> delays: [0, 60, 120, 180, 300, 600, 900, 1800, 3600]
    property list<MenuItem> lockItems: []
    property list<MenuItem> screenItems: []
    property list<MenuItem> sleepItems: []

    // Entries are found by what they do rather than their position, which is the user's to reorder.
    readonly property var stages: ({
            lock: {
                matches: a => a === "lock",
                fresh: {
                    idleAction: "lock"
                }
            },
            screen: {
                matches: a => a === "dpms off",
                fresh: {
                    idleAction: "dpms off",
                    returnAction: "dpms on"
                }
            },
            sleep: {
                matches: a => /suspend|hibernate/i.test([].concat(a ?? []).join(" ")),
                fresh: {
                    idleAction: ["suspendThenHibernate"]
                }
            }
        })

    readonly property list<var> profiles: PowerProfiles.hasPerformanceProfile ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance] : [PowerProfile.PowerSaver, PowerProfile.Balanced]
    readonly property list<MenuItem> profileItems: [
        MenuItem {
            text: qsTr("Power saver")
        },
        MenuItem {
            text: qsTr("Balanced")
        },
        MenuItem {
            text: qsTr("Performance")
        }
    ]

    function delayText(seconds: int): string {
        if (seconds === 0)
            return qsTr("Never");
        if (seconds < 60)
            return qsTr("%1 seconds").arg(seconds);
        if (seconds % 3600 === 0)
            return seconds === 3600 ? qsTr("1 hour") : qsTr("%1 hours").arg(seconds / 3600);
        const minutes = Math.round(seconds / 60);
        return minutes === 1 ? qsTr("1 minute") : qsTr("%1 minutes").arg(minutes);
    }

    function delayOf(stage: string): int {
        const entry = root.timeouts.find(t => root.stages[stage].matches(t.idleAction));
        return entry && (entry.enabled ?? true) ? entry.timeout : 0;
    }

    function setDelay(stage: string, seconds: int): void {
        const list = root.timeouts.map(t => Object.assign({}, t));
        let entry = list.find(t => root.stages[stage].matches(t.idleAction));
        if (!entry) {
            if (seconds === 0)
                return;
            entry = Object.assign({}, root.stages[stage].fresh);
            list.push(entry);
        }
        // Never switches the entry off rather than deleting it, so its action is kept.
        entry.enabled = seconds !== 0;
        if (seconds !== 0)
            entry.timeout = seconds;
        GlobalConfig.general.idle.timeouts = list;
    }

    function makeDelayItems(): var {
        return root.delays.map(s => menuItemComp.createObject(root, {
                    text: root.delayText(s)
                }));
    }

    title: qsTr("Power & sleep")

    Component.onCompleted: {
        root.lockItems = root.makeDelayItems();
        root.screenItems = root.makeDelayItems();
        root.sleepItems = root.makeDelayItems();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Component {
            id: menuItemComp

            MenuItem {}
        }

        SectionHeader {
            first: true
            text: qsTr("When you're away")
        }

        DelayRow {
            first: true
            stage: "lock"
            label: qsTr("Lock the screen after")
            menuItems: root.lockItems
        }

        DelayRow {
            stage: "screen"
            label: qsTr("Turn the screen off after")
            menuItems: root.screenItems
        }

        DelayRow {
            last: true
            stage: "sleep"
            label: qsTr("Sleep after")
            menuItems: root.sleepItems
        }

        SectionHeader {
            text: qsTr("Stay awake")
        }

        ToggleRow {
            first: true
            text: qsTr("While media is playing")
            checked: GlobalConfig.general.idle.inhibitWhenAudio
            onToggled: GlobalConfig.general.idle.inhibitWhenAudio = checked
        }

        ToggleRow {
            last: true
            text: qsTr("While charging")
            checked: GlobalConfig.general.idle.inhibitWhenCharging
            onToggled: GlobalConfig.general.idle.inhibitWhenCharging = checked
        }

        SectionHeader {
            text: qsTr("Sleep")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Lock when going to sleep")
            subtext: qsTr("Also when the lid closes")
            checked: GlobalConfig.general.idle.lockBeforeSleep
            onToggled: GlobalConfig.general.idle.lockBeforeSleep = checked
        }

        SectionHeader {
            text: qsTr("Power mode")
        }

        SelectRow {
            first: true
            last: true
            label: qsTr("Power mode")
            subtext: qsTr("Trades battery life against speed")
            menuItems: root.profileItems.slice(0, root.profiles.length)
            active: root.profileItems[root.profiles.indexOf(PowerProfiles.profile)] ?? null
            onSelected: item => PowerProfiles.profile = root.profiles[root.profileItems.indexOf(item)]
        }
    }

    component DelayRow: SelectRow {
        required property string stage
        readonly property int current: root.delayOf(stage)

        active: menuItems[root.delays.indexOf(current)] ?? null
        fallbackText: root.delayText(current)
        onSelected: item => root.setDelay(stage, root.delays[menuItems.indexOf(item)])
    }
}
