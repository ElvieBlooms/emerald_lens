-- Players from the other Gen 3 games
-- A look whose meta.json has "fromGame" ("red", "leaf", "brendan" or
-- "may") is that player, read from the player's own copy of the other
-- family's game: Red and Leaf from FireRed/LeafGreen for Ruby/Sapphire/
-- Emerald, Brendan and May from Emerald (or Ruby/Sapphire) for FireRed/
-- LeafGreen. Nothing is shipped: the sprites come through the engine's
-- Union Room avatar loader, which reads other games' overworld sprites
-- for online play. -Elvie
--
-- Only overworld sprites can be read that way, so battle pics, the intro
-- and the map icon fall back to the character's other looks. The sheets
-- are laid out for the running game: running frames reordered, FR/LG's
-- bike as both R/S/E bikes, 16-wide surf frames centred in 32. Sheets the
-- other game has no art for use the walk or bike frames instead, so the
-- right player always shows (watering, decorating, field moves where the
-- loader can't read them, the VS Seeker bike). R/S/E diving for Red and
-- Leaf is their surf frames in the dive shade, made here like
-- pack_gen3.py's dive --underwater; a diveBlob.png in the look's folder
-- goes behind them as usual. -Elvie
--
-- A look whose meta.json has "fromDS" ("ethan", "lyra", "silver", "lucas",
-- "dawn" or "barry") is that player or rival from the DS games, read from
-- the player's own HeartGold/SoulSilver or Diamond/Pearl/Platinum dump
-- through Prism Importer (a separate mod; its exports hand out the
-- sprites once the dump is imported from IMPORTER in PRISM). Those looks
-- are offered in every game. Walking, running and the bike come from the
-- overworld sheets; the battle pics are the DS trainer pics cut to 64x64.
-- The rest stands in with walking frames, as for the Gen 3 players above.
-- --------------------------------------------------

local crossgame = {}

local FRLG, RSE = { "firered", "leafgreen" }, { "emerald", "ruby", "sapphire" }
-- Graphics ids, from pokefirered and pokeemerald's
-- object_event_graphics_info_pointers.h (the same in Ruby/Sapphire). -Elvie
local PLAYERS = {
  red     = { family = "frlg", games = FRLG,
              gid = { walk = 0, bike = 1, surf = 2, fieldMove = 3, fishing = 4, vsSeekerBike = 6 } },
  leaf    = { family = "frlg", games = FRLG,
              gid = { walk = 7, bike = 8, surf = 9, fieldMove = 10, fishing = 11, vsSeekerBike = 13 } },
  brendan = { family = "rse", games = RSE,
              gid = { walk = 0, bike = 1, acroBike = 63, surf = 2, fieldMove = 3, fishing = 137,
                      underwater = 111, watering = 191, decorating = 193 } },
  may     = { family = "rse", games = RSE,
              gid = { walk = 89, bike = 90, acroBike = 91, surf = 92, fieldMove = 93, fishing = 138,
                      underwater = 112, watering = 192, decorating = 194 } },
}
crossgame.PLAYERS = PLAYERS

-- What each running layout's sheet is made of: the other game's sheet,
-- frame size and count, and for each frame here the frame it comes from
-- (0-based; nil means the same number). Running frames: FR/LG keeps three
-- in a row per facing (9-11 down, 12-14 up, 15-17 left), R/S/E a stand
-- per facing (9-11) then a pair each (12-17). -Elvie
local WALK_TO_RSE = { [10] = 12, [11] = 15, [12] = 10, [13] = 11, [14] = 13, [15] = 14 }
local WALK_TO_FRLG = { [10] = 12, [11] = 13, [12] = 10, [13] = 14, [14] = 15, [15] = 11,
  -- 18 and 19 shake the head facing down (sAnim_ShakeHeadOrWalkInPlace) -Elvie
  [18] = 3, [19] = 4 }
-- Acro Bike tricks from the plain bike: wheelie and front-wheel frames are
-- the standing one for that facing, the moving wheelie frames its two
-- pedal frames (preview.js ACRO). -Elvie
local ACRO = { [9] = 0, [10] = 0, [11] = 0, [12] = 0, [13] = 1, [14] = 1, [15] = 1, [16] = 1,
  [17] = 2, [18] = 2, [19] = 2, [20] = 2, [21] = 3, [22] = 4, [23] = 5, [24] = 6, [25] = 7, [26] = 8 }
-- FR/LG's field move plays frames 0-4, the same five R/S/E has; the
-- other four are kept as the standing frame rather than left empty.
-- The engine's avatar reader only hands out sheets of 9 frames or more,
-- so R/S/E's 5-frame field move isn't readable yet and the standing
-- frame (alt) is used; reading the cache file directly would put a
-- data/generated path in the mod, which modkit lint refuses (MK301).
local FIELD_MOVE_TO_FRLG = { [5] = 0, [6] = 0, [7] = 0, [8] = 0 }
-- Every frame of the sheet from frame 0 of the source -Elvie
local ALL_FIRST = setmetatable({}, { __index = function() return 0 end })

local SHEETS = {
  rse = {
    ["walk.png"]       = { from = "walk", w = 16, h = 32, n = 18, frames = WALK_TO_RSE },
    ["bike.png"]       = { from = "bike", w = 32, h = 32, n = 9 },
    ["acroBike.png"]   = { from = "bike", w = 32, h = 32, n = 27, frames = ACRO },
    ["surf.png"]       = { from = "surf", w = 32, h = 32, n = 12 },
    ["fieldMove.png"]  = { from = "fieldMove", w = 32, h = 32, n = 5 },
    ["fishing.png"]    = { from = "fishing", w = 32, h = 32, n = 12 },
    ["underwater.png"] = { from = "surf", w = 32, h = 32, n = 9, dive = true },
    -- watering is walking with a can, in walk order: walk frames -Elvie
    ["watering.png"]   = { from = "walk", w = 32, h = 32, n = 9 },
    ["decorating.png"] = { from = "walk", w = 16, h = 32, n = 1 },
  },
  frlg = {
    ["walk.png"]         = { from = "walk", w = 16, h = 32, n = 20, frames = WALK_TO_FRLG },
    ["bike.png"]         = { from = "bike", w = 32, h = 32, n = 9 },
    ["surf.png"]         = { from = "surf", w = 16, h = 32, n = 12 },
    ["fieldMove.png"]    = { from = "fieldMove", w = 16, h = 32, n = 9, frames = FIELD_MOVE_TO_FRLG,
                             alt = { from = "walk", frames = ALL_FIRST } },
    ["fishing.png"]      = { from = "fishing", w = 32, h = 32, n = 12 },
    ["vsSeekerBike.png"] = { from = "bike", w = 32, h = 32, n = 6, frames = ALL_FIRST },
  },
}
-- underwater: stand down, up, left, then two steps each, all the surf
-- sitting frame for that facing (pack_gen3.py dive) -Elvie
local DIVE = { [0] = 0, 1, 2, 0, 0, 1, 1, 2, 2 }
-- pack_gen3.py DIVE_SHADE: navy laid over the sprite at 60% -Elvie
local SHADE, SHADE_A = { 0, 25 / 255, 113 / 255 }, 0.6

local registered = {} -- [base] = player name -Elvie
local dsRegistered = {} -- [base] = DS player name
local cache = {} -- ["red|walk"] = ImageData or false -Elvie
local warned = {}

local function engine(name)
  local ok, m = pcall(require, name)
  return ok and m or nil
end

local function playerOf(meta)
  local which = type(meta) == "table" and type(meta.fromGame) == "string" and meta.fromGame:lower()
  return which and PLAYERS[which] and which or nil
end
crossgame.playerOf = playerOf

---------------------------------------------------------------- DS players

-- Prism Importer's ids for each one, first found wins: Platinum's own
-- pictures before Diamond/Pearl's, which a Platinum dump also has. Its
-- overworld sheets are 32 frames of 32x32, walking then running, each
-- facing up, down, left, right as stand, step, stand, step.
local DS = {
  ethan  = { game = "hgss", name = "HG/SS", walk = { "hero" }, bike = { "cyclehero" },
             front = { "front/pkmn_trainer_ethan" }, back = { "back/00" } },
  lyra   = { game = "hgss", name = "HG/SS", walk = { "heroine" }, bike = { "cycleheroine" },
             front = { "front/pkmn_trainer_lyra" }, back = { "back/01" } },
  silver = { game = "hgss", name = "HG/SS", walk = { "gsrivel" },
             front = { "front/rival" }, back = { "back/02" } },
  lucas  = { game = "dppt", name = "D/P/Pt", walk = { "hero" }, bike = { "pl_cyclehero", "cyclehero" },
             front = { "front/player_male", "front/dp_player_male" }, back = { "back/08", "back/00" } },
  dawn   = { game = "dppt", name = "D/P/Pt", walk = { "heroine" }, bike = { "pl_cycheroine", "cycleheroine" },
             front = { "front/player_female", "front/dp_player_female" }, back = { "back/09", "back/01" } },
  barry  = { game = "dppt", name = "D/P/Pt", walk = { "rivel" },
             front = { "front/rival" }, back = { "back/10", "back/02" } },
}
crossgame.DS = DS

local function dsOf(meta)
  local which = type(meta) == "table" and type(meta.fromDS) == "string" and meta.fromDS:lower()
  return which and DS[which] and which or nil
end
crossgame.dsOf = dsOf

-- A DS frame: facing (0 up, 1 down, 2 left), k (0 stand, 1 and 3 the
-- steps), running or not
local function ds(facing, k, run) return (run and 16 or 0) + facing * 4 + k end
local UP, DOWN, LEFT = 0, 1, 2
-- the Gen 3 walk order: stand down, up, left, then two steps each
local DS_WALK = { [0] = ds(DOWN, 0), ds(UP, 0), ds(LEFT, 0), ds(DOWN, 1), ds(DOWN, 3),
  ds(UP, 1), ds(UP, 3), ds(LEFT, 1), ds(LEFT, 3) }
local DS_FRLG_WALK, DS_RSE_WALK = {}, {}
for i = 0, 8 do DS_FRLG_WALK[i], DS_RSE_WALK[i] = DS_WALK[i], DS_WALK[i] end
-- FR/LG runs three frames a facing (9-11 down, 12-14 up, 15-17 left) and
-- shakes its head with the down steps (18, 19); R/S/E a stand per facing
-- (9-11), then two steps each (12-17)
for n, facing in ipairs({ DOWN, UP, LEFT }) do
  local at = 9 + (n - 1) * 3
  DS_FRLG_WALK[at], DS_FRLG_WALK[at + 1], DS_FRLG_WALK[at + 2] =
    ds(facing, 0, true), ds(facing, 1, true), ds(facing, 3, true)
  DS_RSE_WALK[8 + n] = ds(facing, 0, true)
  DS_RSE_WALK[12 + (n - 1) * 2], DS_RSE_WALK[13 + (n - 1) * 2] = ds(facing, 1, true), ds(facing, 3, true)
end
DS_FRLG_WALK[18], DS_FRLG_WALK[19] = ds(DOWN, 1), ds(DOWN, 3)
local function acroOf(i) return DS_WALK[ACRO[i] or i] end
local DS_ACRO = setmetatable({}, { __index = function(_, i) return acroOf(i) end })
-- a facing's standing frame, for sheets the DS games have no art for.
-- Surfing and other 9-frame orders go down, up, left, then two steps each
-- (surf adds its field move stands, 9-11); fishing is left, up, down in
-- fours (the line-out frames are 3, 7 and 11)
local STAND_OF = { [0] = DS_WALK[0], [1] = DS_WALK[1], [2] = DS_WALK[2] }
local function walkFacing(i)
  if i < 3 then return i elseif i < 9 then return math.floor((i - 3) / 2) else return (i - 9) % 3 end
end
local DS_STAND = setmetatable({}, { __index = function(_, i) return STAND_OF[walkFacing(i)] end })
local FISH_FACING = { [0] = 2, 1, 0 } -- left, up, down
local DS_FISH = setmetatable({}, { __index = function(_, i) return STAND_OF[FISH_FACING[math.floor(i / 4)] or 0] end })
local DS_FIRST = setmetatable({}, { __index = function() return ds(DOWN, 0) end })
local DS_DIVE = setmetatable({}, { __index = function(_, i) return STAND_OF[DIVE[i] or 0] end })

-- What each sheet is made of, by running layout: the DS sheet, the frame
-- size and count here, which DS frame each frame is, and the row the
-- standing frames' feet go on (GAME_FEET in pack_gen3.py)
local DS_SHEETS = {
  frlg = {
    ["walk.png"]         = { from = "walk", w = 32, h = 32, n = 20, frames = DS_FRLG_WALK, feet = 30 },
    ["bike.png"]         = { from = "bike", w = 32, h = 32, n = 9, frames = DS_WALK, feet = 31 },
    ["surf.png"]         = { from = "walk", w = 32, h = 32, n = 12, frames = DS_STAND, feet = 29 },
    ["fieldMove.png"]    = { from = "walk", w = 32, h = 32, n = 9, frames = DS_FIRST, feet = 30 },
    ["fishing.png"]      = { from = "walk", w = 32, h = 32, n = 12, frames = DS_FISH, feet = 30 },
    ["vsSeekerBike.png"] = { from = "bike", w = 32, h = 32, n = 6, frames = DS_FIRST, feet = 31 },
  },
  rse = {
    ["walk.png"]       = { from = "walk", w = 32, h = 32, n = 18, frames = DS_RSE_WALK, feet = 30 },
    ["bike.png"]       = { from = "bike", w = 32, h = 32, n = 9, frames = DS_WALK, feet = 31 },
    ["acroBike.png"]   = { from = "bike", w = 32, h = 32, n = 27, frames = DS_ACRO, feet = 31 },
    ["surf.png"]       = { from = "walk", w = 32, h = 32, n = 12, frames = DS_STAND, feet = 30 },
    ["fieldMove.png"]  = { from = "walk", w = 32, h = 32, n = 5, frames = DS_FIRST, feet = 30 },
    ["fishing.png"]    = { from = "walk", w = 32, h = 32, n = 12, frames = DS_FISH, feet = 30 },
    ["underwater.png"] = { from = "walk", w = 32, h = 32, n = 9, frames = DS_DIVE, feet = 30, dive = true },
    ["watering.png"]   = { from = "walk", w = 32, h = 32, n = 9, frames = DS_WALK, feet = 30 },
    ["decorating.png"] = { from = "walk", w = 32, h = 32, n = 1, frames = DS_FIRST, feet = 30 },
  },
}
-- The battle pics: frame size, count, which pic, and how its frames map
-- (FR/LG's back is idle then four throw frames, R/S/E's three throw
-- frames then idle)
local DS_PICS = {
  frlg = { ["front.png"] = { from = "front", h = 64, n = 1 },
           ["intro.png"] = { from = "front", h = 96, n = 1 },
           ["back.png"]  = { from = "back", h = 64, n = 5, throw = { [0] = 0, 1, 2, 3, 4 } } },
  rse  = { ["front.png"] = { from = "front", h = 64, n = 1 },
           ["back.png"]  = { from = "back", h = 64, n = 4, throw = { [0] = 1, 2, 3, 0 } } },
}

-- Prism Importer's exports, or nil when it isn't installed
local function importer(mod)
  local found = type(mod.find) == "function" and mod.find("prism_importer") or nil
  local api = type(found) == "table" and found.exports or nil
  if type(api) == "table" and api.apiVersion == 1 and type(api.imageData) == "function" then return api end
  return nil
end

-- A DS sheet as { image, w, h, columns, n }, from the first id the dump
-- has
local function dsSource(mod, which, kind)
  local key = "ds|" .. which .. "|" .. kind
  if cache[key] ~= nil then return cache[key] or nil end
  local spec = DS[which]
  local api = importer(mod)
  local data
  if api and spec[kind] then
    local pack = (kind == "front" or kind == "back") and "trainer_pics" or "overworld"
    for _, id in ipairs(spec[kind]) do
      local ok, image, entry = pcall(api.imageData, spec.game, pack, id)
      if ok and image and type(entry) == "table" then
        local sprite = type(entry.sprite) == "table" and entry.sprite or {}
        local w, h = sprite.width or entry.width, sprite.height or entry.height
        if w and h then
          data = { image = image, w = w, h = h, columns = sprite.columns or 1,
                   n = sprite.frames or entry.frames or 1 }
          break
        end
      end
    end
  end
  if not data and spec[kind] and not warned[key] then
    warned[key] = true
    if not api then
      mod.log:info("no %s sprite for %s: Prism Importer isn't installed", kind, which:upper())
    else
      local okS, status = pcall(api.status)
      local st = okS and type(status) == "table" and status[spec.game] or nil
      mod.log:info("no %s sprite for %s: the %s dump %s", kind, which:upper(), spec.name,
        (st and st.state == "ready") and "doesn't have it" or "isn't imported (IMPORTER in PRISM)")
    end
  end
  cache[key] = data or false
  return data
end

-- Frame f of a DS sheet, as a position
local function frameAt(src, f)
  return (f % src.columns) * src.w, math.floor(f / src.columns) * src.h
end

-- The lowest row with a pixel in any of the given frames, or nil
local function lowestRow(src, frames)
  local low
  for _, f in ipairs(frames) do
    if f < src.n then
      local fx, fy = frameAt(src, f)
      for y = src.h - 1, 0, -1 do
        if low and y <= low then break end
        local found = false
        for x = 0, src.w - 1 do
          local _, _, _, a = src.image:getPixel(fx + x, fy + y)
          if a > 0 then found = true break end
        end
        if found then low = y break end
      end
    end
  end
  return low
end

-- An overworld sheet for the running layout: each frame centred, and the
-- whole sheet moved so the standing frames' feet are on the game's row
local function dsOverworld(mod, which, sheet)
  local src = dsSource(mod, which, sheet.from)
  if not src then return nil end
  local low = lowestRow(src, { sheet.frames[0], sheet.frames[1], sheet.frames[2] })
  local dy = low and (sheet.feet - low) or 0
  local out = love.image.newImageData(sheet.w, sheet.h * sheet.n)
  local cw, ch = math.min(src.w, sheet.w), math.min(src.h, sheet.h)
  local dx, sx = math.floor((sheet.w - cw) / 2), math.floor((src.w - cw) / 2)
  for i = 0, sheet.n - 1 do
    local from = sheet.frames[i]
    if from and from < src.n then
      local fx, fy = frameAt(src, from)
      -- rows that would land outside the frame are left off
      local top, rows = 0, ch
      if dy < 0 then top = -dy end
      if dy > 0 then rows = ch - dy end
      if rows - top > 0 then
        out:paste(src.image, dx, i * sheet.h + (sheet.h - ch) + top + dy, fx + sx, fy + top, cw, rows - top)
      end
    end
  end
  if sheet.dive then
    out:mapPixel(function(_, _, r, g, b, a)
      if a == 0 then return r, g, b, a end
      return r * (1 - SHADE_A) + SHADE[1] * SHADE_A, g * (1 - SHADE_A) + SHADE[2] * SHADE_A,
        b * (1 - SHADE_A) + SHADE[3] * SHADE_A, a
    end)
  end
  return out
end

-- The box around a pic's pixels over the given frames: x0, y0, x1, y1
local function bounds(src, frames)
  local x0, y0, x1, y1
  for _, f in ipairs(frames) do
    local fx, fy = frameAt(src, f)
    for y = 0, src.h - 1 do
      for x = 0, src.w - 1 do
        local _, _, _, a = src.image:getPixel(fx + x, fy + y)
        if a > 0 then
          x0, x1 = math.min(x0 or x, x), math.max(x1 or x, x)
          y0, y1 = math.min(y0 or y, y), math.max(y1 or y, y)
        end
      end
    end
  end
  return x0, y0, x1, y1
end

-- A battle pic cut to 64 wide: centred on the trainer, feet on the bottom
-- row (front.png's feet row is 62); a trainer taller than the frame keeps
-- the head, and a back, which the DS cuts at the waist anyway, keeps the
-- head and shoulders
local function dsPic(mod, which, file, layout)
  local pic = DS_PICS[layout] and DS_PICS[layout][file]
  if not pic then return nil end
  local src = dsSource(mod, which, pic.from)
  if not src then return nil end
  local used = {}
  for i = 0, pic.n - 1 do
    local from = pic.throw and pic.throw[i] or 0
    used[i] = math.min(from, src.n - 1)
  end
  local list = {}
  for i = 0, pic.n - 1 do list[#list + 1] = used[i] end
  local x0, y0, x1, y1 = bounds(src, list)
  if not x0 then return nil end
  local sx = math.floor((x0 + x1 + 1) / 2) - 32
  local sy
  if pic.from == "front" and y1 - y0 + 1 <= pic.h - 1 then
    sy = y1 - (pic.h - 2) -- feet on the second row from the bottom
  elseif pic.from == "back" and y1 - y0 + 1 <= pic.h then
    sy = y1 - (pic.h - 1) -- cut at the bottom edge, as the game's are
  else
    sy = y0 - 1 -- the head one row down from the top
  end
  local out = love.image.newImageData(64, pic.h * pic.n)
  for i = 0, pic.n - 1 do
    local fx, fy = frameAt(src, used[i])
    for y = 0, pic.h - 1 do
      local syy = sy + y
      if syy >= 0 and syy < src.h then
        for x = 0, 63 do
          local sxx = sx + x
          if sxx >= 0 and sxx < src.w then
            out:setPixel(x, i * pic.h + y, src.image:getPixel(fx + sxx, fy + syy))
          end
        end
      end
    end
  end
  return out
end

local function dsPlan(base, file, layout)
  local which = dsRegistered[base]
  if not which then return nil end
  return which, DS_SHEETS[layout] and DS_SHEETS[layout][file], DS_PICS[layout] and DS_PICS[layout][file]
end

-- The family a "fromGame" look is offered in: the other one. -Elvie
function crossgame.familyFor(meta)
  local which = playerOf(meta)
  if not which then return nil end
  return PLAYERS[which].family == "frlg" and "rse" or "frlg"
end

function crossgame.register(base, meta)
  registered[base] = playerOf(meta)
  dsRegistered[base] = dsOf(meta)
end

function crossgame.isBase(base)
  return registered[base] ~= nil or dsRegistered[base] ~= nil
end

-- Whether a look is offered in a family: a Gen 3 player in the family
-- it isn't from and in the Game Boy games, a DS player everywhere
function crossgame.offeredIn(meta, family)
  if dsOf(meta) then return true end
  local from = crossgame.familyFor(meta)
  return from ~= nil and (family.gb or from == family.id)
end

-- The layouts its sheets are read in when the running game is family:
-- a Gen 3 player's own family's; a DS player is laid out for the game
-- (each of a Game Boy game's art layouts)
function crossgame.layoutsFor(meta, family)
  if dsOf(meta) then return family.gb and family.art or { family.id } end
  local which = playerOf(meta)
  return which and { PLAYERS[which].family } or {}
end

-- Where its sprites come from, for the LENS screen's info line
function crossgame.sourceName(meta, familyId)
  local which = dsOf(meta)
  if which then return DS[which].name .. " dump" end
  which = playerOf(meta)
  if not which then return nil end
  return (PLAYERS[which].family == "frlg" and "FR/LG" or "R/S/E") .. " game"
end

-- The other game's sheet, from the first installed game that has it. -Elvie
local function source(mod, which, kind, quiet)
  local key = which .. "|" .. kind
  if cache[key] ~= nil then return cache[key] or nil end
  local player = PLAYERS[which]
  local gid = player.gid[kind]
  local Avatars = engine("src.online.union.Avatars")
  local data
  if gid and Avatars and type(Avatars.hostEntry) == "function" then
    for _, game in ipairs(player.games) do
      local ok, entry = pcall(Avatars.hostEntry, game, gid)
      if ok and type(entry) == "table" and entry.layout == "gba" then
        local okData, image = pcall(Avatars.imageData, entry)
        if okData and image then
          data = { image = image, w = entry.w, h = entry.h, n = entry.frames }
          break
        end
      end
    end
  end
  if not data and gid and not quiet and not warned[key] then
    warned[key] = true
    mod.log:info("no %s sprite for %s: %s isn't installed (or hasn't been started yet), or the loader can't read it",
      kind, which:upper(), table.concat(player.games, "/"))
  end
  cache[key] = data or false
  return data
end

-- The recipe for a file, with its source if the game is installed. -Elvie
local function plan(mod, base, file, layout)
  local which = registered[base]
  local sheet = which and SHEETS[layout] and SHEETS[layout][file]
  if not sheet then return nil end
  -- quiet when there's a stand-in to use instead -Elvie
  local src = source(mod, which, sheet.from, sheet.alt ~= nil)
  if src then return sheet, src, sheet.frames end
  if sheet.alt then
    src = source(mod, which, sheet.alt.from)
    if src then return sheet, src, sheet.alt.frames end
  end
  return nil
end

-- A miss is kept so a game that isn't there is asked about once, not on
-- every draw. gen3.lua calls this when it sets up again (an options
-- change, a save loaded), so a game imported since then is found. If
-- anything had missed, the engine's own avatar cache is refreshed too,
-- since it keeps misses as well.
function crossgame.retry()
  local missed = false
  for key, value in pairs(cache) do
    if value == false then cache[key], missed = nil, true end
  end
  if missed then
    local Avatars = engine("src.online.union.Avatars")
    if Avatars and type(Avatars.refresh) == "function" then pcall(Avatars.refresh) end
  end
end

function crossgame.has(mod, base, file, layout)
  local which, sheet, pic = dsPlan(base, file, layout)
  if which then
    return (sheet or pic) ~= nil and dsSource(mod, which, (sheet or pic).from) ~= nil
  end
  return plan(mod, base, file, layout) ~= nil
end

function crossgame.load(mod, base, file, layout)
  if not (love and love.image) then return nil end
  local which, dsSheet, pic = dsPlan(base, file, layout)
  if which then
    if dsSheet then return dsOverworld(mod, which, dsSheet) end
    if pic then return dsPic(mod, which, file, layout) end
    return nil
  end
  local sheet, src, frames = plan(mod, base, file, layout)
  if not sheet then return nil end
  local out = love.image.newImageData(sheet.w, sheet.h * sheet.n)
  -- centre to centre, bottom to bottom; a wider source keeps its middle -Elvie
  local cw, ch = math.min(src.w, sheet.w), math.min(src.h, sheet.h)
  local dx, sx = math.floor((sheet.w - cw) / 2), math.floor((src.w - cw) / 2)
  for i = 0, sheet.n - 1 do
    local from
    if sheet.dive then from = DIVE[i] else from = (frames and frames[i]) or i end
    if from < src.n then
      out:paste(src.image, dx, i * sheet.h + sheet.h - ch, sx, from * src.h + src.h - ch, cw, ch)
    end
  end
  if sheet.dive then
    out:mapPixel(function(_, _, r, g, b, a)
      if a == 0 then return r, g, b, a end
      return r * (1 - SHADE_A) + SHADE[1] * SHADE_A, g * (1 - SHADE_A) + SHADE[2] * SHADE_A,
        b * (1 - SHADE_A) + SHADE[3] * SHADE_A, a
    end)
  end
  return out
end

return crossgame
