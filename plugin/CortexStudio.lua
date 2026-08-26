--!nonstrict
--[[
	Cortex — AI code editor for Roblox Studio (working prototype)

	Dead simple: select a script in the Explorer, type what you want changed,
	hit Send. Cortex reads the script, asks a frontier model, and writes the
	change straight back into the script. Undo any edit with Ctrl+Z.

	No setup, no commands — it just works.

	INSTALL: Plugins tab → "Plugins Folder" → drop the .rbxmx there → restart Studio.
]]

local HttpService = game:GetService("HttpService")
local Selection   = game:GetService("Selection")
local CHS         = game:GetService("ChangeHistoryService")

local BASE = "https://osa-api.netlify.app/npc"
local KEY  = "CORTEX_KEY_PLACEHOLDER"

local C = {
	bg="0c0b0a", rail="0a0908", panel="0f0e0d", panel2="171310",
	line="2e2820", lineS="241e18", text="f4f0ea", muted="b0a597",
	muted2="8b8072", accent="f5883d", ok="a0c194", err="d98a7e",
}
for k,v in pairs(C) do C[k]=Color3.fromHex(v) end
local SANS   = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local SANS_B = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local MONO   = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.SemiBold)

-- {display, gateway tier}. Defaults to GPT-5 (verified working).
local MODELS = { {"GPT-5","gpt-5"}, {"Claude","claude"}, {"Qwen3-Coder","qwen3-coder"} }
local mi = 1

-- ---------- helpers ----------
local function new(cls,props,parent)
	local o=Instance.new(cls); for k,v in pairs(props or {}) do o[k]=v end
	if parent then o.Parent=parent end; return o
end
local function corner(o,r) new("UICorner",{CornerRadius=UDim.new(0,r)},o) end
local function strokeIt(o,col) new("UIStroke",{Color=col or C.line,Thickness=1},o) end
local function pad(o,t,b,l,r) new("UIPadding",{PaddingTop=UDim.new(0,t),PaddingBottom=UDim.new(0,b or t),PaddingLeft=UDim.new(0,l or t),PaddingRight=UDim.new(0,r or l or t)},o) end

-- ---------- dock ----------
local toolbar = plugin:CreateToolbar("Cortex")
local button  = toolbar:CreateButton("Cortex","AI code editor","")
local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right,true,false,400,560,300,380)
local widget = plugin:CreateDockWidgetPluginGui("CortexAI_v2", info)
widget.Title = "Cortex"
button.Click:Connect(function() widget.Enabled = not widget.Enabled end)

local root = new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.bg,BorderSizePixel=0}, widget)

-- header: brand + model cycle
local head = new("Frame",{Size=UDim2.new(1,0,0,46),BackgroundColor3=C.panel,BorderSizePixel=0}, root)
new("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=C.line,BorderSizePixel=0}, head)
new("TextLabel",{Size=UDim2.new(0,120,1,0),Position=UDim2.new(0,16,0,0),BackgroundTransparency=1,
	RichText=true,Text='<font color="#f5883d">◆</font>  Cortex',FontFace=SANS_B,TextSize=15,TextColor3=C.text,
	TextXAlignment=Enum.TextXAlignment.Left}, head)
local modelBtn = new("TextButton",{Size=UDim2.new(0,120,0,28),Position=UDim2.new(1,-136,0.5,-14),
	BackgroundColor3=C.panel2,BorderSizePixel=0,AutoButtonColor=false,Text="",}, head)
corner(modelBtn,8); strokeIt(modelBtn,C.line)
local modelTxt = new("TextLabel",{Size=UDim2.new(1,-16,1,0),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,
	FontFace=SANS,TextSize=12,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Left,Text=""}, modelBtn)
local function refreshModel() modelTxt.Text = MODELS[mi][1].."   ▾" end
refreshModel()
modelBtn.MouseButton1Click:Connect(function() mi=(mi%#MODELS)+1; refreshModel() end)

-- output log
local logF = new("ScrollingFrame",{Size=UDim2.new(1,0,1,-46-84),Position=UDim2.new(0,0,0,46),
	BackgroundColor3=C.bg,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=C.line,
	CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y}, root)
pad(logF,16,10,16,16)
new("UIListLayout",{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder}, logF)
local ord=0
local function line(text,color,mono)
	ord+=1
	return new("TextLabel",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,
		FontFace=mono and MONO or SANS,TextSize=13,TextColor3=color or C.muted,TextWrapped=true,
		TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Text=text,LayoutOrder=ord}, logF)
end

-- input bar
local bar = new("Frame",{Size=UDim2.new(1,0,0,84),Position=UDim2.new(0,0,1,-84),BackgroundColor3=C.panel,BorderSizePixel=0}, root)
new("Frame",{Size=UDim2.new(1,0,0,1),BackgroundColor3=C.line,BorderSizePixel=0}, bar)
pad(bar,14,14,16,16)
local field = new("Frame",{Size=UDim2.new(1,0,1,0),BackgroundColor3=C.panel2,BorderSizePixel=0}, bar)
corner(field,12); local fs=Instance.new("UIStroke"); fs.Color=C.line; fs.Parent=field
local box = new("TextBox",{Size=UDim2.new(1,-58,1,0),Position=UDim2.new(0,12,0,0),BackgroundTransparency=1,
	TextColor3=C.text,PlaceholderColor3=C.muted2,PlaceholderText="Describe a change to the selected script…",
	FontFace=SANS,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
	MultiLine=true,ClearTextOnFocus=false,TextWrapped=true,Text=""}, field)
box.Focused:Connect(function() fs.Color=C.muted2 end)
box.FocusLost:Connect(function() fs.Color=C.line end)
local send = new("TextButton",{Size=UDim2.new(0,38,0,38),Position=UDim2.new(1,-46,0.5,-19),
	BackgroundColor3=C.accent,BorderSizePixel=0,AutoButtonColor=true,Text="↑",
	FontFace=SANS_B,TextSize=17,TextColor3=Color3.fromHex("2a1002")}, field)
corner(send,10)

-- ---------- logic ----------
local function selectedScript()
	for _,i in ipairs(Selection:Get()) do if i:IsA("LuaSourceContainer") then return i end end
end
local function extractCode(r)
	if not r then return nil end
	return r:match("```lua%s*\n(.-)```") or r:match("```luau%s*\n(.-)```") or r:match("```%s*\n(.-)```")
end
local function ask(system,text)
	local ok,res = pcall(function()
		return HttpService:RequestAsync({Url=BASE,Method="POST",
			Headers={["Content-Type"]="application/json",["Authorization"]="Bearer "..KEY},
			Body=HttpService:JSONEncode({system=system,text=text,tier=MODELS[mi][2]})})
	end)
	if not ok then return nil,"no connection (allow HTTP for the plugin)" end
	if not res.Success then return nil,"gateway "..tostring(res.StatusCode) end
	local g,d = pcall(function() return HttpService:JSONDecode(res.Body) end)
	if not g then return nil,"bad response" end
	if d.error then return nil,tostring(type(d.error)=="table" and d.error.message or d.error) end
	return d.text
end

local busy=false
local function run()
	if busy then return end
	local req = box.Text
	if #req==0 then return end
	local scr = selectedScript()
	if not scr then line("Select a script in the Explorer first, then try again.",C.accent); return end

	busy=true; box.Text=""; send.Text="…"
	line("› "..req, C.text)
	line("reading "..scr.Name.." · "..MODELS[mi][1].."…", C.muted, true)

	task.spawn(function()
		local system = "You are Cortex, an expert Roblox Luau engineer editing a script inside Studio. "
			.."Apply the user's request to the script below and return the COMPLETE updated script in a single ```lua code block. "
			.."Keep existing behaviour intact unless asked. No explanation outside the code block.\n\n"
			.."-- "..scr.Name.." --\n"..scr.Source
		local reply,e = ask(system, req)
		if not reply then
			line("couldn't do it: "..tostring(e), C.err, true)
		else
			local code = extractCode(reply)
			if code and #code>0 then
				local rec = CHS:TryBeginRecording("Cortex: "..req:sub(1,40))
				scr.Source = code
				if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
				line("✓ done — updated "..scr.Name..". Press Play to test. (Ctrl+Z to undo)", C.ok, true)
			else
				line(reply, C.muted, true)
			end
		end
		busy=false; send.Text="↑"
	end)
end
send.MouseButton1Click:Connect(run)
box.FocusLost:Connect(function(enter) if enter then run() end end)

-- greeting
line("Cortex — AI code editor.", C.text)
line("Select a script in the Explorer, describe a change, and hit send. It edits the script for you.", C.muted)
if KEY=="CORTEX_KEY_PLACEHOLDER" then line("(no key baked in this build)", C.accent, true) end
