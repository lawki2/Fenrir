pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.modules.nexus

// Fenrir: Nexus's page list grouped into collapsible category cards, one open at a time.
// The cards copy upstream NavLocations.qml's page card.
VerticalFadeFlickable {
    id: root

    required property NexusState nState

    property string openCategory

    function pagesOf(category: string): var {
        const idxs = [];
        PageRegistry.pages.forEach((p, i) => {
            if (p.category === category)
                idxs.push(i);
        });
        return idxs;
    }

    function followCurrentPage(): void {
        root.openCategory = PageRegistry.pages[root.nState.currentPageIdx]?.category ?? "";
    }

    topMargin: Tokens.padding.large
    bottomMargin: Tokens.padding.large
    contentHeight: content.implicitHeight

    Component.onCompleted: followCurrentPage()

    Connections {
        function onCurrentPageIdxChanged(): void {
            root.followCurrentPage();
        }

        target: root.nState
    }

    TapHandler {
        onTapped: root.focus = true
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.medium

        Repeater {
            model: PageRegistry.categories.filter(c => root.pagesOf(c.id).length > 0)

            ColumnLayout {
                id: group

                required property var modelData

                readonly property var pageIdxs: root.pagesOf(modelData.id)
                readonly property bool single: pageIdxs.length === 1
                readonly property bool open: !single && root.openCategory === modelData.id

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                NavCard {
                    readonly property var page: group.single ? PageRegistry.pages[group.pageIdxs[0]] : null

                    icon: page?.icon ?? group.modelData.icon
                    label: page?.label ?? group.modelData.label
                    description: page?.description ?? group.pageIdxs.map(i => PageRegistry.pages[i].label).join(", ")
                    noFill: page?.noFill ?? false
                    selected: group.single && group.pageIdxs[0] === root.nState.currentPageIdx
                    accent: !group.single && !group.open && group.pageIdxs.includes(root.nState.currentPageIdx)
                    expandable: !group.single
                    expanded: group.open
                    roundBottom: !group.open

                    onClicked: {
                        if (group.single)
                            root.nState.currentPageIdx = group.pageIdxs[0];
                        else
                            root.openCategory = group.open ? "" : group.modelData.id;
                    }
                }

                Item {
                    Layout.fillWidth: true
                    visible: implicitHeight > 0
                    clip: true
                    implicitHeight: group.open ? pageList.implicitHeight : 0

                    Behavior on implicitHeight {
                        Anim {
                            type: Anim.Standard
                        }
                    }

                    ColumnLayout {
                        id: pageList

                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: Tokens.spacing.extraSmall

                        Repeater {
                            model: group.single ? [] : group.pageIdxs

                            NavCard {
                                required property int modelData
                                required property int index

                                readonly property var page: PageRegistry.pages[modelData]

                                icon: page.icon
                                label: page.label
                                description: page.description
                                noFill: page.noFill ?? false
                                selected: modelData === root.nState.currentPageIdx
                                roundTop: false
                                roundBottom: index === group.pageIdxs.length - 1

                                onClicked: root.nState.currentPageIdx = modelData
                            }
                        }
                    }
                }
            }
        }
    }

    component NavCard: StyledRect {
        id: card

        property string icon
        property string label
        property string description
        property bool noFill
        property bool selected
        property bool accent
        property bool expandable
        property bool expanded
        property bool roundTop: true
        property bool roundBottom: true

        signal clicked

        Layout.fillWidth: true
        implicitHeight: {
            const h = layout.implicitHeight + layout.anchors.margins * 2;
            return h % 2 === 0 ? h : h + 1;
        }

        color: selected ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

        topLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : selected ? Tokens.rounding.extraLargeIncreased : roundTop ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
        topRightRadius: stateLayer.pressed ? Tokens.rounding.medium : selected ? Tokens.rounding.extraLargeIncreased : roundTop ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
        bottomLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : selected ? Tokens.rounding.extraLargeIncreased : roundBottom ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
        bottomRightRadius: stateLayer.pressed ? Tokens.rounding.medium : selected ? Tokens.rounding.extraLargeIncreased : roundBottom ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall

        RadiusBehavior on topLeftRadius {}
        RadiusBehavior on topRightRadius {}
        RadiusBehavior on bottomLeftRadius {}
        RadiusBehavior on bottomRightRadius {}

        StateLayer {
            id: stateLayer

            anchors.fill: parent
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius

            onClicked: card.clicked()
        }

        RowLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            StyledRect {
                Layout.fillHeight: true
                Layout.topMargin: -1
                Layout.bottomMargin: -1
                implicitWidth: height

                radius: Tokens.rounding.full
                color: card.selected || card.accent ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 1

                    text: card.icon
                    color: card.selected || card.accent ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                    grade: 25
                    fill: card.noFill ? 0 : 1
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: card.label
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: card.description
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }

            MaterialIcon {
                visible: card.expandable
                text: "expand_more"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
                rotation: card.expanded ? 180 : 0

                Behavior on rotation {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }
        }
    }

    component RadiusBehavior: Behavior {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
