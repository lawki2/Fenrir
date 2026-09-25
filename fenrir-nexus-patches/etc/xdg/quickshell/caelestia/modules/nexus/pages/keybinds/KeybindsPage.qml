pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

// Rebinds the keybinds that go through variables.lua's vars.kbXxx, as hypr-vars.lua overrides
// written through HyprVars. `default` values mirror variables.lua by hand.
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
            default: "SUPER",
            modifiersOnly: true
        },
        {
            id: "kbMoveWinToWs",
            category: qsTr("Workspaces"),
            label: qsTr("Move window to workspace"),
            subtext: qsTr("Held with a number key (1-0)"),
            default: "SUPER + ALT",
            modifiersOnly: true
        },
        {
            id: "kbGoToWsGroup",
            category: qsTr("Workspaces"),
            label: qsTr("Switch workspace group"),
            subtext: qsTr("Held with a number key (1-0)"),
            default: "CTRL + SUPER",
            modifiersOnly: true
        },
        {
            id: "kbMoveWinToWsGroup",
            category: qsTr("Workspaces"),
            label: qsTr("Move window to workspace group"),
            subtext: qsTr("Held with a number key (1-0)"),
            default: "CTRL + SUPER + ALT",
            modifiersOnly: true
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
        },
        {
            id: "kbSwitchLayout",
            category: qsTr("Misc"),
            label: qsTr("Switch keyboard layout"),
            default: "CTRL + space"
        }
    ]

    readonly property var overrides: HyprVars.overrides

    function currentValue(entry: var): string {
        return root.overrides[entry.id] ?? entry.default;
    }

    function conflictsFor(entry: var): bool {
        const value = root.currentValue(entry);
        return root.manifest.some(other => other.id !== entry.id && root.currentValue(other) === value);
    }

    function rebind(id: string, newValue: string): void {
        HyprVars.set({
            [id]: newValue
        });
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

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
                    modifiersOnly: group.modelData.modifiersOnly ?? false
                    onChanged: newValue => root.rebind(group.modelData.id, newValue)
                }
            }
        }
    }
}
