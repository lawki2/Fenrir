pragma Singleton

import QtQuick

// State for the picker overlay in shell.qml; options are {label, value}. A
// singleton because Loader'd pages can't reach shell.qml's ids.
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
