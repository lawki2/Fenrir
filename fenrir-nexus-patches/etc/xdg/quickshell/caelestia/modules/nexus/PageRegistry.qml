pragma Singleton

import QtQuick
import qs.services

QtObject {
    id: root

    // What Nexus lists; PageCompRegistry filters its pages the same way, so the two stay index-aligned.
    readonly property list<var> pages: allPages.filter(p => root.shown(p))

    function shown(page: var): bool {
        return !page.laptopOnly || Chassis.isLaptop;
    }

    // popout: the bar popout mode that opens this page (bar/popouts/Wrapper.qml).
    readonly property list<var> allPages: [
        // Personalise
        {
            label: qsTr("Wallpaper & style"),
            icon: "palette",
            description: qsTr("Wallpaper, fonts, colours"),
            category: "personalise",
            popout: "appearance"
        },
        {
            label: qsTr("Look & feel"),
            icon: "tune",
            description: qsTr("Gaps, rounding, blur, animations"),
            category: "personalise"
        },
        {
            label: qsTr("Desktop"),
            icon: "widgets",
            description: qsTr("Desktop clock, audio visualiser"),
            category: "personalise"
        },
        {
            label: qsTr("Panels"),
            icon: "dock_to_bottom",
            description: qsTr("Dashboard, taskbar, launcher, sidebar"),
            category: "personalise"
        },

        // Display
        {
            label: qsTr("Display"),
            icon: "monitor",
            description: qsTr("Arrangement, resolution, rotation, scale"),
            category: "display"
        },
        {
            label: qsTr("Night light"),
            icon: "nightlight",
            description: qsTr("Warm the screen on a schedule"),
            category: "display"
        },

        // Network
        {
            label: qsTr("Network"),
            icon: "wifi",
            description: qsTr("Wi-Fi, ethernet, VPN"),
            category: "network",
            popout: "network"
        },
        {
            label: qsTr("Firewall"),
            icon: "security",
            description: qsTr("Block unsolicited incoming connections"),
            category: "network"
        },

        // Devices
        {
            label: qsTr("Connected devices"),
            icon: "devices_other",
            description: qsTr("Bluetooth, pairing"),
            category: "devices",
            popout: "bluetooth",
            noFill: true
        },
        {
            label: qsTr("Audio"),
            icon: "volume_up",
            description: qsTr("App volumes, sound devices"),
            category: "devices",
            popout: "audio"
        },
        {
            label: qsTr("Printers"),
            icon: "print",
            description: qsTr("Default printer, test page"),
            category: "devices"
        },

        // Input
        {
            label: qsTr("Mouse & touchpad"),
            icon: "touchpad_mouse",
            description: qsTr("Pointer speed, scrolling, gestures"),
            category: "input",
            laptopOnly: true
        },
        {
            label: qsTr("Keybinds"),
            icon: "keyboard",
            description: qsTr("Rebind Hyprland shortcuts"),
            category: "input"
        },
        {
            label: qsTr("Language & region"),
            icon: "globe",
            description: qsTr("Language, keyboard layouts, date & time, units"),
            category: "input"
        },

        // Apps
        {
            label: qsTr("Apps"),
            icon: "apps",
            description: qsTr("Default apps, favourites, hidden apps"),
            category: "apps"
        },
        {
            label: qsTr("Notifications"),
            icon: "notifications",
            description: qsTr("Notifications, toasts, timeouts"),
            category: "apps"
        },

        // System
        {
            label: qsTr("Power & sleep"),
            icon: "battery_charging_full",
            description: qsTr("Screen lock, sleep, power mode"),
            category: "system"
        },
        {
            label: qsTr("Updates"),
            icon: "update",
            description: qsTr("Software and firmware updates"),
            category: "system"
        },
        {
            label: qsTr("Advanced"),
            icon: "build",
            description: qsTr("Polling, media, lyrics, GPU"),
            category: "system"
        },

        // About
        {
            label: qsTr("About"),
            icon: "info",
            description: qsTr("System information, credits"),
            category: "about"
        }
    ]
}
