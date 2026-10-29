#!/usr/bin/env python3
"""Crystal Clear player sheets -> a Game Boy look.

Crystal Clear's player sprite sheets all share one layout: two palette rows
(Greyscale, Injecting), then the front (56x56), back (48x48), trainer card
(40x56), walking (16x96), surfing (16x96), fishing (72x8) and sword (72x8)
sprites, each marked by a blue pixel just above its top-left corner and a
green one just below its bottom-right. This finds those marks, so the sheet
can sit anywhere on the image and be scaled up by a whole number.

It writes Crystal Lens's own files, so the folder works in both mods:
  front.png, back.png, trainerCard.png        the greyscale pics
  frontColor.png, backColor.png,
  trainerCardColor.png                        coloured with the Injecting row
  overworldWalk.png, overworldSurf.png        the overworld strips
  overworldFishFront/Back/Side.png            fishing poses (tiles 1-6)
  overworldFishRod.png                        the rod tiles (7 and 8)
The pics' white backdrop (white touching the edge) becomes see-through, and
so does every white pixel of the overworld art, as on the Game Boy. The
sword isn't used. meta.json (created if the folder has none) gets:
  "overworldColors"   the Injecting row, so the overworld sprites wear the
                      sheet's colours in both mods (--keep-colors leaves
                      the folder's own, or Crystal Lens's)
  "fishRod": "gen2"   the rod is drawn the way Gen 2 places it

  python3 crystal_clear.py sheet.png ../../assets/sprites/mylook
  python3 crystal_clear.py sheet.png ./out --no-meta
  python3 crystal_clear.py sheet.png ./out --meta-out keys.json
--meta-out writes only the keys to add, to its own file.

Needs Pillow. -Elvie"""
import json, os, sys
from collections import deque
from PIL import Image

BLUE, GREEN = (0, 0, 255), (0, 255, 0)
CLEAR = (0, 0, 0, 0)

# Each sprite by its size, in reading order when two share one. -Elvie
SPRITES = {(56, 56): ["front"], (48, 48): ["back"], (40, 56): ["card"],
           (16, 96): ["walk", "surf"], (72, 8): ["fishing", "sword"]}


def marks(im, color):
    """Square blobs of exactly `color`: [(x, y, size)], one per mark."""
    W, H = im.size
    px = im.load()
    seen = bytearray(W * H)
    out = []
    for y in range(H):
        for x in range(W):
            if seen[y * W + x] or px[x, y][:3] != color or px[x, y][3] < 128:
                continue
            q, pts = deque([(x, y)]), []
            seen[y * W + x] = 1
            while q:
                a, b = q.popleft()
                pts.append((a, b))
                for c, d in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
                    if 0 <= c < W and 0 <= d < H and not seen[d * W + c] \
                            and px[c, d][:3] == color and px[c, d][3] >= 128:
                        seen[d * W + c] = 1
                        q.append((c, d))
            xs = [p[0] for p in pts]
            ys = [p[1] for p in pts]
            w, h = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
            if w == h and len(pts) == w * h:
                out.append((min(xs), min(ys), w))
    return out


def find(im):
    """The scale and every sprite's box (in sheet pixels), by name."""
    greens = marks(im, GREEN)
    if not greens:
        sys.exit("no Crystal Clear marks found: is this a Crystal Clear player sheet?")
    scale = min(g[2] for g in greens)
    blues = [b for b in marks(im, BLUE) if b[2] == scale]
    boxes = []
    for gx, gy, _ in greens:
        best = None
        for bx, by, _ in blues:
            w, h = (gx - bx) // scale - 1, (gy - by) // scale - 1
            if (w, h) in SPRITES and (gx - bx) % scale == 0 and (gy - by) % scale == 0:
                if best is None or w * h < best[2] * best[3]:
                    best = (bx + scale, by + scale, w, h)
        if best:
            boxes.append(best)
    found = {}
    for size, names in SPRITES.items():
        same = sorted((b for b in boxes if (b[2], b[3]) == size), key=lambda b: (b[0], b[1]))
        for name, box in zip(names, same):
            found[name] = box
    return scale, found


def swatches(im, scale, below):
    """Blue-outlined palette squares above `below` (the top of the front
    sprite): [[rgb, rgb, rgb, rgb], ...] by row, top first. -Elvie"""
    W, H = im.size
    px = im.load()
    blue = [[px[x, y][:3] == BLUE and px[x, y][3] >= 128 for x in range(W)] for y in range(below)]
    rows = {}
    for y in range(1, below - 1):
        for x in range(1, W - 1):
            # inside a square: not blue, with blue straight above and left -Elvie
            if blue[y][x] or not blue[y - 1][x] or not blue[y][x - 1]:
                continue
            if blue[y - 1][x - 1] is False:
                continue
            x2 = x
            while x2 < W - 1 and not blue[y][x2]:
                x2 += 1
            y2 = y
            while y2 < below - 1 and not blue[y2][x]:
                y2 += 1
            if x2 - x < 4 * scale or x2 - x != y2 - y or x2 >= W - 1 or not blue[y][x2]:
                continue
            c = px[x + (x2 - x) // 2, y + (y2 - y) // 2]
            if c[3] < 128:
                continue
            rows.setdefault(y, []).append((x, c[:3]))
    out = [[c for _, c in sorted(r)] for _, r in sorted(rows.items()) if len(r) == 4]
    return out


def shade_map(grey, inject):
    """rgb -> shade 0-3 (0 lightest). The two palette rows line up by
    position, and a sheet may draw a sprite in either, so a pixel takes
    the shade of the swatch it's closest to in both rows. -Elvie"""
    grey = grey or [(255, 255, 255), (170, 170, 170), (85, 85, 85), (0, 0, 0)]
    refs = [(i, c) for i, c in enumerate(grey)] + [(i, c) for i, c in enumerate(inject or [])]

    def shade(c):
        return min(refs, key=lambda r: sum((c[k] - r[1][k]) ** 2 for k in range(3)))[0]
    return shade, grey


def cut(im, scale, box):
    x, y, w, h = box
    part = im.crop((x, y, x + w * scale, y + h * scale))
    return part.resize((w, h), Image.NEAREST) if scale > 1 else part


def shaded(part, shade):
    """Each pixel's shade (0 lightest), -1 for see-through. -Elvie"""
    W, H = part.size
    px = part.load()
    return [[-1 if px[x, y][3] < 128 else shade(px[x, y][:3]) for x in range(W)] for y in range(H)]


def backdrop(grid):
    """Shade-0 pixels joined to the edge: the pic's backdrop. -Elvie"""
    H, W = len(grid), len(grid[0])
    out = [[False] * W for _ in range(H)]
    q = deque((x, y) for y in range(H) for x in range(W)
              if (x in (0, W - 1) or y in (0, H - 1)) and grid[y][x] <= 0)
    for x, y in q:
        out[y][x] = True
    while q:
        x, y = q.popleft()
        for c, d in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= c < W and 0 <= d < H and not out[d][c] and grid[d][c] <= 0:
                out[d][c] = True
                q.append((c, d))
    return out


def paint(grid, colors, clear):
    H, W = len(grid), len(grid[0])
    im = Image.new("RGBA", (W, H), CLEAR)
    px = im.load()
    for y in range(H):
        for x in range(W):
            s = grid[y][x]
            if s >= 0 and not clear(x, y, s):
                px[x, y] = tuple(colors[s]) + (255,)
    return im


def convert(src, dst, meta=True, colors_too=True, meta_out=None):
    im = Image.open(src).convert("RGBA")
    scale, found = find(im)
    missing = [n for n in ("front", "back", "card", "walk", "surf", "fishing") if n not in found]
    rows = swatches(im, scale, found["front"][1] if "front" in found else im.size[1])
    grey, inject = (rows[0], rows[1]) if len(rows) >= 2 else (rows[0] if rows else None, None)
    shade, ref = shade_map(grey, inject)
    colors = inject
    print(f"  sheet   scale {scale}x, {len(found)} sprites, palettes: "
          + ("greyscale and injecting" if colors else "greyscale only" if grey else "none (by brightness)"))
    os.makedirs(dst, exist_ok=True)
    wrote = []

    def save(img, name):
        img.save(os.path.join(dst, name))
        wrote.append(name)
        print(f"  wrote   {name} ({img.size[0]}x{img.size[1]})")

    for key, base in (("front", "front"), ("back", "back"), ("card", "trainerCard")):
        if key not in found:
            continue
        grid = shaded(cut(im, scale, found[key]), shade)
        bg = backdrop(grid)
        drop = lambda x, y, s: bg[y][x]
        save(paint(grid, ref, drop), base + ".png")
        if colors:
            save(paint(grid, colors, drop), base + "Color.png")
    # overworld: white is see-through, as the Game Boy draws sprites -Elvie
    ow = lambda x, y, s: s == 0
    for key, name in (("walk", "overworldWalk.png"), ("surf", "overworldSurf.png")):
        if key in found:
            save(paint(shaded(cut(im, scale, found[key]), shade), ref, ow), name)
    if "fishing" in found:
        strip = paint(shaded(cut(im, scale, found["fishing"]), shade), ref, ow)
        # tiles 1-2 down, 3-4 up, 5-6 left, 7 and 8 the rod (Crystal's own
        # fishing tiles, pokecrystal gfx/overworld/kris_fish.png order) -Elvie
        for i, name in enumerate(("overworldFishFront.png", "overworldFishBack.png", "overworldFishSide.png")):
            save(strip.crop((i * 16, 0, i * 16 + 16, 8)), name)
        rod = Image.new("RGBA", (8, 16), CLEAR)
        rod.paste(strip.crop((48, 0, 56, 8)), (0, 0))
        rod.paste(strip.crop((56, 0, 64, 8)), (0, 8))
        save(rod, "overworldFishRod.png")
    if "sword" in found:
        print("  skip    sword (Gen 3 has no use for it)")
    for n in missing:
        print(f"  warning no {n} sprite found on the sheet")
    keys = {}
    if colors and colors_too and any(n.startswith("overworld") for n in wrote):
        # shade 0 is see-through on the overworld, but both mods want 4 -Elvie
        keys["overworldColors"] = [list(c) for c in colors]
    if "overworldFishRod.png" in wrote:
        keys["fishRod"] = "gen2"
    if meta_out:
        with open(meta_out, "w", encoding="utf-8") as f:
            json.dump(keys, f)
        print(f"  meta    {os.path.basename(meta_out)}: " + ", ".join(keys))
    elif meta and keys:
        path = os.path.join(dst, "meta.json")
        data = {}
        if os.path.isfile(path):
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
        else:
            data = {"label": os.path.basename(os.path.normpath(dst)).upper()[:12], "genderMode": "girl",
                    "generation": 2}
        data.update(keys)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")
        print("  meta    meta.json: " + ", ".join(keys))
    return wrote


if __name__ == "__main__":
    flags = sys.argv[1:]
    out = flags[flags.index("--meta-out") + 1] if "--meta-out" in flags[:-1] else None
    args = [a for a in flags if not a.startswith("--") and a != out]
    if len(args) != 2:
        sys.exit(__doc__)
    convert(args[0], args[1], meta="--no-meta" not in flags, colors_too="--keep-colors" not in flags, meta_out=out)
