pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

// Rebinds the keybinds that go through variables.lua's vars.kbXxx, as hypr-vars.lua overrides
// written through HyprVars.
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
            modifiersOnly: true
        },
        {
            id: "kbMoveWinToWs",
            category: qsTr("Workspaces"),
            label: qsTr("Move window to workspace"),
            subtext: qsTr("Held with a number key (1-0)"),
            modifiersOnly: true
        },
        {
            id: "kbGoToWsGroup",
            category: qsTr("Workspaces"),
            label: qsTr("Switch workspace group"),
            subtext: qsTr("Held with a number key (1-0)"),
            modifiersOnly: true
        },
        {
            id: "kbMoveWinToWsGroup",
            category: qsTr("Workspaces"),
            label: qsTr("Move window to workspace group"),
            subtext: qsTr("Held with a number key (1-0)"),
            modifiersOnly: true
        },
        {
            id: "kbNextWs",
            category: qsTr("Workspaces"),
            label: qsTr("Next workspace")
        },
        {
            id: "kbPrevWs",
            category: qsTr("Workspaces"),
            label: qsTr("Previous workspace")
        },
        {
            id: "kbMoveWinToWsNext",
            category: qsTr("Workspaces"),
            label: qsTr("Move window to next workspace")
        },
        {
            id: "kbMoveWinToWsPrev",
            category: qsTr("Workspaces"),
            label: qsTr("Move window to previous workspace")
        },

        // Window group
        {
            id: "kbUngroup",
            category: qsTr("Window group"),
            label: qsTr("Remove window from group")
        },
        {
            id: "kbToggleGroup",
            category: qsTr("Window group"),
            label: qsTr("Toggle window group")
        },

        // Window action
        {
            id: "kbWindowGroupCycleNext",
            category: qsTr("Window"),
            label: qsTr("Cycle through windows")
        },
        {
            id: "kbWindowGroupCyclePrev",
            category: qsTr("Window"),
            label: qsTr("Cycle back through windows")
        },
        {
            id: "kbMoveWindow",
            category: qsTr("Window"),
            label: qsTr("Drag to move window")
        },
        {
            id: "kbResizeWindow",
            category: qsTr("Window"),
            label: qsTr("Drag to resize window")
        },
        {
            id: "kbWindowPip",
            category: qsTr("Window"),
            label: qsTr("Toggle picture-in-picture")
        },
        {
            id: "kbPinWindow",
            category: qsTr("Window"),
            label: qsTr("Pin window")
        },
        {
            id: "kbWindowFullscreen",
            category: qsTr("Window"),
            label: qsTr("Toggle fullscreen")
        },
        {
            id: "kbWindowBorderedFullscreen",
            category: qsTr("Window"),
            label: qsTr("Toggle full width"),
            subtext: qsTr("Press again to go back to the width it had")
        },
        {
            id: "kbToggleWindowFloating",
            category: qsTr("Window"),
            label: qsTr("Toggle floating")
        },
        {
            id: "kbCloseWindow",
            category: qsTr("Window"),
            label: qsTr("Close window")
        },

        // Scrolling layout
        {
            id: "kbColumnMoveLeft",
            category: qsTr("Scrolling"),
            label: qsTr("Move column left")
        },
        {
            id: "kbColumnMoveRight",
            category: qsTr("Scrolling"),
            label: qsTr("Move column right")
        },
        {
            id: "kbConsumeOrExpelLeft",
            category: qsTr("Scrolling"),
            label: qsTr("Stack with the column on the left"),
            subtext: qsTr("Or take the window back out into its own column")
        },
        {
            id: "kbConsumeOrExpelRight",
            category: qsTr("Scrolling"),
            label: qsTr("Stack with the column on the right"),
            subtext: qsTr("Or take the window back out into its own column")
        },
        {
            id: "kbColumnWider",
            category: qsTr("Scrolling"),
            label: qsTr("Wider column"),
            subtext: qsTr("Steps through the preset widths")
        },
        {
            id: "kbColumnNarrower",
            category: qsTr("Scrolling"),
            label: qsTr("Narrower column"),
            subtext: qsTr("Steps through the preset widths")
        },
        {
            id: "kbCentreColumn",
            category: qsTr("Scrolling"),
            label: qsTr("Centre column"),
            subtext: qsTr("Or centre a floating window")
        },
        {
            id: "kbColumnFirst",
            category: qsTr("Scrolling"),
            label: qsTr("Go to first column")
        },
        {
            id: "kbColumnLast",
            category: qsTr("Scrolling"),
            label: qsTr("Go to last column")
        },

        // Special workspaces
        {
            id: "kbSpecialWs",
            category: qsTr("Special workspaces"),
            label: qsTr("Toggle scratchpad")
        },
        {
            id: "kbSystemMonitorWs",
            category: qsTr("Special workspaces"),
            label: qsTr("Toggle system monitor")
        },
        {
            id: "kbMusicWs",
            category: qsTr("Special workspaces"),
            label: qsTr("Toggle music")
        },
        {
            id: "kbCommunicationWs",
            category: qsTr("Special workspaces"),
            label: qsTr("Toggle communication")
        },
        {
            id: "kbTodoWs",
            category: qsTr("Special workspaces"),
            label: qsTr("Toggle to-do")
        },

        // Apps
        {
            id: "kbTerminal",
            category: qsTr("Apps"),
            label: qsTr("Open terminal")
        },
        {
            id: "kbBrowser",
            category: qsTr("Apps"),
            label: qsTr("Open browser")
        },
        {
            id: "kbEditor",
            category: qsTr("Apps"),
            label: qsTr("Open editor")
        },
        {
            id: "kbFileExplorer",
            category: qsTr("Apps"),
            label: qsTr("Open file explorer")
        },

        // Screenshot/clipboard
        {
            id: "kbScreenshot",
            category: qsTr("Screenshot & clipboard"),
            label: qsTr("Take screenshot")
        },
        {
            id: "kbClipboard",
            category: qsTr("Screenshot & clipboard"),
            label: qsTr("Open clipboard history")
        },
        {
            id: "kbEmoji",
            category: qsTr("Screenshot & clipboard"),
            label: qsTr("Open emoji picker")
        },

        // Misc
        {
            id: "kbSession",
            category: qsTr("Misc"),
            label: qsTr("Session menu")
        },
        {
            id: "kbShowSidebar",
            category: qsTr("Misc"),
            label: qsTr("Toggle sidebar")
        },
        {
            id: "kbClearNotifs",
            category: qsTr("Misc"),
            label: qsTr("Clear notifications")
        },
        {
            id: "kbShowPanels",
            category: qsTr("Misc"),
            label: qsTr("Toggle panels")
        },
        {
            id: "kbLock",
            category: qsTr("Misc"),
            label: qsTr("Lock screen")
        },
        {
            id: "kbSwitchLayout",
            category: qsTr("Misc"),
            label: qsTr("Switch keyboard layout")
        }
    ]

    // Live binds no row here owns; a row's binds carry its id as their description.
    property var fixedBinds: []
    // The widest combo sets every key box's width, so the column lines up.
    readonly property real keyBoxWidth: Math.max(190, root.manifest.reduce((w, entry) => Math.max(w, keyMetrics.advanceWidth(root.currentValue(entry))), 0) + Tokens.padding.large * 2)

    function currentValue(entry: var): string {
        return HyprVars.value(entry.id) ?? "";
    }

    // "CTRL + SUPER + Left" as hyprctl reports it: modmask 68, key "left".
    function parseCombo(value: string): var {
        const bits = {
            SHIFT: 1,
            CTRL: 4,
            ALT: 8,
            SUPER: 64
        };
        const combo = {
            modmask: 0,
            key: ""
        };
        for (const part of value.split("+").map(p => p.trim())) {
            if (bits[part.toUpperCase()])
                combo.modmask |= bits[part.toUpperCase()];
            else
                combo.key = part.toLowerCase();
        }
        return combo;
    }

    // Same modifiers and key; a workspace prefix row is held with any number key.
    function clashes(a: var, aPrefix: bool, b: var, bPrefix: bool): bool {
        if (a.modmask !== b.modmask)
            return false;
        if (aPrefix || bPrefix)
            return (aPrefix || /^[0-9]$/.test(a.key)) && (bPrefix || /^[0-9]$/.test(b.key));
        return a.key === b.key;
    }

    function conflictsFor(entry: var): bool {
        const value = root.currentValue(entry);
        if (!value)
            return false;
        const combo = root.parseCombo(value);
        const prefix = entry.modifiersOnly ?? false;
        return root.manifest.some(other => other.id !== entry.id && root.currentValue(other)
                && root.clashes(combo, prefix, root.parseCombo(root.currentValue(other)), other.modifiersOnly ?? false))
            || root.fixedBinds.some(bind => root.clashes(combo, prefix, {
                    modmask: bind.modmask,
                    key: String(bind.key).toLowerCase()
                }, false));
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

        FontMetrics {
            id: keyMetrics

            font: Tokens.font.body.small
        }

        Process {
            id: bindsProc

            command: ["hyprctl", "binds", "-j"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    const ids = root.manifest.map(entry => entry.id);
                    try {
                        root.fixedBinds = JSON.parse(text).filter(bind => !ids.includes(bind.description));
                    } catch (e) {
                        root.fixedBinds = [];
                    }
                }
            }
        }

        Connections {
            function onConfigReloaded(): void {
                bindsProc.running = true;
            }

            target: Hypr
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Click a key combo and press the new one to rebind. Highlighted rows share a key with another shortcut, including ones that can't be changed here.")
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
                    boxWidth: root.keyBoxWidth
                    onChanged: newValue => root.rebind(group.modelData.id, newValue)
                }
            }
        }
    }
}
