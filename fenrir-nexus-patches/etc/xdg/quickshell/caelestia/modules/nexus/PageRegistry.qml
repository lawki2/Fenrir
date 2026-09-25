pragma Singleton

import QtQuick
import qs.services

QtObject {
    id: root

    // Fenrir: the sidebar's collapsible groups, in order; a group with one page shows just that page.
    readonly property list<var> categories: [
        { id: "personalise", label: qsTr("Personalise"), icon: "brush" },
        { id: "display", label: qsTr("Screen"), icon: "desktop_windows" },
        { id: "network", label: qsTr("Connectivity"), icon: "lan" },
        { id: "devices", label: qsTr("Devices"), icon: "devices" },
        { id: "input", label: qsTr("Input & language"), icon: "keyboard_alt" },
        { id: "apps", label: qsTr("Apps & notifications"), icon: "grid_view" },
        { id: "system", label: qsTr("System"), icon: "settings" },
        { id: "about", label: qsTr("About"), icon: "info" }
    ]

    // popout: the bar popout mode that opens this page (bar/popouts/Wrapper.qml).
    readonly property list<var> pages: [
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
            label: Chassis.isLaptop ? qsTr("Mouse & touchpad") : qsTr("Mouse"),
            icon: Chassis.isLaptop ? "touchpad_mouse" : "mouse",
            description: Chassis.isLaptop ? qsTr("Pointer speed, scrolling, gestures") : qsTr("Pointer speed, scroll direction"),
            category: "input"
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
