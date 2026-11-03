-- The player's text in the Game Boy games
-- Crystal Lens's girl and enby text (its girlMode.lua and nbMode.lua, by
-- Dgray66 and Elvie), for when Emerald Lens draws the player on its own:
-- lines that call the player boy, son, guy, sir or him say it the look's
-- way instead. With Crystal Lens installed it does this itself, so this
-- file stays out of it.
--
-- Each line is found by its own text (an FNV-1a hash of the game's line,
-- the same as rival_text.lua), so it works in every version, and a line
-- another mod has changed stays theirs. Only the new words are here. The
-- changes are written with setField, so they're put back when the look
-- changes or goes.
-- --------------------------------------------------

local playerText = {}

-- { hash, games, girl = text, enby = text } (either may be left out)
local LINES = {
  { 0x251cf4c2, "Blue/Red",
    girl = "MOM: Right.\nAll girls leave\011home some day.\011It said so on TV.\012PROF.OAK, next\ndoor, is looking\011for you.{DONE}",
    enby = "MOM: Right.\nEveryone leaves\011home some day.\011It said so on TV.\012PROF.OAK, next\ndoor, is looking\011for you.{DONE}" },
  { 0x888ff234, "R/B/Y",
    girl = "BILL: Look, lady,\njust check out\011some of my rare\011POKéMON on my PC!{DONE}",
    enby = "BILL: Look,\njust check out\011some of my rare\011POKéMON on my PC!{DONE}" },
  { 0x0b9e68ae, "R/B/Y",
    girl = "BILL: Yeehah!\nThanks, lady! I\011owe you one!\012So, did you come\nto see my POKéMON\011collection?\011You didn't?\011That's a bummer.\012I've got to thank\nyou... Oh here,\011maybe this'll do.{PROMPT}",
    enby = "BILL: Yeehah!\nThanks! I\011owe you one!\012So, did you come\nto see my POKéMON\011collection?\011You didn't?\011That's a bummer.\012I've got to thank\nyou... Oh here,\011maybe this'll do.{PROMPT}" },
  { 0xe49b2893, "R/B/Y",
    girl = "Raising POKéMON\nis a drag.{DONE}",
    enby = "Raising POKéMON\nis a drag.{DONE}" },
  { 0x84e9d8f2, "R/B/Y",
    girl = "Hahahaha!\nCome on, lady!{DONE}",
    enby = "Hahahaha!\nCome on!{DONE}" },
  { 0x234ac5fc, "R/B/Y",
    girl = "Waitress, I would\nlike a cherry pie\011please!{DONE}",
    enby = "I would\nlike a cherry pie\011please!{DONE}" },
  { 0x6dad2687, "R/B/Y",
    girl = "You've got too\nmuch stuff, lady!{DONE}",
    enby = "You've got too\nmuch stuff!{DONE}" },
  { 0xba264e19, "R/B/Y",
    girl = "Whoa, lady!\nI'm parched!\011...\011Huh? I can have\011this drink?\011Gee, thanks!{DONE}",
    enby = "Whoa there!\nI'm parched!\011...\011Huh? I can have\011this drink?\011Gee, thanks!{DONE}" },
  { 0x584cf32c, "Yellow",
    girl = "MOM: Right.\nAll girls leave\011home some day.\011It said so on TV.\012PROF.OAK, next\ndoor, is looking\011for you.{DONE}",
    enby = "MOM: Right.\nEveryone leaves\011home some day.\011It said so on TV.\012PROF.OAK, next\ndoor, is looking\011for you.{DONE}" },
  { 0x0df9aec7, "Crystal",
    girl = "Whoa!\012Excuse me.\nI was in a hurry!\012My granddaughter\nis missing!\012She's just a wee\ngirl. If you see\012her, please let me\nknow!{DONE}",
    enby = "Whoa!\012Excuse me.\nI was in a hurry!\012My granddaughter\nis missing!\012She's just a wee\ngirl. If you see\012her, please let me\nknow!{DONE}" },
  { 0x375122e5, "Crystal",
    girl = "Ooh, wow. You're\ntough!{DONE}",
    enby = "Ooh, wow. You're\ntough!{DONE}" },
  { 0x87937c75, "Crystal",
    girl = "Hey, lady. Could I\nget you to look\011for my buddy?\012He's goofing off\nsomewhere, that\011lazy bum!\012I want to go find\nhim, but I'm on\011duty right now.{DONE}",
    enby = "Hey. Could I\nget you to look\011for my buddy?\012He's goofing off\nsomewhere, that\011lazy bum!\012I want to go find\nhim, but I'm on\011duty right now.{DONE}" },
  { 0xce7be590, "Crystal",
    girl = "You're a tough\n kid.{DONE}",
    enby = "You're a tough\n kid.{DONE}" },
  { 0x2c6b599a, "Crystal",
    girl = "IRENE: Ohhhh!\nToo strong!{DONE}",
    enby = "IRENE: Ohhhh!\nToo strong!{DONE}" },
  { 0xd137bff1, "Crystal",
    girl = "How'd you like my\nMOOMOO MILK?\012It's my pride and\njoy, lady.\012Give it to POKéMON\nto restore HP!\012I'll give it to ya\nfer just ¥500.{DONE}",
    enby = "How'd you like my\nMOOMOO MILK?\012It's my pride and\njoy.\012Give it to POKéMON\nto restore HP!\012I'll give it to ya\nfer just ¥500.{DONE}" },
  { 0x2e0b67c2, "Crystal",
    girl = "LANCE: It's been a\nlong time since I\011last came here.\012This is where we\nhonor the LEAGUE\012CHAMPIONS for all\neternity.\012Their courageous\nPOKéMON are also\011inducted.\012Here today, we\nwitnessed the rise\012of a new LEAGUE\nCHAMPION--a\012trainer who feels\ncompassion for,\012and trust in, her\nPOKéMON.\012A trainer who\nsucceeded through\012perseverance and\ndetermination.\012The new LEAGUE\nCHAMPION who has\012all the makings\nof greatness!\012{PLAYER}, allow me\nto register you\012and your partners\nas CHAMPIONS!{DONE}",
    enby = "LANCE: It's been a\nlong time since I\011last came here.\012This is where we\nhonor the LEAGUE\012CHAMPIONS for all\neternity.\012Their courageous\nPOKéMON are also\011inducted.\012Here today, we\nwitnessed the rise\012of a new LEAGUE\nCHAMPION--a\012trainer who feels\ncompassion for,\012and trust in \nPOKéMON.\012A trainer who\nsucceeded through\012perseverance and\012determination.\012The new LEAGUE\nCHAMPION who has\012all the makings\nof greatness!\012{PLAYER}, allow me\nto register you\012and your partners\nas CHAMPIONS!{DONE}" },
  { 0x0697742a, "Crystal",
    girl = "{PLAYER}: Hi. You\nmust like POKéMON.\012{PLAYER}: No, not\nme. I asked you.\012{PLAYER}: Pardon?\nYou're weird!{DONE}" },
  { 0xce16cd39, "Crystal",
    girl = "{PLAYER}: Hi. Did\nyou really lose\011your POKé DOLL?\012{PLAYER}: You'll\nreally give me a\012rail PASS if I\nfind it for you?\012{PLAYER}: Sure,\nI'll look for it!\012You think you lost\nit when you were\011in VERMILION?{DONE}" },
  { 0xf78a134a, "Crystal",
    girl = "{PLAYER}: Thank you\nfor the rail PASS!\012{PLAYER}: …Pardon?\012{PLAYER}: Is it\nreally that fun to\012copy what I say\nand do?{DONE}" },
  { 0x2385e5ac, "Crystal",
    girl = "Hiya, kid! I\nsee you're new in\011MAHOGANY TOWN.\012Since you're new,\nyou should try a\012yummy RAGECANDY-\nBAR!\012Right now, it can\nbe yours for just\011¥300! Want one?{DONE}",
    enby = "Hiya, kid! I\nsee you're new in\011MAHOGANY TOWN.\012Since you're new,\nyou should try a\012yummy RAGECANDY-\nBAR!\012Right now, it can\nbe yours for just\011¥300! Want one?{DONE}" },
  { 0x84ea05fd, "Crystal",
    girl = "Let's see…\012…DARK CAVE leads\nto another road…\012That's good to\nknow.\012Thanks for bring-\ning this to me.\012My friend's a good\nguy, and you're \011swell too!\012I'd like to do\nsomething good in\011return too!\012I know! I want you\nto have this!{DONE}",
    enby = "Let's see…\012…DARK CAVE leads\nto another road…\012That's good to\nknow.\012Thanks for bring-\ning this to me.\012My friend's a good\nguy, and you're \011swell too!\012I'd like to do\nsomething good in\011return too!\012I know! I want you\nto have this!{DONE}" },
  { 0x241be52e, "Crystal",
    girl = "Whoa! You've\ngot more zip.{DONE}",
    enby = "Whoa! You've\ngot more zip.{DONE}" },
  { 0xf20aed88, "G/S",
    girl = "Hiya, kid! I\nsee you're new in\011MAHOGANY TOWN.\012Since you're new,\nyou should try a\012yummy RAGECANDY-\nBAR!\012Right now, it can\nbe yours for just\011¥300! Want one?{DONE}",
    enby = "Hiya, kid! I\nsee you're new in\011MAHOGANY TOWN.\012Since you're new,\nyou should try a\012yummy RAGECANDY-\nBAR!\012Right now, it can\nbe yours for just\011¥300! Want one?{DONE}" },
  { 0x3318f7e5, "G/S",
    girl = "Let's see…\012…DARK CAVE leads\nto another road…\012That's good to\nknow.\012Thanks for bring-\ning this to me.\012My friend's a good\nguy, and you're \011swell too!\012I'd like to do\nsomething good in\011return too!\012I know! I want you\nto have this!{DONE}",
    enby = "Let's see…\012…DARK CAVE leads\nto another road…\012That's good to\nknow.\012Thanks for bring-\ning this to me.\012My friend's a good\nguy, and you're \011swell too!\012I'd like to do\nsomething good in\011return too!\012I know! I want you\nto have this!{DONE}" },
  { 0x3ad5e9b0, "G/S",
    girl = "Whoa! You've\ngot more zip.{DONE}",
    enby = "Whoa! You've\ngot more zip.{DONE}" },
  { 0xfcc0d079, "G/S",
    girl = "You're a tough\n kid.{DONE}",
    enby = "You're a tough\n kid.{DONE}" },
  { 0xf9fdc4cc, "G/S",
    girl = "IRENE: Kyaaah!\nSomeone found us!{DONE}",
    enby = "IRENE: Kyaaah!\nSomeone found us!{DONE}" },
  { 0x567bac19, "G/S",
    girl = "IRENE: Ohhhh!\nToo strong!{DONE}",
    enby = "IRENE: Ohhhh!\nToo strong!{DONE}" },
  { 0x1c85c68a, "G/S",
    girl = "A young girl like\nyou should swim.\012Don't SURF on your\nPOKéMON.{DONE}",
    enby = "A young kid like\nyou should swim.\012Don't SURF on your\nPOKéMON.{DONE}" },
  { 0xde706903, "G/S",
    girl = "How'd you like my\nMOOMOO MILK?\012It's my pride and\njoy, lady.\012Give it to POKéMON\nto restore HP!\012I'll give it to ya\nfer just ¥500.{DONE}",
    enby = "How'd you like my\nMOOMOO MILK?\012It's my pride and\njoy.\012Give it to POKéMON\nto restore HP!\012I'll give it to ya\nfer just ¥500.{DONE}" },
  { 0x9b29476b, "G/S",
    girl = "Yo!\012… Huh? It's over\nalready?\012Sorry, sorry!\012CINNABAR GYM was\ngone, so I didn't\012know where to find\nyou.\012But, hey, you're\nplenty strong even\012without my advice.\nI knew you'd win!{DONE}",
    enby = "Yo!\012… Huh? It's over\nalready?\012Sorry, sorry!\012CINNABAR GYM was\ngone, so I didn't\012know where to find\nyou.\012But, hey, you're\nplenty strong even\012without my advice.\nI knew you'd win!{DONE}" },
  { 0xb9291c1a, "G/S",
    girl = "Hold it there,\nkiddo!\012The toll is ¥1000\nto go through.{DONE}",
    enby = "Hold it there,\nkiddo!\012The toll is ¥1000\nto go through.{DONE}" },
  { 0x8bb82249, "G/S",
    girl = "Thank you very\nmuch!{DONE}",
    enby = "Thank you very\nmuch!{DONE}" },
  { 0xc9e725f4, "G/S",
    girl = "Excuse me, kid!\nCan you do a guy\011a favor?\012Can you take this\nPOKéMON with MAIL\011to my friend?\012He's on ROUTE 31.{DONE}",
    enby = "Excuse me, kid!\nCan you do a guy\011a favor?\012Can you take this\nPOKéMON with MAIL\011to my friend?\012He's on ROUTE 31.{DONE}" },
  { 0x099800aa, "G/S",
    girl = "You will? Perfect!\nThanks, kid!\012My pal's a chubby\nguy who snoozes\011all the time.\012You'll recognize\nhim right away!{DONE}",
    enby = "You will? Perfect!\nThanks, kid!\012My pal's a chubby\nguy who snoozes\011all the time.\012You'll recognize\nhim right away!{DONE}" },
  { 0x76ba3a3e, "G/S",
    girl = "Thanks, kid! You\nmade the delivery\011for me!\012Here's something\nfor your trouble!{DONE}",
    enby = "Thanks, kid! You\nmade the delivery\011for me!\012Here's something\nfor your trouble!{DONE}" },
  { 0xbf385560, "G/S",
    girl = "BILL: I knew it!\nWay to go, hero!\012You're the real\ndeal!\012OK, I'm counting\non you. Take good\011care of it.{DONE}",
    enby = "BILL: I knew it!\nWay to go, hero!\012You're the real\ndeal!\012OK, I'm counting\non you. Take good\011care of it.{DONE}" },
  { 0x31e30760, "G/S",
    girl = "May I see your\nrail PASS, please?\012OK. Right this\nway, please.{DONE}",
    enby = "May I see your\nrail PASS, please?\012OK. Right this\nway, please.{DONE}" },
  { 0xb6a8283f, "G/S",
    girl = "SURGE: Hey, you\nlittle tyke!\012I have to hand it\nto you. It may not\012be very smart to\nchallenge me, but\011it takes guts!\012When it comes to\nelectric POKéMON,\011I'm number one!\012I've never lost on\nthe battlefield.\012I'll zap you just\nlike I did my\011enemies in war!{DONE}",
    enby = "SURGE: Hey, you\nlittle tyke!\012I have to hand it\nto you. It may not\012be very smart to\nchallenge me, but\011it takes guts!\012When it comes to\nelectric POKéMON,\011I'm number one!\012I've never lost on\nthe battlefield.\012I'll zap you just\nlike I did my\011enemies in war!{DONE}" },
  { 0x62101a4e, "G/S",
    girl = "SURGE: Arrrgh!\nYou are strong!\012OK, kid. You get\nTHUNDERBADGE!{DONE}",
    enby = "SURGE: Arrrgh!\nYou are strong!\012OK, kid. You get\nTHUNDERBADGE!{DONE}" },
  { 0xd40324af, "G/S",
    girl = "LANCE: It's been a\nlong time since I\011last came here.\012This is where we\nhonor the LEAGUE\012CHAMPIONS for all\neternity.\012Their courageous\nPOKéMON are also\011inducted.\012Here today, we\nwitnessed the rise\012of a new LEAGUE\nCHAMPION--a\012trainer who feels\ncompassion for,\012and trust in, her\nPOKéMON.\012A trainer who\nsucceeded through\012perseverance and\ndetermination.\012The new LEAGUE\nCHAMPION who has\012all the makings\nof greatness!\012{PLAYER}, allow me\nto register you\012and your partners\nas CHAMPIONS!{DONE}",
    enby = "LANCE: It's been a\nlong time since I\011last came here.\012This is where we\nhonor the LEAGUE\012CHAMPIONS for all\neternity.\012Their courageous\nPOKéMON are also\011inducted.\012Here today, we\nwitnessed the rise\012of a new LEAGUE\nCHAMPION--a\012trainer who feels\ncompassion for,\012and trust in \nPOKéMON.\012A trainer who\nsucceeded through\012perseverance and\012determination.\012The new LEAGUE\nCHAMPION who has\012all the makings\nof greatness!\012{PLAYER}, allow me\nto register you\012and your partners\nas CHAMPIONS!{DONE}" },
  { 0x0b0099de, "G/S",
    girl = "May I see your\nS.S.TICKET?{DONE}",
    enby = "May I see your\nS.S.TICKET?{DONE}" },
  { 0xdc35b030, "G/S",
    girl = "{PLAYER} flashed\nthe S.S.TICKET.\012That's it.\nThank you!{DONE}",
    enby = "{PLAYER} flashed\nthe S.S.TICKET.\012That's it.\nThank you!{DONE}" },
  { 0xecd04b8b, "G/S",
    girl = "Whoa!\012Excuse me.\nI was in a hurry!\012My granddaughter\nis missing!\012She's just a wee\ngirl. If you see\012her, please let me\nknow!{DONE}",
    enby = "Whoa!\012Excuse me.\nI was in a hurry!\012My granddaughter\nis missing!\012She's just a wee\ngirl. If you see\012her, please let me\nknow!{DONE}" },
  { 0x1ab9dd27, "G/S",
    girl = "I give up.\nYou don't have to\012look. Just forget\nabout it!{DONE}",
    enby = "I give up.\nYou don't have to\012look. Just forget\nabout it!{DONE}" },
  { 0xbd0227a9, "G/S",
    girl = "Ooh, wow. You're\ntough!{DONE}",
    enby = "Ooh, wow. You're\ntough!{DONE}" },
  { 0xa67d5982, "G/S",
    girl = "Hey, lady. Could I\nget you to look\011for my buddy?\012He's goofing off\nsomewhere, that\011lazy bum!\012I want to go find\nhim, but I'm on\011duty right now.{DONE}",
    enby = "Hey. Could I\nget you to look\011for my buddy?\012He's goofing off\nsomewhere, that\011lazy bum!\012I want to go find\nhim, but I'm on\011duty right now.{DONE}" },
  { 0x88af31f5, "G/S",
    girl = "BLUE: Yo! Finally\ngot here, huh?\012I wasn't in the\nmood at CINNABAR,\012but now I'm ready\nto battle you.\012…\012You're telling me\nyou conquered all\011the GYMS in JOHTO?\012Heh! JOHTO's GYMS\nmust be pretty\011pathetic then.\012Hey, don't worry\nabout it.\012I'll know if you\nare good or not by\012battling you right\nnow.\012Ready, JOHTO\nCHAMP?{DONE}",
    enby = "BLUE: Yo! Finally\ngot here, huh?\012I wasn't in the\nmood at CINNABAR,\012but now I'm ready\nto battle you.\012…\012You're telling me\nyou conquered all\011the GYMS in JOHTO?\012Heh! JOHTO's GYMS\nmust be pretty\011pathetic then.\012Hey, don't worry\nabout it.\012I'll know if you\nare good or not by\012battling you right\nnow.\012Ready, JOHTO\nCHAMP?{DONE}" },
  { 0xe0111602, "G/S",
    girl = "I'm sorry.\nThis would be your\012second time today.\nYou're permitted\012to enter just once\na day.{DONE}",
    enby = "I'm sorry.\nThis would be your\012second time today.\nYou're permitted\012to enter just once\na day.{DONE}" },
  { 0xe5bd916e, "G/S/C",
    girl = "Grandpa, here I\nam! I was playing\012with the CAPTAIN\nand this big girl!{DONE}",
    enby = "Grandpa, here I\nam! I was playing\012with the CAPTAIN\nand this person!{DONE}" },
  { 0x499280e9, "G/S/C",
    girl = "Lassie! If you can\ndefeat all the\012KIMONO GIRLS, I'll\ngive you a gift.{DONE}",
    enby = "If you can\ndefeat all the\012KIMONO GIRLS, I'll\ngive you a gift.{DONE}" },
  { 0x0930822b, "G/S/C",
    girl = "The SLOWPOKE came\nback, and you even\011found FARFETCH'D.\012You're the cool-\nest, lady!{DONE}",
    enby = "The SLOWPOKE came\nback, and you even\011found FARFETCH'D.\012You're the cool-\nest!{DONE}" },
}
playerText.LINES = LINES

local hash = require("mods.emerald_lens.rival_text").hash

-- [text table] = { [hash] = key } of the game's own lines, made once
local indexes = setmetatable({}, { __mode = "k" })
local wanted
local function indexOf(texts)
  if indexes[texts] then return indexes[texts] end
  if not wanted then
    wanted = {}
    for _, line in ipairs(LINES) do wanted[line[1]] = true end
  end
  local index = {}
  for key, text in pairs(texts) do
    if type(text) == "string" then
      local h = hash(text)
      if wanted[h] then
        index[h] = index[h] or {}
        table.insert(index[h], key)
      end
    end
  end
  indexes[texts] = index
  return index
end

-- data: the game's data; gen: 1 or 2; genderMode: "girl" or "enby" (a boy
-- look, or nil, changes nothing); setField(record, field, value) keeps
-- what was there to put back. Returns how many lines changed.
function playerText.apply(data, gen, genderMode, setField)
  if type(data) ~= "table" or (genderMode ~= "girl" and genderMode ~= "enby") then return 0 end
  local texts = gen == 2 and (data.gen2Text or data.text) or data.text
  if type(texts) ~= "table" then return 0 end
  local index, n = indexOf(texts), 0
  for _, line in ipairs(LINES) do
    local new = line[genderMode]
    for _, key in ipairs(new and index[line[1]] or {}) do
      -- only while it's still the game's own line
      if type(texts[key]) == "string" and hash(texts[key]) == line[1] then
        setField(texts, key, new)
        n = n + 1
      end
    end
  end
  return n
end

return playerText
