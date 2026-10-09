-- Gen 3 player sprites (FireRed, LeafGreen, Ruby, Sapphire, Emerald)
-- None of the sprite registries or hooks Crystal Lens uses exist on Gen 3,
-- so this wraps the engine functions that fetch the player's art instead. Each sheet is
-- looked for in the selected folder first, then the character's other
-- folders, then the game's own sprite. genderMode picks the slot: boy
-- replaces Red/Brendan, girl replaces Leaf/May, and enby replaces both,
-- so the player looks the same whichever gender they pick (Gen 3's text
-- stays the game's own either way). Hoenn rivals share the player's front
-- pic and a few overworld sheets, so for those enby only takes the gender
-- actually picked, leaving the rival as themselves. -Elvie
-- --------------------------------------------------

local gen3 = {}

-- Overworld states. FRLG names its player graphics with OW_PLAYER_*
-- constants; RSE lists them in the avatar table by state instead, with
-- decorating fixed outside it. A state a game doesn't have is skipped.
-- Sheet sizes are in the README. -Elvie
-- --------------------------------------------------
local OW_STATES = {
  { file = "walk.png",         suffix = "",                avatar = "NORMAL" },
  { file = "bike.png",         suffix = "_BIKE",           avatar = "MACH_BIKE" },
  { file = "acroBike.png",                                 avatar = "ACRO_BIKE" },
  { file = "surf.png",         suffix = "_SURF",           avatar = "SURFING" },
  { file = "fieldMove.png",    suffix = "_FIELD_MOVE",     avatar = "FIELD_MOVE" },
  { file = "fishing.png",      suffix = "_FISH",           avatar = "FISHING" },
  { file = "vsSeekerBike.png", suffix = "_VS_SEEKER_BIKE" },
  { file = "underwater.png",                               avatar = "UNDERWATER" },
  { file = "watering.png",                                 avatar = "WATERING" },
  { file = "decorating.png",   rse = { male = 193, female = 194 } },
}

-- Player front pic ids (TRAINER_PIC_RED/LEAF, TRAINER_PIC_BRENDAN/MAY). -Elvie
local FRONT_PIC = {
  firered   = { male = 135, female = 136 },
  leafgreen = { male = 135, female = 136 },
  ruby      = { male = 0,   female = 1 },
  sapphire  = { male = 0,   female = 1 },
  emerald   = { male = 71,  female = 72 },
}

-- Back pic index: 0 is the boy and 1 the girl in every Gen 3 game. -Elvie
local BACK_INDEX = { male = 0, female = 1 }

local SLOTS_FOR_GENDER_MODE = {
  boy = { "male" },
  girl = { "female" },
  enby = { "male", "female" },
}

local ONLY_MALE, ONLY_FEMALE = { "male" }, { "female" }

-- Logs a bad file once instead of every frame it's requested. -Elvie
local warned = {}
local function warnOnce(key, fmt, ...)
  if warned[key] then return end
  warned[key] = true
  print(("[emerald_lens] " .. fmt):format(...))
end

-- ctx comes from lens.lua: { folderKeys, genderMode, spritesDir }, with
-- folderKeys in fallback order, the selected look first. -Elvie
function gen3.init(mod, ctx)
  local slots = SLOTS_FOR_GENDER_MODE[ctx.genderMode]
  local folderKeys = ctx.folderKeys or { ctx.folderKey }
  if not slots or #folderKeys == 0 then return end

  -- The gender the player picked, read the same way the engine's battle
  -- code does. nil before there's a save (the intro). -Elvie
  local function pickedSlot()
    local ok, game = pcall(function() return mod.game end)
    if not ok or type(game) ~= "table" then return nil end
    local g
    if type(game.session) == "table" then g = game.session.gender end
    if g == nil and type(game.save) == "table" then g = game.save.gender end
    if g == nil then return nil end
    return (g == 1 or g == "female" or g == "F") and "female" or "male"
  end

  -- For art the rival can share: an enby character takes only the gender
  -- the player picked. Before there's a save, it takes both. -Elvie
  local function sharedSlots()
    if #slots < 2 then return slots end
    local picked = pickedSlot()
    if picked == nil then return slots end
    return picked == "female" and ONLY_FEMALE or ONLY_MALE
  end

  -- For extras with no boy or girl version (surf blob, Fly bird): only
  -- when this character is the player in this save, so a girl character
  -- doesn't hand her surf blob to someone playing as the boy. -Elvie
  local function isPlayer()
    local picked = pickedSlot()
    if picked == nil then return true end
    for _, slot in ipairs(slots) do
      if slot == picked then return true end
    end
    return false
  end

  local GameVersion = require("src.core.GameVersion")
  local version = GameVersion.get()
  local layout = GameVersion.layout(version)
  if layout ~= "frlg" and layout ~= "rse" then return end

  -- FRLG and RSE sheets differ in size, so each family gets its own
  -- folder: <folder>/gen3/frlg/ or <folder>/gen3/rse/. -Elvie
  local function basesFor(keys)
    local list, seen = {}, {}
    for _, key in ipairs(keys) do
      if key and not seen[key] then
        seen[key] = true
        list[#list + 1] = ctx.spritesDir .. "/" .. key .. "/gen3/" .. layout .. "/"
      end
    end
    return list
  end
  local bases = basesFor(folderKeys)

  local function has(file)
    for _, base in ipairs(bases) do
      if mod.assets:info(base .. file) then return true end
    end
    return false
  end

  -- Loads on first use, from the first folder whose copy is the vanilla
  -- size; a missing or wrong-size copy moves on to the next folder. Hands
  -- back the ImageData too, since water reflections recolor from it. -Elvie
  local function loadImage(file, expectW, expectH)
    if not (love and love.image and love.graphics) then return nil end
    for _, base in ipairs(bases) do
      local rel = base .. file
      if mod.assets:info(rel) then
        local ok, data = pcall(love.image.newImageData, mod.assets:path(rel))
        if not ok or not data then
          warnOnce(rel, "could not load %s; skipping it", rel)
        else
          local w, h = data:getDimensions()
          if w == expectW and h == expectH then
            local image = love.graphics.newImage(data)
            image:setFilter("nearest", "nearest")
            return image, data, rel
          end
          warnOnce(rel, "%s is %dx%d but this slot needs %dx%d; skipping it",
            rel, w, h, expectW, expectH)
        end
      end
    end
    return nil
  end

  -- Overworld
  -- Every walk, bike, surf etc. sheet is fetched through OwSprites.get,
  -- so wrapping it covers drawing, prefetch and reflections at once. -Elvie
  -- ---------------------------------------------
  local okOw, OwSprites = pcall(require, "src.core.game3.ow_sprites")
  local wanted = {}
  for _, state in ipairs(OW_STATES) do
    if has(state.file) then wanted[#wanted + 1] = state end
  end

  -- Graphics ids are looked up on first draw, since the avatar table comes
  -- from the cache manifest and isn't loaded yet when the mod is. -Elvie
  local owFile -- [slot][graphics id] = file
  local function resolveOwFiles()
    owFile = {}
    local okVersions, Versions = pcall(require, "src.import.gba.versions")
    local avatars = type(OwSprites.avatars) == "function" and OwSprites.avatars()
    local rows = type(avatars) == "table" and avatars.player or {}
    for _, slot in ipairs(slots) do
      owFile[slot] = {}
      local prefix = slot == "female" and "OW_PLAYER_FEMALE" or "OW_PLAYER_MALE"
      for _, state in ipairs(wanted) do
        local gid
        for _, row in ipairs(rows) do
          if row.state == state.avatar then gid = tonumber(row[slot]) end
        end
        if not gid and state.suffix and okVersions then
          gid = tonumber(Versions[prefix .. state.suffix])
        end
        if not gid and state[layout] then gid = state[layout][slot] end
        if gid then owFile[slot][gid] = state.file end
      end
    end
  end

  if okOw and type(OwSprites.get) == "function" then
    if #wanted > 0 then
      local originalGet = OwSprites.get
      -- Keyed by the vanilla record, so a cache reload rebuilds ours
      -- instead of reusing a stale one. -Elvie
      local replaced = setmetatable({}, { __mode = "k" })

      local function build(vanilla, file)
        local w, h, n = vanilla.width, vanilla.height, vanilla.frameCount
        if not (w and h and n) then return nil end
        local image, data = loadImage(file, w, h * n)
        if not image then return nil end
        local record = {}
        for k, v in pairs(vanilla) do record[k] = v end
        record.image, record.imageData = image, data
        record.quads = {}
        for fi = 0, n - 1 do
          record.quads[fi] = love.graphics.newQuad(0, fi * h, w, h, w, h * n)
        end
        return record
      end

      OwSprites.get = function(graphicsId)
        local vanilla = originalGet(graphicsId)
        if not owFile then resolveOwFiles() end
        local file
        if vanilla then
          for _, slot in ipairs(sharedSlots()) do
            file = file or owFile[slot][tonumber(graphicsId)]
          end
        end
        if not file then return vanilla end
        local record = replaced[vanilla]
        if record == nil then
          record = build(vanilla, file) or false
          replaced[vanilla] = record
        end
        return record or vanilla
      end
    end
  end

  local frontRel = "front.png"
  -- frontIds is a list to loop over, frontIdOf a per-slot lookup. Kept
  -- apart because R/S's ids (0 and 1) would land on the list's own entries. -Elvie
  local frontIds, frontIdOf, isBackIndex = {}, {}, {}
  for _, slot in ipairs(slots) do
    local id = FRONT_PIC[version] and FRONT_PIC[version][slot]
    if id then frontIds[#frontIds + 1] = id; frontIdOf[slot] = id end
    isBackIndex[BACK_INDEX[slot]] = true
  end

  -- Battle back pic and front pic
  -- The front pic also covers the Hall of Fame and battle mugshot. -Elvie
  -- ---------------------------------------------
  local okPic, TrainerPic = pcall(require, "src.core.game3.trainer_pic")
  if okPic and type(TrainerPic.back) == "function" then
    local backRel = "back.png"
    local replaced = setmetatable({}, { __mode = "k" })

    -- The battle UI builds its back pic quads from the vanilla size, so
    -- a replacement has to match it exactly. -Elvie
    local function swap(vanilla, rel)
      local record = replaced[vanilla]
      if record == nil then
        local image = loadImage(rel, vanilla.w or 64, vanilla.h or 64)
        if image then
          record = {}
          for k, v in pairs(vanilla) do record[k] = v end
          record.image = image
        end
        record = record or false
        replaced[vanilla] = record
      end
      return record or vanilla
    end

    if has(backRel) then
      local originalBack = TrainerPic.back
      TrainerPic.back = function(index)
        local vanilla = originalBack(index)
        if vanilla and isBackIndex[tonumber(index)] then
          return swap(vanilla, backRel)
        end
        return vanilla
      end
    end

    if #frontIds > 0 and has(frontRel) and type(TrainerPic.front) == "function" then
      local originalFront = TrainerPic.front
      TrainerPic.front = function(picId)
        local vanilla = originalFront(picId)
        local mine = false
        for _, slot in ipairs(sharedSlots()) do
          mine = mine or frontIdOf[slot] == tonumber(picId)
        end
        if vanilla and mine then
          return swap(vanilla, frontRel)
        end
        return vanilla
      end
    end
  end

  -- Trainer card portrait, FRLG map icon, Fly bird, surf blob, FRLG bag
  -- All read straight from the cache rather than through a loader, so
  -- they're handed back here in the format the cache file has: raw RGBA
  -- for the pics, sheets and bag, PNG file bytes for the icon.
  -- Hooked at CacheFs.readAt, which every cache read ends in (readActive,
  -- read, and the game's own cache reader in newer builds). Every other
  -- read passes through. -Elvie
  -- ---------------------------------------------
  local cacheSwaps = {}
  if has(frontRel) then
    -- TrainerPic.front loads through this same cache read, so the rival's
    -- battle pic would come through here too: front pics follow the same
    -- picked-gender rule as above. -Elvie
    for _, slot in ipairs(slots) do
      local id = frontIdOf[slot]
      cacheSwaps[#cacheSwaps + 1] = id and { suffix = "trainers/front/" .. id .. ".rgba", slot = slot,
        load = function()
          local _, data = loadImage(frontRel, 64, 64)
          return data and data:getString()
        end } or nil
    end
  end
  if layout == "frlg" and has("mapIcon.png") then
    for _, slot in ipairs(slots) do
      cacheSwaps[#cacheSwaps + 1] = { suffix = "region_map/player_" .. (slot == "female" and "leaf" or "red") .. ".png",
        load = function()
          local _, _, rel = loadImage("mapIcon.png", 16, 16)
          return rel and mod:read(rel)
        end }
    end
  end
  local FRAME = 64 * 64 * 4
  if layout == "frlg" and (has("flyBird.png") or has("bird.png")) then
    -- FRLG draws the rider into the bird's own sheet: frame 0 is the bird
    -- alone, then fly-off and fly-in for the boy (1, 2) and the girl (3, 4).
    -- flyBird.png's two frames are spliced into this character's slots, so
    -- the other gender's frames stay the game's own. bird.png (extras) is
    -- frame 0. Frames are 64x64 RGBA, one after another, so each is a plain
    -- run of bytes. -Elvie
    cacheSwaps[#cacheSwaps + 1] = { suffix = "field_effects/fly_bird.rgba",
      load = function(original, rel, mine)
        local vanilla = original(rel)
        if type(vanilla) ~= "string" or #vanilla ~= FRAME * 5 then return nil end
        local sheet = vanilla
        local _, rider = loadImage("flyBird.png", 64, 128)
        if rider then
          for _, slot in ipairs(slots) do
            local first = (slot == "female" and 3 or 1) * FRAME
            sheet = sheet:sub(1, first) .. rider:getString() .. sheet:sub(first + 2 * FRAME + 1)
          end
        end
        if mine then
          local _, bird = loadImage("bird.png", 64, 64)
          if bird then sheet = bird:getString() .. sheet:sub(FRAME + 1) end
        end
        return sheet ~= vanilla and sheet or nil
      end }
  end

  -- Extras
  -- The surf blob (and RSE's Fly bird) have no boy or girl version, so
  -- they only apply when this character is the player (isPlayer). The bag
  -- does have one each, so it follows the character's slots like the
  -- sprites. RSE's bag is a PNG, swapped in the scene kit below. -Elvie
  local EXTRAS = {
    frlg = { surfBlob = { 32, 192 }, bag = { 64, 256 } },
    rse  = { surfBlob = { 32, 96 },  bird = { 32, 32 } },
  }
  local extras = EXTRAS[layout]
  local function rgbaOf(file, w, h)
    return function()
      local _, data = loadImage(file, w, h)
      return data and data:getString()
    end
  end
  if extras.surfBlob and has("surfBlob.png") then
    cacheSwaps[#cacheSwaps + 1] = { suffix = "field_effects/surf_blob.rgba", player = true,
      load = rgbaOf("surfBlob.png", extras.surfBlob[1], extras.surfBlob[2]) }
  end
  if extras.bird and has("bird.png") then
    cacheSwaps[#cacheSwaps + 1] = { suffix = "field_effects/bird.rgba", player = true,
      load = rgbaOf("bird.png", extras.bird[1], extras.bird[2]) }
  end
  if extras.bag and has("bag.png") then
    for _, slot in ipairs(slots) do
      cacheSwaps[#cacheSwaps + 1] = { suffix = "items/bag/bag_" .. slot .. ".rgba",
        load = rgbaOf("bag.png", extras.bag[1], extras.bag[2]) }
    end
  end
  local okFs, CacheFs = pcall(require, "src.import.CacheFs")
  if #cacheSwaps > 0 and okFs and type(CacheFs.readAt) == "function" then
    local originalReadAt = CacheFs.readAt
    CacheFs.readAt = function(rel, ...)
      if type(rel) == "string" then
        for _, swap in ipairs(cacheSwaps) do
          if rel:sub(-#swap.suffix) == swap.suffix then
            local wanted = not swap.slot
            if swap.slot then
              for _, slot in ipairs(sharedSlots()) do wanted = wanted or slot == swap.slot end
            end
            local mine = isPlayer()
            if swap.player and not mine then wanted = false end
            if wanted then
              -- Kept per isPlayer answer, since the Fly sheet differs by it.
              -- false = failed. -Elvie
              swap.bytes = swap.bytes or {}
              local key = mine and "mine" or "other"
              if swap.bytes[key] == nil then swap.bytes[key] = swap.load(originalReadAt, rel, mine) or false end
              if swap.bytes[key] then return swap.bytes[key] end
            end
          end
        end
      end
      return originalReadAt(rel, ...)
    end
  end

  -- New game intro portrait (and RSE's map icon)
  -- FRLG's Oak speech uses its own full-body pic, so intro.png goes into
  -- a copy of the scene's assets (Boot's own table stays untouched). -Elvie
  -- ---------------------------------------------
  if layout == "frlg" then
    local introRel = "intro.png"
    local okScene, NewGameScene = pcall(require, "src.ui.game3.new_game_scene")
    if has(introRel) and okScene and type(NewGameScene.new) == "function" then
      local originalNew = NewGameScene.new
      local introImage -- nil = not loaded yet, false = load failed -Elvie
      NewGameScene.new = function(assets, ...)
        if introImage == nil then introImage = loadImage(introRel, 64, 96) or false end
        if introImage and type(assets) == "table" then
          local copy = {}
          for k, v in pairs(assets) do copy[k] = v end
          for _, slot in ipairs(slots) do
            copy[slot == "female" and "girlSprite" or "boySprite"] = introImage
          end
          assets = copy
        end
        return originalNew(assets, ...)
      end
    end
  elseif layout == "rse" then
    -- The RSE intro, R/S trainer card, region map, PokeNav map, Pokedex
    -- area map and bag all load through the scene kit, so one wrapper covers
    -- them: front.png for the portraits, mapIcon.png for the map marker,
    -- bag.png for the bag. -Elvie
    local okKit, Kit = pcall(require, "src.ui.game3.rse.scene_kit")
    local kitSwaps = {}
    for _, slot in ipairs(slots) do
      local who = slot == "female" and "may" or "brendan"
      if has(frontRel) then
        kitSwaps[#kitSwaps + 1] = { suffix = "birch/" .. who .. ".png", file = frontRel, w = 64, h = 64 }
        kitSwaps[#kitSwaps + 1] = { suffix = "rse/trainer_card/" .. slot .. ".png", file = frontRel, w = 64, h = 64 }
      end
      if has("mapIcon.png") then
        kitSwaps[#kitSwaps + 1] = { suffix = "rse/region_map/" .. who .. "_icon.png", file = "mapIcon.png", w = 16, h = 16 }
      end
      if has("bag.png") then
        kitSwaps[#kitSwaps + 1] = { suffix = "rse/bag/bag_" .. slot .. ".png", file = "bag.png", w = 64, h = 384 }
      end
    end
    if #kitSwaps > 0 and okKit and type(Kit.image) == "function" then
      local originalImage = Kit.image
      Kit.image = function(path, ...)
        if type(path) == "string" then
          for _, swap in ipairs(kitSwaps) do
            if path:sub(-#swap.suffix) == swap.suffix then
              if swap.image == nil then swap.image = loadImage(swap.file, swap.w, swap.h) or false end
              if swap.image then return swap.image end
            end
          end
        end
        return originalImage(path, ...)
      end
    end
  end
end

return gen3
