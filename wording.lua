-- Gendered text
-- Lines that assume the player's or the rival's gender, reworded to match
-- the look: girl or they/them wording. The tables are wording_frlg.lua and
-- wording_rse.lua; each entry names its line by pret label and finds it by a
-- hash of the game's own text, so one entry covers FireRed and LeafGreen,
-- every Ruby and Sapphire revision and Emerald, and no game text needs to
-- be stored to find it. -Elvie
--
-- Every script message, trainer line and intro line is read from the one
-- table the script bundle loads (Space.bundle.text), so swapping entries
-- there covers them all, and swapping them back is just as quick, which
-- is what makes the options apply live. A line another mod has changed
-- is left alone. -Elvie
-- --------------------------------------------------

local wording = {}

local TABLES = { frlg = "mods.emerald_lens.wording_frlg", rse = "mods.emerald_lens.wording_rse" }

-- Canonical form
-- The line as pret writes it: the words, \n \l \p for the breaks and
-- {PLAYER} {RIVAL} {STR_VAR_1} {KUN}... for the placeholders. Colours,
-- fonts and glyphs (ext and tag) are left out, so a coloured line hashes
-- the same as a plain one. -Elvie
-- --------------------------------------------------
local BREAKS = { nl = "\\n", scroll = "\\l", para = "\\p", player = "{PLAYER}", rival = "{RIVAL}" }
local PH_NAMES = { -- the same 0-7 in every Gen 3 game (characters.h)
  [0] = "UNKNOWN", "PLAYER", "STR_VAR_1", "STR_VAR_2", "STR_VAR_3", "KUN", "RIVAL", "VERSION",
}

function wording.canonical(ir)
  local parts = {}
  for _, seg in ipairs(ir) do
    local t = seg.t
    if t == "eos" then break end
    if t == "text" then
      parts[#parts + 1] = seg.s
    elseif BREAKS[t] then
      parts[#parts + 1] = BREAKS[t]
    elseif t == "strvar" then
      parts[#parts + 1] = "{STR_VAR_" .. tostring(seg.n) .. "}"
    elseif t == "ph" then
      parts[#parts + 1] = "{" .. tostring(seg.name or PH_NAMES[tonumber(seg.code)] or seg.code) .. "}"
    elseif t == "dynamic" then
      parts[#parts + 1] = "{DYNAMIC " .. tostring(seg.n) .. "}"
    elseif t == "bph" then
      parts[#parts + 1] = "{B_" .. tostring(seg.code) .. "}"
    end
  end
  return table.concat(parts)
end

-- FNV-1a, 32 bits, as 8 hex digits. h * 16777619 is split into a shift
-- and a small multiply so no bits are lost in a double. -Elvie
function wording.hash(s)
  local h = bit.tobit(0x811c9dc5)
  for i = 1, #s do
    h = bit.bxor(h, s:byte(i))
    h = bit.tobit(bit.lshift(h, 24) + h * 403)
  end
  return bit.tohex(h)
end

-- Rewording
-- An entry's girl/enby/boy value is either a list of { from, to } swaps,
-- made in order inside the line's words (whole words only, never across
-- a line break), or a string that replaces the whole line in pret form.
-- A swap that finds nothing means the line isn't what was expected, so
-- the line is left as it is. -Elvie
-- --------------------------------------------------
local function isLetter(c)
  return c ~= "" and c:find("^%a") ~= nil
end

-- Whole words: a swap that starts (or ends) with a letter can't start
-- (or end) inside a word, so "his" leaves "this" alone, while ", man" can
-- follow any word. -Elvie
local function replaceWords(s, from, to)
  local found, start = false, 1
  local wordStart, wordEnd = isLetter(from:sub(1, 1)), isLetter(from:sub(-1))
  while true do
    local a, b = s:find(from, start, true)
    if not a then break end
    if not (wordStart and isLetter(s:sub(a - 1, a - 1)))
        and not (wordEnd and isLetter(s:sub(b + 1, b + 1))) then
      s = s:sub(1, a - 1) .. to .. s:sub(b + 1)
      found = true
      start = a + #to
    else
      start = a + 1
    end
  end
  return s, found
end

local function withSwaps(ir, swaps)
  local out, hit = {}, {}
  for i, seg in ipairs(ir) do
    if seg.t == "text" then
      local s = seg.s
      for j, pair in ipairs(swaps) do
        local found
        s, found = replaceWords(s, pair[1], pair[2])
        hit[j] = hit[j] or found
      end
      out[i] = { t = "text", s = s }
    else
      out[i] = seg
    end
  end
  for j, pair in ipairs(swaps) do
    if not hit[j] then return nil, pair[1] end
  end
  return out
end

-- A whole new line keeps the original's leading colour/font codes. -Elvie
local function wholeLine(ir, line)
  local TextIR = require("src.core.game3.scripting.text_ir")
  local out = {}
  for _, seg in ipairs(ir) do
    if seg.t ~= "ext" and seg.t ~= "tag" then break end
    out[#out + 1] = seg
  end
  for _, seg in ipairs(TextIR.fromAscii((line:gsub("%$$", "")))) do out[#out + 1] = seg end
  return out
end

local function reworded(ir, value)
  if type(value) == "string" then return wholeLine(ir, value) end
  return withSwaps(ir, value)
end
wording._reworded = reworded -- for tools/wording/check.lua -Elvie

-- The R/S/E rival's name
-- The games write MAY and BRENDAN straight into the rival's lines
-- (speaker tags, "Registered MAY in the POKéNAV.", the POKéNAV entry), so
-- a rival look's name takes their place. Only one of them is the rival in
-- a save, and the other one's lines never show. -Elvie
-- --------------------------------------------------
local RIVAL_NAMES = { "MAY", "BRENDAN" }
local IS_RIVAL_NAME = { MAY = true, BRENDAN = true }

local function namesRival(canonical)
  for _, name in ipairs(RIVAL_NAMES) do
    if canonical:find(name, 1, true) and canonical:find("%f[%w]" .. name .. "%f[%W]") then
      return true
    end
  end
  return false
end

local function renamed(ir, name)
  local out, changed = {}, false
  for i, seg in ipairs(ir) do
    if seg.t == "text" then
      local s = seg.s
      for _, old in ipairs(RIVAL_NAMES) do
        local found
        s, found = replaceWords(s, old, name)
        changed = changed or found
      end
      out[i] = { t = "text", s = s }
    else
      out[i] = seg
    end
  end
  return changed and out or nil
end

-- Returns a handle whose configure(ctx) applies a choice, or nil when
-- this isn't a Gen 3 game. ctx: { player = genderMode or nil (CHARACTER
-- OFF), rival = genderMode or nil (RIVAL OFF), rivalName = the rival
-- look's name (R/S/E only) }; nil turns everything back to the game's own
-- text. -Elvie
-- --------------------------------------------------
function wording.init(mod, family)
  local tableName = TABLES[family]
  if not tableName then return nil end
  local okE, entries = pcall(require, tableName)
  if not okE or type(entries) ~= "table" then
    mod.log:warn("text: %s couldn't be loaded: %s", tableName, tostring(entries))
    return nil
  end
  local okV, GameVersion = pcall(require, "src.core.GameVersion")
  local version = okV and GameVersion.get() or nil

  -- Entries that say which games they're for skip the others. -Elvie
  local mine = {}
  for _, entry in ipairs(entries) do
    local wanted = entry.games == nil
    for _, game in ipairs(entry.games or {}) do wanted = wanted or game == version end
    if wanted then mine[#mine + 1] = entry end
  end

  local lines        -- the bundle's text table
  local index = {}   -- [hash] = { key, ... }
  local originals = {} -- [key] = the game's own line, as indexed
  local applied = {} -- [key] = the line written here
  local nameKeys = {} -- R/S/E: lines that name MAY or BRENDAN
  local renames = family == "rse"
  local rivalName -- the R/S/E rival's name now, nil for the game's own
  local warned = {}

  local function warnOnce(key, fmt, ...)
    if warned[key] then return end
    warned[key] = true
    mod.log:warn(fmt, ...)
  end

  -- Hashes every line once, the first time it's needed. -Elvie
  local function ready()
    if lines then return true end
    local okS, Space = pcall(require, "src.core.game3.scripting.space")
    local bundle = okS and (Space.bundle or Space.ensureBundle(nil)) or nil
    if not (bundle and type(bundle.text) == "table") then return false end
    lines = bundle.text
    local wanted = {}
    for _, entry in ipairs(mine) do wanted[entry.hash] = true end
    for key, ir in pairs(lines) do
      if type(ir) == "table" then
        local canonical = wording.canonical(ir)
        local h = wording.hash(canonical)
        if wanted[h] then
          index[h] = index[h] or {}
          table.insert(index[h], key)
          originals[key] = ir
        end
        if renames and namesRival(canonical) then
          nameKeys[#nameKeys + 1] = key
          originals[key] = ir
        end
      end
    end
    for _, entry in ipairs(mine) do
      if not index[entry.hash] then
        warnOnce(entry.label, "text: %s isn't in this game's text, left out", entry.label)
      end
    end
    return true
  end

  -- The gender the player picked, the way gen3.lua reads it, or from the
  -- save an event just handed over (save.created comes before the game
  -- keeps the new session). nil before there's a save. -Elvie
  local eventSave
  local function pickedGender()
    local ok, game = pcall(function() return mod.game end)
    if not ok or type(game) ~= "table" then game = {} end
    local g
    if type(eventSave) == "table" then g = eventSave.gender end
    if g == nil and type(game.session) == "table" then g = game.session.gender end
    if g == nil and type(game.save) == "table" then g = game.save.gender end
    if g == nil then return nil end
    return (g == 1 or g == "female" or g == "F") and "female" or "male"
  end

  -- The player's wording follows the gender actually picked, so it matches
  -- the sprite: an enby look always, otherwise the save's gender (the
  -- look's own before there's a save). The rival's follows its look. -Elvie
  local function modeFor(who, ctx)
    if who == "rival" then return ctx.rival end
    if ctx.player == nil or ctx.player == "enby" then return ctx.player end
    local picked = pickedGender()
    if picked then return picked == "female" and "girl" or "boy" end
    return ctx.player
  end

  local function restore()
    for key, line in pairs(applied) do
      if lines[key] == line then lines[key] = originals[key] end
    end
    applied = {}
  end

  local current
  local function configure(ctx)
    current = ctx
    if not ready() then return end
    restore()
    rivalName = renames and ctx and ctx.rivalName or nil
    if not ctx then
      mod.log:info("text: the game's own lines")
      return
    end
    -- Each line is worked out first (the wording, then the rival's name),
    -- then written. -Elvie
    local planned = {}
    for _, entry in ipairs(mine) do
      local value = entry[modeFor(entry.who or "player", ctx) or ""]
      for _, key in ipairs(value and index[entry.hash] or {}) do
        local line, missing = reworded(originals[key], value)
        if line then
          planned[key] = line
        else
          warnOnce(entry.label .. ":" .. tostring(missing),
            "text: %s has no \"%s\", left as it is", entry.label, tostring(missing))
        end
      end
    end
    if rivalName then
      for _, key in ipairs(nameKeys) do
        planned[key] = renamed(planned[key] or originals[key], rivalName) or planned[key]
      end
    end
    local count = 0
    for key, line in pairs(planned) do
      -- Only the game's own line; another mod's stays theirs. -Elvie
      if lines[key] == originals[key] then
        lines[key] = line
        applied[key] = line
        count = count + 1
      end
    end
    -- One line each time, so the log shows what the text follows. -Elvie
    mod.log:info("text: player %s, rival %s%s, %d lines reworded",
      tostring(modeFor("player", ctx) or "off"), tostring(ctx.rival or "off"),
      rivalName and (" (" .. rivalName .. ")") or "", count)
  end

  -- A save being loaded or started can change the picked gender; its
  -- event's payload carries the save. -Elvie
  local function refresh(payload)
    if type(payload) == "table" and type(payload.save) == "table" then eventSave = payload.save end
    if current then configure(current) end
  end

  -- The rival's name in {RIVAL} and in battle. Both read rivalName as
  -- they go, so a new choice shows straight away. -Elvie
  -- --------------------------------------------------
  if renames then
    -- {RIVAL} is MAY or BRENDAN from the cart's placeholder strings, which
    -- the engine keeps once read, so the copy it hands out is swapped
    -- instead (text_ir.lua rival_name). -Elvie
    local okI, TextIR = pcall(require, "src.core.game3.scripting.text_ir")
    if okI and type(TextIR.placeholdersFor) == "function" then
      local originalFor = TextIR.placeholdersFor
      local copies = setmetatable({}, { __mode = "k" })
      TextIR.placeholdersFor = function(...)
        local ph = originalFor(...)
        if not (rivalName and type(ph) == "table" and type(ph.byGender) == "table"
            and ph.byGender.RIVAL) then
          return ph
        end
        local hit = copies[ph]
        if hit and hit.name == rivalName then return hit.copy end
        local copy, byGender = {}, {}
        for k, v in pairs(ph) do copy[k] = v end
        for k, v in pairs(ph.byGender) do byGender[k] = v end
        byGender.RIVAL = { male = rivalName, female = rivalName }
        copy.byGender, copy.RIVAL_MALE, copy.RIVAL_FEMALE = byGender, rivalName, rivalName
        copies[ph] = { name = rivalName, copy = copy }
        return copy
      end
    end

    -- Battles, prize money and the POKéNAV read trainers through
    -- Trainers.get, so the rival's battles get a renamed copy. -Elvie
    local okT, Trainers = pcall(require, "src.core.game3.scripting.trainers")
    if okT and type(Trainers.get) == "function" then
      local originalGet = Trainers.get
      local copies = setmetatable({}, { __mode = "k" })
      Trainers.get = function(...)
        local t = originalGet(...)
        if not (rivalName and type(t) == "table" and IS_RIVAL_NAME[t.name]) then return t end
        local hit = copies[t]
        if hit and hit.name == rivalName then return hit.copy end
        local copy = {}
        for k, v in pairs(t) do copy[k] = v end
        copy.name = rivalName
        copies[t] = { name = rivalName, copy = copy }
        return copy
      end
    end
  end

  return { configure = configure, refresh = refresh }
end

return wording
