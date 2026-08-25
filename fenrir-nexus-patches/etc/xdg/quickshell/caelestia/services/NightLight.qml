pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Manual on/off toggle over wlsunset (redshift doesn't work under a
// wlroots/Hyprland session - no RandR gamma to hook into - wlsunset is
// the real equivalent, using the wlr-gamma-control protocol). Fixed
// day/night window rather than a lat/long solar calculation, since the
// installer doesn't collect precise geographic coordinates - only a
// timezone - and a Quick Toggle is expected to just flip a persistent
// on/off switch, same as every other entry in Toggles.qml.
Singleton {
    id: root

    property alias enabled: props.enabled

    PersistentProperties {
        id: props
        property bool enabled: false
        reloadableId: "nightLight"
    }

    Process {
        id: proc
        command: ["wlsunset", "-S", "07:00", "-s", "19:00"]
        running: props.enabled
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
