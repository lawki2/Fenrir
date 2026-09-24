pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

// Windows, effects and animations are Hyprland variables saved through HyprVars; the shell
// section is Caelestia's own config.
PageBase {
    id: root

    readonly property list<string> hyprKeys: ["windowGapsIn", "windowGapsOut", "singleWindowGapsOut", "windowRounding", "windowBorderSize", "windowOpacity", "blurEnabled", "blurSize", "shadowEnabled", "animationsEnabled", "animationSpeed"]
    // Slider moves wait here until the drag settles, so Hyprland isn't reloaded on every step.
    property var pending: ({})

    function hypr(key: string): var {
        return key in root.pending ? root.pending[key] : (HyprVars.value(key) ?? 0);
    }

    function stage(changes: var): void {
        root.pending = Object.assign({}, root.pending, changes);
        commit.restart();
    }

    // The shell's animations follow the same switch and speed as the windows'.
    function setShellAnimations(enabled: bool, speed: real): void {
        GlobalConfig.appearance.anim.durations.scale = enabled ? 1 / speed : 0;
    }

    function setInterfaceSize(scale: real): void {
        GlobalConfig.appearance.font.scale = scale;
        GlobalConfig.appearance.padding.scale = scale;
        GlobalConfig.appearance.spacing.scale = scale;
    }

    title: qsTr("Look & feel")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Timer {
            id: commit

            interval: 400
            onTriggered: {
                HyprVars.set(root.pending);
                root.pending = {};
            }
        }

        SectionHeader {
            first: true
            text: qsTr("Windows")
        }

        SliderRow {
            first: true
            icon: "view_column"
            label: qsTr("Space between windows")
            value: root.hypr("windowGapsIn") / 20
            valueLabel: `${root.hypr("windowGapsIn")} px`
            onMoved: v => root.stage({
                    windowGapsIn: Math.round(v * 20)
                })
        }

        // A lone window gets double the edge space, as in Fenrir's defaults.
        SliderRow {
            icon: "fit_screen"
            label: qsTr("Space at the screen edges")
            value: root.hypr("windowGapsOut") / 40
            valueLabel: `${root.hypr("windowGapsOut")} px`
            onMoved: v => {
                const gap = Math.round(v * 40);
                root.stage({
                    windowGapsOut: gap,
                    singleWindowGapsOut: gap * 2
                });
            }
        }

        SliderRow {
            icon: "rounded_corner"
            label: qsTr("Corner rounding")
            value: root.hypr("windowRounding") / 30
            valueLabel: `${root.hypr("windowRounding")} px`
            onMoved: v => root.stage({
                    windowRounding: Math.round(v * 30)
                })
        }

        StepperRow {
            label: qsTr("Border")
            subtext: qsTr("Outline thickness around each window")
            value: root.hypr("windowBorderSize")
            from: 0
            to: 4
            stepSize: 1
            onMoved: v => HyprVars.set({
                    windowBorderSize: v
                })
        }

        SliderRow {
            last: true
            icon: "opacity"
            label: qsTr("Opacity")
            value: (root.hypr("windowOpacity") - 0.7) / 0.3
            valueLabel: `${Math.round(root.hypr("windowOpacity") * 100)}%`
            onMoved: v => root.stage({
                    windowOpacity: Math.round((0.7 + v * 0.3) * 100) / 100
                })
        }

        SectionHeader {
            text: qsTr("Effects")
        }

        ToggleRow {
            first: true
            text: qsTr("Blur")
            subtext: qsTr("Frost what's behind see-through windows and panels")
            checked: root.hypr("blurEnabled")
            onToggled: HyprVars.set({
                    blurEnabled: checked
                })
        }

        SliderRow {
            visible: root.hypr("blurEnabled")
            icon: "blur_on"
            label: qsTr("Blur strength")
            value: (root.hypr("blurSize") - 2) / 14
            valueLabel: `${root.hypr("blurSize")}`
            onMoved: v => root.stage({
                    blurSize: Math.round(2 + v * 14)
                })
        }

        ToggleRow {
            last: true
            text: qsTr("Shadows")
            checked: root.hypr("shadowEnabled")
            onToggled: HyprVars.set({
                    shadowEnabled: checked
                })
        }

        SectionHeader {
            text: qsTr("Animations")
        }

        ToggleRow {
            first: true
            last: !root.hypr("animationsEnabled")
            text: qsTr("Animations")
            subtext: qsTr("Windows, workspaces and the shell's panels")
            checked: root.hypr("animationsEnabled")
            onToggled: {
                HyprVars.set({
                    animationsEnabled: checked
                });
                root.setShellAnimations(checked, root.hypr("animationSpeed"));
            }
        }

        SliderRow {
            visible: root.hypr("animationsEnabled")
            last: true
            icon: "speed"
            label: qsTr("Speed")
            value: (root.hypr("animationSpeed") - 0.5) / 1.5
            valueLabel: `${root.hypr("animationSpeed").toFixed(1)}×`
            onMoved: v => {
                const speed = Math.round((0.5 + v * 1.5) * 10) / 10;
                root.stage({
                    animationSpeed: speed
                });
                root.setShellAnimations(true, speed);
            }
        }

        SectionHeader {
            text: qsTr("Shell")
        }

        SliderRow {
            first: true
            icon: "border_outer"
            label: qsTr("Screen border")
            value: Config.border.thickness / 30
            valueLabel: `${Config.border.thickness} px`
            onMoved: v => GlobalConfig.border.thickness = Math.round(v * 30)
        }

        SliderRow {
            last: true
            icon: "format_size"
            label: qsTr("Interface size")
            value: (Config.appearance.font.scale - 0.85) / 0.4
            valueLabel: `${Math.round(Config.appearance.font.scale * 100)}%`
            onMoved: v => root.setInterfaceSize(Math.round((0.85 + v * 0.4) * 100) / 100)
        }

        RowButton {
            Layout.topMargin: Tokens.spacing.large
            first: true
            last: true
            icon: "restart_alt"
            text: qsTr("Restore Fenrir's defaults")
            subtext: qsTr("Everything on this page")
            onClicked: {
                commit.stop();
                root.pending = {};
                HyprVars.reset(root.hyprKeys);
                root.setShellAnimations(true, 1);
                root.setInterfaceSize(1);
                GlobalConfig.border.thickness = 10;
            }
        }
    }
}
