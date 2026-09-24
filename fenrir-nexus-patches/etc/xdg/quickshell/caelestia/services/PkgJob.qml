pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Starts jobs in /usr/lib/fenrir/fenrir-pkg and follows them through /run/fenrir-pkg. They run
// outside the shell, so this picks a job back up if the shell reloads while it's running.
Singleton {
    id: root

    // "update" or "install <extra>"; the one waiting on the password prompt counts too.
    readonly property string current: starter.running ? pending : job
    property string job: ""
    // "running", or the job's exit code once done.
    property string state: ""
    property string log: ""
    property string startError: ""
    property string pending: ""

    readonly property bool running: state === "running" || starter.running

    signal finished(job: string, succeeded: bool)

    function start(args: list<string>): void {
        root.startError = "";
        root.pending = args.join(" ");
        starter.command = ["pkexec", "/usr/lib/fenrir/fenrir-pkg"].concat(args);
        starter.running = true;
    }

    function isRunning(job: string): bool {
        return root.running && root.current === job;
    }

    function readFiles(): void {
        jobFile.reload();
        stateFile.reload();
        logFile.reload();
    }

    Process {
        id: starter

        stderr: StdioCollector {
            id: starterErr
        }
        // pkexec exits 126 when the password prompt is dismissed.
        onExited: code => {
            if (code === 126)
                root.startError = qsTr("Cancelled");
            else if (code !== 0)
                root.startError = starterErr.text.trim() || qsTr("It couldn't start");
            root.readFiles();
        }
    }

    FileView {
        id: jobFile

        path: "/run/fenrir-pkg/job"
        printErrors: false
        onLoaded: root.job = text().trim()
    }

    FileView {
        id: stateFile

        path: "/run/fenrir-pkg/state"
        printErrors: false
        onLoaded: {
            const was = root.state;
            root.state = text().trim();
            if (was === "running" && root.state !== "running")
                root.finished(root.job, root.state === "0");
        }
        onLoadFailed: root.state = ""
    }

    FileView {
        id: logFile

        path: "/run/fenrir-pkg/log"
        printErrors: false
        onLoaded: root.log = text()
    }

    Timer {
        running: root.running
        repeat: true
        interval: 700
        onTriggered: root.readFiles()
    }

    // Called by fenrir-settings' pacman hooks (fenrir-update-guard) around any transaction that
    // changes shell files, whether it came from the Updates page or a terminal.
    IpcHandler {
        function pause(): void {
            Quickshell.watchFiles = false;
        }

        function reload(): void {
            Quickshell.watchFiles = true;
            Quickshell.reload(true);
        }

        // Starts the new shell only once this one is gone; `caelestia shell -d` won't start beside it.
        function restart(): void {
            Quickshell.execDetached(["sh", "-c", "qs -c caelestia kill; for i in $(seq 50); do qs -c caelestia list 2>/dev/null | grep -q '^Instance' || break; sleep 0.1; done; caelestia shell -d"]);
        }

        target: "fenrirUpdates"
    }

    Component.onCompleted: root.readFiles()
}
