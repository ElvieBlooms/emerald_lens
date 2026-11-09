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
-- "dawn", "barry", "nate", "rosa", "hugh", "hilbert" or "hilda") is that
-- player or rival from the DS games, read from the player's own
-- HeartGold/SoulSilver, Diamond/Pearl/Platinum or Black 2/White 2 dump
-- through Prism Importer (a separate mod; its exports hand out the
-- sprites once the dump is imported from IMPORTER in PRISM). Those looks
-- are offered in every game. Walking, running, the bike, surfing,
-- fishing and sending out a Pokemon come from the overworld sheets; the
-- battle pics are the DS trainer pics cut to 64x64. What a dump has no
-- art for stands in with standing frames, as for the Gen 3 players above.
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
-- sprites before Diamond/Pearl's, which a Platinum dump also has (its
-- "hero" and "heroine" are the D/P outfits; pl_boy01c and pl_girl01c
-- match Platinum's pics and bikes). Backs 00-02 are a dump's own
-- players and rival; a Platinum dump keeps D/P's as 08-10. The
-- B2W2 dump keeps people it has no name for by their object number, and
-- has Hilbert and Hilda's overworld sprites (for the Memory Link) but no
-- trainer pics of them, so their battle pics come from the game.
-- Sheets: walk (walking, then running), bike, swim (sitting on the SURF
-- Pokemon), fish, use (sending out a Pokemon, facing down)
local DS = {
  ethan   = { game = "hgss", gen = 4, name = "HG/SS", walk = { "hero" }, bike = { "cyclehero" },
              swim = { "swimhero" }, fish = { "fishinghero" },
              front = { "front/pkmn_trainer_ethan" }, back = { "back/00" } },
  lyra    = { game = "hgss", gen = 4, name = "HG/SS", walk = { "heroine" }, bike = { "cycleheroine" },
              swim = { "swimheroine" }, fish = { "fish_heroine" },
              front = { "front/pkmn_trainer_lyra" }, back = { "back/01" } },
  silver  = { game = "hgss", gen = 4, name = "HG/SS", walk = { "gsrivel" },
              front = { "front/rival" }, back = { "back/02" } },
  lucas   = { game = "dppt", gen = 4, name = "D/P/Pt", walk = { "pl_boy01c", "hero" }, bike = { "pl_cyclehero", "cyclehero" },
              swim = { "pl_swimhiro" }, fish = { "pl_fishhero" }, use = { "pl_sphero" },
              front = { "front/player_male", "front/dp_player_male" }, back = { "back/00" } },
  dawn    = { game = "dppt", gen = 4, name = "D/P/Pt", walk = { "pl_girl01c", "heroine" }, bike = { "pl_cycheroine", "cycleheroine" },
              swim = { "pl_swimhiroine" }, fish = { "pl_fheroine" }, use = { "pl_spheroine" },
              front = { "front/player_female", "front/dp_player_female" }, back = { "back/01" } },
  barry   = { game = "dppt", gen = 4, name = "D/P/Pt", walk = { "rivel" },
              front = { "front/rival" }, back = { "back/02" } },
  nate    = { game = "bw2", gen = 5, name = "B2W2", walk = { "hero" }, bike = { "232" },
              swim = { "238" }, fish = { "239" }, use = { "237" },
              front = { "front/pkmn_trainer_nate" }, back = { "back/pkmn_trainer_nate" } },
  rosa    = { game = "bw2", gen = 5, name = "B2W2", walk = { "heroine" }, bike = { "241" },
              swim = { "247" }, fish = { "248" }, use = { "246" },
              front = { "front/pkmn_trainer_rosa" }, back = { "back/pkmn_trainer_rosa" } },
  hugh    = { game = "bw2", gen = 5, name = "B2W2", walk = { "291" },
              front = { "front/pkmn_trainer_rival" }, back = { "back/pkmn_trainer_rival" } },
  hilbert = { game = "bw2", gen = 5, name = "B2W2", walk = { "001" }, bike = { "002" },
              swim = { "158" }, fish = { "160" }, use = { "156" } },
  hilda   = { game = "bw2", gen = 5, name = "B2W2", walk = { "004" }, bike = { "005" },
              swim = { "159" }, fish = { "161" }, use = { "157" } },
}
crossgame.DS = DS

local function dsOf(meta)
  local which = type(meta) == "table" and type(meta.fromDS) == "string" and meta.fromDS:lower()
  return which and DS[which] and which or nil
end
crossgame.dsOf = dsOf

-- Where a frame is on each kind of DS sheet. Facings go up, down, left,
-- right (B2W2's fishing has no right); "per" frames each. Walking and
-- biking are stand, step, stand, step on the HG/SS and D/P/Pt sheets and
-- stand, step, step on B2W2's, with running after walking. Swimming is a
-- frame per facing on the Gen 4 sheets; B2W2's has four, sitting twice
-- then upright twice. Fishing is the cast in four frames. Sending out a
-- Pokemon only faces down. A sheet without running (the rivals') walks.
local UP, DOWN, LEFT = 0, 1, 2
local GEO = {
  [4] = { walk = { per = 4, slots = { [0] = 0, 1, 3 }, run = 16 },
          bike = { per = 4, slots = { [0] = 0, 1, 3 } },
          swim = { per = 1, slots = { [0] = 0 } },
          fish = { per = 4, slots = { [0] = 0, 1, 2, 3 } },
          use  = { per = 0, slots = { [0] = 0, 1, 2, 3 } } },
  [5] = { walk = { per = 3, slots = { [0] = 0, 1, 2 }, run = 12 },
          bike = { per = 3, slots = { [0] = 0, 1, 2 } },
          swim = { per = 4, slots = { [0] = 0, 1, 2, 3 } },
          fish = { per = 4, slots = { [0] = 0, 1, 2, 3 } },
          use  = { per = 0, slots = { [0] = 0, 1, 2, 3 } } },
}

-- A wanted frame: which sheet, facing, slot (0 the stand, 1 and 2 the
-- steps on walking sheets) and whether it's running
local function want(kind, facing, slot, run) return { kind = kind, facing = facing, slot = slot or 0, run = run } end

-- Its frame number on a sheet of n frames, or nil
local function dsIndex(geo, w, n)
  local i = w.facing * geo.per + (geo.slots[w.slot] or geo.slots[0])
  if w.run and geo.run and geo.run + i < n then return geo.run + i end
  return i < n and i or nil
end

-- Gen 3's facings: down, up, left
local G3 = { [0] = DOWN, UP, LEFT }
-- Gen 3's 9-frame order: a stand per facing, then two steps each
local function walkAt(kind, i, run)
  if i < 3 then return want(kind, G3[i], 0, run) end
  return want(kind, G3[math.floor((i - 3) / 2)], 1 + (i - 3) % 2, run)
end
local function standOf(i)
  if i < 3 then return G3[i] elseif i < 9 then return G3[math.floor((i - 3) / 2)] else return G3[(i - 9) % 3] end
end
local function walkStand(i) return want("walk", standOf(i), 0) end

-- What each frame of a Gen 3 sheet is, as wanted frames in order of
-- preference. FR/LG runs three frames a facing (9-11 down, 12-14 up,
-- 15-17 left) and shakes its head with the down steps (18, 19); R/S/E a
-- stand per facing (9-11), then two steps each (12-17)
local function frlgWalk(i)
  if i < 9 then return { walkAt("walk", i) } end
  if i >= 18 then return { walkAt("walk", 3 + (i - 18)) } end
  local n, k = math.floor((i - 9) / 3), (i - 9) % 3
  return { want("walk", G3[n], k, true) }
end
local function rseWalk(i)
  if i < 9 then return { walkAt("walk", i) } end
  if i < 12 then return { want("walk", G3[i - 9], 0, true) } end
  return { want("walk", G3[math.floor((i - 12) / 2)], 1 + (i - 12) % 2, true) }
end
local function bike(i) return { walkAt("bike", i) } end
local function acro(i) return { walkAt("bike", ACRO[i] or i) } end
-- Surfing: sitting for the stands, the two sitting frames for the steps,
-- and upright for 9-11 (getting on and off, field moves from the water)
local function surf(i)
  local slot = 0
  if i >= 9 then slot = 2 elseif i >= 3 then slot = (i - 3) % 2 end
  return { want("swim", standOf(i), slot), walkStand(i) }
end
-- Fishing is left, up, down in fours
local FISH_FACING = { [0] = LEFT, UP, DOWN }
local function fish(i)
  local facing = FISH_FACING[math.floor(i / 4)] or DOWN
  return { want("fish", facing, i % 4), want("walk", facing, 0) }
end
-- A field move: sending out a Pokemon for 0-4, FR/LG's VS Seeker stands
local function fieldMove(i)
  if i > 4 then return { want("walk", DOWN, 0) } end
  return { want("use", DOWN, math.min(i, 3)), want("walk", DOWN, 0) }
end
-- The game moves some fishing frames as it draws them (ow_sprites.lua
-- fishingOffset, from AlignFishingAnimationFrames): the casting left
-- frames 8 left, the up line-out 8 up, the down line-out 8 down. Its own
-- art is drawn the other way in the frame, so the DS art is too, which
-- also gives the rod room
local FISH_NUDGE = { [1] = { 8, 0 }, [2] = { 8, 0 }, [3] = { 8, 0 }, [5] = { 0, 8 }, [10] = { 0, -8 }, [11] = { 0, -8 } }
local function dive(i) return { want("swim", G3[DIVE[i] or 0], 0), want("walk", G3[DIVE[i] or 0], 0) } end
local function standing(kind) return function() return { want(kind, DOWN, 0) } end end

-- What each sheet is made of, by running layout: the DS sheet it needs,
-- the frame size and count here, the frames, and the row the standing
-- frames' feet go on (GAME_FEET in pack_gen3.py)
local DS_SHEETS = {
  frlg = {
    ["walk.png"]         = { from = "walk", w = 32, h = 32, n = 20, at = frlgWalk, feet = 30 },
    ["bike.png"]         = { from = "bike", w = 32, h = 32, n = 9, at = bike, feet = 31 },
    ["surf.png"]         = { from = "walk", w = 32, h = 32, n = 12, at = surf, feet = 29 },
    ["fieldMove.png"]    = { from = "walk", w = 32, h = 32, n = 9, at = fieldMove, feet = 30 },
    ["fishing.png"]      = { from = "walk", w = 32, h = 32, n = 12, at = fish, feet = 30, nudge = FISH_NUDGE },
    ["vsSeekerBike.png"] = { from = "bike", w = 32, h = 32, n = 6, at = standing("bike"), feet = 31 },
  },
  rse = {
    ["walk.png"]       = { from = "walk", w = 32, h = 32, n = 18, at = rseWalk, feet = 30 },
    ["bike.png"]       = { from = "bike", w = 32, h = 32, n = 9, at = bike, feet = 31 },
    ["acroBike.png"]   = { from = "bike", w = 32, h = 32, n = 27, at = acro, feet = 31 },
    ["surf.png"]       = { from = "walk", w = 32, h = 32, n = 12, at = surf, feet = 30 },
    ["fieldMove.png"]  = { from = "walk", w = 32, h = 32, n = 5, at = fieldMove, feet = 30 },
    ["fishing.png"]    = { from = "walk", w = 32, h = 32, n = 12, at = fish, feet = 30, nudge = FISH_NUDGE },
    ["underwater.png"] = { from = "walk", w = 32, h = 32, n = 9, at = dive, feet = 30, dive = true },
    ["watering.png"]   = { from = "walk", w = 32, h = 32, n = 9, at = function(i) return { walkAt("walk", i) } end, feet = 30 },
    ["decorating.png"] = { from = "walk", w = 32, h = 32, n = 1, at = standing("walk"), feet = 30 },
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
-- has. quiet for the sheets that only stand in for something
local function dsSource(mod, which, kind, quiet)
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
  if not data and spec[kind] and not quiet and not warned[key] then
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

-- Which DS frame each frame of a sheet is, as "kind:frame" (or false),
-- given how many frames each of that player's DS sheets has. For the
-- checks in tools/wording.
function crossgame.dsFrames(which, layout, file, counts)
  local sheet = DS_SHEETS[layout] and DS_SHEETS[layout][file]
  if not (sheet and DS[which]) then return nil end
  local out = {}
  for i = 0, sheet.n - 1 do
    out[i] = false
    for _, w in ipairs(sheet.at(i)) do
      local geo, n = GEO[DS[which].gen][w.kind], counts[w.kind]
      local f = geo and n and dsIndex(geo, w, n)
      if f then out[i] = w.kind .. ":" .. f break end
    end
  end
  return out
end

-- An overworld sheet for the running layout: each frame centred, and
-- each DS sheet moved so its standing frames' feet are on the game's row
-- (whatever hangs below them, a fishing line, is cut off). A frame the
-- dump has no art for takes the next one wanted, in the end a stand.
local function dsOverworld(mod, which, sheet)
  if not dsSource(mod, which, sheet.from) then return nil end
  local gen = DS[which].gen
  local out = love.image.newImageData(sheet.w, sheet.h * sheet.n)
  local lows = {}
  for i = 0, sheet.n - 1 do
    for _, w in ipairs(sheet.at(i)) do
      local src = dsSource(mod, which, w.kind, w.kind ~= sheet.from)
      local geo = GEO[gen][w.kind]
      local f = src and geo and dsIndex(geo, w, src.n)
      if f then
        if lows[w.kind] == nil then
          local stands = {}
          for _, facing in ipairs({ UP, DOWN, LEFT }) do
            stands[#stands + 1] = dsIndex(geo, want(w.kind, facing, 0), src.n)
          end
          lows[w.kind] = lowestRow(src, stands) or false
        end
        local low = lows[w.kind]
        local oy = low and (sheet.feet - low) or (sheet.h - src.h)
        local ox = math.floor((sheet.w - src.w) / 2)
        local nudge = sheet.nudge and sheet.nudge[i]
        if nudge then ox, oy = ox + nudge[1], oy + nudge[2] end
        local fx, fy = frameAt(src, f)
        local x0, x1 = math.max(0, -ox), math.min(src.w, sheet.w - ox)
        local y0, y1 = math.max(0, -oy), math.min(src.h, sheet.h - oy)
        if x1 > x0 and y1 > y0 then
          out:paste(src.image, x0 + ox, i * sheet.h + y0 + oy, fx + x0, fy + y0, x1 - x0, y1 - y0)
        end
        break
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

-- Whether a DS look's dump is imported in Prism Importer. Looks whose
-- dump isn't there aren't offered at all.
function crossgame.dsReady(mod, meta)
  local which = dsOf(meta)
  local api = which and importer(mod)
  if not (api and type(api.status) == "function") then return false end
  local ok, status = pcall(api.status)
  local st = ok and type(status) == "table" and status[DS[which].game] or nil
  return type(st) == "table" and st.state == "ready"
end

-- Whether Prism Importer is installed
function crossgame.hasImporter(mod)
  return importer(mod) ~= nil
end

-- Whether a look is offered in a family: a Gen 3 player in the family
-- it isn't from and in the Game Boy games, a DS player everywhere once
-- its dump is imported
function crossgame.offeredIn(meta, family, mod)
  if dsOf(meta) then return mod ~= nil and crossgame.dsReady(mod, meta) end
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
