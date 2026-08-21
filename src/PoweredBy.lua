--!strict
--[[
	Optional "AI by Cortex" badge — a small, subtle tag you can show in your game.
	Keeping it on the free tier helps other devs discover Cortex and unlocks your
	referral rewards. Paid tier removes it.

	Call from a LocalScript:
		local showBadge = require(game.ReplicatedStorage.PoweredBy)
		showBadge(game.Players.LocalPlayer.PlayerGui)
]]

local function showBadge(parent: Instance): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "CortexBadge"
	gui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(1, 1)
	label.Position = UDim2.new(1, -8, 1, -8)
	label.Size = UDim2.fromOffset(140, 22)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(5, 6, 10)
	label.TextColor3 = Color3.fromRGB(244, 247, 251)
	label.TextSize = 12
	label.Font = Enum.Font.Gotham
	label.Text = "🧠 AI by Cortex"
	label.Parent = gui

	gui.Parent = parent
	return gui
end

return showBadge
