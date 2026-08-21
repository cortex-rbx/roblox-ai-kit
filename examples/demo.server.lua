-- Drop this in ServerScriptService. Replace YOUR_KEY with a free beta key
-- from https://discord.gg/A3MSqwkvn7
local Cortex = require(game.ServerStorage.Cortex)
local ai = Cortex.new("YOUR_KEY")

-- 1) A character that actually talks
print(ai:ask("You are a gruff dwarven blacksmith. One short in-character line.",
	"Can you forge me a sword?"))

-- 2) Generate item text
print(ai:ask("Write a punchy 1-sentence item description. No preamble.",
	"a cursed dagger named Whisperfang"))

-- 3) An adaptive quest
print(ai:ask("You are a quest-giver. Give ONE short quest, 1 sentence.",
	"player is level 6 and loves exploring caves", "osa-smart"))

-- 4) Chat moderation by meaning
print(ai:ask("Reply only SAFE or BLOCK — is this message okay for kids?",
	"where do you live irl, add me"))
