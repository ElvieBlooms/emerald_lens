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

## Importing a sheet made for something else

`import_sheet.py` turns a sprite sheet from a fan game or a community collage
into our combined sheets, ready to check, touch up and pack. Nothing is
resized: sprites are cut out at their real size and set into our frames.

1. **Number the sprites.** `slice` removes the background (transparent, or a
   flat backdrop colour), shrinks a sheet that was blown up 2x/3x/4x back to
   its real size, and writes a preview with every sprite boxed and numbered:

        python3 import_sheet.py slice their_sheet.png numbers.png

2. **Write a recipe** saying which numbers go where. Keys are our sheet's
   section names in lower case (`walk`, `run`, `bike` / `mach bike`,
   `acro bike`, `fish`, `surf`, `underwater`, `watering`, `field move`,
   `back`, `front`, `surf blob`, `fly bird`, `bag`, ...), each with the
   frames per facing (`down`, `up`, `left`) in our order, or `frames` for
   one-row sections. Right-facing rows on the source are skipped, since the
   game mirrors left.

        {
          "family": "rse",
          "sections": {
            "walk": { "down": [59, 60, 62], "up": [96, 97, 99], "left": [63, 64, 66] },
            "surf with blob": { "down": [5, 6, 8, 5], "up": [47, 48, 50, 47], "left": [21, 22, 24, 21] }
          }
        }

   - An entry can be a number, a list of numbers drawn as one sprite (a
     sprite that came out in two bits), `{"piece": 12, "flip": true}`, or
     `null` to leave a frame blank.
   - A fishing rod (or anything else) reaching below the feet would lift the
     sprite, since the lowest pixel goes on the foot row. `{"piece": 40,
     "hang": 5}` says 5 pixels hang below the feet: the feet stay put and
     whatever doesn't fit the frame is cut off.
   - `"shift": -3` moves a sprite 3 pixels left of centre (positive is
     right), to choose which side loses pixels when it's wider than the
     frame: keep the pointing hand, lose the edge of the bag.
   - Sprites drawn touching each other come out as one piece. `"split":
     {"29": 4}` cuts piece 29 into 4 columns (`[4, 2]` for columns and rows),
     used as `"29.1"`, `"29.2"`...
   - `"surf with blob"` takes surf sprites drawn together with the mount, as
     most fan games do (frames per facing: sit, step, step, jump). Each is cut
     in two using the game's own placement (see Surf placement): what falls in
     the player's frame goes to surf.png, the rest to surfBlob.png. In game it
     looks the same as the original, except while hopping on or off the
     water, when the game draws the blob by itself for a moment.
   - Optional: `"scale"` and `"background"` (`"#ff7f27"`) if the guesses are
     wrong, and `"reach"` (default 1) for how far apart pixels can be and
     still count as one sprite. Keep the same values for `slice` and `build`
     (`--scale`, `--bg`, `--reach`) so the numbers match.
   - Sheets saved as JPEG or WebP (Discord and many image hosts convert
     them) come with thousands of smeared colours and a speckled halo round
     every sprite. These are spotted and cleaned up on their own: the halo
     goes with the backdrop and the colours are snapped back to a palette of
     48. Small light patches inside a sprite, like eye whites, are kept.
     `"lossy": false` / `true` (`--lossy no` / `yes`) overrides the guess,
     and `"colors"` (`--colors`) changes the palette size. An original PNG
     still gives the best result when you can get one.

   `recipes/` has worked examples:
   - `example_essentials_rikku.json`: a Pokemon Essentials layout (4x4 per
     action: rows down, left, right, up; columns stand, step, stand, step).
   - `example_frlg_jigglypuff.json`: a FRLG-style collage with a Jigglypuff
     surf mount.
   - `example_kris_artist_frlg.json` / `_rse.json`: the layout used by the
     artist of one of our Kris sets (rows down, left, right, up; a 16-frame
     row per facing that comes out as one piece and is split; bike and
     fishing grids of 8 columns; back frames along the top).
   - `example_dp_dawn_rse.json` / `_frlg.json`: a Diamond/Pearl trainer rip
     (labelled boxes on white, rows down, right, up, left) on the wide
     sheets, with the big back pics, portrait and intro shrunk to fit.
   - `example_kris_hgss_collage_rse.json` / `_frlg.json`: an HGSS-style
     Kris collage (rows down, left, up, right; step, stand, step), a WebP on
     the wide sheets, with the battle throw strip pasted under the sheet and
     `hang` on the rod frames. `example_kris_rocket_collage_*.json` takes
     the black Rocket uniform walk and run from the same sheet.

3. **Build**, then look over the result and pack it as usual:

        python3 import_sheet.py build their_sheet.png recipe.json ./imported
        python3 pack_gen3.py pack rse ./imported ../../assets/sprites/<folder>/gen3/rse

   Each sprite is centred, with its lowest pixel where the game's own art
   stands. It warns about anything too big for its frame (cut off, never
   shrunk). Whatever the source doesn't have stays blank, so the game's own
   sprite fills in. If a section is only partly mapped, `pack` warns about
   the blank frames, since the player would vanish in those poses.

### A folder with one file per action

Sets made for Pokemon Essentials (and fan games built on it) usually come as
a folder of charsets, one image per action, each a grid with a row per
facing. Point `build` at the folder; the recipe names the file for each
section instead of numbering sprites:

    {
      "family": "rse_wide",
      "layout": "essentials",
      "files": {
        "walk": "trProtagGirl_Walk.png",
        "run": "trProtagGirl_Run.png",
        "mach bike": "trProtagGirl_Bike.png",
        "surf": "trProtagGirl_Surf.png",
        "fish": "trProtagGirl_Fish_offset.png",
        "field move": "trProtagGirl_UseHM.png"
      }
    }

    python3 import_sheet.py build ./their-folder recipe.json ./imported

- `"essentials"` is a 4x4 grid, rows down, left, right, up. Grid cells can be
  any size (fishing sheets often use bigger ones); blown-up files are shrunk
  back first.
- Frames are picked for you: stand, step, step for walking, running and
  biking; all four for fishing; sit, step, step, sit for surfing; a one-row
  file (field move) counts through and holds its last frame. Extra frames
  (Acro Bike tricks, VS Seeker) repeat the standing frame. To choose your
  own, give the file as `{"file": "...", "columns": [0, 1, 3]}` (or
  `"columns": {"down": [...], "up": [...], "left": [...]}`); `"grid": [4, 4]`
  and `"rows": [...]` change the layout for one file.
- Cells are placed as drawn, not trimmed, so bobs and rods stay where the
  artist put them: the row the feet stand on lines up with ours.
- Essentials surf sprites don't include the blob, so the game's own blob
  (or your `surfBlob.png`) is used.

`recipes/example_essentials_folder_rse.json` / `_frlg.json` are worked
examples.

Sheets made for other games are other people's work: credit the artist, and
ask before shipping their art with a release.

## Wide sheets (bigger characters)

`frlg_wide_sheet.png` and `rse_wide_sheet.png` are the combined sheets with
32-wide frames where the game uses 16 (walk/run, decorating, and FRLG's surf
and field move), for characters drawn bigger than the game's own: Gen 4
overworld sprites are 17-20 pixels wide, for example. The mod takes either
width. Use `frlg_wide` or `rse_wide` in place of `frlg` or `rse` in any
command (`reference` centres the game's own art in the wider frames), and in
an importer recipe's `"family"`.

## Too big for the frame: shrink

Battle back pics and portraits from later games are often bigger than the
game's frames (Gen 4 back pics run up to about 80 wide; the battle draws
64x64). By default the importer cuts off what doesn't fit, with a warning.
List sections under `"shrink"` in a recipe to scale those sprites down to fit
instead (nearest pixel, keeping their shape):

    "shrink": ["front", "back"]

The game draws everything into its 240x160 screen before enlarging it, so
shrinking here looks the same as anything the game could do: some rows and
columns drop out. Treat it as a starting point to tidy up by hand.
