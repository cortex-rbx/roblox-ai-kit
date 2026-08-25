--!nonstrict
--[[
	Cortex Studio — AI coding terminal, as a Roblox Studio plugin (skeleton v1)
	==========================================================================

	WHAT IT DOES (v1 skeleton — enough to test the whole loop end to end):
	  • Docks a dark terminal panel in Studio (Plugins tab → "Cortex" button).
	  • Reads the script you have SELECTED in the Explorer.
	  • Sends your request + that script to the Cortex backend.
	  • Prints the reply in the terminal, with response time + a model line.
	  • `/apply` writes the last ```lua code block back into the selected script
	    (respects the "Ask before edits" idea — it only applies on /apply).
	  • Works OFFLINE too: if there's no key or the request fails, it falls back
	    to a mock reply so the UI + Studio integration always demo cleanly.

	INSTALL (do this once, on your computer):
	  1. Open Roblox Studio.
	  2. Explorer → right-click anywhere → Insert Object → Script.
	  3. Paste this whole file into that Script.
	  4. Right-click the Script in Explorer → "Save as Local Plugin…" → Save.
	  5. A "Cortex" button appears in the Plugins toolbar. Click it.

	FIRST RUN:
	  • In the terminal type:  /key YOUR_BETA_KEY   (stored locally, once).
	  • Select a Script/ModuleScript in the Explorer.
	  • Type a request, e.g. "add a comment header explaining this script".
	  • Hit Send. Then `/apply` to write the change into the script.

	NOTE: the backend currently routes cheaper models on /npc; frontier model
	routing (Opus/Sonnet/Qwen) is the next backend step. The pipe is real either
	way — this proves read-script → Cortex → reply → apply.
]]

local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")

local BASE = "https://osa-api.netlify.app/npc"

-- ---------- design tokens (match the mockup) --------------------------------
local C = {
	bg    = Color3.fromHex("0c0b0a"),
	panel = Color3.fromHex("0f0e0d"),
	panel2= Color3.fromHex("141210"),
	line  = Color3.fromHex("211d19"),
	text  = Color3.fromHex("e9e5e0"),
	muted = Color3.fromHex("7c766e"),
	muted2= Color3.fromHex("4f4a44"),
	accent= Color3.fromHex("c9743f"),
	add   = Color3.fromHex("8a9b82"),
}

-- ---------- named models catalog (name -> unit cost) ------------------------
local MODELS = {
	{name = "Claude Sonnet 5",   u = 4},
	{name = "Claude Opus 4.8",   u = 10},
	{name = "GPT-5",             u = 6},
	{name = "Qwen3-Coder 480B",  u = 1},
}
local modelIndex = 1

-- ---------- toolbar + dock widget -------------------------------------------
local toolbar = plugin:CreateToolbar("Cortex")
local button  = toolbar:CreateButton("Cortex", "Open the Cortex AI terminal", "")
button.ClickableWhenViewportHidden = true

local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 440, 640, 320, 420)
local widget = plugin:CreateDockWidgetPluginGui("CortexTerminal_v1", info)
widget.Title = "Cortex"

button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

-- ---------- helpers ----------------------------------------------------------
local function px(n) return UDim.new(0, n) end
local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function pad(inst, n)
	make("UIPadding", {
		PaddingTop = px(n), PaddingBottom = px(n), PaddingLeft = px(n), PaddingRight = px(n),
	}, inst)
end
local function corner(inst, r)
	make("UICorner", { CornerRadius = UDim.new(0, r) }, inst)
end
local function stroke(inst, col)
	make("UIStroke", { Color = col or C.line, Thickness = 1 }, inst)
end

-- ---------- build UI ---------------------------------------------------------
local root = make("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BorderSizePixel = 0,
}, widget)

-- header
local header = make("Frame", {
	Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, root)
make("Frame", { Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1), BackgroundColor3 = C.line, BorderSizePixel = 0 }, header)
make("TextLabel", {
	Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0,16,0,0),
	BackgroundTransparency = 1, TextColor3 = C.text, Font = Enum.Font.GothamMedium,
	TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Text = "◆  Cortex",
}, header)

-- terminal log (scrolling)
local logFrame = make("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, -40 - 96), Position = UDim2.new(0, 0, 0, 40),
	BackgroundColor3 = C.bg, BorderSizePixel = 0, ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.line, CanvasSize = UDim2.new(0,0,0,0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
}, root)
pad(logFrame, 14)
local logList = make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder, Padding = px(6),
}, logFrame)

local lineOrder = 0
local function addLine(text, color, mono)
	lineOrder += 1
	local lbl = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, TextColor3 = color or C.muted,
		Font = mono and Enum.Font.Code or Enum.Font.Gotham, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true, Text = text, LayoutOrder = lineOrder,
	}, logFrame)
	return lbl
end
local function divider()
	lineOrder += 1
	make("Frame", { Size = UDim2.new(1,0,0,1), BackgroundColor3 = C.line, BorderSizePixel = 0, LayoutOrder = lineOrder }, logFrame)
end

-- input area
local inputBar = make("Frame", {
	Size = UDim2.new(1, 0, 0, 96), Position = UDim2.new(0, 0, 1, -96),
	BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, root)
make("Frame", { Size = UDim2.new(1,0,0,1), BackgroundColor3 = C.line, BorderSizePixel = 0 }, inputBar)

local field = make("Frame", {
	Size = UDim2.new(1, -24, 0, 40), Position = UDim2.new(0, 12, 0, 12),
	BackgroundColor3 = C.panel2, BorderSizePixel = 0,
}, inputBar)
corner(field, 12); stroke(field, C.line)
local box = make("TextBox", {
	Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 10, 0, 0),
	BackgroundTransparency = 1, TextColor3 = C.text, PlaceholderColor3 = C.muted2,
	PlaceholderText = "Ask Cortex to build or fix something…", Font = Enum.Font.Gotham,
	TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
	Text = "",
}, field)

-- controls row: model button | units | send
local modelBtn = make("TextButton", {
	Size = UDim2.new(0, 190, 0, 28), Position = UDim2.new(0, 12, 0, 60),
	BackgroundColor3 = C.panel2, BorderSizePixel = 0, AutoButtonColor = false,
	TextColor3 = C.muted, Font = Enum.Font.Gotham, TextSize = 12,
	Text = "", TextXAlignment = Enum.TextXAlignment.Left,
}, inputBar)
corner(modelBtn, 8); stroke(modelBtn, C.line)
pad(modelBtn, 8)
local function refreshModel()
	local m = MODELS[modelIndex]
	modelBtn.Text = m.name .. "   " .. m.u .. "u  ▾"
end
refreshModel()
modelBtn.MouseButton1Click:Connect(function()
	modelIndex = (modelIndex % #MODELS) + 1
	refreshModel()
end)

local sendBtn = make("TextButton", {
	Size = UDim2.new(0, 30, 0, 28), Position = UDim2.new(1, -42, 0, 60),
	BackgroundColor3 = C.bg, BorderSizePixel = 0, AutoButtonColor = true,
	TextColor3 = C.accent, Font = Enum.Font.GothamBold, TextSize = 14, Text = "↑",
}, inputBar)
corner(sendBtn, 8); stroke(sendBtn, C.line)

-- ---------- key storage ------------------------------------------------------
local function getKey() return plugin:GetSetting("cortex_key") end
local function setKey(k) plugin:SetSetting("cortex_key", k) end

-- ---------- selected script --------------------------------------------------
local function selectedScript()
	for _, inst in ipairs(Selection:Get()) do
		if inst:IsA("LuaSourceContainer") then return inst end
	end
	return nil
end

-- pull the last ```lua ... ``` block out of a reply
local function extractCode(reply)
	local code = reply:match("```lua%s*\n(.-)```") or reply:match("```%s*\n(.-)```")
	return code
end
local lastCode = nil

-- ---------- talk to Cortex ---------------------------------------------------
local function callCortex(system, text)
	local key = getKey()
	if not key or #key == 0 then return nil, "no-key" end
	local ok, res = pcall(function()
		return HttpService:RequestAsync({
			Url = BASE, Method = "POST",
			Headers = { ["Content-Type"] = "application/json", ["Authorization"] = "Bearer " .. key },
			Body = HttpService:JSONEncode({ system = system, text = text, tier = "osa-smart" }),
		})
	end)
	if not ok then return nil, "http-error" end
	if not res.Success then return nil, "HTTP " .. tostring(res.StatusCode) end
	local good, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
	if not good then return nil, "bad-json" end
	return data.text, nil
end

local function mockReply(scriptName, request)
	return ("(offline demo — no key or backend)\n\nFor `%s` you asked: \"%s\".\nHere's a sample change:\n\n```lua\n-- Cortex: %s\nprint(\"Cortex is wired in\")\n```")
		:format(scriptName or "selection", request, request)
end

-- ---------- run one request --------------------------------------------------
local busy = false
local function run()
	if busy then return end
	local request = box.Text
	if #request == 0 then return end

	-- commands
	if request:sub(1,5) == "/key " then
		setKey(request:sub(6))
		box.Text = ""
		addLine("✓ key saved locally", C.add, false)
		return
	elseif request == "/new" then
		for _, c in ipairs(logFrame:GetChildren()) do
			if c:IsA("TextLabel") or (c:IsA("Frame") and c.Size.Y.Offset == 1) then c:Destroy() end
		end
		lineOrder = 0; box.Text = ""
		return
	elseif request == "/apply" then
		local scr = selectedScript()
		if not scr then addLine("· no script selected", C.muted, true); return end
		if not lastCode then addLine("· nothing to apply yet", C.muted, true); return end
		scr.Source = lastCode
		addLine("✓ applied to " .. scr.Name, C.add, true)
		box.Text = ""
		return
	end

	busy = true
	box.Text = ""
	-- user bubble
	divider()
	addLine("› " .. request, C.text, false)

	local scr = selectedScript()
	local sourceCtx = ""
	if scr then
		addLine("· read " .. scr.ClassName .. " › " .. scr.Name, C.muted, true)
		sourceCtx = "\n\nThe user's selected script (" .. scr.Name .. "):\n" .. scr.Source
	else
		addLine("· no script selected — answering generally", C.muted, true)
	end

	local system = "You are Cortex, a Roblox Luau coding assistant inside Studio. "
		.. "Answer concisely. When you change code, return the full updated script in a ```lua code block." .. sourceCtx

	local t0 = os.clock()
	local reply, e2 = callCortex(system, request)
	if not reply then
		reply = mockReply(scr and scr.Name or nil, request)
	end
	local ms = math.floor((os.clock() - t0) * 1000)

	addLine(reply, C.muted, true)
	lastCode = extractCode(reply)
	if lastCode then
		addLine("· code ready — type /apply to write it into the selected script", C.accent, true)
	end
	local m = MODELS[modelIndex]
	addLine(("%.1fs · %s · 1 agent"):format(ms/1000, m.name), C.muted2, true)
	busy = false
end

sendBtn.MouseButton1Click:Connect(run)
box.FocusLost:Connect(function(enter)
	if enter then run() end
end)

-- greeting
addLine("Cortex terminal ready.", C.text, false)
addLine("First: /key YOUR_BETA_KEY  ·  then select a script and ask.", C.muted, true)
addLine("Commands: /key <k> · /new · /apply", C.muted2, true)
