pragma Singleton

import QtQuick
import Quickshell
import qs.components.misc

// Whether Super has been held past a short delay, from the SUPER_L press-and-release bind in keybinds.lua.
Singleton {
    id: root

    property bool superHeld
    readonly property bool peeking: superHeld && FenrirShell.dock && !ShellState.forActive().dashboard

    function dispatchGlobal(name: string): void {
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.global("caelestia:${name}")` : `global caelestia:${name}`);
    }

    // A peek stops Super's release from opening the launcher; ending it clears that, since a shadowed launcher bind never would.
    onPeekingChanged: dispatchGlobal(peeking ? "launcherInterrupt" : "launcher")

    Timer {
        id: holdDelay

        interval: 300
        onTriggered: root.superHeld = true
    }

    // A key-up lost to a reload would otherwise leave the drawer open.
    Connections {
        function onConfigReloaded(): void {
            holdDelay.stop();
            root.superHeld = false;
        }

        target: Hypr
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "superHold"
        description: "Super pressed and released, for the workspace drawer"
        onPressed: holdDelay.restart()
        onReleased: {
            holdDelay.stop();
            root.superHeld = false;
        }
    }
}
