local lens = {}

local SPRITES_DIR = "assets/sprites"
local DEFAULT_GENDER_MODE = "girl" -- matches Crystal Lens, so a folder acts the same in both -Elvie
local VALID_GENDER_MODES = { boy = true, girl = true, enby = true }

-- A small JSON reader for meta.json. The engine's own lives under
-- src.link, which would make this mod ask for the network permission just
-- to read a file. Errors on anything malformed; callers pcall it. -Elvie
-- --------------------------------------------------
local function decodeJson(text)
  local pos = 1
  local function fail(what) error(("meta.json: %s at character %d"):format(what, pos), 0) end
  local function skip() pos = text:find("[^ \t\r\n]", pos) or #text + 1 end
  local value
  local ESCAPES = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
  local function str()
    pos = pos + 1
    local out = {}
    while true do
      local c = text:sub(pos, pos)
      if c == "" then fail("unterminated string") end
      if c == '"' then pos = pos + 1; return table.concat(out) end
      if c == "\\" then
        local e = text:sub(pos + 1, pos + 1)
        if e == "u" then
          local code = tonumber(text:sub(pos + 2, pos + 5), 16) or fail("bad \\u escape")
          out[#out + 1] = code < 128 and string.char(code) or "?"
          pos = pos + 6
        else
          out[#out + 1] = ESCAPES[e] or fail("bad escape")
          pos = pos + 2
        end
      else
        out[#out + 1] = c
        pos = pos + 1
      end
    end
  end
  function value()
    skip()
    local c = text:sub(pos, pos)
    if c == "{" then
      local t = {}
      pos = pos + 1; skip()
      if text:sub(pos, pos) == "}" then pos = pos + 1; return t end
      while true do
        skip()
        if text:sub(pos, pos) ~= '"' then fail("expected a key") end
        local k = str(); skip()
        if text:sub(pos, pos) ~= ":" then fail("expected ':'") end
        pos = pos + 1
        t[k] = value(); skip()
        local d = text:sub(pos, pos); pos = pos + 1
        if d == "}" then return t end
        if d ~= "," then fail("expected ',' or '}'") end
      end
    elseif c == "[" then
      local t = {}
      pos = pos + 1; skip()
      if text:sub(pos, pos) == "]" then pos = pos + 1; return t end
      while true do
        t[#t + 1] = value(); skip()
        local d = text:sub(pos, pos); pos = pos + 1
        if d == "]" then return t end
        if d ~= "," then fail("expected ',' or ']'") end
      end
    elseif c == '"' then
      return str()
    end
    for word, v in pairs({ ["true"] = true, ["false"] = false, ["null"] = false }) do
      if text:sub(pos, pos + #word - 1) == word then pos = pos + #word; return v end
    end
    local num = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
    if num and num ~= "" and tonumber(num) then pos = pos + #num; return tonumber(num) end
    fail("unexpected input")
  end
  local result = value(); skip()
  if pos <= #text then fail("trailing input") end
  return result
end
lens.decodeJson = decodeJson

function lens.init(mod)
  local function readMeta(key)
    local metaPath = SPRITES_DIR .. "/" .. key .. "/meta.json"
    if mod.assets:info(metaPath) then
      local ok, decoded = pcall(decodeJson, mod:read(metaPath))
      if ok and type(decoded) == "table" then return decoded end
      mod.log:warn("%s/meta.json couldn't be read, using defaults: %s", key, tostring(decoded))
    end
    return {}
  end

  local function isDirectory(rel)
    local info = mod.assets:info(rel)
    return info and info.type == "directory"
  end

  local function byLabel(a, b)
    return a.label < b.label
  end

  local function sanitizeKey(s)
    return (s:gsub("%W", "_"))
  end

  -- Character folders
  -- Same meta.json format as Crystal Lens: "label" names a look and
  -- "character" groups looks together. FRLG and RSE are picked
  -- separately, since a character is a lot of work per game family: a look
  -- shows up for a family when it has that family's gen3 folder, but every
  -- folder of a character stays in the fallback chain. -Elvie
  -- --------------------------------------------------
  local FAMILIES = {
    { id = "frlg", suffix = "Frlg", label = "FR/LG" },
    { id = "rse",  suffix = "Rse",  label = "R/S/E" },
  }
  local OFF = "__off"
  local allFolders, metaFor = {}, {}
  local lookFolders = { frlg = {}, rse = {} } -- [family][character] = looks

  for _, key in ipairs(mod.assets:list(SPRITES_DIR)) do
    if isDirectory(SPRITES_DIR .. "/" .. key) then
      local meta = readMeta(key)
      metaFor[key] = meta
      local label = meta.label or key:upper()
      local character = (type(meta.character) == "string" and meta.character ~= "")
        and meta.character or label
      local entry = { label = label, key = key }
      allFolders[character] = allFolders[character] or {}
      table.insert(allFolders[character], entry)
      for _, family in ipairs(FAMILIES) do
        if isDirectory(SPRITES_DIR .. "/" .. key .. "/gen3/" .. family.id) then
          local looks = lookFolders[family.id]
          looks[character] = looks[character] or {}
          table.insert(looks[character], entry)
        end
      end
    end
  end
  for _, entries in pairs(allFolders) do table.sort(entries, byLabel) end

  local choicesFor, any = {}, false
  for _, family in ipairs(FAMILIES) do
    local choices = {}
    for character, entries in pairs(lookFolders[family.id]) do
      table.sort(entries, byLabel)
      table.insert(choices, { label = character, key = character })
    end
    table.sort(choices, byLabel)
    choicesFor[family.id] = choices
    any = any or #choices > 0
  end

  if not any then
    mod.log:info("no character folders with gen3 art in %s; nothing to replace", SPRITES_DIR)
    return
  end

  -- Options
  -- A CHARACTER row per family (plus OFF, to keep that family's own
  -- player), then a LOOK row for any character with more than one look
  -- there, hidden until that character is picked. Both families are
  -- always listed, since the options screen shows what was last defined
  -- whichever game is running. -Elvie
  -- --------------------------------------------------
  local function pairsOf(list)
    local out = {}
    for _, entry in ipairs(list) do table.insert(out, { entry.label, entry.key }) end
    return out
  end

  -- Up to 0.1.5 there was one CHARACTER for both families. A saved choice
  -- carries over as the default for each family that has that character. -Elvie
  local oldCharacter = mod.options:get("character")

  local rows, defaults = {}, {}
  for _, family in ipairs(FAMILIES) do
    local choices = choicesFor[family.id]
    if #choices > 0 then
      local default = choices[1].key
      for _, choice in ipairs(choices) do
        if choice.key == "KRIS" then default = "KRIS" end
      end
      for _, choice in ipairs(choices) do
        if choice.key == oldCharacter then default = oldCharacter end
      end
      defaults[family.id] = default
      local list = pairsOf(choices)
      table.insert(list, { "OFF", OFF })
      local characterKey = "character" .. family.suffix
      table.insert(rows, { key = characterKey, type = "choice", label = family.label .. " CHARACTER",
        choices = list, default = default })
      for _, choice in ipairs(choices) do
        local looks = lookFolders[family.id][choice.key]
        if #looks > 1 then
          local lookDefault = looks[1].key
          local oldLook = mod.options:get("lookFor_" .. sanitizeKey(choice.key))
          for _, entry in ipairs(looks) do
            if entry.key == oldLook then lookDefault = oldLook end
          end
          table.insert(rows, {
            key = "look" .. family.suffix .. "_" .. sanitizeKey(choice.key), type = "choice",
            label = family.label .. " LOOK", choices = pairsOf(looks), default = lookDefault,
            visible_if = { key = characterKey, equals = choice.key },
          })
        end
      end
    end
  end
  mod.options:define(rows)

  -- Resolve this family's selected look, then hand gen3.lua the fallback
  -- chain: that look first, then the character's other folders in menu
  -- order. nil means OFF. Only the running game's family is set up. -Elvie
  -- --------------------------------------------------
  local okVersion, GameVersion = pcall(require, "src.core.GameVersion")
  local layout = okVersion and GameVersion.layout(GameVersion.get())
  local family
  for _, f in ipairs(FAMILIES) do
    if f.id == layout then family = f end
  end
  if not family or not defaults[family.id] then return end

  local function resolve()
    local character = mod.options:get("character" .. family.suffix)
    if character == OFF then return nil end
    local looks = lookFolders[family.id][character]
    if not looks then
      character = defaults[family.id]
      looks = lookFolders[family.id][character]
    end
    local selected = looks[1].key
    local wanted = mod.options:get("look" .. family.suffix .. "_" .. sanitizeKey(character))
    for _, entry in ipairs(looks) do
      if entry.key == wanted then selected = wanted end
    end

    local folderKeys = { selected }
    for _, entry in ipairs(allFolders[character]) do
      if entry.key ~= selected then table.insert(folderKeys, entry.key) end
    end

    local meta = metaFor[selected] or {}
    local genderMode = (type(meta.genderMode) == "string" and VALID_GENDER_MODES[meta.genderMode])
      and meta.genderMode or DEFAULT_GENDER_MODE
    return { folderKeys = folderKeys, genderMode = genderMode, spritesDir = SPRITES_DIR }
  end

  local handle = require("mods.emerald_lens.gen3").init(mod, resolve())

  -- Changing CHARACTER or LOOK in the mod options applies straight away,
  -- no restart. The other family's rows are ignored here. -Elvie
  if handle and mod.events and type(mod.events.on) == "function" then
    local mine = { ["character" .. family.suffix] = true }
    mod.events:on("mod.options_changed", function(change)
      if type(change) ~= "table" or change.mod ~= mod.id or type(change.key) ~= "string" then return end
      if mine[change.key] or change.key:sub(1, #("look" .. family.suffix .. "_")) == "look" .. family.suffix .. "_" then
        handle.configure(resolve())
      end
    end)
  end
end

return lens
