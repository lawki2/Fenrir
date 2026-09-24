pragma Singleton

import QtQuick

QtObject {
    id: root

    // popout: the bar popout mode that opens this page (bar/popouts/Wrapper.qml).
    readonly property list<var> pages: [
        // Appearance
        {
            label: qsTr("Wallpaper & style"),
            icon: "palette",
            description: qsTr("Wallpaper, fonts, colours"),
            category: "appearance",
            popout: "appearance"
        },
        {
            label: qsTr("Desktop"),
            icon: "desktop_windows",
            description: qsTr("Desktop clock, audio visualiser"),
            category: "appearance"
        },

        // Connectivity
        {
            label: qsTr("Display"),
            icon: "monitor",
            description: qsTr("Arrangement, resolution, refresh rate"),
            category: "connectivity"
        },
        {
            label: qsTr("Night light"),
            icon: "nightlight",
            description: qsTr("Warm the screen on a schedule"),
            category: "connectivity"
        },
        {
            label: qsTr("Network"),
            icon: "wifi",
            description: qsTr("Wi-Fi, ethernet, VPN"),
            category: "connectivity",
            popout: "network"
        },
        {
            label: qsTr("Firewall"),
            icon: "security",
            description: qsTr("Block unsolicited incoming connections"),
            category: "connectivity"
        },
        {
            label: qsTr("Connected devices"),
            icon: "devices_other",
            description: qsTr("Bluetooth, pairing"),
            category: "connectivity",
            popout: "bluetooth",
            noFill: true
        },
        {
            label: qsTr("Printers"),
            icon: "print",
            description: qsTr("Default printer, test page"),
            category: "connectivity"
        },
        {
            label: qsTr("Audio"),
            icon: "volume_up",
            description: qsTr("App volumes, sound devices"),
            category: "connectivity",
            popout: "audio"
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
            label: qsTr("Plugins"),
            icon: "extension",
            description: qsTr("Manage plugins"),
            category: "system"
        },

        // Shell
        {
            label: qsTr("Panels"),
            icon: "dock_to_bottom",
            description: qsTr("Dashboard, taskbar, launcher, sidebar"),
            category: "shell"
        },
        {
            label: qsTr("Keybinds"),
            icon: "keyboard",
            description: qsTr("Rebind Hyprland shortcuts"),
            category: "shell"
        },
        {
            label: qsTr("Apps"),
            icon: "apps",
            description: qsTr("Default apps, favourites, hidden apps"),
            category: "shell"
        },
        {
            label: qsTr("Services"),
            icon: "build",
            description: qsTr("Poll intervals, lyrics backend"),
            category: "shell"
        },
        {
            label: qsTr("Language & region"),
            icon: "globe",
            description: qsTr("Language, keyboard layouts, date & time, units"),
            category: "shell"
        },

        // About
        {
            label: qsTr("About"),
            icon: "info",
            description: qsTr("System information, credits"),
            category: "about"
        },
    ]
}
