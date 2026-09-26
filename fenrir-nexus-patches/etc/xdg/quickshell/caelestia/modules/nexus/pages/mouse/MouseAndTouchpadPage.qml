pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Everything here is a Hyprland variable saved through HyprVars; touchpad and gestures show on laptops only.
PageBase {
    id: root

    readonly property list<string> hyprKeys: ["pointerSpeed", "mouseNaturalScroll", "touchpadNaturalScroll", "touchpadTapToClick", "touchpadClickFinger", "touchpadDisableTyping", "touchpadScrollFactor", "workspaceSwipeFingers", "gestureFingers"]
    // Slider moves wait here until the drag settles, so Hyprland isn't reloaded on every step.
    property var pending: ({})
    readonly property int swipeFingers: root.hypr("workspaceSwipeFingers")
    readonly property int otherFingers: root.hypr("gestureFingers")

    readonly property list<MenuItem> fingerItems: [
        MenuItem {
            text: qsTr("Three fingers")
        },
        MenuItem {
            text: qsTr("Four fingers")
        }
    ]

    function hypr(key: string): var {
        return key in root.pending ? root.pending[key] : (HyprVars.value(key) ?? 0);
    }

    function stage(changes: var): void {
        root.pending = Object.assign({}, root.pending, changes);
        commit.restart();
    }

    title: Chassis.isLaptop ? qsTr("Mouse & touchpad") : qsTr("Mouse")

    // Closing the page or Nexus mid-drag still saves the last value.
    Component.onDestruction: {
        if (commit.running) {
            commit.stop();
            HyprVars.set(root.pending);
        }
    }

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
            text: qsTr("Pointer")
        }

        SliderRow {
            first: true
            icon: "speed"
            label: qsTr("Pointer speed")
            value: (root.hypr("pointerSpeed") + 1) / 2
            valueLabel: {
                const speed = root.hypr("pointerSpeed");
                return speed === 0 ? qsTr("Default") : `${speed > 0 ? "+" : ""}${speed.toFixed(1)}`;
            }
            onMoved: v => root.stage({
                    pointerSpeed: Math.round((v * 2 - 1) * 10) / 10
                })
        }

        ToggleRow {
            last: true
            text: qsTr("Reverse the scroll wheel")
            subtext: qsTr("Scroll a mouse the way a touchpad does")
            checked: root.hypr("mouseNaturalScroll")
            onToggled: HyprVars.set({
                    mouseNaturalScroll: checked
                })
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: Chassis.isLaptop
            spacing: Tokens.spacing.extraSmall / 2

            SectionHeader {
                text: qsTr("Touchpad")
            }

            SliderRow {
                first: true
                icon: "swipe_vertical"
                label: qsTr("Scrolling speed")
                value: (root.hypr("touchpadScrollFactor") - 0.2) / 1.8
                valueLabel: `${root.hypr("touchpadScrollFactor").toFixed(1)}×`
                onMoved: v => root.stage({
                        touchpadScrollFactor: Math.round((0.2 + v * 1.8) * 10) / 10
                    })
            }

            ToggleRow {
                text: qsTr("Natural scrolling")
                subtext: qsTr("The page follows your fingers")
                checked: root.hypr("touchpadNaturalScroll")
                onToggled: HyprVars.set({
                        touchpadNaturalScroll: checked
                    })
            }

            ToggleRow {
                text: qsTr("Tap to click")
                subtext: qsTr("A two-finger tap right-clicks")
                checked: root.hypr("touchpadTapToClick")
                onToggled: HyprVars.set({
                        touchpadTapToClick: checked
                    })
            }

            ToggleRow {
                text: qsTr("Two-finger right-click")
                subtext: root.hypr("touchpadClickFinger") ? qsTr("Press down with two fingers to right-click") : qsTr("Press the bottom-right corner to right-click")
                checked: root.hypr("touchpadClickFinger")
                onToggled: HyprVars.set({
                        touchpadClickFinger: checked
                    })
            }

            ToggleRow {
                last: true
                text: qsTr("Ignore while typing")
                subtext: qsTr("Stops a resting palm from moving the pointer")
                checked: root.hypr("touchpadDisableTyping")
                onToggled: HyprVars.set({
                        touchpadDisableTyping: checked
                    })
            }

            SectionHeader {
                text: qsTr("Gestures")
            }

            // The scratchpad swipes take whichever count this leaves free.
            SelectRow {
                first: true
                label: qsTr("Swipe with")
                subtext: qsTr("For workspaces and the launcher")
                menuItems: root.fingerItems
                active: root.fingerItems[root.swipeFingers - 3] ?? null
                fallbackText: qsTr("%1 fingers").arg(root.swipeFingers)
                onSelected: item => {
                    const fingers = root.fingerItems.indexOf(item) + 3;
                    HyprVars.set({
                        workspaceSwipeFingers: fingers,
                        gestureFingers: fingers === 3 ? 4 : 3
                    });
                }
            }

            InfoRow {
                icon: "swipe"
                label: qsTr("Switch workspace")
                value: qsTr("%1 fingers left or right").arg(root.swipeFingers)
            }

            InfoRow {
                icon: "swipe_up"
                label: qsTr("Open or close the launcher")
                value: qsTr("%1 fingers up or down").arg(root.swipeFingers)
            }

            InfoRow {
                last: true
                icon: "swipe_vertical"
                label: qsTr("Show or hide the scratchpad")
                value: qsTr("%1 fingers up or down").arg(root.otherFingers)
            }
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
            }
        }
    }
}
