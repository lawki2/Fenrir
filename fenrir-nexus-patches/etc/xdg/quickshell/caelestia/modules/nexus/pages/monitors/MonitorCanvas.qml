pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.modules.nexus.common

// Windows-Settings-style monitor arrangement canvas: renders each monitor
// to scale (real pixel coordinates mapped into the available canvas area),
// draggable with edge-snapping. Real pixel geometry is owned by the parent
// page (MonitorsPage.qml); this component is presentation + interaction
// only - it reports a snapped real-pixel position via positionChanged and
// waits for the parent to feed the updated model back down, rather than
// owning any persistent state itself.
Item {
    id: root

    // [{name, label, x, y, width, height, primary}], real pixel coords
    required property var monitors
    property string selectedMonitor

    signal selected(string name)
    signal positionChanged(string name, real x, real y)

    readonly property real canvasPadding: Tokens.padding.large

    readonly property real minX: root.monitors.length ? root.monitors.reduce((acc, m) => Math.min(acc, m.x), root.monitors[0].x) : 0
    readonly property real minY: root.monitors.length ? root.monitors.reduce((acc, m) => Math.min(acc, m.y), root.monitors[0].y) : 0
    readonly property real maxX: root.monitors.length ? root.monitors.reduce((acc, m) => Math.max(acc, m.x + m.width), root.monitors[0].x + root.monitors[0].width) : 1
    readonly property real maxY: root.monitors.length ? root.monitors.reduce((acc, m) => Math.max(acc, m.y + m.height), root.monitors[0].y + root.monitors[0].height) : 1
    readonly property real spanX: Math.max(1, maxX - minX)
    readonly property real spanY: Math.max(1, maxY - minY)

    readonly property real canvasScale: Math.min((width - canvasPadding * 2) / spanX, (height - canvasPadding * 2) / spanY)

    readonly property real offsetX: (width - spanX * canvasScale) / 2
    readonly property real offsetY: (height - spanY * canvasScale) / 2

    function findByName(name: string): var {
        return root.monitors.find(m => m.name === name) ?? null;
    }

    function rectsOverlap(a: var, b: var): bool {
        return a.x < b.x + b.width && a.x + a.width > b.x && a.y < b.y + b.height && a.y + a.height > b.y;
    }

    function isOverlapping(name: string): bool {
        const m = root.findByName(name);
        if (!m)
            return false;
        return root.monitors.some(other => other.name !== name && root.rectsOverlap(m, other));
    }

    Repeater {
        model: root.monitors.map(m => m.name)

        MonitorBox {
            id: box

            required property string modelData
            readonly property var data: root.findByName(modelData)

            monitorName: modelData
            label: `${data?.name ?? ""}\n${data?.width ?? 0}×${data?.height ?? 0}`
            primary: data?.primary ?? false
            selected: modelData === root.selectedMonitor
            overlapping: root.isOverlapping(modelData)

            width: (data?.width ?? 0) * root.canvasScale
            height: (data?.height ?? 0) * root.canvasScale
            x: root.offsetX + ((data?.x ?? 0) - root.minX) * root.canvasScale
            y: root.offsetY + ((data?.y ?? 0) - root.minY) * root.canvasScale

            onTapped: root.selected(modelData)

            onDragFinished: (boxX, boxY) => {
                const snapPx = Tokens.spacing.large;
                let snappedX = boxX, snappedY = boxY;

                for (const other of root.monitors) {
                    if (other.name === modelData)
                        continue;

                    const ox = root.offsetX + (other.x - root.minX) * root.canvasScale;
                    const oy = root.offsetY + (other.y - root.minY) * root.canvasScale;
                    const ow = other.width * root.canvasScale;
                    const oh = other.height * root.canvasScale;

                    if (Math.abs(boxX - (ox + ow)) < snapPx)
                        snappedX = ox + ow;
                    else if (Math.abs((boxX + box.width) - ox) < snapPx)
                        snappedX = ox - box.width;

                    if (Math.abs(boxY - (oy + oh)) < snapPx)
                        snappedY = oy + oh;
                    else if (Math.abs((boxY + box.height) - oy) < snapPx)
                        snappedY = oy - box.height;
                }

                // Snap instantly rather than waiting for the parent's model
                // to round-trip back down - avoids a visible flash at the
                // raw, pre-snap drop position.
                box.x = snappedX;
                box.y = snappedY;

                const realX = Math.round((snappedX - root.offsetX) / root.canvasScale + root.minX);
                const realY = Math.round((snappedY - root.offsetY) / root.canvasScale + root.minY);
                root.positionChanged(modelData, realX, realY);
            }
        }
    }
}
