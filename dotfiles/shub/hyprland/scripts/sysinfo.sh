#!/usr/bin/env bash
# Waybar: compact "cpu% ram% temp°C" with a full breakdown in the tooltip
# (per-core, memory, every sensor, GPU). Hwmon is discovered, never hardcoded.
exec python3 - "$@" <<'PY'
import os, glob, json, re, subprocess, sys

STATE = "/tmp/.waybar-sysinfo-cpu"

def notify(tooltip, title):
    """Strip pango markup and show the tooltip as a notification. Never fatal."""
    try:
        subprocess.run(["notify-send", "-a", "waybar", title,
                        re.sub(r"<[^>]*>", "", tooltip)], check=False)
    except FileNotFoundError:
        print("notify-send not found", file=sys.stderr)

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
                cur[p[0]] = (sum(v), v[3] + v[4])   # total, idle
    prev = {}
    if os.path.exists(STATE):
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
    """Every labelled hwmon input, grouped by chip. Numbering varies per host."""
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
                continue   # unconnected superio headers read 0.0; pure noise
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

cpus = cpu_percentages()
total_cpu = cpus.get("cpu", 0.0)
mt, mu, st, su = memory()
mem_pct = 100.0 * mu / mt if mt else 0.0
chips = sensors()

# Headline temp: prefer a CPU package sensor, else the hottest reading.
pkg = None
for nm in ("coretemp", "k10temp", "zenpower", "acpitz"):
    if nm in chips:
        for label, c in chips[nm]:
            if "Package" in label or "Tctl" in label or label == "temp1":
                pkg = c; break
    if pkg is not None:
        break
if pkg is None:
    allt = [c for rows in chips.values() for _, c in rows]
    pkg = max(allt) if allt else 0.0

text = f"{total_cpu:.0f}% {mem_pct:.0f}% {pkg:.0f}°C"

cores = sorted(((k, v) for k, v in cpus.items() if k != "cpu"),
               key=lambda kv: int(kv[0][3:]))
lines = [f"<b>CPU</b>  {total_cpu:.1f}%  ({len(cores)} threads)"]
for i in range(0, len(cores), 4):
    lines.append("  " + "  ".join(f"{k[3:]:>2}:{v:5.1f}%" for k, v in cores[i:i + 4]))
lines.append("")
lines.append(f"<b>Memory</b>  {mu:.1f} / {mt:.1f} GiB  ({mem_pct:.0f}%)")
if st > 0:
    lines.append(f"<b>Swap</b>    {su:.1f} / {st:.1f} GiB")
lines.append("")
lines.append("<b>Temperatures</b>")
for name, rows in chips.items():
    lines.append(f"  {name}")
    for label, c in rows:
        lines.append(f"    {label:<20} {c:5.1f}°C")
g = gpu()
if g:
    lines.append("")
    lines.append("<b>GPU</b>")
    lines.append("  " + g.replace("\n", "\n  "))

cls = "critical" if pkg >= 85 else ("warning" if pkg >= 70 else "normal")
tooltip = "\n".join(lines)
if "info" in sys.argv[1:]:
    # Middle click: same content as the hover tooltip, as a notification.
    notify(tooltip, "System")
else:
    print(json.dumps({"text": text, "tooltip": tooltip, "class": cls}))
PY
