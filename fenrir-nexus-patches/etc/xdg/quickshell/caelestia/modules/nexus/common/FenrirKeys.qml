pragma Singleton

import QtQuick
import Quickshell

// Turns a variables.lua key combo ("SUPER + SHIFT + Left") into what's printed on the keys.
Singleton {
    id: root

    readonly property var names: ({
            super: qsTr("Super"),
            ctrl: qsTr("Ctrl"),
            shift: qsTr("Shift"),
            alt: qsTr("Alt"),
            left: "←",
            right: "→",
            up: "↑",
            down: "↓",
            equal: "=",
            minus: "−",
            space: qsTr("Space"),
            tab: qsTr("Tab"),
            "return": qsTr("Enter"),
            escape: qsTr("Esc"),
            backspace: qsTr("Backspace"),
            "delete": qsTr("Delete"),
            insert: qsTr("Insert"),
            home: qsTr("Home"),
            end: qsTr("End"),
            page_up: qsTr("Page Up"),
            page_down: qsTr("Page Down"),
            print: qsTr("Print Screen"),
            comma: ",",
            period: ".",
            slash: "/",
            backslash: "\\",
            bracketleft: "[",
            bracketright: "]",
            semicolon: ";",
            apostrophe: "'",
            grave: "`"
        })

    function format(combo: var): string {
        if (!combo)
            return "";
        return String(combo).split("+").map(part => {
            const key = part.trim();
            return root.names[key.toLowerCase()] ?? (key.length === 1 ? key.toUpperCase() : key);
        }).join(" + ");
    }
}
