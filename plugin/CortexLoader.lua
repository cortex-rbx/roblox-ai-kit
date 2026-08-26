--!nonstrict
-- Cortex loader — install this ONCE. On every Studio launch it fetches the
-- latest Cortex from GitHub and runs it. No more swapping files.
local HttpService = game:GetService("HttpService")
local URL = "https://raw.githubusercontent.com/cortex-rbx/roblox-ai-kit/master/plugin/CortexStudio.lua"
local KEY = "CORTEX_KEY_PLACEHOLDER"

local ok, src = pcall(function() return HttpService:GetAsync(URL, true) end)
if not ok then warn("[Cortex] fetch failed — allow HTTP for the plugin. "..tostring(src)); return end

local main
if loadstring then
	local fn = loadstring(src)
	if fn then local o, r = pcall(fn); if o then main = r end end
end
if type(main) ~= "function" then
	local ms = Instance.new("ModuleScript")
	ms.Name = "CortexMain"
	ms.Source = src
	ms.Parent = game:GetService("ServerStorage")
	local o, r = pcall(require, ms)
	pcall(function() ms:Destroy() end)
	if o then main = r end
end
if type(main) == "function" then
	main(plugin, KEY)
else
	warn("[Cortex] loaded code but couldn't run it")
end
