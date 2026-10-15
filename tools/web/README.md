# Emerald Lens sprite tools website

A web page for the sprite tools, for people who'd rather not use a
terminal. It runs the same `import_sheet.py` and `pack_gen3.py` from
`../sprite-templates/` in the browser with
[Pyodide](https://pyodide.org) (Python and Pillow compiled to WebAssembly).
Nothing is uploaded: the art stays in the visitor's browser.

The page walks through four steps:

1. **Number the sprites**: `import_sheet.py slice` on a sheet, a folder,
   or a .zip.
2. **Write the recipe and build**: fill the recipe in with the builder (see
   below) or as JSON, starting blank, from `recipes/blank_frlg.json` /
   `blank_rse.json`, or from a recipe file; then `import_sheet.py build`.
3. **Pack into the game's sheets**: `pack_gen3.py pack`, either the sheets
   from step 2 or your own (combined, extras or a templates folder). When
   the look already has files, "Keep what's already in the look" (on by
   default) packs with `--merge`, so new work only fills blank frames and
   redrawn frames are clashes to pick (see Combining). `pack_gen3.py
   transfer` starts the other game's sheet from this one. "Combine sheets"
   runs `pack_gen3.py merge` on any sheets, templates folders, the step 2
   sheets or the look's own files, in an order you set.
4. **Name the look and download it**: a `meta.json` form (label,
   character, genderMode, generation, credit) and a zip of the look folder, ready for
   `assets/sprites/`. A look zip can be opened again to add the other
   family. "Watch it move" plays the packed files (see Previews).

Each step logs the command it ran, so it can be repeated on the command line.

A folder is read a file at a time, with a progress bar, since Python holds
the page while it works and a folder of a few hundred files takes a while
(on a phone most of all). It's kept for the builder, so opening the builder
doesn't read it again. A big folder's numbered preview comes in pages, the
ones `slice` writes on the command line, with a Page picker; the builder
shows the sheet a page at a time too (picking a frame or typing a number
turns to its page). Drawn as one image, a folder that size ran Pyodide out
of memory.

`reference` isn't on the site: it reads the game's own art from a local
install, so it stays command-line only.

## The recipe builder
The builder shows the cleaned sheet with every piece numbered, and the
game's frames grouped by section (front, back, walk...), each frame drawn
as build will place it: centred, feet on the game's foot row. Pick a frame,
click the sprite that goes in it, and the next frame is picked. Shift-click
adds a sprite to the same frame (drawn together as one). For the picked
frame you can mirror it, set hang and shift, type piece numbers (`12 13`,
`29.2`, `walk:3`), or cut a piece in two when sprites touch (`split`). A
section's "Shrink" box adds it to `shrink`. A frame turns red when its
sprite won't fit or names a piece that isn't on the sheet, the same cases
build warns about.

The recipe JSON stays the one source: each click rewrites it (short lists
kept on one line, like the examples), and editing the JSON redraws the
builder, so either works and the result runs with the CLI too. Sections the
builder doesn't show, like `surf with blob`, and folder recipes (`files`)
are left as they are, for editing as JSON.

Opening the builder copies step 1's slicing options into the recipe
(`scale`, `background`, `reach`, `lossy`, `colors`), so build numbers the
sheet the same way.

## Combining
Both merging paths ask `merge` for a report (`--report`) and a PNG of
every clashing version (`--clash-frames`), then show each clash as a card:
the file and frame, where it sits ("walk, down 3"), and each version to
click. "Keep all from" buttons set every clash at once. Applying reruns
the same command with `--pick file:frame=source`, so the result matches
the command line exactly. Sources are snapshots: rebuilding in step 2
doesn't change a source already added.

## Previews
An animated preview plays a section the way the game does. The builder
shows one for the section you're working on, from the frames as build will
place them; step 4 plays the packed files themselves, as the game reads
them. Both use `preview.js`.

- **Walking-style sections** (walk, run, bike, Mach Bike, underwater):
  step, stand, step, stand, with the ground scrolling under the player. Down, up, left, and right as the game
  draws it (left mirrored).
- **Surf**: the sit frame on the surf blob, both bobbing a pixel while
  still, lined up as the game does (blob 32x32 at -8,-8 from the tile,
  behind the player; FRLG swaps its two blob frames as it bobs). Without
  surf blob art a plain stand-in shape is drawn, never the game's own.
- **Acro Bike**: a Trick picker plays riding, popping a wheelie and
  landing it, a bunny hop (the balance frame through the game's low jump,
  over a stand-in shadow), riding a wheelie, and the front-wheel frames
  (on the sheet, but only used by actions the game never runs).
- **Back pic**: idle, then the throw, with the durations from the games'
  own back animations (FRLG idles on frame 0, RSE on frame 3).
- **Everything else** plays its frames in order.

Timings and frame orders come from pokeemerald (`object_event_anims.h`,
`event_object_movement.c`): walking 8 game frames a frame, running and
biking 4, Acro Bike tricks 4, moving 1 or 2 pixels a frame. The surf bob
speed is a guess; check it in game. Pause, step a frame at a time, change the speed or zoom.
Motion starts paused when the system asks for reduced motion.

**Save as GIF** saves the preview as a looping GIF, to share. It's the
loop exactly as shown: every facing side by side at the zoom on screen,
with the trick, speed and Moving setting as chosen. Frames are rendered one
game frame at a time; scenes with the ground moving are sampled every 2
game frames, since GIFs can't show 60 a second. Frames that don't change
are merged, and the delays are rounded so the whole loop keeps the game's
timing (a walk cycle is 530 ms in the GIF, 533 ms in the game). Between
facings, and around battle pics, the GIF is transparent, so it sits on
Discord's dark or light background. Pillow (`web_runner.make_gif`) writes
it with an exact palette, since sprites rarely have 255 colours. The file is named
from the look's folder name, family and section (`kris-rse-walk.gif`).
A single-frame section, like the front pic, saves as a still GIF.

## Files
- `index.html`, `style.css`, `app.js`: the page.
- `builder.js`: the recipe builder.
- `preview.js`: the animated previews.
- `merge.js`: the clash picker for combining and merged packing.
- `web_runner.py`: the glue. It runs a tool's command line with `runpy`
  (same argv as the CLI) and captures its output, plus a few file helpers
  (zip, unzip, listing). `builder_data` gives the builder its pieces, slots,
  frame sizes and foot rows from `import_sheet`'s own functions, so the
  numbers always match `slice` and `build`. `layout_data` gives the same
  section layout without a sheet, for previewing packed files.

The page loads the tools from `../sprite-templates/`, so they never drift:
a fix to the scripts is a fix to the site.

## Hosting
It's static files: serve the `tools/` folder (not just `tools/web/`, since
the page fetches `../sprite-templates/`) and open `web/index.html`. There's
no server code, database or upload handling.

To try it locally, double-click a launcher in `tools/` (see
`HOW TO TRY THE SPRITE TOOLS.txt` there, written for testers):

- Windows: `Start sprite tools (Windows).bat` runs `launch/serve.ps1`, a small
  server in Windows PowerShell 5.1, which comes with Windows 10 and 11.
- Mac: `Start sprite tools (Mac).command`; Linux: `sh start-sprite-tools.sh`.
  Both run `launch/start.sh`, which uses `launch/serve.py` (Python 3.7+) or,
  when Python isn't usable (a Mac without the developer tools), `launch/serve.pl`
  (Perl, which comes with macOS).

Each serves `tools/` to this computer only (127.0.0.1 / localhost), on the
first free port from 8765, opens the browser, and stops when its window is
closed. Or by hand: `cd tools`, `python3 -m http.server 8000`, then open
`http://localhost:8000/web/`.

The Mac launcher needs its executable bit. Committing with git keeps it
(`git update-index --chmod=+x "tools/Start sprite tools (Mac).command"`);
uploading through GitHub's web page drops it, and then macOS refuses to run
it (the tester instructions give the Terminal way round).

Pyodide comes from the jsDelivr CDN by default (about 13 MB on the first
visit, cached after that). To self-host it, put these files from the
matching Pyodide release (`pyodide-<version>.tar.bz2` on its GitHub
releases page) in `tools/web/pyodide/`; the page uses that folder when it
exists:

    pyodide.mjs  pyodide.asm.mjs  pyodide.asm.wasm  python_stdlib.zip
    pyodide-lock.json  pillow-*.whl

`tools/web/pyodide/` is git-ignored. The version is `PYODIDE_VERSION` at the
top of `app.js`.

## Testing
Tested with Pyodide 314.0.7 (Python 3.14, Pillow 12.2) in Chromium. Slice,
build, pack, transfer, convert and blank give byte-identical files to the
CLI on the same input, and a recipe made in the builder builds the same as
it does on the CLI.

## Next
- Running Python in a Web Worker, so the page doesn't pause during a
  command (each takes about a second now).
