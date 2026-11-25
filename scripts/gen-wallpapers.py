# Generates the alternative Catppuccin Mocha wallpapers (glow, bands, topo) in dotfiles/vanilla/backgrounds.
# The main wallpaper comes from gen-wallpaper-dusk.py.
# Usage: nix-shell -p "python3.withPackages(p:[p.pillow p.numpy])" --run "python3 scripts/gen-wallpapers.py <out-dir>"
import sys, numpy as np
from PIL import Image, ImageFilter

OUT = sys.argv[1]
W, H = 3840, 2160
C = {k: np.array([int(v[i:i+2], 16) for i in (0, 2, 4)], np.float32) for k, v in dict(
    rosewater="f5e0dc", flamingo="f2cdcd", pink="f5c2e7", mauve="cba6f7", red="f38ba8",
    maroon="eba0ac", peach="fab387", yellow="f9e2af", blue="89b4fa", lavender="b4befe",
    sapphire="74c7ec", teal="94e2d5", text="cdd6f4", overlay0="6c7086", surface2="585b70",
    surface1="45475a", surface0="313244", base="1e1e2e", mantle="181825", crust="11111b").items()}
rng = np.random.default_rng(7)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)

def mix(a, b, t): return a * (1 - t) + b * t
def ramp(t, stops):
    """t: array in [0,1]; stops: list of (pos, rgb)"""
    t = np.clip(t, 0, 1)[..., None]
    out = np.zeros(t.shape[:-1] + (3,), np.float32)
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        m = (t >= p0) & (t <= p1)
        k = (t - p0) / max(p1 - p0, 1e-6)
        out = np.where(m, mix(c0, c1, k), out)
    return out
def noise1d(n, octaves, seed):
    r = np.random.default_rng(seed); x = np.linspace(0, 1, n); y = np.zeros(n)
    for f, a in octaves:
        y += a * np.sin(2 * np.pi * (f * x + r.random())) 
    return y
def noise2d(scale, seed, octaves=4):
    r = np.random.default_rng(seed); acc = np.zeros((H, W), np.float32); amp = 1; tot = 0
    for o in range(octaves):
        gw, gh = max(2, int(W / scale * 2**o)), max(2, int(H / scale * 2**o))
        g = Image.fromarray(r.random((gh, gw)).astype(np.float32), mode="F").resize((W, H), Image.BICUBIC)
        acc += amp * np.asarray(g, np.float32); tot += amp; amp *= 0.45
    return acc / tot
def save(img, name):
    img = img + rng.normal(0, 1.2, img.shape)  # grain, kills banding
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(f"{OUT}/{name}.png", optimize=True)
    print(name)

# 2. mocha-glow: soft colour fields on base — reads well through blur
img = np.broadcast_to(C["base"], (H, W, 3)).copy()
for (px, py, r, col, k) in [(.12, .18, 1500, C["mauve"], .50), (.92, .88, 1300, C["pink"], .30),
                            (.78, .10, 1000, C["lavender"], .28), (.45, 1.05, 900, C["peach"], .16)]:
    g = np.exp(-(((xx - W * px) ** 2 + (yy - H * py) ** 2) / r ** 2))
    img = mix(img, col, (g * k)[..., None])
img = mix(img, C["crust"], (np.clip(np.hypot(xx / W - .5, yy / H - .5) * 1.4, 0, 1) ** 2 * .6)[..., None])
save(img, "mocha-glow")

# 3. mocha-bands: hard-edged quantized sunset with a sliced sun — blocky like the bar
N = 14
t = np.floor(yy / H * N) / (N - 1)
img = ramp(t, [(0, C["crust"]), (.3, C["base"]), (.6, mix(C["surface0"], C["mauve"], .35)),
               (.85, mix(C["mauve"], C["pink"], .3)), (1, mix(C["peach"], C["mauve"], .25))])
cx, cy, R = W / 2, H * 0.62, 640
d = np.hypot(xx - cx, yy - cy)
sun = ramp((yy - (cy - R)) / (2 * R), [(0, C["peach"]), (.5, mix(C["peach"], C["pink"], .6)), (1, C["mauve"])])
band = H / N
gap = ((yy - cy) > 0) & (((yy - cy) % (band / 2)) < ((yy - cy) / R) * band * .45)
inside = np.clip(R - d + .5, 0, 1) * (~gap)
img = mix(img, sun, (inside * .92)[..., None])
ground = yy > H * 0.80
img = np.where(ground[..., None], mix(C["crust"], C["mantle"], np.clip((yy - H * .8) / (H * .2), 0, 1)[..., None]), img)
save(img, "mocha-bands")

# 4. mocha-topo: filled contour bands of a noise field, edges outlined
f = noise2d(1100, 3, 3)
f = np.argsort(np.argsort(f.ravel())).reshape(H, W).astype(np.float32) / (H * W)  # equalize
f = f * 0.999
L = 10
q = np.floor(f * L) / (L - 1)
img = ramp(q, [(0, C["crust"]), (.3, C["mantle"]), (.55, C["base"]), (.75, C["surface0"]),
               (.9, mix(C["surface0"], C["mauve"], .3)), (1, mix(C["surface1"], C["mauve"], .55))])
gy, gx = np.gradient(f * L)
frac = (f * L) % 1
dist = np.minimum(frac, 1 - frac) / np.maximum(np.hypot(gx, gy), 1e-5)
img = mix(img, mix(C["overlay0"], C["mauve"], q[..., None] * .6), (np.clip(1.6 - dist, 0, 1) * .55)[..., None])
save(img, "mocha-topo")
