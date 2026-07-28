#!/usr/bin/env python3
"""Convert the Flowey pixel-art PNG to half-block art for tuigreet.

Writes three files:
  flowey.txt   plain-text outline art -- THIS is what the greeter uses.
  flowey.ansi  the same sprite in full color, for a tuigreet that can parse
               ANSI (see the note next to the emitter below).
  flowey_preview.png  square-pixel preview of the sampled grid.
"""
import sys
from collections import deque
from PIL import Image, ImageDraw

SRC = "flowey_source.png"
OUT_ANSI = sys.argv[1] if len(sys.argv) > 1 else "flowey.ansi"
OUT_PNG = sys.argv[2] if len(sys.argv) > 2 else "flowey_preview.png"
OUT_TXT = sys.argv[3] if len(sys.argv) > 3 else "flowey.txt"

img = Image.open(SRC).convert("RGB")
W, H = img.size
px = img.load()

# ---- classify pixels into palette classes ----
# classes: None (transparent/bg), 'black','white','yellow','olive','green'
def classify(r, g, b):
    if r > 200 and g > 200 and b > 200:
        return "white"
    if r < 70 and g < 70 and b < 70:
        return "black"
    if b < 120 and r > 180 and g > 180:
        return "yellow"
    if b < 120 and r > 120 and g > 120:
        return "olive"  # darker yellow-green petal shading
    if g > 100 and r < 150:
        return "green"
    # grays of the checkerboard fall here-ish too
    if abs(r - g) < 20 and abs(g - b) < 20:
        return "white" if r > 160 else "black"
    return "black"

cls = [[classify(*px[x, y]) for x in range(W)] for y in range(H)]

# ---- flood fill checkerboard background from the borders ----
# bg is light (white/gray); the face is sealed inside a black outline so the
# fill can't leak into it.
def is_light(x, y):
    r, g, b = px[x, y]
    return r > 160 and g > 160 and b > 160 and abs(r - g) < 25 and abs(g - b) < 25

bg = [[False] * W for _ in range(H)]
q = deque()
for x in range(W):
    for y in (0, H - 1):
        if is_light(x, y) and not bg[y][x]:
            bg[y][x] = True
            q.append((x, y))
for y in range(H):
    for x in (0, W - 1):
        if is_light(x, y) and not bg[y][x]:
            bg[y][x] = True
            q.append((x, y))
while q:
    x, y = q.popleft()
    for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
        if 0 <= nx < W and 0 <= ny < H and not bg[ny][nx] and is_light(nx, ny):
            bg[ny][nx] = True
            q.append((nx, ny))

for y in range(H):
    for x in range(W):
        if bg[y][x]:
            cls[y][x] = None

# ---- find sprite bbox ----
xs = [x for y in range(H) for x in range(W) if cls[y][x] is not None]
ys = [y for y in range(H) for x in range(W) if cls[y][x] is not None]
x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
bw, bh = x1 - x0 + 1, y1 - y0 + 1
print(f"sprite bbox: {bw}x{bh} at ({x0},{y0})")

# ---- detect logical grid: try N cells across, score reconstruction ----
def sample_grid(n_across):
    pitch = bw / n_across
    n_down = round(bh / pitch)
    grid = []
    for gy in range(n_down):
        row = []
        for gx in range(n_across):
            # majority vote inside the cell (robust to edge anti-aliasing)
            cx0, cx1 = x0 + int(gx * pitch), x0 + int((gx + 1) * pitch)
            cy0, cy1 = y0 + int(gy * pitch), y0 + int((gy + 1) * pitch)
            counts = {}
            for yy in range(cy0, max(cy0 + 1, cy1)):
                for xx in range(cx0, max(cx0 + 1, cx1)):
                    c = cls[min(yy, H-1)][min(xx, W-1)]
                    counts[c] = counts.get(c, 0) + 1
            row.append(max(counts, key=counts.get))
        grid.append(row)
    return grid, pitch, n_down

def score(grid, pitch, n_down):
    # fraction of source pixels that disagree with their cell's majority class
    bad = tot = 0
    for gy in range(n_down):
        for gx in range(len(grid[0])):
            cx0, cx1 = x0 + int(gx * pitch), x0 + int((gx + 1) * pitch)
            cy0, cy1 = y0 + int(gy * pitch), y0 + int((gy + 1) * pitch)
            for yy in range(cy0, max(cy0 + 1, cy1), 2):
                for xx in range(cx0, max(cx0 + 1, cx1), 2):
                    tot += 1
                    if cls[min(yy, H-1)][min(xx, W-1)] != grid[gy][gx]:
                        bad += 1
    return bad / tot

best = None
for n in range(16, 49):
    grid, pitch, n_down = sample_grid(n)
    s = score(grid, pitch, n_down)
    if best is None or s < best[0]:
        best = (s, n, grid, n_down)
s, n_across, grid, n_down = best
print(f"best grid: {n_across}x{n_down} cells (error {s:.3%})")

# ---- emit ANSI half-blocks ----
# NOTE this file is NOT what the greeter reads; flowey.txt below is. tuigreet
# 0.9.1 (the latest release, and what nixpkgs ships) has no ANSI parser: the
# greeting goes straight into a ratatui Paragraph, which drops the ESC byte
# because it has zero display width and then draws the rest -- "[0;30m" and
# friends -- as literal text. ANSI greeting support exists only on upstream
# master (ansi-to-tui, `greeting.trim().into_text()` in src/ui/util.rs), which
# has never been released. Keep emitting this so the color version is ready if
# we ever pin that commit; if we do, note that the bright background codes
# (100-107) below are unreliable on the Linux VT the greeter runs on.
FG = {"black": 30, "white": 97, "yellow": 93, "olive": 33, "green": 92}
BG = {"black": 40, "white": 107, "yellow": 103, "olive": 43, "green": 102}
RGB = {"black": (0, 0, 0), "white": (255, 255, 255), "yellow": (255, 255, 85),
       "olive": (170, 170, 0), "green": (85, 255, 85), None: None}

if n_down % 2:
    grid.append([None] * n_across)

lines = []
for gy in range(0, len(grid), 2):
    out = []
    for gx in range(n_across):
        top, bot = grid[gy][gx], grid[gy + 1][gx]
        if top is None and bot is None:
            out.append("\x1b[0m ")
        elif top == bot:
            out.append(f"\x1b[0;{FG[top]}m█")
        elif bot is None:
            out.append(f"\x1b[0;{FG[top]}m▀")
        elif top is None:
            out.append(f"\x1b[0;{FG[bot]}m▄")
        else:
            out.append(f"\x1b[0;{FG[top]};{BG[bot]}m▀")
    lines.append("".join(out) + "\x1b[0m")

with open(OUT_ANSI, "w") as f:
    f.write("\n".join(lines) + "\n")
print(f"wrote {OUT_ANSI}: {n_across} cols x {len(lines)} text rows")

# ---- emit plain-text half-blocks (what the greeter actually shows) ----
# tuigreet styles the whole greeting with a single color (theme key `greet`),
# so there is no point encoding the palette here. Drawing only the black
# outline class and leaving the petal/stem fills blank gives line art; drawing
# every non-background class instead gives a shapeless blob.
OUTLINE = "black"
txt_lines = []
for gy in range(0, len(grid), 2):
    row = []
    for gx in range(n_across):
        top = grid[gy][gx] == OUTLINE
        bot = grid[gy + 1][gx] == OUTLINE
        row.append("█" if top and bot else "▀" if top else "▄" if bot else " ")
    # trailing blanks would be drawn as (themed) spaces, so drop them
    txt_lines.append("".join(row).rstrip())

with open(OUT_TXT, "w") as f:
    f.write("\n".join(txt_lines) + "\n")
print(f"wrote {OUT_TXT}: {max(len(l) for l in txt_lines)} cols x {len(txt_lines)} text rows")

# ---- render preview PNG (square pixels, on dark bg like the greeter) ----
SCALE = 12
pv = Image.new("RGB", (n_across * SCALE, len(grid) * SCALE), (16, 16, 16))
d = ImageDraw.Draw(pv)
for gy, row in enumerate(grid):
    for gx, c in enumerate(row):
        if c is not None:
            d.rectangle([gx*SCALE, gy*SCALE, (gx+1)*SCALE-1, (gy+1)*SCALE-1], fill=RGB[c])
pv.save(OUT_PNG)
print(f"wrote {OUT_PNG}")
