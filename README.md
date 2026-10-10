# Spinning Disks

An [Omarchy](https://omarchy.org) bar widget that shows system load as five small, spinning wheels on a transparent background. No numbers, no graphs: just speed and, if you want it, colour.

| Wheel | What it measures                                                     | Spins         |
| ----- | -------------------------------------------------------------------- | ------------- |
| UP    | Upload speed                                                         | anticlockwise |
| CPU   | Total CPU busy time                                                  | clockwise     |
| MEM   | Memory in use (total minus available)                                | clockwise     |
| DISK  | Disk I/O activity: the busiest physical drive's time spent doing I/O | clockwise     |
| DOWN  | Download speed                                                       | clockwise     |

The higher the usage, the faster a wheel spins, from 0.6 to 6 revolutions per second. Changes glide over a fraction of a second, so nothing flickers. Since a flat colour would hide the rotation, each wheel has two glints like a CD, a bright comet on the rim, a notch dot, fine grooves and a see-through hub.

## Colour

Click the widget to open a popup with the five wheels and their names, plus two buttons. Your choice is saved between sessions.

- **Color: Off** (default): all wheels use your theme's foreground colour.
- **Color: On**: wheels are coloured by usage. A second button then switches between:
    - **Base spectrum** (default): green, yellow, red
    - **Full spectrum**: violet, blue, green, yellow, orange, red

Colour changes are smooth, not sudden. Press Escape to close the popup.

### No network

If no network interface is up (Wi-Fi off, cable unplugged), the UP and DOWN wheels slow down gradually over a few seconds until they stop, and fade to grey. When the connection returns they speed up and regain their colour.

### Colour bands

Each colour covers a band of usage, and neighbouring bands blend over a short, smooth transition. CPU, memory and disk are percentages; UP and DOWN are megabits per second.

| Spectrum | Colours, low to high                     | Band edges: UP / DOWN | CPU                  | MEM                  | DISK                |
| -------- | ---------------------------------------- | --------------------- | -------------------- | -------------------- | ------------------- |
| Base     | green, yellow, red                       | 1, 20 Mbps            | 30, 70 %             | 60, 85 %             | 20, 60 %            |
| Full     | violet, blue, green, yellow, orange, red | 1, 5, 10, 20, 50 Mbps | 10, 25, 45, 65, 85 % | 20, 40, 60, 75, 90 % | 5, 15, 35, 60, 85 % |

To change them, edit `BANDS` at the top of `Model.js`.

## Install

Requires Omarchy 4 ("Quattro") or later, which uses the Quickshell-based shell.

```sh
omarchy plugin add https://github.com/soham3301/omarchy-spinning-disks.git --enable
```

The widget starts in the right section of the bar. Move it with:

```sh
omarchy bar move io.github.soham3301.spinning-disks --section center
```

## Update and remove

```sh
omarchy plugin update
omarchy plugin remove io.github.soham3301.spinning-disks
```

## How it works

- `BarWidget.qml` samples `/proc/stat`, `/proc/meminfo`, `/proc/diskstats`, `/proc/net/dev` and `/sys/class/net/*/operstate` once a second with a short-lived shell command, and hands five values to the wheels.
- `Model.js` parses the samples and maps values to colours and spin speeds. It has no Qt dependencies.
- `DiskView.qml` draws one wheel with QtQuick Shapes. Spinning is a rotation of one item, so it stays cheap.
- `DiskRow.qml` lays out the wheels, in a row or in a column on a vertical bar.
- `Panel.qml` is the click popup, and `PillToggle.qml` is its button.

The widget is 180 px wide (or tall, on a vertical bar). To change that, edit `stripLength` in `BarWidget.qml`.

## Security

Plugins run unsandboxed inside the long-lived `omarchy-shell` process, with your user permissions. This one only reads the `/proc` and `/sys/class/net` files above and makes no network connections. The only file it writes is a two-line settings file, `omarchy-spinning-disks/settings`, in your XDG state directory (`~/.local/state` by default).

## Troubleshooting

- **Nothing appears:** run `omarchy plugin list --json` to check it is enabled, then `omarchy-shell shell rescanPlugins`. QML errors show up in `qs log -p "$OMARCHY_PATH/shell" --tail 100`.
- **The bright comet seems to lead instead of trail:** set `gradientSign` to `-1` in `DiskView.qml`.
- **Code changes do not show:** run `omarchy restart shell`.
- **Reset the colour settings:** delete `~/.local/state/omarchy-spinning-disks/settings`.

## Develop

```sh
git clone https://github.com/soham3301/omarchy-spinning-disks.git ~/.config/omarchy/plugins/io.github.soham3301.spinning-disks
omarchy plugin enable io.github.soham3301.spinning-disks
cd ~/.config/omarchy/plugins/io.github.soham3301.spinning-disks
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml DiskRow.qml DiskView.qml PillToggle.qml
```

## License

MIT. See [LICENSE](LICENSE).
