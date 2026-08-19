import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config

Item {
    id: root

    property string statusText: "Installing Fenrir…"

    function start(plan): void {
        installProc.command = ["python3", "/usr/lib/fenrir-installer/cli.py", "install", JSON.stringify(plan)];
        installProc.running = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: TokenConfig.appearance.spacing.normal

        Text {
            text: root.statusText
            color: Colours.m3onSurface
            font.family: Fonts.sans
            font.pointSize: TokenConfig.appearance.fontSize.large
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: TokenConfig.appearance.rounding.normal
            color: Colours.m3surfaceContainerLow

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: TokenConfig.appearance.padding.large
                contentWidth: width
                contentHeight: logText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    id: logText
                    width: flick.width
                    wrapMode: Text.Wrap
                    color: Colours.m3onSurface
                    font.family: Fonts.mono
                    font.pointSize: TokenConfig.appearance.fontSize.small
                }

                onContentHeightChanged: flick.contentY = Math.max(0, contentHeight - height)
            }
        }
    }

    Process {
        id: installProc
        stdout: SplitParser {
            onRead: data => {
                logText.text += data + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.statusText = exitCode === 0
                ? "Install complete. You can reboot now."
                : "Install failed — see the log below.";
        }
    }
}
