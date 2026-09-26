pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config

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
    // Package names installed or upgraded since boot, read from pacman's own database.
    property list<string> changedSinceBoot: []
    // pacman's database changed after the last job ended, e.g. a -Syu in a terminal.
    property bool dbMovedOn: false

    // Another job (a welcome-window extra) holds pacman's lock too.
    readonly property bool busy: PkgJob.running
    readonly property bool running: PkgJob.isRunning("update")
    readonly property bool finished: PkgJob.job === "update" && PkgJob.state !== "" && PkgJob.state !== "running"
    readonly property bool succeeded: finished && PkgJob.state === "0"
    readonly property string log: PkgJob.job === "update" ? PkgJob.log : ""
    readonly property string startError: PkgJob.pending === "update" ? PkgJob.startError : ""
    // A failed job stops mattering once pacman has moved on without it.
    readonly property bool failed: finished && !succeeded && !dbMovedOn
    readonly property bool lockFailed: failed && /unable to lock database|could not lock database|db\.lck/.test(log)
    readonly property bool restartNeeded: changedSinceBoot.some(n => /^(linux|nvidia|systemd$|glibc$|mesa$|amd-ucode$|intel-ucode$)/.test(n))

    function check(): void {
        if (root.busy || checker.running)
            return;
        root.checking = true;
        checker.running = true;
        firmwareChecker.running = true;
        root.probeSystem();
    }

    function probeSystem(): void {
        if (!root.busy)
            systemProbe.running = true;
    }

    function update(): void {
        PkgJob.start(["update"]);
    }

    function updateInTerminal(): void {
        root.runInTerminal("sudo pacman -Syu");
    }

    function updateFirmware(): void {
        root.runInTerminal("fwupdmgr update");
    }

    // The configured terminal, started the way the launcher starts terminal apps; it stays open until Enter.
    function runInTerminal(script: string): void {
        Quickshell.execDetached(["app2unit", "--", ...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, "sh", "-c", `${script}; printf '\\n%s ' "$1"; read -r _`, "sh", qsTr("Press Enter to close")]);
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
            const key = root.packages.map(p => `${p.name} ${p.to}`).join("\n");
            if (before === 0 && root.packages.length > 0 && key !== toasted.key) {
                toasted.key = key;
                Toaster.toast(qsTr("Updates available"), root.packages.length === 1 ? qsTr("1 update is ready to install in Settings") : qsTr("%1 updates are ready to install in Settings").arg(root.packages.length), "system_update");
            }
        }
    }

    // Survives the reloads an update causes, so the same updates aren't announced twice.
    PersistentProperties {
        id: toasted

        property string key: ""

        reloadableId: "fenrirUpdatesToast"
    }

    // Directory mtimes in pacman's local db are install times, whatever language pacman prints in.
    Process {
        id: systemProbe

        command: ["sh", "-c", "since=$(uptime -s) && find /var/lib/pacman/local -mindepth 1 -maxdepth 1 -newermt \"$since\" -printf '%f\\n'; [ /var/lib/pacman/local -nt /run/fenrir-pkg/state ] && echo @moved"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.length > 0);
                root.dbMovedOn = lines.includes("@moved");
                root.changedSinceBoot = lines.filter(l => l !== "@moved").map(l => l.replace(/-[^-]+-[^-]+$/, ""));
            }
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
            if (job === "update") {
                root.dbMovedOn = false;
                root.check();
            }
        }

        target: PkgJob
    }

    Component.onCompleted: root.probeSystem()

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
