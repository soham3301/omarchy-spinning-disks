pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "Model.js" as Model

// One spinning wheel. Speed and colour follow `value` (see Model.js).
Item {
    id: root

    property string metric: "cpu"
    property real value: 0
    // Network wheels go grey and slowly stop when this is false.
    property bool online: true
    property bool colorOn: false
    property string spectrum: "base"
    property color systemColor: "white"
    property real diameter: 24
    property bool animate: true
    // 1 = clockwise, -1 = anticlockwise.
    property int spinDirection: 1
    // Qt's conical gradient is assumed to sweep anticlockwise. If the bright
    // comet leads instead of trails, set this to -1.
    property int gradientSign: 1
    property real angle: 0

    // Smoothed copies, so colour and speed glide instead of jumping.
    property real shown: value
    property real alive: online ? 1 : 0

    readonly property real r: diameter / 2
    readonly property real strokeW: Math.max(1, diameter * 0.045)
    readonly property real outerR: r - strokeW / 2
    readonly property real glintR: outerR - strokeW * 0.5
    readonly property real hubR: r * 0.2
    readonly property real cometW: Math.max(1.4, diameter * 0.08)
    readonly property real rps: alive * (0.6 + 5.4 * Model.speedLevel(metric, shown))
    readonly property real spin: rps / 6
    readonly property var baseRgb: colorOn ? Model.colorFor(metric, shown, spectrum) : [systemColor.r, systemColor.g, systemColor.b]
    readonly property var rgb: Model.mix(baseRgb, Model.GREY, 1 - alive)
    readonly property var lite: Model.lighten(rgb, 0.45)
    readonly property real tail: Math.min(0.45, (0.5 + spin * 2.2) / (2 * Math.PI))
    readonly property real ghostStep: rps * 3.6
    readonly property int ghostCount: 1 + Math.round(spin * 4)

    function tint(c, a) {
        return Qt.rgba(c[0], c[1], c[2], a);
    }

    width: diameter
    height: diameter
    layer.enabled: true
    layer.samples: 4

    Behavior on shown {
        NumberAnimation {
            duration: 800
            easing.type: Easing.OutCubic
        }
    }

    // Losing the network slows the wheel to a stop over a few seconds.
    Behavior on alive {
        NumberAnimation {
            duration: 3000
            easing.type: Easing.InOutQuad
        }
    }

    FrameAnimation {
        running: root.animate && root.visible && root.rps > 0.001
        onTriggered: root.angle = (root.angle + root.rps * 360 * frameTime) % 360
    }

    // Body: translucent ring with a see-through hub.
    Shape {
        anchors.fill: parent

        ShapePath {
            fillRule: ShapePath.OddEvenFill
            fillColor: root.tint(root.rgb, 0.22)
            strokeColor: root.tint(root.rgb, 0.95)
            strokeWidth: root.strokeW
            startX: root.r + root.outerR
            startY: root.r

            PathAngleArc {
                centerX: root.r
                centerY: root.r
                radiusX: root.outerR
                radiusY: root.outerR
                startAngle: 0
                sweepAngle: 360
            }
            PathMove {
                x: root.r + root.hubR
                y: root.r
            }
            PathAngleArc {
                centerX: root.r
                centerY: root.r
                radiusX: root.hubR
                radiusY: root.hubR
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    // Fine grooves.
    Repeater {
        model: [0.55, 0.7, 0.85]

        delegate: Rectangle {
            id: groove
            required property real modelData
            anchors.centerIn: parent
            width: root.diameter * groove.modelData
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 0.5
            border.color: root.tint(root.rgb, 0.16)
        }
    }

    // Mirrors the artwork for anticlockwise wheels, so the comet still trails.
    Item {
        anchors.fill: parent
        transform: Scale {
            origin.x: root.r
            origin.y: root.r
            xScale: root.spinDirection * root.gradientSign
        }

        // Everything that rotates.
        Item {
            id: rotor
            anchors.fill: parent
            rotation: root.gradientSign * root.angle

            // Two opposite CD-style glints. Extra ghost copies trail behind and
            // blend into a smear at high speed.
            Repeater {
                model: 5

                delegate: Shape {
                    id: ghost
                    required property int index
                    anchors.fill: parent
                    z: -ghost.index
                    rotation: -root.gradientSign * ghost.index * root.ghostStep
                    visible: ghost.index < root.ghostCount
                    opacity: ghost.index === 0 ? 1 : 0.55 / (ghost.index + 1)

                    ShapePath {
                        fillRule: ShapePath.OddEvenFill
                        strokeColor: "transparent"
                        startX: root.r + root.glintR
                        startY: root.r
                        fillGradient: ConicalGradient {
                            centerX: root.r
                            centerY: root.r
                            angle: 0

                            GradientStop { position: 0.0; color: root.tint(root.lite, 0.9) }
                            GradientStop { position: 0.12; color: root.tint(root.lite, 0) }
                            GradientStop { position: 0.499; color: root.tint(root.lite, 0) }
                            GradientStop { position: 0.5; color: root.tint(root.lite, 0.9) }
                            GradientStop { position: 0.62; color: root.tint(root.lite, 0) }
                            GradientStop { position: 1.0; color: root.tint(root.lite, 0) }
                        }

                        PathAngleArc {
                            centerX: root.r
                            centerY: root.r
                            radiusX: root.glintR
                            radiusY: root.glintR
                            startAngle: 0
                            sweepAngle: 360
                        }
                        PathMove {
                            x: root.r + root.hubR
                            y: root.r
                        }
                        PathAngleArc {
                            centerX: root.r
                            centerY: root.r
                            radiusX: root.hubR
                            radiusY: root.hubR
                            startAngle: 0
                            sweepAngle: 360
                        }
                    }
                }
            }

            // Rim comet: a bright arc whose tail grows with speed.
            Shape {
                anchors.fill: parent

                ShapePath {
                    fillRule: ShapePath.OddEvenFill
                    strokeColor: "transparent"
                    startX: root.r + root.outerR
                    startY: root.r
                    fillGradient: ConicalGradient {
                        centerX: root.r
                        centerY: root.r
                        angle: 0

                        GradientStop { position: 0.0; color: root.tint(root.lite, 0.95) }
                        GradientStop { position: root.tail; color: root.tint(root.lite, 0) }
                        GradientStop { position: 1.0; color: root.tint(root.lite, 0) }
                    }

                    PathAngleArc {
                        centerX: root.r
                        centerY: root.r
                        radiusX: root.outerR
                        radiusY: root.outerR
                        startAngle: 0
                        sweepAngle: 360
                    }
                    PathMove {
                        x: root.r + root.outerR - root.cometW
                        y: root.r
                    }
                    PathAngleArc {
                        centerX: root.r
                        centerY: root.r
                        radiusX: root.outerR - root.cometW
                        radiusY: root.outerR - root.cometW
                        startAngle: 0
                        sweepAngle: 360
                    }
                }
            }

            // Index notch, so a single point on the wheel can be followed.
            Rectangle {
                width: root.diameter * 0.16
                height: width
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.85)
                x: root.r + root.r * 0.78 - width / 2
                y: root.r - height / 2
            }
        }
    }
}
