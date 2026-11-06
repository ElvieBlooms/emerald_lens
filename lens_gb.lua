-- The LENS screen in the Game Boy games
-- The same screen as in the Gen 3 games, drawn the Game Boy way, with
-- the game's own font and box: the choices for this game, a preview of
-- the look (its front pic and walking sprite, in full colour) and a
-- CREDITS page. Up and down pick a row, left and right (or A) change it,
-- B closes it. Changes are the same as in the mod options and apply
-- straight away. Crystal Lens has its own, so this one is only used
-- when Crystal Lens isn't installed.
-- --------------------------------------------------

local lensGb = {}

local ROW_Y, ROW_H = 22, 9 -- first row and row height, in pixels
local LABEL_X, VALUE_X = 16, 80
local VALUE_CHARS = 9
local PIC_BOX, PIC_X, PIC_Y = 56, 96, 80 -- the front pic, feet on the bottom edge
local WALK_X, WALK_Y = 40, 104 -- the walking sprite's top-left
local PAGE, LINE_CHARS = 16, 18

local function cut(text, n)
  text = tostring(text or "")
  return #text > n and text:sub(1, n) or text
end

-- Long credit lines broken at spaces, LINE_CHARS a line
local function wrap(text, out, indent)
  indent = indent or ""
  local line = indent
  for word in tostring(text):gmatch("%S+") do
    if #line > #indent and #line + 1 + #word > LINE_CHARS then
      out[#out + 1] = line
      line = indent .. "  "
    end
    line = (#line > #indent and line:sub(-1) ~= " ") and (line .. " " .. word) or (line .. word)
  end
  if #line > #indent then out[#out + 1] = line end
end

-- api: rows() -> { { key, label, who, choices, value, valueLabel, page } },
-- set(game, key, value), preview(who) -> { pic, walk } paths or nil,
-- credits() -> { { text, heading } }
function lensGb.new(mod, api)
  if type(api) ~= "table" then return nil end
  local Font = mod.ui and mod.ui.Font
  -- A translation's TTF prints in the current colour (Game Boy tiles are
  -- black whatever it is), so text is always drawn in black, as the game's
  -- own screens do
  local function text(s, x, y)
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(0, 0, 0, 1)
    local w = Font.draw(s, x, y)
    love.graphics.setColor(r, g, b, a)
    return w
  end
  if not (Font and mod.content and mod.content.screens) then return nil end
  local okFx, PaletteFX = pcall(require, "src.render.PaletteFX")
  if not okFx then PaletteFX = nil end
  local id = (mod.id or "emerald_lens") .. "_lens"

  -- Pictures by path; front pics fitted into the box, made smaller only
  -- if the opaque part doesn't fit
  local images = {}
  local function fitted(data, w, h)
    local x0, y0, x1, y1 = data:getWidth(), data:getHeight(), -1, -1
    data:mapPixel(function(x, y, r, g, b, a)
      if a > 0 then
        if x < x0 then x0 = x end
        if x > x1 then x1 = x end
        if y < y0 then y0 = y end
        if y > y1 then y1 = y end
      end
      return r, g, b, a
    end)
    local out = love.image.newImageData(w, h)
    if x1 < 0 then return out end
    local bw, bh = x1 - x0 + 1, y1 - y0 + 1
    local scale = math.min(1, w / bw, h / bh)
    local dw, dh = math.max(1, math.floor(bw * scale)), math.max(1, math.floor(bh * scale))
    local ox, oy = math.floor((w - dw) / 2), h - dh
    for y = 0, dh - 1 do
      for x = 0, dw - 1 do
        out:setPixel(ox + x, oy + y, data:getPixel(x0 + math.min(bw - 1, math.floor(x / scale)),
          y0 + math.min(bh - 1, math.floor(y / scale))))
      end
    end
    return out
  end
  local function image(path, box)
    if not path then return nil end
    local key = type(path) == "string" and (path .. (box and "|box" or "")) or path
    if images[key] == nil then
      -- a path, or a picture already made (a player read from a Gen 3 game)
      local ok, data
      if type(path) == "string" then ok, data = pcall(love.image.newImageData, path)
      else ok, data = true, path end
      if ok and data then
        if box then data = fitted(data, PIC_BOX, PIC_BOX) end
        local img = love.graphics.newImage(data)
        img:setFilter("nearest", "nearest")
        images[key] = img
      else
        images[key] = false
      end
    end
    return images[key] or nil
  end

  -- A Game Boy sheet's four greys in the look's colours, white clear, as
  -- Crystal Lens colours it
  local walks = {}
  local function gbWalk(path, colors)
    if not (path and type(colors) == "table") then return nil end
    local key = path .. "|" .. table.concat(colors[2] or {}, ",") .. "|" .. table.concat(colors[3] or {}, ",")
    if walks[key] == nil then
      local ok, data = pcall(love.image.newImageData, path)
      if ok and data then
        data:mapPixel(function(_, _, r, g, b, a)
          if a == 0 then return r, g, b, a end
          local shade = r > 0.83 and 1 or r > 0.5 and 2 or r > 0.17 and 3 or 4
          if shade == 1 then return 0, 0, 0, 0 end
          local c = colors[shade]
          return c[1] / 255, c[2] / 255, c[3] / 255, a
        end)
        local img = love.graphics.newImage(data)
        img:setFilter("nearest", "nearest")
        walks[key] = img
      else
        walks[key] = false
      end
    end
    return walks[key] or nil
  end

  local function trueColor(x, y, w, h)
    if PaletteFX and type(PaletteFX.markTrueColor) == "function" then pcall(PaletteFX.markTrueColor, x, y, w, h) end
  end

  local function cursor(x, y)
    local Theme = mod.ui.Theme
    if Theme and Theme.cursor and Font.drawCode then Font.drawCode(Theme.cursor, x, y)
    else text(">", x, y) end
  end

  -- The credits page: up and down scroll, left and right a page, B goes back
  mod.content.screens:register(id .. "_credits", {
    new = function(game)
      local self = { isOpaque = true, top = 1 }
      local lines = {}
      for _, line in ipairs(api.credits()) do
        if line.heading and #lines > 0 then lines[#lines + 1] = "" end
        wrap(line.text, lines, line.heading and "" or " ")
      end
      local last = math.max(1, #lines - PAGE + 1)
      function self:update()
        local input = game.input
        if input:wasPressed("b") or input:wasPressed("a") then game.stack:pop() return end
        if input:wasPressed("down") then self.top = math.min(last, self.top + 1) end
        if input:wasPressed("up") then self.top = math.max(1, self.top - 1) end
        if input:wasPressed("right") then self.top = math.min(last, self.top + PAGE) end
        if input:wasPressed("left") then self.top = math.max(1, self.top - PAGE) end
      end
      function self:draw()
        Font.drawBox(0, 0, 20, 18)
        for i = 0, PAGE - 1 do
          local line = lines[self.top + i]
          if line then text(cut(line, LINE_CHARS), 8, 8 + i * 8) end
        end
      end
      return self
    end,
  })

  mod.content.screens:register(id, {
    new = function(game)
      local self = { isOpaque = true, cursor = 1, clock = 0 }
      function self:update(dt)
        self.clock = self.clock + (dt or 0)
        local input = game.input
        local rows = api.rows()
        self.cursor = math.max(1, math.min(self.cursor, #rows))
        if input:wasPressed("b") or input:wasPressed("start") then game.stack:pop() return end
        if input:wasPressed("down") then self.cursor = self.cursor % #rows + 1 end
        if input:wasPressed("up") then self.cursor = (self.cursor - 2) % #rows + 1 end
        local row = rows[self.cursor]
        if row.page then
          if input:wasPressed("a") then mod.ui.push(game, id .. "_credits") end
          return
        end
        local step = (input:wasPressed("right") or input:wasPressed("a")) and 1 or (input:wasPressed("left") and -1) or 0
        if step ~= 0 and #row.choices > 1 then
          local at = 1
          for i, choice in ipairs(row.choices) do if choice[2] == row.value then at = i end end
          at = (at - 1 + step) % #row.choices + 1
          api.set(game, row.key, row.choices[at][2])
        end
      end
      function self:draw()
        local rows = api.rows()
        Font.drawBox(0, 0, 20, 18)
        text("EMERALD LENS", 8, 8)
        for i, row in ipairs(rows) do
          local y = ROW_Y + (i - 1) * ROW_H
          if i == self.cursor then cursor(LABEL_X - 8, y) end
          text(row.label, LABEL_X, y)
          text(cut(row.valueLabel, VALUE_CHARS), VALUE_X, y)
        end
        local row = rows[self.cursor] or {}
        local preview = api.preview(row.who or "player")
        love.graphics.setColor(1, 1, 1, 1)
        if preview and (preview.pic or preview.walk or preview.walkGb) then
          local pic = image(preview.pic, true)
          if pic then
            trueColor(PIC_X, PIC_Y, PIC_BOX, PIC_BOX)
            love.graphics.draw(pic, PIC_X, PIC_Y)
          end
          local walk = image(preview.walk)
          if walk then
            -- standing facing down, then a step, as on the map (Gen 3
            -- frames 0 and 3)
            local w, h = walk:getDimensions()
            local fw = math.min(w, 32)
            local frame = math.floor(self.clock * 2) % 2 == 0 and 0 or 3
            local quad = love.graphics.newQuad(0, frame * 32, fw, 32, w, h)
            local x = WALK_X - math.floor((fw - 16) / 2)
            trueColor(x, WALK_Y, fw, 32)
            love.graphics.draw(walk, quad, x, WALK_Y)
          end
          local gb = gbWalk(preview.walkGb, preview.colors)
          if gb then
            -- a Game Boy look: standing, then a step (frames 0 and 3), feet
            -- where a Gen 3 sprite's would be
            local w, h = gb:getDimensions()
            local frame = math.floor(self.clock * 2) % 2 == 0 and 0 or 3
            local quad = love.graphics.newQuad(0, frame * 16, 16, 16, w, h)
            trueColor(WALK_X, WALK_Y + 15, 16, 16)
            love.graphics.draw(gb, quad, WALK_X, WALK_Y + 15)
          end
        else
          text(preview and preview.line or "OFF", LABEL_X, WALK_Y + 16)
        end
      end
      return self
    end,
  })

  return {
    id = id,
    open = function(game) mod.ui.push(game, id) end,
  }
end

return lensGb
