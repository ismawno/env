# Generates dotfiles/vanilla/backgrounds/.config/backgrounds/wallpaper.jpg (Catppuccin Mocha lake at dusk).
# Usage: nix-shell -p "python3.withPackages(p:[p.pillow p.numpy])" --run "python3 scripts/gen-wallpaper-dusk.py out.png [scale] [seed]"
# then: magick out.png -quality 93 wallpaper.jpg   (scale 0.5 renders a quick preview, a different seed gives a new landscape)
import sys, numpy as np
from PIL import Image, ImageDraw

OUT = sys.argv[1]
S = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0  # render scale (0.5 for quick previews)
SEED = int(sys.argv[3]) if len(sys.argv) > 3 else 11
W, H = int(3840 * S), int(2160 * S)

C = {k: np.array([int(v[i:i + 2], 16) for i in (0, 2, 4)], np.float32) for k, v in dict(
    rosewater="f5e0dc", flamingo="f2cdcd", pink="f5c2e7", mauve="cba6f7", red="f38ba8",
    maroon="eba0ac", peach="fab387", yellow="f9e2af", blue="89b4fa", lavender="b4befe",
    text="cdd6f4", overlay0="6c7086", surface2="585b70", surface1="45475a",
    surface0="313244", base="1e1e2e", mantle="181825", crust="11111b").items()}
rng = np.random.default_rng(SEED)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)


def mix(a, b, t):
    t = np.asarray(t, np.float32)
    if t.ndim == 2: t = t[..., None]
    return a * (1 - t) + b * t
def sstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)
def ramp(t, stops):
    t = np.clip(t, 0, 1)[..., None]; out = np.zeros(t.shape[:-1] + (3,), np.float32)
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        k = sstep(0, 1, (t - p0) / max(p1 - p0, 1e-6))
        out = np.where((t >= p0) & (t <= p1), mix(c0, c1, k), out)
    return out
def up(a, w, h):
    return np.asarray(Image.fromarray(a.astype(np.float32), mode="F").resize((w, h), Image.BICUBIC))
def fbm1(freq, octaves, seed, ridged=False, gain=.5):
    r = np.random.default_rng(seed); acc = np.zeros(W, np.float32); amp, tot, f = 1., 0., freq
    for _ in range(octaves):
        v = up(r.random((1, int(f) + 3)), W + int(W / f * 2), 1)[0][int(W / f):int(W / f) + W] * 2 - 1
        if ridged: v = (1 - np.abs(np.clip(v * 1.15, -1, 1))) ** 1.6 * 2 - 1
        acc += amp * v; tot += amp; amp *= gain; f *= 2.13
    return acc / tot
def fbm2(gw, gh, seed, octaves=4, w=None, h=None, gain=.5):
    w = w or W; h = h or H
    r = np.random.default_rng(seed); acc = np.zeros((h, w), np.float32); amp, tot = 1., 0.
    for o in range(octaves):
        acc += amp * up(r.random((gh * 2 ** o + 1, gw * 2 ** o + 1)), w, h); tot += amp; amp *= gain
    return acc / tot

SHORE = int(H * 0.735)          # waterline
MX, MY, MR = W * 0.69, H * 0.27, 96 * S

# ── sky ──────────────────────────────────────────────────────────────────────
glow_col = mix(C["peach"], C["pink"], .30)
img = ramp(yy / SHORE, [(0, C["crust"]), (.18, C["base"]), (.42, mix(C["base"], C["mauve"], .30)),
                        (.66, mix(C["surface1"], C["mauve"], .68)), (.84, mix(C["mauve"], C["pink"], .65)),
                        (1, mix(glow_col, C["rosewater"], .25))])
# warm horizon glow, concentrated under the moon
hg = np.exp(-((xx - MX) / (W * .42)) ** 2 - ((yy - SHORE * .97) / (H * .30)) ** 2)
img = mix(img, glow_col, hg * .62)
img = mix(img, mix(C["peach"], C["yellow"], .25), np.exp(-((xx - MX) / (W * .22)) ** 2 - ((yy - SHORE * .62) / (H * .06)) ** 2) * .40)

# stars — denser and brighter towards the zenith, suppressed near the moon
mglow = np.exp(-(np.hypot(xx - MX, yy - MY) / (520 * S)) ** 2)
for _ in range(int(1100 * S * S) + 200):
    sx, sy = rng.random() * W, (rng.random() ** 1.7) * SHORE * .62
    fade = (1 - sy / (SHORE * .62)) ** 1.4 * (1 - mglow[int(sy), int(sx)])
    b = (.15 + .85 * rng.random() ** 4) * fade
    sig = (.55 + rng.random() * .6) * max(S, .6)
    r_ = int(3 * sig) + 1
    x0, x1, y0, y1 = max(int(sx) - r_, 0), min(int(sx) + r_ + 1, W), max(int(sy) - r_, 0), min(int(sy) + r_ + 1, H)
    g = np.exp(-((xx[y0:y1, x0:x1] - sx) ** 2 + (yy[y0:y1, x0:x1] - sy) ** 2) / (2 * sig ** 2)) * b
    col = C["rosewater"] if rng.random() < .7 else C["lavender"]
    img[y0:y1, x0:x1] = mix(img[y0:y1, x0:x1], col, g)

# cloud wisps: long horizontal streaks, lit warm on the moon side
cn = fbm2(3, 26, SEED + 1, 5, gain=.55)
for cy, ch, a in [(.44, .05, .40), (.60, .035, .35)]:
    band = np.exp(-((yy - SHORE * cy) / (H * ch)) ** 2)
    m = sstep(.60, .74, cn * .85 + band * .3) * band
    lit = np.exp(-((xx - MX) / (W * .30)) ** 2)
    ccol = mix(mix(C["mauve"], C["pink"], .35), mix(C["peach"], C["rosewater"], .30), lit * .9)
    img = mix(img, ccol, m * a)

# moon: soft bloom + stepped halo rings + textured disc
d = np.hypot(xx - MX, yy - MY)
img = mix(img, mix(C["lavender"], C["rosewater"], .6), np.exp(-(d / (600 * S)) ** 2) * .20)
for rr, a in [(4.6, .035), (3.4, .045), (2.5, .06), (1.75, .08)]:
    img = mix(img, C["rosewater"], np.clip(MR * rr - d + .5, 0, 1) * a)
tex = fbm2(int(W / (70 * S)), int(H / (70 * S)), SEED + 2, 3)
disc = mix(C["rosewater"], mix(C["flamingo"], C["maroon"], .3), sstep(.5, .7, tex) * .35)
disc = disc * (1 - .10 * (d / MR) ** 2)[..., None]
img = mix(img, disc, np.clip(MR - d + .5, 0, 1))

# ── ridges: even far→near progression, mist pooling in each valley ───────────
far = mix(mix(C["surface1"], C["lavender"], .42), C["mauve"], .12)
near = C["crust"]
specs = [  # base, amp, ridged weight, freq
    (.505, .200, .75, 2.2), (.585, .140, .65, 2.8), (.645, .095, .55, 3.4),
    (.690, .060, .45, 4.0), (.722, .028, .30, 5.5)]
ridges = []
prev_col = mix(glow_col, far, .55)
for i, (b, a, rw, f) in enumerate(specs):
    t = i / (len(specs) - 1)
    col = mix(mix(far, near, t ** .85), mix(C["mauve"], C["surface0"], .5), .25 * np.sin(np.pi * t))
    col = mix(col, glow_col, np.exp(-((xx[0] - MX) / (W * .35)) ** 2)[None, :] * .14 * (1 - t))  # warm rim near moon
    shape = ((1 - rw) * fbm1(f * .5, 2, SEED * 10 + i) + rw * fbm1(f, 3, SEED * 20 + i, ridged=True)
             + .12 * fbm1(f * 9, 4, SEED * 30 + i, gain=.45))
    h = SHORE * b / .735 - H * a * (.5 + .5 * shape)
    ridges.append(h)
    below = yy - h[None, :]
    kk = int(120 * S); hs = np.convolve(np.pad(h, kk, mode="edge"), np.ones(2 * kk + 1) / (2 * kk + 1), "valid")
    mist = sstep(-H * .01, H * (.075 - .01 * i), yy - hs[None, :]) * (.35 + .08 * i)
    lay = mix(col if col.ndim == 3 else np.broadcast_to(col, (H, W, 3)), prev_col, mist)
    img = mix(img, lay, np.clip(below + .5, 0, 1) * (yy < SHORE))
    prev_col = mix(col if col.ndim == 1 else col[0, int(MX)], C["lavender"], .06)

# ── pines on the two nearest ridges (drawn 2x for anti-aliasing) ─────────────
def pine(draw, cx, base, h, s2):
    half, tiers = h * (.20 + rng.random() * .06), int(6 + h / (30 * S))
    top = base - h; right = []
    for j in range(1, tiers + 1):
        yj = top + h * .9 * j / tiers
        wj = half * (j / tiers) ** .85 * (1 + (rng.random() - .5) * .25)
        right += [(wj * .5, yj - h * .9 / tiers * .55), (wj, yj)]
    right += [(half * .12, base - h * .06), (half * .12, base + 8 * S)]
    pts = [(cx, top)] + [(cx + px, py) for px, py in right] + [(cx - px, py) for px, py in reversed(right)]
    draw.polygon([(x * s2, y * s2) for x, y in pts], fill=255)

def treeline(ridge, density, hmin, hmax, clusters):
    m = Image.new("L", (W * 2, H * 2)); dr = ImageDraw.Draw(m)
    for x in np.sort(rng.random(int(density * W / S)) * W):
        wgt = max(np.exp(-((x - cx * W) / (cw * W)) ** 2) for cx, cw in clusters)
        if rng.random() > wgt: continue
        h = (hmin + (hmax - hmin) * rng.random() ** 1.6) * (.45 + .55 * wgt) * S
        pine(dr, x, ridge[min(int(x), W - 1)] + 6 * S, h, 2)
    return np.asarray(m.reduce(2), np.float32) / 255

t3 = treeline(ridges[3], .012, 40, 90, [(.08, .10), (.36, .05), (.93, .07)])
img = mix(img, mix(far, near, (3 / 4) ** .85), t3 * (yy < SHORE))
t4 = treeline(ridges[4], .03, 60, 230, [(.0, .17), (.97, .12), (.55, .03)])
img = mix(img, near, t4 * (yy < SHORE))

# ── lake: rippled mirror, deepening tint, moon glint ─────────────────────────
LH = H - SHORE
ly = yy[SHORE:] - SHORE; lx = xx[SHORE:]
depth = ly / LH
w1 = fbm2(5, 60, SEED + 3, 4, w=W, h=LH) * 2 - 1
w2 = fbm2(3, 90, SEED + 4, 4, w=W, h=LH) * 2 - 1
sx = np.clip(lx + w1 * (3 + 26 * depth) * S, 0, W - 1).astype(int)
sy = np.clip(SHORE - 1 - ly * .98 + w2 * (1 + 10 * depth) * S, 0, SHORE - 1).astype(int)
refl = img[sy, sx]
k = max(int(6 * S), 1)  # horizontal smear, like wind on water
cs = np.cumsum(np.pad(refl, ((0, 0), (k, k), (0, 0)), mode="edge"), axis=1)
refl = (cs[:, 2 * k:] - cs[:, :-2 * k]) / (2 * k)
refl = refl[:, :W] if refl.shape[1] >= W else np.pad(refl, ((0, 0), (0, W - refl.shape[1]), (0, 0)), mode="edge")
water = mix(refl, mix(C["base"], C["mauve"], .12), .22 + .45 * depth) * (.92 - .30 * depth)[..., None]
streak = sstep(.78, .90, fbm2(16, 150, SEED + 5, 3, w=W, h=LH))
water = mix(water, mix(C["lavender"], C["rosewater"], .4), streak * (.05 + .10 * np.exp(-((lx - MX) / (W * .2)) ** 2)))
gl = np.exp(-((lx - MX) / ((50 + 340 * depth) * S)) ** 2)
dash = sstep(.55, .72, fbm2(4, 160, SEED + 6, 3, w=W, h=LH))
water = mix(water, C["rosewater"], gl * dash * (.85 - .55 * depth))
water = mix(water, mix(C["lavender"], C["rosewater"], .5), np.clip(1 - ly / (2.5 * S), 0, 1) * .35)  # waterline
img[SHORE:] = water

# vignette + grain
v = np.hypot((xx / W - .5) * 1.1, yy / H - .45)
img = img * (1 - sstep(.35, .85, v) * .30)[..., None]
img += rng.normal(0, 1.1, img.shape)
Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(OUT)
print(OUT)
