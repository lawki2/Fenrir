pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Fenrir's own Display settings page. Hyprland has no native "primary
// monitor" concept (unlike Windows) - here "primary" is purely a UI
// convention: whichever monitor is marked primary is translated to (0,0)
// at apply time, every other monitor's position is kept relative to it.
//
// Persistence is genuinely new ground for this codebase (no existing
// "GUI writes structured data, Hyprland's Lua config reads it at startup"
// bridge exists anywhere else here): this page owns a small satellite file,
// ~/.config/caelestia/nexus-monitors.lua (fully machine-generated, safe to
// overwrite wholesale every save), loaded via one marker-commented block
// this page inserts into ~/.config/caelestia/hypr-user.lua the first time
// it successfully applies a layout - never touching hypr-user.lua's other,
// hand-authored content. If hypr-user.lua already has its own hl.monitor()
// calls outside that marker (a real, confirmed-possible state - not every
// Fenrir install starts from a clean skel), this page refuses to
// auto-inject and just says so, rather than silently stacking rules.
PageBase {
    id: root

    title: qsTr("Display")

    property var monitorList: []
    property string selectedName: ""
    readonly property var selected: root.monitorList.find(m => m.name === root.selectedName) ?? null

    property list<MenuItem> modeItems: []
    property list<var> modeValues: []

    property bool hyprUserHasForeignRules: false
    property bool nexusBlockPresent: false

    readonly property bool hasOverlap: root.monitorList.some(m => root.monitorList.some(o => o.name !== m.name && o.x < m.x + m.width && o.x + o.width > m.x && o.y < m.y + m.height && o.y + o.height > m.y))

    function buildMonitorList(): void {
        const list = Hypr.monitors.values.map(m => ({
            name: m.name,
            x: m.x,
            y: m.y,
            width: m.width,
            height: m.height,
            refreshRate: m.lastIpcObject?.refreshRate ?? 60,
            transform: m.lastIpcObject?.transform ?? 0,
            scale: m.scale,
            availableModes: m.lastIpcObject?.availableModes ?? [],
            primary: false
        }));
        if (list.length && !list.some(m => m.primary))
            list[0].primary = true;
        root.monitorList = list;
        if (!root.selectedName && list.length)
            root.selectedName = list[0].name;
    }

    function refreshModeItems(): void {
        const m = root.selected;
        const modes = m?.availableModes ?? [];
        const seen = {};
        const items = [];
        const values = [];
        for (const modeStr of modes) {
            const match = modeStr.match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
            if (!match)
                continue;
            const hz = Math.round(parseFloat(match[3]));
            const key = `${match[1]}x${match[2]}@${hz}`;
            if (seen[key])
                continue;
            seen[key] = true;
            items.push(modeItemComp.createObject(root, {
                text: `${match[1]}×${match[2]} @ ${hz}Hz`
            }));
            values.push({
                width: parseInt(match[1], 10),
                height: parseInt(match[2], 10),
                refreshRate: parseFloat(match[3])
            });
        }
        root.modeItems = items;
        root.modeValues = values;
    }

    onSelectedNameChanged: root.refreshModeItems()

    function setSelectedMode(width: real, height: real, refreshRate: real): void {
        root.monitorList = root.monitorList.map(m => {
            if (m.name !== root.selectedName)
                return m;
            return {
                name: m.name,
                x: m.x,
                y: m.y,
                width: width,
                height: height,
                refreshRate: refreshRate,
                transform: m.transform,
                scale: m.scale,
                availableModes: m.availableModes,
                primary: m.primary
            };
        });
        root.apply();
    }

    function setPrimary(name: string): void {
        root.monitorList = root.monitorList.map(m => ({
            name: m.name,
            x: m.x,
            y: m.y,
            width: m.width,
            height: m.height,
            refreshRate: m.refreshRate,
            transform: m.transform,
            scale: m.scale,
            availableModes: m.availableModes,
            primary: m.name === name
        }));
        root.apply();
    }

    function setPosition(name: string, x: real, y: real): void {
        root.monitorList = root.monitorList.map(m => {
            if (m.name !== name)
                return m;
            return {
                name: m.name,
                x: x,
                y: y,
                width: m.width,
                height: m.height,
                refreshRate: m.refreshRate,
                transform: m.transform,
                scale: m.scale,
                availableModes: m.availableModes,
                primary: m.primary
            };
        });
        root.apply();
    }

    // Real position -> Lua `monitor=` string, e.g. "2560x1440@144.00"
    function modeString(m: var): string {
        return `${Math.round(m.width)}x${Math.round(m.height)}@${m.refreshRate.toFixed(2)}`;
    }

    function serializeLua(list: var): string {
        const primary = list.find(m => m.primary) ?? list[0];
        const ox = primary ? primary.x : 0;
        const oy = primary ? primary.y : 0;

        const lines = list.map(m => {
            const x = Math.round(m.x - ox);
            const y = Math.round(m.y - oy);
            return `    { output = "${m.name}", mode = "${root.modeString(m)}", position = "${x}x${y}", scale = ${m.scale}, transform = ${m.transform} },`;
        });
        return `return {\n${lines.join("\n")}\n}\n`;
    }

    function apply(): void {
        if (root.hasOverlap)
            return;

        const list = root.monitorList;
        const primary = list.find(m => m.primary) ?? list[0];
        const ox = primary ? primary.x : 0;
        const oy = primary ? primary.y : 0;

        const evalCalls = list.map(m => {
            const x = Math.round(m.x - ox);
            const y = Math.round(m.y - oy);
            return `eval hl.monitor({ output = "${m.name}", mode = "${root.modeString(m)}", position = "${x}x${y}", scale = ${m.scale}, transform = ${m.transform} })`;
        });
        Hypr.extras.batchMessage(evalCalls);

        monitorsLuaFile.setText(root.serializeLua(list));
        root.ensureHyprUserBlock();
    }

    readonly property string nexusMarkerBegin: "-- BEGIN NEXUS MONITORS (auto-generated by Fenrir's Display settings page)"
    readonly property string nexusMarkerEnd: "-- END NEXUS MONITORS"

    // Read-only: safe to call as soon as the page loads, before the user
    // has changed anything - just informs the "foreign rules" warning.
    function checkHyprUserState(): void {
        const text = hyprUserFile.text();
        root.nexusBlockPresent = text.includes(root.nexusMarkerBegin);
        // Any hl.monitor( call outside our own marker block means someone
        // hand-authored monitor rules in this file already - don't stack
        // a second, competing source of truth on top of it.
        const withoutOurBlock = root.nexusBlockPresent ? text.slice(0, text.indexOf(root.nexusMarkerBegin)) + text.slice(text.indexOf(root.nexusMarkerEnd) + root.nexusMarkerEnd.length) : text;
        root.hyprUserHasForeignRules = withoutOurBlock.includes("hl.monitor(");
    }

    function ensureHyprUserBlock(): void {
        root.checkHyprUserState();
        if (root.nexusBlockPresent || root.hyprUserHasForeignRules)
            return;

        const text = hyprUserFile.text();
        const block = `\n${root.nexusMarkerBegin}\nlocal ok, nexusMonitors = pcall(require, "nexus-monitors")\nif ok and type(nexusMonitors) == "table" then\n    for _, cfg in ipairs(nexusMonitors) do hl.monitor(cfg) end\nend\n${root.nexusMarkerEnd}\n`;
        hyprUserFile.setText(text + block);
        root.nexusBlockPresent = true;
    }

    Component.onCompleted: {
        root.buildMonitorList();
        root.refreshModeItems();
        root.checkHyprUserState();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        Component {
            id: modeItemComp

            MenuItem {}
        }

        FileView {
            id: monitorsLuaFile

            path: `${Quickshell.env("HOME")}/.config/caelestia/nexus-monitors.lua`
            printErrors: false
            onLoadFailed: error => {
                if (error === FileViewError.FileNotFound)
                    Qt.callLater(() => setText(""));
            }
        }

        FileView {
            id: hyprUserFile

            path: `${Quickshell.env("HOME")}/.config/caelestia/hypr-user.lua`
            printErrors: false
            onLoadFailed: error => {
                if (error === FileViewError.FileNotFound)
                    Qt.callLater(() => setText(""));
            }
        }

        StyledText {
            text: qsTr("Arrange displays")
            font: Tokens.font.title.small
        }

        MonitorCanvas {
            Layout.fillWidth: true
            Layout.preferredHeight: 220

            monitors: root.monitorList
            selectedMonitor: root.selectedName

            onSelected: name => root.selectedName = name
            onPositionChanged: (name, x, y) => root.setPosition(name, x, y)
        }

        StyledText {
            visible: root.hasOverlap
            Layout.fillWidth: true
            text: qsTr("Displays overlap - move them apart to apply this layout.")
            color: Colours.palette.m3error
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        StyledText {
            visible: root.hyprUserHasForeignRules
            Layout.fillWidth: true
            text: qsTr("hypr-user.lua already has its own monitor rules - Fenrir won't add its own alongside them. Remove the existing hl.monitor() calls there first if you want this page to manage your layout.")
            color: Colours.palette.m3error
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        SelectRow {
            visible: root.modeItems.length > 0
            first: true
            label: qsTr("Resolution & refresh rate")
            menuItems: root.modeItems
            active: root.modeItems[Math.max(0, root.modeValues.findIndex(v => v.width === root.selected?.width && v.height === root.selected?.height && Math.round(v.refreshRate) === Math.round(root.selected?.refreshRate ?? 0)))]
            onSelected: item => {
                const v = root.modeValues[root.modeItems.indexOf(item)];
                root.setSelectedMode(v.width, v.height, v.refreshRate);
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Set as primary display")
            subtext: qsTr("The primary display is always positioned at 0,0")
            checked: root.selected?.primary ?? false
            onToggled: {
                if (checked)
                    root.setPrimary(root.selectedName);
            }
        }
    }
}
