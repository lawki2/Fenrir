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

    // Deliberately not "running: props.enabled" - if wlsunset ever exits
    // on its own (e.g. a real "gamma control failed" error, confirmed to
    // happen on at least one real laptop), Quickshell's own Process
    // implementation sets running back to false itself to reflect
    // reality. That imperative write silently breaks a running: ...
    // binding for good - the toggle would then look enabled forever
    // (props.enabled never changed) while actually doing nothing, with no
    // way to recover short of restarting the whole shell. Driving it
    // imperatively from onEnabledChanged instead means every toggle
    // explicitly sets running fresh, which works regardless of whatever
    // it currently holds.
    onEnabledChanged: proc.running = props.enabled
    // onEnabledChanged only fires on a real change, not the initial value
    // a restored PersistentProperties state sets during construction - so
    // if night light was left on in a previous session, this is needed to
    // actually start wlsunset again on shell startup instead of just
    // showing the toggle as on with nothing running underneath.
    Component.onCompleted: proc.running = props.enabled

    Process {
        id: proc
        command: ["wlsunset", "-S", "07:00", "-s", "19:00"]
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
