//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Covers the session starting up and raises the lock before uncovering. Imports
// nothing from Caelestia, so a version bump can never wedge the login.
ShellRoot {
    id: root

    // Waits for the shell's own layer, not a timer: slow machines outlast any deadline.
    readonly property string readyLayer: "caelestia-background"
    readonly property int settleMs: 400
    readonly property int fadeMs: 700
    // Nothing may hide the desktop indefinitely if the shell never arrives,
    // but uncovering early would show an unlocked desktop, so wait a long time.
    readonly property int maxWaitMs: 45000

    readonly property string fallback: "/etc/xdg/quickshell/caelestia/assets/wallpaper.webp"
    property string wallpaper: root.fallback
    property bool shellReady: false
    property bool locked: false
    property bool fading: false

    function statePath(): string {
        const state = Quickshell.env("XDG_STATE_HOME");
        if (state && state.length > 0)
            return `${state}/caelestia/wallpaper/path.txt`;
        return `${Quickshell.env("HOME")}/.local/state/caelestia/wallpaper/path.txt`;
    }

    // Same file Caelestia's own Wallpapers service treats as the current
    // wallpaper, so the splash matches whatever the desktop is about to show.
    FileView {
        path: root.statePath()
        printErrors: false
        onLoaded: {
            const wall = text().trim();
            if (wall.length > 0)
                root.wallpaper = wall;
        }
    }

    // Hyprland announces the shell's layer, so subscribe rather than polling
    // hyprctl every 250ms through the slowest part of boot.
    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name === "openlayer" && event.data === root.readyLayer)
                root.shellReady = true;
        }
    }

    // The event is missed if the shell came up first, so check once at start.
    Process {
        id: shellProbe

        running: true
        command: ["sh", "-c", "hyprctl layers | grep -q " + root.readyLayer]
        onExited: code => {
            if (code === 0)
                root.shellReady = true;
        }
    }

    Process {
        id: lockProc

        command: ["caelestia", "shell", "lock", "lock"]
    }

    Process {
        id: lockedProbe

        command: ["sh", "-c", "caelestia shell lock isLocked | grep -q true"]
        onExited: code => {
            if (code === 0)
                root.locked = true;
        }
    }

    // Lock before uncovering. Only ever launched on installed systems, so it
    // always locks.
    onShellReadyChanged: {
        if (root.shellReady)
            lockProc.running = true;
    }

    Timer {
        running: root.shellReady && !root.locked
        interval: 250
        repeat: true
        onTriggered: {
            if (!lockedProbe.running)
                lockedProbe.running = true;
        }
    }

    Timer {
        running: root.locked
        interval: root.settleMs
        onTriggered: root.fading = true
    }

    Timer {
        running: true
        interval: root.maxWaitMs
        onTriggered: root.fading = true
    }

    // Quits even if the fade never runs to completion.
    Timer {
        running: root.fading
        interval: root.fadeMs + 2000
        onTriggered: Qt.quit()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            screen: win.modelData
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            // Never steal keys from the session starting up behind it.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Rectangle {
                anchors.fill: parent
                // Matches the scheme's surface so a missing wallpaper still
                // fades from something deliberate rather than black.
                color: "#000d2a"
                opacity: root.fading ? 0 : 1

                Image {
                    anchors.fill: parent
                    source: `file://${root.wallpaper}`
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.fadeMs
                        // Material standard-decel: quick to start, eased out.
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0, 0, 0, 1, 1, 1]
                    }
                }

                onOpacityChanged: {
                    if (opacity === 0 && win.modelData.name === Quickshell.screens[0].name)
                        Qt.quit();
                }
            }
        }
    }
}
