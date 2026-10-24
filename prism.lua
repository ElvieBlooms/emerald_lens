-- PRISM: one menu item for every visuals mod
-- Facets and Emerald Lens each carry a copy of this file (the same code),
-- so neither needs the other. Each adds its screen to the START menu and
-- the OPTION menu through it: the first one there makes the item, the
-- next adds itself to that item's list. With one mod it's that mod's own
-- item (LENS, FACETS) and opens its screen; with more it's PRISM and
-- opens a list of them. Another mod can join by doing the same: an item
-- or row with id "prism" and an `entries` list. -Elvie
-- --------------------------------------------------

local prism = {}

local ID = "prism"
local LAYER = "prism"
local HELP_BG = { 0 / 255, 123 / 255, 197 / 255, 1 } -- same blue as the OPTION menu -Elvie
local HELP = "{A_BUTTON}OPEN {B_BUTTON}EXIT"
local LABEL_X, VALUE_X, ROW_Y0, ROW_STEP = 16, 112, 26, 13
local VALUE_W = 104

local function engine(name)
  local ok, m = pcall(require, name)
  return ok and m or nil
end

-- entry = { id, label (EMERALD LENS), short (LENS), value = fn() -> text,
-- about (a line on what it changes), open = fn(game) }. Entries sort by label, so the order doesn't depend
-- on which mod loaded first. A mod's entry replaces an older one with its
-- id. -Elvie
local function withEntry(entries, entry)
  local out = {}
  for _, e in ipairs(entries or {}) do
    if e.id ~= entry.id then out[#out + 1] = e end
  end
  out[#out + 1] = entry
  table.sort(out, function(a, b) return tostring(a.label) < tostring(b.label) end)
  return out
end
prism.withEntry = withEntry

local function valueOf(entry)
  local ok, v = pcall(entry.value or function() return "" end)
  return ok and type(v) == "string" and v or ""
end

-- The list screen. Picking an entry opens its screen on top, so B there
-- comes back here. -Elvie
-- --------------------------------------------------
function prism.picker()
  local P = { isMenu = true }
  local state

  function P.open(game, entries)
    local Stack = engine("src.ui.game3.stack")
    if not Stack or Stack.has(LAYER) then return end
    if Stack.onClear and not P.hooked then
      P.hooked = true
      Stack.onClear(function() state = nil end)
    end
    state = { game = game, entries = entries, index = 1 }
    Stack.push(LAYER, P, { hideBelow = true, fullscreen = true })
  end

  function P.close()
    if not state then return end
    state = nil
    local Stack = engine("src.ui.game3.stack")
    if Stack then Stack.pop(LAYER) end
  end

  function P.isOpen() return state ~= nil end
  function P.state() return state end

  function P.handleInput(input)
    if not (state and input) then return end
    local n = #state.entries
    if input:wasPressed("up") then state.index = (state.index - 2) % n + 1
    elseif input:wasPressed("down") then state.index = state.index % n + 1
    elseif input:wasPressed("a") or input:wasPressed("right") then
      local entry = state.entries[state.index]
      if entry and entry.open then entry.open(state.game) end
    elseif input:wasPressed("b") or input:wasPressed("start") then P.close()
    end
  end

  function P.update() end

  function P.draw()
    if not state then return end
    local Window = engine("src.ui.game3.window")
    local FrlgFont = engine("src.ui.game3.frlg_font")
    if not (Window and FrlgFont) then return end
    local PokedexChrome = engine("src.ui.game3.pokedex_chrome")
    local Options = engine("src.core.game3.options")
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, 240, 160)
    love.graphics.setColor(HELP_BG)
    love.graphics.rectangle("fill", 0, 0, 240, 16)
    love.graphics.setColor(1, 1, 1, 1)
    FrlgFont.draw("PRISM", 4, 0, { colors = FrlgFont.COLOR.WHITE })
    if PokedexChrome then PokedexChrome.drawControlInfo(HELP, 0xE4, 0) end
    local frameType = 0
    local game = state.game
    if Options and type(game) == "table" and type(game.options) == "table" then
      local ok, block = pcall(Options.block, game.options)
      frameType = ok and type(block) == "table" and tonumber(block.frameType) or 0
    end
    if not pcall(Window.userFrame, Window.template(1, 3, 28, 16), frameType) then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", 8, 24, 224, 128)
    end
    for i, entry in ipairs(state.entries) do
      local y = ROW_Y0 + (i - 1) * ROW_STEP
      Window.printPx(entry.label, LABEL_X, y, { colors = FrlgFont.COLOR.NORMAL })
      local value = valueOf(entry)
      if FrlgFont.measure(value) > VALUE_W then value = "" end
      Window.printPx(value, VALUE_X, y, { colors = FrlgFont.COLOR.OPTION_VALUE })
    end
    Window.cursorPx(LABEL_X - 8, ROW_Y0 + (state.index - 1) * ROW_STEP)
    local picked = state.entries[state.index]
    if picked and type(picked.about) == "string" then
      Window.printPx(picked.about, LABEL_X, ROW_Y0 + (#state.entries + 1) * ROW_STEP,
        { colors = FrlgFont.COLOR.NORMAL })
    end
  end

  return P
end

-- START menu: add `entry` to the PRISM item (making it, just above MODS
-- or EXIT, if it isn't there). Returns the new list. -Elvie
function prism.addStart(items, entry, picker, game)
  local out, found = {}, nil
  for i, item in ipairs(items) do
    out[i] = item
    if type(item) == "table" and item.id == ID and type(item.entries) == "table" then found = i end
  end
  local entries = withEntry(found and out[found].entries, entry)
  local item = { id = ID, entries = entries }
  if #entries == 1 then
    item.label = entry.short or entry.label
    item.onSelect = function(g) entry.open(g or game) end
  else
    item.label = "PRISM"
    item.onSelect = function(g) picker.open(g or game, entries) end
  end
  if found then
    out[found] = item
    return out
  end
  local at
  for i, it in ipairs(out) do
    if type(it) == "table" and (it.id == "mods" or (it.id == "exit" and not at)) then at = i end
  end
  if not at then return items end
  table.insert(out, at, item)
  return out
end

-- OPTION menu: the same, as a row at the end. One mod: its label and its
-- value (the character, the NPC set); more: PRISM. -Elvie
function prism.addOption(rows, entry, picker, game)
  local out, found = {}, nil
  for i, row in ipairs(rows) do
    out[i] = row
    if type(row) == "table" and row.id == ID and type(row.entries) == "table" then found = i end
  end
  local entries = withEntry(found and out[found].entries, entry)
  local row = { id = ID, entries = entries }
  if #entries == 1 then
    row.label = entry.label
    row.value = function() return valueOf(entry) end
    row.activate = function(g) entry.open(g or game) end
  else
    row.label = "PRISM"
    row.value = function() return "" end
    row.activate = function(g) picker.open(g or game, entries) end
  end
  if found then out[found] = row else out[#out + 1] = row end
  return out
end

return prism
