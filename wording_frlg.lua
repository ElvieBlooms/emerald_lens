-- FireRed / LeafGreen wording (see wording.lua)
-- Each entry: label (pret's name for the line), hash (of the game's own
-- line, from tools/wording/check.lua hash), who ("player" or "rival"), and
-- the wording per genderMode: a list of { from, to } swaps, or a whole
-- line in pret form. A mode that isn't listed keeps the game's line.
-- games = { ... } limits an entry to some games. -Elvie
--
-- "player" follows the gender picked in the save (an enby look always
-- gets enby). "rival" follows the RIVAL look; Blue is a boy, so boy
-- needs nothing. -Elvie
-- --------------------------------------------------

return {
  -- Oak's intro, introducing Blue. The intro doesn't wrap lines, so the
  -- longer enby line moves "both" down. -Elvie
  { label = "gOakSpeech_Text_WhatWasHisName", hash = "3146bc49", who = "rival",
    girl = { { "grandson", "granddaughter" }, { "He's been", "She's been" }, { "his name", "her name" } },
    enby = "This is my grandchild.\\pThey've been your rival since you\\nboth were babies.\\p…Erm, what was their name now?" },
  { label = "gOakSpeech_Text_RememberRivalsName", hash = "de8e3cb6", who = "rival",
    girl = { { "His name", "Her name" } },
    enby = { { "His name", "Their name" } } },
}
