pragma Singleton

import QtQuick

// Shared state for the full-page option picker (shell.qml renders the
// actual overlay). SelectField.qml opens it; picking an option invokes the
// stored callback and closes it. A singleton because SelectField instances
// live inside per-page QML files loaded via Loader, which can't reach back
// up to shell.qml's ids directly.
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

    function pick(option: string): void {
        if (root.callback)
            root.callback(option);
        root.visible = false;
    }

    function close(): void {
        root.visible = false;
    }
}
