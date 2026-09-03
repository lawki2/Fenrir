pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Colours")
    isSubPage: true

    readonly property bool isDynamic: selectedName === "dynamic"

    property string selectedName: Colours.scheme
    property string selectedFlavour: Colours.flavour
    property string selectedMode: Colours.light ? "light" : "dark"
    property string selectedVariant: Colours.variant || "vibrant"

    // { name: { flavour: coloursObj } }, fetched once from `caelestia scheme list`
    property var schemeData: ({})
    property list<MenuItem> flavourItems: []
    property list<string> flavourValues: []

    readonly property list<MenuItem> modeItems: [
        MenuItem {
            text: qsTr("Light")
        },
        MenuItem {
            text: qsTr("Dark")
        }
    ]
    readonly property list<string> modeValues: ["light", "dark"]

    readonly property list<MenuItem> variantItems: [
        MenuItem {
            text: qsTr("Tonal spot")
        },
        MenuItem {
            text: qsTr("Vibrant")
        },
        MenuItem {
            text: qsTr("Expressive")
        },
        MenuItem {
            text: qsTr("Fidelity")
        },
        MenuItem {
            text: qsTr("Fruit salad")
        },
        MenuItem {
            text: qsTr("Monochrome")
        },
        MenuItem {
            text: qsTr("Neutral")
        },
        MenuItem {
            text: qsTr("Rainbow")
        },
        MenuItem {
            text: qsTr("Content")
        }
    ]
    readonly property list<string> variantValues: ["tonalspot", "vibrant", "expressive", "fidelity", "fruitsalad", "monochrome", "neutral", "rainbow", "content"]

    // "dynamic"'s "flavours" are contrast levels (default/hard), not real
    // palettes, but caelestia scheme list already reports them the same
    // shape as every other scheme, so the same flavour mechanism covers
    // both - only the row label changes.
    function refreshFlavourItems(): void {
        const flavours = Object.keys(root.schemeData[root.selectedName] ?? {}).sort();
        const items = [];
        for (const f of flavours)
            items.push(menuItemComp.createObject(root, {
                text: f.slice(0, 1).toUpperCase() + f.slice(1)
            }));
        root.flavourItems = items;
        root.flavourValues = flavours;
        if (flavours.length && !flavours.includes(root.selectedFlavour))
            root.selectedFlavour = flavours[0];
    }

    function apply(): void {
        Colours.setScheme(root.selectedName, root.selectedFlavour, root.selectedMode, root.selectedVariant);
    }

    function selectScheme(name: string): void {
        root.selectedName = name;
        root.refreshFlavourItems();
        root.apply();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        Component {
            id: menuItemComp

            MenuItem {}
        }

        Process {
            id: listProc

            running: true
            command: ["caelestia", "scheme", "list"]
            stdout: StdioCollector {
                id: listCollector
            }
            onExited: exitCode => {
                // schemeData already defaults to {} - on any failure just
                // leave it there rather than letting a malformed/empty
                // response (a CLI error, an upstream format change) throw
                // out of JSON.parse and take the whole page down with it.
                if (exitCode !== 0)
                    return;
                try {
                    root.schemeData = JSON.parse(listCollector.text);
                    root.refreshFlavourItems();
                } catch (e) {
                    // leave schemeData as {} - not a crash, just no schemes shown
                }
            }
        }

        StyledText {
            text: qsTr("Scheme")
            font: Tokens.font.title.small
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.large

            Repeater {
                model: Object.keys(root.schemeData).sort()

                SchemeSwatch {
                    required property string modelData

                    readonly property var firstFlavour: {
                        const flavours = root.schemeData[modelData] ?? {};
                        const keys = Object.keys(flavours);
                        return keys.length ? flavours[keys[0]] : null;
                    }

                    text: modelData === "dynamic" ? qsTr("Dynamic") : modelData.slice(0, 1).toUpperCase() + modelData.slice(1)
                    selected: modelData === root.selectedName
                    primaryColour: firstFlavour ? `#${firstFlavour.primary}` : "transparent"
                    secondaryColour: firstFlavour ? `#${firstFlavour.secondary}` : "transparent"
                    tertiaryColour: firstFlavour ? `#${firstFlavour.tertiary}` : "transparent"
                    surfaceColour: firstFlavour ? `#${firstFlavour.surface}` : "transparent"

                    onClicked: root.selectScheme(modelData)
                }
            }
        }

        SelectRow {
            visible: root.flavourItems.length > 0
            first: true
            label: root.isDynamic ? qsTr("Contrast") : qsTr("Flavour")
            menuItems: root.flavourItems
            active: root.flavourItems[Math.max(0, root.flavourValues.indexOf(root.selectedFlavour))]
            onSelected: item => {
                root.selectedFlavour = root.flavourValues[root.flavourItems.indexOf(item)];
                root.apply();
            }
        }

        SelectRow {
            last: root.isDynamic
            label: qsTr("Mode")
            menuItems: root.modeItems
            active: root.modeItems[Math.max(0, root.modeValues.indexOf(root.selectedMode))]
            onSelected: item => {
                root.selectedMode = root.modeValues[root.modeItems.indexOf(item)];
                root.apply();
            }
        }

        SelectRow {
            visible: !root.isDynamic
            last: true
            label: qsTr("Variant")
            menuItems: root.variantItems
            active: root.variantItems[Math.max(0, root.variantValues.indexOf(root.selectedVariant))]
            onSelected: item => {
                root.selectedVariant = root.variantValues[root.variantItems.indexOf(item)];
                root.apply();
            }
        }
    }
}
