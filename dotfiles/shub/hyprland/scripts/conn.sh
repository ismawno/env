#!/usr/bin/env bash
# Waybar "CONN/BLE": link type from sysfs, bluetooth from a sysfs-gated busctl call (bluetoothctl hangs without an adapter).
exec python3 - "$@" <<'PY'
import fcntl, glob, html, json, os, re, socket, struct, subprocess, sys

SKIP = ("lo", "tailscale", "docker", "veth", "virbr", "br-", "wg", "tun", "zt")
SIOCGIFADDR, SIOCGIFNETMASK = 0x8915, 0x891B

def rd(p):
    try:
        with open(p) as f:
            return f.read().strip()
    except OSError:
        return ""

def links():
    """type==1 keeps real ethernet links only; operstate is safer to read than carrier."""
    eth = wifi = None
    for d in sorted(glob.glob("/sys/class/net/*")):
        n = os.path.basename(d)
        if n.startswith(SKIP) or rd(d + "/type") != "1" or rd(d + "/operstate") != "up":
            continue
        if os.path.isdir(d + "/wireless") or os.path.isdir(d + "/phy80211"):
            wifi = wifi or n
        else:
            eth = eth or n
    return eth, wifi

def ipv4(n):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        req = struct.pack("256s", n.encode()[:15])
        addr = socket.inet_ntoa(fcntl.ioctl(s.fileno(), SIOCGIFADDR, req)[20:24])
        mask = socket.inet_ntoa(fcntl.ioctl(s.fileno(), SIOCGIFNETMASK, req)[20:24])
        return "%s/%d" % (addr, sum(bin(int(o)).count("1") for o in mask.split(".")))
    except OSError:
        return None
    finally:
        s.close()

def ipv6(n):
    try:
        for line in open("/proc/net/if_inet6"):
            p = line.split()
            if p[-1] == n and p[3] == "00":   # scope 00 == global
                return "%s/%d" % (socket.inet_ntop(socket.AF_INET6, bytes.fromhex(p[0])), int(p[2], 16))
    except OSError:
        pass
    return None

def wifi_info():
    """SSID is queried last: nmcli escapes colons inside it, so it must be the tail field."""
    try:
        r = subprocess.run(["nmcli", "-g", "ACTIVE,SIGNAL,FREQ,RATE,SSID", "dev", "wifi",
                            "list", "--rescan", "no"], capture_output=True, text=True, timeout=3)
    except Exception:
        return {}
    for ln in r.stdout.splitlines():
        if ln.startswith("yes:"):
            p = ln.split(":", 4)
            return {"sig": p[1], "freq": p[2], "rate": p[3], "ssid": p[4].replace("\\:", ":")}
    return {}

def prop(iface, key, default=None):
    v = iface.get(key)
    return default if v is None else v.get("data", default)

def bluetooth():
    """Gate on hci* entries: the directory itself appears merely from the module loading."""
    if not glob.glob("/sys/class/bluetooth/hci*"):
        return "X", ["<b>Bluetooth</b>  no adapter"]
    try:
        r = subprocess.run(["busctl", "--system", "--json=short", "call", "org.bluez", "/",
                            "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"],
                           capture_output=True, text=True, timeout=2)
        objs = json.loads(r.stdout)["data"][0]
    except Exception:
        return "X", ["<b>Bluetooth</b>  bluez unreachable"]

    adapters, devices, powered = [], [], False
    for path in sorted(objs):
        a = objs[path].get("org.bluez.Adapter1")
        if a is not None:
            on = bool(prop(a, "Powered", False))
            powered = powered or on
            adapters.append((prop(a, "Alias") or prop(a, "Name") or os.path.basename(path),
                             prop(a, "Address", "?"), on))
        d = objs[path].get("org.bluez.Device1")
        if d is not None and prop(d, "Connected", False):
            bat = prop(objs[path].get("org.bluez.Battery1", {}), "Percentage")
            devices.append((prop(d, "Alias") or prop(d, "Name") or prop(d, "Address", "?"),
                            prop(d, "Address", "?"), bat))
    if not adapters:
        return "X", ["<b>Bluetooth</b>  no adapter"]

    lines = ["<b>Bluetooth</b>"]
    for nm, addr, on in adapters:
        lines.append("  %s  %s  [%s]" % (html.escape(nm), addr, "on" if on else "off"))
    if powered:
        lines.append("  %d connected" % len(devices))
        for nm, addr, bat in devices:
            b = "  %d%%" % bat if isinstance(bat, int) else ""
            lines.append("    %s  %s%s" % (html.escape(nm), addr, b))
    return ("B%d" % len(devices)) if powered else "Off", lines

eth, wl = links()
if eth:
    conn, cls, ifn = "[ETH]", "ethernet", eth
    speed = rd("/sys/class/net/%s/speed" % eth)
    duplex = rd("/sys/class/net/%s/duplex" % eth)
    lines = ["<b>Ethernet</b>  %s" % eth]
    if speed and speed != "-1":
        lines.append("  link    %s Mb/s %s" % (speed, duplex))
elif wl:
    w = wifi_info()
    sig = w.get("sig", "")
    conn = "[W%s%%]" % sig if sig else "[W]"
    cls = "wifi-weak" if sig.isdigit() and int(sig) < 35 else "wifi"
    ifn = wl
    lines = ["<b>Wi-Fi</b>  %s" % wl,
             "  ssid    %s" % html.escape(w.get("ssid", "?")),
             "  signal  %s%%" % (sig or "?")]
    if w.get("freq"):
        lines.append("  link    %s  %s" % (w["freq"], w.get("rate", "?")))
else:
    conn, cls, ifn = "[X]", "disconnected", None
    lines = ["<b>Network</b>  disconnected"]

if ifn:
    lines.append("  mac     %s" % rd("/sys/class/net/%s/address" % ifn))
    for label, val in (("ipv4", ipv4(ifn)), ("ipv6", ipv6(ifn))):
        if val:
            lines.append("  %s    %s" % (label, val))

ble, btlines = bluetooth()
lines += [""] + btlines

tooltip = "\n".join(lines)
if "info" in sys.argv[1:]:
    # Middle click: same content as the hover tooltip, as a notification.
    try:
        subprocess.run(["notify-send", "-a", "waybar", "Connectivity",
                        re.sub(r"<[^>]*>", "", tooltip)], check=False)
    except FileNotFoundError:
        print("notify-send not found", file=sys.stderr)
else:
    print(json.dumps({"text": "%s/[%s]" % (conn, ble),
                      "tooltip": tooltip,
                      "class": cls}))
PY
