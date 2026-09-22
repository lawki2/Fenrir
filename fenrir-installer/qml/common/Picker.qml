pragma Singleton

import QtQuick

// Shared state for the full-page option picker (shell.qml renders the actual
// overlay). Options are {label, value} pairs so the list can show a readable
// name while the page keeps the raw code. A singleton because the rows that
// open it live inside per-page QML files loaded via Loader, which can't reach
// back up to shell.qml's ids directly.
QtObject {
    id: root

    property bool visible: false
    property string title: ""
    property var options: []
    property string selected: ""
    property var callback: null

    function open(title: string, options: var, selected: string, callback: var): void {
        root.title = title;
        root.options = options;
        root.selected = selected;
        root.callback = callback;
        root.visible = true;
    }

    function pick(option: var): void {
        if (root.callback)
            root.callback(option.value);
        root.visible = false;
    }

    function close(): void {
        root.visible = false;
    }
}
