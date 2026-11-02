#!/usr/bin/env python3
"""Prisma backend: talks to the OpenRGB server on behalf of the bar widget.

    prisma.py devices               JSON list of detected devices
    prisma.py rescan                restart the server, then like `devices`
    prisma.py apply '<json>'        {"<device key>": "RRGGBB"|"rainbow"|"off",
                                     "*": <fallback for unlisted devices>}
    prisma.py <color|hex|theme|rainbow|off>   same look on every device
    prisma.py list                  human-readable device list

Device keys are OpenRGB device names, with " #2", " #3"... appended to
repeats, so two identical sticks of RAM can still be told apart.

Hardware quirks handled here, all learned the hard way:

1. Some controllers (ASUS Aura) revert as soon as the process talking to them
   exits, so everything goes through a long-lived OpenRGB server. A server
   already on the SDK port is used as is (the OpenRGB GUI, or the packaged
   system `openrgb.service`), as long as it belongs to us or to root; another
   user's listener is refused. Otherwise we start the user unit
   `openrgb.service` if there is one, or else our own transient unit
   `prisma-openrgb` through systemd-run, so nothing needs installing.

2. Addressable (ARGB) headers can report 0 LEDs, since the length of the strip
   on them can't be detected, and a size set at runtime is lost when the
   server restarts. Empty addressable zones are resized on every apply
   (PRISMA_ARGB_LEDS, default 24); zones that already have LEDs are left as
   OpenRGB knows them.

3. Direct mode blanks Addressable Gen 2 headers on some boards (OpenRGB issue
   4021), so Static wins over Direct. Some keyboards (Keychron QMK) only obey
   Direct: no Static, and Solid Color accepts the color without changing it.
   Hence the order Static, Direct, Solid Color.

4. The server detects devices once, when it starts. A wireless mouse that was
   asleep then is missing until the server restarts: that is `rescan`.

5. The server opens its port seconds before detection ends, and libusb
   devices (HyperX QuadCast S) come last. At boot systemd starts the server
   before the shell, so "the port was already open" doesn't mean detection is
   over. A server younger than WARMUP seconds counts as cold, and a cold
   server is ready when its log says "Detection completed". A device that
   OpenRGB takes over but never gets a color stays dark.

Exit codes: 1 bad input or OpenRGB error, 2 openrgb missing, 3 server down,
4 no devices.
"""
import fcntl
import json
import os
import pathlib
import re
import shlex
import shutil
import subprocess
import sys
import time

NAMED = {
    "red": "FF0000", "green": "00FF00", "blue": "0000FF", "white": "FFFFFF",
    "yellow": "FFFF00", "purple": "8000FF", "pink": "FF00FF",
    "orange": "FF4000", "cyan": "00FFFF", "turquoise": "00FF80",
}

# enough for common AIO fans; LEDs past the real strip are ignored
LEDS_PER_HEADER = int(os.environ.get("PRISMA_ARGB_LEDS", "24") or 0)
# Preference order, matched case-insensitively against each device's modes.
SOLID = ["Static", "Direct", "Solid Color", "Solid", "Fixed", "Custom", "Color", "Normal"]
CYCLE = ["Rainbow", "Rainbow Wave", "Spectrum Cycle", "Color Cycle", "Cycle All",
         "Spectrum", "Rainbow Cycle", "Color Wave", "Cycle", "Wave"]
OFF = ["Off", "Disabled"]
PORT = 6742
USER_UNIT = "openrgb.service"
OWN_UNIT = "prisma-openrgb"
# a server younger than this may still be detecting devices
WARMUP = 90

HOME = pathlib.Path.home()
THEME = HOME / ".local/state/omarchy/current/theme/colors.toml"
CACHE = pathlib.Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "prisma"
OPENRGB_LOGS = pathlib.Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "OpenRGB/logs"


def die(message, code=1):
    print(message, file=sys.stderr)
    sys.exit(code)


def theme_accent():
    try:
        m = re.search(r'^accent\s*=\s*"#?([0-9A-Fa-f]{6})"', THEME.read_text(), re.M)
    except OSError:
        die(f"Omarchy theme not found at {THEME}")
    if not m:
        die(f"no `accent` in {THEME}")
    return m.group(1).upper()


def listener_owners():
    """uids of every socket listening on PORT, in any address family.

    /proc/net/tcp{,6} shows the owner of every socket, other users' included,
    so nothing has to connect to find out who is on the other end."""
    owners = set()
    for table in ("/proc/net/tcp", "/proc/net/tcp6"):
        try:
            rows = pathlib.Path(table).read_text().splitlines()[1:]
        except OSError:
            continue
        for row in rows:
            cols = row.split()
            if len(cols) > 7 and cols[3] == "0A" and int(cols[1].rsplit(":", 1)[1], 16) == PORT:
                owners.add(int(cols[7]))
    return owners


def port_open():
    """True when a server we trust listens on PORT; dies on anyone else's.

    The port is unprivileged, so another local account could bind it first and
    pose as the OpenRGB server to feed our client whatever it likes. Only a
    listener owned by us or by root (the packaged system openrgb.service) is
    used. While ours holds the port nobody else can bind it (SO_REUSEPORT only
    pairs sockets of the same uid), and every openrgb call checks again."""
    owners = listener_owners()
    foreign = owners - {os.getuid(), 0}
    if foreign:
        die(f"port {PORT} is held by another user (uid {', '.join(map(str, sorted(foreign)))}); "
            "refusing to talk to a server that isn't yours", 3)
    return bool(owners)


def openrgb(args, timeout=180):
    """Run an OpenRGB client against the server, once it is known to be ours."""
    if not port_open():
        die("the OpenRGB server went away", 3)
    return subprocess.run(["openrgb"] + args, capture_output=True, text=True, timeout=timeout)


def user_unit_exists(unit):
    r = subprocess.run(["systemctl", "--user", "show", "-p", "LoadState", "--value", unit],
                       capture_output=True, text=True)
    return r.stdout.strip() == "loaded"


def active_unit():
    """The user unit running our server, or "" when it's someone else's."""
    for unit in (USER_UNIT, OWN_UNIT):
        r = subprocess.run(["systemctl", "--user", "is-active", unit],
                           capture_output=True, text=True)
        if r.stdout.strip() == "active":
            return unit
    return ""


def server_pid():
    """PID of the OpenRGB server on our port, or None when we can't tell."""
    unit = active_unit()
    if unit:
        pid = subprocess.run(["systemctl", "--user", "show", "-p", "MainPID", "--value", unit],
                             capture_output=True, text=True).stdout.strip()
        if pid.isdigit() and pid != "0":
            return int(pid)
    r = subprocess.run(["pgrep", "-o", "-f", r"openrgb.*--server"],
                       capture_output=True, text=True)
    first = r.stdout.split()
    return int(first[0]) if first and first[0].isdigit() else None


def server_age():
    """Seconds since the server process started, or None."""
    pid = server_pid()
    if pid is None:
        return None
    r = subprocess.run(["ps", "-o", "etimes=", "-p", str(pid)], capture_output=True, text=True)
    age = r.stdout.strip()
    return int(age) if age.isdigit() else None


def detection_done():
    """True/False from the server's own log, None when there's no such log.

    Every openrgb process writes OpenRGB_YYYYMMDD_HHMMSS.log, clients included,
    so the server's log is the one named after the second the server started."""
    age = server_age()
    if age is None or not OPENRGB_LOGS.is_dir():
        return None
    started = time.time() - age
    for log in OPENRGB_LOGS.glob("OpenRGB_*.log"):
        m = re.fullmatch(r"OpenRGB_(\d{8}_\d{6})\.log", log.name)
        if not m:
            continue
        try:
            stamp = time.mktime(time.strptime(m.group(1), "%Y%m%d_%H%M%S"))
        except ValueError:
            continue
        if abs(stamp - started) <= 3:
            try:
                return "Detection completed" in log.read_text(errors="replace")
            except OSError:
                return None
    return None


def server_id():
    unit = active_unit()
    if not unit:
        return "external"
    pid = subprocess.run(["systemctl", "--user", "show", "-p", "MainPID", "--value", unit],
                         capture_output=True, text=True).stdout.strip()
    return f"{unit}:{pid}"


def start_server():
    if user_unit_exists(USER_UNIT):
        cmd = ["systemctl", "--user", "start", USER_UNIT]
    else:
        subprocess.run(["systemctl", "--user", "reset-failed", OWN_UNIT],
                       capture_output=True)
        cmd = ["systemd-run", "--user", f"--unit={OWN_UNIT}", "--collect",
               "--description=OpenRGB server for Prisma",
               shutil.which("openrgb"), "--server", "--noautoconnect"]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        die(f"couldn't start the OpenRGB server: {r.stderr.strip()}", 3)


def ensure_server():
    """True when we had to wake the server (its detection may still be running)."""
    if not shutil.which("openrgb"):
        die("openrgb is not installed (sudo pacman -S openrgb)", 2)
    for attempt in range(40):
        if port_open():
            age = server_age()
            return attempt > 0 or (age is not None and age < WARMUP)
        if attempt == 0:
            start_server()
        time.sleep(1)
    die("the OpenRGB server didn't come up "
        f"(journalctl --user -u {USER_UNIT} -u {OWN_UNIT})", 3)


def restart_server():
    unit = active_unit()
    if unit == USER_UNIT:
        subprocess.run(["systemctl", "--user", "restart", USER_UNIT])
    elif unit == OWN_UNIT:
        subprocess.run(["systemctl", "--user", "stop", OWN_UNIT])
        start_server()
    elif port_open():
        die("the OpenRGB server running here isn't managed by Prisma "
            "(OpenRGB app or system service); restart it to detect new devices", 3)
    time.sleep(1)


def split(text):
    """OpenRGB quotes names with spaces; a stray quote shouldn't lose the device."""
    try:
        return shlex.split(text)
    except ValueError:
        return text.split()


_list_flag = None


def list_flag():
    """OpenRGB 1.1 made --list-devices names only; the old detailed output
    (Type, Modes, Zones, LEDs) moved to --list-detailed."""
    global _list_flag
    if _list_flag is None:
        help_text = subprocess.run(["openrgb", "--help"], capture_output=True,
                                   text=True, timeout=30).stdout
        _list_flag = "--list-detailed" if "--list-detailed" in help_text else "--list-devices"
    return _list_flag


def read_devices():
    """[{key, name, type, modes, argb}] as the server sees them right now."""
    out = openrgb([list_flag()]).stdout
    devs, cur, seen = [], None, {}
    for line in out.splitlines():
        head = re.match(r"^(\d+): (.+)$", line)
        field = line.strip()
        if head:
            name = head.group(2).strip()
            seen[name] = seen.get(name, 0) + 1
            key = name if seen[name] == 1 else f"{name} #{seen[name]}"
            cur = {"index": int(head.group(1)), "key": key, "name": name,
                   "type": "", "modes": [], "argb": []}
        elif cur is None:
            continue
        elif field.startswith("Type:"):
            cur["type"] = field[len("Type:"):].strip()
        elif field.startswith("Modes:"):
            cur["modes"] = [m.strip("[]") for m in split(field[len("Modes:"):])]
        elif field.startswith("Zones:"):
            cur["zones"] = split(field[len("Zones:"):])
            cur["argb"] = [i for i, z in enumerate(cur["zones"]) if "addressable" in z.lower()]
            devs.append(cur)
        elif field.startswith("LEDs:") and "zones" in cur:
            # LED names are "<zone>, LED n" on addressable zones, so a zone
            # with none of those is empty and needs a size to light up.
            cur["argb"] = [i for i in cur["argb"] if f"'{cur['zones'][i]}, " not in field]
            cur = None
    return devs


def settled_devices(cold):
    """The server opens its port before detection ends, so right after a cold
    start a listing only has some devices. Then we wait for the server's log
    to report the end of detection, or, without a log, for the list to stop
    growing; with a warm server one read is enough (the usual case)."""
    if not cold:
        return read_devices()
    if detection_done() is not None:
        for _ in range(120):                 # 60 s ceiling
            if detection_done():
                break
            time.sleep(0.5)
        return read_devices()
    devs = read_devices()
    steady = 0
    for _ in range(60):                      # 30 s ceiling
        time.sleep(0.5)
        now = read_devices()
        steady = steady + 1 if len(now) == len(devs) else 0
        devs = now
        if devs and steady >= 8:             # 4 s unchanged: wireless
            break                            # devices answer last
    return devs


def normalize(value):
    v = str(value).strip().lower()
    if v in ("rainbow", "off"):
        return v
    v = NAMED.get(v, v).lstrip("#").upper()
    if not re.fullmatch(r"[0-9A-F]{6}", v):
        die(f"invalid color: {value}")
    return v


def pick(modes, preferred):
    lower = {m.lower(): m for m in modes}
    return next((lower[p.lower()] for p in preferred if p.lower() in lower), None)


def plan_for(devs, looks):
    """openrgb argv for one call covering every device, plus a readable plan."""
    args, lines = [], []
    for d in devs:
        look = looks.get(d["key"], looks.get("*"))
        if look is None:
            continue
        modes = d["modes"]
        if look == "rainbow":
            mode, color = pick(modes, CYCLE), None
        elif look == "off":
            mode = pick(modes, OFF)
            mode, color = (mode, None) if mode else (pick(modes, SOLID), "000000")
        else:
            mode, color = pick(modes, SOLID), look
        if not mode:
            lines.append(f"  - {d['key']}: no usable mode, skipped")
            continue
        args += ["-d", str(d["index"])]
        for z in d["argb"] if LEDS_PER_HEADER > 0 else []:
            args += ["-z", str(z), "-sz", str(LEDS_PER_HEADER)]
        args += ["-m", mode] + (["-c", color] if color else [])
        extra = f"  (+{len(d['argb'])} ARGB headers)" if d["argb"] else ""
        lines.append(f"  - {d['key']}: {mode}" + (f" #{color}" if color else "") + extra)
    return args, lines


def apply(looks, force=False):
    cold = ensure_server()
    devs = settled_devices(cold)
    if not devs:
        die("no RGB devices detected", 4)

    # One bar per monitor asks for the same look at startup; skip repeats
    # while the same server process still holds it.
    stamp = CACHE / "applied"
    signature = json.dumps({"server": server_id(), "looks": looks, "leds": LEDS_PER_HEADER,
                            "devices": [d["key"] for d in devs]}, sort_keys=True)
    if not force and not cold:
        try:
            if stamp.read_text() == signature:
                print("  (already applied)")
                return
        except OSError:
            pass

    args, lines = plan_for(devs, looks)
    print("\n".join(lines))
    if not args:
        return
    r = openrgb(args)
    errors = [line for line in (r.stdout + r.stderr).splitlines()
              if re.search(r"error|wrong|invalid|fail", line, re.I)
              and "Connection attempt failed" not in line]
    if errors:
        stamp.unlink(missing_ok=True)
        die("\n".join(errors))
    stamp.write_text(signature)


def print_devices(devs):
    print(json.dumps([{"key": d["key"], "name": d["name"], "type": d["type"]} for d in devs]))


def main():
    if len(sys.argv) < 2:
        die("usage: prisma.py <devices|rescan|list|apply JSON|color|hex|theme|rainbow|off>\n"
            f"colors: {', '.join(NAMED)}")

    CACHE.mkdir(parents=True, exist_ok=True)
    # Every monitor's bar runs its own widget; serialize them.
    lock = open(CACHE / "lock", "w")
    fcntl.flock(lock, fcntl.LOCK_EX)

    cmd = sys.argv[1].lower()
    force = "--force" in sys.argv[2:]

    if cmd == "rescan":
        # The server detects only at startup; restarting it is the only way to
        # pick up a wireless device that was asleep. Otherwise never restart:
        # Aura boards revert when their connection closes.
        restart_server()
        (CACHE / "applied").unlink(missing_ok=True)
        ensure_server()
        print_devices(settled_devices(True))
    elif cmd in ("devices", "list"):
        devs = settled_devices(ensure_server())
        if cmd == "devices":
            print_devices(devs)
        else:
            for d in devs:
                print(f"{d['key']}  [{d['type'] or '?'}]")
                print(f"    ARGB headers: {len(d['argb'])}    modes: {', '.join(d['modes'])}")
    elif cmd == "apply":
        if len(sys.argv) < 3:
            die("apply needs a JSON object")
        try:
            raw = json.loads(sys.argv[2])
        except json.JSONDecodeError as e:
            die(f"bad JSON: {e}")
        apply({k: normalize(v) for k, v in raw.items()}, force)
    else:
        look = theme_accent() if cmd == "theme" else normalize(cmd)
        apply({"*": look}, force=True)


main()
