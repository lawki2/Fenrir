//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Covers the session starting up and raises the lock before uncovering. Confirms it through
// the isSecure() call that Fenrir's Lock.qml overlay adds, so a Caelestia bump must keep it.
ShellRoot {
    id: root

    readonly property string readyLayer: "caelestia-background"
    readonly property int settleMs: 400
    readonly property int fadeMs: 700
    readonly property int retryMs: 1000
    // Past this without a confirmed lock the session ends; it is never uncovered unlocked.
    readonly property int maxWaitMs: 60000
    readonly property string sessionId: Quickshell.env("XDG_SESSION_ID") || "self"

    readonly property string fallback: "/etc/xdg/quickshell/caelestia/assets/wallpaper.webp"
    property string wallpaper: root.fallback
    property bool shellUp: false
    property bool secure: false
    property bool timedOut: false
    property bool fading: false
    // sddm's password login already authenticated the user, so only that one may uncover on timeout.
    property bool passwordLogin: false

    function statePath(): string {
        const state = Quickshell.env("XDG_STATE_HOME");
        if (state && state.length > 0)
            return `${state}/caelestia/wallpaper/path.txt`;
        return `${Quickshell.env("HOME")}/.local/state/caelestia/wallpaper/path.txt`;
    }

    function requestLock(): void {
        if (!root.secure && !root.timedOut && !lockProc.running)
            lockProc.running = true;
    }

    function giveUp(): void {
        root.timedOut = true;
        if (root.passwordLogin)
            root.fading = true;
        else
            root.endSession();
    }

    // Either one ends the session, and sddm (Relogin=false) then shows its password greeter.
    function endSession(): void {
        Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.exit()" : "exit");
        if (!terminator.running)
            terminator.running = true;
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

    // Fast path only: the retry timer below still locks if this layer never opens.
    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name === "openlayer" && event.data === root.readyLayer)
                root.requestLock();
        }
    }

    Process {
        running: true
        command: ["loginctl", "show-session", root.sessionId, "-p", "Service", "--value"]
        stdout: StdioCollector {
            onStreamFinished: root.passwordLogin = text.trim() === "sddm"
        }
    }

    // Exit code 0 means a caelestia instance answered, whatever it printed.
    Process {
        id: lockProc

        command: ["qs", "-c", "caelestia", "ipc", "call", "lock", "lock"]
        onExited: code => {
            if (code === 0)
                root.shellUp = true;
        }
    }

    // `qs ipc call` prints "true"/"false", and exits 0 even for a missing function.
    Process {
        id: secureProbe

        command: ["qs", "-c", "caelestia", "ipc", "call", "lock", "isSecure"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "true" && !root.timedOut)
                    root.secure = true;
            }
        }
    }

    Timer {
        running: !root.secure && !root.timedOut
        interval: root.retryMs
        repeat: true
        triggeredOnStart: true
        onTriggered: root.requestLock()
    }

    Timer {
        running: root.shellUp && !root.secure && !root.timedOut
        interval: 250
        repeat: true
        onTriggered: {
            if (!secureProbe.running)
                secureProbe.running = true;
        }
    }

    Timer {
        running: root.secure
        interval: root.settleMs
        onTriggered: root.fading = true
    }

    Timer {
        running: !root.secure
        interval: root.maxWaitMs
        onTriggered: root.giveUp()
    }

    Process {
        id: terminator

        command: ["loginctl", "terminate-session", root.sessionId]
    }

    Timer {
        running: root.timedOut && !root.fading
        interval: 5000
        repeat: true
        onTriggered: root.endSession()
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
