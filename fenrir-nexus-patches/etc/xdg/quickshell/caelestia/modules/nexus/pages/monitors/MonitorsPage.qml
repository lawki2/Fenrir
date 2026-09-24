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

// Hyprland has no primary monitor, so "primary" is moved to (0,0) on apply. Layout
// lives in nexus-monitors.lua, loaded by a marker block this page adds to hypr-user.lua.
PageBase {
    id: root

    title: qsTr("Display")

    // lw/lh: size in Hyprland's layout, i.e. after rotation and scale; x/y use the same space.
    property var monitorList: []
    property string selectedName: ""
    readonly property var selected: root.monitorList.find(m => m.name === root.selectedName) ?? null
    // Menus rebuild only when what they list changes. Keyed on `selected`, which a
    // selectedName handler would still see as the previous display.
    readonly property string displayKey: root.selected?.name ?? ""
    readonly property string modeKey: root.selected ? `${root.selected.name} ${root.selected.width}x${root.selected.height} ${root.selected.scale}` : ""

    property list<MenuItem> resolutionItems: []
    property list<var> resolutionValues: []
    property list<MenuItem> rateItems: []
    property list<real> rateValues: []
    property list<MenuItem> scaleItems: []
    property list<real> scaleValues: []

    // Index is Hyprland's transform; 4-7 are the mirrored versions, which this page leaves alone.
    readonly property list<MenuItem> rotationItems: [
        MenuItem {
            text: qsTr("Normal")
        },
        MenuItem {
            text: "90°"
        },
        MenuItem {
            text: "180°"
        },
        MenuItem {
            text: "270°"
        }
    ]
    readonly property list<real> scaleSteps: [1, 1.25, 1.5, 1.75, 2, 2.5, 3]

    property bool hyprUserHasForeignRules: false
    property bool nexusBlockPresent: false

    readonly property bool hasOverlap: root.monitorList.some(m => root.monitorList.some(o => o.name !== m.name && o.x < m.x + m.lw && o.x + o.lw > m.x && o.y < m.y + m.lh && o.y + o.lh > m.y))

    function withSize(m: var): var {
        const swap = m.transform % 2 === 1;
        m.lw = (swap ? m.height : m.width) / m.scale;
        m.lh = (swap ? m.width : m.height) / m.scale;
        return m;
    }

    // Hyprland rejects a scale that leaves a fractional layout size and silently picks another.
    function scaleFits(width: real, height: real, scale: real): bool {
        return Number.isInteger(width / scale) && Number.isInteger(height / scale);
    }

    function modesOf(m: var): var {
        return (m?.availableModes ?? []).map(s => s.match(/^(\d+)x(\d+)@([\d.]+)Hz$/)).filter(match => match).map(match => ({
                    width: parseInt(match[1], 10),
                    height: parseInt(match[2], 10),
                    rate: parseFloat(match[3])
                }));
    }

    function makeItems(old: var, texts: var): var {
        for (const item of old)
            item.destroy();
        return texts.map(text => menuItemComp.createObject(root, {
                    text
                }));
    }

    function buildMonitorList(): void {
        const list = Hypr.monitors.values.map(m => root.withSize({
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

    function refreshResolutionItems(): void {
        const seen = new Set();
        const values = root.modesOf(root.selected).filter(v => {
            const key = `${v.width}x${v.height}`;
            if (seen.has(key))
                return false;
            seen.add(key);
            return true;
        });
        root.resolutionValues = values;
        root.resolutionItems = root.makeItems(root.resolutionItems, values.map(v => `${v.width} × ${v.height}`));
    }

    function refreshRateAndScaleItems(): void {
        const m = root.selected;
        const seen = new Set();
        const rates = root.modesOf(m).filter(v => {
            if (!m || v.width !== m.width || v.height !== m.height || seen.has(Math.round(v.rate)))
                return false;
            seen.add(Math.round(v.rate));
            return true;
        }).map(v => v.rate);
        root.rateValues = rates;
        root.rateItems = root.makeItems(root.rateItems, rates.map(r => `${Math.round(r)} Hz`));

        const scales = m ? root.scaleSteps.filter(s => root.scaleFits(m.width, m.height, s)) : [];
        if (m && !scales.some(s => Math.abs(s - m.scale) < 0.001))
            scales.push(m.scale);
        scales.sort((a, b) => a - b);
        root.scaleValues = scales;
        root.scaleItems = root.makeItems(root.scaleItems, scales.map(s => `${Math.round(s * 100)}%`));
    }

    onDisplayKeyChanged: root.refreshResolutionItems()
    onModeKeyChanged: root.refreshRateAndScaleItems()

    // Displays right of or below the selected one follow its new edge, so resizing it keeps them touching.
    function updateSelected(changes: var): void {
        const old = root.selected;
        if (!old)
            return;
        const next = root.withSize(Object.assign({}, old, changes));
        const dx = next.lw - old.lw;
        const dy = next.lh - old.lh;
        root.monitorList = root.monitorList.map(m => {
            if (m.name === old.name)
                return next;
            const moved = Object.assign({}, m);
            if (m.x >= old.x + old.lw)
                moved.x += dx;
            if (m.y >= old.y + old.lh)
                moved.y += dy;
            return moved;
        });
        root.apply();
    }

    function setResolution(width: real, height: real): void {
        const m = root.selected;
        const modes = root.modesOf(m).filter(v => v.width === width && v.height === height);
        const sameRate = modes.find(v => Math.round(v.rate) === Math.round(m.refreshRate));
        root.updateSelected({
            width,
            height,
            refreshRate: (sameRate ?? modes[0]).rate,
            scale: root.scaleFits(width, height, m.scale) ? m.scale : 1
        });
    }

    function setRotation(rotation: int): void {
        root.updateSelected({
            transform: (root.selected.transform & 4) | rotation
        });
    }

    function setPrimary(name: string): void {
        root.monitorList = root.monitorList.map(m => Object.assign({}, m, {
                primary: m.name === name
            }));
        root.apply();
    }

    function setPosition(name: string, x: real, y: real): void {
        root.monitorList = root.monitorList.map(m => m.name === name ? Object.assign({}, m, {
                x,
                y
            }) : m);
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
        // Hand-written hl.monitor() calls outside our block: don't stack a second source.
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
        root.checkHyprUserState();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        Component {
            id: menuItemComp

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
            // The first read can be async, so re-check once the text actually lands.
            onLoaded: root.checkHyprUserState()
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
            visible: root.resolutionItems.length > 0
            first: true
            label: qsTr("Resolution")
            menuItems: root.resolutionItems
            active: root.resolutionItems[root.resolutionValues.findIndex(v => v.width === root.selected?.width && v.height === root.selected?.height)] ?? null
            onSelected: item => {
                const v = root.resolutionValues[root.resolutionItems.indexOf(item)];
                root.setResolution(v.width, v.height);
            }
        }

        SelectRow {
            visible: root.rateItems.length > 0
            label: qsTr("Refresh rate")
            menuItems: root.rateItems
            active: root.rateItems[root.rateValues.findIndex(r => Math.round(r) === Math.round(root.selected?.refreshRate ?? 0))] ?? null
            onSelected: item => root.updateSelected({
                    refreshRate: root.rateValues[root.rateItems.indexOf(item)]
                })
        }

        SelectRow {
            visible: root.selected !== null
            label: qsTr("Rotation")
            menuItems: root.rotationItems
            active: root.rotationItems[(root.selected?.transform ?? 0) % 4]
            onSelected: item => root.setRotation(root.rotationItems.indexOf(item))
        }

        SelectRow {
            visible: root.scaleItems.length > 0
            label: qsTr("Scale")
            subtext: qsTr("Only steps that fit this resolution exactly")
            menuItems: root.scaleItems
            active: root.scaleItems[root.scaleValues.findIndex(s => Math.abs(s - (root.selected?.scale ?? 1)) < 0.001)] ?? null
            onSelected: item => root.updateSelected({
                    scale: root.scaleValues[root.scaleItems.indexOf(item)]
                })
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
