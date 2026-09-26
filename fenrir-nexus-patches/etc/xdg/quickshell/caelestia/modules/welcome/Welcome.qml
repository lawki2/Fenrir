pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.services
import qs.utils

// Opens once at a new install's first login (every login if "Show at startup" is on), and from
// the launcher's Welcome entry via `caelestia shell welcome open`.
Singleton {
    id: root

    property bool showAtStartup: true
    property bool firstRun: false
    property bool live: false
    // name -> packages, from fenrir-pkg list, so the window never keeps its own copy.
    property var extras: ({})
    property list<string> extraNames: []
    property list<string> installed: []
    property QtObject window: null

    function open(): void {
        if (root.window)
            return;
        root.window = windowComp.createObject(dummy);
        installedProc.running = true;
    }

    function setShowAtStartup(on: bool): void {
        root.showAtStartup = on;
        stateFile.setText(on ? "true\n" : "false\n");
    }

    function install(name: string): void {
        PkgJob.start(["install", name]);
    }

    QtObject {
        id: dummy
    }

    // Survives a shell reload, so reloading doesn't reopen it.
    PersistentProperties {
        id: session

        property bool autoOpened

        reloadableId: "fenrirWelcome"
    }

    FileView {
        id: stateFile

        path: `${Paths.state}/fenrir-welcome`
        printErrors: false
        onLoaded: root.showAtStartup = text().trim() !== "false"
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.firstRun = true;
        }
    }

    // The live ISO opens the installer instead.
    FileView {
        path: "/etc/fenrir-packages.x86_64"
        printErrors: false
        onLoaded: root.live = true
    }

    // Late enough for the files above to have loaded; at login the lock screen still covers it.
    Timer {
        running: !session.autoOpened
        interval: 4000
        onTriggered: {
            session.autoOpened = true;
            if (root.live || !root.showAtStartup)
                return;
            root.open();
            if (root.firstRun)
                root.setShowAtStartup(false);
        }
    }

    Process {
        running: true
        command: ["/usr/lib/fenrir/fenrir-pkg", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.split("\n")) {
                    const [name, ...pkgs] = line.trim().split(/\s+/);
                    if (name && pkgs.length)
                        map[name] = pkgs;
                }
                root.extras = map;
                root.extraNames = Object.keys(map);
            }
        }
    }

    // chwd isn't something to be "installed"; its row always offers to run.
    Process {
        id: installedProc

        command: ["sh", "-c", "/usr/lib/fenrir/fenrir-pkg list | while read -r name pkgs; do [ \"$pkgs\" = chwd ] && continue; pacman -Q $pkgs >/dev/null 2>&1 && echo \"$name\"; done"]
        stdout: StdioCollector {
            onStreamFinished: root.installed = text.split("\n").filter(l => l)
        }
    }

    Connections {
        function onFinished(job: string): void {
            if (job.startsWith("install "))
                installedProc.running = true;
        }

        target: PkgJob
    }

    IpcHandler {
        function open(): void {
            root.open();
        }

        target: "welcome"
    }

    Component {
        id: windowComp

        FloatingWindow {
            id: win

            color: Colours.tPalette.m3surface
            surfaceFormat.opaque: false

            // Nexus's height for this screen, only as wide as the one content column; the pages scroll.
            implicitWidth: Math.min(Math.round(implicitHeight * contentItem.Tokens.sizes.nexus.ratio), contentItem.Tokens.sizes.nexus.maxContentWidth + contentItem.Tokens.padding.extraLarge * 2)
            implicitHeight: Math.round(screen.height * contentItem.Tokens.sizes.nexus.heightMult)
            minimumSize.width: contentItem.Tokens.sizes.nexus.minWidth
            minimumSize.height: contentItem.Tokens.sizes.nexus.minHeight

            contentItem.Config.screen: screen.name
            contentItem.Tokens.screen: screen.name

            title: qsTr("Welcome to Fenrir")

            onVisibleChanged: {
                if (!visible) {
                    root.window = null;
                    destroy();
                }
            }

            WelcomeContent {
                anchors.fill: parent
                anchors.margins: Tokens.padding.extraLarge
            }
        }
    }
}
