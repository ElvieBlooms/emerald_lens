#!/usr/bin/env python3
"""Emerald Lens sheet importer: turns a sprite sheet made for something else
(a fan game, a community collage) into our combined sheets, ready to touch up
and pack. Nothing is resized: sprites are cut out at their real size and set
into our frames.

slice   Clean a sheet up and number every sprite on it. Writes a preview with
        the numbers, to look at while writing a recipe:
          python3 import_sheet.py slice rikku.png rikku_numbers.png
        A folder of images is numbered as one sheet. A big folder's preview
        is split into pages (rikku_numbers.png, rikku_numbers-2.png...).

build   Use a recipe to fill our combined sheet (and the extras sheet) from a
        source sheet. Check the result, then pack it as usual:
          python3 import_sheet.py build rikku.png rikku.json ./rikku-out
        Point it at a folder instead for one-file-per-action sets laid out
        on a grid (Pokemon Essentials charsets); the recipe then names the
        file for each section:
          python3 import_sheet.py build ./kris-pack kris-pack.json ./kris-out

Recipes are JSON; see README.md and the examples in recipes/.
Needs Pillow (python3 -m pip install --user pillow).
"""
import json, os, sys
from collections import Counter, deque
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pack_gen3 as P

CLEAR = (0, 0, 0, 0)

def pixels(im):
    # Pillow 12 renamed getdata; use whichever this Pillow has. -Elvie
    f = getattr(im, "get_flattened_data", None)
    return f() if f else im.getdata()

def looks_like_preview(im):
    """True for a numbers preview from `slice` (its dark backdrop and magenta
    boxes) rather than a source sheet. -Elvie"""
    counts = Counter(p[:3] for p in pixels(im.convert("RGBA")))
    total = sum(counts.values())
    return counts.most_common(1)[0][0] == (48, 48, 56) and counts[(255, 0, 255)] > total * 0.002

# ------------------------------------------------------------------ cleaning

def parse_color(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))

def find_background(im):
    """A flat colour used to fill the space around the sprites, if there is
    one: the most common solid colour, when it covers a big share of the
    sheet (sprites are many colours, a backdrop is one). Fully transparent
    pixels always count as background too."""
    counts = Counter(p[:3] for p in pixels(im) if p[3] > 0)
    if not counts:
        return None
    color, count = counts.most_common(1)[0]
    return color if count > sum(counts.values()) * 0.3 else None

def find_scale(im):
    """Sheets are often blown up 2x, 3x or 4x, so every run of same-coloured
    pixels is a multiple of that. Returns the biggest scale (4, 3 or 2) that
    nearly all runs fit, or 1."""
    px = im.load()
    W, H = im.size
    runs = Counter()
    for y in range(0, H, 3):
        run = 1
        for x in range(1, W + 1):
            if x < W and px[x, y] == px[x - 1, y]:
                run += 1
                continue
            if px[x - 1, y][3]:
                runs[run] += 1
            run = 1
    total = sum(c for r, c in runs.items() if r <= 16)
    for s in (4, 3, 2):
        fit = sum(c for r, c in runs.items() if r <= 16 and r % s == 0)
        if total and fit >= total * 0.9:
            return s
    return 1

def unscale_piece(im, box, s):
    """One piece shrunk back to its real size. Collages paste pieces at any
    pixel, so each picks the block grid that fits it best."""
    crop = im.crop(box)
    px = crop.load()
    W, H = crop.size
    best = None
    for ox in range(s):
        for oy in range(s):
            bad = 0
            for by in range(oy, H - s + 1, s):
                for bx in range(ox, W - s + 1, s):
                    p = px[bx, by]
                    if any(px[bx + i, by + j] != p for i in range(s) for j in range(s)):
                        bad += 1
            if best is None or bad < best[0]:
                best = (bad, ox, oy)
    _, ox, oy = best
    # pad so blocks cut at the edges still count
    padded = Image.new("RGBA", (W + 2 * s, H + 2 * s), CLEAR)
    padded.paste(crop, (s, s))
    x0, y0 = (s + ox) % s, (s + oy) % s
    w, h = (padded.width - x0) // s, (padded.height - y0) // s
    small = padded.crop((x0, y0, x0 + w * s, y0 + h * s)).resize((w, h), Image.NEAREST)
    return small, (box[0] - s + x0) // s, (box[1] - s + y0) // s

def is_lossy(im):
    """A sheet saved as JPEG or WebP (Discord and many hosts convert them)
    smears every colour into thousands of near-copies. Pixel art has a few
    dozen. -Elvie"""
    return len(Counter(p[:3] for p in pixels(im) if p[3])) > 4000

def luma(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]

def near_background(im, tol=20):
    """For a lossy sheet: the colour covering most of it, and every pixel
    close to it that's part of the backdrop (touching the edge, or a patch
    big enough to be a gap between limbs) made exactly that colour. Small
    light patches inside a sprite, like eye whites, stay. Close means within
    `tol` in brightness; colour gets more slack, since JPEG and WebP keep
    colour at half resolution and bleed it into the backdrop. -Elvie"""
    counts = Counter(p[:3] for p in pixels(im) if p[3])
    bg = counts.most_common(1)[0][0]
    W, H = im.size
    px = im.load()
    lb = luma(bg)
    close = lambda p: p[3] == 0 or (abs(luma(p) - lb) <= tol
                                    and max(abs(p[i] - bg[i]) for i in range(3)) <= 4 * tol)
    seen = bytearray(W * H)
    for y in range(H):
        for x in range(W):
            if seen[y * W + x] or not close(px[x, y]):
                continue
            q, group, edge = deque([(x, y)]), [], False
            seen[y * W + x] = 1
            while q:
                a, b = q.popleft()
                group.append((a, b))
                edge = edge or a in (0, W - 1) or b in (0, H - 1)
                for c, d in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
                    if 0 <= c < W and 0 <= d < H and not seen[d * W + c] and close(px[c, d]):
                        seen[d * W + c] = 1
                        q.append((c, d))
            if edge or len(group) >= 12:
                for a, b in group:
                    px[a, b] = bg + (255,)
    return bg

def snap_colors(im, colors=48):
    """For a lossy sheet: every drawn pixel snapped to a palette of the
    sheet's main colours, so a flat area is flat again. -Elvie"""
    drawn = [p[:3] for p in pixels(im) if p[3]]
    if not drawn:
        return
    sample = Image.new("RGB", (len(drawn), 1))
    sample.putdata(drawn)
    pal = sample.quantize(colors, method=Image.Quantize.MEDIANCUT, kmeans=4)
    lut = pixels(pal.convert("RGB"))
    mapping = dict(zip(drawn, lut))
    im.putdata([mapping[p[:3]] + (255,) if p[3] else CLEAR for p in pixels(im)])

def clear_backdrop(im, background):
    """Clears the backdrop colour: "auto" finds it, a hex colour names it,
    "none" clears nothing (only pixels already transparent count, for
    sheets whose backdrop colour is also used in the sprites). -Elvie"""
    if background == "none":
        return None
    bg = parse_color(background) if background not in (None, "auto") else find_background(im)
    if bg:
        im.putdata([CLEAR if p[3] and p[:3] == bg else p for p in pixels(im)])
    return bg

def clean(path, scale=None, background=None, lossy="auto", colors=48):
    """Loads a sheet at its real size with the background made transparent.
    Returns (image, scale used, background colour or None)."""
    im = Image.open(path).convert("RGBA")
    # Transparent pixels can carry any colour underneath; make them all the
    # same so they don't look like detail.
    im.putdata([p if p[3] else CLEAR for p in pixels(im)])
    if lossy == "auto":
        lossy = is_lossy(im)
    if lossy and background == "none":
        snap_colors(im, colors)
        print(f"  lossy   sheet looks like a JPEG/WebP; colours snapped to {colors}, no backdrop cleared")
    elif lossy:
        found = near_background(im)
        if background in (None, "auto"):
            background = "%02x%02x%02x" % found
        bgc = parse_color(background)
        im.putdata([CLEAR if p[3] and p[:3] == bgc else p for p in pixels(im)])
        snap_colors(im, colors)
        print(f"  lossy   sheet looks like a JPEG/WebP; backdrop cleared and colours snapped to {colors}")
    bg = clear_backdrop(im, background)
    if scale is None:
        scale = find_scale(im)
    if scale > 1:
        small = Image.new("RGBA", (im.width // scale + 2, im.height // scale + 2), CLEAR)
        for box in find_pieces(im, reach=scale, min_pixels=12 * scale * scale, order=False):
            piece, x, y = unscale_piece(im, box, scale)
            small.alpha_composite(piece, (max(0, x), max(0, y)))
        im = small
    return im, scale, bg

# ----------------------------------------------------------------- detecting

def find_pieces(im, reach=1, min_pixels=12, order=True):
    """Every separate sprite on the sheet, as bounding boxes, numbered in
    reading order: top to bottom in rows, left to right within a row.
    Pixels up to `reach` apart count as touching, so a rod or a loose hair
    strand stays with its sprite."""
    W, H = im.size
    alpha = im.getchannel("A").load()
    seen = bytearray(W * H)
    boxes = []
    for y in range(H):
        for x in range(W):
            if alpha[x, y] == 0 or seen[y * W + x]:
                continue
            q = deque([(x, y)])
            seen[y * W + x] = 1
            x0 = x1 = x
            y0 = y1 = y
            n = 0
            while q:
                a, b = q.popleft()
                n += 1
                x0, x1, y0, y1 = min(x0, a), max(x1, a), min(y0, b), max(y1, b)
                for db in range(-reach, reach + 1):
                    d = b + db
                    if d < 0 or d >= H:
                        continue
                    for da in range(-reach, reach + 1):
                        c = a + da
                        if 0 <= c < W and not seen[d * W + c] and alpha[c, d]:
                            seen[d * W + c] = 1
                            q.append((c, d))
            if n >= min_pixels:
                boxes.append((x0, y0, x1 + 1, y1 + 1))
    if not order:
        return boxes
    # Rows: a piece joins a row if it overlaps the row's middle band.
    boxes.sort(key=lambda b: (b[1] + b[3]) / 2)
    rows = []
    for b in boxes:
        cy = (b[1] + b[3]) / 2
        for row in rows:
            if row["y0"] <= cy <= row["y1"]:
                row["items"].append(b)
                break
        else:
            h = b[3] - b[1]
            rows.append({"y0": cy - h * 0.35, "y1": cy + h * 0.35, "items": [b]})
    rows.sort(key=lambda r: r["y0"])
    ordered = []
    for row in rows:
        ordered.extend(sorted(row["items"], key=lambda b: b[0]))
    return ordered

def preview(im, pieces, zoom=3, first=1):
    """The cleaned sheet blown up, every piece boxed and numbered (from
    first)."""
    W, H = im.size
    out = Image.new("RGBA", (W * zoom, H * zoom), (48, 48, 56, 255))
    out.alpha_composite(im.resize((W * zoom, H * zoom), Image.NEAREST))
    d = ImageDraw.Draw(out)
    font = ImageFont.load_default()
    for i, (x0, y0, x1, y1) in enumerate(pieces, first):
        d.rectangle((x0 * zoom - 1, y0 * zoom - 1, x1 * zoom, y1 * zoom), outline=(255, 0, 255, 255))
        label = str(i)
        tx, ty = x0 * zoom, max(0, y0 * zoom - 11)
        d.rectangle((tx, ty, tx + 6 * len(label) + 2, ty + 10), fill=(255, 0, 255, 255))
        d.text((tx + 1, ty - 1), label, fill=(255, 255, 255, 255), font=font)
    return out

# ------------------------------------------------------------------ building

# Where a sprite's lowest pixel goes in each kind of frame, measured from the
# game's own art (most stand on the frame's bottom row). Sprites are centred
# across. -Elvie
FOOT = {
  "frlg": {"surf.png": 30, "flyBird.png": 47, "front.png": 63, "intro.png": 93,
           "surfBlob.png": 30, "bird.png": 47, "bag.png": 60},
  "rse":  {"underwater.png": 29, "front.png": 63, "mapIcon.png": 15, "bag.png": 60},
  # Game Boy: everything stands on the frame's bottom row -Elvie
  "gb": {},
}

def foot(family, name, h, index=None):
    """The row a sprite's bottom edge goes on: per frame where the game's
    frames differ (pack_gen3.GAME_FEET), else per file."""
    base = P.base_of(family).replace("_extras", "")
    rows = P.feet_rows(base, name, index) if index is not None else ()
    if rows:
        return rows[0] + 1
    return FOOT[base].get(name, h)

def sections(family):
    """Recipe keys and their frames; see pack_gen3.sections. -Elvie"""
    return P.sections(family)

def split_boxes(pieces, split):
    """Sprites drawn touching each other come out as one piece. The recipe's
    "split" names them with how many columns (and rows) to cut them into:
    {"29": 4} or {"29": [4, 1]}. The parts are "29.1", "29.2"... left to
    right, then top to bottom. Returns {name: box}."""
    named = {str(i): b for i, b in enumerate(pieces, 1)}
    for key, grid in (split or {}).items():
        cols, rows = (grid, 1) if isinstance(grid, int) else grid
        x0, y0, x1, y1 = named[str(key)]
        cw, ch = (x1 - x0) / cols, (y1 - y0) / rows
        for r in range(rows):
            for c in range(cols):
                named[f"{key}.{r * cols + c + 1}"] = (round(x0 + c * cw), round(y0 + r * ch),
                                                     round(x0 + (c + 1) * cw), round(y0 + (r + 1) * ch))
    return named

def cut_cells(pieces, cells):
    """The parts of a strip frame that was cut ("12.1", "12.2"): frames
    too, kept where they are in their part of the cell. For a strip read
    as frames twice too wide. -Elvie"""
    return {n for n in pieces if "." in n and n.rsplit(".", 1)[0] in cells}

def tight(im, box):
    """A box shrunk to the pixels actually drawn inside it."""
    bb = im.crop(box).getchannel("A").getbbox()
    return (box[0] + bb[0], box[1] + bb[1], box[0] + bb[2], box[1] + bb[3]) if bb else None

# --------------------------------------------------------- numbered folders
# A folder of loose images (a character compilation: strips in the decomp's
# own format, a collage, a back pic...) numbered as if it were one sheet.
# Strips are cut into frames and every frame keeps its place in its cell,
# since that art is already lined up; anything else is cut into pieces as
# usual. -Elvie

IMAGE_EXT = (".png", ".gif", ".bmp", ".webp", ".jpg", ".jpeg")

def crossing_rows(im, x):
    """Rows with sprite pixels on both sides of column boundary x."""
    a = im.getchannel("A").load()
    return sum(1 for y in range(im.height) if a[x - 1, y] and a[x, y])

def crossings(im, xs):
    """How many of the column boundaries in xs have sprite pixels on both
    sides in 3 or more rows (so a frame edge can't be there)."""
    return sum(crossing_rows(im, x) >= 3 for x in xs)

def wide_frames(im, half, whole):
    """True if a strip's frames are the wider size. Sprites that fill their
    16-wide frames touch at every edge, so the half-way lines are crossed
    too, but only a pixel or two, like the frame edges. Frames twice that
    wide have a sprite's middle on each half-way line. -Elvie"""
    halves = [x for x in range(half, im.width, half) if x % whole]
    edges = list(range(whole, im.width, whole))
    if not edges:
        return crossings(im, halves) > 0
    mean = lambda xs: sum(crossing_rows(im, x) for x in xs) / len(xs)
    return mean(halves) >= mean(edges) + 3

def strip_cells(im):
    """Frame size if the image is a strip of frames: side by side (height up
    to 96, frames as wide as it is tall or half that) or one under the next
    (width up to 96, square frames). None for anything else."""
    w, h = im.size
    if h <= 96 and w >= h:
        cands = [c for c in (h, h // 2) if c and w % c == 0]
        if len(cands) == 2:
            return (cands[0], h) if wide_frames(im, cands[1], cands[0]) else (cands[1], h)
        return (cands[0], h) if cands else None
    if w <= 96 and h > w and h % w == 0:
        return (w, w)
    return None

def load_numbered_folder(folder, opts):
    """All images in a folder as one sheet. Returns (image, pieces, cells,
    rows): pieces numbered from 1 across the folder (files in name order),
    cells the numbers that are strip frames, rows (file, y, mode, first,
    last) for the preview."""
    steps = numbered_folder(folder, opts)
    while True:
        try:
            next(steps)
        except StopIteration as done:
            sheet, pieces, cells, rows, aliases = done.value
            load_numbered_folder.aliases = aliases
            return sheet, pieces, cells, rows

def numbered_folder(folder, opts):
    """load_numbered_folder a file at a time: yields (done, total) after
    each file is read, then returns its result plus the aliases. The web
    page steps through it to show progress. -Elvie"""
    files = sorted(f for f in os.listdir(folder) if f.lower().endswith(IMAGE_EXT))
    override = {k: v for k, v in opts.get("cells", {}).items()}
    loaded = []
    for i, f in enumerate(files):
        path = os.path.join(folder, f)
        with Image.open(path) as probe:
            skip = looks_like_preview(probe)
        if not skip:
            im, _, _ = clean(path, opts.get("scale"), opts.get("background", "auto"),
                             opts.get("lossy", "auto"), opts.get("colors", 48))
            cell = override.get(f, "auto")
            cell = strip_cells(im) if cell == "auto" else (None if cell == "pieces" else tuple(cell))
            loaded.append((f, im, cell))
        yield i + 1, len(files)
    LABEL, GAP = 12, 6
    W = max([im.width for _, im, _ in loaded] or [1])
    H = sum(LABEL + im.height + GAP for _, im, _ in loaded)
    sheet = Image.new("RGBA", (W, max(1, H)), CLEAR)
    pieces, cells, rows, n, y = {}, set(), [], 0, 0
    aliases = {}
    for f, im, cell in loaded:
        y += LABEL
        sheet.alpha_composite(im, (0, y))
        first = n + 1
        if cell:
            cw, ch = cell
            k = 0
            stem = os.path.splitext(f)[0]
            for cy in range(0, im.height - ch + 1, ch):
                for cx in range(0, im.width - cw + 1, cw):
                    n += 1
                    pieces[str(n)] = (cx, y + cy, cx + cw, y + cy + ch)
                    cells.add(str(n))
                    # also "walking:3": frame 3 of walking.png, counting
                    # from 0 like the game -Elvie
                    aliases[f"{stem}:{k}"] = str(n)
                    k += 1
            nf = (im.width // cw) * (im.height // ch)
            mode = f"{nf} frame{'s' if nf > 1 else ''} of {cw}x{ch}, {stem}:0-{nf - 1}"
        else:
            for x0, y0, x1, y1 in find_pieces(im, opts.get("reach", 1)):
                n += 1
                pieces[str(n)] = (x0, y + y0, x1, y + y1)
            mode = f"{n - first + 1} pieces"
        rows.append((f, y - LABEL, mode, first, n))
        y += im.height + GAP
    return sheet, pieces, cells, rows, aliases

# A big folder drawn as one preview runs out of memory (in a browser most of
# all), so the preview is split into pages of whole files, each at most this
# many sheet pixels (about 21 MB once drawn 3x) and this tall. -Elvie
PAGE_AREA, PAGE_TALL = 600_000, 4000

def folder_pages(rows, width, height):
    """Pages for a folder's preview: (top, bottom, first row, end row)."""
    tall = max(1, min(PAGE_TALL, PAGE_AREA // max(1, width)))
    ends = [r[1] for r in rows[1:]] + [height]
    pages, start = [], 0
    for i in range(1, len(rows)):
        if ends[i] - rows[start][1] > tall:
            pages.append((rows[start][1], rows[i][1], start, i))
            start = i
    pages.append((rows[start][1] if rows else 0, height, start, len(rows)))
    return pages

def page_name(out, k):
    """numbers.png, numbers-2.png, numbers-3.png..."""
    stem, ext = os.path.splitext(out)
    return out if k == 0 else f"{stem}-{k + 1}{ext}"

def folder_preview(sheet, pieces, cells, rows, zoom=3, page=None):
    top, bottom, r0, r1 = page or (0, sheet.height, 0, len(rows))
    part = rows[r0:r1]
    first = part[0][3] if part else 1
    last = part[-1][4] if part else 0
    boxes = [pieces[str(i)] for i in range(first, last + 1)]
    boxes = [(x0, y0 - top, x1, y1 - top) for x0, y0, x1, y1 in boxes]
    out = preview(sheet.crop((0, top, sheet.width, bottom)), boxes, zoom, first)
    d = ImageDraw.Draw(out)
    font = ImageFont.load_default()
    for f, y, mode, a, b in part:
        d.text((2, (y - top) * zoom), f"{f}  ({mode}, {a}-{b})", fill=(255, 255, 160, 255), font=font)
    return out

def folder_report(rows, pieces, pages, out):
    """What slice prints for a folder."""
    lines = [f"  {first:>4}-{last:<4} {f}: {mode}" for f, _, mode, first, last in rows]
    if len(pages) == 1:
        lines.append(f"  folder  {len(rows)} images, {len(pieces)} numbered -> {out}")
        return "\n".join(lines)
    for k, (_, _, r0, r1) in enumerate(pages):
        a, b = rows[r0], rows[r1 - 1]
        nums = f"pieces {a[3]}-{b[4]}" if b[4] >= a[3] else "no pieces"
        lines.append(f"  page {k + 1:<3} {a[0]} to {b[0]}, {nums} -> {page_name(out, k)}")
    lines.append(f"  folder  {len(rows)} images, {len(pieces)} numbered -> "
                 f"{len(pages)} pages, {page_name(out, 0)} to {os.path.basename(page_name(out, len(pages) - 1))}")
    return "\n".join(lines)

def folder_options(opts):
    """slice's options for a folder, from its command line flags."""
    opts = dict(zip(opts[::2], opts[1::2]))
    fo = {"reach": int(opts.get("--reach", 1)), "background": opts.get("--bg", "auto")}
    if "--scale" in opts: fo["scale"] = int(opts["--scale"])
    return fo

def piece_image(im, pieces, ref):
    """A recipe entry: a piece number ("29.2" for part of a split piece), a
    list drawn together as one sprite, or {"piece": ..., "flip": true}.
    {"piece": ..., "hang": 5} is for a rod or the like reaching 5 pixels
    below the feet: the feet stay on the frame's foot row instead. "shift"
    moves it right (or left, if negative) from the centre, to choose which
    side gets cut off when it's too wide. null leaves the frame blank."""
    if ref in (None, 0, []):
        return None
    flip, hang, shift = False, 0, 0
    if isinstance(ref, dict):
        flip = bool(ref.get("flip"))
        hang = int(ref.get("hang", 0))
        shift = int(ref.get("shift", 0))
        ref = ref.get("piece")
    nums = ref if isinstance(ref, list) else [ref]
    missing = [n for n in nums if str(n) not in pieces]
    if missing:
        sys.exit(f"recipe names {', '.join(map(str, missing))}, which isn't on the sheet (check the numbers or file:frame names)")
    cells = getattr(piece_image, "cells", ())
    if len(nums) == 1 and str(nums[0]) in cells:
        # a strip frame: whole cell, as drawn -Elvie
        sprite = im.crop(pieces[str(nums[0])])
        sprite = sprite.transpose(Image.FLIP_LEFT_RIGHT) if flip else sprite
        sprite.info.update(hang=hang, shift=shift, cell=True)
        return sprite
    boxes = [b for b in (tight(im, pieces[str(n)]) for n in nums) if b]
    if not boxes:
        return None
    x0, y0 = min(b[0] for b in boxes), min(b[1] for b in boxes)
    x1, y1 = max(b[2] for b in boxes), max(b[3] for b in boxes)
    sprite = Image.new("RGBA", (x1 - x0, y1 - y0), CLEAR)
    for b in boxes:
        sprite.alpha_composite(im.crop(b), (b[0] - x0, b[1] - y0))
    if any("." in str(n) for n in nums):
        # A cut through touching sprites can catch a stray pixel or two of
        # the neighbour; drop specks like that. -Elvie
        for box in find_pieces(sprite, reach=1, min_pixels=1, order=False):
            if (box[2] - box[0]) * (box[3] - box[1]) <= 4:
                sprite.paste(CLEAR, box)
        bb = sprite.getchannel("A").getbbox()
        if not bb:
            return None
        sprite = sprite.crop(bb)
    sprite = sprite.transpose(Image.FLIP_LEFT_RIGHT) if flip else sprite
    sprite.info["hang"] = hang
    sprite.info["shift"] = shift
    return sprite

def shrink(sprite, w, bottom, warn, where):
    """For a section listed under "shrink": a sprite too big for its frame
    is scaled down (nearest pixel, keeping its shape) until it fits. Rows
    and columns get dropped, so it's a starting point to clean up by hand,
    not a finished sprite. -Elvie"""
    k = min(1.0, w / sprite.width, bottom / sprite.height)
    if k >= 1.0:
        return sprite
    size = (max(1, int(sprite.width * k)), max(1, int(sprite.height * k)))
    warn.append(f"{where}: shrunk from {sprite.width}x{sprite.height} to {size[0]}x{size[1]}; touch it up by hand")
    return sprite.resize(size, Image.NEAREST)

def place(sprite, w, h, bottom, warn, where):
    """The sprite set into a w x h frame: centred, lowest pixel on `bottom`.
    Anything that doesn't fit is cut off, with a warning."""
    frame = Image.new("RGBA", (w, h), CLEAR)
    hang = sprite.info.get("hang", 0)
    x = (w - sprite.width) // 2 + sprite.info.get("shift", 0)
    y = bottom - sprite.height + hang
    if sprite.info.get("cell"):
        # strip frames are already placed in their cells: bottoms line up
        y = h - sprite.height + hang
        bb = sprite.getchannel("A").getbbox()
        if bb and (x + bb[0] < 0 or x + bb[2] > w or y + bb[1] < 0):
            warn.append(f"{where}: {sprite.width}x{sprite.height} frame doesn't fit {w}x{h}; the edges are cut off")
        frame.paste(sprite, (x, y), sprite)
        return frame
    if x < 0 or x + sprite.width > w or y < 0 or y + sprite.height > h + hang:
        warn.append(f"{where}: sprite is {sprite.width}x{sprite.height}, frame is {w}x{h}; the edges are cut off")
    frame.paste(sprite, (x, y), sprite)
    return frame

# Surf sprites drawn with the mount, as most fan games do, are cut in two
# using the game's own layout (see surf placement in README.md): in a 32x40
# cell the blob sits at (0, 8) and the player at (8, 0) on FRLG or (0, 0) on
# RSE. Whatever falls in the player's frame goes to surf.png, the rest to
# surfBlob.png. Since the game always draws them in that same spot, the
# result looks the same as the original, except for the moment the player
# hops on or off, when the blob is drawn by itself. -Elvie
SURF_FOOT = {"frlg": 38, "rse": 40}

def split_surf(family, sprite):
    pw, ph, _ = P.spec(family, "surf.png")
    cw, ch = P.SURF_CELL
    cell = place(sprite, cw, ch, SURF_FOOT[P.base_of(family)], [], "")
    px0 = P.SURF_TILE_AT[0] + (16 - pw) // 2
    player = cell.crop((px0, 0, px0 + pw, ph))
    blob = cell.copy()
    ImageDraw.Draw(blob).rectangle((px0, 0, px0 + pw - 1, ph - 1), fill=CLEAR)
    blob = blob.crop((P.SURF_BLOB_AT[0], P.SURF_BLOB_AT[1], P.SURF_BLOB_AT[0] + 32, P.SURF_BLOB_AT[1] + 32))
    return player, blob

def write_out(family, strips, filled, warn, out_dir):
    extras = P.EXTRAS_OF[family]
    os.makedirs(out_dir, exist_ok=True)
    for fam in (family, extras):
        if strips[fam]:
            out = os.path.join(out_dir, P.SHEET_FILE[fam])
            P.sheet_from_strips(fam, strips[fam]).save(out)
            print(f"  wrote   {out}")
    for name, w, h, n in P.SPECS[family] + P.SPECS[extras]:
        if filled[name]:
            print(f"  filled  {name}: {filled[name]} of {n} frames")
    for w in warn:
        print(f"  warning {w}")
    return True

# ------------------------------------------------------------- folder sets
# One image per action, each a grid of frames: a row per facing, a column
# per frame. Pokemon Essentials charsets are 4x4, rows down, left, right,
# up, columns stand, step, stand, step. Unlike a collage, every frame here
# sits in a cell drawn to line up with the others, so cells are placed as
# they are (not trimmed): the row the feet stand on in most cells goes on
# our frame's foot row, the cell's middle on the frame's middle. Bobs and
# rods keep where the artist put them. -Elvie

LAYOUTS = {"essentials": {"grid": (4, 4), "rows": ["down", "left", "right", "up"]},
           # HGSS / DPPt overworld files: 4 frames per facing (stand, step,
           # stand, step), facings up, down, left, right. -Elvie
           "hgss": {"grid": (4, 4), "rows": ["up", "down", "left", "right"]}}

def strip_grid(path, per, first, nrows):
    """A vertical strip of square frames (what HGSS/DPPt overworld files turn
    into, one frame under the next) laid out as a grid: `per` frames to a
    facing, starting at frame `first`. -Elvie"""
    im = Image.open(path).convert("RGBA")
    size = im.width
    grid = Image.new("RGBA", (size * per, size * nrows), CLEAR)
    for r in range(nrows):
        for c in range(per):
            k = first + r * per + c
            if (k + 1) * size <= im.height:
                grid.paste(im.crop((0, k * size, size, (k + 1) * size)), (c * size, r * size))
    return grid

def load_grid(path, cols, rows, scale=None, background="auto"):
    im = path if isinstance(path, Image.Image) else Image.open(path).convert("RGBA")
    im.putdata([p if p[3] else CLEAR for p in pixels(im)])
    bg = clear_backdrop(im, background)
    s = scale or find_scale(im)
    if s > 1:
        im = im.resize((im.width // s, im.height // s), Image.NEAREST)
    cw, ch = im.width // cols, im.height // rows
    cells = [[im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)) for c in range(cols)] for r in range(rows)]
    bottoms = Counter(bb[3] for row in cells for cell in row for bb in [cell.getchannel("A").getbbox()] if bb)
    feet = bottoms.most_common(1)[0][0] if bottoms else ch
    # A step can reach a row or two lower than standing; take the lowest of
    # those as the feet, so no foot gets cut off. A rod hanging well below
    # doesn't count. -Elvie
    feet = max([b for b in bottoms if b <= feet + 2] or [feet])
    return cells, (cw, ch), feet, s

def default_columns(key, n, one_row):
    """Which columns fill a section's frames, in our order, when the recipe
    doesn't say: stand, step, step (the Essentials stand at column 2 is
    skipped); 4 for fishing; sit, step, step, sit for surfing. Extra frames
    (Acro Bike tricks, say) repeat the standing frame so nothing goes
    blank; one-row actions (field move) count through and hold the last."""
    if key == "walk extra":
        return [0] * n
    if one_row:
        base = [0, 1, 2, 3]
        return (base + [base[-1]] * n)[:n]
    base = {"fish": [0, 1, 2, 3], "surf": [0, 1, 3, 0]}.get(key, [0, 1, 3])
    return (base + [0] * n)[:n]

def set_cell(cell, feet, w, h, bottom, warn, where):
    frame = Image.new("RGBA", (w, h), CLEAR)
    x, y = (w - cell.width) // 2, bottom - feet
    frame.paste(cell, (x, y), cell)
    bb = cell.getchannel("A").getbbox()
    if bb and (x + bb[0] < 0 or y + bb[1] < 0 or x + bb[2] > w or y + bb[3] > h):
        warn.append(f"{where}: doesn't fit a {w}x{h} frame; the edges are cut off")
    return frame

def build_folder(folder, recipe):
    family = recipe["family"]
    extras = P.EXTRAS_OF[family]
    targets = {family: sections(family), extras: sections(extras)}
    strips = {family: {}, extras: {}}
    warn, filled = [], Counter()
    layout = LAYOUTS[recipe.get("layout", "essentials")]

    def put(fam, name, index, frame):
        w, h, n = P.spec(fam, name)
        strip = strips[fam].setdefault(name, Image.new("RGBA", (w, h * n), CLEAR))
        strip.paste(frame, (0, index * h))
        filled[name] += 1

    for key, entry in recipe.get("files", {}).items():
        key = key.lower()
        entry = {"file": entry} if isinstance(entry, str) else dict(entry)
        fam = family if key in targets[family] else extras if key in targets[extras] else None
        if fam is None:
            warn.append(f"unknown section '{key}'")
            continue
        path = os.path.join(folder, entry["file"])
        if not os.path.exists(path):
            warn.append(f"{key}: {entry['file']} not found")
            continue
        rows = entry.get("rows", layout["rows"])
        if "strip" in entry:
            # {"file": ..., "strip": 4, "first": 16}: frames in a vertical strip,
            # 4 to a facing in `rows` order, from frame 16. -Elvie
            cols, nrows = int(entry["strip"]), len(rows)
            src = strip_grid(path, cols, int(entry.get("first", 0)), nrows)
        else:
            cols, nrows = entry.get("grid", layout["grid"])
            src = path
        cells, (cw, ch), feet, s = load_grid(src, cols, nrows, recipe.get("scale"), recipe.get("background", "auto"))
        one_row = sum(1 for row in cells if any(c.getchannel("A").getbbox() for c in row)) == 1
        print(f"  file    {entry['file']}: {cols}x{nrows} cells of {cw}x{ch}, scale {s}x, feet on row {feet}")
        for facing, slots in targets[fam][key].items():
            r = 0 if facing == "frames" else rows.index(facing)
            picks = entry.get("columns", {})
            picks = picks.get(facing) if isinstance(picks, dict) else picks
            picks = picks or default_columns(key, len(slots), one_row or facing == "frames")
            for (name, idx), c in zip(slots, picks):
                w, h, _ = P.spec(fam, name)
                put(fam, name, idx, set_cell(cells[r][c], feet, w, h, foot(fam, name, h), warn, f"{key} {facing}"))
    return family, strips, filled, warn

def build(src, recipe_path, out_dir):
    recipe = json.load(open(recipe_path))
    family = recipe["family"]
    if family not in P.EXTRAS_OF:
        sys.exit(f"recipe family must be frlg, rse, frlg_wide, rse_wide or gb, not {family}")
    piece_image.cells = ()
    if os.path.isdir(src) and "files" in recipe:
        return write_out(*build_folder(src, recipe), out_dir)
    if os.path.isdir(src):
        im, found, cells, rows = load_numbered_folder(src, recipe)
        pieces = split_boxes([found[str(i)] for i in range(1, len(found) + 1)], recipe.get("split"))
        for name, num in load_numbered_folder.aliases.items():
            pieces[name] = pieces[num]
            cells.add(name)
        cells |= cut_cells(pieces, cells)
        piece_image.cells = cells
        print(f"  folder  {os.path.basename(os.path.normpath(src))}: {len(rows)} images, {len(found)} numbered")
    else:
        if looks_like_preview(Image.open(src)):
            sys.exit(f"{os.path.basename(src)} looks like a numbers preview from slice. Build from the "
                     "original sheet you sliced; the preview is only for reading the numbers.")
        im, scale, bg = clean(src, recipe.get("scale"), recipe.get("background", "auto"),
                              recipe.get("lossy", "auto"), recipe.get("colors", 48))
        found = find_pieces(im, recipe.get("reach", 1))
        pieces = split_boxes(found, recipe.get("split"))
        print(f"  sheet   {os.path.basename(src)}: scale {scale}x, "
              f"background {'#%02x%02x%02x' % bg if bg else 'transparent'}, {len(found)} pieces")
    extras = P.EXTRAS_OF[family]
    targets = {family: sections(family), extras: sections(extras)}
    strips = {family: {}, extras: {}}
    warn, filled = [], Counter()
    shrink_keys = {k.lower() for k in recipe.get("shrink", [])}

    def put(fam, name, index, frame):
        w, h, n = P.spec(fam, name)
        strip = strips[fam].setdefault(name, Image.new("RGBA", (w, h * n), CLEAR))
        strip.paste(frame, (0, index * h))
        filled[name] += 1

    jobs = []
    for key, facings in recipe.get("sections", {}).items():
        key = key.lower()
        if isinstance(facings, list):
            # A plain list is fine for one-row sections (front, back, field
            # move...); sections with facings need them named. -Elvie
            known = {**targets[family], **targets[extras]}
            if "frames" in known.get(key, {}):
                facings = {"frames": facings}
            else:
                shape = '{"down": [...], "up": [...], "left": [...]}'
                warn.append(f"{key}: give the frames per facing, like \"{key}\": {shape}; skipped")
                continue
        if key == "surf with blob":
            # player + mount in one sprite, per facing: the surf frames in
            # order (sit, step, step, jump), split as above. The blob comes
            # from the first one or two, matching the blob's own frames.
            surf = targets[family]["surf"]
            blob = targets[extras]["surf blob"]
            for facing, refs in facings.items():
                frames = [piece_image(im, pieces, r) for r in refs]
                for (name, idx), spr in zip(surf.get(facing, []), frames):
                    if spr:
                        player, _ = split_surf(family, spr)
                        put(family, name, idx, player)
                for (name, idx), spr in zip(blob.get(facing, []), frames):
                    if spr:
                        _, b = split_surf(family, spr)
                        put(extras, name, idx, b)
            continue
        fam = family if key in targets[family] else extras if key in targets[extras] else None
        if fam is None:
            warn.append(f"unknown section '{key}'; known: {', '.join(sorted(targets[family]) + sorted(targets[extras]))}, surf with blob")
            continue
        for facing, refs in facings.items():
            slots = targets[fam][key].get(facing)
            if slots is None:
                warn.append(f"{key}: no '{facing}' (use {', '.join(targets[fam][key])})")
                continue
            if len(refs) > len(slots):
                warn.append(f"{key} {facing}: {len(refs)} sprites given, only {len(slots)} frames; the rest are ignored")
            for (name, idx), ref in zip(slots, refs):
                jobs.append((key, facing, fam, name, idx, ref))

    # A sprite used for more than one frame of a sheet (tricks drawn as the
    # riding frame, say) goes on the row of its first frame in each, so a
    # stand-in doesn't float or sink where the game's own frame lifts. -Elvie
    firsts = {}
    for key, facing, fam, name, idx, ref in jobs:
        k = (fam, name, json.dumps(ref, sort_keys=True))
        firsts[k] = min(firsts.get(k, idx), idx)
    for key, facing, fam, name, idx, ref in jobs:
        spr = piece_image(im, pieces, ref)
        if spr:
            w, h, _ = P.spec(fam, name)
            bottom = foot(fam, name, h, firsts[(fam, name, json.dumps(ref, sort_keys=True))])
            if key in shrink_keys:
                spr = shrink(spr, w, bottom, warn, f"{key} {facing}")
            put(fam, name, idx, place(spr, w, h, bottom, warn, f"{key} {facing}"))

    return write_out(family, strips, filled, warn, out_dir)

# ------------------------------------------------------------------ commands

def main(a):
    if len(a) >= 3 and a[0] == "slice" and os.path.isdir(a[1]):
        sheet, pieces, cells, rows = load_numbered_folder(a[1], folder_options(a[3:]))
        pages = folder_pages(rows, sheet.width, sheet.height)
        for k, page in enumerate(pages):
            folder_preview(sheet, pieces, cells, rows, page=page).save(page_name(a[2], k))
        print(folder_report(rows, pieces, pages, a[2]))
        return 0
    if len(a) >= 3 and a[0] == "slice":
        opts = dict(zip(a[3::2], a[4::2]))
        lossy = {"yes": True, "no": False}.get(opts.get("--lossy"), "auto")
        im, scale, bg = clean(a[1], int(opts["--scale"]) if "--scale" in opts else None, opts.get("--bg", "auto"),
                              lossy, int(opts.get("--colors", 48)))
        pieces = find_pieces(im, int(opts.get("--reach", 1)))
        preview(im, pieces).save(a[2])
        print(f"  sheet   scale {scale}x, background {'#%02x%02x%02x' % bg if bg else 'transparent'}, "
              f"{len(pieces)} pieces -> {a[2]}")
        return 0
    if len(a) == 4 and a[0] == "build":
        return 0 if build(a[1], a[2], a[3]) else 1
    if a and a[0] in ("pack", "convert", "reference", "blank", "surf", "transfer"):
        # Those live in pack_gen3.py; run it there rather than fail. -Elvie
        import subprocess
        print(f"  note    '{a[0]}' is a pack_gen3.py command; running it there")
        return subprocess.call([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "pack_gen3.py")] + a)
    print(__doc__)
    return 2

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
