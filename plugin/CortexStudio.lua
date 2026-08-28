--!nonstrict
--[[
	Cortex — AI terminal for Roblox Studio. Config-driven.
	Вид/раскладка/элементы читаются из config.json в репо — правь его, плагин
	подхватит на следующем запуске. Логика (гейтвей, запуск кода, Undo) в коде.
]]
return function(plugin, KEY)

local HttpService = game:GetService("HttpService")
local Selection   = game:GetService("Selection")
local CHS         = game:GetService("ChangeHistoryService")

local BASE = "https://alishergiyasov100boop--280269849ac811f18ca91607ee4eb77e.web.val.run/npc"
local CFG_URL = "https://raw.githubusercontent.com/cortex-rbx/roblox-ai-kit/master/plugin/config.json"

-- ── дефолтный конфиг (переопределяется config.json) ──
local CFG = {
	title = "CORTEX",
	colors = { bg="000000", panel="17120d", text="e9e0d2", dim="9c8b76",
		faint="5f5140", line="2a2118", accent="ffffff", ok="00ff00", err="d17a52" },
	size = { font=14, headerH=40, inputH=56, logPad=16, corner=8 },
	show = { studioTag=true, modelChip=true, hint=true, codeBlock=true, runHint=true },
}

-- подтянуть config.json и слить поверх дефолтов
pcall(function()
	local raw = HttpService:GetAsync(CFG_URL, true)
	local ext = HttpService:JSONDecode(raw)
	for _,grp in ipairs({"colors","size","show"}) do
		if type(ext[grp])=="table" then
			for k,v in pairs(ext[grp]) do CFG[grp][k]=v end
		end
	end
	if type(ext.title)=="string" then CFG.title=ext.title end
end)

-- палитра
local C = {}
for k,v in pairs(CFG.colors) do C[k]=Color3.fromHex(v) end
C.rail    = C.rail    or C.panel
C.accentD = C.accentD or C.accent:Lerp(C.bg, 0.35)
C.user    = C.user    or C.accent
local F  = Enum.Font.Code
local FS = CFG.size.font
local hexA = "#"..CFG.colors.accent
local function hx(name) return "#"..CFG.colors[name] end

local MODELS = {
	{"Fable 5","fable-5"},{"Opus 4.8","claude-opus-4-8"},{"Sonnet 5","claude-sonnet-5"},
	{"GPT-5","gpt-5"},{"DeepSeek V4","deepseek-v4-pro"},{"Qwen 3.7","qwen3.7-plus"},
	{"Doubao","doubao"},{"Grok 4","grok-4"},{"GLM 5","glm-5"},
	{"Llama 3.3","llama-3.3-70b"},{"MiniMax","minimax"},{"Mistral","mistral-large"},
}
local mi = 1

local function new(cls,props,parent)
	local o=Instance.new(cls); for k,v in pairs(props or {}) do o[k]=v end
	if parent then o.Parent=parent end; return o
end
local function esc(s) return (tostring(s):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")) end

-- ── widget ──
local toolbar=plugin:CreateToolbar("Cortex")
local button=toolbar:CreateButton("Cortex","AI terminal","")
local info=DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right,true,false,420,600,320,420)
local widget=plugin:CreateDockWidgetPluginGui("CortexTerm_v2",info)
widget.Title="Cortex"
button.Click:Connect(function() widget.Enabled=not widget.Enabled end)

local root=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.bg,BorderSizePixel=0,ClipsDescendants=true},widget)
if (CFG.size.corner or 0) > 0 then new("UICorner",{CornerRadius=UDim.new(0,CFG.size.corner)},root) end

-- top bar
local HH=CFG.size.headerH
local bar=new("Frame",{Size=UDim2.new(1,0,0,HH),BackgroundColor3=C.panel,BorderSizePixel=0},root)
new("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=C.line,BorderSizePixel=0},bar)
local head=CFG.show.studioTag
	and "<font color='"..hexA.."'>✻</font>  <font color='"..hx("text").."'>"..esc(CFG.title).."</font>  <font color='"..hx("faint").."'>studio</font>"
	or  "<font color='"..hexA.."'>✻</font>  <font color='"..hx("text").."'>"..esc(CFG.title).."</font>"
new("TextLabel",{Size=UDim2.new(0,260,1,0),Position=UDim2.new(0,14,0,0),BackgroundTransparency=1,
	Font=F,TextSize=FS,TextXAlignment=Enum.TextXAlignment.Left,RichText=true,Text=head},bar)
if CFG.show.modelChip then
	local modelBtn=new("TextButton",{Size=UDim2.new(0,116,0,26),Position=UDim2.new(1,-130,0.5,-13),
		BackgroundColor3=C.panel,BorderSizePixel=0,AutoButtonColor=false,Text=""},bar)
	new("UICorner",{CornerRadius=UDim.new(0,5)},modelBtn)
	new("UIStroke",{Color=C.line,Thickness=1},modelBtn)
	local modelTxt=new("TextLabel",{Size=UDim2.new(1,-14,1,0),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,
		Font=F,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,RichText=true},modelBtn)
	local function refM() modelTxt.Text="<font color='"..hx("dim").."'>◍ </font><font color='"..hx("accent").."'>"..MODELS[mi][1].."</font><font color='"..hx("faint").."'> ▾</font>" end; refM()
	modelBtn.MouseButton1Click:Connect(function() mi=(mi%#MODELS)+1; refM() end)
end

-- log
local IH=CFG.size.inputH
local logF=new("ScrollingFrame",{Size=UDim2.new(1,0,1,-HH-IH),Position=UDim2.new(0,0,0,HH),
	BackgroundColor3=C.bg,BorderSizePixel=0,ScrollBarThickness=5,ScrollBarImageColor3=C.line,
	CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y},root)
new("UIPadding",{PaddingTop=UDim.new(0,CFG.size.logPad),PaddingBottom=UDim.new(0,10),PaddingLeft=UDim.new(0,CFG.size.logPad),PaddingRight=UDim.new(0,CFG.size.logPad)},logF)
local lay=new("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},logF)
local ord=0
local function scroll() task.defer(function() logF.CanvasPosition=Vector2.new(0,lay.AbsoluteContentSize.Y) end) end
local function line(rich,gap)
	ord+=1
	local l=new("TextLabel",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,
		Font=F,TextSize=FS,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
		TextWrapped=true,RichText=true,Text=rich,LayoutOrder=ord},logF)
	if gap then new("UIPadding",{PaddingTop=UDim.new(0,gap)},l) end
	scroll(); return l
end
local function codeBlock(src)
	if not CFG.show.codeBlock then return end
	ord+=1
	local holder=new("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
		BackgroundColor3=C.rail,BorderSizePixel=0,LayoutOrder=ord},logF)
	new("UIPadding",{PaddingTop=UDim.new(0,6),PaddingBottom=UDim.new(0,6),PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,8)},holder)
	new("Frame",{Size=UDim2.new(0,2,1,0),BackgroundColor3=C.line,BorderSizePixel=0},holder)
	new("TextLabel",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,
		Font=F,TextSize=FS-2,TextColor3=C.dim,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
		TextWrapped=true,Text=src},holder)
	scroll()
end

-- logic
local function selInst() return Selection:Get()[1] end
local function code_of(r)
	if not r then return nil end
	return r:match("```lua%s*\n(.-)```") or r:match("```luau%s*\n(.-)```") or r:match("```%s*\n(.-)```")
end
local function runLua(src)
	if loadstring then local fn=loadstring(src); if fn then return pcall(fn) end end
	local ms=Instance.new("ModuleScript"); ms.Name="CortexRun"; ms.Source=src.."\nreturn true"
	ms.Parent=game:GetService("ServerStorage")
	local ok,res=pcall(require,ms); pcall(function() ms:Destroy() end); return ok,res
end
local function ask(system,text)
	local ok,res=pcall(function()
		return HttpService:RequestAsync({Url=BASE,Method="POST",
			Headers={["Content-Type"]="application/json",["Authorization"]="Bearer "..KEY,["User-Agent"]="Roblox/Studio"},
			Body=HttpService:JSONEncode({system=system,text=text,tier=MODELS[mi][2]})})
	end)
	if not ok then return nil,"нет сети — нажми Allow" end
	if not res.Success then return nil,"gateway "..tostring(res.StatusCode) end
	local g,d=pcall(function() return HttpService:JSONDecode(res.Body) end)
	if not g then return nil,"кривой ответ" end
	if d.error then return nil,tostring(type(d.error)=="table" and d.error.message or d.error) end
	return d.text
end

-- input row
local prow=new("Frame",{Size=UDim2.new(1,0,0,IH),Position=UDim2.new(0,0,1,-IH),BackgroundColor3=C.panel,BorderSizePixel=0},root)
new("Frame",{Size=UDim2.new(1,0,0,1),BackgroundColor3=C.line,BorderSizePixel=0},prow)
new("UIPadding",{PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14)},prow)
new("TextLabel",{Size=UDim2.new(0,14,1,0),BackgroundTransparency=1,Font=F,TextSize=FS+1,TextColor3=C.accent,
	Text="›",TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center},prow)
local rightW = CFG.show.runHint and 150 or 20
local box=new("TextBox",{Size=UDim2.new(1,-6-rightW,1,-16),Position=UDim2.new(0,20,0,8),BackgroundTransparency=1,
	TextColor3=C.text,PlaceholderColor3=C.faint,PlaceholderText="опиши, что построить…",
	Font=F,TextSize=FS,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
	ClearTextOnFocus=false,TextWrapped=true,Text=""},prow)
if CFG.show.runHint then
	new("TextLabel",{Size=UDim2.new(0,120,1,0),Position=UDim2.new(1,-120,0,0),BackgroundTransparency=1,Font=F,TextSize=11,
		TextXAlignment=Enum.TextXAlignment.Right,TextYAlignment=Enum.TextYAlignment.Center,RichText=true,
		Text="<font color='"..hx("faint").."'>Enter — </font><font color='"..hexA.."'>запустить</font>"},prow)
end

local busy=false
local function run()
	if busy then return end
	local req=box.Text; if #req==0 then return end
	busy=true; box.Text=""
	line("<font color='"..hexA.."'>›</font> <font color='"..hx("text").."'>"..esc(req).."</font>", 12)
	local s=selInst()
	local ctx = s and ("Selected: "..s:GetFullName().." ("..s.ClassName..")"..(s:IsA("LuaSourceContainer") and ("\nIts source:\n"..s.Source) or "")) or "Nothing is selected."
	local think=line("<font color='"..hexA.."'>✻</font> <font color='"..hx("dim").."'>Thinking…</font>", 6)
	task.spawn(function()
		local system="You are Cortex, an AI that edits a Roblox place from inside Studio as a plugin. "
			.."Turn the user's request into a Luau snippet that performs it when run. "
			.."Return ONLY Luau in one ```lua code block, no words outside it.\n\n"..ctx
		local reply,e=ask(system,req)
		if think then think:Destroy() end
		if not reply then
			line("<font color='"..hx("faint").."'>⎿</font> <font color='"..hx("err").."'>"..esc(e).."</font>", 4)
		else
			local code=code_of(reply)
			if code and #code>0 then
				line("<font color='"..hx("faint").."'>⎿</font> <font color='"..hx("dim").."'>применяю Luau</font>", 4)
				codeBlock(code)
				local rec=CHS:TryBeginRecording("Cortex: "..req:sub(1,40))
				local ok,err=runLua(code)
				if rec then CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end
				if ok then line("<font color='"..hx("ok").."'>✔ готово</font> <font color='"..hx("faint").."'>· Ctrl+Z</font>", 6)
				else line("<font color='"..hx("err").."'>✗ ошибка:</font> <font color='"..hx("dim").."'>"..esc(tostring(err)).."</font>", 4) end
			else
				line("<font color='"..hx("dim").."'>"..esc(reply).."</font>", 4)
			end
		end
		busy=false
	end)
end
box.FocusLost:Connect(function(enter) if enter then run() end end)

-- boot
if CFG.show.hint then
	line("<font color='"..hx("dim").."'>готов.</font> <font color='"..hx("faint").."'>опиши, что построить — соберу и запущу прямо в место.</font>")
else
	line("<font color='"..hx("dim").."'>готов.</font>")
end
if KEY:sub(1,4)~="osa-" then line("<font color='"..hexA.."'>⚠ repo build — ключ не вшит</font>", 6) end

end
