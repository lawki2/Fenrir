pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

// Rebinds the ~1/3 of Fenrir's default Hyprland keybinds that already go
// through variables.lua's vars.kbXxx indirection (see keybinds.lua) - the
// existing hypr-vars.lua override mechanism upstream Caelestia already
// ships (hyprland.lua merges it into `vars` before keybinds.lua runs)
// already makes every entry below rebindable with zero changes to any
// vendored file, so this page just reads/writes that one small file and
// triggers a reload. The manifest's `default` values mirror
// variables.lua's real current defaults - kept in sync by hand, since Lua
// and QML are separate runtimes with no shared source of truth here.
//
// Deliberately not covered: the ~2/3 of binds that are still hardcoded
// literals in keybinds.lua (mostly hardware keys, mouse-drag binds with no
// sane rebind UX, and anything not judged worth exposing), and the
// workspace-loop binds are exposed as their one shared modifier (rebinding
// per-workspace-number isn't a sane granularity anyone actually wants).
PageBase {
    id: root

    title: qsTr("Keybinds")

    readonly property var manifest: [
        // Workspaces
        {
            id: "kbGoToWs",
            category: qsTr("Workspaces"),
            label: qsTr("Switch workspace"),
            subtext: qsTr("Held with a number key (1-0)"),
            default: "SUPER"
        },
        {
            id: "kbMoveWinToWs",
            category: qsTr("Workspaces"),
            label: qsTr("Move window to workspace"),
            subtext: qsTr("Held with a number key (1-0)"),
            default: "SUPER + ALT"
        },
        {
            id: "kbGoToWsGroup",
            category: qsTr("Workspaces"),
            label: qsTr("Switch workspace group"),
            subtext: qsTr("Held with a number key (1-0)"),
            default: "CTRL + SUPER"
        },
        {
            id: "kbMoveWinToWsGroup",
            category: qsTr("Workspaces"),
            label: qsTr("Move window to workspace group"),
            subtext: qsTr("Held with a number key (1-0)"),
            default: "CTRL + SUPER + ALT"
        },
        {
            id: "kbNextWs",
            category: qsTr("Workspaces"),
            label: qsTr("Next workspace"),
            default: "CTRL + SUPER + Right"
        },
        {
            id: "kbPrevWs",
            category: qsTr("Workspaces"),
            label: qsTr("Previous workspace"),
            default: "CTRL + SUPER + Left"
        },

        // Window group
        {
            id: "kbWindowGroupCycleNext",
            category: qsTr("Window group"),
            label: qsTr("Cycle to next grouped window"),
            default: "ALT + TAB"
        },
        {
            id: "kbWindowGroupCyclePrev",
            category: qsTr("Window group"),
            label: qsTr("Cycle to previous grouped window"),
            default: "SHIFT + ALT + TAB"
        },
        {
            id: "kbUngroup",
            category: qsTr("Window group"),
            label: qsTr("Remove window from group"),
            default: "SUPER + U"
        },
        {
            id: "kbToggleGroup",
            category: qsTr("Window group"),
            label: qsTr("Toggle window group"),
            default: "SUPER + Comma"
        },

        // Window action
        {
            id: "kbMoveWindow",
            category: qsTr("Window"),
            label: qsTr("Drag to move window"),
            default: "SUPER + Z"
        },
        {
            id: "kbResizeWindow",
            category: qsTr("Window"),
            label: qsTr("Drag to resize window"),
            default: "SUPER + X"
        },
        {
            id: "kbWindowPip",
            category: qsTr("Window"),
            label: qsTr("Toggle picture-in-picture"),
            default: "SUPER + ALT + backslash"
        },
        {
            id: "kbPinWindow",
            category: qsTr("Window"),
            label: qsTr("Pin window"),
            default: "SUPER + P"
        },
        {
            id: "kbWindowFullscreen",
            category: qsTr("Window"),
            label: qsTr("Toggle fullscreen"),
            default: "SUPER + F"
        },
        {
            id: "kbWindowBorderedFullscreen",
            category: qsTr("Window"),
            label: qsTr("Toggle bordered fullscreen"),
            default: "SUPER + ALT + F"
        },
        {
            id: "kbToggleWindowFloating",
            category: qsTr("Window"),
            label: qsTr("Toggle floating"),
            default: "SUPER + ALT + space"
        },
        {
            id: "kbCloseWindow",
            category: qsTr("Window"),
            label: qsTr("Close window"),
            default: "SUPER + Q"
        },

        // Special workspaces
        {
            id: "kbSpecialWs",
            category: qsTr("Special workspaces"),
            label: qsTr("Toggle scratchpad"),
            default: "SUPER + S"
        },
        {
            id: "kbSystemMonitorWs",
            category: qsTr("Special workspaces"),
            label: qsTr("Toggle system monitor"),
            default: "CTRL + SHIFT + Escape"
        },
        {
            id: "kbMusicWs",
            category: qsTr("Special workspaces"),
            label: qsTr("Toggle music"),
            default: "SUPER + M"
        },
        {
            id: "kbCommunicationWs",
            category: qsTr("Special workspaces"),
            label: qsTr("Toggle communication"),
            default: "SUPER + D"
        },
        {
            id: "kbTodoWs",
            category: qsTr("Special workspaces"),
            label: qsTr("Toggle to-do"),
            default: "SUPER + R"
        },

        // Apps
        {
            id: "kbTerminal",
            category: qsTr("Apps"),
            label: qsTr("Open terminal"),
            default: "SUPER + T"
        },
        {
            id: "kbBrowser",
            category: qsTr("Apps"),
            label: qsTr("Open browser"),
            default: "SUPER + W"
        },
        {
            id: "kbEditor",
            category: qsTr("Apps"),
            label: qsTr("Open editor"),
            default: "SUPER + C"
        },
        {
            id: "kbFileExplorer",
            category: qsTr("Apps"),
            label: qsTr("Open file explorer"),
            default: "SUPER + E"
        },

        // Screenshot/clipboard
        {
            id: "kbScreenshot",
            category: qsTr("Screenshot & clipboard"),
            label: qsTr("Take screenshot"),
            default: "Print"
        },
        {
            id: "kbClipboard",
            category: qsTr("Screenshot & clipboard"),
            label: qsTr("Open clipboard history"),
            default: "SUPER + V"
        },
        {
            id: "kbEmoji",
            category: qsTr("Screenshot & clipboard"),
            label: qsTr("Open emoji picker"),
            default: "SUPER + Period"
        },

        // Misc
        {
            id: "kbSession",
            category: qsTr("Misc"),
            label: qsTr("Session menu"),
            default: "CTRL + ALT + Delete"
        },
        {
            id: "kbShowSidebar",
            category: qsTr("Misc"),
            label: qsTr("Toggle sidebar"),
            default: "SUPER + N"
        },
        {
            id: "kbClearNotifs",
            category: qsTr("Misc"),
            label: qsTr("Clear notifications"),
            default: "CTRL + ALT + C"
        },
        {
            id: "kbShowPanels",
            category: qsTr("Misc"),
            label: qsTr("Toggle panels"),
            default: "SUPER + K"
        },
        {
            id: "kbLock",
            category: qsTr("Misc"),
            label: qsTr("Lock screen"),
            default: "SUPER + L"
        }
    ]

    property var overrides: ({})

    function currentValue(entry: var): string {
        return root.overrides[entry.id] ?? entry.default;
    }

    function conflictsFor(entry: var): bool {
        const value = root.currentValue(entry);
        return root.manifest.some(other => other.id !== entry.id && root.currentValue(other) === value);
    }

    // hypr-vars.lua is always a flat `return { key = "value", ... }`
    // table (the shape upstream Caelestia itself generates/expects) - not
    // a general Lua parser, just enough for this one known-simple format.
    function parseHyprVars(text: string): var {
        const result = {};
        const re = /(\w+)\s*=\s*"((?:[^"\\]|\\.)*)"/g;
        let match;
        while ((match = re.exec(text)) !== null)
            result[match[1]] = match[2];
        return result;
    }

    function serializeHyprVars(data: var): string {
        const keys = Object.keys(data);
        if (!keys.length)
            return "return {}\n";
        const lines = keys.map(k => `    ${k} = "${data[k]}",`);
        return `return {\n${lines.join("\n")}\n}\n`;
    }

    function loadOverrides(): void {
        root.overrides = root.parseHyprVars(hyprVarsFile.text());
    }

    function rebind(id: string, newValue: string): void {
        const data = root.parseHyprVars(hyprVarsFile.text());
        data[id] = newValue;
        hyprVarsFile.setText(root.serializeHyprVars(data));
        root.overrides = data;
        Hypr.extras.batchMessage(["reload"]);
    }

    Component.onCompleted: root.loadOverrides()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        FileView {
            id: hyprVarsFile

            path: `${Quickshell.env("HOME")}/.config/caelestia/hypr-vars.lua`
            printErrors: false
            // Component.onCompleted below also calls loadOverrides()
            // eagerly, but if this FileView's initial read is actually
            // asynchronous (as onLoadFailed existing at all implies it
            // can be), that call would run against empty/stale text with
            // nothing to re-trigger it once the real content lands -
            // matching services/Colours.qml's own onLoaded-driven load()
            // call fixes that; re-running loadOverrides() here is a
            // harmless no-op if the eager call already had the real text.
            onLoaded: root.loadOverrides()
            onLoadFailed: error => {
                if (error === FileViewError.FileNotFound)
                    Qt.callLater(() => setText("return {}\n"));
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Click a key combo and press the new one to rebind. Highlighted rows share a key with another action below.")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.manifest

            ColumnLayout {
                id: group

                required property var modelData
                required property int index

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                readonly property bool isNewCategory: index === 0 || root.manifest[index - 1].category !== modelData.category

                SectionHeader {
                    visible: group.isNewCategory
                    first: group.index === 0
                    text: group.modelData.category
                }

                KeybindRow {
                    label: group.modelData.label
                    subtext: group.modelData.subtext ?? ""
                    value: root.currentValue(group.modelData)
                    conflict: root.conflictsFor(group.modelData)
                    onChanged: newValue => root.rebind(group.modelData.id, newValue)
                }
            }
        }
    }
}
