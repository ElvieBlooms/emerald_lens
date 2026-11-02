-- Gen 3 and 4 looks in Red/Blue/Yellow and Gold/Silver/Crystal
-- A look's gen3/ sheets, laid out for the Game Boy games' player: walking
-- (both of Gen 3's steps, so art that isn't symmetrical doesn't flip
-- sides), biking, surfing on the look's (or the SURF row's) Pokemon,
-- fishing, the battle pics and the trainer card. The rival (Blue or
-- Silver) can wear a look too: battle pics and walking sprite. Nothing is
-- written to disk: each sheet is built when it's first drawn.
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
           front = { 64, 64, 1 }, back = { 64, 64, 5 }, surfBlob = { 32, 32, 6 }, surfOverlay = { 32, 32, 3 },
           rivalEarly = { 64, 64, 1 }, rivalLate = { 64, 64, 1 }, rivalChampion = { 64, 64, 1 } },
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

-- The rival: its battle pics per trainer record, the Gen 3 file each one
-- comes from (else front.png), and its overworld sprite. Gen 1:
-- OPP_RIVAL1-3 in data.trainers and SPRITE_BLUE; Gen 2: RIVAL1-2 in
-- data.gen2Trainers.classes and SPRITE_RIVAL, as Crystal Lens does.
local RIVAL = {
  [1] = { pics = { { "OPP_RIVAL1", "rivalEarly" }, { "OPP_RIVAL2", "rivalLate" }, { "OPP_RIVAL3", "rivalChampion" } },
          sprite = "SPRITE_BLUE" },
  [2] = { pics = { { "RIVAL1", "rivalEarly" }, { "RIVAL2", "rivalLate" } }, sprite = "SPRITE_RIVAL" },
}
-- An opponent's pic box is 7x7 tiles in both generations
local PIC_BOX = 56
-- The Gen 2 trainer card's portrait box: 5x7 tiles at tile (14, 1)
local CARD_X, CARD_Y, CARD_W, CARD_H = 14 * 8, 1 * 8, 40, 56

local function engine(name)
  local ok, m = pcall(require, name)
  return ok and m or nil
end

local function cleanKey(s)
  return (tostring(s):gsub("%W", "_"))
end

-- The fixed path a look's battle back is published at, so its scale can
-- be registered while the mod loads
function gen12.backPath(modId, key)
  return ("mods/%s/live/back/%s.png"):format(modId or "emerald_lens", cleanKey(key))
end

-- opts: lookKeys (every look this family offers, for the back scales),
-- pikachuKit (a surf kit folder for Yellow's surfing Pikachu), ownCard
-- (draw the Gen 2 trainer card portrait; off while Crystal Lens leads,
-- since it draws the card itself)
function gen12.init(mod, ctx, family, opts)
  opts = opts or {}
  if not (love and love.graphics and love.image) then return nil end
  local GameVersion = engine("src.core.GameVersion")
  local Assets = engine("src.render.Assets")
  local SpriteRenderer = engine("src.render.SpriteRenderer")
  if not (GameVersion and Assets and SpriteRenderer and type(Assets.compose) == "function") then
    mod.log:info("this gen1recomp build can't draw Gen 3 looks in Game Boy games; skipping")
    return nil
  end
  local gen = GameVersion.generation(GameVersion.get())
  local PaletteFX = engine("src.render.PaletteFX")

  local warned = {}
  local function warnOnce(key, fmt, ...)
    if warned[key] then return end
    warned[key] = true
    mod.log:info(fmt, ...)
  end

  -- The current choice -Elvie
  local bases = {} -- { dir, layout, top } in fallback order; top is the look folder itself
  local surfFolders = {} -- the SURF row's Pokemon, by layout
  local pikaFolders = {} -- Yellow's surfing Pikachu
  local slots = {} -- [gender] = true for the save genders this look replaces
  local lookKey -- the selected look, for the back pic's fixed path
  local live -- built renderers and pic paths, or nil for none
  local serial = 0

  local function basesOf(newCtx)
    local list = {}
    for _, key in ipairs(newCtx.folderKeys or {}) do
      for _, layout in ipairs(family.art) do
        list[#list + 1] = { dir = newCtx.spritesDir .. "/" .. key .. "/gen3/" .. layout .. "/", layout = layout,
          top = newCtx.spritesDir .. "/" .. key .. "/" }
      end
    end
    return list
  end

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
  local function publish(name, data, path)
    path = path or ("mods/%s/live/%d/%s.png"):format(mod.id or "emerald_lens", serial, name)
    Assets.compose(path, function() return data end)
    return path
  end

  local function renderer(name, data, w, h, n, rOpts)
    rOpts = rOpts or {}
    local def = { id = "EMERALD_LENS_" .. name:upper(), image = publish(name, data), frames = n, walker = true,
      frameWidth = w, frameHeight = h, anchorX = rOpts.anchorX, anchorY = rOpts.anchorY, gbaArt = true }
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
      local frame = rOpts.frameFor and rOpts.frameFor(facing, walkPhase, stepFlip)
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
  -- no surfing sheet: the game's own Seel or Lapras shows. kit: the
  -- folders to take the Pokemon from first.
  local SURF_W, SURF_H = 32, 40
  local function surfSheet(name, kit)
    local rider, _, rw = loadSheet("surf")
    if not rider then return nil end
    local blob, blobLayout, _, _, folder = loadSheet("surfBlob", kit)
    if not blob and kit ~= pikaFolders then blob, blobLayout, _, _, folder = loadSheet("surfBlob") end
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
    return renderer(name, out, SURF_W, SURF_H, 3, { anchorX = 16, anchorY = 32,
      frameFor = function(facing) return STAND[facing] end })
  end

  -- The opaque part of a picture: x, y, w, h (nil if it's all clear)
  local function bounds(data)
    local w, h = data:getDimensions()
    local x0, y0, x1, y1 = w, h, -1, -1
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local _, _, _, a = data:getPixel(x, y)
        if a > 0 then
          if x < x0 then x0 = x end
          if x > x1 then x1 = x end
          if y < y0 then y0 = y end
          if y > y1 then y1 = y end
        end
      end
    end
    if x1 < 0 then return nil end
    return x0, y0, x1 - x0 + 1, y1 - y0 + 1
  end

  -- A picture fitted into a w x h box: the opaque part centred, standing
  -- on the bottom edge, made smaller only if it doesn't fit
  local function fitBox(src, w, h)
    local bx, by, bw, bh = bounds(src)
    local out = love.image.newImageData(w, h)
    if not bx then return out end
    local scale = math.min(1, w / bw, h / bh)
    local dw, dh = math.max(1, math.floor(bw * scale)), math.max(1, math.floor(bh * scale))
    local ox, oy = math.floor((w - dw) / 2), h - dh
    for y = 0, dh - 1 do
      for x = 0, dw - 1 do
        local sx = bx + math.min(bw - 1, math.floor(x / scale))
        local sy = by + math.min(bh - 1, math.floor(y / scale))
        out:setPixel(ox + x, oy + y, src:getPixel(sx, sy))
      end
    end
    return out
  end

  -- The front pic is the look's own front.png file: the trainer card,
  -- Oak's intro and the Hall of Fame open the path as a file. The back is
  -- one frame of a strip, so it's built (battles load through Assets), at
  -- the look's fixed path.
  local function picOf(name)
    local src, layout, _, _, dir = loadSheet(name)
    if not src then return nil end
    if name == "front" then return mod.assets:path(dir .. "front.png") end
    local out = love.image.newImageData(64, 64)
    out:paste(src, 0, 0, 0, BACK_IDLE[layout] * 64, 64, 64)
    return publish(name, out, lookKey and gen12.backPath(mod.id, lookKey) or nil)
  end

  -- The Gen 2 trainer card portrait: a folder's own Crystal Lens
  -- trainerCardColor.png or trainerCard.png (40x56) first, through the
  -- chain, else the front pic fitted into the box
  local function cardOf()
    for _, base in ipairs(bases) do
      for _, file in ipairs({ "trainerCardColor.png", "trainerCard.png" }) do
        local rel = base.top .. file
        if mod.assets:info(rel) then
          local ok, data = pcall(love.image.newImageData, mod.assets:path(rel))
          if ok and data then return fitBox(data, CARD_W, CARD_H) end
        end
      end
    end
    local front = loadSheet("front")
    return front and fitBox(front, CARD_W, CARD_H) or nil
  end

  local function build()
    if #bases == 0 then return nil end
    serial = serial + 1
    local out = {}
    local walk, _, ww, wh = loadSheet("walk")
    if walk then out.walk = walker("walk", walk, ww, wh) end
    local bike, _, bw, bh = loadSheet("bike")
    if bike then out.bike = walker("bike", bike, bw, bh) end
    out.surf = surfSheet("surf", surfFolders)
    if #pikaFolders > 0 then out.surfPika = surfSheet("surfPika", pikaFolders) end
    local fish = loadSheet("fishing")
    if fish then
      out.fish = renderer("fishing", pick(fish, 32, 32, { FISH_FRAME.down, FISH_FRAME.up, FISH_FRAME.left }),
        32, 32, 3, { frameFor = function(facing) return STAND[facing] end })
    end
    out.front, out.back = picOf("front"), picOf("back")
    local card = cardOf()
    if card then
      local ok, img = pcall(love.graphics.newImage, card)
      if ok and img then
        img:setFilter("nearest", "nearest")
        out.card = img
      end
    end
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

  local function saveFemale()
    local game = liveGame()
    -- Gen 2 keeps it at save.player.gender (World:playerGender) -Elvie
    local save = game and type(game.save) == "table" and game.save
    local g = save and type(save.player) == "table" and save.player.gender or nil
    return g == "female"
  end

  -- Gen 1 battle backs draw at twice the size unless battle_sprite_scales
  -- says otherwise, so each look's back is registered at 1x while the mod
  -- loads, at its fixed path (Gen 2 backs are 1x already)
  if gen == 1 and mod.content and mod.content.battle_sprite_scales then
    for _, key in ipairs(opts.lookKeys or {}) do
      pcall(mod.content.battle_sprite_scales.register, mod.content.battle_sprite_scales,
        "emerald_lens_back_" .. cleanKey(key), { path = gen12.backPath(mod.id, key), scale = 1 })
    end
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

  -- The rival
  -- Written into the game's own trainer and sprite records, keeping what
  -- was there to put back. Putting back then writing again is safe to
  -- repeat, and a new game's records are new tables, so nothing old is
  -- carried over. The walking sprite changes on the next map, since the
  -- game sets up who's on a map as you enter it.
  -- --------------------------------------------------
  local rivalBases = {}
  local saved = {} -- [record] = { [field] = { value } }
  local function setField(record, field, value)
    saved[record] = saved[record] or {}
    if not saved[record][field] then saved[record][field] = { value = record[field] } end
    record[field] = value
  end
  local function restoreRival()
    for record, fields in pairs(saved) do
      for field, old in pairs(fields) do record[field] = old.value end
    end
    saved = {}
  end

  -- An opponent pic: fitted into the 7x7 box if it fits as it is, else
  -- the whole 64x64 (the box's own position keeps it on screen)
  local function opponentPic(src)
    local _, _, bw, bh = bounds(src)
    if bw and bw <= PIC_BOX and bh <= PIC_BOX then return fitBox(src, PIC_BOX, PIC_BOX) end
    return src
  end

  local rivalSerial = 0
  local function applyRival()
    restoreRival()
    if #rivalBases == 0 then return end
    local game = liveGame()
    local data = game and game.data
    local spec = RIVAL[gen]
    if type(data) ~= "table" or not spec then return end
    rivalSerial = rivalSerial + 1
    local tag = ("mods/%s/live/rival%d/"):format(mod.id or "emerald_lens", rivalSerial)
    local records = gen == 2 and type(data.gen2Trainers) == "table" and data.gen2Trainers.classes or data.trainers
    local front = loadSheet("front", rivalBases)
    for _, pair in ipairs(spec.pics) do
      local record = type(records) == "table" and records[pair[1]]
      local src = loadSheet(pair[2], rivalBases) or front
      if type(record) == "table" and src then
        setField(record, "pic", publish(pair[2], opponentPic(src), tag .. pair[2] .. ".png"))
        setField(record, "trueColor", true)
      end
    end
    local sprites = gen == 2 and data.gen2Sprites or data.sprites
    local sprite = type(sprites) == "table" and sprites[spec.sprite]
    local walk, _, ww, wh = loadSheet("walk", rivalBases)
    if type(sprite) == "table" and walk then
      -- the Game Boy order, one step each way, as the game's NPCs walk
      local sheet = pick(walk, ww, wh, { 0, 1, 2, 3, 5, 7 })
      setField(sprite, "image", publish("rivalWalk", sheet, tag .. "walk.png"))
      setField(sprite, "frames", 6)
      setField(sprite, "frameWidth", ww)
      setField(sprite, "frameHeight", wh)
      setField(sprite, "gbaArt", true)
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
        local s1, s2, s3, s4 = self.sprite, self.bikeSprite, self.surfSprite, self.surfPikachuSprite
        self.sprite = (self.fishing and live.fish) or live.walk or s1
        self.bikeSprite = live.bike or s2
        self.surfSprite = live.surf or s3
        -- Yellow: surfing on Pikachu, the look rides it too
        if s4 and live.surfPika then self.surfPikachuSprite = live.surfPika end
        local ok, err = pcall(originalDraw, self, ...)
        self.sprite, self.bikeSprite, self.surfSprite, self.surfPikachuSprite = s1, s2, s3, s4
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
        local before = self.sprite
        self.sprite = r
        local ok, err = pcall(originalDraw, self, ...)
        self.sprite = before
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
      if not replaces(saveFemale()) then return path end
      local mine = hookCtx.side == "back" and live.back or (hookCtx.side == "front" and live.front)
      if mine then
        hookCtx.trueColor = true
        return mine
      end
      return path
    end)
  end

  -- The Gen 2 trainer card draws its portrait from tiles, so with a look
  -- the card's drawPortrait paints the look's portrait instead, the way
  -- Crystal Lens does it
  local function drawCard()
    local card = live and live.card
    if not card or not replaces(saveFemale()) then return false end
    local w, h = card:getDimensions()
    local x, y = CARD_X + math.floor((CARD_W - w) / 2), CARD_Y + CARD_H - h
    if PaletteFX and type(PaletteFX.markTrueColor) == "function" then pcall(PaletteFX.markTrueColor, x, y, w, h) end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(card, x, y)
    return true
  end
  if gen == 2 and opts.ownCard and mod.content and mod.content.screens then
    mod.content.screens:register("Gen2TrainerCard", {
      new = function(game, screenOpts)
        local TrainerCard = require("src.ui.gen2.TrainerCard")
        local instance = TrainerCard.new(game, screenOpts)
        local own = instance.drawPortrait
        instance.drawPortrait = function(self, ...)
          if drawCard() then return end
          return own(self, ...)
        end
        return instance
      end,
    })
  end

  -- configure: a new choice (nil for OFF) -Elvie
  local function configure(newCtx)
    bases, surfFolders, pikaFolders, slots, lookKey = {}, {}, {}, {}, nil
    if newCtx and type(newCtx.folderKeys) == "table" then
      bases = basesOf(newCtx)
      lookKey = newCtx.lookKey or newCtx.folderKeys[1]
      local mode = newCtx.fitSave and "enby" or newCtx.genderMode
      slots.male = mode ~= "girl"
      slots.female = mode ~= "boy"
    end
    if newCtx and type(newCtx.surfKit) == "string" then
      for _, layout in ipairs(family.art) do
        surfFolders[#surfFolders + 1] = { dir = newCtx.surfKit .. layout .. "/", layout = layout }
      end
    end
    if gen == 1 and type(opts.pikachuKit) == "string" then
      for _, layout in ipairs(family.art) do
        pikaFolders[#pikaFolders + 1] = { dir = opts.pikachuKit .. layout .. "/", layout = layout }
      end
    end
    live = build()
    setRod()
  end

  -- configureRival: { folderKeys, spritesDir } for a rival, nil for the game's own
  local function configureRival(rivalCtx)
    rivalBases = (rivalCtx and type(rivalCtx.folderKeys) == "table") and basesOf(rivalCtx) or {}
    applyRival()
  end

  configure(ctx)
  if ctx and ctx.rival then configureRival(ctx.rival) end
  if mod.events and type(mod.events.on) == "function" then
    -- the game's data comes after the mod loads -Elvie
    mod.events:on("game.ready", function()
      savedFx = nil
      setRod()
      applyRival()
    end)
  end
  return {
    configure = configure,
    configureRival = configureRival,
    current = function() return live end,
    -- the trainer card portrait, for Crystal Lens's card
    card = function() return live and live.card or nil end,
  }
end

return gen12
