pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

// Key-capture rebind row. Names match variables.lua's spelling ("TAB", "space")
// so re-capturing an unchanged combo round-trips to the same string.
ConnectedRect {
    id: root

    property string label
    property string subtext
    property string value
    property bool conflict

    signal changed(string newValue)

    function keyName(key: int): string {
        if (key >= Qt.Key_A && key <= Qt.Key_Z)
            return String.fromCharCode(key);
        if (key >= Qt.Key_0 && key <= Qt.Key_9)
            return String.fromCharCode(key);
        for (let n = 1; n <= 12; n++) {
            if (key === Qt["Key_F" + n])
                return "F" + n;
        }
        switch (key) {
        case Qt.Key_Space: return "space";
        case Qt.Key_Tab: return "TAB";
        case Qt.Key_Return:
        case Qt.Key_Enter: return "Return";
        case Qt.Key_Escape: return "Escape";
        case Qt.Key_Backspace: return "BackSpace";
        case Qt.Key_Delete: return "Delete";
        case Qt.Key_Insert: return "Insert";
        case Qt.Key_Home: return "Home";
        case Qt.Key_End: return "End";
        case Qt.Key_PageUp: return "Page_Up";
        case Qt.Key_PageDown: return "Page_Down";
        case Qt.Key_Left: return "Left";
        case Qt.Key_Right: return "Right";
        case Qt.Key_Up: return "Up";
        case Qt.Key_Down: return "Down";
        case Qt.Key_Print: return "Print";
        case Qt.Key_Comma: return "Comma";
        case Qt.Key_Period: return "Period";
        case Qt.Key_Slash: return "slash";
        case Qt.Key_Backslash: return "backslash";
        case Qt.Key_Minus: return "minus";
        case Qt.Key_Equal: return "equal";
        case Qt.Key_BracketLeft: return "bracketleft";
        case Qt.Key_BracketRight: return "bracketright";
        case Qt.Key_Semicolon: return "semicolon";
        case Qt.Key_Apostrophe: return "apostrophe";
        case Qt.Key_QuoteLeft: return "grave";
        case Qt.Key_VolumeUp: return "XF86AudioRaiseVolume";
        case Qt.Key_VolumeDown: return "XF86AudioLowerVolume";
        case Qt.Key_VolumeMute: return "XF86AudioMute";
        case Qt.Key_MediaPlay: return "XF86AudioPlay";
        case Qt.Key_MediaPause: return "XF86AudioPause";
        case Qt.Key_MediaTogglePlayPause: return "XF86AudioPlay";
        case Qt.Key_MediaStop: return "XF86AudioStop";
        case Qt.Key_MediaNext: return "XF86AudioNext";
        case Qt.Key_MediaPrevious: return "XF86AudioPrev";
        case Qt.Key_MonBrightnessUp: return "XF86MonBrightnessUp";
        case Qt.Key_MonBrightnessDown: return "XF86MonBrightnessDown";
        }
        return "";
    }

    function isModifierKey(key: int): bool {
        return key === Qt.Key_Shift || key === Qt.Key_Control || key === Qt.Key_Alt
            || key === Qt.Key_Meta || key === Qt.Key_Super_L || key === Qt.Key_Super_R
            || key === Qt.Key_AltGr;
    }

    // Some binds are modifier-only chords (kbGoToWs = "SUPER"), which only complete
    // on release; tracked held keys, since event.modifiers is unreliable on release.
    function orderedModifierNames(keys: var): var {
        const present = {
            ctrl: false,
            super: false,
            shift: false,
            alt: false
        };
        for (const k of keys) {
            if (k === Qt.Key_Control)
                present.ctrl = true;
            else if (k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R)
                present.super = true;
            else if (k === Qt.Key_Shift)
                present.shift = true;
            else if (k === Qt.Key_Alt || k === Qt.Key_AltGr)
                present.alt = true;
        }
        const parts = [];
        if (present.ctrl)
            parts.push("CTRL");
        if (present.super)
            parts.push("SUPER");
        if (present.shift)
            parts.push("SHIFT");
        if (present.alt)
            parts.push("ALT");
        return parts;
    }

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + Tokens.padding.medium * 2

    RowLayout {
        id: rowLayout

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.label
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.subtext.length > 0
                text: root.subtext
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
            }
        }

        Rectangle {
            id: captureBox

            property bool capturing: false
            property var heldModifiers: []

            Layout.preferredWidth: 190
            Layout.preferredHeight: captureText.implicitHeight + Tokens.padding.small * 2
            radius: Tokens.rounding.small
            color: root.conflict ? Qt.alpha(Colours.palette.m3error, 0.15)
                : captureBox.capturing ? Qt.alpha(Colours.palette.m3primary, 0.12)
                : Colours.tPalette.m3surfaceContainerHighest
            border.width: captureBox.capturing || root.conflict ? 1 : 0
            border.color: root.conflict ? Colours.palette.m3error : Colours.palette.m3primary

            onActiveFocusChanged: {
                if (!captureBox.activeFocus)
                    captureBox.capturing = false;
            }

            Keys.onPressed: event => {
                if (!captureBox.capturing)
                    return;

                event.accepted = true;

                if (root.isModifierKey(event.key)) {
                    if (captureBox.heldModifiers.indexOf(event.key) === -1)
                        captureBox.heldModifiers = captureBox.heldModifiers.concat([event.key]);
                    return;
                }

                if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
                    captureBox.capturing = false;
                    captureBox.heldModifiers = [];
                    return;
                }

                const name = root.keyName(event.key);
                if (name.length === 0)
                    return;

                const parts = [];
                if (event.modifiers & Qt.ControlModifier)
                    parts.push("CTRL");
                if (event.modifiers & Qt.MetaModifier)
                    parts.push("SUPER");
                if (event.modifiers & Qt.ShiftModifier)
                    parts.push("SHIFT");
                if (event.modifiers & Qt.AltModifier)
                    parts.push("ALT");
                parts.push(name);

                captureBox.capturing = false;
                captureBox.heldModifiers = [];
                const combo = parts.join(" + ");
                if (combo !== root.value)
                    root.changed(combo);
            }

            Keys.onReleased: event => {
                if (!captureBox.capturing)
                    return;
                if (!root.isModifierKey(event.key))
                    return;
                if (captureBox.heldModifiers.indexOf(event.key) === -1)
                    return;

                event.accepted = true;

                const heldBeforeRelease = captureBox.heldModifiers;
                const remaining = heldBeforeRelease.filter(k => k !== event.key);

                if (remaining.length > 0) {
                    captureBox.heldModifiers = remaining;
                    return;
                }

                captureBox.capturing = false;
                captureBox.heldModifiers = [];
                const combo = root.orderedModifierNames(heldBeforeRelease).join(" + ");
                if (combo.length > 0 && combo !== root.value)
                    root.changed(combo);
            }

            StyledText {
                id: captureText
                anchors.centerIn: parent
                text: captureBox.capturing ? qsTr("Press a key…") : root.value
                color: captureBox.capturing ? Colours.palette.m3primary : Colours.palette.m3onSurface
                font: Tokens.font.body.small
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    captureBox.capturing = true;
                    captureBox.forceActiveFocus();
                }
            }
        }
    }
}
