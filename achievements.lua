-- Achievements
-- With Recomp Achievements installed, Emerald Lens adds its own, on a
-- LENS tab of their own (they count on its Extra Credit board). Without
-- it, nothing here runs. See Recomp Achievements' docs/PROVIDER_API.md.
-- --------------------------------------------------

local achievements = {}

local GEN3 = { "firered", "leafgreen", "ruby", "sapphire", "emerald" }
local GAME_BOY = { "red", "blue", "yellow", "gold", "silver", "crystal" }

-- Ids never change once released: the player's records are kept by id.
local LIST = {
  { id = "fresh_look", title = "Fresh Look", points = 2,
    description = "Play with a look on." },
  { id = "behind_the_lens", title = "Behind the Lens", points = 1,
    description = "Open the LENS screen." },
  { id = "wardrobe", title = "Wardrobe", points = 15, goal = 10, unit = "LOOKS",
    description = "Wear 10 different looks in one save." },
  { id = "old_school", title = "Old School", points = 5, games = GEN3,
    description = "Wear a Game Boy look in FireRed, LeafGreen, Ruby, Sapphire or Emerald." },
  { id = "new_tricks", title = "New Tricks", points = 5, games = GAME_BOY,
    description = "Wear a Gen 3 or Gen 4 look in Red, Blue, Yellow, Gold, Silver or Crystal." },
  { id = "across_the_sea", title = "Across the Sea", points = 5, games = GEN3,
    description = "Play as RED or LEAF in Hoenn, or as BRENDAN or MAY in Kanto." },
  { id = "frenemies", title = "Frenemies", points = 10,
    description = "Battle your rival while they wear a look." },
  { id = "mirror_match", title = "Mirror Match", points = 15,
    description = "Battle a rival wearing the same character as you." },
  { id = "surfs_up", title = "Surf's Up", points = 5,
    description = "Surf on a Pokemon from the SURF row." },
  { id = "pika_pal", title = "Pika Pal", points = 10, games = { "yellow" },
    description = "Ride the surfing Pikachu as your look." },
  { id = "sky_high", title = "Sky High", points = 10, games = { "ruby", "sapphire", "emerald" },
    description = "Ride the Mt. Chimney cable car with a look on." },
  { id = "hall_of_lens", title = "Hall of Lens", points = 25,
    description = "Enter the Hall of Fame wearing a look." },
  { id = "long_walk", title = "Long Walk", points = 10, goal = 1000, unit = "STEPS",
    description = "Walk 1,000 steps with a look on." },
}
for _, a in ipairs(LIST) do a.category = "LENS" end
achievements.LIST = LIST

-- api: family (the running family), now() -> { look, rival, surfKit },
-- handle (the sprites: surfNow() in the Game Boy games, isRivalTrainer
-- in the Gen 3 ones), kindOf(key) -> "gen3" | "gameboy" | "cross",
-- characterOf(key). Returns { changed, lensOpened }, or nil without
-- Recomp Achievements.
function achievements.init(mod, api)
  local found = type(mod.find) == "function" and mod.find("recomp_achievements") or nil
  local ach = type(found) == "table" and found.exports or nil
  if type(ach) ~= "table" or type(ach.connect) ~= "function" then return nil end
  local major = tonumber(tostring(ach.apiVersion or ""):match("^(%d+)"))
  if major ~= 1 then
    mod.log:info("Recomp Achievements API %s isn't one this version knows; no achievements", tostring(ach.apiVersion))
    return nil
  end
  local handle, code = ach.connect(mod, { tab = "LENS" })
  if not handle then
    mod.log:info("Recomp Achievements: connect failed (%s)", tostring(code))
    return nil
  end
  local ok, errors = handle:registerMany(LIST)
  for i, err in pairs(errors or {}) do
    mod.log:warn("achievement %s not added: %s", tostring(LIST[i] and LIST[i].id), tostring(err[2] or err[1]))
  end
  mod.log:info("%d achievements added to Recomp Achievements", ok or 0)

  local family, gb = api.family, api.family.gb
  local ready = false -- a save is attached (before that, unlocks are refused)

  local function unlock(id)
    if ready and not handle:isUnlocked(id) then handle:unlock(id) end
  end

  -- The looks worn in this save, kept with the save, for Wardrobe
  local function wore(key)
    if type(mod.save) ~= "table" then return end
    local okGet, worn = pcall(mod.save.get, mod.save, "worn", nil)
    worn = okGet and type(worn) == "table" and worn or {}
    if not worn[key] then
      worn[key] = true
      pcall(mod.save.set, mod.save, "worn", worn)
    end
    local n = 0
    for _ in pairs(worn) do n = n + 1 end
    handle:setProgress("wardrobe", n)
  end

  -- The look achievements: checked when a save is attached and when the
  -- look changes
  local function changed()
    if not ready then return end
    local now = api.now()
    local look = now.look
    if not look then return end
    unlock("fresh_look")
    wore(look)
    local kind = api.kindOf(look)
    if not gb and kind == "gameboy" then unlock("old_school") end
    if gb and kind ~= "gameboy" then unlock("new_tricks") end
    if not gb and kind == "cross" then unlock("across_the_sea") end
  end

  mod.events:on(ach.events.ready, function()
    ready = true
    changed()
  end)

  -- Rival battles: Blue's OPP_RIVAL1-3 in Gen 1, Silver's RIVAL1-2 in
  -- Gen 2, and in Gen 3 whichever trainer's pic the rival's look replaces
  mod.events:on("battle.started", function(ev)
    local now = api.now()
    if not (ready and now.rival and type(ev) == "table" and ev.kind == "trainer") then return end
    local id = ev.trainerId
    local rival
    if gb then
      rival = type(id) == "string" and (id:match("^OPP_RIVAL%d") or id:match("^RIVAL%d")) ~= nil
    else
      rival = type(api.handle.isRivalTrainer) == "function" and api.handle.isRivalTrainer(id)
    end
    if not rival then return end
    unlock("frenemies")
    if now.look and api.characterOf(now.look) == api.characterOf(now.rival) then unlock("mirror_match") end
  end)

  -- Surfing, checked as you go
  local function surfing()
    if gb then
      return type(api.handle.surfNow) == "function" and api.handle.surfNow() or nil
    end
    local okP, Player = pcall(require, "src.core.game3.player")
    return okP and type(Player) == "table" and Player.surfing == true and "surf" or nil
  end

  mod.events:on("world.stepped", function()
    if not ready then return end
    local now = api.now()
    local riding = surfing()
    if riding and now.surfKit then unlock("surfs_up") end
    if riding == "pika" and now.look then unlock("pika_pal") end
    if now.look then handle:addProgress("long_walk", 1) end
  end)

  mod.events:on("map.entered", function(ev)
    local now = api.now()
    if ready and now.look and type(ev) == "table" and type(ev.mapId) == "string"
        and ev.mapId:find("HALL_OF_FAME", 1, true) then
      unlock("hall_of_lens")
    end
  end)

  -- The Mt. Chimney cable car is a scene of its own, not a map
  if family.id == "rse" then
    local okCable, CableCar = pcall(require, "src.ui.game3.rse.cable_car")
    if okCable and type(CableCar) == "table" and type(CableCar.open) == "function" then
      local open = CableCar.open
      CableCar.open = function(...)
        if api.now().look then unlock("sky_high") end
        return open(...)
      end
    end
  end

  return {
    changed = changed,
    lensOpened = function() unlock("behind_the_lens") end,
  }
end

return achievements
