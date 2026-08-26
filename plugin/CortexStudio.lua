--!nonstrict
--[[
	Cortex — AI builder for Roblox Studio (pixel prototype)
	Type what you want, hit send. It turns it into Luau and runs it in your place.
	Undo with Ctrl+Z. No setup.
	INSTALL: Plugins tab → "Plugins Folder" → drop the .rbxmx → restart Studio.
]]

local HttpService = game:GetService("HttpService")
local Selection   = game:GetService("Selection")
local CHS         = game:GetService("ChangeHistoryService")

local BASE = "https://osa-api.netlify.app/npc"
local KEY  = "CORTEX_KEY_PLACEHOLDER"

-- pixel palette, high contrast (bright text guaranteed)
local C = {
	bg="0a0b0e", panel="12141a", panel2="1c2029", line="323847",
	text="f6f8fc", sub="c6cfdc", muted="8a94a6", accent="ffa23e",
	ok="76e08a", err="ff6f6f",
}
for k,v in pairs(C) do C[k]=Color3.fromHex(v) end
local F = Enum.Font.Code   -- mono, renders everywhere, pixel/terminal feel

local MODELS = { {"gpt-5","gpt-5","🤖"}, {"claude","claude","🧠"}, {"qwen3-coder","qwen3-coder","⚙"} }
local mi = 1

local function new(cls,props,parent)
	local o=Instance.new(cls); for k,v in pairs(props or {}) do o[k]=v end
	if parent then o.Parent=parent end; return o
end
local function stk(o,col,t) new("UIStroke",{Color=col or C.line,Thickness=t or 1},o) end
local function pad(o,t,b,l,r) new("UIPadding",{PaddingTop=UDim.new(0,t),PaddingBottom=UDim.new(0,b or t),PaddingLeft=UDim.new(0,l or t),PaddingRight=UDim.new(0,r or l or t)},o) end
local function label(props,parent)
	local d={BackgroundTransparency=1,Font=F,TextSize=14,TextColor3=C.text,
		TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center}
	for k,v in pairs(props) do d[k]=v end
	return new("TextLabel",d,parent)
end

local toolbar=plugin:CreateToolbar("Cortex")
local button=toolbar:CreateButton("Cortex","AI builder","")
local info=DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right,true,false,400,560,300,380)
local widget=plugin:CreateDockWidgetPluginGui("CortexPix_v1",info)
widget.Title="Cortex"
button.Click:Connect(function() widget.Enabled=not widget.Enabled end)

local root=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.bg,BorderSizePixel=0},widget)

-- header (sharp pixel bar)
local head=new("Frame",{Size=UDim2.new(1,0,0,46),BackgroundColor3=C.panel,BorderSizePixel=0},root)
new("Frame",{Size=UDim2.new(1,0,0,2),Position=UDim2.new(0,0,1,-2),BackgroundColor3=C.accent,BorderSizePixel=0},head)
label({Size=UDim2.new(0,180,1,0),Position=UDim2.new(0,14,0,0),Text="🤖 CORTEX",TextSize=16,TextColor3=C.text},head)
local modelBtn=new("TextButton",{Size=UDim2.new(0,120,0,28),Position=UDim2.new(1,-134,0.5,-14),
	BackgroundColor3=C.panel2,BorderSizePixel=0,AutoButtonColor=false,Text=""},head)
stk(modelBtn,C.line)
local modelTxt=label({Size=UDim2.new(1,-12,1,0),Position=UDim2.new(0,8,0,0),TextSize=13,TextColor3=C.sub,Text=""},modelBtn)
local function refM() modelTxt.Text=MODELS[mi][3].." "..MODELS[mi][1] end; refM()
modelBtn.MouseButton1Click:Connect(function() mi=(mi%#MODELS)+1; refM() end)

-- output
local logF=new("ScrollingFrame",{Size=UDim2.new(1,0,1,-46-90),Position=UDim2.new(0,0,0,46),
	BackgroundColor3=C.bg,BorderSizePixel=0,ScrollBarThickness=6,ScrollBarImageColor3=C.line,
	CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y},root)
pad(logF,14,12,14,14)
local lay=new("UIListLayout",{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder},logF)
local ord=0
local function line(text,color,size)
	ord+=1
	local l=label({Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,Text=text,TextColor3=color or C.sub,
		TextSize=size or 14,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,LayoutOrder=ord},logF)
	task.defer(function() logF.CanvasPosition=Vector2.new(0,lay.AbsoluteContentSize.Y) end)
	return l
end

-- input (sharp pixel box)
local bar=new("Frame",{Size=UDim2.new(1,0,0,90),Position=UDim2.new(0,0,1,-90),BackgroundColor3=C.panel,BorderSizePixel=0},root)
new("Frame",{Size=UDim2.new(1,0,0,1),BackgroundColor3=C.line,BorderSizePixel=0},bar)
pad(bar,14,14,14,14)
local field=new("Frame",{Size=UDim2.new(1,0,1,0),BackgroundColor3=C.panel2,BorderSizePixel=0},bar)
local fs=Instance.new("UIStroke"); fs.Color=C.line; fs.Thickness=2; fs.Parent=field
local box=new("TextBox",{Size=UDim2.new(1,-62,1,-16),Position=UDim2.new(0,12,0,8),BackgroundTransparency=1,
	TextColor3=C.text,PlaceholderColor3=C.muted,PlaceholderText="tell me what to build…",
	Font=F,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
	MultiLine=true,ClearTextOnFocus=false,TextWrapped=true,Text=""},field)
box.Focused:Connect(function() fs.Color=C.accent end)
box.FocusLost:Connect(function() fs.Color=C.line end)
local send=new("TextButton",{Size=UDim2.new(0,42,0,42),Position=UDim2.new(1,-50,0.5,-21),
	BackgroundColor3=C.accent,BorderSizePixel=0,AutoButtonColor=true,Text="▶",Font=F,TextSize=18,
	TextColor3=Color3.fromHex("1a0f02")},field)

-- ---------- logic ----------
local function selInst() return Selection:Get()[1] end
local function code_of(r)
	if not r then return nil end
	return r:match("```lua%s*\n(.-)```") or r:match("```luau%s*\n(.-)```") or r:match("```%s*\n(.-)```")
end
local function runLua(src)
	if loadstring then
		local fn=loadstring(src)
		if fn then return pcall(fn) end
	end
	local ms=Instance.new("ModuleScript")
	ms.Name="CortexRun"; ms.Source=src.."\nreturn true"
	ms.Parent=game:GetService("ServerStorage")
	local ok,res=pcall(require,ms); pcall(function() ms:Destroy() end)
	return ok,res
end
local function ask(system,text)
	local ok,res=pcall(function()
		return HttpService:RequestAsync({Url=BASE,Method="POST",
			Headers={["Content-Type"]="application/json",["Authorization"]="Bearer "..KEY},
			Body=HttpService:JSONEncode({system=system,text=text,tier=MODELS[mi][2]})})
	end)
	if not ok then return nil,"no HTTP — click Allow on the plugin's request" end
	if not res.Success then return nil,"gateway "..tostring(res.StatusCode) end
	local g,d=pcall(function() return HttpService:JSONDecode(res.Body) end)
	if not g then return nil,"bad response" end
	if d.error then return nil,tostring(type(d.error)=="table" and d.error.message or d.error) end
	return d.text
end

local busy=false
local function run()
	if busy then return end
	local req=box.Text
	if #req==0 then return end
	busy=true; box.Text=""; send.Text="…"
	line("▎ "..req, C.text)
	local s=selInst()
	local ctx = s and ("Selected: "..s:GetFullName().." ("..s.ClassName..")"..(s:IsA("LuaSourceContainer") and ("\nIts source:\n"..s.Source) or "")) or "Nothing is selected."
	line(MODELS[mi][3].." "..MODELS[mi][1].." working…", C.muted, 13)
	task.spawn(function()
		local system="You are Cortex, an AI that edits a Roblox place from inside Studio as a plugin. "
			.."Turn the user's request into a Luau snippet that performs it when run (create or modify Instances anywhere, "
			.."set properties, set a Script's .Source). Return ONLY Luau in one ```lua code block, no words outside it.\n\n"..ctx
		local reply,e=ask(system,req)
		if not reply then
			line("❌ "..tostring(e), C.err)
		else
			local code=code_of(reply)
			if code and #code>0 then
				local rec=CHS:TryBeginRecording("Cortex: "..req:sub(1,40))
				local ok,err=runLua(code)
				if rec then CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end
				if ok then line("✅ done — Ctrl+Z to undo", C.ok)
				else line("❌ error: "..tostring(err), C.err, 12) end
			else
				line(reply, C.sub)
			end
		end
		busy=false; send.Text="▶"
	end)
end
send.MouseButton1Click:Connect(run)

line("🤖 Cortex ready.", C.text, 15)
line("Tell me what to build. Try: create a red glowing part above spawn", C.sub)
if KEY:sub(1,4)~="osa-" then line("⚠ repo build — no key baked", C.accent) end
