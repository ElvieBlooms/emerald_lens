local lens = {}

local SPRITES_DIR = "assets/sprites"
local SURF_DIR = "assets/surfmons" -- ridden Pokemon for the LENS screen's SURF row -Elvie
local DEFAULT_GENDER_MODE = "girl" -- matches Crystal Lens, so a folder acts the same in both -Elvie
local VALID_GENDER_MODES = { boy = true, girl = true, enby = true }

-- A small JSON reader for meta.json. The engine's own lives under
-- src.link, which would make this mod ask for the network permission just
-- to read a file. Errors on anything malformed; callers pcall it. -Elvie
-- --------------------------------------------------
-- \u escapes become UTF-8, the same as the characters written out.
local function utf8Char(code)
  if code < 0x80 then return string.char(code) end
  if code < 0x800 then
    return string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
  end
  if code < 0x10000 then
    return string.char(0xE0 + math.floor(code / 0x1000), 0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
  end
  return string.char(0xF0 + math.floor(code / 0x40000), 0x80 + math.floor(code / 0x1000) % 0x40,
    0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
end

local function decodeJson(text)
  local pos = 1
  -- Notepad and some other Windows editors start the file with a UTF-8 BOM.
  if text:sub(1, 3) == "\239\187\191" then pos = 4 end
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
          pos = pos + 6
          if code >= 0xD800 and code <= 0xDBFF and text:sub(pos, pos + 1) == "\\u" then
            -- a surrogate pair: one character outside the BMP
            local low = tonumber(text:sub(pos + 2, pos + 5), 16)
            if low and low >= 0xDC00 and low <= 0xDFFF then
              code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
              pos = pos + 6
            end
          end
          out[#out + 1] = (code >= 0xD800 and code <= 0xDFFF) and "?" or utf8Char(code)
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
  local okGameboy, gameboy = pcall(require, "mods.emerald_lens.gameboy")
  if not okGameboy then gameboy = nil end
  local okCross, crossgame = pcall(require, "mods.emerald_lens.crossgame")
  if not okCross then crossgame = nil end
  local function readMeta(key)
    local metaPath = SPRITES_DIR .. "/" .. key .. "/meta.json"
    if mod.assets:info(metaPath) then
      local ok, decoded = pcall(decodeJson, mod:read(metaPath))
      if ok and type(decoded) == "table" then return decoded end
      mod.log:warn("%s/meta.json couldn't be read, using defaults: %s", key, tostring(decoded))
    end
    return {}
  end

  -- A label is sorted and turned into an option key, so it has to be text;
  -- anything else in meta.json (a number, true) falls back to the folder name.
  local function labelOf(meta, key)
    if type(meta.label) == "string" and meta.label ~= "" then return meta.label end
    return key:upper()
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
  -- The Game Boy games (gb = true) show a look's gen3/ sheets through
  -- gen12.lua, from the art families in order: FR/LG's first in Kanto,
  -- R/S/E's first in Johto. Game Boy looks are offered there too, drawn
  -- from their own Crystal Lens files (with Crystal Lens installed, only
  -- the ones it doesn't have itself).
  local FAMILIES = {
    { id = "frlg", suffix = "Frlg", label = "FR/LG" },
    { id = "rse",  suffix = "Rse",  label = "R/S/E" },
    { id = "gb1",  suffix = "Gb1",  label = "R/B/Y", gb = true, art = { "frlg", "rse" } },
    { id = "gb2",  suffix = "Gb2",  label = "G/S/C", gb = true, art = { "rse", "frlg" } },
  }
  local OFF = "__off"
  local allFolders, metaFor = {}, {}
  local lookFolders = { frlg = {}, rse = {}, gb1 = {}, gb2 = {} } -- [family][character] = looks
  -- A folder with no gen3/ art for a family but Crystal Lens art (or a
  -- romOverworld) is a Game Boy look there: gameboy.lua fits it to the
  -- Gen 3 sizes. [family][key] = true. -Elvie
  local gameBoyFor = { frlg = {}, rse = {}, gb1 = {}, gb2 = {} }
  -- A "fromGame" folder is the other family's player, read from that game
  -- (crossgame.lua), in the family it isn't from. [family][key] = true. -Elvie
  local crossFor = { frlg = {}, rse = {}, gb1 = {}, gb2 = {} }
  -- Folders with gen3/ art, for the Game Boy games' fallback order -Elvie
  local hasGen3 = {}
  -- DS games whose looks aren't offered because the dump isn't imported
  -- in Prism Importer: [name] = true
  local hiddenDS = {}
  -- [character] = DS game name, for characters with a look like that
  local hiddenChar = {}

  for _, key in ipairs(mod.assets:list(SPRITES_DIR)) do
    if isDirectory(SPRITES_DIR .. "/" .. key) then
      local meta = readMeta(key)
      metaFor[key] = meta
      local label = labelOf(meta, key)
      if meta.label ~= nil and meta.label ~= false and type(meta.label) ~= "string" then
        mod.log:warn("%s/meta.json: \"label\" should be text, using %s", key, label)
      end
      local character = (type(meta.character) == "string" and meta.character ~= "")
        and meta.character or label
      local entry = { label = label, key = key }
      allFolders[character] = allFolders[character] or {}
      table.insert(allFolders[character], entry)
      local root = SPRITES_DIR .. "/" .. key .. "/"
      local gameBoy = gameboy and gameboy.hasArt(mod, root, meta)
      if gameBoy then gameboy.register(root, meta) end
      for _, family in ipairs(FAMILIES) do
        local own = isDirectory(SPRITES_DIR .. "/" .. key .. "/gen3/" .. family.id)
        if family.gb then
          own = false
          for _, art in ipairs(family.art) do
            own = own or isDirectory(SPRITES_DIR .. "/" .. key .. "/gen3/" .. art)
          end
          if own then hasGen3[key] = true end
        end
        -- In the Game Boy games every one of them is offered, read from
        -- its own family's game (registered below, once the running game
        -- is known)
        local cross = crossgame ~= nil and crossgame.offeredIn(meta, family, mod)
        if crossgame and crossgame.dsOf(meta) and not cross then
          hiddenDS[crossgame.DS[crossgame.dsOf(meta)].name] = true
          hiddenChar[character] = crossgame.DS[crossgame.dsOf(meta)].name
        end
        if cross and not family.gb then
          crossgame.register(SPRITES_DIR .. "/" .. key .. "/gen3/" .. family.id .. "/", meta)
        elseif crossgame and crossgame.homeOf and crossgame.homeOf(meta) == family.id and not own then
          -- RED FR/LG and LEAF FR/LG in FR/LG: not a look there, but the
          -- character's other looks fall back to them (Elvie, 2026-11-11)
          crossgame.register(SPRITES_DIR .. "/" .. key .. "/gen3/" .. family.id .. "/", meta)
        end
        if cross then
          crossFor[family.id][key] = true
          if family.gb then hasGen3[key] = true end
        end
        if not own and gameBoy then gameBoyFor[family.id][key] = true end
        if own or gameBoy or cross then
          local looks = lookFolders[family.id]
          looks[character] = looks[character] or {}
          table.insert(looks[character], entry)
        end
      end
    end
  end
  for _, entries in pairs(allFolders) do table.sort(entries, byLabel) end

  -- Option keys per character. sanitizeKey turns "A-B" and "A_B" into the
  -- same key, so a clash gets _2, _3... A name that is already a clean key
  -- keeps it, then the rest go in name order, so keys don't move around
  -- between runs and existing settings stay where they are.
  local optionKeyOf = {}
  do
    local names, used = {}, {}
    for character in pairs(allFolders) do names[#names + 1] = character end
    table.sort(names, function(a, b)
      local ca, cb = sanitizeKey(a) == a, sanitizeKey(b) == b
      if ca ~= cb then return ca end
      return a < b
    end)
    for _, character in ipairs(names) do
      local base = sanitizeKey(character)
      local key, n = base, 1
      while used[key] do n = n + 1; key = base .. "_" .. n end
      used[key], optionKeyOf[character] = true, key
    end
  end
  local function characterKey(character)
    return optionKeyOf[character] or sanitizeKey(character)
  end

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
    mod.log:info("no character folders with gen3 or Game Boy art in %s; nothing to replace", SPRITES_DIR)
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

  local function genderModeOf(key)
    local meta = metaFor[key] or {}
    return (type(meta.genderMode) == "string" and VALID_GENDER_MODES[meta.genderMode])
      and meta.genderMode or DEFAULT_GENDER_MODE
  end

  -- Up to 0.1.5 there was one CHARACTER for both families. A saved choice
  -- carries over as the default for each family that has that character. -Elvie
  local oldCharacter = mod.options:get("character")

  local defaults, lookDefaults = {}, {}
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
      for _, choice in ipairs(choices) do
        local looks = lookFolders[family.id][choice.key]
        -- the first look in menu order, but not a Game Boy one or one read
        -- from the other games if the character has art of its own, so
        -- added folders don't change it -Elvie
        local lookDefault = looks[1].key
        for i = #looks, 1, -1 do
          local key = looks[i].key
          if not gameBoyFor[family.id][key] and not crossFor[family.id][key] then lookDefault = key end
        end
        local oldLook = mod.options:get("lookFor_" .. sanitizeKey(choice.key))
        for _, entry in ipairs(looks) do
          if entry.key == oldLook then lookDefault = oldLook end
        end
        lookDefaults[family.id .. ":" .. choice.key] = lookDefault
      end
    end
  end

  local function lookKey(family, character)
    return "look" .. family.suffix .. "_" .. characterKey(character)
  end

  -- The rival's rows have keys of their own, so the rival can be any
  -- character, the player's too, in any look. -Elvie
  local function rivalLookKey(family, character)
    return "rivalLook" .. family.suffix .. "_" .. characterKey(character)
  end

  -- The look a character would use in this family right now (as the
  -- rival, with rival = true). -Elvie
  local function selectedLook(family, character, rival)
    local looks = lookFolders[family.id][character]
    local wanted = mod.options:get((rival and rivalLookKey or lookKey)(family, character))
    for _, entry in ipairs(looks) do
      if entry.key == wanted then return wanted end
    end
    return lookDefaults[family.id .. ":" .. character] or looks[1].key
  end

  -- Ridden Pokemon (surf kits): assets/surfmons/<id>/ with a meta.json
  -- (label, credit) and frlg/ and rse/ folders made by pack_gen3.py
  -- surfmon. Picked on the LENS screen only, per family (in the Game Boy
  -- games in the mod options too); OFF keeps the look's blob or the
  -- game's. -Elvie
  local surfKits = {} -- [family id] = { { key, label, credit } } -Elvie
  for _, id in ipairs(mod.assets:list(SURF_DIR) or {}) do
    if isDirectory(SURF_DIR .. "/" .. id) then
      local ok, meta = pcall(decodeJson, mod:read(SURF_DIR .. "/" .. id .. "/meta.json"))
      meta = ok and type(meta) == "table" and meta or {}
      for _, family in ipairs(FAMILIES) do
        local has = false
        for _, art in ipairs(family.art or { family.id }) do
          has = has or mod.assets:info(SURF_DIR .. "/" .. id .. "/" .. art .. "/surfBlob.png") ~= nil
        end
        if has then
          surfKits[family.id] = surfKits[family.id] or {}
          table.insert(surfKits[family.id], { key = id, label = labelOf(meta, id), credit = meta.credit })
        end
      end
    end
  end
  for _, list in pairs(surfKits) do table.sort(list, byLabel) end
  local function surfKitOf(family)
    local value = mod.options:get("surf" .. family.suffix)
    for _, kit in ipairs(surfKits[family.id] or {}) do
      if kit.key == value then return value end
    end
    return nil
  end

  -- Layout
  -- A heading per family with CHARACTER, LOOK and GENDER under it, then
  -- RIVAL, RIVAL LOOK and TEXT, then a reminder at the bottom. Mod options only have rows the cursor can land
  -- on, so the headings and the reminder are choice rows with one
  -- choice: selectable, but they do nothing. -Elvie
  -- --------------------------------------------------
  local INERT = "_"
  local function inertRow(key, label, visibleIf)
    return { key = key, type = "choice", label = label, choices = { { "", INERT } },
      default = INERT, visible_if = visibleIf }
  end

  -- A boy or girl look only replaces that player, unless GENDER is MY
  -- SAVE, so the menu ends with a reminder. Labels are cut at 18
  -- characters, so it takes two rows. -Elvie
  local WARNING = { "GENDER MY SAVE:", "FITS EITHER SAVE" }

  -- GENDER: the selected look's genderMode, or MY SAVE, where the look
  -- replaces whichever player the save picked (as an enby look does).
  -- Only the sprites; the text still follows the look. The options screen
  -- keeps the rows it opened with but reads each value as it draws, so
  -- the first choice's text is changed in place and shows straight away.
  -- Values are cut at 8 characters, hence ENBY. -Elvie
  local GENDER_TEXT = { boy = "BOY", girl = "GIRL", enby = "ENBY" }
  local LOOK_GENDER, SAVE_GENDER = "look", "save"
  local genderRows = {} -- [family id] = the GENDER row
  local function genderRow(key)
    return { key = key, type = "choice", label = "  GENDER",
      choices = { { "", LOOK_GENDER }, { "MY SAVE", SAVE_GENDER } }, default = LOOK_GENDER }
  end

  -- Crystal Lens (mods/crystal), when it's running too: in the Game Boy
  -- games it keeps the choices and these looks join its lists, so the
  -- R/B/Y and G/S/C rows aren't added here (see the end of init). -Elvie
  local crystal = type(mod.find) == "function" and mod.find("crystal") or nil
  local crystalLens = type(crystal) == "table" and type(crystal.exports) == "table"
    and type(crystal.exports.lens) == "table" and type(crystal.exports.lens.addLooks) == "function"
    and crystal.exports.lens or nil

  local function buildRows()
    local rows = {}
    for _, family in ipairs(FAMILIES) do
      local choices = choicesFor[family.id]
      -- With Crystal Lens leading, its rows pick the look, so only SURF
      -- is left here, for when one of these looks rides
      if family.gb and crystalLens then
        if #choices > 0 and surfKits[family.id] and #surfKits[family.id] > 0 then
          table.insert(rows, inertRow("section" .. family.suffix, family.label))
          local kits = pairsOf(surfKits[family.id])
          table.insert(kits, 1, { "OFF", OFF })
          table.insert(rows, { key = "surf" .. family.suffix, type = "choice", label = "  SURF",
            choices = kits, default = OFF })
        end
        choices = {}
      end
      if #choices > 0 then
        local characterKey = "character" .. family.suffix
        table.insert(rows, inertRow("section" .. family.suffix, family.label))
        local list = pairsOf(choices)
        table.insert(list, { "OFF", OFF })
        -- OFF to start with in the Game Boy games, so Crystal Lens's
        -- player stays until you pick one here -Elvie
        table.insert(rows, { key = characterKey, type = "choice", label = "  CHARACTER",
          choices = list, default = family.gb and OFF or defaults[family.id] })
        for _, choice in ipairs(choices) do
          local looks = lookFolders[family.id][choice.key]
          if #looks > 1 then
            table.insert(rows, {
              key = lookKey(family, choice.key), type = "choice",
              label = "  LOOK", choices = pairsOf(looks),
              default = lookDefaults[family.id .. ":" .. choice.key],
              visible_if = { key = characterKey, equals = choice.key },
            })
          end
        end
        -- Game Boy games: GENDER only in Crystal (G/S/C), where there's
        -- a Kris; RIVAL for Blue or Silver; no text rows; SURF here as
        -- well as on the LENS screen
        if family.gb then
          if family.id == "gb2" then
            genderRows[family.id] = genderRow("gender" .. family.suffix)
            table.insert(rows, genderRows[family.id])
          end
          local rivalKey = "rival" .. family.suffix
          local rivals = pairsOf(choices)
          table.insert(rivals, 1, { "OFF", OFF })
          table.insert(rows, { key = rivalKey, type = "choice", label = "  RIVAL",
            choices = rivals, default = OFF })
          for _, choice in ipairs(choices) do
            local looks = lookFolders[family.id][choice.key]
            if #looks > 1 then
              table.insert(rows, {
                key = rivalLookKey(family, choice.key), type = "choice",
                label = "  RIVAL LOOK", choices = pairsOf(looks),
                default = lookDefaults[family.id .. ":" .. choice.key],
                visible_if = { key = rivalKey, equals = choice.key },
              })
            end
          end
          if surfKits[family.id] and #surfKits[family.id] > 0 then
            local kits = pairsOf(surfKits[family.id])
            table.insert(kits, 1, { "OFF", OFF })
            table.insert(rows, { key = "surf" .. family.suffix, type = "choice", label = "  SURF",
              choices = kits, default = OFF })
          end
          goto nextFamily
        end
        genderRows[family.id] = genderRow("gender" .. family.suffix)
        table.insert(rows, genderRows[family.id])
        -- R/S/E: the gender the player didn't pick; FR/LG: Blue. OFF keeps
        -- the game's own rival. -Elvie
        local rivalKey = "rival" .. family.suffix
        local rivals = pairsOf(choices)
        table.insert(rivals, 1, { "OFF", OFF })
        table.insert(rows, { key = rivalKey, type = "choice", label = "  RIVAL",
          choices = rivals, default = OFF })
        for _, choice in ipairs(choices) do
          local looks = lookFolders[family.id][choice.key]
          if #looks > 1 then
            table.insert(rows, {
              key = rivalLookKey(family, choice.key), type = "choice",
              label = "  RIVAL LOOK", choices = pairsOf(looks),
              default = lookDefaults[family.id .. ":" .. choice.key],
              visible_if = { key = rivalKey, equals = choice.key },
            })
          end
        end
        -- Gendered text (wording.lua): ON rewords lines to the player's and
        -- the rival's looks, OFF keeps the game's own text. -Elvie
        table.insert(rows, { key = "text" .. family.suffix, type = "choice", label = "  TEXT",
          choices = { { "ON", "on" }, { "OFF", "off" } }, default = "on" })
      end
      ::nextFamily::
    end
    for i, line in ipairs(WARNING) do
      table.insert(rows, inertRow("warning" .. i, line))
    end
    return rows
  end
  mod.options:define(buildRows())

  -- Resolve this family's selected look, then hand gen3.lua the fallback
  -- chain (see resolve below). nil means OFF. Only the running game's
  -- family is set up. -Elvie
  -- --------------------------------------------------
  local okVersion, GameVersion = pcall(require, "src.core.GameVersion")
  local layout = okVersion and GameVersion.layout(GameVersion.get())
  local generation = okVersion and type(GameVersion.generation) == "function"
    and GameVersion.generation(GameVersion.get())
  if generation == 1 then layout = "gb1" elseif generation == 2 then layout = "gb2" end
  local running
  for _, f in ipairs(FAMILIES) do
    if f.id == layout then running = f end
  end
  -- Players from the Gen 3 games in a Game Boy game: each one's sheets
  -- come from its own family's game (Red and Leaf from FR/LG, Brendan and
  -- May from R/S/E), through crossgame.lua as in the Gen 3 games
  if running and running.gb and crossgame then
    for key in pairs(crossFor[running.id]) do
      local meta = metaFor[key]
      for _, from in ipairs(crossgame.layoutsFor(meta, running)) do
        crossgame.register(SPRITES_DIR .. "/" .. key .. "/gen3/" .. from .. "/", meta)
      end
    end
  end

  -- The character a family would use right now (nil for OFF). -Elvie
  local warnedHidden = {}
  local function currentCharacter(family)
    local character = mod.options:get("character" .. family.suffix)
    if character == OFF then return nil end
    if not lookFolders[family.id][character] then
      -- a DS character whose dump isn't imported (after Prism Importer
      -- updates, say) plays as the game's own player until it's back;
      -- the setting stays, so it returns after importing and a restart
      if hiddenChar[character] then
        if not warnedHidden[character] then
          warnedHidden[character] = true
          mod.log:info("%s needs the %s dump imported in Prism Importer; playing as the game's own player", character, hiddenChar[character])
        end
        return nil
      end
      if family.gb then return nil end
      character = defaults[family.id]
    end
    return character
  end

  -- GENDER set to MY SAVE (anything else is the look's own, including
  -- the "_" older versions stored in this row) -Elvie
  local function fitsSave(family)
    return mod.options:get("gender" .. family.suffix) == SAVE_GENDER
  end

  local function updateGender()
    for _, family in ipairs(FAMILIES) do
      local row = genderRows[family.id]
      if row then
        local character = currentCharacter(family)
        row.choices[1][1] = character and GENDER_TEXT[genderModeOf(selectedLook(family, character))] or ""
      end
    end
  end
  updateGender()

  -- "generation" in meta.json: 3 for art in the games' own style, 4 for
  -- bigger DS-style art. Left out, it's 3. A Game Boy look (in the running
  -- family) is 2, or 1 if meta.json says so. -Elvie
  local function generationOf(key)
    local g = tonumber((metaFor[key] or {}).generation)
    if running and gameBoyFor[running.id][key] then return g == 1 and 1 or 2 end
    -- in the Game Boy games, a folder with no gen3/ art has nothing to show -Elvie
    if running and running.gb and not hasGen3[key] then return 1 end
    return g == 4 and 4 or 3
  end

  -- Fallback: the selected look, then the character's looks of the same
  -- generation, then its other looks, each in menu order. With Game Boy
  -- looks in the mix, the other looks go closest first: Gen 3 and 4
  -- looks before Game Boy ones (and the other way round), then by how
  -- many generations apart. With only Gen 3 and 4 looks that's the same
  -- order as before. -Elvie
  local function chainFor(character, selected)
    local folderKeys = { selected }
    local gen = generationOf(selected)
    local others = {}
    for i, entry in ipairs(allFolders[character]) do
      if entry.key ~= selected then
        local g = generationOf(entry.key)
        local apart = ((g <= 2) ~= (gen <= 2)) and 10 or 0
        others[#others + 1] = { key = entry.key, rank = g == gen and -1 or apart + math.abs(g - gen), i = i }
      end
    end
    table.sort(others, function(a, b)
      if a.rank ~= b.rank then return a.rank < b.rank end
      return a.i < b.i
    end)
    for _, o in ipairs(others) do folderKeys[#folderKeys + 1] = o.key end
    return folderKeys
  end

  -- The rival's character (nil for OFF), the same way. -Elvie
  local function currentRival(family)
    local character = mod.options:get("rival" .. family.suffix)
    if character == OFF or not lookFolders[family.id][character] then return nil end
    return character
  end

  -- MIX
  -- One look's overworld sprites with another's battle pics, say. Each
  -- kind of art (gen3.GROUPS) gets a chain of its own: the look picked
  -- for it on the LENS screen (and that look's own fallback), then the
  -- player's look, then what its meta.json "borrow" names, then the
  -- character's other looks. "borrow" is for looks that only draw some
  -- of the art, so the rest doesn't drop to the game's own player:
  --   "borrow": { "default": "ASH", "battle": "kris_blue" }
  -- A value is a character (its default look in this game) or a look's
  -- folder. "default" is for every kind not named. The rival gets its
  -- own picks. Only the Gen 3 games. -Elvie
  -- rival: the families where the rival has that art (FR/LG's Blue only
  -- walks; R/S/E's rival has no Oak intro). overworld: what "borrow"'s
  -- "overworld" covers
  local MIX_GROUPS = {
    { id = "walk", label = "WALK", rival = { frlg = true, rse = true }, overworld = true },
    { id = "bike", label = "BIKE", rival = { rse = true }, overworld = true },
    { id = "surf", label = "SURF", rival = { rse = true }, overworld = true },
    { id = "fishing", label = "FISHING", overworld = true },
    { id = "fieldMove", label = "FIELD MOVE", rival = { rse = true }, overworld = true },
    { id = "fly", label = "FLY", overworld = true },
    { id = "battle", label = "BATTLE" },
    { id = "front", label = "FRONT PIC", rival = { frlg = true, rse = true } },
    { id = "intro", label = "INTRO", rival = { frlg = true }, only = "frlg" },
    { id = "mapIcon", label = "MAP ICON" },
    { id = "bag", label = "BAG" },
  }
  local AUTO = "auto"
  local characterOfLook = {}
  for character, entries in pairs(allFolders) do
    for _, entry in ipairs(entries) do characterOfLook[entry.key] = character end
  end
  local function mixGroups(family, rival)
    local out = {}
    for _, group in ipairs(MIX_GROUPS) do
      if (not rival or (group.rival and group.rival[family.id])) and (not group.only or group.only == family.id) then
        out[#out + 1] = group
      end
    end
    return out
  end
  local function mixKey(family, character, group, rival)
    return (rival and "rivalMix" or "mix") .. family.suffix .. "_" .. characterKey(character) .. "_" .. group
  end
  -- The look picked for a kind of art, or nil for AUTO (or a look that's
  -- gone)
  local function mixPick(family, character, group, rival)
    local value = mod.options:get(mixKey(family, character, group, rival))
    local owner = type(value) == "string" and characterOfLook[value]
    if not owner or not lookFolders[family.id][owner] then return nil end
    for _, entry in ipairs(lookFolders[family.id][owner]) do
      if entry.key == value then return value end
    end
    return nil
  end
  -- A "borrow" value as a chain: a character from its default look in
  -- this game, a look from itself
  local function borrowChain(family, value)
    if type(value) ~= "string" or value == "" then return nil end
    if allFolders[value] then
      local looks = lookFolders[family.id][value]
      local first = looks and (lookDefaults[family.id .. ":" .. value] or looks[1].key) or allFolders[value][1].key
      return chainFor(value, first)
    end
    local upper = value:upper()
    if allFolders[upper] then return borrowChain(family, upper) end
    if characterOfLook[value] then return chainFor(characterOfLook[value], value) end
    return nil
  end
  local function append(list, more)
    for _, key in ipairs(more or {}) do list[#list + 1] = key end
    return list
  end
  -- The look's chain with what it borrows, and a chain per kind of art
  -- where that kind is picked or borrowed on its own
  local function mixedChain(family, character, selected, rival)
    local own = chainFor(character, selected)
    local rest = {}
    for i = 2, #own do rest[#rest + 1] = own[i] end
    local borrow = (metaFor[selected] or {}).borrow
    if type(borrow) ~= "table" then borrow = {} end
    local default = borrowChain(family, borrow.default)
    local folderKeys = append(append({ selected }, default), rest)
    local groups, mixed = {}, {}
    if not family.gb then
      for _, group in ipairs(mixGroups(family, rival)) do
        local pick = mixPick(family, character, group.id, rival)
        local lent = borrowChain(family, borrow[group.id] or (group.overworld and borrow.overworld or nil))
        if pick or lent then
          local list = pick and chainFor(characterOfLook[pick], pick) or {}
          append(list, { selected })
          append(list, lent or default)
          local seen, unique = {}, {}
          for _, key in ipairs(append(list, rest)) do
            if not seen[key] then seen[key], unique[#unique + 1] = true, key end
          end
          groups[group.id] = unique
          if pick then mixed[#mixed + 1] = group end
        end
      end
    end
    return folderKeys, groups, mixed
  end


  local handle
  -- With Crystal Lens leading, its pick (see the end of init); restarting
  -- the sprites re-applies it instead of this mod's own rows -Elvie
  local crystalPick

  -- What's on right now, from every configure the sprites get (this
  -- mod's own rows or Crystal Lens's pick), for the achievements
  local lensNow, lensChanged = {}, nil
  local function noteLook(ctx)
    lensNow.look = ctx and ctx.lookKey or nil
    lensNow.surfKit = (ctx and ctx.surfKit) ~= nil
    -- the Game Boy games set the rival on its own (configureRival)
    if not (running and running.gb) then
      lensNow.rival = ctx and ctx.rival and type(ctx.rival.folderKeys) == "table" and ctx.rival.folderKeys[1] or nil
    end
    if lensChanged then lensChanged() end
  end
  local function noteRival(rivalCtx)
    lensNow.rival = rivalCtx and type(rivalCtx.folderKeys) == "table" and rivalCtx.folderKeys[1] or nil
    if lensChanged then lensChanged() end
  end
  local function watch(h, ctx)
    if type(h) ~= "table" then return h end
    noteLook(ctx)
    if ctx and ctx.rival then noteRival(ctx.rival) end
    local configure, configureRival = h.configure, h.configureRival
    h.configure = function(c, ...)
      noteLook(c)
      return configure(c, ...)
    end
    if configureRival then
      h.configureRival = function(r, ...)
        noteRival(r)
        return configureRival(r, ...)
      end
    end
    return h
  end
  local achievements
  local function resolve()
    local ctx = { folderKeys = {}, genderMode = DEFAULT_GENDER_MODE, spritesDir = SPRITES_DIR,
      gameBoy = gameBoyFor[running.id] }
    local character = currentCharacter(running)
    local kit = surfKitOf(running)
    if kit then
      -- gen12.lua picks the art family's folder itself -Elvie
      ctx.surfKit = SURF_DIR .. "/" .. kit .. "/" .. (running.gb and "" or (running.id .. "/"))
    end
    if character then
      local selected = selectedLook(running, character)
      ctx.folderKeys, ctx.groups = mixedChain(running, character, selected)
      ctx.lookKey = selected
      ctx.genderMode = genderModeOf(selected)
      ctx.fitSave = fitsSave(running) or nil
    end
    local rival = currentRival(running)
    if rival then
      local keys, groups = mixedChain(running, rival, selectedLook(running, rival, true), true)
      ctx.rival = { folderKeys = keys, groups = groups, gameBoy = gameBoyFor[running.id] }
    end
    if not character and not rival and not kit then return nil end
    return ctx
  end

  -- What the text follows: the player's look (nil for CHARACTER OFF) and
  -- the rival's (nil for RIVAL OFF). nil when TEXT is OFF. -Elvie
  local textHandle

  -- The rival's name in R/S/E: the look's first nameChoices entry (Crystal
  -- Lens's key for its name choices), else the character. Names are 7
  -- letters at most in Gen 3. -Elvie
  local NAME_LENGTH = 7
  local function rivalNameOf(key, character)
    local names = (metaFor[key] or {}).nameChoices
    local name = type(names) == "table" and type(names[1]) == "string" and names[1] ~= ""
      and names[1] or character
    local cut, n = {}, 0
    for ch in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
      n = n + 1
      if n > NAME_LENGTH then break end
      cut[n] = ch
    end
    return table.concat(cut)
  end

  local function textChoice()
    if mod.options:get("text" .. running.suffix) == "off" then return nil end
    local character, rival = currentCharacter(running), currentRival(running)
    if not character and not rival then return nil end
    local rivalLook = rival and selectedLook(running, rival, true)
    return {
      player = character and genderModeOf(selectedLook(running, character)) or nil,
      rival = rivalLook and genderModeOf(rivalLook) or nil,
      rivalName = rivalLook and rivalNameOf(rivalLook, rival) or nil,
    }
  end

  -- What the Game Boy LENS screens show of a look, through its chain:
  -- the front pic (rivalEarly.png first for the rival), and the walking
  -- sprite, a Gen 3 walk.png (walk) or a Game Boy overworldWalk.png in
  -- the look's overworldColors (walkGb, colors). Used by this mod's screen
  -- and Crystal Lens's.
  local CRYSTAL_COLORS = { { 255, 255, 255 }, { 255, 173, 99 }, { 1, 99, 198 }, { 0, 0, 0 } }
  local crossWalks = {} -- [key] = the walk read from its Gen 3 game, or false
  local function gbPreviewOf(character, look, rival)
    local out = {}
    local gb = running and gameBoyFor[running.id] or {}
    local names = rival and { "rivalEarly", "front" } or { "front" }
    for _, name in ipairs(names) do
      for _, key in ipairs((mixedChain(running, character, look, rival))) do
        local files = gb[key] and { SPRITES_DIR .. "/" .. key .. "/" .. name .. "Color.png", SPRITES_DIR .. "/" .. key .. "/" .. name .. ".png" } or {}
        if not gb[key] then
          for _, art in ipairs(running.art) do files[#files + 1] = SPRITES_DIR .. "/" .. key .. "/gen3/" .. art .. "/" .. name .. ".png" end
        end
        for _, rel in ipairs(files) do
          if not out.pic and mod.assets:info(rel) then out.pic = mod.assets:path(rel) end
        end
      end
    end
    for _, key in ipairs((mixedChain(running, character, look, rival))) do
      if out.walk or out.walkGb then break end
      if gb[key] then
        local rel = SPRITES_DIR .. "/" .. key .. "/overworldWalk.png"
        if mod.assets:info(rel) then
          local c = (metaFor[key] or {}).overworldColors
          out.walkGb, out.colors = mod.assets:path(rel), (type(c) == "table" and #c == 4) and c or CRYSTAL_COLORS
        end
      else
        for _, art in ipairs(running.art) do
          local rel = SPRITES_DIR .. "/" .. key .. "/gen3/" .. art .. "/walk.png"
          if not out.walk and mod.assets:info(rel) then out.walk = mod.assets:path(rel) end
        end
        -- a player from the Gen 3 games: the sheet read from that game
        -- (an ImageData; both LENS screens take one in place of a path)
        if not out.walk and crossFor[running.id][key] and crossgame then
          if crossWalks[key] == nil then
            local from = crossgame.layoutsFor(metaFor[key], running)[1]
            local base = SPRITES_DIR .. "/" .. key .. "/gen3/" .. from .. "/"
            local ok, data = false, nil
            if crossgame.has(mod, base, "walk.png", from) then ok, data = pcall(crossgame.load, mod, base, "walk.png", from) end
            crossWalks[key] = ok and data or false
          end
          out.walk = crossWalks[key] or nil
        end
      end
    end
    return out
  end

  -- The rival in the Game Boy games, from this mod's own rows (nil for OFF)
  local function gbRival()
    local rival = currentRival(running)
    if not rival then return nil end
    local look = selectedLook(running, rival, true)
    return { folderKeys = (mixedChain(running, rival, look, true)), spritesDir = SPRITES_DIR,
      gameBoy = gameBoyFor[running.id], genderMode = genderModeOf(look) }
  end

  if running and defaults[running.id] and running.gb then
    -- every look offered here, so each one's battle back gets its scale
    -- while the mod loads; and Yellow's surfing Pikachu, if it's shipped
    local lookKeys = {}
    for _, choice in ipairs(choicesFor[running.id]) do
      for _, entry in ipairs(lookFolders[running.id][choice.key]) do lookKeys[#lookKeys + 1] = entry.key end
    end
    local pikachu
    for _, kit in ipairs(surfKits[running.id] or {}) do
      if kit.key == "pikachu" then pikachu = SURF_DIR .. "/pikachu/" end
    end
    local first = not crystalLens and resolve() or nil
    if first then first.rival = gbRival() end
    handle = watch(require("mods.emerald_lens.gen12").init(mod, first, running,
      { lookKeys = lookKeys, gameBoy = gameBoyFor[running.id], spritesDir = SPRITES_DIR,
        pikachuKit = pikachu, ownCard = not crystalLens, ownText = not crystalLens }), first)
    if handle and crystalLens then
      -- Hand Crystal Lens every look with gen3/ art. While one is its
      -- front sprite, it calls configure with that look's key and this
      -- mod draws the player; otherwise configure(nil) and it doesn't.
      -- The same for its RIVAL: configureRival with the look's key while
      -- one of these is the rival, nil otherwise.
      local PREFIX = "emerald_lens:"
      local characterOf, looks = {}, {}
      for _, choice in ipairs(choicesFor[running.id]) do
        for _, entry in ipairs(lookFolders[running.id][choice.key]) do
          characterOf[entry.key] = choice.key
          local meta = metaFor[entry.key] or {}
          -- folder: Crystal Lens leaves out a Game Boy look it has itself;
          -- genderMode: its girl or enby text, after a restart
          looks[#looks + 1] = { key = PREFIX .. entry.key, character = choice.key, label = entry.label,
            credit = meta.credit, folder = entry.key, genderMode = genderModeOf(entry.key) }
        end
      end
      local function folderOf(key)
        return type(key) == "string" and key:sub(1, #PREFIX) == PREFIX and key:sub(#PREFIX + 1) or nil
      end
      local pickedFolder
      crystalLens.addLooks({
        id = mod.id,
        looks = looks,
        configure = function(key)
          local folder = folderOf(key)
          local character = folder and characterOf[folder]
          pickedFolder = character and folder or nil
          if not character then
            crystalPick = function() return nil end
            return handle.configure(nil)
          end
          -- Crystal Lens decides who's replaced (its GENDER row), so either;
          -- SURF is this mod's own row
          crystalPick = function()
            local kit = surfKitOf(running)
            return { folderKeys = (mixedChain(running, character, folder)), lookKey = folder, genderMode = genderModeOf(folder),
              fitSave = true, spritesDir = SPRITES_DIR, surfKit = kit and (SURF_DIR .. "/" .. kit .. "/") or nil,
              gameBoy = gameBoyFor[running.id] }
          end
          handle.configure(crystalPick())
        end,
        configureRival = function(key)
          local folder = folderOf(key)
          local character = folder and characterOf[folder]
          handle.configureRival(character and { folderKeys = (mixedChain(running, character, folder)), spritesDir = SPRITES_DIR,
            gameBoy = gameBoyFor[running.id], genderMode = genderModeOf(folder) } or nil)
        end,
        preview = function(key)
          local folder = folderOf(key)
          local character = folder and characterOf[folder]
          if not character then return nil end
          -- the card while this look is the player's: the one being drawn
          -- Crystal Lens's names: walk is a Game Boy sheet coloured with
          -- colors, walkFull a Gen 3 one drawn as it is
          local p = gbPreviewOf(character, folder)
          return { pic = p.pic, walk = p.walkGb, colors = p.colors, walkFull = p.walk,
            card = folder == pickedFolder and handle.card() or nil }
        end,
      })
    end
  elseif running and defaults[running.id] then
    local first = resolve()
    handle = watch(require("mods.emerald_lens.gen3").init(mod, first), first)
    textHandle = require("mods.emerald_lens.wording").init(mod, running.id)
    if textHandle then textHandle.configure(textChoice()) end
  end

  -- Achievements, with Recomp Achievements installed (achievements.lua)
  if running and handle then
    local characterOf
    achievements = require("mods.emerald_lens.achievements").init(mod, {
      family = running,
      now = function() return lensNow end,
      handle = handle,
      kindOf = function(key)
        if gameBoyFor[running.id][key] then return "gameboy" end
        if crossFor[running.id][key] and not (crossgame and crossgame.dsOf(metaFor[key])) then return "cross" end
        return "gen3"
      end,
      characterOf = function(key)
        if not characterOf then
          characterOf = {}
          for character, entries in pairs(allFolders) do
            for _, entry in ipairs(entries) do characterOf[entry.key] = character end
          end
        end
        return characterOf[key]
      end,
    })
    lensChanged = achievements and achievements.changed or nil
  end

  -- The LENS screen (lens_screen.lua)
  -- The running family's rows, read fresh each time it draws, and set the
  -- way the mod settings screen sets them (ManagerState:setOption), so
  -- everything below reacts the same. -Elvie
  -- --------------------------------------------------
  local function liveGame(game)
    if type(game) == "table" then return game end
    local ok, g = pcall(function() return mod.game end)
    return ok and type(g) == "table" and g or nil
  end

  local function setOption(game, key, value)
    local Runtime = package.loaded["src.mods.Runtime"]
    if Runtime and Runtime.safeMode then return end
    game = liveGame(game)
    if not game then return end
    -- The settings that get saved: game.options in Gold/Silver/Crystal and
    -- the Gen 3 games, game.save.options in Red/Blue/Yellow (the same table
    -- in Gold/Silver/Crystal), as the Mods manager writes them
    local saved = {}
    if type(game.options) == "table" then saved[#saved + 1] = game.options end
    local fromSave = type(game.save) == "table" and game.save.options
    if type(fromSave) == "table" and fromSave ~= game.options then saved[#saved + 1] = fromSave end
    for _, t in ipairs(saved) do
      t.modOptions = t.modOptions or {}
      t.modOptions[mod.id] = t.modOptions[mod.id] or {}
      t.modOptions[mod.id][key] = value
    end
    local loader = game.mods
    if type(loader) == "table" then
      loader.modOptions = loader.modOptions or {}
      loader.modOptions[mod.id] = loader.modOptions[mod.id] or {}
      loader.modOptions[mod.id][key] = value
    end
    if type(game.writeOptions) == "function" then pcall(game.writeOptions, game) end
    if type(loader) == "table" and loader.events then
      loader.events:emit("mod.options_changed", { mod = mod.id, key = key, value = value })
    end
  end

  local function choiceLabel(list, value)
    for _, choice in ipairs(list) do
      if choice[2] == value then return choice[1] end
    end
    return ""
  end

  local function screenRows()
    local f, rows = running, {}
    local function add(row)
      row.valueLabel = row.valueLabel or choiceLabel(row.choices, row.value)
      rows[#rows + 1] = row
    end
    local characters = pairsOf(choicesFor[f.id])
    table.insert(characters, { "OFF", OFF })
    local character = currentCharacter(f)
    add({ key = "character" .. f.suffix, label = "CHARACTER", who = "player",
      choices = characters, value = character or OFF })
    if character then
      -- A opens MIX for this look; a + after the name says something's mixed in
      local look = selectedLook(f, character)
      local _, _, mixed = mixedChain(f, character, look)
      local choices = pairsOf(lookFolders[f.id][character])
      add({ key = lookKey(f, character), label = "LOOK", who = "player", sub = "mix",
        choices = choices, value = look, valueLabel = choiceLabel(choices, look) .. (#mixed > 0 and " +" or "") })
      -- an enby look already fits either save, so it has no GENDER row -Elvie
      local mode = genderModeOf(selectedLook(f, character))
      if mode ~= "enby" then
        add({ key = "gender" .. f.suffix, label = "GENDER", who = "player",
          choices = { { GENDER_TEXT[mode], LOOK_GENDER }, { "MY SAVE", SAVE_GENDER } },
          value = fitsSave(f) and SAVE_GENDER or LOOK_GENDER })
      end
    end
    local rivals = pairsOf(choicesFor[f.id])
    table.insert(rivals, 1, { "OFF", OFF })
    local rival = currentRival(f)
    add({ key = "rival" .. f.suffix, label = "RIVAL", who = "rival", choices = rivals, value = rival or OFF })
    if rival then
      local look = selectedLook(f, rival, true)
      local _, _, mixed = mixedChain(f, rival, look, true)
      local choices = pairsOf(lookFolders[f.id][rival])
      add({ key = rivalLookKey(f, rival), label = "RIVAL LOOK", who = "rival", sub = "rivalMix",
        choices = choices, value = look, valueLabel = choiceLabel(choices, look) .. (#mixed > 0 and " +" or "") })
    end
    add({ key = "text" .. f.suffix, label = "TEXT", who = "text",
      choices = { { "ON", "on" }, { "OFF", "off" } },
      value = mod.options:get("text" .. f.suffix) == "off" and "off" or "on" })
    -- SURF: a Pokemon to ride, on this screen only -Elvie
    if surfKits[f.id] and #surfKits[f.id] > 0 then
      local kits = pairsOf(surfKits[f.id])
      table.insert(kits, 1, { "OFF", OFF })
      add({ key = "surf" .. f.suffix, label = "SURF", who = "surf", choices = kits, value = surfKitOf(f) or OFF })
    end
    -- A opens the full credits page (credits below). -Elvie
    add({ key = "credits", label = "CREDITS", who = "player", page = true, valueLabel = "SEE ALL" })
    return rows
  end

  -- Who each genderMode stands in for, and what the rival's text says. -Elvie
  local PLAYERS = {
    frlg = { boy = "RED", girl = "LEAF", enby = "RED/LEAF" },
    rse = { boy = "BRENDAN", girl = "MAY", enby = "BRENDAN/MAY" },
  }
  local MODE_WORD = { boy = "Boy", girl = "Girl", enby = "Enby" }
  local GRAND = { boy = "grandson", girl = "granddaughter", enby = "grandchild" }

  local function saveGender(game)
    game = liveGame(game)
    local session = game and game.session
    local g = type(session) == "table" and session.gender or nil
    if g == nil then return nil end
    return (g == 1 or g == "female" or g == "F") and "girl" or "boy"
  end

  local function lookName(character, key)
    local label = labelOf(metaFor[key] or {}, key)
    return label == character and character or (character .. ": " .. label)
  end

  -- What each kind of art covers, for the MIX page
  local MIX_ABOUT = {
    walk = "Walking and running.",
    bike = running and running.id == "rse" and "Mach and Acro Bikes." or "The bike.",
    bikeRival = "Mach and Acro Bikes.",
    surf = running and running.id == "rse" and "Surfing and diving." or "Surfing.",
    surfRival = "Surfing.",
    fishing = "Fishing.",
    fieldMove = running and running.id == "rse" and "Field moves, watering." or "Field moves, VS Seeker.",
    fieldMoveRival = "Field moves.",
    fly = "Flying, and the bird.",
    bag = "The bag.",
    battle = "The back pic and the throw.",
    front = running and running.id == "rse" and "Trainer card, Birch's intro." or "The trainer card.",
    frontRival = "The battle pic.",
    intro = "Oak's intro.",
    introRival = "Oak's intro, as his grandkid.",
    mapIcon = "The town map marker.",
  }

  -- the MIX rows whose kind the walker can show (lens_screen.lua SHEETS)
  local MIX_SHEET = { bike = true, surf = true, fishing = true, fieldMove = true, fly = true }

  local function creditLines(key, lines)
    local credit = (metaFor[key] or {}).credit
    if type(credit) == "string" then credit = { credit } end
    if type(credit) ~= "table" then return end
    for _, line in ipairs(credit) do
      if type(line) == "string" and line ~= "" then lines[#lines + 1] = { text = line } end
    end
  end

  local function basesFor(keys)
    local bases = {}
    for _, key in ipairs(keys) do
      bases[#bases + 1] = SPRITES_DIR .. "/" .. key .. (gameBoyFor[running.id][key] and "/" or ("/gen3/" .. running.id .. "/"))
    end
    return bases
  end
  -- The preview's folders: the front pic and the walker each through
  -- their own chain, so a MIX shows -Elvie
  local function previewOf(character, look, rival)
    local keys, groups = mixedChain(running, character, look, rival)
    return { bases = basesFor(keys), frontBases = basesFor(groups.front or keys),
      walkBases = basesFor(groups.walk or keys), layout = running.id }
  end

  -- A line saying more looks come with Prism Importer or another dump,
  -- or nil when every DS look is already offered
  local function moreLooks()
    if not (crossgame and next(hiddenDS)) then return nil end
    if not crossgame.hasImporter(mod) then return "More looks with Prism Importer." end
    local names = {}
    for name in pairs(hiddenDS) do names[#names + 1] = name end
    table.sort(names, function(a, b) return a > b end)
    return "More looks with " .. table.concat(names, ", ") .. "."
  end

  local function screenPreview(who, game)
    local f, names = running, PLAYERS[running.id]
    local textOn = mod.options:get("text" .. f.suffix) ~= "off"
    local lines = {}
    if who == "rival" then
      local rival = currentRival(f)
      if not rival then return { lines = { { text = "The game's own rival." } } } end
      local look = selectedLook(f, rival, true)
      local mode = genderModeOf(look)
      if f.id == "frlg" then
        lines[1] = { text = "Stands in for BLUE." }
        if textOn then lines[2] = { text = "Oak's " .. GRAND[mode] .. "." } end
      else
        local picked = saveGender(game)
        lines[1] = { text = picked and ("Takes over " .. (picked == "girl" and "BRENDAN" or "MAY") .. ".")
          or "Shows once there's a save." }
        if textOn then lines[2] = { text = "Called " .. rivalNameOf(look, rival) .. "." } end
      end
      if gameBoyFor[f.id][look] then lines[#lines + 1] = { text = "Game Boy art." } end
      if crossFor[f.id][look] and crossgame then
        lines[#lines + 1] = { text = "Read from your " .. (crossgame.sourceName(metaFor[look], f.id) or "game") .. "." }
      end
      creditLines(look, lines)
      local p = previewOf(rival, look, true)
      p.frontFile, p.lines = f.id == "frlg" and "rivalEarly.png" or nil, lines
      return p
    end
    local mixWho, mixGroup = who:match("^(%a+):(%a+)$")
    if mixWho then
      -- a MIX row: what that kind of art covers, and whose it is
      local rival = mixWho == "rivalMix"
      local character = rival and currentRival(f) or currentCharacter(f)
      if not character then return { lines = {} } end
      local look = selectedLook(f, character, rival)
      local pick = mixPick(f, character, mixGroup, rival)
      lines[1] = { text = MIX_ABOUT[mixGroup .. (rival and "Rival" or "")] or MIX_ABOUT[mixGroup] or "" }
      if pick then
        lines[2] = { text = "From " .. lookName(characterOfLook[pick], pick) .. "." }
        creditLines(pick, lines)
      else
        lines[2] = { text = "The look's own, as it falls back." }
      end
      local p = previewOf(character, look, rival)
      if rival and f.id == "frlg" then p.frontFile = "rivalEarly.png" end
      -- an overworld row's walker shows that kind of art, through its chain
      if mixGroup ~= "walk" and MIX_SHEET[mixGroup] then
        local keys, groups = mixedChain(running, character, look, rival)
        p.sheet, p.walkBases = mixGroup, basesFor(groups[mixGroup] or keys)
      end
      p.lines = lines
      return p
    end
    if who == "surf" then
      local kit = surfKitOf(f)
      if not kit then return { lines = { { text = "The look's surf blob, or the game's." } } } end
      for _, entry in ipairs(surfKits[f.id]) do
        if entry.key == kit then
          lines[1] = { text = "Everyone rides " .. entry.label .. "." }
          local credit = entry.credit
          if type(credit) == "string" then credit = { credit } end
          for _, line in ipairs(type(credit) == "table" and credit or {}) do lines[#lines + 1] = { text = line } end
        end
      end
      local character = currentCharacter(f)
      if not character then return { lines = lines } end
      local look = selectedLook(f, character)
      local p = previewOf(character, look)
      p.lines = lines
      return p
    end
    local character = currentCharacter(f)
    if who == "text" then
      lines[1] = { text = textOn and "Lines match your looks." or "The game's own text." }
      if textOn then lines[2] = { text = "They/them for enby looks." } end
    end
    if not character then
      if who ~= "text" then
        lines[1] = { text = "The game's own player." }
        local more = moreLooks()
        if more then lines[2] = { text = more } end
      end
      return { lines = lines }
    end
    local look = selectedLook(f, character)
    local mode = genderModeOf(look)
    if who ~= "text" then
      local picked = saveGender(game)
      if fitsSave(f) and mode ~= "enby" then
        -- MY SAVE: whoever the save picked, both before there's a save -Elvie
        lines[1] = { text = (picked and "Save: replaces " or "Replaces ") .. names[picked or "enby"] .. "." }
      else
        lines[1] = { text = MODE_WORD[mode] .. ": replaces " .. names[mode] .. "." }
        if picked and mode ~= "enby" and picked ~= mode then
          lines[2] = { text = "Not shown: save is " .. names[picked] .. ".", red = true }
        end
      end
      if gameBoyFor[f.id][look] then lines[#lines + 1] = { text = "Game Boy art." } end
      if crossFor[f.id][look] and crossgame then
        lines[#lines + 1] = { text = "Read from your " .. (crossgame.sourceName(metaFor[look], f.id) or "game") .. "." }
      end
      creditLines(look, lines)
      local more = moreLooks()
      if more then lines[#lines + 1] = { text = more } end
    end
    local p = previewOf(character, look)
    p.lines = lines
    return p
  end

  -- The credits page: the player's and the rival's looks, every other
  -- look this family offers, then the mod itself. -Elvie

  local function screenCredits()
    local f, out, listed = running, {}, {}
    local function addLook(title, character, key)
      listed[key] = true
      out[#out + 1] = { text = title .. lookName(character, key), heading = true }
      local lines = {}
      creditLines(key, lines)
      if #lines == 0 then lines[1] = { text = "No credit listed." } end
      for _, line in ipairs(lines) do out[#out + 1] = { text = line.text } end
    end
    local character, rival = currentCharacter(f), currentRival(f)
    if character then addLook("YOU: ", character, selectedLook(f, character)) end
    if rival then addLook("RIVAL: ", rival, selectedLook(f, rival, true)) end
    -- looks mixed in, under the kind of art they're for -Elvie
    for _, who in ipairs({ { character, false, "YOU" }, { rival, true, "RIVAL" } }) do
      if who[1] then
        for _, group in ipairs(mixGroups(f, who[2])) do
          local pick = mixPick(f, who[1], group.id, who[2])
          if pick and not listed[pick] then addLook(who[3] .. ", " .. group.label .. ": ", characterOfLook[pick], pick) end
        end
      end
    end
    for _, choice in ipairs(choicesFor[f.id]) do
      for _, entry in ipairs(lookFolders[f.id][choice.key]) do
        if not listed[entry.key] then addLook("", choice.key, entry.key) end
      end
    end
    -- the Pokemon to ride on the SURF row -Elvie
    for _, kit in ipairs(surfKits[f.id] or {}) do
      out[#out + 1] = { text = "SURF: " .. kit.label, heading = true }
      local credit = kit.credit
      if type(credit) == "string" then credit = { credit } end
      for _, line in ipairs(type(credit) == "table" and credit or { "No credit listed." }) do out[#out + 1] = { text = line } end
    end
    local more = moreLooks()
    if more then out[#out + 1] = { text = more } end
    out[#out + 1] = { text = "EMERALD LENS", heading = true }
    out[#out + 1] = { text = "Built on the Crystal Lens framework by Dgray66, used with permission." }
    out[#out + 1] = { text = "Gen 3 support: Elvie" }
    return out
  end

  -- The MIX page for the player's look (sub "mix") or the rival's
  -- ("rivalMix"): a row per kind of art, AUTO or any look this game
  -- offers -Elvie
  local function mixRows(sub)
    local f, rows = running, {}
    local rival = sub == "rivalMix"
    local character = rival and currentRival(f) or currentCharacter(f)
    if not character then return rows end
    local choices = { { "AUTO", AUTO } }
    for _, choice in ipairs(choicesFor[f.id]) do
      for _, entry in ipairs(lookFolders[f.id][choice.key]) do
        choices[#choices + 1] = { lookName(choice.key, entry.key), entry.key }
      end
    end
    for _, group in ipairs(mixGroups(f, rival)) do
      local value = mixPick(f, character, group.id, rival) or AUTO
      rows[#rows + 1] = { key = mixKey(f, character, group.id, rival), label = group.label,
        who = sub .. ":" .. group.id, choices = choices, value = value,
        valueLabel = choiceLabel(choices, value) }
    end
    return rows
  end
  local function mixTitle(sub)
    return sub == "rivalMix" and "MIX: RIVAL" or "MIX: YOU"
  end

  local lensScreen
  if running and defaults[running.id] and not running.gb then
    lensScreen = require("mods.emerald_lens.lens_screen").new(mod, {
      title = function() return "EMERALD LENS" end,
      rows = screenRows,
      set = setOption,
      preview = screenPreview,
      credits = screenCredits,
      subRows = mixRows,
      subTitle = mixTitle,
    })
  end

  if lensScreen and mod.hooks and type(mod.hooks.wrap) == "function" then
    -- START and OPTION menus: through prism.lua, so with Facets (or
    -- another visuals mod) installed both share one PRISM item. On its
    -- own it's LENS on the START menu and EMERALD LENS, showing the
    -- character, on the OPTION menu, as before. -Elvie
    local prism = require("mods.emerald_lens.prism")
    local picker = prism.picker()
    local entry = { id = "emerald_lens", label = "EMERALD LENS", short = "LENS",
      about = "The look of you and your rival.",
      colour = { 24, 140, 72 }, -- emerald -Elvie
      order = 10, -- the lens first, Facets under it
      draw = function(area, clock)
        lensScreen.drawLook(screenPreview("player", liveGame()), {
          frontX = area.x0 + 16, frontY = area.y1 - 64, walkX = area.x1 - 18, walkBottom = area.y1,
        }, clock)
      end,
      value = function() return currentCharacter(running) or "OFF" end,
      open = function(g)
        if achievements then achievements.lensOpened() end
        lensScreen.open(liveGame(g))
      end,
    }
    mod.hooks:wrap("ui.start_menu.items", function(nextFn, game, items)
      local out = nextFn()
      if type(out) ~= "table" then return out end
      -- Not in the scripted tutorial menu, which waits on a pick. -Elvie
      local StartMenu = package.loaded["src.ui.game3.start_menu"]
      if StartMenu and StartMenu._tutorial then return out end
      return prism.addStart(out, entry, picker, game)
    end)
    mod.hooks:wrap("ui.options.rows", function(nextFn, game, rows)
      local out = nextFn()
      if type(out) ~= "table" then return out end
      return prism.addOption(out, entry, picker, game)
    end)
  end

  -- The Game Boy games: the LENS screen drawn their way (lens_gb.lua),
  -- on the START and OPTION menus through PRISM. Crystal Lens has its own
  -- LENS screen, so with it installed its rows pick the looks.
  -- --------------------------------------------------
  local function hasKris()
    local game = liveGame()
    local data = game and game.data
    local sprites = type(data) == "table" and (data.gen2Sprites or data.sprites)
    return type(sprites) == "table" and sprites.SPRITE_KRIS ~= nil
  end

  local function gbRows()
    local f, rows = running, {}
    local function add(row)
      row.valueLabel = row.valueLabel or choiceLabel(row.choices, row.value)
      rows[#rows + 1] = row
    end
    local characters = pairsOf(choicesFor[f.id])
    table.insert(characters, { "OFF", OFF })
    local character = currentCharacter(f)
    add({ key = "character" .. f.suffix, label = "CHAR", who = "player", choices = characters, value = character or OFF })
    if character then
      add({ key = lookKey(f, character), label = "LOOK", who = "player",
        choices = pairsOf(lookFolders[f.id][character]), value = selectedLook(f, character) })
      -- only Crystal has a girl to replace; an enby look fits either
      local mode = genderModeOf(selectedLook(f, character))
      if f.id == "gb2" and hasKris() and mode ~= "enby" then
        add({ key = "gender" .. f.suffix, label = "GENDER", who = "player",
          choices = { { GENDER_TEXT[mode], LOOK_GENDER }, { "MY SAVE", SAVE_GENDER } },
          value = fitsSave(f) and SAVE_GENDER or LOOK_GENDER })
      end
    end
    local rivals = pairsOf(choicesFor[f.id])
    table.insert(rivals, 1, { "OFF", OFF })
    local rival = currentRival(f)
    add({ key = "rival" .. f.suffix, label = "RIVAL", who = "rival", choices = rivals, value = rival or OFF })
    if rival then
      add({ key = rivalLookKey(f, rival), label = "R.LOOK", who = "rival",
        choices = pairsOf(lookFolders[f.id][rival]), value = selectedLook(f, rival, true) })
    end
    if surfKits[f.id] and #surfKits[f.id] > 0 then
      local kits = pairsOf(surfKits[f.id])
      table.insert(kits, 1, { "OFF", OFF })
      add({ key = "surf" .. f.suffix, label = "SURF", who = "player", choices = kits, value = surfKitOf(f) or OFF })
    end
    add({ key = "credits", label = "CREDITS", who = "player", page = true, valueLabel = "SEE ALL" })
    return rows
  end

  local function gbPreview(who)
    local f = running
    if who == "rival" then
      local rival = currentRival(f)
      if not rival then return { line = "THE GAME'S OWN" } end
      return gbPreviewOf(rival, selectedLook(f, rival, true), true)
    end
    local character = currentCharacter(f)
    if not character then return { line = "THE GAME'S OWN" } end
    return gbPreviewOf(character, selectedLook(f, character))
  end

  if running and defaults[running.id] and running.gb and not crystalLens then
    local gbScreen = require("mods.emerald_lens.lens_gb").new(mod, {
      rows = gbRows, set = setOption, preview = gbPreview, credits = screenCredits,
    })
    -- START and OPTION menus through prism.lua, as in the Gen 3 games: on
    -- its own it's LENS on START and EMERALD LENS on OPTION; with Facets
    -- (or another visuals mod) they share one PRISM item.
    local prism = require("mods.emerald_lens.prism")
    local prismScreen = prism.registerGb(mod)
    if gbScreen and mod.hooks and type(mod.hooks.wrap) == "function" then
      local entry = { id = "emerald_lens", label = "EMERALD LENS", short = "LENS",
        about = "The look of you and your rival.",
        colour = { 24, 140, 72 }, -- emerald
        order = 10, -- the lens first, Facets under it
        value = function() return currentCharacter(running) or "OFF" end,
        open = function(g)
          if achievements then achievements.lensOpened() end
          gbScreen.open(liveGame(g))
        end,
      }
      mod.hooks:wrap("ui.start_menu.items", function(nextFn, game, items)
        local out = nextFn(game, items)
        if type(out) ~= "table" then return out end
        return prism.addStartGb(mod, out, entry, liveGame(game), prismScreen)
      end)
      mod.hooks:wrap("ui.options.rows", function(nextFn, game, rows)
        local out = nextFn(game, rows)
        if type(out) ~= "table" then return out end
        return prism.addOptionGb(mod, out, entry, liveGame(game), prismScreen)
      end)
    end
  end

  if mod.events and type(mod.events.on) == "function" then
    -- Changing CHARACTER or LOOK in the mod options applies straight away,
    -- no restart, and GENDER follows (and MY SAVE in GENDER). Only the running family's rows
    -- change the sprites. -Elvie
    local lookPrefix = running and ("look" .. running.suffix .. "_")
    local rivalPrefix = running and ("rivalLook" .. running.suffix .. "_")
    local mixPrefix = running and ("mix" .. running.suffix .. "_")
    local rivalMixPrefix = running and ("rivalMix" .. running.suffix .. "_")
    mod.events:on("mod.options_changed", function(change)
      if type(change) ~= "table" or change.mod ~= mod.id or type(change.key) ~= "string" then return end
      local key = change.key
      if key:sub(1, 9) == "character" or key:sub(1, 4) == "look" then updateGender() end
      local rivalKey = key == "rival" .. running.suffix or key:sub(1, #rivalPrefix) == rivalPrefix
      if handle and (key == "character" .. running.suffix or key:sub(1, #lookPrefix) == lookPrefix
          or key == "gender" .. running.suffix or key == "surf" .. running.suffix or rivalKey
          or key:sub(1, #mixPrefix) == mixPrefix or key:sub(1, #rivalMixPrefix) == rivalMixPrefix) then
        handle.configure(crystalPick and crystalPick() or resolve())
      end
      -- the Game Boy games' rival is set apart from the player
      if handle and running.gb and not crystalLens and rivalKey then handle.configureRival(gbRival()) end
      if textHandle and (key == "character" .. running.suffix or key:sub(1, #lookPrefix) == lookPrefix
          or key == "rival" .. running.suffix or key:sub(1, #rivalPrefix) == rivalPrefix
          or key == "text" .. running.suffix) then
        textHandle.configure(textChoice())
      end
    end)
    -- A new or loaded save can change which slot the look takes (MY SAVE,
    -- enby, the Hoenn rival), and pics built for the last save or before
    -- any save stay in the engine's caches, so the sprites start over.
    if handle then
      local function restart()
        handle.configure(crystalPick and crystalPick() or resolve())
        if running.gb and not crystalLens then handle.configureRival(gbRival()) end
      end
      mod.events:on("save.loaded", restart)
      mod.events:on("save.created", restart)
    end
    -- The player's wording follows the gender picked in the save. -Elvie
    if textHandle then
      mod.events:on("save.loaded", textHandle.refresh)
      mod.events:on("save.created", textHandle.refresh)
    end
  end
end

return lens
