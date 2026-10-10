import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Click popup: the same five wheels with names, plus the colour buttons.
Panel {
    id: root
    moduleName: "io.github.soham3301.spinning-disks"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    property var diskValues: [0, 0, 0, 0, 0]
    property var diskOnline: [true, true, true, true, true]
    property bool colorOn: false
    property string spectrum: "base"

    function open() {
        root.controller.show();
    }

    function close() {
        root.controller.hide();
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.hostWidget || root, direction);
        return false;
    }

    function setColorOn(value) {
        if (root.hostWidget && typeof root.hostWidget.setColorOn === "function")
            root.hostWidget.setColorOn(value);
    }

    function setSpectrum(value) {
        if (root.hostWidget && typeof root.hostWidget.setSpectrum === "function")
            root.hostWidget.setSpectrum(value);
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(300))
        contentHeight: panel.fittedContentHeight(content.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function (direction) {
                root.switchPanel(direction);
            }

            Column {
                id: content
                width: parent.width
                spacing: Style.space(12)

                DiskRow {
                    width: parent.width
                    cell: width / 5
                    diameter: Style.space(44)
                    values: root.diskValues
                    online: root.diskOnline
                    colorOn: root.colorOn
                    spectrum: root.spectrum
                    systemColor: root.barForeground
                    animate: root.opened === true
                    showLabels: true
                    labelColor: root.barForeground
                    labelFamily: root.bar ? root.bar.fontFamily : Style.font.family
                    labelSize: Style.font.subtitle
                }

                Flow {
                    width: parent.width
                    spacing: Style.space(8)

                    PillToggle {
                        text: root.colorOn ? "Color: On" : "Color: Off"
                        on: root.colorOn
                        fg: root.barForeground
                        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        fontSize: Style.font.subtitle
                        onClicked: root.setColorOn(!root.colorOn)
                    }

                    PillToggle {
                        visible: root.colorOn
                        text: root.spectrum === "full" ? "Full spectrum" : "Base spectrum"
                        on: root.spectrum === "full"
                        fg: root.barForeground
                        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        fontSize: Style.font.subtitle
                        onClicked: root.setSpectrum(root.spectrum === "full" ? "base" : "full")
                    }
                }
            }
        }
    }
}
