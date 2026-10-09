# Emerald Lens sprite templates

Two formats, usable interchangeably -- draw in either, convert between them
at any point, and pack from either or both:

- **One combined sheet** (`frlg_sheet.png`, `rse_sheet.png`), laid out like
  the standard community sprite sheets: front, back and intro on top, then a
  labeled block per action. In every block the rows are facing **down, up,
  left** (right-facing frames are the left ones mirrored by the game).
- **Separate templates** in `frlg/` and `rse/`, one strip per game sheet, in
  the game's own frame order.

`frlg` is FireRed and LeafGreen; `rse` is Ruby, Sapphire and Emerald. Each
frame is boxed by a 1px magenta (#FF00FF) guide line; draw only inside the
boxes and keep the background transparent. Gen 3 sprites are always full color.

## Seeing the originals
Export the game's own sprites from your imported cache, in both formats by
default: a filled `frlg_sheet.png` / `rse_sheet.png` plus the separate
templates. Add `--sheet` or `--separate` for just one. They're Nintendo's art
from your own ROM, so keep them on your machine and out of any repo.

    python3 pack_gen3.py reference frlg girl /path/to/pokemon-love2d/firered ./ref-frlg
    python3 pack_gen3.py reference rse  girl /path/to/pokemon-love2d/emerald ./ref-rse
    python3 pack_gen3.py reference rse  girl /path/to/pokemon-love2d/ruby    ./ref-rse --sheet

Use `boy` instead of `girl` for a boy character.

## Converting between formats
`convert` turns a combined sheet into a folder of separate templates, or a
folder of separate templates into a combined sheet. Nothing is lost either
way, and anything not drawn yet stays blank.

    python3 pack_gen3.py convert frlg frlg_sheet.png ./frlg-separate
    python3 pack_gen3.py convert frlg ./frlg frlg_sheet.png

## Packing into the mod
Run these from this folder. Point `pack` at a combined sheet, a folder of separate templates, or a folder
holding both:

    python3 pack_gen3.py pack frlg frlg_sheet.png ../../assets/sprites/<folder>/gen3/frlg
    python3 pack_gen3.py pack rse  ./my-rse-work  ../../assets/sprites/<folder>/gen3/rse

When a folder has both, a drawn separate template is used over the same block
on the combined sheet (the script says so), and blank templates are ignored.
So you can keep most of a character on the sheet and redo one action as a
separate file, or the other way round.

Anything left blank is skipped, so a fallback folder or the game's own sprite
fills in. If a file is only partly drawn (say WALK but not RUN, which share
`walk.png`), it's still packed but you're told which frames are blank, since
the player would vanish in those poses. The script also warns if guide pixels
were painted over. Needs Pillow: `python3 -m pip install --user pillow`.

Need a fresh blank sheet? `python3 pack_gen3.py blank rse rse_sheet.png`

## Frame sizes

| Game sheet | FireRed/LeafGreen | Ruby/Sapphire/Emerald | Combined sheet block(s) |
|---|---|---|---|
| walk.png | 16x32 x 20 | 16x32 x 18 | WALK, RUN (+ WALK EXTRA on FRLG) |
| bike.png | 32x32 x 9 | 32x32 x 9 | BIKE / MACH BIKE |
| acroBike.png | -- | 32x32 x 27 | ACRO BIKE |
| surf.png | 16x32 x 12 | 32x32 x 12 | SURF (sit, move, jump) |
| fieldMove.png | 16x32 x 9 | 32x32 x 5 | FIELD MOVE (/ VS SEEKER) |
| fishing.png | 32x32 x 12 | 32x32 x 12 | FISH |
| vsSeekerBike.png | 32x32 x 6 | -- | VS SEEKER BIKE |
| underwater.png | -- | 32x32 x 9 | UNDERWATER |
| watering.png | -- | 32x32 x 9 | WATERING |
| decorating.png | -- | 16x32 x 1 | DECORATE |
| back.png | 64x64 x 5 | 64x64 x 4 | BACK |
| front.png | 64x64 | 64x64 | FRONT (also the trainer card, and the RSE intro) |
| intro.png | 64x96 | -- | INTRO (FRLG's Oak intro) |
| mapIcon.png | 16x16 | 16x16 | MAP ICON (Town Map / Fly map marker; also the PokeNav and Pokedex area maps on RSE) |
| flyBird.png | 64x64 x 2 | -- | FLY (OFF / IN): the player on the bird as Fly takes off, then lands. Draw the bird too; the reference shows where it sits |

The FRLG sheet grew a FLY block at the bottom. A sheet made before it still packs:
the missing block is read as blank and you're told so.

## Extras (optional)

The surf blob, the Fly bird and the bag have their own smaller sheet,
`frlg_extras.png` / `rse_extras.png`, with separate templates in
`frlg_extras/` and `rse_extras/`. Every command takes `frlg_extras` or
`rse_extras` in place of `frlg` or `rse`:

    python3 pack_gen3.py reference frlg_extras girl /path/to/pokemon-love2d/firered ./ref-frlg
    python3 pack_gen3.py reference rse_extras  girl /path/to/pokemon-love2d/emerald ./ref-rse
    python3 pack_gen3.py convert   rse_extras  rse_extras.png ./rse-extras-separate

Packing goes to the same `gen3/frlg` or `gen3/rse` folder as everything else.
`pack frlg` with an extras sheet packs it as extras, and packing a folder that
holds both the main work and the extras packs both:

    python3 pack_gen3.py pack frlg frlg_extras.png ../../assets/sprites/<folder>/gen3/frlg
    python3 pack_gen3.py pack rse  ./my-rse-work   ../../assets/sprites/<folder>/gen3/rse

| Game sheet | FireRed/LeafGreen | Ruby/Sapphire/Emerald | Extras sheet block |
|---|---|---|---|
| surfBlob.png | 32x32 x 6 | 32x32 x 3 | SURF BLOB (rows down, up, left; FRLG has two bob frames each) |
| bird.png | 64x64 | 32x32 | FLY BIRD (FRLG: the bird alone, before and after the rider frames in `flyBird.png`) |
| bag.png | 64x64 x 4 | 64x64 x 6 | BAG (one per pocket; frame 0 also shows while the bag opens) |

## Surf placement (reference only)

`frlg_surf_placement.png` and `rse_surf_placement.png` show how the game lines
up the player and the surf blob, one cell per facing (right is left mirrored):
pink is the player's frame, blue the blob's, and the dots mark the tile the
player stands on. They aren't packed; they're for checking placement.

From the tile's top-left corner, the 32x32 blob is drawn at (-8, -8), behind
the player. The player is centred on the tile with its feet on the tile's
bottom edge: (0, -16) for FRLG's 16x32 frames, (-8, -16) for RSE's 32x32. So
the player's bottom 24 rows sit over the blob's top 24, and the blob's last
8 rows show below the feet. Standing still, both bob up 1px together (FRLG
also swaps to the blob's second frame), so the overlap never changes.

| Facing | Player frame (surf.png) | Blob frame (surfBlob.png) FRLG | RSE |
|---|---|---|---|
| Down | 0 | 0, 1 | 0 |
| Up | 1 | 2, 3 | 1 |
| Left | 2 | 4, 5 | 2 |
| Right | 2, mirrored | 4, 5, mirrored | 2, mirrored |

`surf` draws the same layout with real art, from a look's folder and/or the
game's own sprites:

    python3 pack_gen3.py surf frlg girl my_surf.png --art ../../assets/sprites/<folder>/gen3/frlg --game /path/to/pokemon-love2d/firered
