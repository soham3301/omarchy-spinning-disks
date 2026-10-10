pragma ComponentBehavior: Bound

import QtQuick

// Five wheels in a row (or a column on a vertical bar):
// upload, CPU, memory, disk I/O, download. Upload spins anticlockwise.
Item {
    id: root

    // Usage figures in the units Model.js expects (percent, or Mbit/s for the
    // two network wheels), and whether each wheel has a connection.
    property var values: [0, 0, 0, 0, 0]
    property var online: [true, true, true, true, true]
    property var metrics: ["up", "cpu", "mem", "disk", "down"]
    property var names: ["UP", "CPU", "MEM", "DISK", "DOWN"]
    property real diameter: 24
    property real cell: 36
    property bool vertical: false
    property bool animate: true
    property bool colorOn: false
    property string spectrum: "base"
    property color systemColor: "white"
    property bool showLabels: false
    property color labelColor: "white"
    property string labelFamily: "monospace"
    property real labelSize: 11

    readonly property real labelBlock: showLabels ? labelSize + 8 : 0

    implicitWidth: vertical ? diameter : cell * 5
    implicitHeight: vertical ? cell * 5 : diameter + labelBlock

    Repeater {
        model: 5

        delegate: Item {
            id: slot
            required property int index

            width: root.vertical ? root.width : root.cell
            height: root.vertical ? root.cell : root.height
            x: root.vertical ? 0 : slot.index * root.cell
            y: root.vertical ? slot.index * root.cell : 0

            DiskView {
                x: (slot.width - width) / 2
                y: root.showLabels ? 0 : (slot.height - height) / 2
                diameter: root.diameter
                metric: root.metrics[slot.index]
                value: Number(root.values[slot.index]) || 0
                online: root.online[slot.index] !== false
                colorOn: root.colorOn
                spectrum: root.spectrum
                systemColor: root.systemColor
                animate: root.animate
                spinDirection: slot.index === 0 ? -1 : 1
            }

            Text {
                visible: root.showLabels
                x: (slot.width - width) / 2
                y: root.diameter + 6
                text: root.names[slot.index]
                color: root.labelColor
                font.family: root.labelFamily
                font.pixelSize: root.labelSize
            }
        }
    }
}
