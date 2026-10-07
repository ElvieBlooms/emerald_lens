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
  -- "character" groups looks together. Only folders with a gen3/ folder
  -- show up as looks, but every folder of a character stays in the
  -- fallback chain. -Elvie
  -- --------------------------------------------------
  local allFolders, lookFolders, metaFor = {}, {}, {}

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
      if isDirectory(SPRITES_DIR .. "/" .. key .. "/gen3") then
        lookFolders[character] = lookFolders[character] or {}
        table.insert(lookFolders[character], entry)
      end
    end
  end

  local characterChoices = {}
  for character, entries in pairs(lookFolders) do
    table.sort(entries, byLabel)
    table.sort(allFolders[character], byLabel)
    table.insert(characterChoices, { label = character, key = character })
  end
  table.sort(characterChoices, byLabel)

  if #characterChoices == 0 then
    mod.log:info("no character folders with gen3 art in %s; nothing to replace", SPRITES_DIR)
    return
  end

  -- Options
  -- CHARACTER first, then a LOOK choice for any character with more than
  -- one look, hidden until that character is picked. -Elvie
  -- --------------------------------------------------
  local function pairsOf(list)
    local out = {}
    for _, entry in ipairs(list) do table.insert(out, { entry.label, entry.key }) end
    return out
  end

  local defaultCharacter = characterChoices[1].key
  for _, choice in ipairs(characterChoices) do
    if choice.key == "KRIS" then defaultCharacter = "KRIS" end
  end

  local rows = {
    { key = "character", type = "choice", label = "CHARACTER",
      choices = pairsOf(characterChoices), default = defaultCharacter },
  }
  for _, choice in ipairs(characterChoices) do
    local looks = lookFolders[choice.key]
    if #looks > 1 then
      table.insert(rows, {
        key = "lookFor_" .. sanitizeKey(choice.key), type = "choice", label = "LOOK",
        choices = pairsOf(looks), default = looks[1].key,
        visible_if = { key = "character", equals = choice.key },
      })
    end
  end
  mod.options:define(rows)

  -- Resolve the selected look, then hand gen3.lua the fallback chain:
  -- that look first, then the character's other folders in menu order. -Elvie
  -- --------------------------------------------------
  local character = mod.options:get("character")
  local looks = lookFolders[character]
  if not looks then
    character = defaultCharacter
    looks = lookFolders[character]
  end
  local selected = looks[1].key
  local wanted = mod.options:get("lookFor_" .. sanitizeKey(character))
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

  require("mods.emerald_lens.gen3").init(mod, {
    folderKeys = folderKeys,
    genderMode = genderMode,
    spritesDir = SPRITES_DIR,
  })
end

return lens
