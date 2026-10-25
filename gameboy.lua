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
-- "gold" or "kris"), that player's sprites from the player's own
-- installed Gen 1 or Gen 2 game, through the engine's Union Room avatar
-- loader (which reads other games' sprites for online play). Nintendo's
-- art is never shipped. -Elvie
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
-- The player's own sprites in each game; the first installed game in
-- the list is used. -Elvie
-- pokecrystal/data/sprites/player_sprites.asm, pokered/data/sprites/sprites.asm
local ROM = {
  red  = { games = { "red", "blue", "yellow" }, walk = "SPRITE_RED", bike = "SPRITE_RED_BIKE", palette = "red" },
  gold = { games = { "gold", "silver", "crystal" }, walk = "SPRITE_CHRIS", bike = "SPRITE_CHRIS_BIKE", palette = "red" },
  kris = { games = { "crystal" }, walk = "SPRITE_KRIS", bike = "SPRITE_KRIS_BIKE", palette = "blue" },
}
-- Gen 2 sprites come with the game's own colours. Gen 1's are grey, so
-- Red gets Gen 2's: pokecrystal/gfx/overworld/npc_sprites.pal, day,
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

local registered = {} -- [base] = meta -Elvie
local warned = {}
local romCache = {} -- ["kris|walk"] = { grey ImageData, the game's colours } or false -Elvie

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
local ART = { "front.png", "frontColor.png", "back.png", "backColor.png", "overworldWalk.png", "overworldBike.png" }
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
  local own = OW_FILES[file]
  if not own then return false end
  if mod.assets:info(base .. own) then return true end
  return romOf(registered[base]) ~= nil
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

local function rankedShades(data)
  local seen, list, clear = {}, {}, false
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
  table.sort(list, function(x, y) return seen[x] > seen[y] end)
  local shade = {}
  -- with no see-through pixels, the lightest colour is the backdrop -Elvie
  local first = clear and 1 or 0
  for i, key in ipairs(list) do shade[key] = math.min(3, first + i - 1) end
  return function(r, g, b)
    return shade[math.floor(r * 255) * 65536 + math.floor(g * 255) * 256 + math.floor(b * 255)] or 3
  end
end

local function colourise(data, colors, ranked)
  local shadeOf = ranked and rankedShades(data) or function(r) return greyShade(r) end
  data:mapPixel(function(_, _, r, g, b, a)
    if a < 0.5 then return 0, 0, 0, 0 end
    local s = shadeOf(r, g, b)
    if s == 0 then return 0, 0, 0, 0 end
    local c = colors[s + 1]
    return c[1] / 255, c[2] / 255, c[3] / 255, 1
  end)
  return data
end

-- The player's sprite sheet from an installed game: grey, plus the
-- game's own colours (Gen 2) or nil (Gen 1). -Elvie
local function fromRom(mod, which, kind)
  local key = which .. "|" .. kind
  if romCache[key] ~= nil then return unpack(romCache[key] or {}) end
  local Avatars = engine("src.online.union.Avatars")
  local rom = ROM[which]
  local data, colors
  if Avatars and type(Avatars.hostEntry) == "function" then
    for _, game in ipairs(rom.games) do
      local ok, entry = pcall(Avatars.hostEntry, game, rom[kind])
      if ok and type(entry) == "table" and entry.layout == "gb" then
        local okData, grey = pcall(Avatars.imageData, entry)
        if okData and grey then
          data = grey
          colors = type(entry.palette) == "table" and type(entry.palette.colors) == "table"
            and #entry.palette.colors == 4 and entry.palette.colors or nil
          break
        end
      end
    end
  end
  if not data then
    note(mod, key, "no %s sprite for %s: %s isn't installed (or hasn't been started yet)",
      kind, which:upper(), table.concat(rom.games, "/"))
  end
  romCache[key] = data and { data, colors } or false
  return data, colors
end

-- The six Game Boy frames for a walk or bike sheet, coloured. -Elvie
local function frames(mod, base, kind)
  local meta = registered[base] or {}
  local own = base .. OW_FILES[kind .. ".png"]
  if mod.assets:info(own) then
    local ok, data = pcall(love.image.newImageData, mod.assets:path(own))
    if ok and data then return colourise(data, colorsOf(meta, CRYSTAL_COLORS), true) end
    note(mod, own, "could not load %s; skipping it", own)
    return nil
  end
  local which = romOf(meta)
  if not which then return nil end
  local grey, own = fromRom(mod, which, kind)
  if not grey then return nil end
  -- overworldColors in meta.json wins over the game's own colours -Elvie
  return colourise(grey:clone(), colorsOf(meta, own or PALETTES[ROM[which].palette]), false)
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

-- The Gen 3 file as ImageData, or nil if the folder has no art for it.
-- layout ("frlg" or "rse") sets the frame counts. -Elvie
function gameboy.load(mod, base, file, layout)
  if not (love and love.image) then return nil end
  if OW_FILES[file] then return sheet(mod, base, file:sub(1, 4), layout) end
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
