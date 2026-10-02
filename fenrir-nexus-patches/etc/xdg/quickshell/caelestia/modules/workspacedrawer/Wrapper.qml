pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar.components.workspaces

// The workspace row at the top middle, shown for a moment after a switch and while Super is held; dock style only.
Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property bool focused: Hypr.focusedMonitor === monitor
    readonly property bool perMonitor: GlobalConfig.bar.workspaces.perMonitorWorkspaces
    // The workspace this screen's row follows, as in Workspaces.qml; 0 until Hyprland reports it.
    readonly property int activeWsId: (perMonitor ? monitor?.activeWorkspace : Hypr.focusedWorkspace)?.id ?? 0
    property int lastWsId

    property bool fullscreen
    readonly property bool peek: WorkspacePeek.superHeld && focused
    // Clicks and hover-to-stay only follow a Super peek, so the brief show after a switch can't catch clicks.
    property bool stayOnHover
    readonly property bool interactive: peek || (stayOnHover && hover.hovered)
    readonly property bool shouldBeActive: FenrirShell.dock && !screenState.dashboard && !fullscreen && ((recentSwitch.running && (perMonitor || focused)) || interactive)
    property real offsetScale: shouldBeActive ? 0 : 1

    visible: offsetScale < 1
    anchors.topMargin: (-implicitHeight - 5) * offsetScale
    implicitWidth: content.implicitWidth + Tokens.padding.large * 2
    implicitHeight: content.implicitHeight + Tokens.padding.large * 2
    opacity: 1 - offsetScale

    // Only a move from one known workspace to another counts, so start-up doesn't open it.
    onActiveWsIdChanged: {
        if (activeWsId === 0)
            return;
        if (lastWsId !== 0 && lastWsId !== activeWsId)
            recentSwitch.restart();
        lastWsId = activeWsId;
    }

    Component.onCompleted: lastWsId = activeWsId
    onPeekChanged: {
        if (peek)
            stayOnHover = true;
    }
    // Column moves send no window event, so refresh positions for the icon order.
    onShouldBeActiveChanged: {
        if (shouldBeActive)
            Hyprland.refreshToplevels();
    }

    Behavior on offsetScale {
        Anim {}
    }

    Timer {
        id: recentSwitch

        interval: 1000
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (!hovered && !root.peek)
                root.stayOnHover = false;
        }
    }

    Loader {
        id: content

        anchors.centerIn: parent
        active: FenrirShell.dock

        sourceComponent: Workspaces {
            screen: root.screen
            fullscreen: false
            vertical: false
        }
    }
}
