-- Ruby / Sapphire / Emerald wording (see wording.lua and wording_frlg.lua for
-- the entry format). R/S spell "…" as "...", so their lines hash apart
-- from Emerald's and get entries of their own, with games so the other
-- game doesn't log them as missing. -Elvie
--
-- The rival's lines need nothing: the games already call May and Brendan
-- "my kid" and "our child" when they could be either. -Elvie
-- --------------------------------------------------

-- Brendan meeting a girl player. An enby player who picked the girl gets
-- him not knowing what to expect instead. -Elvie
local BRENDAN_MEETS = {
  enby = { { "I didn't know that you're a girl.", "You're not what I expected." },
    { "so I assumed you'd be a guy.", "so I pictured a real bruiser." } },
}

-- The man in Dewford Hall calls everyone "chap". -Elvie
local NOT_CHAP = { { "chap", "friend" } }

return {
  { label = "RivalsHouse_1F_Text_BrendanWhoAreYou", hash = "14d076f9", who = "player",
    games = { "emerald" }, enby = BRENDAN_MEETS.enby }, -- also RivalsHouse_2F
  { label = "RivalsHouse_2F_Text_BrendanWhoAreYou", hash = "bb44f719", who = "player",
    games = { "ruby", "sapphire" }, enby = BRENDAN_MEETS.enby },

  { label = "DewfordTown_Hall_Text_WorkOnYourSinging", hash = "a1e2059d", who = "player",
    games = { "emerald" }, girl = NOT_CHAP, enby = NOT_CHAP },
  { label = "DewfordTown_Hall_Text_WorkOnYourSinging", hash = "683330dd", who = "player",
    games = { "ruby", "sapphire" }, girl = NOT_CHAP, enby = NOT_CHAP },

  -- Birch's intro, before the BOY/GIRL menu. Same line in all three
  -- (gText_Birch_BoyOrGirl in Emerald). -Elvie
  { label = "gBirchSpeech_AreYouBoyOrGirl", hash = "a8d73c1e", who = "player",
    enby = "Which would you\\nlike to be?" },
}
