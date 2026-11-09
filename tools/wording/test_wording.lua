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
  local gameA = lines.TestA -- the game's own line, to check it's put back
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
  check(lines.TestA == gameA and wording.canonical(lines.TestA) == A, "boy save: the game's own line")

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
    -- Exactly the lines whose text one of this game's player entries for
    -- the mode matches (an entry can match more than one line with the
    -- same text) change, and no others.
    local function expected(mode)
      local hashes = {}
      for _, e in ipairs(entries) do
        local mine = e.games == nil
        for _, g in ipairs(e.games or {}) do mine = mine or g == case.game end
        if mine and e[mode] and (e.who or "player") == "player" then hashes[e.hash] = true end
      end
      local keys = {}
      for k, v in pairs(before) do
        if type(v) == "table" and hashes[wording.hash(wording.canonical(v))] then keys[k] = true end
      end
      return keys
    end
    local function sameChanges(mode)
      local want, extra, missing = expected(mode), {}, {}
      for k, v in pairs(t) do
        if before[k] ~= v and not want[k] then extra[#extra + 1] = tostring(k) end
      end
      for k in pairs(want) do
        if t[k] == before[k] then missing[#missing + 1] = tostring(k) end
      end
      check(#extra == 0 and #missing == 0, ("%s %s: only the matched lines change (extra: %s; unchanged: %s)")
        :format(case.game, mode, table.concat(extra, ","), table.concat(missing, ",")))
    end
    sameChanges("enby")
    h.configure({ player = "girl" })
    sameChanges("girl")
    local chap, dewford = 0, 0
    for _, e in ipairs(entries) do
      if e.label == "DewfordTown_Hall_Text_WorkOnYourSinging" then
        for k, v in pairs(before) do
          if type(v) == "table" and wording.hash(wording.canonical(v)) == e.hash then dewford = dewford + 1 end
        end
      end
    end
    for k, v in pairs(t) do
      if before[k] ~= v and TextIR.toPlain(v, {}):find("I dare say, friend", 1, true) then chap = chap + 1 end
    end
    check(chap == dewford and chap >= 1, ("%s: a girl save gets the Dewford line (%d of %d)")
      :format(case.game, chap, dewford))
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
  package.loaded["mods.emerald_lens.achievements"] = dofile("achievements.lua")
  package.loaded["mods.emerald_lens.lens_gb"] = dofile("lens_gb.lua")
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
  local byKey = {}
  for _, row in ipairs(rows) do byKey[row.key] = row end
  check(byKey.characterGb1 and byKey.characterGb2 and byKey.genderGb2 and not byKey.genderGb1
    and byKey.rivalGb1 and byKey.rivalGb2 and byKey.rivalGb1.default == "__off" and not byKey.textGb2,
    "R/B/Y and G/S/C rows: CHARACTER and RIVAL (OFF) for both, GENDER only for G/S/C, no text")

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
    ethan_x = '{"label":"HG/SS","character":"ETHAN","genderMode":"boy","generation":4,"fromDS":"ethan"}',
    dawn_x = '{"label":"D/P/PT","character":"DAWN","genderMode":"girl","generation":4,"fromDS":"dawn"}',
  }
  -- Prism Importer with HG/SS imported and Diamond/Pearl/Platinum not
  local importer = { exports = { apiVersion = 1, imageData = function() return nil end,
    status = function() return { hgss = { state = "ready" }, dppt = { state = "needed" } } end } }
  local dirs = { "kris/gen3/frlg", "zeta/gen3/frlg" }
  local files = { ["arale/backColor.png"] = true }
  local options, handlers, ctxs = {}, {}, {}
  local defined
  package.loaded["mods.emerald_lens.gen3"] = { init = function(_, ctx)
    ctxs[#ctxs + 1] = ctx
    return { configure = function(c) ctxs[#ctxs + 1] = c; ctxs.calls = (ctxs.calls or 0) + 1; ctxs.last = c end }
  end }
  local mod = {
    id = "emerald_lens",
    assets = {
      list = function(_, dir)
        if dir == "assets/surfmons" then return { "lapras" } end
        return dir == "assets/sprites" and { "arale", "dawn_x", "ethan_x", "kris", "may_x", "red_gb", "red_x", "zeta" } or {}
      end,
      info = function(_, rel)
        if rel == "assets/surfmons/lapras" then return { type = "directory" } end
        if rel:match("^assets/surfmons/lapras/[a-z]+/surfBlob%.png$") then return { type = "file" } end
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
    find = function(a, b) return (b == nil and a or b) == "prism_importer" and importer or nil end,
    log = { warn = function() end, info = function() end },
    options = { define = function(_, r) defined = r end, get = function(_, key) return options[key] end },
    events = { on = function(_, name, fn) handlers[name] = fn end },
    hooks = { wrap = function() end },
  }
  version = "firered"
  options.characterFrlg = "KRIS"
  local Screen = package.loaded["mods.emerald_lens.lens_screen"]
  local realNew, model = Screen.new, nil
  Screen.new = function(m, mdl) model = mdl return realNew(m, mdl) end
  dofile("lens.lua").init(mod)
  Screen.new = realNew
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
  options.characterFrlg = "ETHAN"
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "characterFrlg" })
  check(ctxs[#ctxs].folderKeys[1] == "ethan_x" and ctxs[#ctxs].genderMode == "boy",
    "a fromDS look is its own character's look in FR/LG")
  check(X.isBase("assets/sprites/ethan_x/gen3/frlg/") and X.isBase("assets/sprites/ethan_x/gen3/rse/"),
    "fromDS bases are registered for both families")
  check(X.sourceName({ fromDS = "ethan" }) == "HG/SS dump" and X.sourceName({ fromGame = "may" }) == "R/S/E game",
    "the LENS line names where a read look comes from")
  check(X.sourceName({ fromDS = "nate" }) == "B2W2 dump" and X.DS.hilbert.front == nil,
    "B2W2 looks name their dump; Hilbert has no trainer pics in it")
  local F = X.dsFrames
  local silver = F("silver", "frlg", "walk.png", { walk = 16 })
  check(silver[9] == "walk:4" and silver[10] == "walk:5" and silver[17] == "walk:11",
    "a DS sheet with no running frames walks instead of leaving them blank")
  local ethan = F("ethan", "frlg", "walk.png", { walk = 32 })
  check(ethan[0] == "walk:4" and ethan[3] == "walk:5" and ethan[4] == "walk:7" and ethan[9] == "walk:20",
    "HG/SS walking: stand, step, stand, step; running from 16")
  local nate = F("nate", "rse", "walk.png", { walk = 24 })
  check(nate[0] == "walk:3" and nate[3] == "walk:4" and nate[4] == "walk:5" and nate[9] == "walk:15"
    and nate[12] == "walk:16", "B2W2 walking: stand, step, step; running from 12")
  local surf4 = F("ethan", "rse", "surf.png", { walk = 32, swim = 4 })
  check(surf4[0] == "swim:1" and surf4[1] == "swim:0" and surf4[2] == "swim:2" and surf4[11] == "swim:2",
    "Gen 4 surfing sits, a frame per facing")
  local surf5 = F("nate", "rse", "surf.png", { walk = 24, swim = 16 })
  check(surf5[0] == "swim:4" and surf5[4] == "swim:5" and surf5[9] == "swim:6", "B2W2 surfing: sitting, upright for 9-11")
  check(F("silver", "rse", "surf.png", { walk = 16 })[0] == "walk:4", "no swimming sheet: the standing frame")
  local fish5 = F("rosa", "frlg", "fishing.png", { walk = 24, fish = 12 })
  check(fish5[0] == "fish:8" and fish5[7] == "fish:3" and fish5[11] == "fish:7", "fishing: left, up, down in fours")
  local fm = F("lucas", "frlg", "fieldMove.png", { walk = 32, use = 4 })
  check(fm[0] == "use:0" and fm[4] == "use:3" and fm[5] == "walk:4", "field move: sending out, then FR/LG's stands")
  local before = ctxs.calls or 0
  options.characterFrlg = "DAWN"
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "characterFrlg" })
  check((ctxs.calls or 0) == before + 1 and (ctxs.last == nil or ctxs.last.folderKeys == nil),
    "a DS character whose dump isn't imported plays as the game's own player")
  check(not X.isBase("assets/sprites/dawn_x/gen3/frlg/"), "and isn't registered")
  local said = {}
  for _, line in ipairs(model and model.preview("you", {}).lines or {}) do said[#said + 1] = line.text end
  check(table.concat(said, "|"):find("More looks with D/P/Pt.", 1, true) ~= nil,
    "the LENS screen says a dump would add looks: " .. table.concat(said, "|"))
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
  check(not gb.has(mod, "assets/sprites/red_gb/", "front.png") and not gb.has(mod, "assets/sprites/blue_gb/", "rivalEarly.png"),
    "no installed game, no battle pics for a romOverworld look")
  check(gb.has(mod, "assets/sprites/arale/", "back.png") and not gb.has(mod, "assets/sprites/arale/", "front.png"),
    "back.png from backColor.png; no front art, no front.png")
  check(not gb.has(mod, "assets/sprites/arale/", "walk.png") and not gb.has(mod, "assets/sprites/arale/", "surf.png")
    and not gb.has(mod, "assets/sprites/arale/", "surfBlob.png"),
    "romOverworld with the game not installed: no walk, surf or blob, so they fall back")
  check(not gb.has(mod, "assets/sprites/arale/", "bike.png") and gb.BIKE_CUT == 10,
    "no game installed, no bike sprite to borrow the bottom half of (cut at row 10)")
  check(not gb.has(mod, "assets/sprites/arale/", "fishing.png") and gb.DROP["fishing.png"] == 8,
    "no fishing art readable: fishing.png isn't offered, so it falls back; fishing frames are 8 taller")
  files["arale/overworldSurf.png"] = true
  check(gb.has(mod, "assets/sprites/arale/", "surf.png") and gb.has(mod, "assets/sprites/arale/", "surfBlob.png")
    and gb.has(mod, "assets/sprites/arale/", "underwater.png") and not gb.has(mod, "assets/sprites/arale/", "walk.png"),
    "a folder's own overworldSurf.png: surf, dive and the left-out blob, with no game installed")

  -- Red/Blue/Yellow: Gen 3 looks only, through gen12.lua -Elvie
  local gbCtx, gbFamily, gbOpts, gbRival = nil, nil, nil, nil
  package.loaded["mods.emerald_lens.gen12"] = { init = function(_, c, f, o)
    gbCtx, gbFamily, gbOpts = c, f, o
    gbRival = c and c.rival
    return { configure = function(c2) gbCtx = c2 end, configureRival = function(r) gbRival = r end,
      card = function() return "card" end }
  end }
  local GV = package.loaded["src.core.GameVersion"]
  local GENERATION = { red = 1 }
  GV.generation = function(v) return GENERATION[v] or 3 end
  version = "red"
  local screens = {}
  mod.content = { screens = { register = function(_, id, def) screens[id] = def end } }
  mod.ui = { Font = {}, push = function() end }
  mod.hooks = { wrap = function(_, name, fn) handlers[name] = fn end }
  dofile("lens.lua").init(mod)
  check(screens.emerald_lens_lens and screens.emerald_lens_lens_credits and screens.emerald_lens_prism,
    "the Game Boy LENS, credits and PRISM screens are registered")
  check(gbCtx == nil, "R/B/Y starts OFF, so Crystal Lens's player stays")
  options.characterGb1 = "KRIS"
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "characterGb1" })
  check(gbFamily and gbFamily.id == "gb1" and gbFamily.art[1] == "frlg",
    "Red runs gen12.lua with FR/LG art first")
  check(gbCtx and table.concat(gbCtx.folderKeys, ",") == "kris,zeta,arale",
    "R/B/Y chain: " .. tostring(gbCtx and table.concat(gbCtx.folderKeys, ",")))
  options.lookGb1_KRIS = "arale"
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "lookGb1_KRIS" })
  check(gbCtx.folderKeys[1] == "arale" and gbCtx.gameBoy and gbCtx.gameBoy.arale and not gbCtx.gameBoy.kris,
    "a Game Boy look is offered in R/B/Y, drawn from its own files")
  local X = package.loaded["mods.emerald_lens.crossgame"]
  check(X.isBase("assets/sprites/red_x/gen3/frlg/") and X.isBase("assets/sprites/may_x/gen3/rse/"),
    "players from the Gen 3 games are offered in R/B/Y, each read from its own family's game")
  options.lookGb1_KRIS = "kris"
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "lookGb1_KRIS" })
  check(gbCtx.lookKey == "kris", "the selected look is handed over, for the battle back's fixed path")
  check(gbOpts and gbOpts.ownCard == true and table.concat(gbOpts.lookKeys, ",") == "ethan_x,arale,kris,zeta,may_x,red_x,red_gb"
    and gbOpts.gameBoy.arale and gbOpts.spritesDir == "assets/sprites",
    "every R/B/Y look listed for the back scales, Game Boy ones marked; the trainer card is this mod's own")
  check(gbRival == nil, "RIVAL starts OFF in R/B/Y")
  options.rivalGb1 = "KRIS"
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "rivalGb1" })
  check(gbRival and table.concat(gbRival.folderKeys, ",") == "kris,zeta,arale" and gbRival.spritesDir == "assets/sprites",
    "R/B/Y RIVAL: Blue gets the look's chain")
  options.rivalLookGb1_KRIS = "zeta"
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "rivalLookGb1_KRIS" })
  check(gbRival and gbRival.folderKeys[1] == "zeta", "RIVAL LOOK changes Blue's look")
  check(gbCtx and gbCtx.folderKeys[1] == "kris", "the player keeps their own look")
  gbRival = "unset"
  handlers["save.loaded"]()
  check(type(gbRival) == "table" and gbRival.folderKeys[1] == "zeta", "loading a save puts the rival back")
  -- the LENS screen on the Game Boy START and OPTION menus, through PRISM
  local items = handlers["ui.start_menu.items"](function(_, list) return list end, nil,
    { { label = "OPTION" }, { label = "MODS" }, { label = "QUIT" } })
  check(items[2] and items[2].label == "LENS" and items[2].id == "prism" and items[3].label == "MODS",
    "LENS goes just above MODS on the Game Boy START menu")
  local optRows = handlers["ui.options.rows"](function(_, list) return list end, nil, { { id = "text" }, { id = "cancel", cancel = true } })
  check(optRows[2] and optRows[2].label == "EMERALD LENS" and optRows[2].value() == "KRIS" and optRows[2].activate
    and optRows[3].cancel, "EMERALD LENS row on the Game Boy OPTION menu, before BACK, showing the character")
  -- with Facets there too, one PRISM item for both
  local prism = dofile("prism.lua")
  local facetsEntry = { id = "facets", label = "FACETS", short = "FACETS", value = function() return "HGSS" end, open = function() end }
  local both = prism.addStartGb(mod, handlers["ui.start_menu.items"](function(_, list) return list end, nil,
    { { label = "OPTION" }, { label = "MODS" }, { label = "QUIT" } }), facetsEntry, nil, "facets_prism")
  check(both[2].label == "PRISM" and #both[2].entries == 2 and both[2].entries[1].id == "emerald_lens"
    and both[2].screen == "emerald_lens_prism" and #both == 4, "with Facets, one PRISM item lists both, sorted by name")
  options.rivalGb1, options.rivalLookGb1_KRIS = nil, nil
  options.surfGb1 = "lapras"

  -- With Crystal Lens: it keeps the choices; these looks join its lists -Elvie
  local added
  local installed = { crystal = { exports = { lens = { addLooks = function(p) added = p return true end } } },
    prism_importer = importer }
  mod.find = function(a, b) return installed[b == nil and a or b] end
  gbCtx = "unset"
  dofile("lens.lua").init(mod)
  local keys = {}
  for _, look in ipairs(added and added.looks or {}) do keys[#keys + 1] = look.key end
  check(added and table.concat(keys, ",") == "emerald_lens:ethan_x,emerald_lens:arale,emerald_lens:kris,emerald_lens:zeta,emerald_lens:may_x,emerald_lens:red_x,emerald_lens:red_gb"
    and added.looks[2].folder == "arale",
    "looks handed to Crystal Lens, with their folders so it can leave out its own: " .. table.concat(keys, ","))
  check(gbCtx == nil, "nothing drawn until Crystal Lens picks one")
  check(gbOpts and gbOpts.ownCard == false, "with Crystal Lens, its trainer card screen stays")
  local surfRow, charRow
  for _, row in ipairs(defined) do
    if row.key == "surfGb1" then surfRow = row end
    if row.key == "characterGb1" then charRow = row end
  end
  check(surfRow and not charRow, "with Crystal Lens only SURF is left in the R/B/Y rows")
  added.configure("emerald_lens:zeta")
  check(gbCtx and gbCtx.folderKeys[1] == "zeta" and gbCtx.fitSave == true and gbCtx.lookKey == "zeta"
    and gbCtx.surfKit == "assets/surfmons/lapras/",
    "Crystal Lens picks a look: drawn, for either save (its GENDER decides), with this mod's SURF")
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "surfGb1" })
  check(gbCtx and gbCtx.folderKeys[1] == "zeta", "changing SURF keeps Crystal Lens's pick")
  added.configureRival("emerald_lens:kris")
  check(type(gbRival) == "table" and gbRival.folderKeys[1] == "kris", "Crystal Lens's RIVAL on one of these looks: drawn here")
  added.configureRival(nil)
  check(gbRival == nil, "Crystal Lens's own rival: this mod steps back")
  local preview = added.preview("emerald_lens:zeta")
  check(preview and preview.card == "card", "the trainer card portrait handed to Crystal Lens for the drawn look")
  gbCtx = nil
  handlers["save.loaded"]()
  check(gbCtx and gbCtx.folderKeys[1] == "zeta", "loading a save keeps Crystal Lens's pick")
  added.configure(nil)
  check(gbCtx == nil, "Crystal Lens's own look: this mod steps back")
  mod.find = nil
  GV.generation = nil
  version = "firered"
end

-- The Game Boy games' text tables (rival_text.lua, player_text.lua): every
-- line fits the 18-character text box, and each entry has a hash and words
do
  local rival = dofile("rival_text.lua")
  package.loaded["mods.emerald_lens.rival_text"] = rival
  local player = dofile("player_text.lua")
  local wide, shape = 0, 0
  for _, list in ipairs({ rival.LINES, player.LINES }) do
    for _, line in ipairs(list) do
      if type(line[1]) ~= "number" or not (line.girl or line.enby or line.boy or line.all) then shape = shape + 1 end
      for _, mode in ipairs({ "girl", "enby", "boy", "all" }) do
        local t = line[mode]
        if t then
          local flat = t:gsub("{RIVAL}", "RRRRRRR"):gsub("{PLAYER}", "PPPPPPP"):gsub("{PROMPT}", "")
            :gsub("{DONE}", ""):gsub("é", "e"):gsub("…", "."):gsub("¥", "Y")
          for seg in (flat .. "\n"):gmatch("([^\n\011\012]*)[\n\011\012]") do
            if #seg > 18 then wide = wide + 1; print("  too wide: " .. seg) end
          end
        end
      end
    end
  end
  check(shape == 0, "Game Boy text: every entry has a hash and its words")
  check(wide == 0, "Game Boy text: every line fits the text box")
  check(#player.LINES >= 50, "player text: Crystal Lens's girl and enby lines are all here")
  -- a boy look, or none, changes nothing
  check(player.apply({ text = {} }, 1, "boy", function() error("no") end) == 0, "player text: a boy look leaves the lines alone")
end

-- Achievements (achievements.lua), against a stand-in Recomp Achievements
do
  local Ach = dofile("achievements.lua")
  local handlers = {}
  local saved = {}
  local mod = {
    id = "emerald_lens",
    log = { warn = function() end, info = function() end },
    events = { on = function(_, name, fn) handlers[name] = fn end },
    save = { get = function(_, k, d) if saved[k] == nil then return d end return saved[k] end,
      set = function(_, k, v) saved[k] = v end },
  }
  check(Ach.init(mod, {}) == nil, "achievements: nothing without Recomp Achievements")
  local unlocked, progress, registered = {}, {}, nil
  local exports = { apiVersion = "2.0.0", events = { ready = "ach.ready" } }
  mod.find = function(a, b)
    local id = b == nil and a or b
    if id == "recomp_achievements" then return { exports = exports } end
  end
  check(Ach.init(mod, {}) == nil, "achievements: an API version this mod doesn't know is left alone")
  exports.apiVersion = "1.3.0"
  exports.connect = function(_, opts)
    check(opts and opts.tab == "LENS", "achievements: their own LENS tab")
    return {
      registerMany = function(_, list) registered = list; return #list, {} end,
      isUnlocked = function(_, id) return unlocked[id] == true end,
      unlock = function(_, id) unlocked[id] = true; return true end,
      setProgress = function(_, id, n) progress[id] = n; return true end,
      addProgress = function(_, id, n) progress[id] = (progress[id] or 0) + (n or 1); return true end,
    }
  end
  local now = { look = "gbkris", surfKit = false }
  local kinds = { gbkris = "gameboy", red_frlg = "cross", may = "gen3", may2 = "gen3" }
  local chars = { gbkris = "KRIS", red_frlg = "RED", may = "MAY", may2 = "MAY" }
  local rivalTrainer = false
  local api = {
    family = { id = "rse", gb = false },
    now = function() return now end,
    handle = { isRivalTrainer = function() return rivalTrainer end },
    kindOf = function(k) return kinds[k] end,
    characterOf = function(k) return chars[k] end,
  }
  local a = Ach.init(mod, api)
  check(a and registered and #registered == 13, "achievements: 13 added")
  a.changed()
  check(next(unlocked) == nil, "achievements: nothing before a save is attached")
  handlers["ach.ready"]({ game = "emerald" })
  check(unlocked.fresh_look and unlocked.old_school and progress.wardrobe == 1,
    "achievements: a Game Boy look in Emerald (Fresh Look, Old School, Wardrobe 1)")
  now.look = "red_frlg"; a.changed()
  check(unlocked.across_the_sea and progress.wardrobe == 2, "achievements: RED from FR/LG in Emerald (Across the Sea)")
  a.changed()
  check(progress.wardrobe == 2, "achievements: the same look twice counts once")
  now.look, now.rival = "may", "may2"
  handlers["battle.started"]({ kind = "trainer", trainerId = 520 })
  check(not unlocked.frenemies, "achievements: a trainer that isn't the rival")
  rivalTrainer = true
  handlers["battle.started"]({ kind = "trainer", trainerId = 520 })
  check(unlocked.frenemies and unlocked.mirror_match, "achievements: the rival, the same character (Frenemies, Mirror Match)")
  handlers["map.entered"]({ mapId = "EM_EVER_GRANDE_CITY_HALL_OF_FAME" })
  check(unlocked.hall_of_lens, "achievements: Hall of Fame with a look")
  a.lensOpened()
  check(unlocked.behind_the_lens, "achievements: opening LENS")
  -- the Game Boy games: surfing on the SURF row's Pokemon, and Yellow's Pikachu
  unlocked, progress, saved = {}, {}, {}
  local riding
  api.family = { id = "gb1", gb = true }
  api.handle = { surfNow = function() return riding end }
  now = { look = "may", surfKit = true }
  a = Ach.init(mod, api)
  handlers["ach.ready"]({ game = "yellow" })
  check(unlocked.new_tricks, "achievements: a Gen 3 look in Yellow (New Tricks)")
  handlers["world.stepped"]({})
  check(not unlocked.surfs_up and progress.long_walk == 1, "achievements: walking isn't surfing; Long Walk counts")
  riding = "pika"
  handlers["world.stepped"]({})
  check(unlocked.surfs_up and unlocked.pika_pal, "achievements: surfing on Pikachu (Surf's Up, Pika Pal)")
  handlers["battle.started"]({ kind = "trainer", trainerId = "OPP_RIVAL2" })
  check(not unlocked.frenemies, "achievements: no rival look, no Frenemies")
  now.rival = "may2"
  handlers["battle.started"]({ kind = "trainer", trainerId = "OPP_RIVAL2" })
  check(unlocked.frenemies, "achievements: Blue wearing a look (Frenemies)")
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
