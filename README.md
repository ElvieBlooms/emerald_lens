# Emerald Lens
A player sprite mod for the Gen 3 games in gen1recomp: FireRed, LeafGreen, Ruby, Sapphire and Emerald.

<img width="960" height="641" alt="Kris" src="https://github.com/user-attachments/assets/ed42d94d-aaf5-41b7-b022-cbf9bb71f996" />
<img width="1022" height="676" alt="krisfrlgow1" src="https://github.com/user-attachments/assets/fc2a50e5-a031-4e75-b665-75286d963de0" />
<img width="989" height="657" alt="krisfrlgtc" src="https://github.com/user-attachments/assets/ad6a854c-98f5-4937-8445-572a1665de4d" />

Emerald Lens is the Gen 3 companion to [Crystal Lens](https://github.com/dburton95/crystal) and uses the same character folder format. Each mod reads only its own `assets/sprites` folder, but a character folder can be copied between them unchanged: Crystal Lens uses its Game Boy art and Emerald Lens uses its `gen3` art, so one folder can carry both and be copied into each mod. The two mods load on different games, so you can keep both enabled.

## Features
* Replaces the player everywhere Gen 3 draws them: walking, running, biking, surfing, fishing and other overworld poses, the battle back pic and throw, the front pic (Hall of Fame, battle intro), the trainer card, the new-game intro, the map icon, and riding the bird in FRLG's Fly.
* Per-character gender: replace the boy, the girl, or both.
* Falls back sheet by sheet: the selected look, then the same character's other looks, then the game's own sprite. Draw as much or as little as you like.
* Sprite tools to draw from the game's own sprites and pack your art (`tools/sprite-templates`).

## Adding a character
Each look is a folder at `assets/sprites/FOLDER_NAME_HERE` (no spaces in the folder name) with a `meta.json`, using the same keys as Crystal Lens:

```json
{
  "label": "KRIS",
  "character": "KRIS",
  "genderMode": "girl"
}
```

* `label` is the look's name in the options menu.
* `character` groups several looks under one **CHARACTER** entry; each look is then a **LOOK** choice. A folder without it is its own character.
* `genderMode` picks which player gets replaced:
  * `"girl"` replaces Leaf (FireRed/LeafGreen) or May (Ruby/Sapphire/Emerald).
  * `"boy"` replaces Red or Brendan.
  * `"enby"` replaces both, so the player looks like the character whichever gender is picked. Gen 3's text is the game's own for the gender picked. The Hoenn rival battles with the player's portrait and shares the fishing, underwater and watering sprites, so for those an enby character only takes the gender actually picked, and the rival stays themselves.
  
  Left out, it's `"girl"`, the same as Crystal Lens. The game still asks boy or girl at the start, so pick the one that matches your character (any choice works for enby).

Crystal Lens's other keys (`overworldColors`, `nameChoices`) are ignored here, so a folder copied from Crystal Lens works as-is once it has a `gen3` folder.

Gen 3 art goes in a `gen3` subfolder, one per game family, since their sheets are different sizes:

```
assets/sprites/<folder>/
  meta.json
  gen3/
    frlg/     FireRed and LeafGreen
    rse/      Ruby, Sapphire and Emerald
```

Only folders with a `gen3` folder show up as looks, but every folder of a character is used as a fallback. Options are read when the game starts, so a change needs a restart.

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
| `back.png` | 64x64, 5 frames (64x320) | 64x64, 4 frames (64x256) |
| `front.png` | 64x64 (also the trainer card) | 64x64 (also the trainer card and Birch intro) |
| `intro.png` | 64x96 (Oak intro) | -- |
| `mapIcon.png` | 16x16 (Town Map and Fly map) | 16x16 (region map, Fly, PokeNav and Pokedex area maps) |
| `flyBird.png` | 64x64, 2 frames (64x128): riding the bird as Fly takes off, then as it lands | -- (Hoenn draws the bird and player separately) |

Gen 3 sprites are always full color.

## Sprite tools
`tools/sprite-templates` has blank templates in two formats you can use interchangeably: one combined sheet per game family, laid out like the standard community sheets, or one strip per game sheet. `pack_gen3.py` exports the game's own sprites from your imported cache to draw from, converts between the two formats, and packs your art into a look's `gen3` folder. See its README. It needs Python 3 and Pillow, and isn't needed to play.

**Sheet Examples:**

**FR/LG**

<img width="500" height="298" alt="frlg_sheet" src="https://github.com/user-attachments/assets/a51981b9-997d-44f1-a1ff-abcb6020cf51" />

**R/S/E**

<img width="470" height="480" alt="rse_sheet" src="https://github.com/user-attachments/assets/d9d7a051-cd6e-4961-8dcd-4abde6fcd81a" />

## Not covered yet
* New-game name choices.
* Gender-neutral text (Gen 3 has none).
* In link battles, an opponent who picked a replaced gender also shows your character, since front pics are replaced by picture number.

## Credits
* Built on the Crystal Lens framework by Dgray66, used with permission.
* Gen 3 support: Elvie