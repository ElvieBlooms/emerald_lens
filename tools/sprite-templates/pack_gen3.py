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

transfer   Start the other game's sheet from this one: every section that has
           a counterpart (walk, run, Mach Bike to bike, fishing, surf, back...)
           is copied over, frame by frame, if it fits; the rest stays blank.
             python3 pack_gen3.py transfer rse rse_sheet.png frlg frlg_sheet.png
             python3 pack_gen3.py transfer frlg_extras frlg_extras.png rse_extras rse_extras.png

merge      Combine partial work, frame by frame: sheets, templates folders or
           packed look folders, into one sheet (out ending in .png) or a
           packed folder. A frame drawn in only one source is taken from it.
           Where two sources draw the same frame differently, the first one
           listed is kept and the clash is listed; choose another with
           --pick file:frame=source (sources counted from 1). Extras sheets
           and files come along too:
             python3 pack_gen3.py merge rse rse_sheet.png walk_work.png bike_work.png
             python3 pack_gen3.py merge rse rse_sheet.png a.png b.png --pick walk.png:3=2
           Add --report clashes.json to write the clashes as JSON, and
           --clash-frames DIR to save each clashing version as a PNG.

           pack --merge packs into a look folder without losing what's there:
           the folder's own files come first, the new work fills their blank
           frames, and clashes work as above (source 2 is the new work):
             python3 pack_gen3.py pack rse run_work.png ../../assets/sprites/<folder>/gen3/rse --merge

dive       Underwater art for sets that have none (most Gen 4 sets), in a
           packed R/S/E look folder. --blob makes diveBlob.png from the
           folder's surfBlob.png, recolored dark like the game's own diver;
           --underwater fills underwater.png with the surf.png sitting
           frames, washed navy (--no-shade keeps their colours). Both by
           default; files already there are kept unless --force:
             python3 pack_gen3.py dive ../../assets/sprites/<folder>/gen3/rse
             python3 pack_gen3.py dive ../../assets/sprites/<folder>/gen3/rse --blob

blobs      Ready-made surf and dive blobs from a blob set (blobs/<set>/)
           into a packed look's gen3 folder: the FR/LG surfBlob.png into
           frlg/, the R/S/E surfBlob.png and diveBlob.png into rse/, for
           whichever of the two the look has. --surf or --dive for just
           those; files already there are kept unless --force:
             python3 pack_gen3.py blobs ../../assets/sprites/<folder>/gen3 blobs/set1
             python3 pack_gen3.py blobs ../../assets/sprites/<folder>/gen3 blobs/set2 --dive

surfmon    A surfing Pokemon sheet from the dynamic surf overworlds hacks
           (12 frames: down, up, left, two bob frames each, then the same
           again for the parts in front of the player; their 6, 16 and
           32-frame layouts too) into a packed look's gen3 folder:
           surfBlob.png for FR/LG and R/S/E, plus surfOverlay.png, which
           the mod draws over the player. 64x64 sheets are cut to the
           32x32 centred on the drawing, and the rider moves with it to
           stay where the sheet drew them (--middle keeps the middle
           32x32, --half draws the frame at half size). --off dx,dy sets
           the rider offset yourself (surfBlob.json), for every facing or
           as down/up/left (--off 0,-4/0,-6/2,-3). Colour 0
           of an indexed sheet is see-through. surfmons/ has ready-made
           sheets. Files already there are kept unless --force:
             python3 pack_gen3.py surfmon surfmons/lugia.png ../../assets/sprites/<folder>/gen3
             python3 pack_gen3.py surfmon surfmons/lugia.png ../../assets/sprites/<folder>/gen3 --off 0,-6 --force

flybird    A Fly sheet (flyBird.png) for a packed FR/LG look folder from a
           bird kit: the kit's back layer, the look's surf sitting frame
           tilted onto it, then the kit's front layer (the bird) over
           the rider. A kit's bird.png (the bird alone, flying past) is
           written too, unless --no-bird. --off and --in nudge the rider
           for the fly-off and fly-in frames (x,y in pixels, + is right
           and down); --off-tilt and --in-tilt set a frame's tilt in
           degrees clockwise, for birds that hold their rider differently:
             python3 pack_gen3.py flybird ../../assets/sprites/<folder>/gen3/frlg flybirds/pidgeot
             python3 pack_gen3.py flybird ../../assets/sprites/<folder>/gen3/frlg flybirds/pidgeot --off 1,-2 --in 0,1

feet       Check a packed look folder's frames against where the game's own
           sit: the walking bob (standing frames a row up, steps a row
           down), bikes on the bottom row, back pics reaching the bottom
           edge, and so on. Lists frames that float or sink; --match moves
           each one up or down onto the game's row:
             python3 pack_gen3.py feet rse ../../assets/sprites/<folder>/gen3/rse
             python3 pack_gen3.py feet rse ../../assets/sprites/<folder>/gen3/rse --match

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
import json, os, sys, zlib
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
  "rse_extras":  [("surfBlob.png", 32, 32, 3), ("bird.png", 32, 32, 1), ("bag.png", 64, 64, 6),
                  ("diveBlob.png", 32, 32, 3)],
  # Game Boy: Crystal Lens's own files, at the Game Boy's sizes, for a Game
  # Boy look (the mod fits them to Gen 3 when the game loads them). Colour
  # pics; the overworld in four shades, since both mods colour it with
  # overworldColors. 16x16 frames: stand down, up, left, then the steps
  # (the games mirror them). Fishing poses are the 16x8 bottom half under
  # the standing frame; the rod is two 8x8 tiles, for down/up then left.
  # overworldSurf.png and overworldFishRod.png are Emerald Lens's own;
  # Crystal Lens leaves them be. No extras. -Elvie
  "gb": [
    ("overworldWalk.png", 16, 16, 6), ("overworldBike.png", 16, 16, 6),
    ("frontColor.png", 56, 56, 1), ("backColor.png", 48, 48, 1), ("trainerCardColor.png", 40, 56, 1),
    ("overworldSurf.png", 16, 16, 6), ("overworldFishFront.png", 16, 8, 1),
    ("overworldFishBack.png", 16, 8, 1), ("overworldFishSide.png", 16, 8, 1),
    ("overworldFishRod.png", 8, 8, 2),
  ],
  "gb_extras": [],
}
EXTRAS_OF = {"frlg": "frlg_extras", "rse": "rse_extras", "gb": "gb_extras"}
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
    # The game has no dive blob: its diver's Pokemon is drawn into the
    # underwater frames. The mod puts this behind them, where the surf blob
    # goes. Added after the first release, so last. -Elvie
    ("DIVE BLOB", "diveBlob.png", [((0, 1, 2), 1)]),
  ],
  # Walk and bike: a standing column, then a step column, rows down, up,
  # left, so recipes fill them like the Gen 3 walk ("down": [stand, step]). -Elvie
  "gb": [
    ("FRONT", "frontColor.png", [((0,), 1)]),
    ("BACK", "backColor.png", [((0,), 1)]),
    ("TRAINER CARD", "trainerCardColor.png", [((0,), 1)]),
    ("WALK", "overworldWalk.png", [((0, 1, 2), 1), ((3, 4, 5), 1)]),
    ("BIKE", "overworldBike.png", [((0, 1, 2), 1), ((3, 4, 5), 1)]),
    ("SURF", "overworldSurf.png", [((0, 1, 2), 1), ((3, 4, 5), 1)]),
    ("FISH DOWN", "overworldFishFront.png", [((0,), 1)]),
    ("FISH UP", "overworldFishBack.png", [((0,), 1)]),
    ("FISH LEFT", "overworldFishSide.png", [((0,), 1)]),
    ("ROD", "overworldFishRod.png", [((0,), 2)]),
  ],
  "gb_extras": [],
}
SHEET_W = {"frlg": 500, "rse": 470, "frlg_extras": 500, "rse_extras": 470, "gb": 260, "gb_extras": 260}
TITLE = {"frlg": "FireRed / LeafGreen", "rse": "Ruby / Sapphire / Emerald",
         "gb": "Game Boy (Crystal Lens)", "gb_extras": "Game Boy extras (none)",
         "frlg_extras": "FireRed / LeafGreen extras", "rse_extras": "Ruby / Sapphire / Emerald extras"}
HINT = {"frlg_extras": "Optional. Surf blob rows: down, up, left.",
        "rse_extras": "Optional. Surf and dive blob rows: down, up, left.",
        # RSE's back pic stands in its last frame, FRLG's in its first -Elvie
        "rse": "Draw inside the boxes. Rows: down, up, left. BACK: throw first, standing last.",
        "rse_wide": "Draw inside the boxes. Rows: down, up, left. BACK: throw first, standing last.",
        "gb": "Down, up, left; stand, step. FISH: lower half."}

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
    missing = set()
    for s in sections:
        guides = [p for b in s["blocks"] for p in guide_pixels(b)]
        damaged = sum(1 for p in guides if px[p] != GUIDE)
        if damaged == len(guides):
            # A block added since the sheet was made, in space that was
            # background then (the dive blob): no guides at all. -Elvie
            missing.add(s["label"])
            warnings.append(f"{s['label']}: not on this sheet (made before it was added); read as blank")
        elif damaged:
            warnings.append(f"{s['label']}: {damaged} guide pixel(s) were painted over -- check frame edges")
    strips = {}
    blank = {b_cell[:2] for s in sections if s["label"] in missing
             for b in s["blocks"] for b_cell in b["cells"]}
    for name, frames in cells_by_file(family).items():
        w, h, n = spec(family, name)
        strip = Image.new("RGBA", (w, h * n), CLEAR)
        for i, box in frames.items():
            if (name, i) not in blank:
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

def write_strips(family, strips, dst_dir, quiet=False):
    """Saves each drawn strip; skips untouched ones and flags half-drawn ones,
    since a blank frame would make the player vanish for that pose. quiet
    leaves out sheets no source had (merge). -Elvie"""
    os.makedirs(dst_dir, exist_ok=True)
    for name, w, h, n in SPECS[family]:
        strip = strips.get(name)
        if strip is None:
            if not quiet:
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
        src = SOURCES[base_of(family)][gender].get(name)
        if src is None:
            print(f"  skip    {name} (the game has none)")
            continue
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

def sections(family):
    """Recipe keys: our sheet's section labels in lower case, each naming its
    frames per facing (down, up, left) or as one list ("frames"). Returns
    {key: {facing: [(file, frame index), ...]}}."""
    out = {}
    for label, name, blocks in LAYOUT[family]:
        grids = [block_rows(b) for b in blocks]
        nrows = max(len(g) for g in grids)
        entry = out.setdefault(label.lower(), {})
        if nrows == 3:
            for r, facing in enumerate(("down", "up", "left")):
                for g in grids:
                    if r < len(g):
                        entry.setdefault(facing, []).extend((name, f) for f in g[r])
        else:
            # Not laid out by facing (the RSE bag is two rows of three):
            # every frame in order, row by row. -Elvie
            for g in grids:
                for row in g:
                    entry.setdefault("frames", []).extend((name, f) for f in row)
    return out


# The same section under each game's name. -Elvie
SAME_SECTION = {"mach bike": "bike", "bike": "mach bike",
                "field move": "field move / vs seeker", "field move / vs seeker": "field move"}
# Same size but not the same picture in the other game, so never moved.
NOT_MOVED = {"bag"}
# Back pic frames by what they show. FRLG: idle 0, throw 1-2-3-4 (1 and 4
# held). RSE: idle 3, throw 0-1-2 (0 and 2 held). From the games' own
# back pic anims. -Elvie
BACK_FRAMES = {("frlg", "rse"): {1: 0, 2: 1, 4: 2, 0: 3},
               ("rse", "frlg"): {3: 0, 0: 1, 1: 2, 2: 4}}
BACK_EXTRA = {("rse", "frlg"): {3: 1}}  # FRLG's second quick frame reuses RSE's

def transfer(src_family, src, dst_family, dst):
    """Fill the other game's sheet from this one: each section goes to its
    counterpart (Mach Bike to bike, and so on), frame by frame in order.
    The game draws every frame centred and standing on its bottom edge, so a
    frame moves centre to centre, bottom to bottom; one whose drawing
    doesn't fit the other game's frame is left out. Everything with no
    counterpart stays blank. -Elvie"""
    if (src_family in EXTRAS_OF.values()) != (dst_family in EXTRAS_OF.values()):
        print("  ERROR   transfer a main sheet to a main sheet, or extras to extras")
        return False
    strips, ok = read_any(src_family, src)
    if not ok:
        return False
    src_secs, dst_secs = sections(src_family), sections(dst_family)
    out, moved, skipped, too_big = {}, [], [], []
    for key, facings in src_secs.items():
        to = key if key in dst_secs else SAME_SECTION.get(key)
        if to not in dst_secs or key in NOT_MOVED:
            if any(not is_blank(strips[n]) for f in facings.values() for n, _ in f if n in strips):
                skipped.append(key)
            continue
        got = total = 0
        pair = (base_of(src_family), base_of(dst_family))
        for facing, slots in facings.items():
            dslots = dst_secs[to].get(facing, [])
            if key == "back" and pair in BACK_FRAMES:
                order = sorted((d, s) for s, d in BACK_FRAMES[pair].items())
                order += sorted((d, s) for d, s in BACK_EXTRA.get(pair, {}).items())
                pairs = [(slots[s], dslots[d]) for d, s in order if s < len(slots) and d < len(dslots)]
            else:
                pairs = list(zip(slots, dslots))
            for (sname, si), (dname, di) in pairs:
                if sname not in strips:
                    continue
                sw, sh, _ = spec(src_family, sname)
                frame = strips[sname].crop((0, si * sh, sw, (si + 1) * sh))
                bb = frame.getchannel("A").getbbox()
                if not bb:
                    continue
                total += 1
                dw, dh, dn = spec(dst_family, dname)
                ox, oy = (dw - sw) // 2, dh - sh
                if bb[0] + ox < 0 or bb[1] + oy < 0 or bb[2] + ox > dw or bb[3] + oy > dh:
                    too_big.append(key if facing == "frames" else f"{key} {facing}")
                    continue
                strip = out.setdefault(dname, Image.new("RGBA", (dw, dh * dn), CLEAR))
                strip.alpha_composite(frame.crop(bb), (bb[0] + ox, di * dh + bb[1] + oy))
                got += 1
        if total:
            moved.append(f"{key} -> {to}: {got} of {total} frames")
    sheet_from_strips(dst_family, out).save(dst)
    for m in moved:
        print(f"  moved   {m}")
    for k in skipped:
        print(f"  skipped {k} (no counterpart in {base_of(dst_family).upper()})")
    for k in sorted(set(too_big)):
        print(f"  skipped {k}: {too_big.count(k)} frame(s) too big for {base_of(dst_family).upper()}'s frame (try the _wide family)")
    print(f"  wrote   {dst}")
    return True


# ------------------------------------------------------------------- merging
# Several partial sources into one, frame by frame. A frame drawn in one
# source is taken from it; the same frame drawn differently in two is a
# clash: the first source listed keeps it unless a --pick says otherwise,
# and every clash is reported so nothing is chosen silently. -Elvie

def fit_strip(family, name, im):
    """An exact-size strip for this family, or None. A 16-wide sheet goes
    into a wide family centred; a 32-wide one into a narrow family only if
    every frame's drawing fits the narrow frame. -Elvie"""
    w, h, n = spec(family, name)
    if im.height != h * n:
        return None
    if im.width == w:
        return im
    if im.width < w:
        return widen(im, w, h, n)
    x0 = (im.width - w) // 2
    bb = im.getchannel("A").getbbox()
    if bb and (bb[0] < x0 or bb[2] > x0 + w):
        return None
    return im.crop((x0, 0, x0 + w, h * n))

def read_file_strip(family, name, path):
    """One file: a separate template (with guides) or a packed strip."""
    w, h, n = spec(family, name)
    im = Image.open(path).convert("RGBA")
    if im.size == (w + 2, n * (h + 1) + 1):
        strip = Image.new("RGBA", (w, h * n), CLEAR)
        for i in range(n):
            strip.paste(im.crop(frame_box(i, w, h)), (0, i * h))
        return strip
    strip = fit_strip(family, name, im)
    if strip is None:
        print(f"  ERROR   {path}: {im.width}x{im.height} isn't a {name} strip or template for {family}"
              + (" (too wide: try the _wide family)" if im.height == h * n and im.width > w else ""))
    return strip

def other_width(family):
    """rse <-> rse_wide; None for extras, which have no wide form."""
    if family.endswith("_wide"):
        return base_of(family)
    return family + "_wide" if family + "_wide" in SPECS else None

def read_sheet_as(family, path):
    """A sheet for this family, or for the other width converted frame by
    frame (16-wide frames centred; 32-wide ones only if they fit). -Elvie"""
    size = Image.open(path).size
    alt = other_width(family)
    if size != layout(family)[0] and alt and size == layout(alt)[0]:
        strips = read_sheet(alt, path)
        if strips is None:
            return None
        out = {}
        for name, strip in strips.items():
            fitted = fit_strip(family, name, strip)
            if fitted is None:
                print(f"  ERROR   {os.path.basename(path)}: {name} is drawn too wide for {family}; use {alt}")
                return None
            out[name] = fitted
        print(f"  note    {os.path.basename(path)}: {alt} sheet, read as {family}")
        return out
    return read_sheet(family, path)

def read_source(family, src):
    """{family: {file: strip}} for the main family and its extras, from a
    sheet file or a folder (sheets, templates or packed strips). A drawn
    separate file wins over the same block of a sheet in that folder."""
    extras = EXTRAS_OF.get(family)
    fams = [family] + ([extras] if extras else [])
    out = {f: {} for f in fams}
    if os.path.isfile(src):
        im = Image.open(src)
        fam = extras if extras and im.size == layout(extras)[0] else family
        strips = read_sheet_as(fam, src)
        if strips is None:
            return None
        out[fam] = {k: v for k, v in strips.items() if not is_blank(v)}
        return out
    if not os.path.isdir(src):
        print(f"  ERROR   {src} is not a file or folder")
        return None
    for fam in fams:
        alt = other_width(fam)
        sheet = find_sheet(fam, src) or (alt and find_sheet(alt, src))
        if sheet:
            strips = read_sheet_as(fam, sheet)
            if strips:
                out[fam].update({k: v for k, v in strips.items() if not is_blank(v)})
        for name, w, h, n in SPECS[fam]:
            path = os.path.join(src, name)
            if os.path.isfile(path):
                strip = read_file_strip(fam, name, path)
                if strip is None:
                    # stop rather than merge without it and overwrite it -Elvie
                    return None
                if not is_blank(strip):
                    out[fam][name] = strip
    return out

def parse_picks(values):
    """['walk.png:3=2', ...] -> {('walk.png', 3): 2}"""
    picks = {}
    for v in values:
        try:
            where, src = v.rsplit("=", 1)
            name, frame = where.rsplit(":", 1)
            picks[(name, int(frame))] = int(src)
        except ValueError:
            print(f"  ERROR   --pick {v}: write it as file:frame=source, like walk.png:3=2")
            return None
    return picks

def merge_strips(family, sources, picks=None, clash_dir=None):
    """sources: [{family: {file: strip}}] -> ({family: {file: strip}}, clashes)."""
    picks = picks or {}
    fams = [family] + ([EXTRAS_OF[family]] if family in EXTRAS_OF else [])
    merged, clashes, used = {f: {} for f in fams}, [], set()
    for fam in fams:
        for name, w, h, n in SPECS[fam]:
            have = [(k, src[fam][name]) for k, src in enumerate(sources, 1) if name in src.get(fam, {})]
            if not have:
                continue
            strip = Image.new("RGBA", (w, h * n), CLEAR)
            for i in range(n):
                box = (0, i * h, w, (i + 1) * h)
                drawn = [(k, s.crop(box)) for k, s in have]
                drawn = [(k, f) for k, f in drawn if not is_blank(f)]
                if not drawn:
                    continue
                versions = {}
                for k, f in drawn:
                    versions.setdefault(f.tobytes(), []).append(k)
                choice = drawn[0]
                if len(versions) > 1:
                    want = picks.get((name, i))
                    chosen = next(((k, f) for k, f in drawn if k == want), None)
                    if want is not None:
                        used.add((name, i))
                        if chosen is None:
                            print(f"  warning --pick {name}:{i}={want}: source {want} has no drawing there; kept source {choice[0]}")
                    choice = chosen or choice
                    clashes.append({"family": fam, "file": name, "frame": i,
                                    "sources": [ks[0] for ks in versions.values()],
                                    "same_as": {str(ks[0]): ks[1:] for ks in versions.values() if len(ks) > 1},
                                    "kept": choice[0]})
                    if clash_dir:
                        os.makedirs(clash_dir, exist_ok=True)
                        for ks in versions.values():
                            f = next(f for k, f in drawn if k == ks[0])
                            f.save(os.path.join(clash_dir, f"{name[:-4]}_{i}_{ks[0]}.png"))
                strip.paste(choice[1], (0, i * h))
            merged[fam][name] = strip
    for name, i in picks:
        if (name, i) not in used:
            print(f"  note    --pick {name}:{i}: no clash there, nothing to choose")
    return merged, clashes

def merge(family, out, srcs, picks=None, report=None, clash_dir=None):
    sources = []
    for src in srcs:
        got = read_source(family, src)
        if got is None:
            return False
        n = sum(len(v) for v in got.values())
        print(f"  source  {len(sources) + 1}: {src} ({n} sheet{'s' if n != 1 else ''} with drawing)")
        sources.append(got)
    merged, clashes = merge_strips(family, sources, picks, clash_dir)
    for c in clashes:
        alts = ", ".join(str(k) for k in c["sources"] if k != c["kept"])
        print(f"  clash   {c['file']} frame {c['frame']}: drawn differently in sources "
              f"{', '.join(map(str, c['sources']))}; kept {c['kept']} "
              f"(or --pick {c['file']}:{c['frame']}={alts.split(', ')[0]})")
    if report:
        with open(report, "w") as f:
            json.dump({"family": family, "sources": list(srcs), "clashes": clashes}, f, indent=1)
    extras = EXTRAS_OF.get(family)
    if out.lower().endswith(".png"):
        folder = os.path.dirname(out) or "."
        os.makedirs(folder, exist_ok=True)
        sheet_from_strips(family, merged[family]).save(out)
        print(f"  wrote   {out}")
        if extras and merged[extras]:
            ex = os.path.join(folder, SHEET_FILE[extras])
            sheet_from_strips(extras, merged[extras]).save(ex)
            print(f"  wrote   {ex}")
    else:
        write_strips(family, merged[family], out, quiet=True)
        if extras and merged[extras]:
            print("  extras")
            write_strips(extras, merged[extras], out, quiet=True)
    print(f"  merged  {len(srcs)} sources, {len(clashes)} clash{'es' if len(clashes) != 1 else ''}")
    return True

def merge_options(args):
    """The --pick / --report / --clash-frames options after a command."""
    picks, report, clash_dir, rest, i = [], None, None, [], 0
    while i < len(args):
        if args[i] in ("--pick", "--report", "--clash-frames") and i + 1 < len(args):
            if args[i] == "--pick": picks.append(args[i + 1])
            elif args[i] == "--report": report = args[i + 1]
            else: clash_dir = args[i + 1]
            i += 2
        else:
            rest.append(args[i])
            i += 1
    return parse_picks(picks), report, clash_dir, rest

# ------------------------------------------------------------------- feet
# Where the game's own frames sit: the lowest row of each frame, from pret's
# pokeemerald / pokefirered pics through their pic tables, so frame N here
# is frame N of our sheet. Walking bobs (standing frames a row up, steps a
# row down); bikes sit on the bottom row; back pics reach the bottom edge;
# front pics stop a row above it. (a, b): the boy's and girl's differ, and
# either is fine. Fishing and underwater aren't listed: the rod and the
# diver's mount make the lowest row the art's own business. -Elvie
GAME_FEET = {
  "frlg": {
    "walk.png": [30, 30, 30, 31, 31, 31, 31, 30, 30, 28, 30, 30, 29, 31, 31, 29, (29, 30), 29, (30, 31), (30, 31)],
    "bike.png": [31, 31, 31, 31, 31, 31, 31, 31, 31],
    "surf.png": [29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29],
    "fieldMove.png": [30, 30, 30, 30, 30, 30, 30, 30, 30],
    "vsSeekerBike.png": [31, 31, 31, 31, 31, 31],
    "back.png": [63, 63, 63, 63, 63],
    "front.png": [62],
  },
  "rse": {
    "walk.png": [30, 30, 30, 31, 31, 31, 31, 31, 31, 29, 29, 30, 30, 30, 31, 31, 31, 31],
    "bike.png": [31, 31, 31, 31, 31, 31, 31, 31, 31],
    "acroBike.png": [31, 31, 31, 31, 31, 31, 31, 31, 31, 30, 28, 30, 29, 30, 29, 30, 29, 31, 31, 31, 31, 28, 28, 29, 29, 31, 31],
    "surf.png": [30, 30, 31, 30, 30, 30, 30, 31, 31, 29, 29, 30],
    "fieldMove.png": [30, 30, 30, 30, 30],
    "watering.png": [30, 30, 30, 31, 31, 30, 30, 30, 30],
    "back.png": [63, 63, 63, 63],
    "front.png": [62],
    "decorating.png": [30],
  },
}

def feet_rows(family, name, index):
    """The rows the game's frame sits on, as a tuple (empty if not listed)."""
    rows = GAME_FEET.get(base_of(family), {}).get(name)
    if not rows or index >= len(rows):
        return ()
    r = rows[index]
    return r if isinstance(r, tuple) else (r,)

# The game's walking steps drop the whole sprite a row: the head is one row
# lower than in the standing frame, in the same column, in every facing of
# both games (FRLG's left steps keep their feet up, but the head still drops).
# So steps are lined up by the head, which is what the eye follows; a step
# whose head doesn't match its standing frame closely, or that wouldn't fit,
# falls back to its feet. -Elvie
WALK_FACINGS = ((0, 3, 4), (1, 5, 6), (2, 7, 8))  # standing frame, steps
# Running does the same against its own standing frame (the game's running
# steps are a row below it too): RSE runs in walk.png 9-17 like walking,
# FRLG keeps each facing's three run frames together. -Elvie
STEP_GROUPS = {
  "frlg": WALK_FACINGS + ((9, 10, 11), (12, 13, 14), (15, 16, 17)),
  "rse":  WALK_FACINGS + ((9, 12, 13), (10, 14, 15), (11, 16, 17)),
}

def head_shift(stand, step, rows=10, reach=4):
    """(match, dx, dy): moving step by dx, dy lays its head over the standing
    frame's (its top rows). match is the share of head pixels that agree."""
    bb = stand.getchannel("A").getbbox()
    if not bb or not step.getchannel("A").getbbox():
        return 0, 0, 0
    a, b = stand.load(), step.load()
    W, H = stand.size
    best = (-1, 0, 0)
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            same = seen = 0
            for y in range(bb[1], min(H, bb[1] + rows)):
                for x in range(W):
                    p = a[x, y]
                    xx, yy = x - dx, y - dy
                    q = b[xx, yy] if 0 <= xx < W and 0 <= yy < H else CLEAR
                    if p[3] or q[3]:
                        seen += 1
                        same += bool(p[3] and q[3] and p[:3] == q[:3])
            score = same / max(1, seen)
            if score > best[0] or (score == best[0] and abs(dx) + abs(dy) < abs(best[1]) + abs(best[2])):
                best = (score, dx, dy)
    return best

def feet(family, folder, match=False):
    """Each frame against where the game's sits (lowest row; walking steps
    by the head); with match, frames moved there."""
    base = base_of(family)
    changed = found = 0
    too_tall = []
    for name in GAME_FEET.get(base, {}):
        path = os.path.join(folder, name)
        if not os.path.isfile(path):
            continue
        w, h, n = spec(base, name)
        im = Image.open(path).convert("RGBA")
        if im.height != h * n or im.width not in (w, 32):
            print(f"  skip    {name} ({im.width}x{im.height} isn't a {base} {name})")
            continue
        W = im.width
        frames = [im.crop((0, i * h, W, (i + 1) * h)) for i in range(n)]
        boxes = [f.getchannel("A").getbbox() for f in frames]
        fits = lambda i, dx, dy: (boxes[i][0] + dx >= 0 and boxes[i][2] + dx <= W
                                  and boxes[i][1] + dy >= 0 and boxes[i][3] + dy <= h)

        # A frame that's a copy of an earlier one stands in for art the set
        # doesn't have (tricks drawn as the riding frame): it moves with its
        # original, so it doesn't float or sink on its own. -Elvie
        first, copy_of = {}, {}
        for i, f in enumerate(frames):
            key = f.tobytes()
            if key in first:
                copy_of[i] = first[key]
            else:
                first[key] = i

        moves, why, stuck = {}, {}, []
        for i in range(n):
            want = feet_rows(base, name, i)
            if i in copy_of or not want or not boxes[i] or boxes[i][3] - 1 in want:
                continue
            got = boxes[i][3] - 1
            row = min(want, key=lambda r: abs(r - got))
            moves[i] = (0, row - got)
            why[i] = f"feet on row {got}, the game's is {row}"
        if name == "walk.png":
            for st, a, b in STEP_GROUPS[base]:
                if st >= n or b >= n:
                    continue
                if not boxes[st] or a in copy_of or b in copy_of or not boxes[a] or not boxes[b]:
                    continue
                regs = {i: head_shift(frames[st], frames[i]) for i in (a, b)}
                if not all(regs[i][0] >= 0.7 for i in (a, b)):
                    continue
                # Steps a row below the standing frame's head, as the game
                # does. The standing frame goes on the game's row, or up to a
                # row above it when the steps are drawn taller and need room
                # below to dip. If even that doesn't fit, the feet decide and
                # the set keeps its own bob. Sideways only when the heads
                # match closely. -Elvie
                feet_dy = moves.get(st, (0, 0))[1]
                room = min(h - boxes[i][3] - (dy + 1) for i, (_, _, dy) in regs.items())
                sdy = min(feet_dy, room)
                plan = None
                if sdy >= feet_dy - 1 and boxes[st][1] + sdy >= 0:
                    p = {i: (dx if sc >= 0.9 else 0, dy + 1 + sdy) for i, (sc, dx, dy) in regs.items()}
                    if all(fits(i, *p[i]) for i in (a, b)):
                        plan = p
                if plan:
                    if sdy != feet_dy:
                        # a row higher than the game's, to leave the steps room
                        moves.pop(st, None)
                        why.pop(st, None)
                        if sdy:
                            moves[st] = (0, sdy)
                            got = boxes[st][3] - 1
                            why[st] = f"feet on row {got}, the game's is {got + feet_dy}; {got + sdy} leaves the steps room to dip"
                    for i in (a, b):
                        moves.pop(i, None)
                        why.pop(i, None)
                        dx, dy = plan[i]
                        if (dx, dy) != (0, 0):
                            moves[i] = (dx, dy)
                            top = boxes[i][1]
                            side = f"; {abs(dx)} px {'left' if dx > 0 else 'right'} of the standing frame's head" if dx else ""
                            why[i] = f"head on row {top}, the game's is {top + dy}{side}"
        for i, (dx, dy) in list(moves.items()):
            if not fits(i, dx, dy):
                stuck.append(i)
                why[i] += "; too tall to move up without cutting off its top" if dy < 0 else "; doesn't fit when moved"
        for i in sorted(why):
            print(f"  differs {name} frame {i}: {why[i]}")
        for i, j in copy_of.items():
            if j in moves:
                moves[i] = moves[j]
        if not moves:
            print(f"  ok      {name}: every frame where the game's sits")
            continue
        found += len(why)
        if stuck and not match:
            too_tall.append(name)
        if match and stuck:
            # moving the rest would leave a trick or a pose half lifted, so
            # the whole sheet stays as it is -Elvie
            print(f"  kept    {name} as it is: frame{'s' if len(stuck) > 1 else ''} "
                  f"{', '.join(map(str, stuck))} can't move without losing pixels")
            continue
        if match:
            # frame by frame, so nothing spills into a neighbour
            clean = Image.new("RGBA", im.size, CLEAR)
            for i in range(n):
                cell = Image.new("RGBA", (W, h), CLEAR)
                cell.paste(frames[i], moves.get(i, (0, 0)))
                clean.paste(cell, (0, i * h))
            clean.save(path)
            changed += len(moves)
            print(f"  moved   {name}: {len(moves)} frame{'s' if len(moves) != 1 else ''}")
    if match:
        print(f"  matched {changed} frame{'s' if changed != 1 else ''}")
    elif found:
        note = f" (except {', '.join(too_tall)}: a frame too tall to move up)" if too_tall else ""
        print(f"  off     {found} frame{'s' if found != 1 else ''}; --match moves them{note}")
    return True

# ------------------------------------------------------------------- dive
# Underwater art for sets with none. The game's diver rides a dark
# silhouette of a Pokemon; this recolors the surf blob to match, keeping its
# shading in four dark blues. The surf sitting frames stand in for the
# diver: underwater frames are drawn in the same place as surf ones. -Elvie
DIVE_RAMP = [(8, 16, 40), (24, 40, 80), (40, 64, 112), (64, 96, 144)]
# Diving frames get a navy wash so the diver reads as underwater: navy laid
# over every drawn pixel at 60%, as Elvie did by hand for HGSS Ash. -Elvie
DIVE_SHADE, DIVE_SHADE_ALPHA = (0, 25, 113), 0.6

def dive_shade(im):
    """A sprite with DIVE_SHADE laid over its drawn pixels, alpha kept."""
    im = im.convert("RGBA")
    px, k = im.load(), DIVE_SHADE_ALPHA
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = tuple(round(c * (1 - k) + s * k) for c, s in zip((r, g, b), DIVE_SHADE)) + (a,)
    return im

def dive_tint(im):
    """A sprite recolored into DIVE_RAMP by brightness, alpha kept."""
    im = im.convert("RGBA")
    px = im.load()
    lumas = sorted({(299 * r + 587 * g + 114 * b) // 1000
                    for y in range(im.height) for x in range(im.width)
                    for r, g, b, a in [px[x, y]] if a})
    if not lumas:
        return im
    lo, hi = lumas[0], lumas[-1]
    out = Image.new("RGBA", im.size, CLEAR)
    po = out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a:
                t = ((299 * r + 587 * g + 114 * b) // 1000 - lo) / max(1, hi - lo)
                po[x, y] = DIVE_RAMP[min(len(DIVE_RAMP) - 1, int(t * len(DIVE_RAMP)))] + (a,)
    return out

# Fly bird kits (flybirds/<name>/): back.png and front.png, two 64x64
# frames each (fly-off, fly-in), and kit.json with the tilt and, per frame,
# which surf frame rides (0 down, 1 up, 2 left), whether it's mirrored and
# where the tilted rider's centre goes; a frame's own "tilt" beats the
# kit's. Users nudge from there. A kit can
# also have bird.png, the FR/LG extra (the bird alone, 64x64). -Elvie
FLY_TILT = 10.23  # degrees clockwise, as Elvie tilts her riders by hand
FLY_FRAMES = [{"surf": 0, "mirror": True, "x": 29, "y": 23},
              {"surf": 1, "mirror": True, "x": 32, "y": 29}]

# Blob sets (blobs/<set>/): frlg/surfBlob.png, rse/surfBlob.png and
# rse/diveBlob.png, drawn to match, for looks with no blob of their own.
# Copied as they are; a missing file in the set is just skipped. -Elvie
BLOB_FILES = (("frlg", "surfBlob.png", "surf"), ("rse", "surfBlob.png", "surf"), ("rse", "diveBlob.png", "dive"))

def blobs(gen3, kit, kinds=("surf", "dive"), force=False):
    """A blob set's surf/dive blobs into a look's gen3 folder."""
    made = 0
    for fam, name, kind in BLOB_FILES:
        src, dst_dir = os.path.join(kit, fam, name), os.path.join(gen3, fam)
        if kind not in kinds or not os.path.isfile(src):
            continue
        if not os.path.isdir(dst_dir):
            print(f"  skip    {fam}/{name} (the look has no {fam} folder)")
            continue
        dst = os.path.join(dst_dir, name)
        if os.path.exists(dst) and not force:
            print(f"  skip    {fam}/{name} (already there; --force to replace it)")
            continue
        w, h, n = spec(fam + "_extras", name)
        im = Image.open(src).convert("RGBA")
        if im.size != (w, h * n):
            print(f"  skip    {fam}/{name} (the set's is {im.width}x{im.height}, expected {w}x{h * n})")
            continue
        im.save(dst)
        print(f"  made    {fam}/{name}")
        made += 1
    return made > 0

# Dynamic surf overworld sheets (ghoulslash's FR hack and its expansion):
# the Pokemon facing down, up and left (and right, on sheets with a
# unique one), then the same frames again for the parts drawn over the
# player. Placed like the game's own blob, so they map frame for frame:
# FR/LG's blob takes two bob frames a facing, R/S/E's the first (it bobs
# in code), and the overlay is that first frame's front parts. -Elvie
# Frames per sheet -> frames per facing, facings (down, up, left[, right]),
# and whether there's an overlay half. From the hack's src/surf_mons.h. -Elvie
SURFMON_LAYOUTS = {6: (2, 3, False), 12: (2, 3, True), 16: (2, 4, True), 32: (4, 4, True)}
# 64x64 sheets: the games' blob is 32x32 around the same centre (the
# hack's 64x64 template has the player 16 in from where the 32x32 one
# does). Each facing keeps the 32x32 centred on its drawing, so as little
# as possible is cut, and the rider moves with it to stay where the sheet
# drew them: the rider offsets, saved as surfBlob.json and applied by the
# mod.
# --middle keeps the middle 32x32 instead; --half draws the whole frame at
# half size (every edge kept, but the Pokemon smaller than the rider). -Elvie
# How far the rider can move and stay in its 32x32 surf frame (the game's
# surf sitters fill rows 12-29, columns 8-23 of it). Past that the mod
# grows the surf frames to fit, so it's only mentioned. -Elvie
SURFMON_REACH = ((-8, 8), (-12, 2))

def surfmon_strip(path):
    """The sheet as RGBA. GBA sheets keep colour 0 for see-through, whatever
    the PNG's own transparency says."""
    im = Image.open(path)
    if im.mode == "P":
        mask = im.point(lambda i: 0 if i == 0 else 255, "L")
        im = im.convert("RGBA")
        im.putalpha(mask)
        return im
    return im.convert("RGBA")

def surfmon_half(frame):
    """Half size, pixel art friendly: each 2x2 block takes its commonest
    colour (the darker on a tie), a lone dark pixel kept for outlines."""
    w, h = frame.size
    out = Image.new("RGBA", (w // 2, h // 2), CLEAR)
    px, po = frame.load(), out.load()
    for y in range(h // 2):
        for x in range(w // 2):
            block = [px[2 * x + i, 2 * y + j] for j in (0, 1) for i in (0, 1)]
            solid = [p for p in block if p[3] >= 128]
            if len(solid) < 2:
                if solid and sum(solid[0][:3]) < 200:
                    po[x, y] = solid[0][:3] + (255,)
                continue
            counts = {}
            for p in solid:
                counts[p[:3]] = counts.get(p[:3], 0) + 1
            best = max(counts.items(), key=lambda kv: (kv[1], -sum(kv[0])))[0]
            po[x, y] = best + (255,)
    return out

FACINGS3 = ("down", "up", "left")

def surfmon_frames(path, fit=None):
    """[(base, overlay or None)] for down, up, left, each a list of the
    facing's bob frames as 32x32 RGBA; a note on any resizing; and each
    facing's rider offset that keeps the rider where the sheet drew them."""
    im = surfmon_strip(path)
    size = im.width
    if size not in (32, 64) or im.height % size:
        return None, f"it's {im.width}x{im.height}; it needs 32 or 64 wide", None
    n = im.height // size
    if n not in SURFMON_LAYOUTS:
        return None, f"it has {n} frames; the layouts known are {sorted(SURFMON_LAYOUTS)}", None
    per, faces, over = SURFMON_LAYOUTS[n]
    frames = [im.crop((0, i * size, size, (i + 1) * size)) for i in range(n)]
    half = per * faces
    notes, riders, out = [], [], []
    for face in range(3):
        idx = list(range(face * per, face * per + 2))
        top_idx = [half + i for i in idx] if over else []
        base = [frames[i] for i in idx]
        top = [frames[i] for i in top_idx] if over else None
        rider = (0, 0)
        if size == 64:
            if fit == "half":
                base = [surfmon_half(f) for f in base]
                top = [surfmon_half(f) for f in top] if top else None
                notes.append(f"{FACINGS3[face]} at half size")
            else:
                # each facing's own 32x32, centred on its drawing -Elvie
                bb = None
                for f in base + (top or []):
                    b2 = f.getbbox()
                    if b2:
                        bb = b2 if bb is None else (min(bb[0], b2[0]), min(bb[1], b2[1]), max(bb[2], b2[2]), max(bb[3], b2[3]))
                x0 = y0 = 16
                if fit != "middle" and bb is not None:
                    x0 = max(0, min(32, (bb[0] + bb[2]) // 2 - 16))
                    y0 = max(0, min(32, (bb[1] + bb[3]) // 2 - 16))
                base = [f.crop((x0, y0, x0 + 32, y0 + 32)) for f in base]
                top = [f.crop((x0, y0, x0 + 32, y0 + 32)) for f in top] if top else None
                rider = (16 - x0, 16 - y0)
                past = 0 if bb is None else max(x0 - bb[0], y0 - bb[1], bb[2] - x0 - 32, bb[3] - y0 - 32, 0)
                notes.append(f"{FACINGS3[face]} cut" + (f", {past} px past the edge" if past else ""))
        riders.append(rider)
        out.append((base, top))
    note = ("64x64: " + "; ".join(notes)) if notes else ""
    return out, note, riders

def surfmon(path, gen3, force=False, fit=None, off=None):
    """surfBlob.png and surfOverlay.png for each family folder the look has,
    and surfBlob.json with the rider offsets (down, up, left) when any
    isn't (0, 0). fit: "half" or "middle" for a 64x64 sheet, else each
    facing is centred on its drawing. off: one offset for every facing, or
    three, instead of the ones that keep the sheet's."""
    faces, note, riders = surfmon_frames(path, fit)
    if faces is None:
        print(f"  ERROR   {os.path.basename(path)}: {note}")
        return False
    if note:
        print(f"  note    {note}")
    if off is not None:
        riders = list(off) if len(off) == 3 else [off[0]] * 3
    (lx, hx), (ly, hy) = SURFMON_REACH
    riders = [tuple(r) for r in riders]
    for face, r in enumerate(riders):
        if not (lx <= r[0] <= hx and ly <= r[1] <= hy):
            print(f"  note    {FACINGS3[face]} rider offset {r[0]},{r[1]} goes past the surf frame; the mod makes the frame bigger")
    moved = any(r != (0, 0) for r in riders)
    if moved:
        print("  note    rider offsets " + "  ".join(f"{FACINGS3[i]} {r[0]},{r[1]}" for i, r in enumerate(riders)))
    made = 0
    for fam, bobs in (("frlg", 2), ("rse", 1)):
        dst_dir = os.path.join(gen3, fam)
        if not os.path.isdir(dst_dir):
            print(f"  skip    {fam} (the look has no {fam} folder)")
            continue
        blob = Image.new("RGBA", (32, 32 * 3 * bobs), CLEAR)
        over = Image.new("RGBA", (32, 96), CLEAR)
        for face, (base, top) in enumerate(faces):
            for k in range(bobs):
                # the front parts too, so nothing's missing where no player covers it
                cell = base[k].copy()
                if top:
                    cell.alpha_composite(top[k])
                blob.alpha_composite(cell, (0, (face * bobs + k) * 32))
            if top:
                over.alpha_composite(top[0], (0, face * 32))
        offset = os.path.join(dst_dir, "surfBlob.json")
        if moved and (force or not os.path.exists(offset)):
            with open(offset, "w") as f:
                json.dump({"player": [list(r) for r in riders]}, f)
                f.write("\n")
            print(f"  made    {fam}/surfBlob.json")
        elif not moved and os.path.exists(offset) and force:
            os.remove(offset)
            print(f"  removed {fam}/surfBlob.json (no offset)")
        for name, img in (("surfBlob.png", blob), ("surfOverlay.png", over if over.getbbox() else None)):
            dst = os.path.join(dst_dir, name)
            if img is None:
                print(f"  skip    {fam}/{name} (the sheet has no front parts)")
                continue
            if os.path.exists(dst) and not force:
                print(f"  skip    {fam}/{name} (already there; --force to replace it)")
                continue
            img.save(dst)
            print(f"  made    {fam}/{name}")
            made += 1
    return made > 0

def flybird(folder, kit, nudges=((0, 0), (0, 0)), out=None, force=False, bird=True, tilts=(None, None)):
    """flyBird.png (and the kit's bird.png) for a packed FR/LG look folder."""
    alone = os.path.join(kit, "bird.png")
    if bird and os.path.isfile(alone):
        target = os.path.join(folder, "bird.png")
        im = Image.open(alone).convert("RGBA")
        if im.size != (64, 64):
            print(f"  skip    bird.png (the kit's is {im.width}x{im.height}, expected 64x64)")
        elif os.path.exists(target) and not force:
            print("  skip    bird.png (already there; --force to replace it)")
        else:
            im.save(target)
            print("  made    bird.png (the bird alone)")
    out = out or os.path.join(folder, "flyBird.png")
    if os.path.exists(out) and not force:
        print(f"  skip    {os.path.basename(out)} (already there; --force to replace it)")
        return False
    layers = {}
    for name in ("back.png", "front.png"):
        path = os.path.join(kit, name)
        if not os.path.isfile(path):
            print(f"  ERROR   the kit has no {name}")
            return False
        layers[name] = Image.open(path).convert("RGBA")
        if layers[name].size != (64, 128):
            print(f"  ERROR   the kit's {name} is {layers[name].width}x{layers[name].height}, expected 64x128")
            return False
    conf = {}
    if os.path.isfile(os.path.join(kit, "kit.json")):
        with open(os.path.join(kit, "kit.json")) as f:
            conf = json.load(f)
    tilt = conf.get("tilt", FLY_TILT)
    frames = conf.get("frames", FLY_FRAMES)
    src = os.path.join(folder, "surf.png")
    if not os.path.isfile(src):
        print("  ERROR   no surf.png in this folder for the rider")
        return False
    surf = Image.open(src).convert("RGBA")
    if surf.height != 32 * 12 or surf.width not in (16, 32):
        print(f"  ERROR   surf.png is {surf.width}x{surf.height}, expected 16x384 or 32x384")
        return False
    sheet = Image.new("RGBA", (64, 128), CLEAR)
    for i, (f, (dx, dy), turn) in enumerate(zip(frames, nudges, tilts)):
        turn = f.get("tilt", tilt) if turn is None else turn
        rider = surf.crop((0, f["surf"] * 32, surf.width, f["surf"] * 32 + 32))
        if f.get("mirror"):
            rider = rider.transpose(Image.FLIP_LEFT_RIGHT)
        # nearest neighbour keeps the palette; PIL turns anticlockwise
        rider = rider.rotate(-turn, resample=Image.NEAREST, expand=True)
        x = f["x"] + dx - rider.width // 2
        y = f["y"] + dy - rider.height // 2
        frame = layers["back.png"].crop((0, i * 64, 64, i * 64 + 64))
        layer = Image.new("RGBA", (64, 64), CLEAR)
        layer.paste(rider, (x, y), rider)
        frame.alpha_composite(layer)
        frame.alpha_composite(layers["front.png"].crop((0, i * 64, 64, i * 64 + 64)))
        sheet.paste(frame, (0, i * 64))
        print(f"  rider   {('fly-off', 'fly-in')[i]}: surf frame {f['surf']}, centre at {f['x'] + dx},{f['y'] + dy}, "
              f"tilted {turn:g} degrees")
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    sheet.save(out)
    print(f"  made    {os.path.basename(out)}")
    return True

def dive(folder, blob=True, underwater=True, force=False, shade=True):
    """diveBlob.png and/or underwater.png in a packed R/S/E look folder."""
    if not os.path.isdir(folder):
        print(f"  ERROR   {folder} is not a folder")
        return False
    made = 0
    jobs = []
    if blob:
        jobs.append(("diveBlob.png", "surfBlob.png", "rse_extras"))
    if underwater:
        jobs.append(("underwater.png", "surf.png", "rse"))
    for name, src_name, fam in jobs:
        out = os.path.join(folder, name)
        if os.path.exists(out) and not force:
            print(f"  skip    {name} (already there; --force to replace it)")
            continue
        src = os.path.join(folder, src_name)
        sw, sh, sn = spec(fam, src_name)
        if not os.path.isfile(src):
            print(f"  skip    {name} (no {src_name} in this folder to make it from)")
            continue
        im = Image.open(src).convert("RGBA")
        if im.size != (sw, sh * sn):
            print(f"  skip    {name} ({src_name} is {im.width}x{im.height}, expected {sw}x{sh * sn})")
            continue
        w, h, n = spec(fam, name)
        if name == "diveBlob.png":
            strip = dive_tint(im)
        else:
            # standard order: stand down, up, left, then two steps each;
            # every one is the surf sitting frame for that facing
            strip = Image.new("RGBA", (w, h * n), CLEAR)
            for fi in range(n):
                facing = fi if fi < 3 else (fi - 3) // 2
                strip.paste(im.crop((0, facing * sh, sw, (facing + 1) * sh)), (0, fi * h))
            if shade:
                strip = dive_shade(strip)
        if not strip.getbbox():
            print(f"  skip    {name} ({src_name} is blank)")
            continue
        strip.save(out)
        print(f"  made    {name} from {src_name}")
        made += 1
    return made > 0

FORMAT_FLAGS = {"--sheet": ("sheet",), "--separate": ("separate",), "--both": ("sheet", "separate")}

if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) >= 4 and a[0] == "pack" and a[1] in SPECS and "--merge" in a[4:]:
        # into what's already in the look folder, frame by frame -Elvie
        picks, report, clash_dir, rest = merge_options([x for x in a[4:] if x != "--merge"])
        if picks is None or rest:
            print(__doc__); sys.exit(2)
        family = a[1]
        if os.path.isfile(a[2]) and family in EXTRAS_OF and Image.open(a[2]).size == layout(EXTRAS_OF[family])[0]:
            family = EXTRAS_OF[family]
        srcs = [a[3], a[2]] if os.path.isdir(a[3]) else [a[2]]
        sys.exit(0 if merge(family, a[3], srcs, picks, report, clash_dir) else 1)
    if len(a) == 4 and a[0] == "pack" and a[1] in SPECS:
        sys.exit(0 if pack(a[1], a[2], a[3]) else 1)
    if len(a) >= 4 and a[0] == "merge" and a[1] in SPECS:
        picks, report, clash_dir, rest = merge_options(a[3:])
        if picks is None or not rest:
            print(__doc__); sys.exit(2)
        sys.exit(0 if merge(a[1], a[2], rest, picks, report, clash_dir) else 1)
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
    if len(a) == 5 and a[0] == "transfer" and a[1] in SPECS and a[3] in SPECS:
        sys.exit(0 if transfer(a[1], a[2], a[3], a[4]) else 1)
    if len(a) in (3, 4) and a[0] == "feet" and a[1] in SPECS and a[3:] in ([], ["--match"]):
        sys.exit(0 if feet(a[1], a[2], a[3:] == ["--match"]) else 1)
    if len(a) >= 3 and a[0] == "blobs" and set(a[3:]) <= {"--surf", "--dive", "--force"}:
        kinds = [k for k in ("surf", "dive") if "--" + k in a] or ["surf", "dive"]
        sys.exit(0 if blobs(a[1], a[2], kinds, "--force" in a) else 1)
    if len(a) >= 3 and a[0] == "surfmon":
        opts, off, ok = a[3:], None, True
        if "--off" in opts:
            k = opts.index("--off")
            try:
                # dx,dy for every facing, or down/up/left: dx,dy/dx,dy/dx,dy -Elvie
                off = [tuple(int(v) for v in part.split(",")) for part in opts[k + 1].split("/")]
                if len(off) not in (1, 3) or any(len(o) != 2 for o in off):
                    raise ValueError
                opts = opts[:k] + opts[k + 2:]
            except (IndexError, ValueError):
                ok = False
        if ok and set(opts) <= {"--force", "--half", "--middle"}:
            fit = "half" if "--half" in opts else "middle" if "--middle" in opts else None
            sys.exit(0 if surfmon(a[1], a[2], "--force" in opts, fit, off) else 1)
    if len(a) >= 3 and a[0] == "flybird":
        opts, nudge, out, force, bird, k = a[3:], [(0, 0), (0, 0)], None, False, True, 0
        tilts = [None, None]
        while k < len(opts):
            if opts[k] in ("--off", "--in") and k + 1 < len(opts):
                x, y = (int(v) for v in opts[k + 1].split(","))
                nudge[opts[k] == "--in"] = (x, y)
                k += 2
            elif opts[k] in ("--off-tilt", "--in-tilt") and k + 1 < len(opts):
                tilts[opts[k] == "--in-tilt"] = float(opts[k + 1])
                k += 2
            elif opts[k] == "--out" and k + 1 < len(opts):
                out = opts[k + 1]
                k += 2
            elif opts[k] == "--force":
                force = True
                k += 1
            elif opts[k] == "--no-bird":
                bird = False
                k += 1
            else:
                sys.exit(f"  ERROR   unknown option {opts[k]}")
        sys.exit(0 if flybird(a[1], a[2], nudge, out, force, bird, tilts) else 1)
    if len(a) >= 2 and a[0] == "dive" and set(a[2:]) <= {"--blob", "--underwater", "--force", "--no-shade"}:
        both = not ({"--blob", "--underwater"} & set(a[2:]))
        sys.exit(0 if dive(a[1], both or "--blob" in a, both or "--underwater" in a, "--force" in a,
                           "--no-shade" not in a) else 1)
    if len(a) == 3 and a[0] == "blank" and a[1] in SPECS:
        blank_sheet(a[1]).save(a[2])
        print(f"  wrote   {a[2]}")
        sys.exit(0)
    print(__doc__)
    sys.exit(2)
