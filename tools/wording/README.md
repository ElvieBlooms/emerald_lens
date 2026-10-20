# Emerald Lens wording tools

Tools for the gendered text tables, `wording_frlg.lua` and `wording_rse.lua`
(the code is `wording.lua`). They read files on your own machine only: a
pret disassembly you've cloned and your install's extracted text cache. The
game's text never goes in the repo; the tables hold a hash of each line and
the new words. Needs LuaJIT, plus Python 3 for `pret_strings.py`. Not
needed to play.

Run everything from the repo root.

## Paths you'll need
- **pret:** a clone of `pret/pokefirered`, `pret/pokeemerald` or
  `pret/pokeruby`.
- **The text cache** for a game: `scripts/text.lua` in that game's cache
  folder of your install (for example
  `pokemon-love2d/firered/…/gba/scripts/text.lua`).
- **Font widths**: `chrome/fonts/latin_widths.lua` in the same cache folder
  (FireRed/LeafGreen and Emerald; Ruby and Sapphire use `rs_latin_*`).
- **The engine**: `src/core/game3/scripting/text_ir.lua` from the game's
  `.love` (`pokemon-love2d/updates/gen1recomp-<version>.love` is a zip).

## Adding a line
1. Dump pret's strings (the `.out.lua` file holds game text; it's
   git-ignored):

   ```
   python3 tools/wording/pret_strings.py ~/pret/pokefirered frlg.out.lua
   ```

2. Find the line's pret label (search pret, e.g. for "grandson") and get its
   hash:

   ```
   luajit tools/wording/check.lua hash frlg.out.lua gOakSpeech_Text_WhatWasHisName
   ```

3. Add an entry to `wording_frlg.lua` or `wording_rse.lua`:

   ```lua
   { label = "gOakSpeech_Text_WhatWasHisName", hash = "3146bc49", who = "rival",
     girl = { { "grandson", "granddaughter" }, { "He's been", "She's been" } },
     enby = "This is my grandchild.\\pThey've been your rival since you\\nboth were babies.\\p…" },
   ```

   - `who`: `"player"` follows the gender picked in the save (an enby look
     always gets enby); `"rival"` follows the RIVAL LOOK.
   - Per mode (`girl`, `enby`, `boy`): a list of `{ from, to }` swaps, made
     in order, whole words only, within one line of text; or a whole line
     in pret form when the words have to move (`\\n`, `\\l`, `\\p`,
     `{PLAYER}`, `{RIVAL}`, `{STR_VAR_1}`). A mode that's left out keeps
     the game's line.
   - `games = { "emerald" }` (optional) limits it to some games, so the
     others don't log it as missing.

4. Check it against every game it's for. It shows how many places each
   line is found, the reworded lines, and their widths:

   ```
   TEXT_IR=<.love>/src/core/game3/scripting/text_ir.lua \
   WIDTHS=<firered cache>/chrome/fonts/latin_widths.lua \
     luajit tools/wording/check.lua entries frlg <firered cache>/scripts/text.lua <leafgreen cache>/scripts/text.lua
   ```

   A line marked **WIDE** is over 208 px, the text box's width. The message
   box wraps a long line onto the next page, but FR/LG's Oak intro doesn't
   wrap at all, so keep every line within 208 px.

## Checking the tools themselves
- `luajit tools/wording/check.lua verify <pret.out.lua> <cache text.lua> [<syms.lua>]`
  confirms pret's spelling hashes the same as the cache. For R/S/E, pass
  the engine's `src/import/gba/syms/<game>.lua` to line labels up with the
  cache. On the 0.3.91 caches every Emerald label matches; the FR/LG and
  R/S mismatches are help-screen glyphs and unused Japanese strings, not
  dialogue.
- `ENGINE=<unpacked .love> FRLG_TEXT=<firered cache>/scripts/text.lua luajit tools/wording/test_wording.lua`
  runs the headless tests: swaps, live switching, restoring, other mods'
  lines left alone, the picked gender, and the TEXT option.
  Add `RSE_TEXT=<emerald cache>/scripts/text.lua` and/or
  `RS_TEXT=<ruby cache>/scripts/text.lua` to also check that every
  `wording_rse.lua` entry is found and applies in those games.

If a line isn't found in game, the log says
`text: <label> isn't in this game's text`; if a swap's words aren't in the
line, `text: <label> has no "<words>"`, and the line stays the game's own.
