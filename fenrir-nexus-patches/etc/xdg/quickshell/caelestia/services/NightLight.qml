pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// hyprsunset holds one temperature while it runs. The schedule is ours, so
// `enabled` is always the real state the quick toggle shows.
Singleton {
    id: root

    property alias enabled: props.enabled
    property alias temperature: props.temperature
    property alias scheduleEnabled: props.scheduleEnabled
    property alias startTime: props.startTime
    property alias endTime: props.endTime

    // Tracks the schedule's own last verdict, so only a transition writes to
    // enabled - a manual override then survives until the next one.
    property int lastVerdict: -1
    // Nothing runs until the saved settings are read, so login never starts with the defaults.
    property bool loaded: false

    FileView {
        id: file

        path: `${Paths.state}/nightlight.json`
        printErrors: false
        onLoaded: root.start()
        onLoadFailed: root.start()
        onAdapterUpdated: {
            if (root.loaded)
                writeAdapter();
        }

        JsonAdapter {
            id: props

            property bool enabled: false
            property int temperature: 4000
            property bool scheduleEnabled: false
            property string startTime: "20:00"
            property string endTime: "06:00"
        }
    }

    function minutesOf(hhmm: string): int {
        const parts = hhmm.split(":");
        if (parts.length !== 2)
            return -1;
        const h = parseInt(parts[0]);
        const m = parseInt(parts[1]);
        if (isNaN(h) || isNaN(m) || h < 0 || h > 23 || m < 0 || m > 59)
            return -1;
        return h * 60 + m;
    }

    function inWindow(): bool {
        const start = root.minutesOf(props.startTime);
        const end = root.minutesOf(props.endTime);
        if (start < 0 || end < 0 || start === end)
            return false;
        const now = new Date();
        const mins = now.getHours() * 60 + now.getMinutes();
        // A window that ends before it starts runs through midnight.
        return start < end ? (mins >= start && mins < end) : (mins >= start || mins < end);
    }

    function applySchedule(): void {
        if (!props.scheduleEnabled)
            return;
        const verdict = root.inWindow() ? 1 : 0;
        if (verdict === root.lastVerdict)
            return;
        root.lastVerdict = verdict;
        props.enabled = verdict === 1;
    }

    function restart(): void {
        proc.running = false;
        proc.running = props.enabled;
    }

    // The schedule settles `enabled` first, so hyprsunset starts at most once. Rewriting the
    // file also creates it on first run and replaces a corrupt one with the values in use.
    function start(): void {
        if (root.loaded)
            return;
        if (props.temperature < 1000 || props.temperature > 20000)
            props.temperature = 4000;
        if (root.minutesOf(props.startTime) < 0)
            props.startTime = "20:00";
        if (root.minutesOf(props.endTime) < 0)
            props.endTime = "06:00";
        root.applySchedule();
        root.loaded = true;
        root.restart();
        Qt.callLater(() => file.writeAdapter());
    }

    // Not "running: props.enabled": if hyprsunset dies, Quickshell writes running
    // itself and silently breaks the binding.
    onEnabledChanged: {
        if (root.loaded)
            root.restart();
    }

    // Retuned over IPC rather than restarted, which would flash. Throttled, not
    // debounced, so dragging the slider previews live.
    onTemperatureChanged: {
        if (proc.running && !retune.running)
            retune.start();
    }

    Timer {
        id: retune

        interval: 100
        onTriggered: Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(props.temperature)])
    }

    onScheduleEnabledChanged: {
        root.lastVerdict = -1;
        if (root.loaded)
            root.applySchedule();
    }

    Timer {
        running: root.loaded && props.scheduleEnabled
        interval: 30000
        repeat: true
        onTriggered: root.applySchedule()
    }

    Process {
        id: proc

        command: ["hyprsunset", "-t", String(props.temperature)]
    }

    IpcHandler {
        function isEnabled(): bool {
            return props.enabled;
        }

        function toggle(): void {
            props.enabled = !props.enabled;
        }

        function enable(): void {
            props.enabled = true;
        }

        function disable(): void {
            props.enabled = false;
        }

        target: "nightLight"
    }
}
