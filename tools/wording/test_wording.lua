-- Headless tests for wording.lua, the TEXT option in lens.lua, the LENS
-- screen's rows (lens_screen.lua) and Game Boy looks. Run from
-- the repo root with luajit, pointing at an unpacked gen1recomp .love and
-- an install's FireRed cache (game text stays on your machine):
--
--   ENGINE=<unpacked .love> FRLG_TEXT=<firered/.../scripts/text.lua> \
--     luajit tools/wording/test_wording.lua
-- -Elvie
-- --------------------------------------------------

local ENGINE = assert(os.getenv("ENGINE"), "set ENGINE to an unpacked gen1recomp .love")
local FRLG_TEXT = assert(os.getenv("FRLG_TEXT"), "set FRLG_TEXT to firered's scripts/text.lua")
package.path = ENGINE .. "/?.lua;./?.lua;" .. package.path

local passed, failed = 0, 0
local function check(ok, what)
  if ok then passed = passed + 1 else failed = failed + 1; print("FAIL " .. what) end
end

local function loadData(path)
  local chunk = assert(loadfile(path))
  setfenv(chunk, {})
  return chunk()
end

-- Engine stand-ins: the game version and the script bundle. text_ir and
-- rom_text are the engine's own.
local version = "firered"
package.preload["src.core.GameVersion"] = function()
  return { get = function() return version end,
    layout = function(v) return (v == "firered" or v == "leafgreen") and "frlg" or "rse" end }
end
local Space = { bundle = nil }
function Space.ensureBundle() return Space.bundle end
package.loaded["src.core.game3.scripting.space"] = Space
package.loaded["mods.emerald_lens.wording"] = nil

local TextIR = require("src.core.game3.scripting.text_ir")
local RomText = require("src.core.game3.rom_text")
local wording = dofile("wording.lua")
package.loaded["mods.emerald_lens.wording"] = wording

local cache = loadData(FRLG_TEXT)
local function freshBundle()
  local t = {}
  for k, v in pairs(cache) do t[k] = v end
  Space.bundle = { text = t }
  return t
end

local function fakeMod(session)
  local logs = {}
  return {
    logs = logs,
    log = { warn = function(_, fmt, ...) logs[#logs + 1] = fmt:format(...) end,
            info = function() end },
    game = { session = session },
  }
end

local function plain(key) return TextIR.toPlain(Space.bundle.text[key], { rivalName = "BLUE" }) end
local OAK1, OAK2 = "gOakSpeech_Text_WhatWasHisName", "gOakSpeech_Text_RememberRivalsName"

-- Real table: the Oak intro follows the rival's look
-- --------------------------------------------------
do
  package.loaded["mods.emerald_lens.wording_frlg"] = dofile("wording_frlg.lua")
  local lines = freshBundle()
  local before1, before2 = lines[OAK1], lines[OAK2]
  local mod = fakeMod(nil)
  local h = wording.init(mod, "frlg")
  check(h ~= nil, "init returns a handle on FR/LG")

  h.configure({ player = "girl", rival = "girl" })
  check(plain(OAK1):find("This is my granddaughter.", 1, true), "girl rival: granddaughter")
  check(plain(OAK1):find("She's been your rival", 1, true), "girl rival: She's been")
  check(plain(OAK1):find("what was her name now?", 1, true), "girl rival: her name")
  check(plain(OAK2):find("Her name is BLUE!", 1, true), "girl rival: Her name is {RIVAL}")
  check(RomText.plain(OAK1):find("granddaughter", 1, true), "RomText (the intro's reader) sees it")

  h.configure({ player = "girl", rival = "enby" })
  check(plain(OAK1):find("They've been your rival since you\nboth", 1, true), "enby rival: whole line, moved break")
  check(plain(OAK2):find("Their name is BLUE!", 1, true), "enby rival: Their name")

  h.configure({ player = "girl", rival = "boy" })
  check(lines[OAK1] == before1 and lines[OAK2] == before2, "boy rival: the game's own lines, same tables")

  h.configure({ player = "enby", rival = nil })
  check(lines[OAK1] == before1, "RIVAL OFF: the game's own line")

  h.configure({ rival = "girl" })
  h.configure(nil)
  check(lines[OAK1] == before1 and lines[OAK2] == before2, "TEXT OFF / nil: everything restored")
  check(#mod.logs == 0, "no warnings for a table that matches: " .. table.concat(mod.logs, "; "))

  -- another mod's line is left alone, both ways
  local theirs = TextIR.fromAscii("Somebody else's line.")
  lines[OAK1] = theirs
  h.configure({ rival = "girl" })
  check(lines[OAK1] == theirs, "another mod's override isn't replaced")
  check(plain(OAK2):find("Her name", 1, true), "the other line still changes")
  h.configure({ rival = "girl" })
  lines[OAK2] = theirs -- a mod merging after ours
  h.configure({ rival = "enby" })
  check(lines[OAK2] == theirs, "a later override isn't restored over")
end

-- Made-up entries: player modes, swaps, headers, misses
-- --------------------------------------------------
local function lineHash(s) return wording.hash(wording.canonical(TextIR.fromAscii(s))) end

do
  local lines = freshBundle()
  lines.TestA = TextIR.fromAscii("Thanks, son! This is his.\\pGood lad.")
  lines.TestB = { { t = "ext", cmd = 1, args = { 2 } }, { t = "text", s = "Hey, chap!" }, { t = "eos" } }
  lines.TestC = TextIR.fromAscii("Nothing to swap here.")
  lines.TestD = TextIR.fromAscii("It's a drag, man. Manly.")
  local A, B = "Thanks, son! This is his.\\pGood lad.", "Hey, chap!"
  package.loaded["mods.emerald_lens.wording_frlg"] = {
    { label = "TestA", hash = lineHash(A), who = "player",
      girl = { { "son", "lass" }, { "his", "hers" }, { "lad", "lass" } },
      enby = { { "son", "kid" }, { "his", "theirs" }, { "lad", "kid" } } },
    { label = "TestB", hash = wording.hash("Hey, chap!"), who = "player", enby = "Hey, you!" },
    { label = "TestC", hash = lineHash("Nothing to swap here."), who = "player", girl = { { "absent", "x" } } },
    { label = "TestD", hash = lineHash("It's a drag, man. Manly."), who = "player",
      girl = { { ", man", "" } } },
    { label = "Missing", hash = "00000000", who = "player", girl = "x" },
    { label = "OtherGame", hash = "00000001", who = "player", games = { "emerald" }, girl = "x" },
  }
  check(wording.hash(wording.canonical(lines.TestB)) == wording.hash("Hey, chap!"), "colour codes don't change the hash")

  local session = {}
  local mod = fakeMod(session)
  local h = wording.init(mod, "frlg")

  h.configure({ player = "girl" }) -- before a save: the look's genderMode
  local a = TextIR.toPlain(lines.TestA, {})
  check(a == "Thanks, lass! This is hers.\n\nGood lass.", "girl swaps, whole words only (This stays): " .. a)
  local d = TextIR.toPlain(lines.TestD, {})
  check(d == "It's a drag. Manly.", "a swap starting with a comma follows a word: " .. d)

  session.gender = 0 -- a boy save: the look's girl doesn't apply
  h.refresh()
  check(lines.TestA == cache.TestA or wording.canonical(lines.TestA) == A, "boy save: the game's own line")

  session.gender = 1
  h.refresh()
  check(TextIR.toPlain(lines.TestA, {}):find("Good lass.", 1, true), "girl save: girl wording")

  h.configure({ player = "enby" }) -- enby looks ignore the save's gender
  session.gender = 0
  h.refresh()
  check(TextIR.toPlain(lines.TestA, {}) == "Thanks, kid! This is theirs.\n\nGood kid.", "enby: kid/theirs")
  check(lines.TestB[1].t == "ext" and lines.TestB[2].s == "Hey, you!", "whole line keeps the colour code")

  -- save.created's payload is read before the game keeps the session
  mod.game.session = nil
  h.configure({ player = "girl" })
  h.refresh({ save = { gender = 1 } })
  check(TextIR.toPlain(lines.TestA, {}):find("lass", 1, true), "save.created payload gives the gender")
  h.refresh({ save = { gender = 0 } })
  check(wording.canonical(lines.TestA) == A, "a new boy save puts the game's line back")

  local warns = table.concat(mod.logs, "\n")
  check(warns:find("Missing isn't in this game's text", 1, true), "unmatched entry is logged")
  check(not warns:find("OtherGame", 1, true), "an entry for another game isn't logged")
  check(warns:find('TestC has no "absent"', 1, true), "a swap that finds nothing is logged")
  check(wording.canonical(lines.TestC) == "Nothing to swap here.", "and its line is left alone")
end

-- R/S/E, when RSE_TEXT (Emerald's) and/or RS_TEXT (Ruby's) caches are
-- given: every entry for that game is found and applies, none from the
-- other is logged
-- --------------------------------------------------
local TRAINERS = { [1] = { name = "MAY", className = "POKéMON TRAINER" },
  [2] = { name = "BRENDAN", className = "POKéMON TRAINER" }, [3] = { name = "ROXANNE" } }
local TrainersStub = { get = function(id) return TRAINERS[id] end }
package.loaded["src.core.game3.scripting.trainers"] = TrainersStub
local plainGet = TrainersStub.get

for _, case in ipairs({ { env = "RSE_TEXT", game = "emerald" }, { env = "RS_TEXT", game = "ruby" } }) do
  local path = os.getenv(case.env)
  if path then
    version = case.game
    local t = loadData(path)
    Space.bundle = { text = t }
    local entries = dofile("wording_rse.lua")
    package.loaded["mods.emerald_lens.wording_rse"] = entries
    local before = {}
    for k, v in pairs(t) do before[k] = v end
    local mod = fakeMod({ gender = 1 })
    local h = wording.init(mod, "rse")
    h.configure({ player = "enby" })
    check(#mod.logs == 0, case.game .. ": no warnings: " .. table.concat(mod.logs, "; "))
    local changed = 0
    for k, v in pairs(t) do if before[k] ~= v then changed = changed + 1 end end
    local want = 0
    for _, e in ipairs(entries) do
      local mine = e.games == nil
      for _, g in ipairs(e.games or {}) do mine = mine or g == case.game end
      if mine and e.enby and (e.who or "player") == "player" then want = want + 1 end
    end
    check(changed >= want, ("%s: %d lines changed for %d entries"):format(case.game, changed, want))
    h.configure({ player = "girl" })
    local chap = 0
    for k, v in pairs(t) do
      if before[k] ~= v and TextIR.toPlain(v, {}):find("I dare say, friend", 1, true) then chap = chap + 1 end
    end
    check(chap >= 1, case.game .. ": a girl save gets the Dewford line")
    -- the rival's name, with the enby wording on the same line -Elvie
    TrainersStub.get = plainGet
    local h2mod = fakeMod({ gender = 1 })
    local h2 = wording.init(h2mod, "rse")
    h2.configure({ player = "enby", rival = "girl", rivalName = "KRIS" })
    local all, brendanMeet = {}, nil
    for k, v in pairs(t) do
      local p = wording.canonical(v)
      all[#all + 1] = p
      if p:find("You're not what I expected", 1, true) then brendanMeet = p end
    end
    local joined = table.concat(all, "\n")
    check(not joined:find("%f[%w]MAY%f[%W]") and not joined:find("%f[%w]BRENDAN%f[%W]"),
      case.game .. ": no MAY or BRENDAN left")
    check(joined:find("KRIS:", 1, true) ~= nil, case.game .. ": speaker tags renamed")
    check(brendanMeet and brendanMeet:find("My name's KRIS", 1, true),
      case.game .. ": the reworded line is renamed too")
    local ph = TextIR.placeholdersFor({ placeholders = { byGender = { RIVAL = { male = "MAY", female = "BRENDAN" } } } })
    check(ph.byGender.RIVAL.male == "KRIS" and ph.byGender.RIVAL.female == "KRIS", case.game .. ": {RIVAL} placeholder")
    check(TextIR.toPlain(TextIR.fromAscii("Hi, {RIVAL}!"), { dialect = "rse", playerGender = 0,
      placeholders = { byGender = { RIVAL = { male = "MAY", female = "BRENDAN" } } } }) == "Hi, KRIS!",
      case.game .. ": {RIVAL} expands to the name")
    check(TrainersStub.get(1).name == "KRIS" and TrainersStub.get(2).name == "KRIS", case.game .. ": battle names")
    local sonKey = case.game == "ruby" and "gOtherText_Son" or "gText_Son"
    local daughterKey = case.game == "ruby" and "gOtherText_Daughter" or "gText_Daughter"
    check(wording.canonical(t[sonKey]) == "daughter" and wording.canonical(t[daughterKey]) == "daughter",
      case.game .. ": the rival's mom says daughter for a girl rival")
    h2.configure({ player = "enby", rival = "enby", rivalName = "KRIS" })
    check(wording.canonical(t[sonKey]) == "kid" and wording.canonical(t[daughterKey]) == "kid",
      case.game .. ": and kid for an enby rival")
    h2.configure({ player = "enby", rival = "boy", rivalName = "KRIS" })
    check(wording.canonical(t[sonKey]) == "son" and wording.canonical(t[daughterKey]) == "son",
      case.game .. ": and son for a boy rival")
    h2.configure({ player = "enby", rival = "girl", rivalName = "KRIS" })
    check(TrainersStub.get(3).name == "ROXANNE" and TRAINERS[1].name == "MAY", case.game .. ": others and the pack untouched")
    h2.configure({ player = "enby", rival = "girl", rivalName = "GOLD" })
    check(TrainersStub.get(1).name == "GOLD", case.game .. ": a new name shows straight away")
    h2.configure({ player = "enby" })
    check(TrainersStub.get(1).name == "MAY", case.game .. ": RIVAL OFF gives MAY back")
    h2.configure(nil)
    h.configure(nil)
    local same = true
    for k, v in pairs(t) do if before[k] ~= v then same = false end end
    check(same, case.game .. ": everything restored")
  end
end
version = "firered"

-- Hash
-- --------------------------------------------------
check(wording.hash("") == "811c9dc5", "FNV-1a of the empty string")
check(wording.hash("a") == "e40c292c", "FNV-1a of 'a'")
check(wording.hash("foobar") == "bf9cf968", "FNV-1a of 'foobar'")

-- lens.lua: the TEXT row and what reaches the text handle
-- --------------------------------------------------
do
  local folders = {
    kris = { label = "KRIS", character = "KRIS", genderMode = "girl" },
    nb = { label = "SAGE", character = "SAGE", genderMode = "enby",
      names = '["ROWANBERRY", "X"]' },
  }
  local options, rows, handlers = {}, nil, {}
  local got = {}
  package.loaded["mods.emerald_lens.gen3"] = { init = function() return { configure = function() end } end }
  package.loaded["mods.emerald_lens.prism"] = dofile("prism.lua")
  package.loaded["mods.emerald_lens.gameboy"] = dofile("gameboy.lua")
  package.loaded["mods.emerald_lens.crossgame"] = dofile("crossgame.lua")
  package.loaded["mods.emerald_lens.lens_screen"] = dofile("lens_screen.lua")
  local layers = {}
  package.loaded["src.ui.game3.stack"] = {
    push = function(id, m) layers[#layers + 1] = { id = id, mod = m } end,
    pop = function(id) for i = #layers, 1, -1 do if layers[i].id == id then table.remove(layers, i) end end end,
    has = function(id) for _, l in ipairs(layers) do if l.id == id then return true end end return false end,
    onClear = function() end,
  }
  package.loaded["mods.emerald_lens.wording"] = {
    init = function(_, family)
      got.family = family
      return { configure = function(ctx) got.ctx = ctx; got.n = (got.n or 0) + 1 end,
        refresh = function(p) got.refreshed = p end }
    end,
  }
  local json = function(t)
    return ('{"label":"%s","character":"%s","genderMode":"%s"%s}'):format(t.label, t.character, t.genderMode,
      t.names and (',"nameChoices":' .. t.names) or "")
  end
  local mod = {
    id = "emerald_lens",
    assets = {
      list = function(_, dir) return dir == "assets/sprites" and { "kris", "nb" } or {} end,
      info = function(_, rel)
        if rel:match("meta%.json$") then return { type = "file" } end
        return { type = "directory" }
      end,
    },
    read = function(_, path) return json(folders[path:match("sprites/([^/]+)/")]) end,
    log = { warn = function() end, info = function() end },
    options = {
      define = function(_, r) rows = r end,
      get = function(_, key) return options[key] end,
    },
    events = { on = function(_, name, fn) handlers[name] = fn end },
    hooks = { wrap = function(_, name, fn) handlers[name] = fn end },
  }
  version = "firered"
  dofile("lens.lua").init(mod)

  local textRow
  for _, row in ipairs(rows) do if row.key == "textFrlg" then textRow = row end end
  check(textRow and textRow.label == "  TEXT" and textRow.default == "on", "TEXT row defined, ON by default")
  local genderRow
  for _, row in ipairs(rows) do if row.key == "genderFrlg" then genderRow = row end end
  check(genderRow and #genderRow.choices == 2 and genderRow.choices[2][1] == "MY SAVE" and genderRow.default == "look",
    "GENDER row: the look's gender or MY SAVE")
  check(got.family == "frlg", "text set up for the running family")

  options.characterFrlg, options.rivalFrlg = "KRIS", "SAGE"
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "rivalFrlg" })
  check(got.ctx and got.ctx.player == "girl" and got.ctx.rival == "enby", "player and rival genderModes passed")
  check(got.ctx.rivalName == "ROWANBE", "rival name from nameChoices, 7 letters: " .. tostring(got.ctx.rivalName))
  options.rivalFrlg = "KRIS"
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "rivalFrlg" })
  check(got.ctx.rivalName == "KRIS", "no nameChoices: the character's name")
  options.rivalFrlg = "SAGE"

  options.textFrlg = "off"
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "textFrlg" })
  check(got.ctx == nil, "TEXT OFF passes nil")

  options.textFrlg, options.characterFrlg, options.rivalFrlg = "on", "__off", "__off"
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "characterFrlg" })
  check(got.ctx == nil, "CHARACTER and RIVAL OFF pass nil")

  local n = got.n
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "lookRse_KRIS" })
  check(got.n == n, "the other family's rows don't reconfigure")

  local payload = { save = { gender = 1 } }
  handlers["save.created"](payload)
  check(got.refreshed == payload, "save.created refreshes with its payload")
  check(handlers["save.loaded"] ~= nil, "save.loaded is listened to")

  -- The LENS screen (lens_screen.lua): its START and OPTION rows, and
  -- setting an option the way the mod settings screen does. -Elvie
  options.characterFrlg, options.rivalFrlg = "KRIS", "__off"
  local emitted = {}
  local game = { options = {}, writes = 0,
    mods = { modOptions = {}, events = { emit = function(_, name, p) emitted[#emitted + 1] = p end } } }
  function game:writeOptions() self.writes = self.writes + 1 end
  local items = { { id = "save", label = "SAVE" }, { id = "option", label = "OPTION" },
    { id = "mods", label = "MODS" }, { id = "exit", label = "EXIT" } }
  local start = handlers["ui.start_menu.items"](function() return items end, game, items)
  check(#start == 5 and start[3].id == "prism" and start[3].label == "LENS", "LENS sits above MODS")
  check(#items == 4, "the engine's list isn't changed in place")
  local noMods = handlers["ui.start_menu.items"](function() return { items[1], items[4] } end, game, {})
  check(noMods[2].id == "prism", "without MODS, LENS sits above EXIT")
  local optionRows = handlers["ui.options.rows"](function() return {} end, game, {})
  local optionRow = optionRows[#optionRows]
  check(optionRow.label == "EMERALD LENS" and optionRow.value(game) == "KRIS", "OPTION row shows the character")
  optionRow.activate(game)
  local screenLayer = layers[#layers]
  check(screenLayer and screenLayer.id == "emerald_lens", "the OPTION row opens the screen")
  optionRow.activate(game)
  check(#layers == 1, "opening twice keeps one layer")
  local function press(key) return { wasPressed = function(_, k) return k == key end } end
  screenLayer.mod.handleInput(press("right"))
  local set = game.mods.modOptions.emerald_lens or {}
  check(set.characterFrlg == "SAGE" and game.options.modOptions.emerald_lens.characterFrlg == "SAGE",
    "right on CHARACTER steps to the next choice in both option tables")
  check(game.writes == 1 and emitted[1] and emitted[1].key == "characterFrlg" and emitted[1].value == "SAGE",
    "the change is written and announced")
  screenLayer.mod.handleInput(press("up"))
  screenLayer.mod.handleInput(press("a"))
  screenLayer.mod.handleInput(press("b"))
  check(#layers == 1, "A on CREDITS opens the credits page, and B there goes back")
  screenLayer.mod.handleInput(press("b"))
  check(#layers == 0, "B closes the screen")
end

-- Game Boy looks: folders copied from Crystal Lens, with no gen3/ art,
-- and romOverworld looks. -Elvie
-- --------------------------------------------------
do
  local metas = {
    kris = '{"label":"KRIS","character":"KRIS","genderMode":"girl"}',
    zeta = '{"label":"ZETA","character":"KRIS","genderMode":"girl","generation":4}',
    arale = '{"label":"ARALE","character":"KRIS","genderMode":"girl","romOverworld":"kris"}',
    red_gb = '{"label":"RED","character":"RED","genderMode":"boy","romOverworld":"red"}',
    red_x = '{"label":"FR/LG","character":"RED","genderMode":"boy","fromGame":"red"}',
    may_x = '{"label":"EMERALD","character":"MAY","genderMode":"girl","fromGame":"may"}',
  }
  local dirs = { "kris/gen3/frlg", "zeta/gen3/frlg" }
  local files = { ["arale/backColor.png"] = true }
  local options, handlers, ctxs = {}, {}, {}
  package.loaded["mods.emerald_lens.gen3"] = { init = function(_, ctx)
    ctxs[#ctxs + 1] = ctx
    return { configure = function(c) ctxs[#ctxs + 1] = c end }
  end }
  local mod = {
    id = "emerald_lens",
    assets = {
      list = function(_, dir) return dir == "assets/sprites" and { "arale", "kris", "may_x", "red_gb", "red_x", "zeta" } or {} end,
      info = function(_, rel)
        local key, rest = rel:match("^assets/sprites/([^/]+)/?(.*)$")
        if not key or not metas[key] then return nil end
        if rest == "" or rest == "gen3" then
          if rest == "gen3" and key ~= "kris" and key ~= "zeta" then return nil end
          return { type = "directory" }
        end
        if rest == "meta.json" or files[key .. "/" .. rest] then return { type = "file" } end
        for _, d in ipairs(dirs) do if d == key .. "/" .. rest:gsub("/$", "") then return { type = "directory" } end end
        return nil
      end,
    },
    read = function(_, path) return metas[path:match("sprites/([^/]+)/")] end,
    log = { warn = function() end, info = function() end },
    options = { define = function() end, get = function(_, key) return options[key] end },
    events = { on = function(_, name, fn) handlers[name] = fn end },
    hooks = { wrap = function() end },
  }
  version = "firered"
  options.characterFrlg = "KRIS"
  dofile("lens.lua").init(mod)
  local ctx = ctxs[#ctxs]
  check(ctx and ctx.folderKeys[1] == "kris", "a Game Boy look doesn't become the default look")
  check(ctx and table.concat(ctx.folderKeys, ",") == "kris,zeta,arale",
    "Gen 3 look: Gen 4 before Game Boy: " .. tostring(ctx and table.concat(ctx.folderKeys, ",")))
  check(ctx and ctx.gameBoy.arale and not ctx.gameBoy.kris, "copied folder is a Game Boy look")
  options.lookFrlg_KRIS = "arale"
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "lookFrlg_KRIS" })
  ctx = ctxs[#ctxs]
  check(table.concat(ctx.folderKeys, ",") == "arale,kris,zeta",
    "Game Boy look: Gen 3 before Gen 4: " .. table.concat(ctx.folderKeys, ","))
  options.characterFrlg = "RED"
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "characterFrlg" })
  ctx = ctxs[#ctxs]
  check(ctx.folderKeys[1] == "red_gb" and ctx.genderMode == "boy" and ctx.gameBoy.red_gb,
    "a romOverworld folder alone is a look")
  check(not ctx.gameBoy.red_x, "a fromGame look isn't a Game Boy look")
  options.characterFrlg = "MAY"
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "characterFrlg" })
  check(ctxs[#ctxs].folderKeys[1] == "may_x", "a fromGame look is offered in the other family (Emerald's May in FR/LG)")
  local X = package.loaded["mods.emerald_lens.crossgame"]
  check(X and X.isBase("assets/sprites/may_x/gen3/frlg/") and not X.isBase("assets/sprites/red_x/gen3/frlg/"),
    "fromGame bases are registered for the other family only")
  options.characterFrlg = "RED"
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "characterFrlg" })
  ctx = ctxs[#ctxs]

  -- GENDER: MY SAVE fits the look to either save (gen3 takes both slots) -Elvie
  check(not ctx.fitSave, "GENDER is the look's own by default")
  options.genderFrlg = "save"
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "genderFrlg" })
  ctx = ctxs[#ctxs]
  check(ctx.fitSave == true and ctx.genderMode == "boy", "GENDER MY SAVE reaches gen3; the text's genderMode stays")
  options.genderFrlg = "_"
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "genderFrlg" })
  check(not ctxs[#ctxs].fitSave, "an older version's stored GENDER value counts as the look's own")

  local gb = package.loaded["mods.emerald_lens.gameboy"]
  check(gb.isBase("assets/sprites/arale/") and not gb.isBase("assets/sprites/kris/gen3/frlg/"),
    "Game Boy bases are told apart")
  check(not gb.isBase("assets/surfmons/lapras/rse/"), "a SURF row folder isn't a Game Boy look")
  check(gb.has(mod, "assets/sprites/arale/", "back.png") and not gb.has(mod, "assets/sprites/arale/", "front.png"),
    "back.png from backColor.png; no front art, no front.png")
  check(not gb.has(mod, "assets/sprites/arale/", "walk.png") and not gb.has(mod, "assets/sprites/arale/", "surf.png")
    and not gb.has(mod, "assets/sprites/arale/", "surfBlob.png"),
    "romOverworld with the game not installed: no walk, surf or blob, so they fall back")
  check(not gb.has(mod, "assets/sprites/arale/", "fishing.png") and gb.DROP["fishing.png"] == 8,
    "no fishing art readable: fishing.png isn't offered, so it falls back; fishing frames are 8 taller")
  files["arale/overworldSurf.png"] = true
  check(gb.has(mod, "assets/sprites/arale/", "surf.png") and gb.has(mod, "assets/sprites/arale/", "surfBlob.png")
    and gb.has(mod, "assets/sprites/arale/", "underwater.png") and not gb.has(mod, "assets/sprites/arale/", "walk.png"),
    "a folder's own overworldSurf.png: surf, dive and the left-out blob, with no game installed")
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
