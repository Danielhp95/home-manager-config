#!/usr/bin/env python3
"""Convert the Sans pixel-art sprite to half-block art for tuigreet.

Writes two files:
  sans.txt          half-block art -- THIS is what the greeter uses.
  sans_preview.png  square-pixel preview of the sampled grid.

sans_source.png is frame 0 of Sans' battle idle animation, from
https://undertale.fandom.com/wiki/File:Sans_battle_idle.gif -- every frame is
the same pose bobbing, so the choice of frame does not matter.

Run it from this directory with pillow available, e.g.
  nix-shell -p 'python3.withPackages(ps: [ps.pillow])' --run 'python3 sans.py'
"""
import sys
from PIL import Image, ImageDraw

SRC = "sans_source.png"
OUT_TXT = sys.argv[1] if len(sys.argv) > 1 else "sans.txt"
OUT_PNG = sys.argv[2] if len(sys.argv) > 2 else "sans_preview.png"

img = Image.open(SRC).convert("RGB")
W, H = img.size
px = img.load()

# The battle sprite is already line art -- white strokes and white bone on a
# black field, two colors and nothing in between -- so "ink" is just the light
# pixels. No palette classification and no background flood fill, both of which
# the Flowey source this replaced needed because it was a screenshot with an
# editor checkerboard behind it.
ink = [[sum(px[x, y]) > 384 for x in range(W)] for y in range(H)]

xs = [x for y in range(H) for x in range(W) if ink[y][x]]
ys = [y for y in range(H) for x in range(W) if ink[y][x]]
x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
bw, bh = x1 - x0 + 1, y1 - y0 + 1
print(f"sprite bbox: {bw}x{bh} at ({x0},{y0})")


# ---- detect logical grid: try N cells across, score reconstruction ----
# The wiki sprite is a 2x upscale, so this settles on half the bbox width. The
# search keeps the script honest if the source is ever re-fetched at another
# scale; it currently reconstructs with 0% error.
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
            on = off = 0
            for yy in range(cy0, max(cy0 + 1, cy1)):
                for xx in range(cx0, max(cx0 + 1, cx1)):
                    if ink[min(yy, H - 1)][min(xx, W - 1)]:
                        on += 1
                    else:
                        off += 1
            row.append(on > off)
        grid.append(row)
    return grid, pitch, n_down


def score(grid, pitch, n_down):
    # fraction of source pixels that disagree with their cell's majority value
    bad = tot = 0
    for gy in range(n_down):
        for gx in range(len(grid[0])):
            cx0, cx1 = x0 + int(gx * pitch), x0 + int((gx + 1) * pitch)
            cy0, cy1 = y0 + int(gy * pitch), y0 + int((gy + 1) * pitch)
            for yy in range(cy0, max(cy0 + 1, cy1)):
                for xx in range(cx0, max(cx0 + 1, cx1)):
                    tot += 1
                    if ink[min(yy, H - 1)][min(xx, W - 1)] != grid[gy][gx]:
                        bad += 1
    return bad / tot


best = None
for n in range(16, 81):
    grid, pitch, n_down = sample_grid(n)
    s = score(grid, pitch, n_down)
    if best is None or s < best[0]:
        best = (s, n, grid, n_down)
s, n_across, grid, n_down = best
print(f"best grid: {n_across}x{n_down} cells (error {s:.3%})")

# ---- emit plain-text half-blocks (what the greeter shows) ----
# tuigreet styles the whole greeting with a single color (theme key `greet`),
# which costs nothing here: the sprite is monochrome to begin with. So this is
# the sprite itself, not the outline-only reduction Flowey needed to avoid
# coming out as a shapeless blob. There is likewise no point emitting a colored
# ANSI variant -- see the note on greeterCommand in ../tuigreet.nix for why the
# greeting has to be plain text anyway.
if n_down % 2:
    grid.append([False] * n_across)

txt_lines = []
for gy in range(0, len(grid), 2):
    row = []
    for gx in range(n_across):
        top, bot = grid[gy][gx], grid[gy + 1][gx]
        row.append("█" if top and bot else "▀" if top else "▄" if bot else " ")
    # trailing blanks would be drawn as (themed) spaces, so drop them
    txt_lines.append("".join(row).rstrip())

with open(OUT_TXT, "w") as f:
    f.write("\n".join(txt_lines) + "\n")
print(f"wrote {OUT_TXT}: {max(len(l) for l in txt_lines)} cols x {len(txt_lines)} text rows")

# ---- render preview PNG (square pixels, on dark bg, in the greeter's color) ----
SCALE = 12
BONE = (216, 208, 192)  # palette.nix `fg`, which is what `greet` is set to
pv = Image.new("RGB", (n_across * SCALE, len(grid) * SCALE), (28, 27, 25))
d = ImageDraw.Draw(pv)
for gy, row in enumerate(grid):
    for gx, on in enumerate(row):
        if on:
            d.rectangle([gx*SCALE, gy*SCALE, (gx+1)*SCALE-1, (gy+1)*SCALE-1], fill=BONE)
pv.save(OUT_PNG)
print(f"wrote {OUT_PNG}")
