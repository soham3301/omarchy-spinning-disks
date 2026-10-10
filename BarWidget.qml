import QtQuick
import Quickshell.Io
import qs.Ui
import "Model.js" as Model

BarWidget {
    id: root
    moduleName: "io.github.soham3301.spinning-disks"

    readonly property int stripLength: 180
    readonly property bool isVertical: root.bar ? root.bar.vertical === true : false
    readonly property int barThickness: root.bar ? Number(root.bar.barSize) : 26

    // Upload, CPU, memory, disk I/O, download: percent, or Mbit/s for the
    // two network wheels. `diskOnline` is false for the network wheels when
    // no interface is up.
    property var diskValues: [0, 0, 0, 0, 0]
    property var diskOnline: [true, true, true, true, true]
    property var prevSnap: null
    property real prevTime: 0

    // Colour settings, saved between sessions. Off means the theme colour.
    property bool colorOn: false
    property string spectrum: "base"
    readonly property color systemColor: root.bar ? root.bar.foreground : "white"

    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
    readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

    function open() {
        if (panelLoader.item)
            panelLoader.item.open();
    }

    function close() {
        if (panelLoader.item)
            panelLoader.item.close();
    }

    function toggle() {
        if (panelLoader.item)
            panelLoader.item.toggle();
    }

    function closeForPopoutSwitch() {
        if (panelLoader.item)
            panelLoader.item.closeForPopoutSwitch();
    }

    function injectPanel() {
        if (!panelLoader.item)
            return;
        panelLoader.item.bar = root.bar;
        panelLoader.item.anchorItem = strip;
        panelLoader.item.hostWidget = root;
    }

    function ingest(text) {
        const snap = Model.parseSnapshot(text);
        if (!snap)
            return;
        const now = Date.now();
        const usage = Model.compute(root.prevSnap, snap, now - root.prevTime);
        const up = snap.linkUp;
        root.diskValues = [usage.upMbps, usage.cpu, usage.mem, usage.disk, usage.downMbps];
        root.diskOnline = [up, true, true, true, up];
        root.prevSnap = snap;
        root.prevTime = now;
    }

    function setColorOn(value) {
        if (root.colorOn === value)
            return;
        root.colorOn = value;
        root.saveSettings();
    }

    function setSpectrum(value) {
        if ((value !== "base" && value !== "full") || root.spectrum === value)
            return;
        root.spectrum = value;
        root.saveSettings();
    }

    function applySettings(text) {
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line === "color=1")
                root.colorOn = true;
            else if (line === "color=0")
                root.colorOn = false;
            else if (line === "spectrum=base" || line === "spectrum=full")
                root.spectrum = line.substring(9);
        }
    }

    function saveSettings() {
        settingsSaver.running = false;
        settingsSaver.command = [
            "sh", "-c",
            'd="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-spinning-disks"; mkdir -p "$d" && printf "%s\\n%s\\n" "$0" "$1" > "$d/settings"',
            "color=" + (root.colorOn ? "1" : "0"),
            "spectrum=" + root.spectrum
        ];
        settingsSaver.running = true;
    }

    implicitWidth: root.isVertical ? root.barThickness : root.stripLength
    implicitHeight: root.isVertical ? root.stripLength : root.barThickness

    onBarChanged: injectPanel()

    // One short-lived `cat` per second; no extra dependencies.
    Process {
        id: sampler
        command: ["sh", "-c", "cat /proc/stat; echo '#mem'; cat /proc/meminfo; echo '#disk'; cat /proc/diskstats; echo '#net'; cat /proc/net/dev; echo '#link'; grep -H . /sys/class/net/*/operstate 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.ingest(this.text)
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!sampler.running)
                sampler.running = true;
        }
    }

    // Reads the saved colour settings once at start.
    Process {
        id: settingsLoader
        command: ["sh", "-c", 'cat "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-spinning-disks/settings" 2>/dev/null']
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.applySettings(this.text)
        }
    }

    Process {
        id: settingsSaver
    }

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel();
            Qt.callLater(root.injectPanel);
        }
    }

    Binding {
        target: panelLoader.item
        property: "diskValues"
        value: root.diskValues
        when: panelLoader.item !== null
    }

    Binding {
        target: panelLoader.item
        property: "diskOnline"
        value: root.diskOnline
        when: panelLoader.item !== null
    }

    Binding {
        target: panelLoader.item
        property: "colorOn"
        value: root.colorOn
        when: panelLoader.item !== null
    }

    Binding {
        target: panelLoader.item
        property: "spectrum"
        value: root.spectrum
        when: panelLoader.item !== null
    }

    DiskRow {
        id: strip
        anchors.fill: parent
        values: root.diskValues
        online: root.diskOnline
        colorOn: root.colorOn
        spectrum: root.spectrum
        systemColor: root.systemColor
        vertical: root.isVertical
        diameter: Math.min(24, root.barThickness - 4)
        cell: root.stripLength / 5
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggle()
    }
}
