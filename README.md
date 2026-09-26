<p align="center">
  <img src="assets/prisma-icon.svg" alt="Prisma" width="120">
</p>

<h1 align="center">Prisma</h1>

<p align="center">
  <b>All your RGB lighting, from your Omarchy bar.</b><br>
  <sub>Powered by <a href="https://openrgb.org/">OpenRGB</a></sub>
</p>

---

Motherboard, RAM, graphics card, AIO fans, keyboard, mouse: every one of them
ships with its own vendor app, and none of them run on Linux. **Prisma puts all
of them behind one icon in your Omarchy bar.** Paint everything at once or pick
a color per device, follow the colors of your Omarchy theme, and give each
device a name you'll recognize.

<p align="center">
  <img src="screenshots/popup.png" alt="Prisma panel" width="420">
</p>

## Features

- **All together or one by one.** One color for every device, or a color per
  device. A device without its own color follows the shared one.
- **Follows your theme.** Pick the theme's accent, text or any palette color.
  Prisma stores the *reference*, not the hex, so when you run
  `omarchy theme set` the lights change with it. One click on **Use theme
  color** puts every device back on the theme accent.
- **Any color, plus effects.** Ten ready-made colors, a `#RRGGBB` field for
  anything else, a rainbow cycle and off.
- **Rename devices.** "ASUS TUF GAMING B650-PLUS WIFI" can just be
  "Motherboard". Click a name to rename it; clear it to get the original back.
- **Smart per device.** Each device gets the best mode it supports for the
  look you picked (Static, Direct, Solid Color... for colors; Rainbow,
  Spectrum Cycle, Color Cycle... for the rainbow), so you never pick modes by
  hand.
- **Survives reboots.** Your choice lives in the shell config and is applied
  again every time the shell starts.
- **Quick toggle.** **Middle-click** the bar icon to turn the lights off and
  on without opening the panel. In the panel, `←/→` switches between "all
  together" and "per device", `Esc` closes.
- **Multilingual.** English, Português, Español, Français and Deutsch. It
  follows your system locale, or you can pick a language in the widget
  settings.

## Requirements

Prisma drives your hardware through OpenRGB, which does the heavy lifting.
Before installing:

1. **Install OpenRGB** (it's in the official Arch repos):

   ```bash
   sudo pacman -S --needed openrgb
   ```

   The package also installs the udev rules that let your user talk to RGB
   controllers, and loads the `i2c-dev` kernel module at boot, which RAM,
   motherboard and GPU lighting need.

2. **Reboot once** after installing OpenRGB, so the udev rules and `i2c-dev`
   take effect. (Or `sudo modprobe i2c-dev` and re-plug USB devices.)

3. **Check that OpenRGB sees your hardware:**

   ```bash
   openrgb --list-devices
   ```

   If a device is missing here, Prisma can't see it either; see
   [Troubleshooting](#troubleshooting).

Prisma itself also needs `python3` and a systemd user session, both present on
every Omarchy install.

## Install

```bash
omarchy plugin add https://github.com/diogocezar/omarchy-prisma.git --enable
```

The icon lands in the right section of the bar
(<img src="screenshots/bar.png" alt="bar icon" height="22">). Move it with
`omarchy bar move diogocezar.prisma --section <left|center|right>`.

## Update

```bash
omarchy plugin update diogocezar.prisma
```

## Uninstall

```bash
omarchy plugin remove diogocezar.prisma
systemctl --user stop prisma-openrgb 2>/dev/null   # if Prisma started its own server
rm -rf ~/.cache/prisma                             # optional
```

## How it works

Prisma has two parts:

1. **A bar widget** (`src/Widget.qml`) that stores your choices in the shell
   config and resolves them to colors, reading the palette straight from the
   active theme's `colors.toml`.
2. **A small backend** (`src/prisma.py`) that turns those colors into one
   `openrgb` call for every device.

### The OpenRGB server

Some controllers (ASUS Aura, for one) go back to their default colors as soon
as the program talking to them exits. So Prisma always goes through a
long-running OpenRGB server, picking the first of:

1. **A server already running**: the OpenRGB app with its SDK server on, or
   the system service shipped with the package
   (`sudo systemctl enable --now openrgb`). Prisma uses it as is.
2. **A user unit named `openrgb.service`**, if you have one. Prisma starts it.
3. **Otherwise, its own server**, started as the transient user unit
   `prisma-openrgb`. Nothing is installed; it lasts until you log out, and
   Prisma starts it again when the shell comes back.

### Addressable (ARGB) headers

OpenRGB can't tell how many LEDs are on a strip or fan plugged into an
addressable header, so those zones often show up with **0 LEDs** and stay
dark. Prisma resizes every *empty* addressable zone to **24 LEDs** (enough for
common AIO fans) on each apply. Zones that already have a size are left
alone. Change the number, or set it to `0` to turn this off, with
**LEDs per empty ARGB header** in the widget settings.

### Command line

The backend works on its own, handy for binds and scripts:

```bash
SRC=~/.config/omarchy/plugins/diogocezar.prisma/src
python3 $SRC/prisma.py list            # what OpenRGB sees, and each device's modes
python3 $SRC/prisma.py red             # also: a hex like ff4000, theme, rainbow, off
python3 $SRC/prisma.py rescan          # restart the server to pick up new devices
```

Commands run this way don't change the widget's settings, so the next change
in the panel (or the next shell start) applies the panel's choice again.

## Troubleshooting

- **The icon is red.** Hover it, or open the panel: the error from OpenRGB is
  shown there.
- **A wireless mouse or headset is missing.** The OpenRGB server only detects
  devices when it starts, and wireless devices that are asleep don't answer.
  Move the device to wake it, then press **↻** (detect again) next to
  *Devices* in the panel.
  Detecting again restarts the server, so it only works on a server Prisma
  manages. For the OpenRGB app or the system service, restart it yourself.
- **RAM or motherboard lighting is missing.** Check that `i2c-dev` is loaded
  (`lsmod | grep i2c_dev`). On some Intel boards the SMBus is blocked unless
  you add `acpi_enforce_resources=lax` to the kernel command line; see
  OpenRGB's [SMBus guide](https://openrgb.org/udev.html).
- **Fans on a motherboard header stay dark.** Raise **LEDs per empty ARGB
  header** to the number of LEDs on your fans or strip.
- **A device ignores colors.** Run `prisma.py list` and look at its modes. If
  none of them is a static-color mode Prisma knows, please open an issue with
  that output.
- **Logs of the server Prisma started:** `journalctl --user -u prisma-openrgb`.

## Credits

Built on [OpenRGB](https://gitlab.com/CalcProgrammer1/OpenRGB) by Adam Honse
and contributors, which does all of the actual hardware work. Prisma is an
independent project and isn't affiliated with OpenRGB.

## License

[MIT](LICENSE) © Diogo Cezar
