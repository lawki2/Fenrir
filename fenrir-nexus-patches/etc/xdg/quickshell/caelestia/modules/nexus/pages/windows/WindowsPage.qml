pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

// The scrolling layout's Hyprland variables, saved through HyprVars; the shortcuts shown are the live ones.
PageBase {
    id: root

    readonly property list<string> hyprKeys: ["columnWidth", "centreFocusedColumn", "singleColumnFullWidth", "focusFollowsMouse"]
    readonly property real columnWidth: root.hypr("columnWidth")
    readonly property var widthPresets: [...new Set(String(HyprVars.value("columnWidthPresets") ?? "").split(",").map(Number).filter(w => w > 0))]

    function hypr(key: string): var {
        return HyprVars.value(key) ?? 0;
    }

    function widthText(width: real): string {
        return width >= 1 ? qsTr("Full width") : qsTr("%1% of the screen").arg(Math.round(width * 100));
    }

    // A left/right pair, as "Super + Shift + ← / →" when both hold the same modifiers.
    function pair(left: var, right: var): string {
        const a = FenrirKeys.format(left);
        const b = FenrirKeys.format(right);
        if (!a || !b)
            return a || b;
        const mods = combo => combo.split(" + ").slice(0, -1).join(" + ");
        return mods(a) === mods(b) ? `${a} / ${b.split(" + ").pop()}` : `${a} / ${b}`;
    }

    title: qsTr("Windows")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Variants {
            id: widthItems

            model: root.widthPresets

            MenuItem {
                required property real modelData

                text: root.widthText(modelData)
            }
        }

        SectionHeader {
            first: true
            text: qsTr("Scrolling")
        }

        SelectRow {
            id: widthRow

            first: true
            label: qsTr("New windows open at")
            menuItems: widthItems.instances
            fallbackText: root.widthText(root.columnWidth)
            onSelected: item => HyprVars.set({
                    columnWidth: item.modelData
                })

            // A pick assigns active directly, which would drop a plain binding and miss a reset.
            Binding {
                target: widthRow
                property: "active"
                value: widthItems.instances.find(i => Math.abs(i.modelData - root.columnWidth) < 0.001) ?? null
            }
        }

        ToggleRow {
            text: qsTr("Keep the focused window centred")
            subtext: qsTr("Otherwise the row only scrolls as far as it needs to")
            checked: root.hypr("centreFocusedColumn")
            onToggled: HyprVars.set({
                    centreFocusedColumn: checked
                })
        }

        ToggleRow {
            last: true
            text: qsTr("A single window fills the screen")
            subtext: qsTr("When it's the only column on the workspace")
            checked: root.hypr("singleColumnFullWidth")
            onToggled: HyprVars.set({
                    singleColumnFullWidth: checked
                })
        }

        SectionHeader {
            text: qsTr("Focus")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Focus follows the mouse")
            subtext: root.hypr("focusFollowsMouse") ? qsTr("Pointing at a window lets you type in it") : qsTr("Click a window to type in it")
            checked: root.hypr("focusFollowsMouse")
            onToggled: HyprVars.set({
                    focusFollowsMouse: checked
                })
        }

        SectionHeader {
            text: qsTr("Shortcuts")
        }

        InfoRow {
            first: true
            label: qsTr("Move between windows")
            value: root.pair("SUPER + Left", "SUPER + Right")
        }

        InfoRow {
            label: qsTr("Move a column")
            value: root.pair(HyprVars.value("kbColumnMoveLeft"), HyprVars.value("kbColumnMoveRight"))
        }

        InfoRow {
            label: qsTr("Stack with a neighbour")
            value: root.pair(HyprVars.value("kbConsumeOrExpelLeft"), HyprVars.value("kbConsumeOrExpelRight"))
        }

        InfoRow {
            label: qsTr("Wider or narrower")
            value: root.pair(HyprVars.value("kbColumnWider"), HyprVars.value("kbColumnNarrower"))
        }

        InfoRow {
            label: qsTr("Full width")
            value: FenrirKeys.format(HyprVars.value("kbWindowBorderedFullscreen"))
        }

        InfoRow {
            label: qsTr("Centre column")
            value: FenrirKeys.format(HyprVars.value("kbCentreColumn"))
        }

        InfoRow {
            label: qsTr("First or last column")
            value: root.pair(HyprVars.value("kbColumnFirst"), HyprVars.value("kbColumnLast"))
        }

        InfoRow {
            label: qsTr("Scroll with the mouse")
            value: qsTr("%1 + scroll wheel").arg(FenrirKeys.format("SUPER"))
        }

        InfoRow {
            visible: Chassis.isLaptop
            label: qsTr("Scroll with the touchpad")
            value: qsTr("%1 fingers left or right").arg(root.hypr("workspaceSwipeFingers"))
        }

        NavRow {
            last: true
            icon: "keyboard"
            text: qsTr("Change shortcuts")
            onClicked: root.nState.currentPageIdx = PageRegistry.pages.findIndex(p => p.key === "keybinds")
        }

        RowButton {
            Layout.topMargin: Tokens.spacing.large
            first: true
            last: true
            icon: "restart_alt"
            text: qsTr("Restore Fenrir's defaults")
            subtext: qsTr("Everything on this page")
            onClicked: HyprVars.reset(root.hyprKeys)
        }
    }
}
