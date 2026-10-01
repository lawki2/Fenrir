pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services

// A looping sketch of the scrolling layout for the tour; each scene is a list of frames.
StyledClippingRect {
    id: root

    property string scene
    // The scene on screen, swapped in by play() with motion off so it doesn't fly in from the last one.
    property string playing
    property bool jumping
    property int step

    // Frame: `cols` are [width in screens, windows top to bottom], `below` the next workspace down,
    // `scroll` how far the row has slid (screens), `row` the workspace in view, `float` a lifted-out window.
    readonly property var scenes: {
        const third = 1 / 3;
        const two = [[0.5, "a"], [0.5, "b"]];
        const four = [[0.5, "a"], [0.5, "b"], [0.5, "c"], [0.5, "d"]];
        const below = [[third, "c"], [2 * third, "d"]];
        return {
            row: [
                { cols: [[1, "a"]], focus: "a" },
                { cols: two, focus: "b" },
                { cols: [[0.5, "a"], [0.5, "b"], [0.5, "c"]], scroll: 0.5, focus: "c" }
            ],
            focus: [
                { cols: four, focus: "a" },
                { cols: four, focus: "b" },
                { cols: four, scroll: 0.5, focus: "c" },
                { cols: four, scroll: 1, focus: "d" },
                { cols: four, scroll: 1, focus: "c" },
                { cols: four, scroll: 0.5, focus: "b" }
            ],
            // [width, scroll]: the row scrolls only as far as the focused column needs, as Fenrir does by default.
            width: [[0.35, 0], [0.5, 0], [0.65, 0.15], [1, 0.5], [0.5, 0.5]].map(f => ({ cols: [[0.5, "a"], [f[0], "b"], [0.5, "c"]], scroll: f[1], focus: "b" })),
            rearrange: [
                { cols: [[third, "a"], [third, "b"], [third, "c"]], focus: "a" },
                { cols: [[third, "b"], [third, "a"], [third, "c"]], focus: "a" },
                { cols: [[third, "b"], [third, "c", "a"]], focus: "a" },
                { cols: [[third, "b"], [third, "a"], [third, "c"]], focus: "a" }
            ],
            // Each workspace holds for two beats so the slide doesn't run non-stop.
            workspaces: [
                { cols: two, below: below, focus: "a" },
                { cols: two, below: below, focus: "a" },
                { cols: two, below: below, row: 1, focus: "c" },
                { cols: two, below: below, row: 1, focus: "c" }
            ],
            float: [
                { cols: two, focus: "a" },
                { cols: [[1, "b"]], float: "a", focus: "a" },
                { cols: two, focus: "a" },
                { cols: [[1, "b"]], focus: "b" }
            ]
        };
    }
    readonly property var frames: root.scenes[root.playing] ?? []
    readonly property var frame: root.frames[root.step] ?? {}
    readonly property real gap: Tokens.spacing.small

    // A window's spot in frame f, in screens across and rows down; null when it isn't in that frame.
    function spotIn(f: var, id: string): var {
        if (f.float === id)
            return { x: 0.2, y: 0.14, w: 0.45, h: 0.66, row: f.row ?? 0 };
        const rows = [f.cols ?? [], f.below ?? []];
        for (let r = 0; r < rows.length; r++) {
            let left = 0;
            for (const col of rows[r]) {
                const slot = col.indexOf(id);
                if (slot > 0)
                    return { x: left, y: (slot - 1) / (col.length - 1), w: col[0], h: 1 / (col.length - 1), row: r };
                left += col[0];
            }
        }
        return null;
    }

    // Relative to the view; a window missing from this frame waits, hidden, where it next shows up.
    function placeOf(id: string): var {
        let p = root.spotIn(root.frame, id);
        const shown = p !== null;
        for (let k = 1; !p && k < root.frames.length; k++)
            p = root.spotIn(root.frames[(root.step + k) % root.frames.length], id);
        p = p ?? { x: 0, y: 0, w: 1, h: 1, row: 0 };
        return {
            x: p.x - (root.frame.scroll ?? 0),
            y: p.y,
            w: p.w,
            h: p.h,
            row: p.row - (root.frame.row ?? 0),
            shown: shown
        };
    }

    function play(): void {
        root.jumping = true;
        root.playing = root.scene;
        root.step = 0;
        root.jumping = false;
        if (ticker.running)
            ticker.restart();
    }

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer
    border.width: 1
    border.color: Colours.palette.m3outlineVariant
    contentUnderBorder: true

    onSceneChanged: root.play()
    Component.onCompleted: root.play()

    Timer {
        id: ticker

        interval: 1400
        repeat: true
        running: root.visible && root.frames.length > 1
        onTriggered: root.step = (root.step + 1) % root.frames.length
    }

    Repeater {
        model: ["a", "b", "c", "d"]

        Rectangle {
            id: win

            required property string modelData
            readonly property var place: root.placeOf(modelData)
            readonly property bool focused: root.frame.focus === modelData
            readonly property bool floating: root.frame.float === modelData

            // Shares of the screen (fr in rows), animated between frames; the diagram's size maps them to pixels.
            property real fx: place.x
            property real fy: place.y
            property real fw: place.w
            property real fh: place.h
            property real fr: place.row

            x: root.gap + fx * (root.width - root.gap)
            y: root.gap + fy * (root.height - root.gap) + fr * root.height
            width: fw * (root.width - root.gap) - root.gap
            height: fh * (root.height - root.gap) - root.gap
            opacity: place.shown ? 1 : 0
            scale: place.shown ? 1 : 0.8
            z: floating ? 2 : focused ? 1 : 0
            radius: Tokens.rounding.small
            color: focused ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

            Behavior on fx {
                enabled: !root.jumping

                Anim {}
            }
            Behavior on fy {
                enabled: !root.jumping

                Anim {}
            }
            Behavior on fw {
                enabled: !root.jumping

                Anim {}
            }
            Behavior on fh {
                enabled: !root.jumping

                Anim {}
            }
            Behavior on fr {
                enabled: !root.jumping

                Anim {}
            }
            Behavior on scale {
                enabled: !root.jumping

                Anim {}
            }
            Behavior on opacity {
                enabled: !root.jumping

                Anim {
                    type: Anim.DefaultEffects
                }
            }
            Behavior on color {
                enabled: !root.jumping

                CAnim {}
            }

            Elevation {
                anchors.fill: parent
                z: -1
                radius: win.radius
                level: 2
                opacity: win.floating ? 1 : 0

                Behavior on opacity {
                    enabled: !root.jumping

                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }
        }
    }
}
