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

-- Casual "..., man" said to the player, dropped for girls and enby. -Elvie
local NO_MAN = { { ", man", "" } }

return {
  -- Oak's intro, introducing Blue. The intro doesn't wrap lines, so the
  -- longer enby line moves "both" down. -Elvie
  { label = "gOakSpeech_Text_WhatWasHisName", hash = "3146bc49", who = "rival",
    girl = { { "grandson", "granddaughter" }, { "He's been", "She's been" }, { "his name", "her name" } },
    enby = "This is my grandchild.\\pThey've been your rival since you\\nboth were babies.\\p…Erm, what was their name now?" },
  { label = "gOakSpeech_Text_RememberRivalsName", hash = "de8e3cb6", who = "rival",
    girl = { { "His name", "Her name" } },
    enby = { { "His name", "Their name" } } },

  -- Oak's question before the BOY/GIRL menu, for an enby look -Elvie
  { label = "gOakSpeech_Text_AskPlayerGender", hash = "ceced5fd", who = "player",
    enby = "Now tell me. Which would\\nyou like to be?" },

  -- Blue's sister and Lance talking about Blue -Elvie
  { label = "PalletTown_RivalsHouse_Text_HiBrothersAtLab", hash = "45d10835", who = "rival",
    girl = { { "My brother", "My sister" } },
    enby = { { "My brother", "My sibling" } } },
  { label = "gFameCheckerPersonQuote_Daisy", hash = "2d39f568", who = "rival",
    girl = { { "little brother", "little sister" } },
    enby = { { "little brother", "little sibling" } } },
  { label = "PokemonLeague_LancesRoom_Text_PostBattle", hash = "86b31313", who = "rival",
    girl = { { "His name", "Her name" }, { "He beat", "She beat" }, { "He is the real", "She is the real" } },
    enby = { { "His name", "Their name" }, { "He beat", "They beat" }, { "He is the real", "They are the real" } } },

  -- Lines the game already has a boy and a girl version of. Girls and boys
  -- get the game's own; enby gets the same words in both. Bill's pal,
  -- chief and bud count as neutral, so his girl lines take those. -Elvie
  { label = "PalletTown_PlayersHouse_1F_Text_AllBoysLeaveOakLookingForYou", hash = "b52a198c", who = "player",
    enby = { { "All boys leave", "Everyone leaves" } } },
  { label = "PalletTown_PlayersHouse_1F_Text_AllGirlsLeaveOakLookingForYou", hash = "3401dc7e", who = "player",
    enby = { { "All girls dream", "Everyone dreams" } } },
  { label = "FuchsiaCity_WardensHouse_Text_ThanksSonGiveYouSomething", hash = "435b49c3", who = "player",
    enby = { { "son", "kid" } } },
  { label = "FuchsiaCity_WardensHouse_Text_ThanksLassieGiveYouSomething", hash = "685b9556", who = "player",
    enby = { { "lassie", "kid" } } },
  { label = "PokemonTower_1F_Text_ComeToPayRespectsSon", hash = "8e1ec1dc", who = "player",
    enby = { { "son", "child" } } },
  { label = "PokemonTower_1F_Text_ComeToPayRespectsGirl", hash = "c6b384e2", who = "player",
    enby = { { "girl", "child" } } },
  { label = "Route25_SeaCottage_Text_ImBillHelpMeOutLady", hash = "29aa8fdf", who = "player",
    enby = { { "lady", "pal" } } },
  { label = "Route25_SeaCottage_Text_NoPleaseBeautiful", hash = "2f987950", who = "player",
    enby = { { "beautiful", "chief" } } },
  { label = "Route25_SeaCottage_Text_ThanksLadyTakeThis", hash = "89a98f78", who = "player",
    enby = { { "lady", "bud" } } },
  { label = "Route4_PokemonCenter_1F_Text_LaddieBuyMagikarpForJust500", hash = "21bb0219", who = "player",
    enby = { { "laddie", "kiddo" } } },
  { label = "Route4_PokemonCenter_1F_Text_SweetieBuyMagikarpForJust500", hash = "9bfc708c", who = "player",
    enby = { { "sweetie pie", "kiddo" } } },
  { label = "SSAnne_1F_Room4_Text_WaiterCherryPiePlease", hash = "ee7c2d13", who = "player",
    enby = { { "Waiter", "Server" } } },
  { label = "SSAnne_1F_Room4_Text_WaitressCherryPiePlease", hash = "bce6b6cf", who = "player",
    enby = { { "Waitress", "Server" } } },
  { label = "SSAnne_1F_Room6_Text_SorryYouLookLikeMyBrother", hash = "e5a34682", who = "player",
    enby = { { "little brother", "little sibling" } } },
  { label = "SSAnne_1F_Room6_Text_SorryYouLookLikeMySister", hash = "45b8f17c", who = "player",
    enby = { { "little sister", "little sibling" } } },
  { label = "SilphCo_11F_Text_ThanksForSavingMeDearBoy", hash = "cdc52c6f", who = "player",
    enby = { { "dear boy", "dear friend" } } },
  { label = "SilphCo_11F_Text_ThanksForSavingMeDearGirl", hash = "03677607", who = "player",
    enby = { { "dear girl", "dear friend" } } },

  -- "..., man" from bikers and a Rocket, said to the player. Billy's
  -- intro and rematch are the same line, so one entry does both. -Elvie
  { label = "Route14_Text_IsaacPostBattle", hash = "49cc3ba1", who = "player", girl = NO_MAN, enby = NO_MAN },
  { label = "Route17_Text_BillyIntro", hash = "9c2a0b71", who = "player", girl = NO_MAN, enby = NO_MAN },
  { label = "Route8_Text_RicardoIntro", hash = "ffa1fa45", who = "player", girl = NO_MAN, enby = NO_MAN },
  { label = "Route8_Text_RicardoPostBattle", hash = "249ea29b", who = "player", girl = NO_MAN, enby = NO_MAN },
  { label = "Route8_Text_RicardoRematchIntro", hash = "1d51276f", who = "player", girl = NO_MAN, enby = NO_MAN },
  { label = "SixIsland_OutcastIsland_Text_RocketIntro", hash = "010a3827", who = "player", girl = NO_MAN, enby = NO_MAN },
  { label = "ThreeIsland_Text_Biker2PostBattle", hash = "b3643b47", who = "player", girl = NO_MAN, enby = NO_MAN },
  { label = "ThreeIsland_Text_Biker3Intro", hash = "9049a66c", who = "player", girl = NO_MAN, enby = NO_MAN },
  { label = "ThreeIsland_Text_OughtToBeThankingUs", hash = "32e50715", who = "player",
    girl = { { "No, man,", "No," } }, enby = { { "No, man,", "No," } } },
}
