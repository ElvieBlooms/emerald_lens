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
    ["fieldMove.png"]    = { from = "fieldMove", w = 16, h = 32, n = 9, alt = { from = "walk", frames = ALL_FIRST } },
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

-- The family a "fromGame" look is offered in: the other one. -Elvie
function crossgame.familyFor(meta)
  local which = playerOf(meta)
  if not which then return nil end
  return PLAYERS[which].family == "frlg" and "rse" or "frlg"
end

function crossgame.register(base, meta)
  registered[base] = playerOf(meta)
end

function crossgame.isBase(base)
  return registered[base] ~= nil
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

function crossgame.has(mod, base, file, layout)
  return plan(mod, base, file, layout) ~= nil
end

function crossgame.load(mod, base, file, layout)
  if not (love and love.image) then return nil end
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
