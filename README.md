# Emerald Lens
A player sprite mod for the Gen 3 games in gen1recomp: FireRed, LeafGreen, Ruby, Sapphire and Emerald. Needs gen1recomp 0.3.93 or newer.

<img width="960" height="641" alt="Kris" src="https://github.com/user-attachments/assets/ed42d94d-aaf5-41b7-b022-cbf9bb71f996" />
<img width="1022" height="676" alt="krisfrlgow1" src="https://github.com/user-attachments/assets/fc2a50e5-a031-4e75-b665-75286d963de0" />
<img width="989" height="657" alt="krisfrlgtc" src="https://github.com/user-attachments/assets/ad6a854c-98f5-4937-8445-572a1665de4d" />

Emerald Lens is the Gen 3 companion to [Crystal Lens](https://github.com/dburton95/crystal) and uses the same character folder format. Each mod reads only its own `assets/sprites` folder, but a character folder can be copied between them unchanged: Crystal Lens uses its Game Boy art and Emerald Lens uses its `gen3` art, so one folder can carry both and be copied into each mod. A folder with only Game Boy art works here too, as a Game Boy look (see **Game Boy looks** below). The two mods load on different games, so you can keep both enabled.

## Features
* Replaces the player everywhere Gen 3 draws them: walking, running, biking, surfing, fishing and other overworld poses, the battle back pic and throw, the front pic (Hall of Fame, battle intro), the trainer card, the new-game intro, the map icon, and riding the bird in FRLG's Fly.
* Optional extras: the surf blob, the Fly bird and the Bag, plus a dive blob for Ruby/Sapphire/Emerald, which the games don't have.
* Pick a character for FireRed/LeafGreen and for Ruby/Sapphire/Emerald separately, so a character only needs art for one of them.
* Per-character gender: replace the boy, the girl, or both, or set **GENDER** to **MY SAVE** to use any look on whichever save you have.
* A **LENS** screen on the START menu and the OPTION menu: pick your character, look, rival and text with a preview of the look (see **The LENS screen** below).
* A rival of your choosing: any character can stand in for Blue, or for May/Brendan, with the rival's own looks and fallback (see **The rival** below).
* Gendered text follows your characters: girl or they/them wording where the game assumes a gender, for the player and the rival (see **Text** below).
* Game Boy looks: drop in a folder from Crystal Lens and its battle art is used as it is; Red's, Gold's and Kris's Game Boy walking and biking sprites come from your own copies of those games (see **Game Boy looks** below).
* Falls back sheet by sheet: the selected look, then the same character's other looks of the same generation, then its other looks, closest generation first, then the game's own sprite. Draw as much or as little as you like.
* Sprite tools to draw from the game's own sprites and pack your art (`tools/sprite-templates`).

## Adding a character
Each look is a folder at `assets/sprites/FOLDER_NAME_HERE` (no spaces in the folder name) with a `meta.json`, using the same keys as Crystal Lens:

```json
{
  "label": "KRIS",
  "character": "KRIS",
  "genderMode": "girl",
  "credit": ["RSE by richardPT", "FRLG by FourLeafSunny"]
}
```

* `label` is the look's name in the options menu.
* `character` groups several looks under one character; each look is then a **LOOK** choice. A folder without it is its own character.
* `genderMode` picks which player gets replaced:
  * `"girl"` replaces Leaf (FireRed/LeafGreen) or May (Ruby/Sapphire/Emerald).
  * `"boy"` replaces Red or Brendan.
  * `"enby"` replaces both, so the player looks like the character whichever gender is picked, and with **TEXT** on the game's gendered lines use they/them wording. The Hoenn rival battles with the player's portrait and shares the fishing, underwater and watering sprites, so for those an enby character only takes the gender actually picked, and the rival stays themselves.
  * Players don't need to edit this to use a look on the other gender's save: **GENDER** in the options (or on the LENS screen) set to **MY SAVE** does that (see the options below).
  
  Left out, it's `"girl"`, the same as Crystal Lens. The game still asks boy or girl at the start, so pick the one that matches your character (any choice works for enby).
* `generation` (optional) is `3` for art in the games' own style or `4` for bigger DS-style art (HGSS/DPPt sprites, usually on the 32-wide sheets). It only decides fallback order: a missing sheet is taken from the character's looks of the same generation first, then from its other looks, so a Gen 4 look borrows from other Gen 4 looks before Gen 3 ones. Left out, it's `3`. Game Boy looks count as `2` (or `1`, if you set it).
* `nameChoices` (optional) is Crystal Lens's list of name choices. Emerald Lens uses the first one as the rival's name in Ruby/Sapphire/Emerald (see **The rival**); left out, the rival takes the character's name. Gen 3 names are 7 letters at most, so a longer one is cut.
* `credit` (optional) names the artists, as a list of lines. The LENS screen shows it under the look and in full on its CREDITS page; it also keeps the credit with the art wherever the folder is copied. Please fill it in when you share a look made from someone else's sprites.

Keep `meta.json` valid JSON: a trailing comma after the last item (`"...",]`) makes it unreadable, and the look falls back to its folder name and `"girl"`.

A folder copied from Crystal Lens works as-is: with a `gen3` folder it's a normal look, and without one it's a Game Boy look.

Gen 3 art goes in a `gen3` subfolder, one per game family, since their sheets are different sizes:

```
assets/sprites/<folder>/
  meta.json
  gen3/
    frlg/     FireRed and LeafGreen
    rse/      Ruby, Sapphire and Emerald
```

The options menu has a section for each family, **FR/LG** and **R/S/E**, each with a **CHARACTER** choice, a **LOOK** choice when that character has more than one look, and **GENDER**: the selected look's own gender (**GIRL**, **BOY** or **ENBY**, both), or **MY SAVE**, where the look replaces whichever player your save picked, so a girl look like KRIS shows on a Brendan save without editing `meta.json`. MY SAVE only changes the sprites: the text still follows the look's `genderMode` (girl and boy looks keep the game's own text), and before there's a save the look stands in for both, as an enby look does. It's one setting per family, kept when you change character or look. A look only shows up for a family it has a folder for, so a character drawn for just FireRed/LeafGreen is only offered there, and you can use different characters for each. Pick **OFF** to keep a family's own player. Under the rival rows, **TEXT** turns the gendered text on or off (see **Text** below).

### The rival
Under GENDER, **RIVAL** picks a character for your rival, with **RIVAL LOOK** when it has more than one look. It can be any character, the same one as the player too, and it falls back sheet by sheet like the player does. **OFF** (the default) keeps the game's own rival.

* **Ruby/Sapphire/Emerald:** the rival is whoever you didn't pick (May when you play Brendan, and the other way round), so the rival character takes that gender: walking, Mach and Acro Bike, surfing and field moves (from `walk.png`, `bike.png`, `acroBike.png`, `surf.png`, `fieldMove.png`), and the battle pic (`front.png`). The look's `genderMode` doesn't matter for the art (the text follows it). With **TEXT** on, the rival is also called by the look's name instead of MAY or BRENDAN: in what they say, in `{RIVAL}`, on the POKéNAV and in battle. The name is the look's first `nameChoices` entry, or else the character's name. Before there's a save the rival isn't shown.
* **FireRed/LeafGreen:** the rival character stands in for Blue: walking (the first 9 frames of `walk.png`; Blue doesn't run, bike or surf), Oak's intro (`intro.png`) and his three battle pics. Each pic has its own optional file, `rivalEarly.png`, `rivalLate.png` and `rivalChampion.png` (64x64), and falls back to the look's `front.png` when it's missing.

Your own character's art only replaces the gender you picked once there's a save, so with RIVAL off the Hoenn rival is always the game's own, battle pic included.

A boy or girl character only replaces that player unless GENDER is MY SAVE, so the menu ends with a reminder: **GENDER MY SAVE: FITS EITHER SAVE**. Enby characters replace either player. (The section names and the reminder can be selected but don't do anything; the game's mod options don't have rows the cursor skips.)

### The LENS screen
The same choices for the game you're playing are on a screen of their own: **LENS** on the START menu (above MODS, or EXIT), and **EMERALD LENS** on the OPTION menu, which also works from the Ruby/Sapphire/Emerald title screen. With Facets installed too, the two share one item instead: **PRISM**, on both menus, opens a short list (EMERALD LENS, with your character, and FACETS, with your NPC set), and picking one opens its screen; B there comes back to the list. Each mod has its own gem in the list (emerald for Emerald Lens, amethyst for Facets); the header takes the picked one's colour, and a faceted corner in the same colour shows what it's doing right now: your character, or a Pokémon and an NPC from Facets' sets. Each mod still works on its own. Up and down pick a row, left and right (or A) change it, and B closes it. Changes apply straight away, the same as in the mod options, and are saved to the same settings.

* **CHARACTER**, **LOOK**, **GENDER** (not for enby looks, which fit either save already), **RIVAL**, **RIVAL LOOK** (when a rival is set) and **TEXT**, for the running family only, then **CREDITS**.
* A preview of the look: its `front.png` (FR/LG rivals: `rivalEarly.png`, else `front.png`) and a walking sprite from `walk.png`, found through the same fallback chain the game uses. The player rows show the player, the rival rows the rival.
* Under the rows: who the look replaces (with GENDER on MY SAVE, whoever your save picked), a red **Not shown** line when the save is the other gender (set GENDER to MY SAVE to fix it), what the rival stands in for (and, with TEXT on, what it's called), and as much of the look's `credit` as fits.
* **CREDITS** (press A) opens a page with every credit in full: your look, the rival's, every other look offered for this game, and the mod's own. Up and down scroll, left and right turn a page, B goes back.

The mod options still have every row for both families.

### Text
With **TEXT** on (the default), lines that assume the player's or the rival's gender are reworded to match your characters:

* **The player:** the games already have both a boy and a girl version of most lines and use the one for the gender you picked, the same gender your character's art replaces. A girl or boy character keeps that. An enby character gets they/them wording whichever gender you picked. Lines the game says to everyone that assume a gender are reworded for the gender you picked too. With CHARACTER off, the player's lines stay the game's own.
* **The rival:** lines about the rival follow the RIVAL LOOK's `genderMode`. In FireRed/LeafGreen, Oak's intro introduces a girl rival as his granddaughter and an enby rival as his grandchild, Daisy calls them her sister or sibling, and Lance says she or they. With RIVAL off, the rival's lines stay the game's own.

FireRed/LeafGreen is covered: Oak's intro, Daisy and Lance on the rival; Mom, the Safari Zone warden, Bill, the S.S. Anne, Silph's president and a few others on the player (they/them wording for enby characters, where the game has a boy and a girl version); and bikers' "…, man" dropped for girls and enby. Ruby/Sapphire/Emerald needs much less, since the games already talk about May and Brendan as "my kid" and "our child": Brendan meeting an enby player who picked the girl, the Dewford Hall man's "chap", and the rival's mom, who says son, daughter or kid to match the RIVAL LOOK. In every game, an enby character also gets "Which would you like to be?" instead of "Are you a boy? Or are you a girl?" before the BOY/GIRL choice. Changes apply straight away (a message already on screen keeps its text). Each line is found by its own text, so it works the same in every version of a game, and a line another mod has changed, such as a translation, stays theirs.

Every folder of a character is still used as a fallback, in this order: the selected look, the character's other looks of the same `generation`, then its other looks (Gen 3 and Gen 4 looks before Game Boy ones, and the other way round for a Game Boy look, then the closest generation first, menu order within each), then the game's own sprite.

### Game Boy looks
A folder with no `gen3` folder for a game family, but with Crystal Lens's Game Boy art, is a Game Boy look there. Nothing is converted on disk, so the folder stays exactly as Crystal Lens reads it and can be copied back and forth. What it supplies:

* **Front pic** (`front.png`, and the FR/LG Oak intro) from `frontColor.png`, or `front.png` if there's no colour version. Gen 3 is always in colour, so the colour file comes first. It's drawn at its own size, centred, feet on the bottom edge: a 56x56 Game Boy pic sits in the 64x64 Gen 3 frame the way it does on a Game Boy.
* **Back pic** (`back.png`) from `backColor.png` or `back.png`, the same way. A taller pic, like Crystal Lens's full-body backs, keeps its top 64 rows (the game's log says so once). Game Boy backs have no throw, so every throw frame is the still pic.
* **Walking and biking** from the folder's own `overworldWalk.png` and `overworldBike.png` (Crystal Lens's 16x96 files, coloured with its `overworldColors`), or with `romOverworld` (below) from your own game. The six Game Boy frames are laid out on the Gen 3 sheets, at their own size, standing on the game's feet rows; steps mirror the way they do on a Game Boy.
* **Surfing**: the folder's own `overworldSurf.png` (Emerald Lens only: 16x96, the six Game Boy frames like `overworldWalk.png`, of whatever shows while you surf, coloured the same way) for surfing and diving. Otherwise, with `romOverworld`, the Game Boy games show only the Pokémon you surf on, so that's what you get: Gen 1's Seel for Red and Blue, Gold/Silver/Crystal's Lapras for Gold and Kris. The Gen 3 surf blob under it is left out. In Ruby/Sapphire/Emerald, Red and Blue dive on Seel too, and Gold and Kris dive on Seel while surfing on Lapras (Seel comes from Red, Blue or Yellow; without one of those they dive on Lapras).
* **Fishing**: the Game Boy pose, the standing sprite's top half over a fishing bottom half, and the rod beside it. The bottom halves are Crystal Lens's `overworldFishFront.png`, `overworldFishBack.png` and `overworldFishSide.png` (16x8 each); the rod is `overworldFishRod.png` (Emerald Lens only: 8x16, the rod tile for facing down and up, then the one for facing left, placed as Gen 1 places its rod). Any of these the folder doesn't have comes from your own game, through the engine's `mod.datasets`: the `romOverworld` trainer's (Red and Blue from Red, Blue or Yellow; Gold and Kris from Gold/Silver/Crystal, which needs gen1recomp 0.3.97 or newer), or Red, Blue or Yellow's for any other look. A look with a walk but no way to complete the pose fishes with its other looks' art. Facing down, the rod hangs below the player's tile, as on the Game Boy.
* Everything else (the trainer card's other art and so on) falls back as usual: to the character's other looks, then the game's own sprite.

`romOverworld` (optional, Emerald Lens only; Crystal Lens ignores it) is `"red"`, `"blue"`, `"gold"` or `"kris"`. It takes that trainer's Game Boy walking, biking and surfing sprites from your own installed copy of the game, through the engine's Union Room sprite loader: Red from Red, Blue or Yellow; Blue, the rival, from Red, Blue or Yellow (or Gold, Silver or Crystal, where he's the Viridian Gym Leader; Blue has no bike sprite); Gold from Gold, Silver or Crystal; Kris from Crystal. Nothing is shipped, so if you haven't imported that game yet the look falls back as usual (the game's log says which game it needs). Gold/Silver/Crystal's sprites use their own colours; Gen 1's get Gen 2's (red for Red and Blue, blue for Seel). `overworldColors` overrides the trainer's colours, not the Pokémon's. A folder with only a `meta.json` and `romOverworld` is a look too: that's how **RED**, and the **GAME BOY** looks of **GOLD** and **GARY**, work.

The sprite tools website makes Game Boy looks too: pick **Game Boy** as the look's generation in step 4, add the Crystal Lens files and, if you like, a game to take the sprites from. To draw them, or import them from another sheet, step 2 and 3 have a **Game Boy** family with its own sheet (`tools/sprite-templates/gb_sheet.png`): front, back, trainer card, walk, bike, surf, the three fishing halves and the rod.

A Game Boy look is never a character's default look when the character has Gen 3 or Gen 4 art, so adding one doesn't change what you already picked. The LENS screen says **Game Boy art.** under one.


Changing a character or look applies straight away, no restart needed: the player changes as soon as you're back in the game. The one exception is the FireRed/LeafGreen trainer card, which keeps the portrait it first loaded until the game restarts. Adding or editing files in a character folder still needs a restart.

Updating from 0.1.5 or earlier, your old character choice carries over to both families, wherever that character has art.

Updating from 0.3.0, copy the new files over the old `emerald_lens` folder; no looks moved. The new **RIVAL** rows start **OFF** and **TEXT** starts **ON**, so nothing changes until you pick a rival, apart from the wording for your own character.

## Sheet sizes
Every file is optional. Each one is looked for in the selected look's folder, then the character's other folders (in menu order), then the game's own sprite. A file that isn't exactly the right size is skipped and logged to the console, and the next folder is tried.

Each sheet is one vertical strip of frames, in the game's own order:

| File | FireRed/LeafGreen | Ruby/Sapphire/Emerald |
|---|---|---|
| `walk.png` | 16x32, 20 frames (16x640) | 16x32, 18 frames (16x576) |
| `bike.png` | 32x32, 9 frames (32x288) | 32x32, 9 frames (Mach Bike) |
| `acroBike.png` | -- | 32x32, 27 frames (32x864) |
| `surf.png` | 16x32, 12 frames (16x384) | 32x32, 12 frames (32x384) |
| `fieldMove.png` | 16x32, 9 frames (16x288) | 32x32, 5 frames (32x160) |
| `fishing.png` | 32x32, 12 frames (32x384) | 32x32, 12 frames (32x384) |
| `vsSeekerBike.png` | 32x32, 6 frames (32x192) | -- |
| `underwater.png` | -- | 32x32, 9 frames (32x288) |
| `watering.png` | -- | 32x32, 9 frames (32x288) |
| `decorating.png` | -- | 16x32, 1 frame (16x32) |
| `back.png` | 64x64, 5 frames (64x320): standing first, then the throw | 64x64, 4 frames (64x256): the throw first, standing **last** |
| `front.png` | 64x64 (also the trainer card) | 64x64 (also the trainer card and Birch intro) |
| `intro.png` | 64x96 (Oak intro) | -- |
| `mapIcon.png` | 16x16 (Town Map and Fly map) | 16x16 (region map, Fly, PokeNav and Pokedex area maps) |
| `flyBird.png` | 64x64, 2 frames (64x128): riding the bird as Fly takes off, then as it lands | -- (Hoenn draws the bird and player separately) |
| `rivalEarly.png`, `rivalLate.png`, `rivalChampion.png` | 64x64 each, only when the look is the rival (see The rival); each falls back to `front.png` | -- |

Gen 3 sprites are always full color.

In `walk.png`, draw the standing frames with the feet one row above the bottom and the steps a row lower, as the game does, or the walk won't bob like everyone else's (`pack_gen3.py feet` checks and fixes this, and where every other sheet's frames sit; see the tools README).

The 16-wide sheets (`walk.png`, `decorating.png`, and FRLG's `surf.png` and `fieldMove.png`) can also be drawn 32 wide, for characters bigger than the game's own, such as Gen 4 sprites. The game draws them centred on the tile with the feet on its bottom edge, so they just stand a little wider. Any other size is still skipped.

### Extras
Also optional, in the same folders and with the same fallback. They aren't the player, but the game only draws them for the player:

| File | FireRed/LeafGreen | Ruby/Sapphire/Emerald |
|---|---|---|
| `surfBlob.png` | 32x32, 6 frames (32x192): down, up, left, two bob frames each | 32x32, 3 frames (32x96): down, up, left |
| `bird.png` | 64x64 (the bird alone as it flies in and away; `flyBird.png` has the rider frames) | 32x32 (the bird the player rides) |
| `bag.png` | 64x64, 4 frames (64x256), one per pocket | 64x64, 6 frames (64x384), one per pocket |
| `diveBlob.png` | -- | 32x32, 3 frames (32x96): down, up, left |

The games have no dive blob: their diver's Pokémon is drawn into the `underwater.png` frames. With a `diveBlob.png`, Emerald Lens puts it behind your underwater frames, where the surf blob goes, and it bobs along with the diver, so `underwater.png` can be the player alone (a free-floating diver, or surf-style sitting frames). It's only used with the `underwater.png` from its own folder, never borrowed by another look (whose divers may already carry their Pokémon) or put behind the game's own diver. Looks that share diver-alone art each need the `diveBlob.png` too. The sprite tools can make both from a look's surf art (see their README).

The surf blob and bird have no boy or girl version, so they're only used when your character is the player in that save: a girl character's surf blob doesn't show for someone playing as the boy (enby, or GENDER on MY SAVE, works for either). The bag has one each, so it follows `genderMode` like the sprites.

## Sprite tools
`tools/sprite-templates` has blank templates in two formats you can use interchangeably: one combined sheet per game family, laid out like the standard community sheets, or one strip per game sheet. The extras have a smaller sheet of their own (`frlg_extras.png`, `rse_extras.png`). `pack_gen3.py` exports the game's own sprites from your imported cache to draw from, converts between the two formats, and packs your art into a look's `gen3` folder. `import_sheet.py` turns a sprite sheet made for something else (a fan game, a community collage) into our sheets. See its README. It needs Python 3 and Pillow, and isn't needed to play. The same tools also run as a web page in `tools/web`, with nothing to install: number a sheet's sprites, fill in the recipe by clicking them into the game's frames, build and pack it, watch it walk, run, surf and dive (and save that as a GIF to share), add ready-made surf and dive blobs, seat the look's rider on a ready-made Fly bird, combine partial sheets, and download a ready look folder. For now it runs on your own computer only: download `emerald_lens_tools-<version>.zip` from the [releases](https://github.com/ElvieBlooms/emerald_lens/releases) (the same files as `tools/` here; the mod zip doesn't include them) and double-click the launcher for your system (see `HOW TO TRY THE SPRITE TOOLS.txt`). A hosted version will follow once it's had some testing.

**Sheet Examples:**

**FR/LG**

<img width="500" height="378" alt="frlg_sheet" src="https://github.com/user-attachments/assets/a8ac5db8-e3b7-4a88-80cb-4164e082b5f8" /><img width="500" height="138" alt="frlg_extras" src="https://github.com/user-attachments/assets/d09a906e-c4a4-469e-a6ab-72c3653092c2" />

**R/S/E**

<img width="470" height="480" alt="rse_sheet" src="https://github.com/user-attachments/assets/d9d7a051-cd6e-4961-8dcd-4abde6fcd81a" /><img width="470" height="169" alt="rse_extras" src="https://github.com/user-attachments/assets/4decd6a4-f0e7-4d31-b0c0-cce6f22fdb3d" />

## Text tools
`tools/wording` checks the gendered text tables against your own install: it finds each line in your game's text cache, prints the reworded lines and measures them in pixels against the text box. It needs LuaJIT (and Python 3 for the pret helper), and isn't needed to play. See its README. The game's own text never goes in the repo; the tables only hold a hash of each line plus the new words.

## Not covered yet
* New-game name choices.
* In link battles, an opponent who picked a replaced gender also shows your character, since front pics are replaced by picture number.

## Credits
* Built on the Crystal Lens framework by Dgray66, used with permission. The gendered text follows Crystal Lens's girl and enby text modes.
* Gen 3 support: Elvie
* AANG: made by iamtrine, commissioned by Slawter666; front and back pics by waterpixelart
* ASH (ASH, BACK CAP, HATLESS): shared by kalarie on [PokeCommunity](https://www.pokecommunity.com/threads/looking-for-trainer-overworld-sprites-of-jesse-james.404892/post-9821260); original artist not named; HGSS (Gen 4 style) by PKMNTrainerRick
* BRENDAN: ORAS BRENDAN and SKATEBOARD from Team Aqua's Asset Repo; HGSS (Gen 4 style) by DiegoWT
* GARY (KANTO): by Alan_Flygon
* GOLD: R/S/E sprites from Team Aqua's Asset Repo, FR/LG sprites by FourLeafSunny; HGSS (Gen 4 style) by GregarLink10
* GREEN (BIG PUFF): sprites compiled from virdiangrass and Team Aqua's Asset Repo; additional edits and AcroJiggly by Elvie
* GREEN (GREEN): by LouLilie
* GREEN (HGSS, Gen 4 style): compiled by ChromeValiant; art by Poltergeist/Coffee Cup, Mid117, Wolfang62 and aethestode
* KRIS: R/S/E sprites by richardPT, FR/LG sprites by FourLeafSunny; KRIS BLUE edits by eykav
* KRIS: LOULILIE, PKATHLON and ROCKET (Gen 4 style) by LouLilie
* KRIS Game Boy looks, from [Crystal Lens](https://github.com/dburton95/crystal): ARALE by Amanda Arale-Chan, DARIO by DarioMelo, ROCKET A, ROCKET B and SYGNA (with their ZOOM backs) by Elvie
* RED, and the GAME BOY looks of GOLD and GARY: read from your own games, nothing shipped
* MAY: ORAS MAY and SKATEBOARD from Team Aqua's Asset Repo; HGSS (Gen 4 style) by DiegoWT
