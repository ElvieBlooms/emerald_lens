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
--
-- The wrappers go in once and read the current choice each time, so
-- picking another character in the options takes effect straight away:
-- configure() swaps the choice and drops anything already built. -Elvie
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

local ONLY_MALE, ONLY_FEMALE, NONE = { "male" }, { "female" }, {}

-- Extras with no boy or girl version get the isPlayer check; the bag has
-- one each. Sizes are the whole strip. RSE's bag is a PNG, swapped in the
-- scene kit below. -Elvie
local EXTRAS = {
  frlg = { surfBlob = { 32, 192 }, bag = { 64, 256 } },
  rse  = { surfBlob = { 32, 96 },  bird = { 32, 32 } },
}

local FRAME = 64 * 64 * 4 -- one 64x64 RGBA frame of the FRLG Fly sheet

-- Logs a bad file once instead of every frame it's requested. -Elvie
local warned = {}
local function warnOnce(key, fmt, ...)
  if warned[key] then return end
  warned[key] = true
  print(("[emerald_lens] " .. fmt):format(...))
end

-- ctx comes from lens.lua: { folderKeys, genderMode, spritesDir }, with
-- folderKeys in fallback order, the selected look first. nil means OFF:
-- everything passes through to the game's own art. Returns a handle whose
-- configure(ctx) changes the choice later. -Elvie
function gen3.init(mod, ctx)
  local GameVersion = require("src.core.GameVersion")
  local version = GameVersion.get()
  local layout = GameVersion.layout(version)
  if layout ~= "frlg" and layout ~= "rse" then return nil end
  local extras = EXTRAS[layout]

  -- The current choice. Everything below reads these, so configure() only
  -- has to replace them. -Elvie
  local slots = NONE
  local bases = {}
  local present = {} -- [file] = true if any folder in the chain has it
  local frontIdOf, isBackIndex = {}, {}

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
    if #slots == 0 then return false end
    local picked = pickedSlot()
    if picked == nil then return true end
    for _, slot in ipairs(slots) do
      if slot == picked then return true end
    end
    return false
  end

  local function has(file)
    return present[file] == true
  end

  -- Loads on first use, from the first folder whose copy is the vanilla
  -- size (or altW wide, where a wider frame is allowed); a missing or
  -- wrong-size copy moves on to the next folder. Hands back the ImageData
  -- too, since water reflections recolor from it, and the width found. -Elvie
  local function loadImage(file, expectW, expectH, altW)
    if not (love and love.image and love.graphics) then return nil end
    for _, base in ipairs(bases) do
      local rel = base .. file
      if mod.assets:info(rel) then
        local ok, data = pcall(love.image.newImageData, mod.assets:path(rel))
        if not ok or not data then
          warnOnce(rel, "could not load %s; skipping it", rel)
        else
          local w, h = data:getDimensions()
          if (w == expectW or (altW and w == altW)) and h == expectH then
            local image = love.graphics.newImage(data)
            image:setFilter("nearest", "nearest")
            return image, data, rel, w
          end
          warnOnce(rel, "%s is %dx%d but this slot needs %dx%d%s; skipping it",
            rel, w, h, expectW, expectH, altW and (" or %dx%d"):format(altW, expectH) or "")
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

  -- Graphics ids are looked up on first draw, since the avatar table comes
  -- from the cache manifest and isn't loaded yet when the mod is. -Elvie
  local owFile -- [slot][graphics id] = file; nil = look up again
  local owReplaced -- keyed by the vanilla record, so a cache reload rebuilds ours -Elvie
  local function resolveOwFiles()
    owFile = {}
    local okVersions, Versions = pcall(require, "src.import.gba.versions")
    local avatars = type(OwSprites.avatars) == "function" and OwSprites.avatars()
    local rows = type(avatars) == "table" and avatars.player or {}
    for _, slot in ipairs(slots) do
      owFile[slot] = {}
      local prefix = slot == "female" and "OW_PLAYER_FEMALE" or "OW_PLAYER_MALE"
      for _, state in ipairs(OW_STATES) do
        if has(state.file) then
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
  end

  if okOw and type(OwSprites.get) == "function" then
    local originalGet = OwSprites.get

    -- Sheets with 16-wide frames can also come 32 wide, for characters
    -- drawn bigger than the game's own (Gen 4 sprites, say). The engine
    -- draws any frame centred on the tile with the feet on its bottom edge,
    -- so only the width changes. -Elvie
    local function build(vanilla, file)
      local w, h, n = vanilla.width, vanilla.height, vanilla.frameCount
      if not (w and h and n) then return nil end
      local image, data, _, gotW = loadImage(file, w, h * n, w == 16 and 32 or nil)
      if not image then return nil end
      w = gotW or w
      local record = {}
      for k, v in pairs(vanilla) do record[k] = v end
      record.image, record.imageData, record.width = image, data, w
      record.quads = {}
      for fi = 0, n - 1 do
        record.quads[fi] = love.graphics.newQuad(0, fi * h, w, h, w, h * n)
      end
      return record
    end

    OwSprites.get = function(graphicsId)
      local vanilla = originalGet(graphicsId)
      if not vanilla or #slots == 0 then return vanilla end
      if not owFile then resolveOwFiles() end
      local file
      for _, slot in ipairs(sharedSlots()) do
        file = file or (owFile[slot] and owFile[slot][tonumber(graphicsId)])
      end
      if not file then return vanilla end
      local record = owReplaced[vanilla]
      if record == nil then
        record = build(vanilla, file) or false
        owReplaced[vanilla] = record
      end
      return record or vanilla
    end
  end

  -- Battle back pic and front pic
  -- The front pic also covers the Hall of Fame and battle mugshot. -Elvie
  -- ---------------------------------------------
  local frontRel, backRel = "front.png", "back.png"
  local picReplaced
  local okPic, TrainerPic = pcall(require, "src.core.game3.trainer_pic")
  if okPic and type(TrainerPic.back) == "function" then
    -- The battle UI builds its back pic quads from the vanilla size, so
    -- a replacement has to match it exactly. -Elvie
    local function swap(vanilla, rel)
      local record = picReplaced[vanilla]
      if record == nil then
        local image = loadImage(rel, vanilla.w or 64, vanilla.h or 64)
        if image then
          record = {}
          for k, v in pairs(vanilla) do record[k] = v end
          record.image = image
        end
        record = record or false
        picReplaced[vanilla] = record
      end
      return record or vanilla
    end

    local originalBack = TrainerPic.back
    TrainerPic.back = function(index)
      local vanilla = originalBack(index)
      if vanilla and has(backRel) and isBackIndex[tonumber(index)] then
        return swap(vanilla, backRel)
      end
      return vanilla
    end

    if type(TrainerPic.front) == "function" then
      local originalFront = TrainerPic.front
      TrainerPic.front = function(picId)
        local vanilla = originalFront(picId)
        if not (vanilla and has(frontRel)) then return vanilla end
        local mine = false
        for _, slot in ipairs(sharedSlots()) do
          mine = mine or frontIdOf[slot] == tonumber(picId)
        end
        if mine then return swap(vanilla, frontRel) end
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
  -- read passes through. The list is rebuilt by configure(). -Elvie
  -- ---------------------------------------------
  local cacheSwaps = {}
  local function rgbaOf(file, w, h)
    return function()
      local _, data = loadImage(file, w, h)
      return data and data:getString()
    end
  end

  local function buildCacheSwaps()
    local list = {}
    if has(frontRel) then
      -- TrainerPic.front loads through this same cache read, so the rival's
      -- battle pic would come through here too: front pics follow the same
      -- picked-gender rule as above. -Elvie
      for _, slot in ipairs(slots) do
        local id = frontIdOf[slot]
        if id then
          list[#list + 1] = { suffix = "trainers/front/" .. id .. ".rgba", slot = slot,
            load = rgbaOf(frontRel, 64, 64) }
        end
      end
    end
    if layout == "frlg" and has("mapIcon.png") then
      for _, slot in ipairs(slots) do
        list[#list + 1] = { suffix = "region_map/player_" .. (slot == "female" and "leaf" or "red") .. ".png",
          load = function()
            local _, _, rel = loadImage("mapIcon.png", 16, 16)
            return rel and mod:read(rel)
          end }
      end
    end
    if layout == "frlg" and (has("flyBird.png") or has("bird.png")) then
      -- FRLG draws the rider into the bird's own sheet: frame 0 is the bird
      -- alone, then fly-off and fly-in for the boy (1, 2) and the girl (3, 4).
      -- flyBird.png's two frames are spliced into this character's slots, so
      -- the other gender's frames stay the game's own. bird.png (extras) is
      -- frame 0. Frames are 64x64 RGBA, one after another, so each is a plain
      -- run of bytes. -Elvie
      list[#list + 1] = { suffix = "field_effects/fly_bird.rgba",
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
    if extras.surfBlob and has("surfBlob.png") then
      list[#list + 1] = { suffix = "field_effects/surf_blob.rgba", player = true,
        load = rgbaOf("surfBlob.png", extras.surfBlob[1], extras.surfBlob[2]) }
    end
    if extras.bird and has("bird.png") then
      list[#list + 1] = { suffix = "field_effects/bird.rgba", player = true,
        load = rgbaOf("bird.png", extras.bird[1], extras.bird[2]) }
    end
    if extras.bag and has("bag.png") then
      for _, slot in ipairs(slots) do
        list[#list + 1] = { suffix = "items/bag/bag_" .. slot .. ".rgba",
          load = rgbaOf("bag.png", extras.bag[1], extras.bag[2]) }
      end
    end
    return list
  end

  local okFs, CacheFs = pcall(require, "src.import.CacheFs")
  if okFs and type(CacheFs.readAt) == "function" then
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

  -- New game intro portrait (and RSE's map icon and bag)
  -- FRLG's Oak speech uses its own full-body pic, so intro.png goes into
  -- a copy of the scene's assets (Boot's own table stays untouched). -Elvie
  -- ---------------------------------------------
  local introImage -- nil = not loaded yet, false = load failed -Elvie
  local kitSwaps = {}
  local introRel = "intro.png"
  if layout == "frlg" then
    local okScene, NewGameScene = pcall(require, "src.ui.game3.new_game_scene")
    if okScene and type(NewGameScene.new) == "function" then
      local originalNew = NewGameScene.new
      NewGameScene.new = function(assets, ...)
        if has(introRel) and introImage == nil then introImage = loadImage(introRel, 64, 96) or false end
        if has(introRel) and introImage and type(assets) == "table" then
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
    if okKit and type(Kit.image) == "function" then
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

  local function buildKitSwaps()
    local list = {}
    if layout ~= "rse" then return list end
    for _, slot in ipairs(slots) do
      local who = slot == "female" and "may" or "brendan"
      if has(frontRel) then
        list[#list + 1] = { suffix = "birch/" .. who .. ".png", file = frontRel, w = 64, h = 64 }
        list[#list + 1] = { suffix = "rse/trainer_card/" .. slot .. ".png", file = frontRel, w = 64, h = 64 }
      end
      if has("mapIcon.png") then
        list[#list + 1] = { suffix = "rse/region_map/" .. who .. "_icon.png", file = "mapIcon.png", w = 16, h = 16 }
      end
      if has("bag.png") then
        list[#list + 1] = { suffix = "rse/bag/bag_" .. slot .. ".png", file = "bag.png", w = 64, h = 384 }
      end
    end
    return list
  end

  -- Engine caches
  -- A few screens keep what they loaded. On a change of character these
  -- are dropped so they load again, through the wrappers above. -Elvie
  -- ---------------------------------------------
  local function dropEngineCaches()
    local L = package.loaded
    local pic = L["src.core.game3.trainer_pic"]
    local ids = FRONT_PIC[version]
    if type(pic) == "table" and type(pic._front) == "table" and ids then
      pic._front[ids.male], pic._front[ids.female] = nil, nil
    end
    local fx = L["src.core.game3.field_effects"]
    if type(fx) == "table" and type(fx._sheets) == "table" then
      fx._sheets.surf_blob, fx._sheets.bird, fx._sheets.fly_bird = nil, nil, nil
    end
    local bag = L["src.ui.game3.bag_chrome"]
    if type(bag) == "table" then
      bag._bagMale, bag._bagFemale = nil, nil
      bag._bagQuads, bag._bagData, bag._rotated = {}, {}, {}
    end
    local gpu = L["src.ui.game3.region_map_gpu"]
    if type(gpu) == "table" and type(gpu.images) == "table" then
      gpu.images.player_red, gpu.images.player_leaf = nil, nil
    end
  end

  -- configure
  -- Takes a new ctx (or nil for OFF) and starts over from it: new fallback
  -- chain and slots, nothing built yet. -Elvie
  -- ---------------------------------------------
  local configured = false
  local function configure(newCtx)
    slots = newCtx and SLOTS_FOR_GENDER_MODE[newCtx.genderMode] or NONE
    local folderKeys = newCtx and (newCtx.folderKeys or { newCtx.folderKey }) or {}
    if #folderKeys == 0 then slots = NONE end

    -- FRLG and RSE sheets differ in size, so each family gets its own
    -- folder: <folder>/gen3/frlg/ or <folder>/gen3/rse/. -Elvie
    bases = {}
    local seen = {}
    for _, key in ipairs(folderKeys) do
      if key and not seen[key] then
        seen[key] = true
        bases[#bases + 1] = newCtx.spritesDir .. "/" .. key .. "/gen3/" .. layout .. "/"
      end
    end

    -- Which files exist anywhere in the chain, checked once here rather
    -- than on every draw. -Elvie
    present = {}
    if #slots > 0 then
      local files = { frontRel, backRel, introRel, "mapIcon.png", "flyBird.png", "surfBlob.png", "bird.png", "bag.png" }
      for _, state in ipairs(OW_STATES) do files[#files + 1] = state.file end
      for _, file in ipairs(files) do
        for _, base in ipairs(bases) do
          if mod.assets:info(base .. file) then present[file] = true end
        end
      end
    end

    frontIdOf, isBackIndex = {}, {}
    for _, slot in ipairs(slots) do
      frontIdOf[slot] = FRONT_PIC[version] and FRONT_PIC[version][slot]
      isBackIndex[BACK_INDEX[slot]] = true
    end

    owFile = nil
    owReplaced = setmetatable({}, { __mode = "k" })
    picReplaced = setmetatable({}, { __mode = "k" })
    introImage = nil
    cacheSwaps = buildCacheSwaps()
    kitSwaps = buildKitSwaps()
    if configured then dropEngineCaches() end
    configured = true
  end

  configure(ctx)
  return { configure = configure }
end

return gen3
