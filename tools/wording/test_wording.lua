-- Headless tests for wording.lua and the TEXT option in lens.lua. Run from
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
  local A, B = "Thanks, son! This is his.\\pGood lad.", "Hey, chap!"
  package.loaded["mods.emerald_lens.wording_frlg"] = {
    { label = "TestA", hash = lineHash(A), who = "player",
      girl = { { "son", "lass" }, { "his", "hers" }, { "lad", "lass" } },
      enby = { { "son", "kid" }, { "his", "theirs" }, { "lad", "kid" } } },
    { label = "TestB", hash = wording.hash("Hey, chap!"), who = "player", enby = "Hey, you!" },
    { label = "TestC", hash = lineHash("Nothing to swap here."), who = "player", girl = { { "absent", "x" } } },
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
    nb = { label = "SAGE", character = "SAGE", genderMode = "enby" },
  }
  local options, rows, handlers = {}, nil, {}
  local got = {}
  package.loaded["mods.emerald_lens.gen3"] = { init = function() return { configure = function() end } end }
  package.loaded["mods.emerald_lens.wording"] = {
    init = function(_, family)
      got.family = family
      return { configure = function(ctx) got.ctx = ctx; got.n = (got.n or 0) + 1 end,
        refresh = function(p) got.refreshed = p end }
    end,
  }
  local json = function(t)
    return ('{"label":"%s","character":"%s","genderMode":"%s"}'):format(t.label, t.character, t.genderMode)
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
  }
  version = "firered"
  dofile("lens.lua").init(mod)

  local textRow
  for _, row in ipairs(rows) do if row.key == "textFrlg" then textRow = row end end
  check(textRow and textRow.label == "  TEXT" and textRow.default == "on", "TEXT row defined, ON by default")
  check(got.family == "frlg", "text set up for the running family")

  options.characterFrlg, options.rivalFrlg = "KRIS", "SAGE"
  handlers["mod.options_changed"]({ mod = "emerald_lens", key = "rivalFrlg" })
  check(got.ctx and got.ctx.player == "girl" and got.ctx.rival == "enby", "player and rival genderModes passed")

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
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
