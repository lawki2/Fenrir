pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

// The on/off switch itself lives in the quick toggles; this page is the
// schedule and the strength of the effect.
PageBase {
    id: root

    title: qsTr("Night light")

    // HH:MM, 24-hour. Anything else is rejected rather than silently ignored,
    // since a bad time would just make the schedule never fire.
    readonly property var timeRegex: /^([01][0-9]|2[0-3]):[0-5][0-9]$/

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Schedule")
        }

        ToggleRow {
            first: true
            text: qsTr("Automatic night light")
            subtext: qsTr("Turns on and off at the times below. You can still flip it in the quick toggles for the rest of the session.")
            checked: NightLight.scheduleEnabled
            onToggled: NightLight.scheduleEnabled = checked
        }

        TextFieldRow {
            label: qsTr("Turns on at")
            subtext: qsTr("24-hour, for example 20:00")
            value: NightLight.startTime
            smallField: true
            placeholderText: "20:00"
            errorText: qsTr("Use HH:MM")
            validate: text => root.timeRegex.test(text)
            onEditingFinished: value => {
                if (root.timeRegex.test(value))
                    NightLight.startTime = value;
            }
        }

        TextFieldRow {
            last: true
            label: qsTr("Turns off at")
            subtext: qsTr("A time earlier than the one above runs through midnight")
            value: NightLight.endTime
            smallField: true
            placeholderText: "06:00"
            errorText: qsTr("Use HH:MM")
            validate: text => root.timeRegex.test(text)
            onEditingFinished: value => {
                if (root.timeRegex.test(value))
                    NightLight.endTime = value;
            }
        }

        SectionHeader {
            text: qsTr("Strength")
        }

        SliderRow {
            first: true
            last: true
            icon: "light_mode"
            label: qsTr("Colour temperature")
            // Lower is warmer, so the slider reads left-to-right as warmer to
            // cooler; 6500K is daylight, i.e. no visible effect.
            value: (NightLight.temperature - 2500) / 4000
            valueLabel: `${NightLight.temperature}K`
            onMoved: v => NightLight.temperature = Math.round(2500 + v * 4000)
        }
    }
}
