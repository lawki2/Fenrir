//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Runs as the unprivileged "greeter" user inside its own Hyprland instance,
// so it is the only surface on screen: a full-screen overlay that takes
// keyboard focus outright rather than a window competing for it.
ShellRoot {
    id: root

    property var users: []
    property var sessions: []
    property int sessionIndex: 0

    readonly property var session: root.sessions[root.sessionIndex] ?? null

    // Reads the real accounts straight out of passwd: uid 1000+ with a login
    // shell, which is exactly who SDDM would have offered.
    function parsePasswd(text: string): var {
        const out = [];
        for (const line of text.split("\n")) {
            const f = line.split(":");
            if (f.length < 7)
                continue;
            const uid = parseInt(f[2]);
            if (uid < 1000 || uid >= 65534)
                continue;
            if (f[6].endsWith("nologin") || f[6].endsWith("/false"))
                continue;
            out.push({
                name: f[0],
                fullName: f[4].split(",")[0] || f[0]
            });
        }
        return out;
    }

    FileView {
        path: "/etc/passwd"
        onLoaded: root.users = root.parsePasswd(text())
    }

    // One line per session: display name, tab, Exec command.
    Process {
        running: true
        command: ["sh", "-c", "for f in /usr/share/wayland-sessions/*.desktop; do n=$(sed -n 's/^Name=//p' \"$f\" | head -1); e=$(sed -n 's/^Exec=//p' \"$f\" | head -1); [ -n \"$e\" ] && printf '%s\\t%s\\n' \"${n:-$(basename \"$f\" .desktop)}\" \"$e\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.trim().split("\n")) {
                    if (!line.trim())
                        continue;
                    const parts = line.split("\t");
                    if (parts.length >= 2)
                        out.push({
                            name: parts[0],
                            exec: parts[1]
                        });
                }
                root.sessions = out;
                // Prefer the uwsm-managed session, which is what the live ISO
                // autologs into; falling back to whatever is first.
                const preferred = out.findIndex(s => s.exec.includes("uwsm"));
                root.sessionIndex = preferred >= 0 ? preferred : 0;
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            screen: win.modelData
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            // Nexus scopes both per screen; without them Config and Tokens
            // warn when read from a singleton and use the wrong screen.
            contentItem.Config.screen: win.modelData.name
            contentItem.Tokens.screen: win.modelData.name

            Image {
                anchors.fill: parent
                source: "file:///etc/xdg/quickshell/caelestia/assets/wallpaper.webp"
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }

            // Keeps the form readable over an arbitrary wallpaper without
            // hiding it entirely.
            Rectangle {
                anchors.fill: parent
                color: Colours.palette.m3surface
                opacity: 0.55
            }

            LoginForm {
                anchors.centerIn: parent
                // Scales like the lock screen does, off the screen's height.
                screenHeight: win.modelData.height
                // Only the first screen gets the form; the rest just show the
                // wallpaper, so a multi-monitor setup has one place to type.
                visible: win.modelData.name === Quickshell.screens[0].name
                users: root.users
                session: root.session
                sessionName: root.session ? root.session.name : ""
                onCycleSession: {
                    if (root.sessions.length > 1)
                        root.sessionIndex = (root.sessionIndex + 1) % root.sessions.length;
                }
            }
        }
    }
}
