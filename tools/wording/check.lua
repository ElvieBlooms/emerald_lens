-- Text tools for Emerald Lens's gendered text (run with luajit from the
-- repo root). Everything here reads files on your own machine: a pret
-- dump from pret_strings.py and the game's extracted text cache
-- (scripts/text.lua in your install's cache folder for that game). Nothing
-- it prints belongs in the repo except hashes. -Elvie
--
--   luajit tools/wording/check.lua hash    <pret.out.lua> <label>...
--   luajit tools/wording/check.lua verify  <pret.out.lua> <text.lua> [<syms.lua>]
--   TEXT_IR=<engine text_ir.lua> [WIDTHS=<latin_widths.lua>] \
--   luajit tools/wording/check.lua entries <frlg|rse> <text.lua>...
--
-- hash     prints each label's hash, for a new table entry
-- verify   checks pret's spelling hashes like the cache does (by label,
--          via the engine's syms file for R/S/E), and lists mismatches
-- entries  finds every table entry in each cache and prints the reworded
--          lines for girl, enby and boy, flagging any that don't apply
-- --------------------------------------------------

package.path = "./?.lua;" .. package.path
local wording = dofile("wording.lua")

-- Placeholders pret writes in braces that the cache keeps; every other
-- brace is a colour, font, pause or glyph, which the canonical form drops.
local KEEP = {}
for _, n in ipairs({ "PLAYER", "RIVAL", "STR_VAR_1", "STR_VAR_2", "STR_VAR_3", "KUN",
    "VERSION", "UNKNOWN", "MAGMA", "AQUA", "MAXIE", "ARCHIE", "GROUDON", "KYOGRE",
    "EVIL_TEAM", "GOOD_TEAM", "EVIL_LEADER", "GOOD_LEADER", "EVIL_LEGENDARY",
    "GOOD_LEGENDARY" }) do KEEP[n] = true end

local function fromPret(s)
  s = s:match("^[^$]*") -- the text ends at the first $ -Elvie
  s = s:gsub("{([^}]*)}", function(name)
    if KEEP[name] or name:match("^DYNAMIC %d+$") then return "{" .. name .. "}" end
    return ""
  end)
  return s
end

local function loadData(path)
  local chunk = assert(loadfile(path))
  setfenv(chunk, {})
  return chunk()
end

local function sortedKeys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  return keys
end

local cmd = arg[1]

if cmd == "hash" then
  local pret = loadData(arg[2])
  for i = 3, #arg do
    local s = pret[arg[i]]
    if s then
      print(("%s  %s"):format(wording.hash(fromPret(s)), arg[i]))
    else
      print(("????????  %s (not in the dump)"):format(arg[i]))
    end
  end

elseif cmd == "verify" then
  local pret, cache = loadData(arg[2]), loadData(arg[3])
  local keyOf = {}
  if arg[4] then
    local syms = loadData(arg[4])
    for name, off in syms.data:gmatch("([^ \n]+) (%x+) ") do
      keyOf[name] = ("g3:%08x"):format(0x08000000 + tonumber(off, 16))
    end
  end
  local inCache = {}
  for _, ir in pairs(cache) do
    if type(ir) == "table" then inCache[wording.hash(wording.canonical(ir))] = true end
  end
  local same, differ, anywhere, total, shown = 0, 0, 0, 0, 0
  for _, label in ipairs(sortedKeys(pret)) do
    total = total + 1
    local want = fromPret(pret[label])
    if inCache[wording.hash(want)] then anywhere = anywhere + 1 end
    local ir = cache[label] or (keyOf[label] and cache[keyOf[label]])
    if type(ir) == "table" then
      local got = wording.canonical(ir)
      if got == want then
        same = same + 1
      else
        differ = differ + 1
        if shown < (tonumber(os.getenv("SHOW")) or 15) then
          shown = shown + 1
          print("DIFF " .. label)
          print("  pret : " .. want)
          print("  cache: " .. got)
        end
      end
    end
  end
  print(("%d pret strings; by label %d same, %d differ; %d found anywhere by hash")
    :format(total, same, differ, anywhere))

elseif cmd == "entries" then
  -- The engine's own text_ir.lua (from the .love) builds whole new lines;
  -- the game version only picks its dialect there.
  local TextIR
  package.preload["src.core.GameVersion"] = function()
    return { get = function() return arg[2] == "rse" and "emerald" or "firered" end,
      layout = function() return arg[2] end }
  end
  package.preload["src.core.game3.scripting.text_ir"] = function()
    TextIR = TextIR or dofile(assert(os.getenv("TEXT_IR"), "set TEXT_IR to the engine's text_ir.lua"))
    return TextIR
  end
  local TextIR = require("src.core.game3.scripting.text_ir")

  -- WIDTHS=<the game's chrome/fonts/latin_widths.lua> measures each line
  -- in pixels: the widest line before and after. Names count as 7 wide
  -- letters (42 px). The message box wraps past 208; the FR/LG Oak intro
  -- doesn't wrap at all. -Elvie
  local widths = os.getenv("WIDTHS") and loadData(os.getenv("WIDTHS"))
  local codeOf = {}
  for code, ch in pairs(TextIR.CHARMAP or {}) do
    if type(ch) == "string" and codeOf[ch] == nil then codeOf[ch] = code end
  end
  local function widest(ir)
    local best, line = 0, 0
    for _, seg in ipairs(ir) do
      if seg.t == "text" then
        for ch in seg.s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
          line = line + (widths[codeOf[ch] or -1] or 6)
        end
      elseif seg.t == "player" or seg.t == "rival" or seg.t == "strvar" then
        line = line + 42
      elseif seg.t == "nl" or seg.t == "scroll" or seg.t == "para" or seg.t == "eos" then
        if line > best then best = line end
        line = 0
      end
    end
    return math.max(best, line)
  end

  local entries = dofile("wording_" .. arg[2] .. ".lua")
  for i = 3, #arg do
    local cache = loadData(arg[i])
    print("== " .. arg[i])
    local byHash = {}
    for key, ir in pairs(cache) do
      if type(ir) == "table" then
        local h = wording.hash(wording.canonical(ir))
        byHash[h] = byHash[h] or {}
        table.insert(byHash[h], key)
      end
    end
    for _, entry in ipairs(entries) do
      local keys = byHash[entry.hash] or {}
      table.sort(keys)
      print(("%-44s %d match%s %s"):format(entry.label, #keys, #keys == 1 and "" or "es",
        table.concat(keys, " ")))
      local ir = keys[1] and cache[keys[1]]
      if ir then
        local was = widths and widest(ir)
        if was then print(("  game %3d px"):format(was)) end
        for _, mode in ipairs({ "girl", "enby", "boy" }) do
          if entry[mode] then
            local line, missing = wording._reworded(ir, entry[mode])
            if line then
              local w = widths and widest(line)
              print(("  %-4s %s%s"):format(mode, w and ("%3d px%s  "):format(w,
                (w > 208 and w > was) and " WIDE" or "") or "", wording.canonical(line)))
            else
              print(("  %-4s NOT APPLIED: no \"%s\""):format(mode, missing))
            end
          end
        end
      end
    end
  end

else
  print("usage: see the top of tools/wording/check.lua")
end
