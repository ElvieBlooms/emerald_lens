#!/usr/bin/env python3
"""Emerald Lens sprite helper.

Two formats, usable interchangeably: one combined sheet (frlg_sheet.png /
rse_sheet.png, laid out like the standard community sheets; in each block the
rows face down, up, left) or separate templates (one strip per game sheet, in
frlg/ or rse/). Both use 1px magenta guide lines around each frame; draw only
inside them.

pack       Turn your work into game-ready sheets in a sprite folder. Point it at
           a combined sheet, a folder of separate templates, or a folder with
           both (a drawn separate template wins over that sheet's block).
           Anything left blank is skipped, so a fallback folder or the game's
           own sprite supplies it:
             python3 pack_gen3.py pack frlg frlg_sheet.png ../../assets/sprites/kris/gen3/frlg
             python3 pack_gen3.py pack frlg ./my-frlg-work ../../assets/sprites/kris/gen3/frlg

convert    Move work from one format to the other:
             python3 pack_gen3.py convert frlg frlg_sheet.png ./frlg-separate
             python3 pack_gen3.py convert frlg ./frlg frlg_sheet.png

reference  Export the game's own sprites from YOUR imported cache, in both
           formats by default (add --sheet or --separate for just one). Works
           for firered, leafgreen, ruby, sapphire and emerald folders. For
           personal reference only -- don't commit these anywhere.
             python3 pack_gen3.py reference frlg girl ~/.local/share/pokemon-love2d/firered ./ref-frlg
             python3 pack_gen3.py reference rse  girl ~/.local/share/pokemon-love2d/ruby    ./ref-rse --sheet

blank      Write a fresh blank combined sheet:
             python3 pack_gen3.py blank rse rse_sheet.png

Needs Pillow (python3 -m pip install --user pillow).
"""
import os, sys, zlib
from PIL import Image, ImageDraw, ImageFont

# (file, frame width, frame height, frame count) -- the game's own sizes.
SPECS = {
  "frlg": [
    ("walk.png", 16, 32, 20), ("bike.png", 32, 32, 9), ("surf.png", 16, 32, 12),
    ("fieldMove.png", 16, 32, 9), ("fishing.png", 32, 32, 12),
    ("vsSeekerBike.png", 32, 32, 6), ("back.png", 64, 64, 5), ("front.png", 64, 64, 1), ("intro.png", 64, 96, 1),
    ("mapIcon.png", 16, 16, 1),
  ],
  "rse": [
    ("walk.png", 16, 32, 18), ("bike.png", 32, 32, 9), ("acroBike.png", 32, 32, 27),
    ("surf.png", 32, 32, 12), ("fieldMove.png", 32, 32, 5), ("fishing.png", 32, 32, 12),
    ("underwater.png", 32, 32, 9), ("watering.png", 32, 32, 9), ("decorating.png", 16, 32, 1),
    ("back.png", 64, 64, 4), ("front.png", 64, 64, 1), ("mapIcon.png", 16, 16, 1),
  ],
}
GUIDE = (255, 0, 255, 255)
CLEAR = (0, 0, 0, 0)

# Combined sheet layout. Each section is (label, file, blocks); a block is
# (first frame of each row, frames per row), or a list of rows of frame
# numbers when the game's order doesn't follow that pattern. Three-row
# blocks are the down, up and left facings, which the game stores in that
# order within each group (except fishing, which it stores left, up, down --
# hence 8, 4, 0).
STAND, STEP = ((0, 1, 2), 1), ((3, 5, 7), 2)
FISH = ((8, 4, 0), 4)
SURF = [STAND, STEP, ((9, 10, 11), 1)]
LAYOUT = {
  "frlg": [
    ("FRONT", "front.png", [((0,), 1)]),
    ("INTRO", "intro.png", [((0,), 1)]),
    ("BACK", "back.png", [((0,), 5)]),
    ("WALK", "walk.png", [STAND, STEP]),
    ("RUN", "walk.png", [((9, 12, 15), 3)]),
    ("BIKE", "bike.png", [STAND, STEP]),
    ("FISH", "fishing.png", [FISH]),
    ("SURF", "surf.png", SURF),
    ("FIELD MOVE / VS SEEKER", "fieldMove.png", [((0,), 9)]),
    ("VS SEEKER BIKE", "vsSeekerBike.png", [((0,), 6)]),
    ("WALK EXTRA", "walk.png", [((18,), 2)]),
    ("MAP ICON", "mapIcon.png", [((0,), 1)]),
  ],
  "rse": [
    ("FRONT", "front.png", [((0,), 1)]),
    ("BACK", "back.png", [((0,), 4)]),
    ("WALK", "walk.png", [STAND, STEP]),
    # RSE stores running like walking: a standing frame per facing (9-11),
    # then a pair each (12-17). FRLG stores three in a row per facing.
    ("RUN", "walk.png", [[[9, 12, 13], [10, 14, 15], [11, 16, 17]]]),
    ("MACH BIKE", "bike.png", [STAND, STEP]),
    ("FISH", "fishing.png", [FISH]),
    ("MAP ICON", "mapIcon.png", [((0,), 1)]),
    ("ACRO BIKE", "acroBike.png", [STAND, STEP, ((9, 13, 17), 4), ((21, 23, 25), 2)]),
    ("SURF", "surf.png", SURF),
    ("UNDERWATER", "underwater.png", [STAND, STEP]),
    ("WATERING", "watering.png", [STAND, STEP]),
    ("FIELD MOVE", "fieldMove.png", [((0,), 5)]),
    ("DECORATE", "decorating.png", [((0,), 1)]),
  ],
}
SHEET_W = {"frlg": 500, "rse": 470}
TITLE = {"frlg": "FireRed / LeafGreen", "rse": "Ruby / Sapphire / Emerald"}
PAD, LABEL_H, BLOCK_GAP, HEADER_H = 4, 10, 3, 24
BG, INK = (52, 101, 101, 255), (240, 240, 240, 255)

# Ruby/Sapphire number their player front pics differently from Emerald.
RS_FRONT = {"male": "trainers/front/0", "female": "trainers/front/1"}

# Where each sheet lives in an imported cache (data/generated/gba/...), per
# gender. ow/<gid>.rgba, trainers/back_<n>.rgba, trainers/front/<id>.rgba
SOURCES = {
  "frlg": {
    "male":   {"walk.png": "ow/0", "bike.png": "ow/1", "surf.png": "ow/2", "fieldMove.png": "ow/3",
               "fishing.png": "ow/4", "vsSeekerBike.png": "ow/6",
               "back.png": "trainers/back_0", "front.png": "trainers/front/135",
               "intro.png": "intro/boy.png", "mapIcon.png": "region_map/player_red.png"},
    "female": {"walk.png": "ow/7", "bike.png": "ow/8", "surf.png": "ow/9", "fieldMove.png": "ow/10",
               "fishing.png": "ow/11", "vsSeekerBike.png": "ow/13",
               "back.png": "trainers/back_1", "front.png": "trainers/front/136",
               "intro.png": "intro/girl.png", "mapIcon.png": "region_map/player_leaf.png"},
  },
  "rse": {
    "male":   {"walk.png": "ow/0", "bike.png": "ow/1", "acroBike.png": "ow/63", "surf.png": "ow/2",
               "fieldMove.png": "ow/3", "fishing.png": "ow/137", "underwater.png": "ow/111",
               "watering.png": "ow/191", "decorating.png": "ow/193",
               "back.png": "trainers/back_0", "front.png": "trainers/front/71",
               "mapIcon.png": "rse/region_map/brendan_icon.png"},
    "female": {"walk.png": "ow/89", "bike.png": "ow/90", "acroBike.png": "ow/91", "surf.png": "ow/92",
               "fieldMove.png": "ow/93", "fishing.png": "ow/138", "underwater.png": "ow/112",
               "watering.png": "ow/192", "decorating.png": "ow/194",
               "back.png": "trainers/back_1", "front.png": "trainers/front/72",
               "mapIcon.png": "rse/region_map/may_icon.png"},
  },
}

def spec(family, name):
    for n, w, h, count in SPECS[family]:
        if n == name:
            return w, h, count
    raise KeyError(name)

def read_rgba(path, expect):
    """Newer game builds zlib-compress their .rgba cache files; older ones
    don't. Accept either."""
    data = open(path, "rb").read()
    if len(data) == expect:
        return data
    try:
        data = zlib.decompress(data)
    except zlib.error:
        return None
    return data if len(data) == expect else None

def is_blank(im):
    return im.getchannel("A").getbbox() is None

# ---------------------------------------------------------------- one sheet
# Per-sheet templates: one vertical strip, a guide line around every frame.

def frame_box(i, w, h):
    x0, y0 = 1, 1 + i * (h + 1)
    return (x0, y0, x0 + w, y0 + h)

def guided(sheet, w, h, n):
    """Exact-size strip -> template with guide lines."""
    out = Image.new("RGBA", (w + 2, n * (h + 1) + 1), CLEAR)
    px = out.load()
    W, H = out.size
    for y in range(H):
        px[0, y] = GUIDE; px[W - 1, y] = GUIDE
    for i in range(n + 1):
        for x in range(W): px[x, i * (h + 1)] = GUIDE
    for i in range(n):
        out.paste(sheet.crop((0, i * h, w, (i + 1) * h)), frame_box(i, w, h)[:2])
    return out

# ----------------------------------------------------------- combined sheet

def block_rows(block):
    """A block as rows of frame numbers, whichever way it was written."""
    if isinstance(block, list):
        return block
    starts, cols = block
    return [[first + c for c in range(cols)] for first in starts]

def layout(family):
    """Places every section; returns (size, sections) where each section has
    its label position, and each block its guide box and cells. Each cell is
    (file, frame index, box). Shelf-packed left to right, so the same family
    always lands in the same place."""
    width = SHEET_W[family]
    x, y, shelf_h = PAD, HEADER_H, 0
    placed = []
    for label, name, blocks in LAYOUT[family]:
        w, h, _ = spec(family, name)
        grids = [block_rows(b) for b in blocks]
        dims = [(len(rows[0]) * (w + 1) + 1, len(rows) * (h + 1) + 1) for rows in grids]
        sw = sum(d[0] for d in dims) + BLOCK_GAP * (len(dims) - 1)
        sh = LABEL_H + max(d[1] for d in dims)
        sw = max(sw, len(label) * 6)
        if x + sw > width - PAD and x > PAD:
            x, y, shelf_h = PAD, y + shelf_h + PAD, 0
        bx, out_blocks = x, []
        for rows, (bw, bh) in zip(grids, dims):
            top = y + LABEL_H
            cells = []
            for r, frames in enumerate(rows):
                for c, frame in enumerate(frames):
                    cx, cy = bx + 1 + c * (w + 1), top + 1 + r * (h + 1)
                    cells.append((name, frame, (cx, cy, cx + w, cy + h)))
            out_blocks.append({"box": (bx, top, bx + bw, top + bh), "w": w, "h": h,
                               "cols": len(rows[0]), "rows": len(rows), "cells": cells})
            bx += bw + BLOCK_GAP
        placed.append({"label": label, "at": (x, y), "blocks": out_blocks})
        x += sw + PAD * 2
        shelf_h = max(shelf_h, sh)
    return (width, y + shelf_h + PAD), placed

def cells_by_file(family):
    _, sections = layout(family)
    by = {}
    for s in sections:
        for b in s["blocks"]:
            for name, i, box in b["cells"]:
                by.setdefault(name, {})[i] = box
    # Every frame of every sheet must appear exactly once.
    for name, w, h, n in SPECS[family]:
        assert sorted(by.get(name, {})) == list(range(n)), f"{family} layout misses frames of {name}"
    return by

def guide_pixels(block):
    x0, y0, x1, y1 = block["box"]
    w, h = block["w"], block["h"]
    pts = set()
    for c in range(block["cols"] + 1):
        for yy in range(y0, y1): pts.add((x0 + c * (w + 1), yy))
    for r in range(block["rows"] + 1):
        for xx in range(x0, x1): pts.add((xx, y0 + r * (h + 1)))
    return pts

def blank_sheet(family):
    size, sections = layout(family)
    im = Image.new("RGBA", size, BG)
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    font = ImageFont.load_default()
    d.text((PAD, 3), f"Emerald Lens sheet - {TITLE[family]}", fill=INK, font=font)
    d.text((PAD, 13), "Draw inside the boxes. Rows: down, up, left.", fill=INK, font=font)
    px = im.load()
    for s in sections:
        d.text((s["at"][0], s["at"][1] - 1), s["label"], fill=INK, font=font)
        for b in s["blocks"]:
            for _, _, box in b["cells"]:
                d.rectangle((box[0], box[1], box[2] - 1, box[3] - 1), fill=CLEAR)
            for p in guide_pixels(b):
                px[p] = GUIDE
    return im

def split_sheet(family, im):
    """Combined sheet -> {file: exact-size strip}, plus warnings."""
    size, sections = layout(family)
    if im.size != size:
        return None, [f"sheet is {im.size[0]}x{im.size[1]}, the {family} sheet is {size[0]}x{size[1]}"]
    px, warnings = im.load(), []
    for s in sections:
        damaged = sum(1 for b in s["blocks"] for p in guide_pixels(b) if px[p] != GUIDE)
        if damaged:
            warnings.append(f"{s['label']}: {damaged} guide pixel(s) were painted over -- check frame edges")
    strips = {}
    for name, frames in cells_by_file(family).items():
        w, h, n = spec(family, name)
        strip = Image.new("RGBA", (w, h * n), CLEAR)
        for i, box in frames.items():
            strip.paste(im.crop(box), (0, i * h))
        strips[name] = strip
    return strips, warnings

# ------------------------------------------------------------- readers/writers
# Both formats read into the same thing -- {file: exact-size strip} -- so
# anything one format can do, the other can too.

def read_sheet(family, path):
    """Combined sheet -> strips, or None if it isn't this family's sheet."""
    strips, warnings = split_sheet(family, Image.open(path).convert("RGBA"))
    if strips is None:
        print(f"  ERROR   {os.path.basename(path)}: {warnings[0]}")
        return None
    for w in warnings:
        print(f"  warning {w}")
    return strips

def read_templates(family, folder):
    """Separate templates in a folder -> (strips, ok). Missing files are left out."""
    ok, strips = True, {}
    for name, w, h, n in SPECS[family]:
        path = os.path.join(folder, name)
        if not os.path.exists(path):
            continue
        im = Image.open(path).convert("RGBA")
        want = (w + 2, n * (h + 1) + 1)
        if im.size != want:
            print(f"  ERROR   {name} is {im.size[0]}x{im.size[1]}, template size is {want[0]}x{want[1]}")
            ok = False
            continue
        px = im.load()
        W, H = im.size
        lines = [(0, y) for y in range(H)] + [(W - 1, y) for y in range(H)] + \
                [(x, i * (h + 1)) for i in range(n + 1) for x in range(W)]
        damaged = sum(1 for p in lines if px[p] != GUIDE)
        if damaged:
            print(f"  warning {name}: {damaged} guide pixel(s) were painted over -- check frame edges")
        strip = Image.new("RGBA", (w, h * n), CLEAR)
        for i in range(n):
            strip.paste(im.crop(frame_box(i, w, h)), (0, i * h))
        strips[name] = strip
    return strips, ok

def find_sheet(family, folder):
    for name in (f"{family}_sheet.png", "sheet.png"):
        path = os.path.join(folder, name)
        if os.path.isfile(path):
            return path
    return None

def read_any(family, src):
    """A sheet file, a templates folder, or a folder holding both. With both,
    a drawn separate template wins over that sheet's block on the combined
    sheet, so either can be used for any part. Returns (strips, ok)."""
    if os.path.isfile(src):
        strips = read_sheet(family, src)
        return (strips, True) if strips is not None else ({}, False)
    if not os.path.isdir(src):
        print(f"  ERROR   {src} is not a file or folder")
        return {}, False
    merged, ok = {}, True
    sheet = find_sheet(family, src)
    if sheet:
        from_sheet = read_sheet(family, sheet)
        if from_sheet is None:
            ok = False
        else:
            merged.update({k: v for k, v in from_sheet.items() if not is_blank(v)})
    templates, tok = read_templates(family, src)
    ok = ok and tok
    for name, strip in templates.items():
        if not is_blank(strip):
            if sheet and name in merged:
                print(f"  note    {name}: using the separate template over {os.path.basename(sheet)}")
            merged[name] = strip
        elif name not in merged:
            merged[name] = strip
    return merged, ok

def sheet_from_strips(family, strips):
    sheet = blank_sheet(family)
    for name, frames in cells_by_file(family).items():
        if name not in strips:
            continue
        w, h, _ = spec(family, name)
        for i, box in frames.items():
            sheet.paste(strips[name].crop((0, i * h, w, (i + 1) * h)), box[:2])
    return sheet

def write_templates(family, strips, dst_dir):
    """Every separate template, blank where there's nothing to fill it with."""
    os.makedirs(dst_dir, exist_ok=True)
    for name, w, h, n in SPECS[family]:
        strip = strips.get(name) or Image.new("RGBA", (w, h * n), CLEAR)
        guided(strip, w, h, n).save(os.path.join(dst_dir, name))

# ------------------------------------------------------------------ commands

def write_strips(family, strips, dst_dir):
    """Saves each drawn strip; skips untouched ones and flags half-drawn ones,
    since a blank frame would make the player vanish for that pose."""
    os.makedirs(dst_dir, exist_ok=True)
    for name, w, h, n in SPECS[family]:
        strip = strips.get(name)
        if strip is None:
            print(f"  skip    {name} (not found -- a fallback folder or the game's own sprite will be used)")
            continue
        empty = [i for i in range(n) if is_blank(strip.crop((0, i * h, w, (i + 1) * h)))]
        if len(empty) == n:
            print(f"  skip    {name} (not drawn -- a fallback folder or the game's own sprite will be used)")
            continue
        strip.save(os.path.join(dst_dir, name))
        note = f"  (blank frames: {', '.join(map(str, empty))})" if empty else ""
        print(f"  packed  {name} -> {w}x{h * n}{note}")
        if empty:
            print(f"  warning {name}: the player will be invisible in those frames")

def pack(family, src, dst_dir):
    strips, ok = read_any(family, src)
    if not strips and not ok:
        return False
    write_strips(family, strips, dst_dir)
    return ok

def convert(family, src, dst):
    """Sheet -> separate templates folder, or templates folder -> sheet."""
    if os.path.isfile(src):
        strips = read_sheet(family, src)
        if strips is None:
            return False
        write_templates(family, strips, dst)
        print(f"  wrote   separate templates in {dst}")
        return True
    strips, ok = read_templates(family, src)
    if dst.lower().endswith(".png"):
        sheet_from_strips(family, strips).save(dst)
        print(f"  wrote   {dst} ({len(strips)} of {len(SPECS[family])} templates found)")
    else:
        os.makedirs(dst, exist_ok=True)
        out = os.path.join(dst, f"{family}_sheet.png")
        sheet_from_strips(family, strips).save(out)
        print(f"  wrote   {out} ({len(strips)} of {len(SPECS[family])} templates found)")
    return ok

def reference(family, gender, game_dir, dst_dir, formats=("sheet", "separate")):
    os.makedirs(dst_dir, exist_ok=True)
    root = os.path.join(game_dir, "data", "generated", "gba")
    game = os.path.basename(os.path.normpath(game_dir)).lower()
    strips = {}
    for name, w, h, n in SPECS[family]:
        src = SOURCES[family][gender][name]
        if name == "front.png" and game in ("ruby", "sapphire"):
            src = RS_FRONT[gender]
        raw = os.path.join(root, src if src.endswith(".png") else src + ".rgba")
        if not os.path.exists(raw):
            print(f"  skip    {name} ({raw} not found)")
            continue
        if raw.endswith(".png"):
            strip = Image.open(raw).convert("RGBA")
            if strip.size != (w, h * n):
                print(f"  skip    {name} (cache image is {strip.size[0]}x{strip.size[1]}, expected {w}x{h * n})")
                continue
        else:
            data = read_rgba(raw, w * h * n * 4)
            if data is None:
                print(f"  skip    {name} (cache file isn't a {w}x{h}x{n} sheet)")
                continue
            strip = Image.frombytes("RGBA", (w, h * n), data)
        strips[name] = strip
    if "separate" in formats:
        for name, w, h, n in SPECS[family]:
            if name in strips:
                guided(strips[name], w, h, n).save(os.path.join(dst_dir, name))
        print(f"  ref     {len(strips)} separate templates")
    if "sheet" in formats:
        sheet_from_strips(family, strips).save(os.path.join(dst_dir, f"{family}_sheet.png"))
        print(f"  ref     {family}_sheet.png (combined)")

FORMAT_FLAGS = {"--sheet": ("sheet",), "--separate": ("separate",), "--both": ("sheet", "separate")}

if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) == 4 and a[0] == "pack" and a[1] in SPECS:
        sys.exit(0 if pack(a[1], a[2], a[3]) else 1)
    if len(a) == 4 and a[0] == "convert" and a[1] in SPECS:
        sys.exit(0 if convert(a[1], a[2], a[3]) else 1)
    if len(a) in (5, 6) and a[0] == "reference" and a[1] in SPECS and a[2] in ("male", "female", "boy", "girl"):
        formats = FORMAT_FLAGS.get(a[5], None) if len(a) == 6 else FORMAT_FLAGS["--both"]
        if formats:
            reference(a[1], {"boy": "male", "girl": "female"}.get(a[2], a[2]), a[3], a[4], formats)
            sys.exit(0)
    if len(a) == 3 and a[0] == "blank" and a[1] in SPECS:
        blank_sheet(a[1]).save(a[2])
        print(f"  wrote   {a[2]}")
        sys.exit(0)
    print(__doc__)
    sys.exit(2)
