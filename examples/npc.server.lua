--[[
	Example: a talking NPC that remembers each player, moderates their input,
	and behaves correctly in multiplayer — all handled by the SDK.

	Put Cortex (the ModuleScript) in ServerStorage, then put THIS in a
	Script under ServerScriptService. Wire `askNpc` to a ProximityPrompt,
	RemoteEvent, or chat command from your game.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Cortex = require(ServerStorage.Cortex)
local ai = Cortex.new("YOUR_KEY", {
	perPlayerCooldown = 1.5, -- one reply per player per 1.5s (anti-spam)
})

-- One NPC. `moderate = true` blocks nasty player input before it hits the model;
-- memory is per-player and correct across many players at once.
local blacksmith = ai:npc({
	personality = "You are Bramm, a gruff dwarven blacksmith. Reply in character, one or two short sentences.",
	moderate = true,
})

-- Call this when a player talks to the NPC.
local function askNpc(player: Player, message: string)
	local reply = blacksmith:say(player, message)
	if not reply then
		return -- blocked, on cooldown, or a transient error the SDK already retried
	end
	-- ALWAYS filter AI output through Roblox before showing it to players.
	local safe = ai:filterForPlayer(reply, player)
	-- show `safe` however your game displays NPC dialogue (BillboardGui, chat bubble…)
	print(("[%s] %s"):format(player.Name, safe))
end

-- Free the player's memory when they leave.
Players.PlayerRemoving:Connect(function(player)
	blacksmith:forget(player)
end)

-- --- quick demo: reply to a chat message starting with "npc " ---------------
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(msg)
		if msg:sub(1, 4):lower() == "npc " then
			askNpc(player, msg:sub(5))
		end
	end)
end)
