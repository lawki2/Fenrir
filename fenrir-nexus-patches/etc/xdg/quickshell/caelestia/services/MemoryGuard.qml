pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia

// Says which app systemd-oomd closed to free memory, since oomd itself tells the user nothing.
Singleton {
    id: root

    // systemd.catalog's "systemd-oomd killed one or more processes in unit" entry.
    readonly property string killMessageId: "d989611b15e44c9dbf31e3c81256e4ed"
    // Not --user: a volatile journal (the live ISO) has no per-user files, so match our uid instead.
    readonly property string uid: (Quickshell.env("XDG_RUNTIME_DIR") ?? "").match(/^\/run\/user\/(\d+)$/)?.[1] ?? ""
    property int retryMs: 5000
    property real startedAt: 0

    // Handles app2unit's app-<desktop>-<app>-<random>.scope and <app>@<random>.service, and
    // app-<app>-<pid>.scope as apps like Chromium make themselves.
    function appName(unit: string): string {
        const desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") ?? "").split(":")[0];
        let id = unit.replace(/^app-/, "").replace(/(-[0-9a-f]+\.scope|@[0-9a-f]+\.service)$/, "");
        if (desktop && id.startsWith(`${desktop}-`))
            id = id.slice(desktop.length + 1);
        id = id.replace(/\\x([0-9a-f]{2})/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)));
        // Reverse-DNS ids (org.chromium.Chromium) don't always match the entry's file name.
        const short = id.split(".").pop();
        return (DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id) ?? DesktopEntries.heuristicLookup(short))?.name ?? short;
    }

    function report(unit: string): void {
        if (unit.startsWith("app-"))
            Toaster.toast(qsTr("%1 was closed").arg(root.appName(unit)), qsTr("It was using memory the system had run out of"), "memory_alt", Toast.Warning);
        else
            Toaster.toast(qsTr("A background task was closed"), qsTr("%1 was using memory the system had run out of").arg(unit), "memory_alt", Toast.Warning);
    }

    Process {
        id: journal

        running: true
        command: ["journalctl", "--follow", "--lines=0", "--output=json", `MESSAGE_ID=${root.killMessageId}`, root.uid ? `_UID=${root.uid}` : "--user"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const entry = JSON.parse(line);
                    root.report(entry.USER_UNIT ?? entry.UNIT ?? "");
                } catch (e) {}
            }
        }
        onStarted: root.startedAt = Date.now()
        // journalctl only exits if the journal went away underneath it, or never had one to read.
        onExited: {
            if (Date.now() - root.startedAt > 60000)
                root.retryMs = 5000;
            restart.start();
        }
    }

    Timer {
        id: restart

        interval: root.retryMs
        onTriggered: {
            journal.running = true;
            root.retryMs = Math.min(root.retryMs * 2, 300000);
        }
    }
}
