.pragma library

// Pure data helpers: parsing /proc snapshots, turning them into usage figures,
// and mapping a usage figure to a colour and a spin speed. No Qt types, so it
// can be tested with node.

// Wheel order, left to right.
var IDS = ["up", "cpu", "mem", "disk", "down"];

var COLORS = {
    violet: [166, 108, 255],
    blue: [79, 140, 255],
    green: [61, 220, 132],
    yellow: [247, 209, 84],
    orange: [255, 159, 67],
    red: [255, 85, 85]
};

// Colour spectra, low usage first.
var SPECTRA = {
    base: [COLORS.green, COLORS.yellow, COLORS.red],
    full: [COLORS.violet, COLORS.blue, COLORS.green, COLORS.yellow, COLORS.orange, COLORS.red]
};

// Where each colour band starts, per wheel and spectrum.
// cpu, mem and disk are percentages; up and down are megabits per second.
// n colours need n - 1 thresholds.
var BANDS = {
    up:   { base: [1, 20], full: [1, 5, 10, 20, 50] },
    down: { base: [1, 20], full: [1, 5, 10, 20, 50] },
    cpu:  { base: [30, 70], full: [10, 25, 45, 65, 85] },
    mem:  { base: [60, 85], full: [20, 40, 60, 75, 90] },
    disk: { base: [20, 60], full: [5, 15, 35, 60, 85] }
};

// Neutral grey for a network wheel with no connection.
var GREY = [0.55, 0.56, 0.6];

// Whole physical disks only (no partitions, loop, ram or dm devices).
var DISK_PATTERN = /^(sd[a-z]+|vd[a-z]+|xvd[a-z]+|hd[a-z]+|nvme\d+n\d+|mmcblk\d+)$/;

// Virtual interfaces that would double count traffic or are not a real link.
var NET_SKIP = /^(lo|veth|docker|br-|virbr|tailscale|wg|tun|tap)/;

function clamp01(v) {
    if (!(v > 0))
        return 0;
    return v > 1 ? 1 : v;
}

function smoothstep(a, b, x) {
    if (x <= a)
        return 0;
    if (x >= b)
        return 1;
    var t = (x - a) / (b - a);
    return t * t * (3 - 2 * t);
}

// Mixes two [r, g, b] colours (0..1). t = 0 gives a, t = 1 gives b.
function mix(a, b, t) {
    t = clamp01(t);
    return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
}

// Mixes an [r, g, b] colour towards white.
function lighten(rgb, amount) {
    return mix(rgb, [1, 1, 1], amount);
}

// Position along a spectrum: 0 is the first colour, n - 1 the last. Each
// threshold is crossed over a short, smooth transition (0.7x to 1.4x).
function bandPosition(thresholds, value) {
    var p = 0;
    for (var i = 0; i < thresholds.length; i++)
        p += smoothstep(thresholds[i] * 0.7, thresholds[i] * 1.4, value);
    return p;
}

// Returns [r, g, b] in 0..1 for a wheel's usage figure and a spectrum name.
function colorFor(metric, value, spectrum) {
    var mode = spectrum === "full" ? "full" : "base";
    var cols = SPECTRA[mode];
    var p = bandPosition(BANDS[metric][mode], value);
    var i = Math.min(Math.floor(p), cols.length - 2);
    var c = mix(cols[i], cols[i + 1], p - i);
    return [c[0] / 255, c[1] / 255, c[2] / 255];
}

// Spin level 0..1 (independent of colour mode). Percentages scale linearly.
// Network speed scales by decade: 50 kbit/s is 0, 50 Mbit/s is 1.
function speedLevel(metric, value) {
    if (metric === "up" || metric === "down")
        return value <= 0.05 ? 0 : clamp01(Math.log(value / 0.05) / Math.log(1000));
    return clamp01(value / 100);
}

// Parses the output of the sampler command in BarWidget.qml.
// Sections are separated by lines starting with "#": stat (first), mem, disk, net, link.
function parseSnapshot(text) {
    if (!text)
        return null;

    var snap = { cpuIdle: 0, cpuTotal: 0, memFrac: 0, diskMs: {}, rxBytes: 0, txBytes: 0, linkUp: false };
    var section = "stat";
    var sawCpu = false;
    var memTotal = 0;
    var memAvail = -1;
    var lines = text.split("\n");

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (line.charAt(0) === "#") {
            section = line.substring(1).trim();
            continue;
        }

        if (section === "stat") {
            if (line.indexOf("cpu ") === 0) {
                var f = line.trim().split(/\s+/).slice(1);
                var total = 0;
                for (var j = 0; j < 8 && j < f.length; j++)
                    total += Number(f[j]);
                snap.cpuTotal = total;
                snap.cpuIdle = Number(f[3] || 0) + Number(f[4] || 0);
                sawCpu = true;
            }
        } else if (section === "mem") {
            var m = /^(MemTotal|MemAvailable):\s+(\d+)/.exec(line);
            if (m) {
                if (m[1] === "MemTotal")
                    memTotal = Number(m[2]);
                else
                    memAvail = Number(m[2]);
            }
        } else if (section === "disk") {
            var p = line.trim().split(/\s+/);
            if (p.length >= 13 && DISK_PATTERN.test(p[2]))
                snap.diskMs[p[2]] = Number(p[12]); // milliseconds spent doing I/O
        } else if (section === "net") {
            var idx = line.indexOf(":");
            if (idx < 0)
                continue;
            if (NET_SKIP.test(line.substring(0, idx).trim()))
                continue;
            var n = line.substring(idx + 1).trim().split(/\s+/);
            if (n.length >= 9) {
                snap.rxBytes += Number(n[0]);
                snap.txBytes += Number(n[8]);
            }
        } else if (section === "link") {
            // Lines look like /sys/class/net/wlan0/operstate:up
            var c = line.lastIndexOf(":");
            if (c < 0)
                continue;
            var iface = line.substring(0, c).split("/")[4];
            if (iface && !NET_SKIP.test(iface) && line.substring(c + 1).trim() === "up")
                snap.linkUp = true;
        }
    }

    if (!sawCpu || memTotal <= 0 || memAvail < 0)
        return null;
    snap.memFrac = clamp01(1 - memAvail / memTotal);
    return snap;
}

// Turns two snapshots into usage figures: cpu, mem and disk as percentages,
// upMbps and downMbps as megabits per second.
function compute(prev, cur, dtMs) {
    var out = { cpu: 0, mem: cur.memFrac * 100, disk: 0, upMbps: 0, downMbps: 0 };
    if (!prev || !(dtMs > 0))
        return out;

    var dTotal = cur.cpuTotal - prev.cpuTotal;
    var dIdle = cur.cpuIdle - prev.cpuIdle;
    out.cpu = dTotal > 0 ? clamp01(1 - dIdle / dTotal) * 100 : 0;

    var busy = 0;
    for (var name in cur.diskMs) {
        if (prev.diskMs[name] === undefined)
            continue;
        var b = (cur.diskMs[name] - prev.diskMs[name]) / dtMs;
        if (b > busy)
            busy = b;
    }
    out.disk = clamp01(busy) * 100;

    var seconds = dtMs / 1000;
    var dTx = cur.txBytes - prev.txBytes;
    var dRx = cur.rxBytes - prev.rxBytes;
    out.upMbps = dTx > 0 ? dTx * 8 / 1000000 / seconds : 0;
    out.downMbps = dRx > 0 ? dRx * 8 / 1000000 / seconds : 0;
    return out;
}
