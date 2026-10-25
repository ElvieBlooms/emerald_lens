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
  local okGameboy, gameboy = pcall(require, "mods.emerald_lens.gameboy")
  if not okGameboy then gameboy = nil end
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
  -- A folder with no gen3/ art for a family but Crystal Lens art (or a
  -- romOverworld) is a Game Boy look there: gameboy.lua fits it to the
  -- Gen 3 sizes. [family][key] = true. -Elvie
  local gameBoyFor = { frlg = {}, rse = {} }

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
      local root = SPRITES_DIR .. "/" .. key .. "/"
      local gameBoy = gameboy and gameboy.hasArt(mod, root, meta)
      if gameBoy then gameboy.register(root, meta) end
      for _, family in ipairs(FAMILIES) do
        local own = isDirectory(SPRITES_DIR .. "/" .. key .. "/gen3/" .. family.id)
        if not own and gameBoy then gameBoyFor[family.id][key] = true end
        if own or gameBoy then
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
        -- the first look in menu order, but not a Game Boy one if the
        -- character has Gen 3 or 4 art, so copied folders don't change it -Elvie
        local lookDefault = looks[1].key
        for i = #looks, 1, -1 do
          if not gameBoyFor[family.id][looks[i].key] then lookDefault = looks[i].key end
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
    return "look" .. family.suffix .. "_" .. sanitizeKey(character)
  end

  -- The rival's rows have keys of their own, so the rival can be any
  -- character, the player's too, in any look. -Elvie
  local function rivalLookKey(family, character)
    return "rivalLook" .. family.suffix .. "_" .. sanitizeKey(character)
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

  -- Layout
  -- A heading per family with CHARACTER, LOOK and GENDER under it, then
  -- RIVAL, RIVAL LOOK and TEXT, then a reminder at the bottom. Mod options only have rows the cursor can land
  -- on, so the headings, GENDER and the reminder are choice rows with one
  -- choice: selectable, but they do nothing. -Elvie
  -- --------------------------------------------------
  local INERT = "_"
  local function inertRow(key, label, visibleIf)
    return { key = key, type = "choice", label = label, choices = { { "", INERT } },
      default = INERT, visible_if = visibleIf }
  end

  -- A boy or girl character only replaces that player, so the menu ends
  -- with a reminder. Labels are cut at 18 characters, so it takes two
  -- rows. -Elvie
  local WARNING = { "GENDER MUST MATCH", "SAVE TO SHOW" }

  -- GENDER shows the selected look's genderMode. The options screen keeps
  -- the rows it opened with but reads each value as it draws, so the one
  -- choice's text is changed in place and shows straight away. Values are
  -- cut at 8 characters, hence ENBY. -Elvie
  local GENDER_TEXT = { boy = "BOY", girl = "GIRL", enby = "ENBY" }
  local genderRows = {} -- [family id] = the GENDER row

  local function buildRows()
    local rows = {}
    for _, family in ipairs(FAMILIES) do
      local choices = choicesFor[family.id]
      if #choices > 0 then
        local characterKey = "character" .. family.suffix
        table.insert(rows, inertRow("section" .. family.suffix, family.label))
        local list = pairsOf(choices)
        table.insert(list, { "OFF", OFF })
        table.insert(rows, { key = characterKey, type = "choice", label = "  CHARACTER",
          choices = list, default = defaults[family.id] })
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
        genderRows[family.id] = inertRow("gender" .. family.suffix, "  GENDER")
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
  local running
  for _, f in ipairs(FAMILIES) do
    if f.id == layout then running = f end
  end

  -- The character a family would use right now (nil for OFF). -Elvie
  local function currentCharacter(family)
    local character = mod.options:get("character" .. family.suffix)
    if character == OFF then return nil end
    if not lookFolders[family.id][character] then character = defaults[family.id] end
    return character
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

  local handle
  local function resolve()
    local ctx = { folderKeys = {}, genderMode = DEFAULT_GENDER_MODE, spritesDir = SPRITES_DIR,
      gameBoy = gameBoyFor[running.id] }
    local character = currentCharacter(running)
    if character then
      local selected = selectedLook(running, character)
      ctx.folderKeys = chainFor(character, selected)
      ctx.genderMode = genderModeOf(selected)
    end
    local rival = currentRival(running)
    if rival then
      ctx.rival = { folderKeys = chainFor(rival, selectedLook(running, rival, true)), gameBoy = gameBoyFor[running.id] }
    end
    if not character and not rival then return nil end
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

  if running and defaults[running.id] then
    handle = require("mods.emerald_lens.gen3").init(mod, resolve())
    textHandle = require("mods.emerald_lens.wording").init(mod, running.id)
    if textHandle then textHandle.configure(textChoice()) end
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
    if type(game.options) == "table" then
      game.options.modOptions = game.options.modOptions or {}
      game.options.modOptions[mod.id] = game.options.modOptions[mod.id] or {}
      game.options.modOptions[mod.id][key] = value
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

  local function labelOf(list, value)
    for _, choice in ipairs(list) do
      if choice[2] == value then return choice[1] end
    end
    return ""
  end

  local function screenRows()
    local f, rows = running, {}
    local function add(row)
      row.valueLabel = row.valueLabel or labelOf(row.choices, row.value)
      rows[#rows + 1] = row
    end
    local characters = pairsOf(choicesFor[f.id])
    table.insert(characters, { "OFF", OFF })
    local character = currentCharacter(f)
    add({ key = "character" .. f.suffix, label = "CHARACTER", who = "player",
      choices = characters, value = character or OFF })
    if character then
      add({ key = lookKey(f, character), label = "LOOK", who = "player",
        choices = pairsOf(lookFolders[f.id][character]), value = selectedLook(f, character) })
    end
    local rivals = pairsOf(choicesFor[f.id])
    table.insert(rivals, 1, { "OFF", OFF })
    local rival = currentRival(f)
    add({ key = "rival" .. f.suffix, label = "RIVAL", who = "rival", choices = rivals, value = rival or OFF })
    if rival then
      add({ key = rivalLookKey(f, rival), label = "RIVAL LOOK", who = "rival",
        choices = pairsOf(lookFolders[f.id][rival]), value = selectedLook(f, rival, true) })
    end
    add({ key = "text" .. f.suffix, label = "TEXT", who = "text",
      choices = { { "ON", "on" }, { "OFF", "off" } },
      value = mod.options:get("text" .. f.suffix) == "off" and "off" or "on" })
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

  local function creditLines(key, lines)
    local credit = (metaFor[key] or {}).credit
    if type(credit) == "string" then credit = { credit } end
    if type(credit) ~= "table" then return end
    for _, line in ipairs(credit) do
      if type(line) == "string" and line ~= "" then lines[#lines + 1] = { text = line } end
    end
  end

  local function basesOf(character, look)
    local bases = {}
    for _, key in ipairs(chainFor(character, look)) do
      bases[#bases + 1] = SPRITES_DIR .. "/" .. key .. (gameBoyFor[running.id][key] and "/" or ("/gen3/" .. running.id .. "/"))
    end
    return bases
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
      creditLines(look, lines)
      return { bases = basesOf(rival, look), frontFile = f.id == "frlg" and "rivalEarly.png" or nil,
        lines = lines, layout = f.id }
    end
    local character = currentCharacter(f)
    if who == "text" then
      lines[1] = { text = textOn and "Lines match your looks." or "The game's own text." }
      if textOn then lines[2] = { text = "They/them for enby looks." } end
    end
    if not character then
      if who ~= "text" then lines[1] = { text = "The game's own player." } end
      return { lines = lines }
    end
    local look = selectedLook(f, character)
    local mode = genderModeOf(look)
    if who ~= "text" then
      lines[1] = { text = MODE_WORD[mode] .. ": replaces " .. names[mode] .. "." }
      local picked = saveGender(game)
      if picked and mode ~= "enby" and picked ~= mode then
        lines[2] = { text = "Not shown: save is " .. names[picked] .. ".", red = true }
      end
      if gameBoyFor[f.id][look] then lines[#lines + 1] = { text = "Game Boy art." } end
      creditLines(look, lines)
    end
    return { bases = basesOf(character, look), lines = lines, layout = f.id }
  end

  -- The credits page: the player's and the rival's looks, every other
  -- look this family offers, then the mod itself. -Elvie
  local function lookName(character, key)
    local label = (metaFor[key] or {}).label or key:upper()
    return label == character and character or (character .. ": " .. label)
  end

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
    for _, choice in ipairs(choicesFor[f.id]) do
      for _, entry in ipairs(lookFolders[f.id][choice.key]) do
        if not listed[entry.key] then addLook("", choice.key, entry.key) end
      end
    end
    out[#out + 1] = { text = "EMERALD LENS", heading = true }
    out[#out + 1] = { text = "Built on the Crystal Lens framework by Dgray66, used with permission." }
    out[#out + 1] = { text = "Gen 3 support: Elvie" }
    return out
  end

  local lensScreen
  if running and defaults[running.id] then
    lensScreen = require("mods.emerald_lens.lens_screen").new(mod, {
      title = function() return "EMERALD LENS" end,
      rows = screenRows,
      set = setOption,
      preview = screenPreview,
      credits = screenCredits,
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
      draw = function(area, clock)
        lensScreen.drawLook(screenPreview("player", liveGame()), {
          frontX = area.x0 + 16, frontY = area.y1 - 64, walkX = area.x1 - 18, walkBottom = area.y1,
        }, clock)
      end,
      value = function() return currentCharacter(running) or "OFF" end,
      open = function(g) lensScreen.open(liveGame(g)) end,
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

  if mod.events and type(mod.events.on) == "function" then
    -- Changing CHARACTER or LOOK in the mod options applies straight away,
    -- no restart, and GENDER follows. Only the running family's rows
    -- change the sprites. -Elvie
    local lookPrefix = running and ("look" .. running.suffix .. "_")
    local rivalPrefix = running and ("rivalLook" .. running.suffix .. "_")
    mod.events:on("mod.options_changed", function(change)
      if type(change) ~= "table" or change.mod ~= mod.id or type(change.key) ~= "string" then return end
      local key = change.key
      if key:sub(1, 9) == "character" or key:sub(1, 4) == "look" then updateGender() end
      if handle and (key == "character" .. running.suffix or key:sub(1, #lookPrefix) == lookPrefix
          or key == "rival" .. running.suffix or key:sub(1, #rivalPrefix) == rivalPrefix) then
        handle.configure(resolve())
      end
      if textHandle and (key == "character" .. running.suffix or key:sub(1, #lookPrefix) == lookPrefix
          or key == "rival" .. running.suffix or key:sub(1, #rivalPrefix) == rivalPrefix
          or key == "text" .. running.suffix) then
        textHandle.configure(textChoice())
      end
    end)
    -- The player's wording follows the gender picked in the save. -Elvie
    if textHandle then
      mod.events:on("save.loaded", textHandle.refresh)
      mod.events:on("save.created", textHandle.refresh)
    end
  end
end

return lens
