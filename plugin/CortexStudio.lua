--!nonstrict
--[[ Cortex — AI terminal for Roblox Studio. Config-driven, free+pro tiers. ]]
return function(plugin, KEY)

local HttpService = game:GetService("HttpService")
local Selection   = game:GetService("Selection")
local CHS         = game:GetService("ChangeHistoryService")

local ROOT = "https://alishergiyasov100boop--280269849ac811f18ca91607ee4eb77e.web.val.run"
local BASE = ROOT.."/npc"
local CFG_URL = "https://raw.githubusercontent.com/cortex-rbx/roblox-ai-kit/master/plugin/config.json"

-- ── config ──
local CFG = {
	title="CORTEX",
	colors={bg="000000",panel="17120d",text="e9e0d2",dim="9c8b76",faint="5f5140",line="2a2118",accent="b0b0b0",ok="00ff00",err="d17a52"},
	size={font=16,headerH=60,inputH=40,logPad=22,corner=20},
	show={studioTag=true,modelChip=true,hint=true,codeBlock=true,runHint=true},
}
pcall(function()
	local ext=HttpService:JSONDecode(HttpService:GetAsync(CFG_URL,true))
	for _,g in ipairs({"colors","size","show"}) do if type(ext[g])=="table" then for k,v in pairs(ext[g]) do CFG[g][k]=v end end end
	if type(ext.title)=="string" then CFG.title=ext.title end
end)

local C={}; for k,v in pairs(CFG.colors) do C[k]=Color3.fromHex(v) end
C.rail=C.rail or C.panel; C.accentD=C.accentD or C.accent:Lerp(C.bg,0.35); C.user=C.user or C.accent
local F=Enum.Font.Code
local WM=Enum.Font.GothamBold
local FS=CFG.size.font
local function hx(n) return "#"..CFG.colors[n] end
local hexA="#"..CFG.colors.accent
local LOGO="rbxassetid://129227232422535"  -- Cortex brain mark

local function new(cls,p,par) local o=Instance.new(cls); for k,v in pairs(p or {}) do o[k]=v end; if par then o.Parent=par end; return o end
local function esc(s) return (tostring(s):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")) end
local function httpJSON(method,url,key,body)
	local ok,res=pcall(function()
		local h={["Content-Type"]="application/json",["User-Agent"]="Roblox/Studio"}
		if key then h["Authorization"]="Bearer "..key end
		return HttpService:RequestAsync({Url=url,Method=method,Headers=h,Body=body and HttpService:JSONEncode(body) or nil})
	end)
	if not ok or not res.Success then return nil end
	local g,d=pcall(function() return HttpService:JSONDecode(res.Body) end)
	return g and d or nil
end

-- ── ключ + план ──
local key = (type(KEY)=="string" and KEY:sub(1,4)=="osa-") and KEY or plugin:GetSetting("cortex_key")
if type(key)~="string" or key:sub(1,4)~="osa-" then
	local d=httpJSON("POST",ROOT.."/shop/free",nil,{})
	if d and d.key then key=d.key; plugin:SetSetting("cortex_key",key) end
end
local PLAN="free"
do local b=httpJSON("GET",ROOT.."/v1/balance",key); if b and b.plan then PLAN=b.plan end end

local ALL={ {"OSA Ultra","osa-ultra"},{"OSA Fast","osa-fast"},{"Fable 5","fable-5"},
	{"Opus 4.8","claude-opus-4-8"},{"Sonnet 5","claude-sonnet-5"},{"GPT-5","gpt-5"},
	{"DeepSeek V4","deepseek-v4-pro"},{"Qwen 3.7","qwen3.7-plus"},{"Doubao","doubao"},
	{"Grok 4","grok-4"},{"GLM 5","glm-5"},{"Llama 3.3","llama-3.3-70b"},{"MiniMax","minimax"},{"Mistral","mistral-large"} }
local FREE={["osa-fast"]=true,["qwen3.7-plus"]=true,["deepseek-v4-pro"]=true}
local MODELS={}
if PLAN=="pro" then MODELS=ALL else for _,m in ipairs(ALL) do if FREE[m[2]] then table.insert(MODELS,m) end end end
if #MODELS==0 then MODELS={{"OSA Fast","osa-fast"}} end
local mi=1

-- ── widget ──
local toolbar=plugin:CreateToolbar("Cortex")
local button=toolbar:CreateButton("Cortex","AI terminal","")
local info=DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right,true,false,420,600,320,420)
local widget=plugin:CreateDockWidgetPluginGui("CortexTerm_v3",info); widget.Title="Cortex"
button.Click:Connect(function() widget.Enabled=not widget.Enabled end)
local root=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.bg,BorderSizePixel=0,ClipsDescendants=true},widget)
if (CFG.size.corner or 0)>0 then new("UICorner",{CornerRadius=UDim.new(0,CFG.size.corner)},root) end

-- ── header: 3 кружка слева · модель по центру · CORTEX code справа ──
local HH=CFG.size.headerH
local bar=new("Frame",{Size=UDim2.new(1,0,0,HH),BackgroundColor3=C.panel,BorderSizePixel=0},root)
new("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=C.line,BorderSizePixel=0},bar)
local dots={Color3.fromHex("6fae57"),Color3.fromHex("e05650"),Color3.fromHex("4a9eff")}
for i,col in ipairs(dots) do
	local d=new("Frame",{Size=UDim2.new(0,12,0,12),Position=UDim2.new(0,14+(i-1)*18,0.5,-6),BackgroundColor3=col,BorderSizePixel=0},bar)
	new("UICorner",{CornerRadius=UDim.new(1,0)},d)
end
-- CORTEX code (справа)
local wm=new("Frame",{Size=UDim2.new(0,150,1,0),Position=UDim2.new(1,-160,0,0),BackgroundTransparency=1},bar)
new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Right,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,6)},wm)
new("TextLabel",{BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,0,20),Font=WM,TextSize=17,TextColor3=C.text,Text=CFG.title,LayoutOrder=1},wm)
new("TextLabel",{BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,0,16),Font=F,TextSize=12,TextColor3=C.accent,Text="code",LayoutOrder=2},wm)
-- модель (по центру), кликается
local modelBtn=new("TextButton",{Size=UDim2.new(0,120,0,26),Position=UDim2.new(0.5,-60,0.5,-13),BackgroundColor3=C.bg,BorderSizePixel=0,AutoButtonColor=false,Text=""},bar)
new("UICorner",{CornerRadius=UDim.new(0,6)},modelBtn); new("UIStroke",{Color=C.line,Thickness=1},modelBtn)
local modelTxt=new("TextLabel",{Size=UDim2.new(1,-14,1,0),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,Font=F,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,RichText=true},modelBtn)
local function refM() modelTxt.Text="<font color='"..hx("dim").."'>◍ </font><font color='"..hx("accent").."'>"..MODELS[mi][1].."</font><font color='"..hx("faint").."'> ▾</font>" end; refM()
modelBtn.MouseButton1Click:Connect(function() mi=(mi%#MODELS)+1; refM() end)

-- ── log ──
local IH=CFG.size.inputH
local logF=new("ScrollingFrame",{Size=UDim2.new(1,0,1,-HH-IH),Position=UDim2.new(0,0,0,HH),BackgroundColor3=C.bg,BorderSizePixel=0,ScrollBarThickness=5,ScrollBarImageColor3=C.line,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y},root)
new("UIPadding",{PaddingTop=UDim.new(0,CFG.size.logPad),PaddingBottom=UDim.new(0,10),PaddingLeft=UDim.new(0,CFG.size.logPad),PaddingRight=UDim.new(0,CFG.size.logPad)},logF)
local lay=new("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},logF)
local ord=0
local function scroll() task.defer(function() logF.CanvasPosition=Vector2.new(0,lay.AbsoluteContentSize.Y) end) end
local function line(rich,gap)
	ord+=1
	local l=new("TextLabel",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Font=F,TextSize=FS,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,RichText=true,Text=rich,LayoutOrder=ord},logF)
	if gap then new("UIPadding",{PaddingTop=UDim.new(0,gap)},l) end
	scroll(); return l
end
local function codeBlock(src)
	if not CFG.show.codeBlock then return end
	ord+=1
	local h=new("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=C.rail,BorderSizePixel=0,LayoutOrder=ord},logF)
	new("UICorner",{CornerRadius=UDim.new(0,6)},h)
	new("UIPadding",{PaddingTop=UDim.new(0,6),PaddingBottom=UDim.new(0,6),PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,8)},h)
	new("Frame",{Size=UDim2.new(0,2,1,0),BackgroundColor3=C.line,BorderSizePixel=0},h)
	new("TextLabel",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Font=F,TextSize=FS-2,TextColor3=C.dim,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,Text=src},h)
	scroll()
end
local function thinkLine()
	ord+=1
	local h=new("Frame",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,LayoutOrder=ord},logF)
	new("UIPadding",{PaddingTop=UDim.new(0,6)},h)
	new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,7)},h)
	new("ImageLabel",{BackgroundTransparency=1,Size=UDim2.new(0,15,0,15),Image=LOGO,ScaleType=Enum.ScaleType.Fit,LayoutOrder=1},h)
	new("TextLabel",{BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,0,16),Font=F,TextSize=FS,TextColor3=C.dim,Text="Thinking…",LayoutOrder=2},h)
	scroll(); return h
end

-- ── splash (пустая сессия) ──
local splash=new("Frame",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,ZIndex=5},logF)
do
	local col=new("Frame",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1},splash)
	new("UIListLayout",{FillDirection=Enum.FillDirection.Vertical,HorizontalAlignment=Enum.HorizontalAlignment.Center,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,6)},col)
	new("ImageLabel",{BackgroundTransparency=1,Size=UDim2.new(0,76,0,76),Image=LOGO,ScaleType=Enum.ScaleType.Fit,LayoutOrder=1},col)
	new("TextLabel",{BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.XY,Font=WM,TextSize=18,TextColor3=C.text,Text=CFG.title,LayoutOrder=2},col)
	new("TextLabel",{BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.XY,Font=F,TextSize=13,TextColor3=C.dim,Text="опиши, что построить",LayoutOrder=3},col)
	if PLAN~="pro" then
		new("TextLabel",{BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.XY,Font=F,TextSize=12,TextColor3=C.faint,Text="Free · 15 сообщений/день · 3 модели",LayoutOrder=4},col)
	end
end

-- ── logic ──
local function selInst() return Selection:Get()[1] end
local function code_of(r) if not r then return nil end; return r:match("```lua%s*\n(.-)```") or r:match("```luau%s*\n(.-)```") or r:match("```%s*\n(.-)```") end
local function runLua(src)
	if loadstring then local fn=loadstring(src); if fn then return pcall(fn) end end
	local ms=Instance.new("ModuleScript"); ms.Name="CortexRun"; ms.Source=src.."\nreturn true"; ms.Parent=game:GetService("ServerStorage")
	local ok,res=pcall(require,ms); pcall(function() ms:Destroy() end); return ok,res
end
local function ask(system,text)
	local d=httpJSON("POST",BASE,key,{system=system,text=text,tier=MODELS[mi][2]})
	if not d then return nil,"нет сети — нажми Allow на запрос" end
	if d.error then return nil,tostring(type(d.error)=="table" and d.error.message or d.error) end
	return d.text
end

-- ── input ──
local prow=new("Frame",{Size=UDim2.new(1,0,0,IH),Position=UDim2.new(0,0,1,-IH),BackgroundColor3=C.panel,BorderSizePixel=0},root)
new("Frame",{Size=UDim2.new(1,0,0,1),BackgroundColor3=C.line,BorderSizePixel=0},prow)
new("UIPadding",{PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14)},prow)
new("TextLabel",{Size=UDim2.new(0,14,1,0),BackgroundTransparency=1,Font=F,TextSize=FS+1,TextColor3=C.accent,Text="›",TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center},prow)
local rightW=CFG.show.runHint and 150 or 20
local boxx=new("TextBox",{Size=UDim2.new(1,-6-rightW,1,-14),Position=UDim2.new(0,20,0,7),BackgroundTransparency=1,TextColor3=C.text,PlaceholderColor3=C.faint,PlaceholderText="опиши, что построить…",Font=F,TextSize=FS,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,ClearTextOnFocus=false,TextWrapped=true,Text=""},prow)
if CFG.show.runHint then
	new("TextLabel",{Size=UDim2.new(0,120,1,0),Position=UDim2.new(1,-120,0,0),BackgroundTransparency=1,Font=F,TextSize=11,TextXAlignment=Enum.TextXAlignment.Right,TextYAlignment=Enum.TextYAlignment.Center,RichText=true,Text="<font color='"..hx("faint").."'>Enter — </font><font color='"..hexA.."'>run</font>"},prow)
end

local started=false
local busy=false
local function run()
	if busy then return end
	local req=boxx.Text; if #req==0 then return end
	if not started then started=true; if splash then splash:Destroy(); splash=nil end end
	busy=true; boxx.Text=""
	line("<font color='"..hexA.."'>›</font> <font color='"..hx("text").."'>"..esc(req).."</font>", 12)
	local s=selInst()
	local ctx=s and ("Selected: "..s:GetFullName().." ("..s.ClassName..")"..(s:IsA("LuaSourceContainer") and ("\nIts source:\n"..s.Source) or "")) or "Nothing is selected."
	local think=thinkLine()
	task.spawn(function()
		local system="You are Cortex, an AI that edits a Roblox place from inside Studio as a plugin. Turn the user's request into a Luau snippet that performs it when run. Return ONLY Luau in one ```lua code block, no words outside it.\n\n"..ctx
		local reply,e=ask(system,req)
		if think then think:Destroy() end
		if not reply then
			line("<font color='"..hx("faint").."'>⎿</font> <font color='"..hx("err").."'>"..esc(e).."</font>", 4)
			if tostring(e):find("Pro") then line("<font color='"..hexA.."'>🔒 апгрейд на Pro открывает все 12 моделей + OSA Ultra</font>", 4) end
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
boxx.FocusLost:Connect(function(enter) if enter then run() end end)

end
