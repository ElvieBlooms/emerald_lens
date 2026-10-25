-- Game Boy looks
-- A folder copied from Crystal Lens, with no gen3/ art for the running
-- game family, still works here: its art is fitted into the Gen 3 sizes
-- when the game asks for it. Nothing is written to disk, so the folder
-- stays exactly as Crystal Lens reads it. -Elvie
--
-- Such a folder's base is the folder itself (assets/sprites/<key>/),
-- where a Gen 3 look's is <key>/gen3/<family>/, which is how a base is
-- told apart. lens.lua registers each one with its meta.json. -Elvie
--
-- Overworld: the folder's own overworldWalk.png / overworldBike.png
-- (Crystal Lens's files), or with "romOverworld" in meta.json ("red",
-- "blue", "gold" or "kris"), that trainer's sprites from the player's own
-- installed Gen 1 or Gen 2 game, through the engine's Union Room avatar
-- loader (which reads other games' sprites for online play). Nintendo's
-- art is never shipped. -Elvie
--
-- Surfing: the Game Boy games show only the Pokémon (Gen 1's Seel, Gen
-- 2's Lapras), so with romOverworld that's surf.png, and the Gen 3 surf
-- blob under it is left out. R/S/E diving (underwater.png) uses the same
-- Pokémon, except Gold and Kris dive on Gen 1's Seel. A folder's own
-- overworldSurf.png (16x96, like overworldWalk.png; Emerald Lens only)
-- wins over the game's, for surfing and diving. -Elvie
--
-- Fishing: Crystal Lens's overworldFishFront/Back/Side.png (16x8, the
-- pose under the standing frame's top half) win over the game's, facing
-- by facing, and overworldFishRod.png (8x16: the rod tile for down and
-- up, then the one for left, drawn as Gen 1's; Emerald Lens only) over
-- the game's rod. -Elvie
-- --------------------------------------------------

local gameboy = {}

local unpack = table.unpack or unpack

-- Battle pics: the Gen 3 file each one makes, and the Crystal Lens files
-- it's made from, colour first (the Gen 3 games are always in colour). -Elvie
local SOURCES = {
  ["front.png"] = { "frontColor.png", "front.png" },
  ["back.png"] = { "backColor.png", "back.png" },
  ["intro.png"] = { "frontColor.png", "front.png" },
}
local SIZE = {
  ["front.png"] = { 64, 64 },
  ["back.png"] = { 64, 64 },
  ["intro.png"] = { 64, 96 },
}
-- Back pic frames per family: FR/LG idle + 4 throw, R/S/E 3 throw + idle.
-- Game Boy backs have no throw, so every frame is the same pic. -Elvie
local BACK_FRAMES = { frlg = 5, rse = 4 }

-- Overworld sheets, from 16x16 frames in the Game Boy order: stand down,
-- up, left, then step down, up, left. -Elvie
local OW_FILES = {
  ["walk.png"] = "overworldWalk.png",
  ["bike.png"] = "overworldBike.png",
}
-- A folder's own file for each kind of Game Boy sheet -Elvie
local OWN_OF = { walk = "overworldWalk.png", bike = "overworldBike.png",
  surf = "overworldSurf.png", dive = "overworldSurf.png" }
local OWN_FISH = { down = "overworldFishFront.png", up = "overworldFishBack.png", left = "overworldFishSide.png" }
local OWN_ROD = "overworldFishRod.png"
-- Each trainer's sprites: per kind, { games, sprite id, colours for a
-- game with none } in order; the first installed game is used. -Elvie
-- pokered/data/sprites/sprites.asm, pokecrystal/data/sprites/sprites.asm
-- and player_sprites.asm
local GEN1, GEN2 = { "red", "blue", "yellow" }, { "gold", "silver", "crystal" }
local ROM = {
  red  = { walk = { { GEN1, "SPRITE_RED", "red" } }, bike = { { GEN1, "SPRITE_RED_BIKE", "red" } },
           surf = { { GEN1, "SPRITE_SEEL", "blue" } } },
  -- the rival in Gen 1, the Viridian Gym Leader in Gen 2; no bike -Elvie
  blue = { walk = { { GEN1, "SPRITE_BLUE", "red" }, { GEN2, "SPRITE_BLUE", "red" } },
           surf = { { GEN1, "SPRITE_SEEL", "blue" } } },
  -- surf on Lapras, dive on Gen 1's Seel (Lapras without a Gen 1 game) -Elvie
  gold = { walk = { { GEN2, "SPRITE_CHRIS", "red" } }, bike = { { GEN2, "SPRITE_CHRIS_BIKE", "red" } },
           surf = { { GEN2, "SPRITE_SURF", "blue" } },
           dive = { { GEN1, "SPRITE_SEEL", "blue" }, { GEN2, "SPRITE_SURF", "blue" } } },
  kris = { walk = { { { "crystal" }, "SPRITE_KRIS", "blue" } }, bike = { { { "crystal" }, "SPRITE_KRIS_BIKE", "blue" } },
           surf = { { GEN2, "SPRITE_SURF", "blue" } },
           dive = { { GEN1, "SPRITE_SEEL", "blue" }, { GEN2, "SPRITE_SURF", "blue" } } },
}
-- The sprite kind each mount file reads: diving has its own where a
-- trainer lists one, else it's the surf Pokémon. -Elvie
local function mountKind(which, file)
  if file == "underwater.png" and ROM[which] and ROM[which].dive then return "dive" end
  return "surf"
end
-- Gen 2 sprites come with the game's own colours. Gen 1's are grey, so
-- they get Gen 2's: pokecrystal/gfx/overworld/npc_sprites.pal, day,
-- PAL_OW_RED and PAL_OW_BLUE, as the engine draws them (the same values
-- Facets uses). Shade 0 is see-through. -Elvie
local PALETTES = {
  red  = { { 222, 255, 222 }, { 255, 156, 82 }, { 255, 58, 8 }, { 0, 0, 0 } },
  blue = { { 222, 255, 222 }, { 255, 156, 82 }, { 82, 74, 255 }, { 0, 0, 0 } },
}
-- Crystal Lens's own overworld colours, for a folder's overworld files. -Elvie
local CRYSTAL_COLORS = { { 255, 255, 255 }, { 255, 173, 99 }, { 1, 99, 198 }, { 0, 0, 0 } }

-- Each Gen 3 frame: { Game Boy frame, mirrored, step }. Steps sit a row
-- lower than standing, like the game's own. Down and up step between a
-- walk frame and its mirror. Gen 3 plays stand, step, stand, step, so
-- both left steps are the walk frame; a stand frame there skips a step.
-- Right is left, mirrored by the game. -Elvie
local S, U, L, SD, SU, SL = 0, 1, 2, 3, 4, 5
local WALK = { { S }, { U }, { L }, { SD, false, true }, { SD, true, true }, { SU, false, true },
  { SU, true, true }, { SL, false, true }, { SL, false, true } }
local LAYOUT = {
  -- FR/LG: walk, then running by facing (stand, step, step), then 2 more -Elvie
  frlg = { 20, { { S }, { SD, false, true }, { SD, true, true }, { U }, { SU, false, true }, { SU, true, true },
    { L }, { SL, false, true }, { SL, false, true }, { S }, { SD, false, true } } },
  -- R/S/E: walk, then running in the walk order -Elvie
  rse = { 18, WALK },
}
local STAND_ROW, BIKE_ROW = 30, 31 -- the game's feet rows (pack_gen3 GAME_FEET) -Elvie
-- Surf and underwater: 0-8 like walking, FR/LG and R/S/E surf's 9-11 one
-- per facing. The Pokémon fills the tile the player stands on: the
-- bottom 16 rows, centred. Surf blob sizes, to leave it out. -Elvie
local MOUNT = { ["surf.png"] = { frlg = { 16, 12 }, rse = { 32, 12 } }, ["underwater.png"] = { rse = { 32, 9 } } }
local MOUNT_EXTRA = { { S }, { U }, { L } }
local BLOB = { frlg = 6, rse = 3 }

local registered = {} -- [base] = meta -Elvie
local warned = {}
local romCache = {} -- ["kris|walk"] = { grey ImageData, the game's colours } or false -Elvie
local fromRom -- below; gameboy.has asks it whether a game has a sprite -Elvie
local FISH, fishParts -- below, with fishing -Elvie

local function engine(name)
  local ok, m = pcall(require, name)
  return ok and m or nil
end

local function note(mod, key, fmt, ...)
  if warned[key] then return end
  warned[key] = true
  mod.log:info(fmt, ...)
end

function gameboy.isBase(base)
  return type(base) == "string" and not base:find("/gen3/", 1, true)
end

function gameboy.register(base, meta)
  registered[base] = type(meta) == "table" and meta or {}
end

local function romOf(meta)
  local which = type(meta) == "table" and type(meta.romOverworld) == "string" and meta.romOverworld:lower()
  return which and ROM[which] and which or nil
end
gameboy.romOf = romOf

-- What makes a folder a Game Boy look: Crystal Lens battle art, its
-- overworld files, or a romOverworld. -Elvie
local ART = { "front.png", "frontColor.png", "back.png", "backColor.png", "overworldWalk.png", "overworldBike.png",
  "overworldSurf.png" }
function gameboy.hasArt(mod, base, meta)
  if romOf(meta) then return true end
  for _, name in ipairs(ART) do
    if mod.assets:info(base .. name) then return true end
  end
  return false
end

local function sourceOf(mod, base, file)
  for _, name in ipairs(SOURCES[file] or {}) do
    if mod.assets:info(base .. name) then return base .. name end
  end
  return nil
end

local function colorsOf(meta, fallback)
  local c = type(meta) == "table" and meta.overworldColors
  if type(c) == "table" and #c == 4 then
    for _, t in ipairs(c) do
      if type(t) ~= "table" or #t ~= 3 then return fallback end
      for _, v in ipairs(t) do if type(v) ~= "number" then return fallback end end
    end
    return c
  end
  return fallback
end

function gameboy.has(mod, base, file)
  if SOURCES[file] then return sourceOf(mod, base, file) ~= nil end
  local which = romOf(registered[base])
  -- surf art and the left-out blob only with something to surf on -Elvie
  if MOUNT[file] or file == "surfBlob.png" then
    if mod.assets:info(base .. OWN_OF.surf) then return true end
    return which ~= nil and fromRom(mod, which, mountKind(which, file)) ~= nil
  end
  if file == "fishing.png" then
    local walk = mod.assets:info(base .. OWN_OF.walk) or (which ~= nil and fromRom(mod, which, "walk") ~= nil)
    return walk and fishParts(mod, base) ~= nil
  end
  local own = OW_FILES[file]
  if not own then return false end
  if mod.assets:info(base .. own) then return true end
  return which ~= nil and fromRom(mod, which, file:sub(1, 4)) ~= nil
end

-- The pic in a w x h box: centred across, feet on the bottom edge. A
-- taller pic keeps its top rows, the way Gen 3 back pics stop at the
-- waist; a wider one keeps its middle. -Elvie
local function fit(mod, src, rel, w, h)
  local sw, sh = src:getDimensions()
  local cw, ch = math.min(sw, w), math.min(sh, h)
  if sw > w or sh > h then
    note(mod, rel .. w .. "x" .. h, "%s is %dx%d; the Gen 3 %dx%d pic shows %s", rel, sw, sh, w, h,
      sh > h and ("its top " .. h .. " rows") or ("its middle " .. w .. " columns"))
  end
  local out = love.image.newImageData(w, h)
  out:paste(src, math.floor((w - cw) / 2), h - ch, math.floor((sw - cw) / 2), 0, cw, ch)
  return out
end

-- Game Boy art comes in four shades. The game's own cache is grey, so
-- the shade is read off the red channel (as the Union Room does); a
-- Crystal Lens file may be tinted, so its colours are ranked by
-- brightness instead. Shade 0, or a see-through pixel, stays see-through. -Elvie
local function greyShade(r)
  if r > 0.83 then return 0 end
  if r > 0.5 then return 1 end
  if r > 0.17 then return 2 end
  return 3
end

-- datas: one ImageData, or a list ranked together (a folder's walk and
-- fishing files, so their shades agree). -Elvie
local function rankedShades(datas)
  if type(datas) ~= "table" then datas = { datas } end
  local seen, list, clear = {}, {}, false
  for _, data in ipairs(datas) do
    data:mapPixel(function(_, _, r, g, b, a)
      if a < 0.5 then clear = true
      else
        local key = math.floor(r * 255) * 65536 + math.floor(g * 255) * 256 + math.floor(b * 255)
        if not seen[key] then
          seen[key] = 0.299 * r + 0.587 * g + 0.114 * b
          list[#list + 1] = key
        end
      end
      return r, g, b, a
    end)
  end
  table.sort(list, function(x, y) return seen[x] > seen[y] end)
  local shade = {}
  -- with no see-through pixels, the lightest colour is the backdrop -Elvie
  local first = clear and 1 or 0
  for i, key in ipairs(list) do shade[key] = math.min(3, first + i - 1) end
  return function(r, g, b)
    return shade[math.floor(r * 255) * 65536 + math.floor(g * 255) * 256 + math.floor(b * 255)] or 3
  end
end

-- ranked: true to rank this picture's own colours, a shade function
-- from rankedShades, or false for the game's grey. -Elvie
local function colourise(data, colors, ranked)
  local shadeOf = type(ranked) == "function" and ranked or ranked and rankedShades(data)
    or function(r) return greyShade(r) end
  data:mapPixel(function(_, _, r, g, b, a)
    if a < 0.5 then return 0, 0, 0, 0 end
    local s = shadeOf(r, g, b)
    if s == 0 then return 0, 0, 0, 0 end
    local c = colors[s + 1]
    return c[1] / 255, c[2] / 255, c[3] / 255, 1
  end)
  return data
end

-- A trainer's sprite sheet from an installed game: grey, plus colours
-- (the game's own for Gen 2, else Gen 2's). nil if no game has it. -Elvie
function fromRom(mod, which, kind)
  local key = which .. "|" .. kind
  if romCache[key] ~= nil then return unpack(romCache[key] or {}) end
  local Avatars = engine("src.online.union.Avatars")
  local sources = ROM[which] and ROM[which][kind] or {}
  local data, colors, games = nil, nil, {}
  for _, source in ipairs(sources) do
    for _, game in ipairs(source[1]) do
      games[#games + 1] = game
      if not data and Avatars and type(Avatars.hostEntry) == "function" then
        local ok, entry = pcall(Avatars.hostEntry, game, source[2])
        if ok and type(entry) == "table" and entry.layout == "gb" then
          local okData, grey = pcall(Avatars.imageData, entry)
          if okData and grey then
            data = grey
            local own = type(entry.palette) == "table" and entry.palette.colors
            colors = type(own) == "table" and #own == 4 and own or PALETTES[source[3]]
          end
        end
      end
    end
  end
  if not data and #sources > 0 then
    note(mod, key, "no %s sprite for %s: %s isn't installed (or hasn't been started yet)",
      kind, which:upper(), table.concat(games, "/"))
  end
  romCache[key] = data and { data, colors } or false
  return data, colors
end

-- The six Game Boy frames for a walk, bike or surf sheet, coloured. -Elvie
local function frames(mod, base, kind)
  local meta = registered[base] or {}
  local own = OWN_OF[kind] and base .. OWN_OF[kind]
  if own and mod.assets:info(own) then
    local ok, data = pcall(love.image.newImageData, mod.assets:path(own))
    if ok and data then return colourise(data, colorsOf(meta, CRYSTAL_COLORS), true) end
    note(mod, own, "could not load %s; skipping it", own)
    return nil
  end
  local which = romOf(meta)
  if not which then return nil end
  local grey, colors = fromRom(mod, which, kind)
  if not grey then return nil end
  -- overworldColors in meta.json wins over the game's own colours, but
  -- not for the Pokémon you surf or dive on -Elvie
  if kind ~= "surf" and kind ~= "dive" then colors = colorsOf(meta, colors) end
  return colourise(grey:clone(), colors, false)
end

local function sheet(mod, base, kind, layout)
  local src = frames(mod, base, kind)
  if not src then return nil end
  local sw, sh = src:getDimensions()
  if sw ~= 16 or sh < 16 * 6 then
    note(mod, base .. kind, "%s's Game Boy %s sprite is %dx%d; it needs 16x96", base, kind, sw, sh)
    return nil
  end
  local bike = kind == "bike"
  local w = bike and 32 or 16
  local list, n = WALK, 9
  if not bike then n, list = LAYOUT[layout][1], LAYOUT[layout][2] end
  local out = love.image.newImageData(w, 32 * n)
  for i = 0, n - 1 do
    local f = i < 9 and WALK[i + 1] or list[i - 8]
    local row = bike and BIKE_ROW or (f[3] and STAND_ROW + 1 or STAND_ROW)
    local x0, y0 = (w - 16) / 2, i * 32 + row - 15
    for y = 0, 15 do
      for x = 0, 15 do
        local r, g, b, a = src:getPixel(f[2] and 15 - x or x, f[1] * 16 + y)
        if a > 0 then out:setPixel(x0 + x, y0 + y, r, g, b, a) end
      end
    end
  end
  return out
end

-- Surfing or diving: the Pokémon in the tile at the bottom of each frame. -Elvie
local function mount(mod, base, file, layout)
  local size = MOUNT[file][layout]
  if not size then return nil end
  local which = romOf(registered[base])
  -- the folder's own surf art first, else the game's Pokémon -Elvie
  local src = frames(mod, base, mod.assets:info(base .. OWN_OF.surf) and "surf" or mountKind(which, file))
  if not src then return nil end
  local sw, sh = src:getDimensions()
  if sw ~= 16 or sh < 16 * 6 then return nil end
  local w, n = size[1], size[2]
  local out = love.image.newImageData(w, 32 * n)
  for i = 0, n - 1 do
    local f = i < 9 and WALK[i + 1] or MOUNT_EXTRA[i - 8]
    local x0, y0 = (w - 16) / 2, i * 32 + 16
    for y = 0, 15 do
      for x = 0, 15 do
        local r, g, b, a = src:getPixel(f[2] and 15 - x or x, f[1] * 16 + y)
        if a > 0 then out:setPixel(x0 + x, y0 + y, r, g, b, a) end
      end
    end
  end
  return out
end

-- Fishing
-- On the Game Boy the fishing pose is the standing frame with its bottom
-- 8 rows swapped for hands holding a rod, plus a loose rod tile beside it.
-- Those tiles come through mod.datasets: Gen 1's from the field data's
-- overworldFx (red_fish_front/back/side and fishing_rod), Gen 2's from the
-- emotes sheet (fishing, Crystal's fishing_female for Kris: pose rows
-- down, up, left, then the two rod tiles). Gen 2's emotes aren't served
-- yet (gen1recomp issue filed 2026-10-25), so until they are, Gold and
-- Kris fish with the other looks' art. -Elvie
-- --------------------------------------------------
FISH = {
  red = { gen = 1, games = GEN1 }, blue = { gen = 1, games = GEN1 },
  gold = { gen = 2, games = GEN2, key = "fishing" },
  kris = { gen = 2, games = { "crystal" }, key = "fishingFemale" },
}
-- The rod tile, from the sprite's top-left: { dx, dy, tile, mirrored }.
-- Right is left mirrored by the game. -Elvie
-- src/world/OverworldController.lua ROD_OAM (Gen 1), src/world/gen2/Player.lua ROD_OAM (Gen 2)
local ROD = {
  [1] = { down = { 4, 15, 0 }, up = { 4, -8, 0 }, left = { -8, 4, 1 } },
  [2] = { down = { 0, 16, 0 }, up = { 0, -8, 0 }, left = { -8, 5, 1, true } },
}
-- Gen 3 keeps fishing left, up, down, four frames each; facing down the
-- rod hangs below the tile, so each frame gets 8 more rows and is drawn 8
-- lower (as the dive blob does). -Elvie
local FISH_ORDER = { "left", "up", "down" }
local FISH_DROP = 8
gameboy.DROP = { ["fishing.png"] = FISH_DROP }
local STAND_OF = { down = S, up = U, left = L }
local fishCache = {} -- [base] = { pose = { facing = ImageData }, rod = { [0], [1] }, gen, own } or false -Elvie

local function crop(src, x, y, w, h)
  local out = love.image.newImageData(w, h)
  out:paste(src, 0, 0, x, y, w, h)
  return out
end

-- A tile from a dataset's cache, as ImageData, or nil. -Elvie
local function datasetImage(view, path)
  if type(path) ~= "string" then return nil end
  local ok, full = pcall(view.assets.path, view.assets, path)
  if not ok or type(full) ~= "string" then return nil end
  local okData, data = pcall(love.image.newImageData, full)
  return okData and data or nil
end

local function registryGet(view, name, id)
  local registry = view.content and view.content[name]
  if type(registry) ~= "table" or type(registry.get) ~= "function" then return nil end
  local ok, value = pcall(registry.get, registry, id)
  return ok and value or nil
end

local function fromDataset(view, info)
  if info.gen == 1 then
    local fx = registryGet(view, "field", "overworldFx")
    if type(fx) ~= "table" then return nil end
    local function pathOf(name) return type(fx[name]) == "table" and fx[name].path end
    local pose = { down = datasetImage(view, pathOf("redFishFront")), up = datasetImage(view, pathOf("redFishBack")),
      left = datasetImage(view, pathOf("redFishSide")) }
    local rod = datasetImage(view, pathOf("fishingRod"))
    if not (pose.down and pose.up and pose.left and rod) then return nil end
    return { pose = pose, rod = { [0] = crop(rod, 0, 0, 8, 8), [1] = crop(rod, 0, 8, 8, 8) } }
  end
  -- Gen 2: wherever the fix puts the emotes record -Elvie
  local emotes = registryGet(view, "menu_gfx", "emotes") or registryGet(view, "field", "emotes")
  local sheet = type(emotes) == "table" and datasetImage(view, emotes[info.key])
  if not sheet then return nil end
  local w, h = sheet:getDimensions()
  if w ~= 16 or h < 32 then return nil end
  return { pose = { down = crop(sheet, 0, 0, 16, 8), up = crop(sheet, 0, 8, 16, 8), left = crop(sheet, 0, 16, 16, 8) },
    rod = { [0] = crop(sheet, 0, 24, 8, 8), [1] = crop(sheet, 8, 24, 8, 8) } }
end

-- The fishing tiles for a trainer, still grey, from the first installed
-- game that has them. -Elvie
local fishCacheOf = {} -- [which] = art or false -Elvie
local function fishArt(mod, which)
  if fishCacheOf[which] ~= nil then return fishCacheOf[which] or nil end
  local info = FISH[which]
  local datasets = type(mod.datasets) == "table" and mod.datasets
  local art
  if info and datasets and type(datasets.open) == "function" then
    for _, game in ipairs(info.games) do
      local ok, view = pcall(datasets.open, datasets, game)
      if ok and type(view) == "table" then art = fromDataset(view, info) end
      if art then break end
    end
  end
  if art then art.gen = info.gen end
  fishCacheOf[which] = art or false
  return art
end

local function ownImage(mod, rel)
  if not (love and love.image and mod.assets:info(rel)) then return nil end
  local ok, data = pcall(love.image.newImageData, mod.assets:path(rel))
  if ok and data then return data end
  note(mod, rel, "could not load %s; skipping it", rel)
  return nil
end

-- A folder's fishing: each pose and the rod from its own files where it
-- has them, the rest from a game (its romOverworld trainer's, else Gen 1's,
-- else Gen 2's). Own tiles are shaded with the folder's walk, game tiles
-- from grey. The rod's offsets follow whoever drew it. nil if any part
-- is missing, so it fishes with the other looks' art. -Elvie
function fishParts(mod, base)
  if fishCache[base] ~= nil then return fishCache[base] or nil end
  local which = romOf(registered[base])
  local pose, own, rod, gen = {}, {}, nil, nil
  for facing, name in pairs(OWN_FISH) do
    local data = ownImage(mod, base .. name)
    local w, h = 0, 0
    if data then w, h = data:getDimensions() end
    if data and w == 16 and h == 8 then pose[facing], own[facing] = data, true
    elseif data then note(mod, base .. name, "%s%s is %dx%d; it needs 16x8", base, name, w, h) end
  end
  local rodData = ownImage(mod, base .. OWN_ROD)
  if rodData then
    local w, h = rodData:getDimensions()
    if w == 8 and h == 16 then
      rod, gen, own.rod = { [0] = crop(rodData, 0, 0, 8, 8), [1] = crop(rodData, 0, 8, 8, 8) }, 1, true
    else
      note(mod, base .. OWN_ROD, "%s%s is %dx%d; it needs 8x16", base, OWN_ROD, w, h)
    end
  end
  if not (pose.down and pose.up and pose.left and rod) then
    local game
    for _, who in ipairs(which and FISH[which] and { which } or { "red", "gold" }) do
      game = fishArt(mod, who)
      if game then break end
    end
    if game then
      for facing, tile in pairs(game.pose) do pose[facing] = pose[facing] or tile end
      if not rod then rod, gen = game.rod, game.gen end
    end
  end
  local art = pose.down and pose.up and pose.left and rod and { pose = pose, rod = rod, gen = gen, own = own } or nil
  if not art and (which and FISH[which] or next(own)) then
    note(mod, base .. "|fish", "no fishing art for %s yet (%s); it fishes with its other looks' art", base,
      which and FISH[which] and FISH[which].gen == 2 and "Gen 2's isn't readable through mod.datasets yet"
        or "no overworldFish files or rod, and Red, Blue or Yellow isn't installed")
  end
  fishCache[base] = art or false
  return art
end

local function fishing(mod, base)
  local meta = registered[base] or {}
  local which = romOf(meta)
  local art = fishParts(mod, base)
  if not art then return nil end
  local walk = frames(mod, base, "walk")
  if not walk then return nil end
  -- the walk's colours, and the folder's own shades for its own tiles -Elvie
  local ownWalk = mod.assets:info(base .. OWN_OF.walk)
  local colors
  if ownWalk then
    colors = colorsOf(meta, CRYSTAL_COLORS)
  else
    local _, romColors = fromRom(mod, which, "walk")
    colors = colorsOf(meta, romColors or PALETTES.red)
  end
  local mine = {}
  if ownWalk then mine[#mine + 1] = ownImage(mod, base .. OWN_OF.walk) end
  for facing in pairs(OWN_FISH) do if art.own[facing] then mine[#mine + 1] = art.pose[facing] end end
  if art.own.rod then mine[#mine + 1] = art.rod[0]; mine[#mine + 1] = art.rod[1] end
  local shades = #mine > 0 and rankedShades(mine) or nil
  local pose, rod = {}, {}
  for facing, tile in pairs(art.pose) do
    pose[facing] = colourise(tile:clone(), colors, art.own[facing] and shades or false)
  end
  for i, tile in pairs(art.rod) do rod[i] = colourise(tile:clone(), colors, art.own.rod and shades or false) end
  local offsets = ROD[art.gen]
  local H = 32 + FISH_DROP
  local out = love.image.newImageData(32, H * 12)
  local function put(src, sx, sy, w, h, dx, dy, mirror)
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local r, g, b, a = src:getPixel(sx + (mirror and w - 1 - x or x), sy + y)
        local px, py = dx + x, dy + y
        if a > 0 and px >= 0 and px < 32 and py >= 0 then out:setPixel(px, py, r, g, b, a) end
      end
    end
  end
  for group, facing in ipairs(FISH_ORDER) do
    for k = 0, 3 do
      local fi = (group - 1) * 4 + k
      local x0, y0 = 8, fi * H + STAND_ROW - 15
      -- the standing frame's top half, the fishing pose under it -Elvie
      put(walk, 0, STAND_OF[facing] * 16, 16, 8, x0, y0)
      put(pose[facing], 0, 0, 16, 8, x0, y0 + 8)
      local o = offsets[facing]
      put(rod[o[3]], 0, 0, 8, 8, x0 + o[1], y0 + o[2], o[4])
    end
  end
  return out
end

-- The Gen 3 file as ImageData, or nil if the folder has no art for it.
-- layout ("frlg" or "rse") sets the frame counts. -Elvie
function gameboy.load(mod, base, file, layout)
  if not (love and love.image) then return nil end
  if OW_FILES[file] then return sheet(mod, base, file:sub(1, 4), layout) end
  if MOUNT[file] then return mount(mod, base, file, layout) end
  if file == "fishing.png" then return fishing(mod, base) end
  if file == "surfBlob.png" then
    -- see-through: the Game Boy Pokémon is the whole picture -Elvie
    if not (BLOB[layout] and gameboy.has(mod, base, file)) then return nil end
    return love.image.newImageData(32, 32 * BLOB[layout])
  end
  local rel = sourceOf(mod, base, file)
  if not rel then return nil end
  local ok, src = pcall(love.image.newImageData, mod.assets:path(rel))
  if not ok or not src then
    note(mod, rel, "could not load %s; skipping it", rel)
    return nil
  end
  local size = SIZE[file]
  local pic = fit(mod, src, rel, size[1], size[2])
  if file ~= "back.png" then return pic end
  local n = BACK_FRAMES[layout] or 1
  local strip = love.image.newImageData(64, 64 * n)
  for i = 0, n - 1 do strip:paste(pic, 0, i * 64, 0, 0, 64, 64) end
  return strip
end

return gameboy
