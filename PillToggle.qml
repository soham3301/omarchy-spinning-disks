import QtQuick

// Small pill-shaped toggle button, tinted from one foreground colour so it
// fits any Omarchy theme.
Rectangle {
    id: root

    property string text: ""
    property bool on: false
    property color fg: "white"
    property string fontFamily: "monospace"
    property real fontSize: 12

    signal clicked

    implicitWidth: label.implicitWidth + fontSize * 2
    implicitHeight: label.implicitHeight + fontSize * 0.9
    radius: height / 2
    color: Qt.rgba(fg.r, fg.g, fg.b, on ? 0.22 : 0.06)
    border.width: 1
    border.color: Qt.rgba(fg.r, fg.g, fg.b, on ? 0.7 : 0.3)

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.fg
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
