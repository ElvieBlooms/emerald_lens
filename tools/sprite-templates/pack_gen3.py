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

Extras (optional): the surf blob, the Fly bird and the bag have their own
smaller sheet, frlg_extras.png / rse_extras.png, with separate templates in
frlg_extras/ and rse_extras/. Use frlg_extras or rse_extras in place of frlg
or rse in any command above. Packing a frlg or rse folder also packs any
extras it finds there, and packing an extras sheet with frlg or rse works too;
they all land in the same gen3/frlg or gen3/rse folder:
             python3 pack_gen3.py reference frlg_extras girl ~/.local/share/pokemon-love2d/firered ./ref-frlg
             python3 pack_gen3.py pack frlg frlg_extras.png ../../assets/sprites/kris/gen3/frlg

surf       Placement reference for the player on the surf blob, exactly as the
           game lines them up (not for packing). With no art it's a blank
           guide; --art takes a look's gen3 folder and --game a game folder
           for anything the look doesn't have:
             python3 pack_gen3.py surf frlg girl frlg_surf.png
             python3 pack_gen3.py surf rse girl rse_surf.png --art ../../assets/sprites/kris/gen3/rse --game ~/.local/share/pokemon-love2d/emerald

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
    ("mapIcon.png", 16, 16, 1), ("flyBird.png", 64, 64, 2),
  ],
  "rse": [
    ("walk.png", 16, 32, 18), ("bike.png", 32, 32, 9), ("acroBike.png", 32, 32, 27),
    ("surf.png", 32, 32, 12), ("fieldMove.png", 32, 32, 5), ("fishing.png", 32, 32, 12),
    ("underwater.png", 32, 32, 9), ("watering.png", 32, 32, 9), ("decorating.png", 16, 32, 1),
    ("back.png", 64, 64, 4), ("front.png", 64, 64, 1), ("mapIcon.png", 16, 16, 1),
  ],
  # Extras: not the player, but drawn only for them. bird.png is the bird
  # alone (on FRLG, the first frame of the Fly sheet; the rider frames are
  # flyBird.png on the main sheet).
  "frlg_extras": [("surfBlob.png", 32, 32, 6), ("bird.png", 64, 64, 1), ("bag.png", 64, 64, 4)],
  "rse_extras":  [("surfBlob.png", 32, 32, 3), ("bird.png", 32, 32, 1), ("bag.png", 64, 64, 6)],
}
EXTRAS_OF = {"frlg": "frlg_extras", "rse": "rse_extras"}
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
    # Added after the first release: kept last so every earlier block stays
    # where it was on sheets people have already drawn on.
    ("FLY (OFF / IN)", "flyBird.png", [((0,), 2)]),
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
  # FRLG's surf blob bobs: two frames per facing. RSE has one per facing and
  # bobs it in code. Bag frames are one per pocket (frame 0 also shows while
  # the bag opens and switches pockets).
  "frlg_extras": [
    ("SURF BLOB", "surfBlob.png", [((0, 2, 4), 2)]),
    ("FLY BIRD", "bird.png", [((0,), 1)]),
    ("BAG", "bag.png", [((0,), 4)]),
  ],
  "rse_extras": [
    ("SURF BLOB", "surfBlob.png", [((0, 1, 2), 1)]),
    ("FLY BIRD", "bird.png", [((0,), 1)]),
    ("BAG", "bag.png", [((0, 3), 3)]),
  ],
}
SHEET_W = {"frlg": 500, "rse": 470, "frlg_extras": 500, "rse_extras": 470}
TITLE = {"frlg": "FireRed / LeafGreen", "rse": "Ruby / Sapphire / Emerald",
         "frlg_extras": "FireRed / LeafGreen extras", "rse_extras": "Ruby / Sapphire / Emerald extras"}
HINT = {"frlg_extras": "Optional. Surf blob rows: down, up, left.",
        "rse_extras": "Optional. Surf blob rows: down, up, left."}

# Wide: the same sheets, but the 16-wide overworld frames are 32 wide, for
# characters drawn bigger than the game's own (Gen 4 sprites, say). The mod
# takes either width; the game draws them centred on the tile. Use
# frlg_wide or rse_wide in place of frlg or rse in any command.
WIDE_FILES = {"walk.png", "surf.png", "fieldMove.png", "decorating.png"}
for _base in ("frlg", "rse"):
    _wide = _base + "_wide"
    SPECS[_wide] = [(n, 32 if n in WIDE_FILES and w == 16 else w, h, c) for n, w, h, c in SPECS[_base]]
    LAYOUT[_wide] = LAYOUT[_base]
    EXTRAS_OF[_wide] = EXTRAS_OF[_base]
    SHEET_W[_wide] = SHEET_W[_base] + 60
    TITLE[_wide] = TITLE[_base] + " (wide)"

def base_of(family):
    """frlg_wide -> frlg, rse_extras -> rse_extras."""
    return family.replace("_wide", "")

def widen(strip, w, h, n):
    """A strip centred in wider frames (the game's own art, for reference)."""
    if strip.width >= w:
        return strip
    out = Image.new("RGBA", (w, h * n), CLEAR)
    out.paste(strip, ((w - strip.width) // 2, 0))
    return out

SHEET_FILE = {f: f + ".png" if f in EXTRAS_OF.values() else f + "_sheet.png" for f in SHEET_W}
PAD, LABEL_H, BLOCK_GAP, HEADER_H = 4, 10, 3, 24
BG, INK = (52, 101, 101, 255), (240, 240, 240, 255)

# Ruby/Sapphire number their player front pics differently from Emerald.
RS_FRONT = {"male": "trainers/front/0", "female": "trainers/front/1"}

# Where each sheet lives in an imported cache (data/generated/gba/...), per
# gender. ow/<gid>.rgba, trainers/back_<n>.rgba, trainers/front/<id>.rgba.
# A (file, first frame, frames in file) entry is a run of frames inside a
# bigger sheet: FRLG's Fly bird holds the bird alone, then each gender's
# rider frames.
SOURCES = {
  "frlg": {
    "male":   {"walk.png": "ow/0", "bike.png": "ow/1", "surf.png": "ow/2", "fieldMove.png": "ow/3",
               "fishing.png": "ow/4", "vsSeekerBike.png": "ow/6",
               "back.png": "trainers/back_0", "front.png": "trainers/front/135",
               "intro.png": "intro/boy.png", "mapIcon.png": "region_map/player_red.png",
               "flyBird.png": ("field_effects/fly_bird", 1, 5)},
    "female": {"walk.png": "ow/7", "bike.png": "ow/8", "surf.png": "ow/9", "fieldMove.png": "ow/10",
               "fishing.png": "ow/11", "vsSeekerBike.png": "ow/13",
               "back.png": "trainers/back_1", "front.png": "trainers/front/136",
               "intro.png": "intro/girl.png", "mapIcon.png": "region_map/player_leaf.png",
               "flyBird.png": ("field_effects/fly_bird", 3, 5)},
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
  "frlg_extras": {
    "male":   {"surfBlob.png": "field_effects/surf_blob", "bird.png": ("field_effects/fly_bird", 0, 5),
               "bag.png": "items/bag/bag_male"},
    "female": {"surfBlob.png": "field_effects/surf_blob", "bird.png": ("field_effects/fly_bird", 0, 5),
               "bag.png": "items/bag/bag_female"},
  },
  "rse_extras": {
    "male":   {"surfBlob.png": "field_effects/surf_blob", "bird.png": "field_effects/bird",
               "bag.png": "rse/bag/bag_male.png"},
    "female": {"surfBlob.png": "field_effects/surf_blob", "bird.png": "field_effects/bird",
               "bag.png": "rse/bag/bag_female.png"},
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
    d.text((PAD, 3), f"Emerald Lens - {TITLE[family]}", fill=INK, font=font)
    d.text((PAD, 13), HINT.get(family, "Draw inside the boxes. Rows: down, up, left."), fill=INK, font=font)
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
    warnings = []
    if im.size != size:
        # A sheet from before newer blocks were added: same width, shorter.
        # Earlier blocks haven't moved, so pad it and read the new ones blank.
        if im.width == size[0] and im.height < size[1]:
            grown = Image.new("RGBA", size, CLEAR)
            grown.paste(im, (0, 0))
            for s in sections:
                for b in s["blocks"]:
                    if b["box"][3] > im.height:
                        x0, y0, x1, y1 = b["box"]
                        ImageDraw.Draw(grown).rectangle((x0, y0, x1 - 1, y1 - 1), outline=GUIDE)
                        for p in guide_pixels(b): grown.putpixel(p, GUIDE)
            im = grown
            warnings.append("this sheet is from an earlier version; blocks added since are read as blank")
        else:
            return None, [f"sheet is {im.size[0]}x{im.size[1]}, the {family} sheet is {size[0]}x{size[1]}"]
    px = im.load()
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
    names = (SHEET_FILE[family],) if family in EXTRAS_OF.values() else (SHEET_FILE[family], "sheet.png")
    for name in names:
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
            print(f"  warning {name}: those frames will be invisible in game")

def has_extras(family, folder):
    """Whether a folder holds any of this family's extras work."""
    if find_sheet(family, folder):
        return True
    return any(os.path.exists(os.path.join(folder, n)) for n, _, _, _ in SPECS[family])

def pack(family, src, dst_dir):
    # An extras sheet handed to frlg/rse is packed as extras: same folder.
    if os.path.isfile(src) and family in EXTRAS_OF:
        extras = EXTRAS_OF[family]
        if Image.open(src).size == layout(extras)[0]:
            family = extras
    strips, ok = read_any(family, src)
    if not strips and not ok:
        return False
    write_strips(family, strips, dst_dir)
    # A folder with the main work and the extras packs both.
    if os.path.isdir(src) and family in EXTRAS_OF and has_extras(EXTRAS_OF[family], src):
        print("  extras")
        more, eok = read_any(EXTRAS_OF[family], src)
        write_strips(EXTRAS_OF[family], more, dst_dir)
        ok = ok and eok
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
        out = os.path.join(dst, SHEET_FILE[family])
        sheet_from_strips(family, strips).save(out)
        print(f"  wrote   {out} ({len(strips)} of {len(SPECS[family])} templates found)")
    return ok

def reference(family, gender, game_dir, dst_dir, formats=("sheet", "separate")):
    os.makedirs(dst_dir, exist_ok=True)
    root = os.path.join(game_dir, "data", "generated", "gba")
    game = os.path.basename(os.path.normpath(game_dir)).lower()
    strips = {}
    for name, w, h, n in SPECS[base_of(family)]:
        src = SOURCES[base_of(family)][gender][name]
        if name == "front.png" and game in ("ruby", "sapphire"):
            src = RS_FRONT[gender]
        first, total = 0, n
        if isinstance(src, tuple):
            src, first, total = src
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
            data = read_rgba(raw, w * h * total * 4)
            if data is None:
                print(f"  skip    {name} (cache file isn't a {w}x{h}x{total} sheet)")
                continue
            strip = Image.frombytes("RGBA", (w, h * total), data)
            if total != n:
                strip = strip.crop((0, first * h, w, (first + n) * h))
        strips[name] = widen(strip, spec(family, name)[0], h, n)
    if "separate" in formats:
        for name, w, h, n in SPECS[family]:
            if name in strips:
                guided(strips[name], w, h, n).save(os.path.join(dst_dir, name))
        print(f"  ref     {len(strips)} separate templates")
    if "sheet" in formats:
        sheet_from_strips(family, strips).save(os.path.join(dst_dir, SHEET_FILE[family]))
        print(f"  ref     {SHEET_FILE[family]} (combined)")

# ------------------------------------------------------------ surf placement
# How the game lines up the player and the surf blob, from the tile's
# top-left corner (the player's position): the player is centred on the
# tile with its feet on the tile's bottom edge (x + (16 - w) / 2, y + 16 - h),
# and the 32x32 blob is drawn at (x - 8, y - 8), behind the player. While
# standing still both bob up 1px together, so the overlap never changes.
# In a 32x40 cell that puts the blob at (0, 8) and the player at (8, 0) on
# FRLG (16 wide) or (0, 0) on RSE (32 wide): the player's bottom 24 rows sit
# over the blob's top 24, and the blob's last 8 rows show below the feet.
SURF_CELL = (32, 40)
SURF_BLOB_AT = (0, 8)
SURF_TILE_AT = (8, 16)
# (label, player frame, blob frame, mirrored). Right is left mirrored.
SURF_POSES = {
  "frlg": [("DOWN", 0, 0, False), ("UP", 1, 2, False), ("LEFT", 2, 4, False), ("RIGHT", 2, 4, True),
           ("DOWN", 0, 1, False), ("UP", 1, 3, False), ("LEFT", 2, 5, False), ("RIGHT", 2, 5, True)],
  "rse":  [("DOWN", 0, 0, False), ("UP", 1, 1, False), ("LEFT", 2, 2, False), ("RIGHT", 2, 2, True)],
}
PLAYER_TINT, BLOB_TINT, TILE_INK = (255, 0, 255, 90), (0, 200, 255, 90), (255, 255, 255, 160)

def load_strip(family, name, art_dir, game_dir, gender):
    """A packed strip from a look's folder, else the game's own, else None."""
    w, h, n = spec(family, name) if name in [x[0] for x in SPECS[family]] else spec(EXTRAS_OF[family], name)
    if art_dir:
        path = os.path.join(art_dir, name)
        if os.path.exists(path):
            im = Image.open(path).convert("RGBA")
            if im.size == (w, h * n):
                return im
            print(f"  skip    {path} is {im.size[0]}x{im.size[1]}, expected {w}x{h * n}")
    if game_dir:
        fam = base_of(family) if name == "surf.png" else EXTRAS_OF[family]
        src = SOURCES[fam][gender][name]
        gw = spec(fam, name)[0]
        raw = os.path.join(game_dir, "data", "generated", "gba", src + ".rgba")
        if os.path.exists(raw):
            data = read_rgba(raw, gw * h * n * 4)
            if data:
                return widen(Image.frombytes("RGBA", (gw, h * n), data), w, h, n)
    return None

def surf_placement(family, art_dir=None, game_dir=None, gender="female"):
    pw, ph, _ = spec(family, "surf.png")
    player_at = (SURF_TILE_AT[0] + (16 - pw) // 2, 0)
    player = load_strip(family, "surf.png", art_dir, game_dir, gender)
    blob = load_strip(family, "surfBlob.png", art_dir, game_dir, gender)
    poses = SURF_POSES[base_of(family)]
    cols = 4
    rows = len(poses) // cols
    cw, ch = SURF_CELL
    gap, top = 6, HEADER_H + 2
    short = {"frlg": "FR/LG", "rse": "R/S/E", "frlg_wide": "FR/LG wide", "rse_wide": "R/S/E wide"}[family]
    blank = not (player and blob)
    lines = ["Pink: player", "Blue: blob", "Dots: the tile"] if blank else \
            (["Rows: the blob's two", "bob frames"] if family == "frlg" else [])
    W = max(PAD * 2 + cols * cw + (cols - 1) * gap, 160)
    H = top + rows * (LABEL_H + ch + gap) + PAD + 10 * len(lines)
    im = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    font = ImageFont.load_default()
    d.text((PAD, 3), f"Surf placement - {short}", fill=INK, font=font)
    d.text((PAD, 13), "Reference only, not packed.", fill=INK, font=font)
    for i, (label, pf, bf, mirror) in enumerate(poses):
        r, c = divmod(i, cols)
        x0 = PAD + c * (cw + gap)
        y0 = top + r * (LABEL_H + ch + gap)
        d.text((x0, y0 - 1), label, fill=INK, font=font)
        cy = y0 + LABEL_H
        cell = Image.new("RGBA", SURF_CELL, CLEAR)
        if blob:
            frame = blob.crop((0, bf * 32, 32, (bf + 1) * 32))
            cell.alpha_composite(frame.transpose(Image.FLIP_LEFT_RIGHT) if mirror else frame, SURF_BLOB_AT)
        else:
            cell.alpha_composite(Image.new("RGBA", (32, 32), BLOB_TINT), SURF_BLOB_AT)
        if player:
            frame = player.crop((0, pf * ph, pw, (pf + 1) * ph))
            cell.alpha_composite(frame.transpose(Image.FLIP_LEFT_RIGHT) if mirror else frame, player_at)
        else:
            cell.alpha_composite(Image.new("RGBA", (pw, ph), PLAYER_TINT), player_at)
        bg = Image.new("RGBA", SURF_CELL, CLEAR)
        im.paste(bg, (x0, cy))
        im.alpha_composite(cell, (x0, cy))
        if blank:
            # the tile the player stands on, as corner marks
            tx, ty = x0 + SURF_TILE_AT[0], cy + SURF_TILE_AT[1]
            for dx, dy in ((0, 0), (15, 0), (0, 15), (15, 15)):
                im.putpixel((tx + dx, ty + dy), TILE_INK)
    y = top + rows * (LABEL_H + ch + gap)
    for line in lines:
        d.text((PAD, y), line, fill=INK, font=font)
        y += 10
    return im

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
    if len(a) >= 4 and a[0] == "surf" and base_of(a[1]) in SURF_POSES and a[2] in ("male", "female", "boy", "girl"):
        opts = dict(zip(a[4::2], a[5::2]))
        im = surf_placement(a[1], opts.get("--art"), opts.get("--game"),
                            {"boy": "male", "girl": "female"}.get(a[2], a[2]))
        im.save(a[3])
        print(f"  wrote   {a[3]}")
        sys.exit(0)
    if len(a) == 3 and a[0] == "blank" and a[1] in SPECS:
        blank_sheet(a[1]).save(a[2])
        print(f"  wrote   {a[2]}")
        sys.exit(0)
    print(__doc__)
    sys.exit(2)
