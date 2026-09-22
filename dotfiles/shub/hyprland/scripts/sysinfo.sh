#!/usr/bin/env bash
# Waybar: "cpu% ram% temp°C [bat%]", with per-core, memory, every discovered hwmon sensor, GPU and battery in the tooltip.
exec python3 - "$@" <<'PY'
import os, glob, json, re, subprocess, sys

STATE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "waybar-sysinfo-cpu")

def cpu_percentages():
    """Per-core + total, from two /proc/stat samples cached between runs."""
    cur = {}
    with open("/proc/stat") as f:
        for line in f:
            if not line.startswith("cpu"):
                break
            p = line.split()
            if p[0] == "cpu" or p[0][3:].isdigit():
                v = list(map(int, p[1:8]))
                cur[p[0]] = (sum(v), v[3] + v[4])
    try:
        prev = json.load(open(STATE))
    except Exception:
        prev = {}
    json.dump({k: list(v) for k, v in cur.items()}, open(STATE, "w"))
    out = {}
    for k, (tot, idle) in cur.items():
        if k in prev:
            dt, di = tot - prev[k][0], idle - prev[k][1]
            out[k] = max(0.0, min(100.0, 100.0 * (dt - di) / dt)) if dt > 0 else 0.0
        else:
            out[k] = 0.0
    return out

def memory():
    m = {}
    for line in open("/proc/meminfo"):
        k, v = line.split(":", 1)
        m[k] = int(v.split()[0]) / 1048576.0   # KiB -> GiB
    total = m["MemTotal"]; avail = m.get("MemAvailable", m["MemFree"])
    swt = m.get("SwapTotal", 0.0); swf = m.get("SwapFree", 0.0)
    return total, total - avail, swt, swt - swf

def sensors():
    """Every labelled hwmon input, grouped by chip; numbering varies per host, and unconnected superio headers read 0.0."""
    chips = {}
    for hw in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
        try:
            name = open(os.path.join(hw, "name")).read().strip()
        except OSError:
            continue
        rows = []
        for ti in sorted(glob.glob(os.path.join(hw, "temp*_input"))):
            try:
                c = int(open(ti).read().strip()) / 1000.0
            except (OSError, ValueError):
                continue
            if c <= 0.0:
                continue
            lf = ti.replace("_input", "_label")
            label = open(lf).read().strip() if os.path.exists(lf) else os.path.basename(ti).split("_")[0]
            rows.append((label, c))
        if rows:
            chips[name] = rows
    return chips

def gpu():
    """nvidia-smi if present; Intel iGPU needs root for intel_gpu_top, so skipped."""
    try:
        q = "utilization.gpu,temperature.gpu,memory.used,memory.total,name"
        r = subprocess.run(["nvidia-smi", f"--query-gpu={q}", "--format=csv,noheader,nounits"],
                           capture_output=True, text=True, timeout=2)
        if r.returncode == 0 and r.stdout.strip():
            u, t, mu, mt, nm = [x.strip() for x in r.stdout.strip().split(",")]
            return f"{nm}\n  load {u}%   {t}°C   {float(mu)/1024:.1f}/{float(mt)/1024:.1f} GiB"
    except Exception:
        pass
    return None

def battery():
    """First system battery (scope=Device is a peripheral) as a dict, or None on a desktop."""
    def rd(path, cast=str):
        try:
            return cast(open(path).read().strip())
        except (OSError, ValueError):
            return None
    for ps in sorted(glob.glob("/sys/class/power_supply/*")):
        if rd(f"{ps}/type") != "Battery" or rd(f"{ps}/scope") == "Device":
            continue
        cap = rd(f"{ps}/capacity", int)
        if cap is None:
            continue
        fam = "energy" if rd(f"{ps}/energy_now", int) is not None else "charge"
        now = rd(f"{ps}/{fam}_now", int)
        full = rd(f"{ps}/{fam}_full", int)
        design = rd(f"{ps}/{fam}_full_design", int)
        rate = abs(rd(f"{ps}/power_now" if fam == "energy" else f"{ps}/current_now", int) or 0)
        volt = (rd(f"{ps}/voltage_now", int) or 0) / 1e6
        status = rd(f"{ps}/status") or "Unknown"
        hours = None
        if rate and now is not None and full:
            if status == "Discharging":
                hours = now / rate
            elif status == "Charging":
                hours = max(0, full - now) / rate
        return {
            "name": os.path.basename(ps), "cap": cap, "status": status, "hours": hours,
            "watts": rate / 1e6 if fam == "energy" else rate / 1e6 * volt,
            "health": 100.0 * full / design if full and design else None,
            "cycles": rd(f"{ps}/cycle_count", int),
            "limit": rd(f"{ps}/charge_control_end_threshold", int),
        }
    return None

cpus = cpu_percentages()
total_cpu = cpus.get("cpu", 0.0)
mt, mu, st, su = memory()
mem_pct = 100.0 * mu / mt if mt else 0.0
chips = sensors()

# Headline temp: prefer a CPU package sensor, else the hottest reading.
pkg = next((c for nm in ("coretemp", "k10temp", "zenpower", "acpitz") for label, c in chips.get(nm, [])
            if "Package" in label or "Tctl" in label or label == "temp1"), None)
if pkg is None:
    pkg = max((c for rows in chips.values() for _, c in rows), default=0.0)

text = f"{total_cpu:.0f}% {mem_pct:.0f}% {pkg:.0f}°C"
bat = battery()
if bat:
    text += " {}%".format(bat["cap"])

cores = sorted(((k, v) for k, v in cpus.items() if k != "cpu"),
               key=lambda kv: int(kv[0][3:]))
lines = [f"<b>CPU</b>  {total_cpu:.1f}%  ({len(cores)} threads)"]
for i in range(0, len(cores), 4):
    lines.append("  " + "  ".join(f"{k[3:]:>2}:{v:5.1f}%" for k, v in cores[i:i + 4]))
lines += ["", f"<b>Memory</b>  {mu:.1f} / {mt:.1f} GiB  ({mem_pct:.0f}%)"]
if st > 0:
    lines.append(f"<b>Swap</b>    {su:.1f} / {st:.1f} GiB")
lines += ["", "<b>Temperatures</b>"]
for name, rows in chips.items():
    lines.append(f"  {name}")
    for label, c in rows:
        lines.append(f"    {label:<20} {c:5.1f}°C")
g = gpu()
if g:
    lines += ["", "<b>GPU</b>", "  " + g.replace("\n", "\n  ")]

if bat:
    lines += ["", "<b>Battery</b>  {}%  {}".format(bat["cap"], bat["status"])]
    row = "  {:.1f} W".format(bat["watts"])
    if bat["hours"] is not None:
        h = int(bat["hours"]); mnt = int((bat["hours"] - h) * 60)
        row += "   {}h {:02d}m {}".format(h, mnt, "left" if bat["status"] == "Discharging" else "to full")
    lines.append(row)
    extra = [f.format(bat[k]) for f, k in (("health {:.0f}%", "health"), ("{} cycles", "cycles"), ("limit {}%", "limit"))
             if bat[k] is not None]
    if extra:
        lines.append("  " + "   ".join(extra))

cls = "critical" if pkg >= 85 else ("warning" if pkg >= 70 else "normal")
if bat and bat["status"] == "Discharging":
    if bat["cap"] <= 10:
        cls = "critical"
    elif bat["cap"] <= 20 and cls == "normal":
        cls = "warning"
tooltip = "\n".join(lines)
if "info" in sys.argv[1:]:
    try:
        subprocess.run(["notify-send", "-a", "waybar", "System", re.sub(r"<[^>]*>", "", tooltip)], check=False)
    except FileNotFoundError:
        print("notify-send not found", file=sys.stderr)
else:
    print(json.dumps({"text": text, "tooltip": tooltip, "class": cls}))
PY
