-- Gen 3 and 4 looks in Red/Blue/Yellow and Gold/Silver/Crystal
-- A look's gen3/ sheets, laid out for the Game Boy games' player: walking
-- (both of Gen 3's steps, so art that isn't symmetrical doesn't flip
-- sides), biking, surfing on the look's (or the SURF row's) Pokemon,
-- fishing, and the battle pics. Nothing is written to disk: each sheet is
-- built when it's first drawn. -Elvie
--
-- Gen 1/2 draw the player with a SpriteRenderer, so this swaps in its own
-- renderers while the player is drawn and puts them back after. Sheets
-- are full colour (gbaArt), so no Game Boy palette touches them. -Elvie
-- --------------------------------------------------

local gen12 = {}

-- Each family's sheets: { width, height, frames }; wide sheets (32 across
-- for a 16-wide one) are fine too. Back pics: the frame that stands
-- still (FR/LG's first, R/S/E's last). -Elvie
local SHEETS = {
  frlg = { walk = { 16, 32, 20 }, bike = { 32, 32, 9 }, surf = { 16, 32, 12 }, fishing = { 32, 32, 12 },
           front = { 64, 64, 1 }, back = { 64, 64, 5 }, surfBlob = { 32, 32, 6 }, surfOverlay = { 32, 32, 3 } },
  rse  = { walk = { 16, 32, 18 }, bike = { 32, 32, 9 }, surf = { 32, 32, 12 }, fishing = { 32, 32, 12 },
           front = { 64, 64, 1 }, back = { 64, 64, 4 }, surfBlob = { 32, 32, 3 }, surfOverlay = { 32, 32, 3 } },
}
local BACK_IDLE = { frlg = 0, rse = 3 }
-- The blob's frame per facing (down, up, left): FR/LG has two bob frames each -Elvie
local BLOB_FRAME = { frlg = { 0, 2, 4 }, rse = { 0, 1, 2 } }

-- Game Boy order: stand down, up, left, then a step each (the engine's
-- STAND and WALK), then the other step each, which only this file draws.
-- Gen 3 order: stand down, up, left, then two steps each. -Elvie
local WALK_ORDER = { 0, 1, 2, 3, 5, 7, 4, 6, 8 }
local SECOND_STEP = { down = 6, up = 7, left = 8, right = 8 }
local STAND = { down = 0, up = 1, left = 2, right = 2 }
-- fishing.png: four frames a facing (left, up, down); the fourth has the
-- line out, so that's the one held while fishing -Elvie
local FISH_FRAME = { left = 3, right = 3, up = 7, down = 11 }

local function engine(name)
  local ok, m = pcall(require, name)
  return ok and m or nil
end

function gen12.init(mod, ctx, family)
  if not (love and love.graphics and love.image) then return nil end
  local GameVersion = engine("src.core.GameVersion")
  local Assets = engine("src.render.Assets")
  local SpriteRenderer = engine("src.render.SpriteRenderer")
  if not (GameVersion and Assets and SpriteRenderer and type(Assets.compose) == "function") then
    mod.log:info("this gen1recomp build can't draw Gen 3 looks in Game Boy games; skipping")
    return nil
  end
  local gen = GameVersion.generation(GameVersion.get())

  local warned = {}
  local function warnOnce(key, fmt, ...)
    if warned[key] then return end
    warned[key] = true
    mod.log:info(fmt, ...)
  end

  -- The current choice -Elvie
  local bases = {} -- { dir, layout } in fallback order
  local surfFolders = {} -- the SURF row's Pokemon, by layout
  local slots = {} -- [gender] = true for the save genders this look replaces
  local live -- built renderers and pic paths, or nil for none
  local serial = 0

  -- First folder whose copy of file is the right size, sheet by sheet -Elvie
  local function loadSheet(name, list)
    for _, base in ipairs(list or bases) do
      local size = SHEETS[base.layout][name]
      local rel = base.dir .. name .. ".png"
      if size and mod.assets:info(rel) then
        local ok, data = pcall(love.image.newImageData, mod.assets:path(rel))
        if ok and data then
          local w, h = data:getDimensions()
          if (w == size[1] or (size[1] == 16 and w == 32)) and h == size[2] * size[3] then
            return data, base.layout, w, size[2], base.dir
          end
          warnOnce(rel, "%s is %dx%d but needs %dx%d; skipping it", rel, w, h, size[1], size[2] * size[3])
        else
          warnOnce(rel, "could not load %s; skipping it", rel)
        end
      end
    end
    return nil
  end

  -- frames picked from a sheet, one under another -Elvie
  local function pick(src, w, h, order)
    local out = love.image.newImageData(w, h * #order)
    for i, from in ipairs(order) do out:paste(src, 0, (i - 1) * h, 0, from * h, w, h) end
    return out
  end

  -- A virtual image path the engine loads through Assets.compose. A new
  -- path each time the look changes, so nothing cached keeps the old one. -Elvie
  local function publish(name, data)
    local path = ("mods/%s/live/%d/%s.png"):format(mod.id or "emerald_lens", serial, name)
    Assets.compose(path, function() return data end)
    return path
  end

  local function renderer(name, data, w, h, n, opts)
    opts = opts or {}
    local def = { id = "EMERALD_LENS_" .. name:upper(), image = publish(name, data), frames = n, walker = true,
      frameWidth = w, frameHeight = h, anchorX = opts.anchorX, anchorY = opts.anchorY, gbaArt = true }
    local ok, r = pcall(SpriteRenderer.new, def, "player")
    if not ok then
      warnOnce("renderer" .. name, "couldn't set up the %s sheet: %s", name, tostring(r))
      return nil
    end
    local draw = SpriteRenderer.draw
    -- frame: which one to draw for a pose, or nil for the engine's own
    -- choice; drawTile does nothing, so the Game Boy fishing pose and rod
    -- tiles don't land on top -Elvie
    r.draw = function(self, px, py, camX, camY, facing, walkPhase, stepFlip, topHalf, forceFlip, frameOverride, oamRow)
      local frame = opts.frameFor and opts.frameFor(facing, walkPhase, stepFlip)
      if frame then
        return draw(self, px, py, camX, camY, facing, walkPhase, stepFlip, nil, facing == "right", frame, oamRow)
      end
      return draw(self, px, py, camX, camY, facing, walkPhase, stepFlip, topHalf, forceFlip, frameOverride, oamRow)
    end
    r.drawTile = function() end
    return r
  end

  local function walker(name, src, w, h)
    return renderer(name, pick(src, w, h, WALK_ORDER), w, h, #WALK_ORDER, {
      frameFor = function(facing, walkPhase, stepFlip)
        if walkPhase == 1 and stepFlip then return SECOND_STEP[facing] end
        return nil
      end })
  end

  -- Rider offsets from surfBlob.json, read the same way as gen3.lua's -Elvie
  local function riderOffsets(folder)
    local ok, text = pcall(mod.read, mod, folder .. "surfBlob.json")
    if not ok or type(text) ~= "string" then return nil end
    local list = text:match('"player"%s*:%s*(%b[])')
    if not list then return nil end
    -- whole JSON numbers (1.5, -2.0, 1e1 too), rounded to pixels -Elvie
    local n = {}
    for v in list:gmatch("[^,%s%[%]]+") do
      local num = tonumber(v)
      if not num then n = nil; break end
      n[#n + 1] = math.floor(num + 0.5)
    end
    if n and #n == 2 then return { { n[1], n[2] }, { n[1], n[2] }, { n[1], n[2] } } end
    if n and #n == 6 then return { { n[1], n[2] }, { n[3], n[4] }, { n[5], n[6] } } end
    warnOnce(folder .. "surfBlob.json", "%ssurfBlob.json: \"player\" needs 2 or 6 numbers; ignoring it", folder)
    return nil
  end

  -- Surfing: the Pokemon (the SURF row's, else the look's surf blob) with
  -- the rider on it and its front parts over them, one frame per facing.
  -- The blob sits 8 left and 8 up of the tile as in Gen 3, so a frame is
  -- 32 wide and 40 tall with the tile's foot point at (16, 32). No blob,
  -- no surfing sheet: the game's own Seel or Lapras shows. -Elvie
  local SURF_W, SURF_H = 32, 40
  local function surfSheet()
    local rider, riderLayout, rw = loadSheet("surf")
    if not rider then return nil end
    local blob, blobLayout, _, _, folder = loadSheet("surfBlob", surfFolders)
    if not blob then blob, blobLayout, _, _, folder = loadSheet("surfBlob") end
    if not blob then return nil end
    local over = loadSheet("surfOverlay", { { dir = folder, layout = blobLayout } })
    local offsets = riderOffsets(folder) or {}
    local out = love.image.newImageData(SURF_W, SURF_H * 3)
    -- dx, dy inside the frame; anything past its edges is cut -Elvie
    local function put(src, sx, sy, w, h, top, dx, dy)
      for y = 0, h - 1 do
        for x = 0, w - 1 do
          local r, g, b, a = src:getPixel(sx + x, sy + y)
          local px, py = dx + x, dy + y
          if a > 0 and px >= 0 and px < SURF_W and py >= 0 and py < SURF_H then out:setPixel(px, top + py, r, g, b, a) end
        end
      end
    end
    for facing = 0, 2 do
      local top = facing * SURF_H
      put(blob, 0, BLOB_FRAME[blobLayout][facing + 1] * 32, 32, 32, top, 0, 8)
      local o = offsets[facing + 1] or { 0, 0 }
      put(rider, 0, facing * 32, rw, 32, top, (SURF_W - rw) / 2 + o[1], o[2])
      if over then put(over, 0, facing * 32, 32, 32, top, 0, 8) end
    end
    return renderer("surf", out, SURF_W, SURF_H, 3, { anchorX = 16, anchorY = 32,
      frameFor = function(facing) return STAND[facing] end })
  end

  -- The front pic is the look's own front.png file: the trainer card,
  -- Oak's intro and the Hall of Fame open the path as a file. The back is
  -- one frame of a strip, so it's built (battles load through Assets). -Elvie
  local function picOf(name)
    local src, layout, _, _, dir = loadSheet(name)
    if not src then return nil end
    if name == "front" then return mod.assets:path(dir .. "front.png") end
    local out = love.image.newImageData(64, 64)
    out:paste(src, 0, 0, 0, BACK_IDLE[layout] * 64, 64, 64)
    return publish(name, out)
  end

  local function build()
    if #bases == 0 then return nil end
    serial = serial + 1
    local out = {}
    local walk, _, ww, wh = loadSheet("walk")
    if walk then out.walk = walker("walk", walk, ww, wh) end
    local bike, _, bw, bh = loadSheet("bike")
    if bike then out.bike = walker("bike", bike, bw, bh) end
    out.surf = surfSheet()
    local fish = loadSheet("fishing")
    if fish then
      out.fish = renderer("fishing", pick(fish, 32, 32, { FISH_FRAME.down, FISH_FRAME.up, FISH_FRAME.left }),
        32, 32, 3, { frameFor = function(facing) return STAND[facing] end })
    end
    out.front, out.back = picOf("front"), picOf("back")
    return out
  end

  local function liveGame()
    local ok, g = pcall(function() return mod.game end)
    return ok and type(g) == "table" and g or nil
  end

  -- A game with a girl to play (Crystal's Kris) -Elvie
  local function hasKris()
    local game = liveGame()
    local data = game and game.data
    local sprites = type(data) == "table" and (data.gen2Sprites or data.sprites)
    return type(sprites) == "table" and sprites.SPRITE_KRIS ~= nil
  end

  -- Whether the look stands in for this save's player: always with one
  -- player to pick (Gen 1, Gold/Silver); with Kris, the look's gender, or
  -- either with GENDER on MY SAVE. female: true for a Kris save. -Elvie
  local function replaces(female)
    if not hasKris() then return true end
    return slots[female and "female" or "male"] == true
  end

  -- Gen 1/2 battle backs draw at twice the size unless battle_sprite_scales
  -- says otherwise, so ours gets 1x -Elvie
  local SCALE_ID = "emerald_lens_back"
  local function setBackScale()
    local game = liveGame()
    local data = game and game.data
    if type(data) ~= "table" then return end
    data.battle_sprite_scales = data.battle_sprite_scales or {}
    data.battle_sprite_scales[SCALE_ID] = live and live.back and { path = live.back, scale = 1 } or nil
  end

  -- Gen 1 draws the rod apart from the player, from field.overworldFx;
  -- with our fishing frames (which hold their own rod) it's left out -Elvie
  local savedFx
  local function setRod()
    if gen ~= 1 then return end
    local game = liveGame()
    local field = game and type(game.data) == "table" and game.data.field
    if type(field) ~= "table" or type(field.overworldFx) ~= "table" then return end
    if live and live.fish then
      if not savedFx then
        savedFx = field.overworldFx
        local copy = {}
        for k, v in pairs(savedFx) do copy[k] = v end
        copy.fishingRod = nil
        field.overworldFx = copy
      end
    elseif savedFx then
      field.overworldFx = savedFx
      savedFx = nil
    end
  end

  -- Drawing the player
  -- -----------------------------------------------
  if gen == 1 then
    local Player = engine("src.world.Player")
    if Player and type(Player.draw) == "function" then
      local originalDraw = Player.draw
      Player.draw = function(self, ...)
        if not live then return originalDraw(self, ...) end
        local s1, s2, s3 = self.sprite, self.bikeSprite, self.surfSprite
        self.sprite = (self.fishing and live.fish) or live.walk or s1
        self.bikeSprite = live.bike or s2
        self.surfSprite = live.surf or s3
        local ok, err = pcall(originalDraw, self, ...)
        self.sprite, self.bikeSprite, self.surfSprite = s1, s2, s3
        if not ok then error(err, 0) end
      end
    end
  else
    local Player = engine("src.world.gen2.Player")
    if Player and type(Player.draw) == "function" then
      local KIND = { SPRITE_CHRIS = "walk", SPRITE_KRIS = "walk", SPRITE_CHRIS_BIKE = "bike",
        SPRITE_KRIS_BIKE = "bike", SPRITE_SURF = "surf" }
      local originalDraw = Player.draw
      Player.draw = function(self, ...)
        local id = live and type(self.spriteDef) == "table" and self.spriteDef.id
        local kind = id and KIND[id]
        local female = type(id) == "string" and id:find("KRIS") ~= nil
        if kind == "surf" then female = self.female end
        local r = kind and replaces(female) and ((self.fishing and self.fishSheet and live.fish) or live[kind])
        if not r then return originalDraw(self, ...) end
        local saved = self.sprite
        self.sprite = r
        local ok, err = pcall(originalDraw, self, ...)
        self.sprite = saved
        if not ok then error(err, 0) end
      end
      -- remember the save's gender for the surf sheet, which both share -Elvie
      local originalSet = Player.setSprite
      if type(originalSet) == "function" then
        Player.setSprite = function(self, def, ...)
          if type(def) == "table" and type(def.id) == "string" and KIND[def.id] == "walk" then
            self.female = def.id:find("KRIS") ~= nil
          end
          return originalSet(self, def, ...)
        end
      end
    end
  end

  -- Battle pics, Hall of Fame, trainer card: the engine's player.sprite
  -- hook, which both generations raise -Elvie
  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("player.sprite", function(nextFn, path, hookCtx)
      path = nextFn(path, hookCtx)
      if not live or type(hookCtx) ~= "table" or hookCtx.demo or hookCtx.oakDemo then return path end
      local game = liveGame()
      local female = false
      if game then
        -- Gen 2 keeps it at save.player.gender (World:playerGender) -Elvie
        local save = type(game.save) == "table" and game.save
        local g = save and type(save.player) == "table" and save.player.gender or nil
        female = g == "female"
      end
      if not replaces(female) then return path end
      local mine = hookCtx.side == "back" and live.back or (hookCtx.side == "front" and live.front)
      if mine then
        hookCtx.trueColor = true
        return mine
      end
      return path
    end)
  end

  -- configure: a new choice (nil for OFF) -Elvie
  local function configure(newCtx)
    bases, surfFolders, slots = {}, {}, {}
    if newCtx and type(newCtx.folderKeys) == "table" then
      for _, key in ipairs(newCtx.folderKeys) do
        for _, layout in ipairs(family.art) do
          bases[#bases + 1] = { dir = newCtx.spritesDir .. "/" .. key .. "/gen3/" .. layout .. "/", layout = layout }
        end
      end
      local mode = newCtx.fitSave and "enby" or newCtx.genderMode
      slots.male = mode ~= "girl"
      slots.female = mode ~= "boy"
    end
    if newCtx and type(newCtx.surfKit) == "string" then
      for _, layout in ipairs(family.art) do
        surfFolders[#surfFolders + 1] = { dir = newCtx.surfKit .. layout .. "/", layout = layout }
      end
    end
    live = build()
    setBackScale()
    setRod()
  end

  configure(ctx)
  if mod.events and type(mod.events.on) == "function" then
    -- the game's data comes after the mod loads -Elvie
    mod.events:on("game.ready", function()
      setBackScale()
      savedFx = nil
      setRod()
    end)
  end
  return { configure = configure, current = function() return live end }
end

return gen12
