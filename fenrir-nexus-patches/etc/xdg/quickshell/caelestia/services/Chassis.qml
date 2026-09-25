pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// The firmware's chassis type, as systemd reads it; a laptop battery covers firmware that mislabels it.
Singleton {
    id: root

    // Read up front, so Nexus's laptop-only settings don't pop in late.
    readonly property int chassisType: parseInt(chassisFile.text()) || 0
    // SMBIOS portable, laptop, notebook, sub-notebook, tablet, convertible and detachable.
    readonly property bool isLaptop: [8, 9, 10, 14, 30, 31, 32].includes(root.chassisType) || UPower.displayDevice.isLaptopBattery

    FileView {
        id: chassisFile

        path: "/sys/class/dmi/id/chassis_type"
        blockLoading: true
        printErrors: false
    }
}
