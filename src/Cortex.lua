--!strict
--[[
	Cortex — AI for any part of your Roblox game.
	One server-side request. Your key never touches the client.

	Free beta key:  https://discord.gg/A3MSqwkvn7
	Docs & demo:    https://cortex-rbx.github.io

	Put this ModuleScript in ServerStorage/ServerScriptService and call it
	from a SERVER Script (Roblox blocks HTTP from LocalScripts).
]]

local HttpService = game:GetService("HttpService")

export type Tier = "osa-fast" | "osa-smart" | "osa-cheap" | "osa-auto"

local Cortex = {}
Cortex.__index = Cortex

local BASE = "https://osa-api.netlify.app"

function Cortex.new(apiKey: string)
	assert(apiKey and #apiKey > 0, "Cortex.new: pass your beta key")
	return setmetatable({ _key = apiKey }, Cortex)
end

--[[
	ask(instructions, input, tier?) -> text, unitsLeft
	`instructions` = what to do (the role/task).  `input` = the player/game input.
	Anything text-shaped: dialogue, quests, item/lore text, moderation.
]]
function Cortex:ask(instructions: string, input: string, tier: Tier?): (string?, number?)
	local ok, res = pcall(function()
		return HttpService:PostAsync(BASE .. "/npc", HttpService:JSONEncode({
			system = instructions,
			text = input,
			tier = tier or "osa-fast",
		}), Enum.HttpContentType.ApplicationJson, false, {
			Authorization = "Bearer " .. self._key,
		})
	end)
	if not ok then
		warn("[Cortex] request failed:", res)
		return nil
	end
	local data = HttpService:JSONDecode(res)
	return data.text, data.units_left
end

return Cortex
