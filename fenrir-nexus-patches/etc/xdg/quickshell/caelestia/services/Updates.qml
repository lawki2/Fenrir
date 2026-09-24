pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia

// Checks for updates in the background; the update itself runs through PkgJob.
Singleton {
    id: root

    // [{name, from, to}]
    property list<var> packages: []
    property list<var> firmware: []
    property bool checking: false
    property bool checkFailed: false
    // checkupdates' own last line, e.g. "Cannot fetch updates".
    property string checkError: ""
    property date lastChecked
    property list<string> updatedNames: []

    // Another job (a welcome-window extra) holds pacman's lock too.
    readonly property bool busy: PkgJob.running
    readonly property bool running: PkgJob.isRunning("update")
    readonly property bool finished: PkgJob.job === "update" && PkgJob.state !== "" && PkgJob.state !== "running"
    readonly property bool succeeded: finished && PkgJob.state === "0"
    readonly property string log: PkgJob.job === "update" ? PkgJob.log : ""
    readonly property string startError: PkgJob.pending === "update" ? PkgJob.startError : ""
    readonly property bool restartNeeded: succeeded && updatedNames.some(n => /^(linux|nvidia|systemd$|glibc$|mesa$|amd-ucode$|intel-ucode$)/.test(n))

    function check(): void {
        if (root.busy || checker.running)
            return;
        root.checking = true;
        checker.running = true;
        firmwareChecker.running = true;
    }

    function update(): void {
        root.updatedNames = root.packages.map(p => p.name);
        PkgJob.start(["update"]);
    }

    function updateInTerminal(): void {
        Quickshell.execDetached(["foot", "--hold", "sudo", "pacman", "-Syu"]);
    }

    function updateFirmware(): void {
        Quickshell.execDetached(["foot", "--hold", "fwupdmgr", "update"]);
    }

    Process {
        id: checker

        command: ["checkupdates", "--nocolor"]
        stdout: StdioCollector {
            id: checkOut
        }
        stderr: StdioCollector {
            id: checkErr
        }
        // 0 lists updates, 2 means none, anything else is a failure to check.
        onExited: code => {
            const before = root.packages.length;
            root.checking = false;
            root.checkFailed = code !== 0 && code !== 2;
            root.checkError = root.checkFailed ? (checkErr.text.trim().split("\n").pop() || qsTr("checkupdates exited with %1").arg(code)) : "";
            if (code === 0)
                root.packages = checkOut.text.split("\n").map(l => l.match(/^(\S+) (\S+) -> (\S+)$/)).filter(m => m).map(m => ({
                                name: m[1],
                                from: m[2],
                                to: m[3]
                            }));
            else if (code === 2)
                root.packages = [];
            root.lastChecked = new Date();
            if (before === 0 && root.packages.length > 0)
                Toaster.toast(qsTr("Updates available"), root.packages.length === 1 ? qsTr("1 update is ready to install in Settings") : qsTr("%1 updates are ready to install in Settings").arg(root.packages.length), "system_update");
        }
    }

    Process {
        id: firmwareChecker

        command: ["fwupdmgr", "get-updates", "--json"]
        stdout: StdioCollector {
            id: firmwareOut
        }
        onExited: {
            try {
                root.firmware = (JSON.parse(firmwareOut.text).Devices ?? []).filter(d => d.Releases?.length).map(d => ({
                                name: d.Name,
                                from: d.Version ?? "",
                                to: d.Releases[0].Version ?? ""
                            }));
            } catch (e) {
                root.firmware = [];
            }
        }
    }

    Connections {
        function onFinished(job: string): void {
            if (job === "update")
                root.check();
        }

        target: PkgJob
    }

    // First check a minute after login, then every six hours.
    Timer {
        running: true
        repeat: true
        interval: 60000
        onTriggered: {
            interval = 6 * 3600 * 1000;
            root.check();
        }
    }
}
