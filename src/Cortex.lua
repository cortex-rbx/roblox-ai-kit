--[[
	Cortex — AI for Roblox games, correct by default.

	One server-side request gives your game a brain: talking NPCs, quests,
	generated text, chat moderation. Your key never touches the client.

	Unlike a bare API wrapper, this SDK ships the server-side plumbing most
	devs get wrong — ON BY DEFAULT:
	  • per-player cooldown        no "only the first player talks" bug
	  • retry + backoff on 429/5xx transient errors don't surface to players
	  • response caching           identical prompts are free + ease the
	                               HttpService 500-req/min server cap
	  • moderation helper          SAFE / BLOCK by meaning, + Roblox filter
	  • NPC objects                per-player memory, correct multiplayer state

	Put this ModuleScript in ServerStorage and require it from a SERVER Script
	(Roblox blocks HTTP from LocalScripts). Turn on
	Game Settings → Security → Allow HTTP Requests.

	Free beta key:  https://discord.gg/A3MSqwkvn7
	Docs & demo:    https://cortex-rbx.github.io
]]

local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

export type Tier = "osa-fast" | "osa-smart" | "osa-cheap" | "osa-auto"
export type AskOptions = {
	tier: Tier?,
	player: Player?,       -- pass the player to enable per-player cooldown
	cacheKey: string?,     -- override the automatic cache key
	bypassCache: boolean?, -- force a fresh call
}

local BASE = "https://osa-api.netlify.app/npc"

local Cortex = {}
Cortex.__index = Cortex

-- new(key, opts?)
--   opts: { tier?, perPlayerCooldown?=1.0, maxRetries?=3, cacheTtl?=300,
--           cacheEnabled?=true }
function Cortex.new(apiKey: string, opts: { [string]: any }?)
	assert(apiKey and #apiKey > 0, "Cortex.new: pass your beta key")
	local o = opts or {}
	return setmetatable({
		_key = apiKey,
		_tier = o.tier or "osa-smart",
		_cooldown = o.perPlayerCooldown or 1.0,
		_maxRetries = o.maxRetries or 3,
		_cacheTtl = o.cacheTtl or 300,
		_cacheEnabled = o.cacheEnabled ~= false,
		_cache = {},  -- [key] = { text = string, expires = number }
		_last = {},   -- [userId] = os.clock()
	}, Cortex)
end

-- internal: POST with retry + exponential backoff on 429 / 5xx / network fail
function Cortex:_send(body)
	local payload = HttpService:JSONEncode(body)
	for attempt = 1, self._maxRetries + 1 do
		local ok, res = pcall(function()
			return HttpService:RequestAsync({
				Url = BASE,
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json",
					["Authorization"] = "Bearer " .. self._key,
				},
				Body = payload,
			})
		end)
		if ok and res.Success then
			local good, data = pcall(function()
				return HttpService:JSONDecode(res.Body)
			end)
			if good then return data end
			return nil, "bad response"
		end
		local status = (ok and res.StatusCode) or 0
		local retriable = (not ok) or status == 429 or status >= 500
		if not retriable or attempt > self._maxRetries then
			return nil, ok and ("HTTP " .. tostring(status)) or "network error"
		end
		task.wait(0.5 * 2 ^ (attempt - 1)) -- 0.5s, 1s, 2s...
	end
	return nil, "unreachable"
end

--[[
	ask(instructions, input, tierOrOpts?) -> text?, unitsLeft?

	`instructions` = the role/task.  `input` = the player/game input.
	Third arg is backward compatible: a tier string OR an options table.

	    ai:ask("You are a gruff blacksmith. One line.", "forge me a sword?")
	    ai:ask(personality, message, { player = plr })  -- per-player cooldown
]]
function Cortex:ask(instructions: string, input: string, tierOrOpts): (string?, number?)
	local opts
	if type(tierOrOpts) == "string" then
		opts = { tier = tierOrOpts }
	else
		opts = tierOrOpts or {}
	end
	local tier = opts.tier or self._tier

	-- per-player cooldown. State is keyed by UserId, so the classic
	-- "global debounce = only the first player gets a reply" bug can't happen.
	if opts.player then
		local uid = opts.player.UserId
		local now = os.clock()
		local last = self._last[uid]
		if last and (now - last) < self._cooldown then
			return nil, nil -- on cooldown; show "..." or ignore
		end
		self._last[uid] = now
	end

	-- cache: identical instructions+input+tier come back free (and don't
	-- burn a request against the HttpService cap).
	local ck = opts.cacheKey or (instructions .. "\1" .. input .. "\1" .. tier)
	if self._cacheEnabled and not opts.bypassCache then
		local hit = self._cache[ck]
		if hit and hit.expires > os.clock() then
			return hit.text, nil
		end
	end

	local data, err = self:_send({ system = instructions, text = input, tier = tier })
	if not data then
		warn("[Cortex] " .. tostring(err))
		return nil
	end
	if data.error then
		warn("[Cortex] " .. tostring(data.error))
		return nil
	end
	if self._cacheEnabled and type(data.text) == "string" then
		self._cache[ck] = { text = data.text, expires = os.clock() + self._cacheTtl }
	end
	return data.text, data.units_left
end

--[[
	moderate(text) -> "SAFE" | "BLOCK"
	Classifies by meaning, not a word list. One short token, so it's cheap.
]]
function Cortex:moderate(text: string): string
	local verdict = self:ask(
		"You moderate a kids' Roblox game. Reply with exactly one word: SAFE or BLOCK.",
		text,
		{ tier = "osa-fast", cacheKey = "mod\1" .. text }
	)
	if verdict and string.find(string.upper(verdict), "BLOCK") then
		return "BLOCK"
	end
	return "SAFE"
end

--[[
	filterForPlayer(text, player) -> filtered string
	Run AI output through Roblox's text filter BEFORE you show it. Unfiltered
	AI text can get your game moderated — always filter what you display.
]]
function Cortex:filterForPlayer(text: string, player: Player): string
	local ok, filtered = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	return ok and filtered or "..."
end

--[[
	npc(config) -> an NPC object with per-player memory + built-in cooldown.
	config: { personality, memory?=true, historyLimit?=8, moderate?=false }

	    local blacksmith = ai:npc({ personality = "You are a gruff blacksmith." })
	    local reply = blacksmith:say(player, "forge me a sword?")
	    -- remember to blacksmith:forget(player) on PlayerRemoving
]]
function Cortex:npc(config)
	local ai = self
	local npc = {
		personality = config.personality,
		memory = config.memory ~= false,
		limit = config.historyLimit or 8,
		moderate = config.moderate or false,
		_hist = {}, -- [userId] = { lines }
	}

	function npc:say(player: Player, message: string): string?
		if self.moderate and ai:moderate(message) == "BLOCK" then
			return nil
		end
		local prompt = message
		if self.memory then
			local h = self._hist[player.UserId]
			prompt = (h and #h > 0 and (table.concat(h, "\n") .. "\nPlayer: " .. message))
				or ("Player: " .. message)
		end
		local reply = ai:ask(self.personality, prompt, { player = player })
		if not reply then return nil end
		if self.memory then
			local h = self._hist[player.UserId] or {}
			table.insert(h, "Player: " .. message)
			table.insert(h, "You: " .. reply)
			while #h > self.limit * 2 do table.remove(h, 1) end
			self._hist[player.UserId] = h
		end
		return reply
	end

	function npc:forget(player: Player)
		self._hist[player.UserId] = nil
	end

	return npc
end

return Cortex
