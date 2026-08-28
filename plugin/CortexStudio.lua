--!nonstrict
--[[
	Cortex — AI terminal for Roblox Studio (Claude Code style)
	Type what you want, hit Enter. It turns it into Luau and runs it in your place.
	Undo with Ctrl+Z. No setup.
]]

-- Loaded and run by the Cortex loader as: return function(plugin, KEY) ... end
return function(plugin, KEY)

local HttpService = game:GetService("HttpService")
local Selection   = game:GetService("Selection")
local CHS         = game:GetService("ChangeHistoryService")

-- Прямой endpoint вала, а не osa-api.netlify.app: Netlify-прокси рубит на ~26с,
-- а reasoning-модели (Fable 5 / GPT-5.6 Sol) думают дольше. Прямой вал терпит.
local BASE = "https://alishergiyasov100boop--280269849ac811f18ca91607ee4eb77e.web.val.run/npc"

-- тёплый коричнево-чёрный, один янтарный акцент (стиль Claude Code)
local C = {
	bg="100c09", panel="17120d", rail="1e1710",
	text="e9e0d2", dim="9c8b76", faint="5f5140", line="2a2118",
	accent="d98a3d", accentD="a8794a", ok="a8c47f", err="d17a52", user="e0be82",
}
for k,v in pairs(C) do C[k]=Color3.fromHex(v) end
local F = Enum.Font.Code  -- моноширинный — терминал

-- hex-строки для RichText <font color>
local HEX = { accent="#d98a3d", ok="#a8c47f", dim="#9c8b76", faint="#5f5140",
	text="#e9e0d2", user="#e0be82", err="#d17a52" }

local MODELS = {
	{"Fable 5","fable-5","◍"},
	{"GPT-5.6 Sol","gpt-5.6-sol","◍"},
	{"Gemini 3","gemini-3-flash","◍"},
	{"Grok 4.2","grok-4.20-fast","◍"},
	{"DeepSeek V4","deepseek-v4-pro","◍"},
	{"Qwen 3.7","qwen3.7-plus","◍"},
}
local mi = 1

local function new(cls,props,parent)
	local o=Instance.new(cls); for k,v in pairs(props or {}) do o[k]=v end
	if parent then o.Parent=parent end; return o
end
local function pad(o,t,b,l,r) new("UIPadding",{PaddingTop=UDim.new(0,t),PaddingBottom=UDim.new(0,b or t),PaddingLeft=UDim.new(0,l or t),PaddingRight=UDim.new(0,r or l or t)},o) end
local function esc(s) return (tostring(s):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")) end

-- ── widget shell ────────────────────────────────────────────
local toolbar=plugin:CreateToolbar("Cortex")
local button=toolbar:CreateButton("Cortex","AI terminal","")
local info=DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right,true,false,420,600,320,420)
local widget=plugin:CreateDockWidgetPluginGui("CortexTerm_v1",info)
widget.Title="Cortex"
button.Click:Connect(function() widget.Enabled=not widget.Enabled end)

local root=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.bg,BorderSizePixel=0},widget)

-- top bar (минимальная)
local bar=new("Frame",{Size=UDim2.new(1,0,0,40),BackgroundColor3=C.panel,BorderSizePixel=0},root)
new("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=C.line,BorderSizePixel=0},bar)
new("TextLabel",{Size=UDim2.new(0,240,1,0),Position=UDim2.new(0,14,0,0),BackgroundTransparency=1,
	Font=F,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left,RichText=true,
	Text="<font color='"..HEX.accent.."'>✻</font>  <font color='"..HEX.text.."'>CORTEX</font>  <font color='"..HEX.faint.."'>studio</font>"},bar)
local modelBtn=new("TextButton",{Size=UDim2.new(0,116,0,26),Position=UDim2.new(1,-130,0.5,-13),
	BackgroundColor3=C.panel,BorderSizePixel=0,AutoButtonColor=false,Text=""},bar)
new("UICorner",{CornerRadius=UDim.new(0,5)},modelBtn)
new("UIStroke",{Color=C.line,Thickness=1},modelBtn)
local modelTxt=new("TextLabel",{Size=UDim2.new(1,-14,1,0),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,
	Font=F,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,RichText=true},modelBtn)
local function refM() modelTxt.Text="<font color='"..HEX.dim.."'>◍ </font><font color='"..HEX.user.."'>"..MODELS[mi][1].."</font><font color='"..HEX.faint.."'> ▾</font>" end; refM()
modelBtn.MouseButton1Click:Connect(function() mi=(mi%#MODELS)+1; refM() end)

-- log
local logF=new("ScrollingFrame",{Size=UDim2.new(1,0,1,-40-56),Position=UDim2.new(0,0,0,40),
	BackgroundColor3=C.bg,BorderSizePixel=0,ScrollBarThickness=5,ScrollBarImageColor3=C.line,
	CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y},root)
pad(logF,16,10,16,16)
local lay=new("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},logF)
local ord=0
local function scroll() task.defer(function() logF.CanvasPosition=Vector2.new(0,lay.AbsoluteContentSize.Y) end) end

-- одна строка (RichText); возвращает label чтобы можно было убрать (Thinking…)
local function line(rich,topGap)
	ord+=1
	local l=new("TextLabel",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,
		Font=F,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
		TextWrapped=true,RichText=true,Text=rich,LayoutOrder=ord},logF)
	if topGap then new("UIPadding",{PaddingTop=UDim.new(0,topGap)},l) end
	scroll(); return l
end

-- рамочный блок с кодом (⎿ … + левая полоса)
local function codeBlock(src)
	ord+=1
	local holder=new("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
		BackgroundColor3=C.rail,BorderSizePixel=0,LayoutOrder=ord},logF)
	new("UIPadding",{PaddingTop=UDim.new(0,6),PaddingBottom=UDim.new(0,6),PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,8)},holder)
	new("Frame",{Size=UDim2.new(0,2,1,0),BackgroundColor3=C.line,BorderSizePixel=0},holder)
	local lines=0; for _ in tostring(src):gmatch("\n") do lines+=1 end
	new("TextLabel",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,
		Font=F,TextSize=12,TextColor3=C.dim,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
		TextWrapped=true,Text=src},holder)
	scroll(); return holder
end

-- ── logic ───────────────────────────────────────────────────
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
			Headers={["Content-Type"]="application/json",["Authorization"]="Bearer "..KEY,["User-Agent"]="Roblox/Studio"},
			Body=HttpService:JSONEncode({system=system,text=text,tier=MODELS[mi][2]})})
	end)
	if not ok then return nil,"нет сети — нажми Allow на запрос плагина" end
	if not res.Success then return nil,"gateway "..tostring(res.StatusCode) end
	local g,d=pcall(function() return HttpService:JSONDecode(res.Body) end)
	if not g then return nil,"кривой ответ" end
	if d.error then return nil,tostring(type(d.error)=="table" and d.error.message or d.error) end
	return d.text
end

-- ── input row (prompt) ──────────────────────────────────────
local prow=new("Frame",{Size=UDim2.new(1,0,0,56),Position=UDim2.new(0,0,1,-56),BackgroundColor3=C.panel,BorderSizePixel=0},root)
new("Frame",{Size=UDim2.new(1,0,0,1),BackgroundColor3=C.line,BorderSizePixel=0},prow)
pad(prow,0,0,14,14)
new("TextLabel",{Size=UDim2.new(0,14,1,0),BackgroundTransparency=1,Font=F,TextSize=15,TextColor3=C.accent,
	Text="›",TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center},prow)
local box=new("TextBox",{Size=UDim2.new(1,-150,1,-16),Position=UDim2.new(0,20,0,8),BackgroundTransparency=1,
	TextColor3=C.text,PlaceholderColor3=C.faint,PlaceholderText="опиши, что построить…",
	Font=F,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
	ClearTextOnFocus=false,TextWrapped=true,Text=""},prow)
new("TextLabel",{Size=UDim2.new(0,120,1,0),Position=UDim2.new(1,-120,0,0),BackgroundTransparency=1,Font=F,TextSize=11,
	TextXAlignment=Enum.TextXAlignment.Right,TextYAlignment=Enum.TextYAlignment.Center,RichText=true,
	Text="<font color='"..HEX.faint.."'>Enter — </font><font color='"..HEX.accent.."'>запустить</font>"},prow)

local busy=false
local function run()
	if busy then return end
	local req=box.Text
	if #req==0 then return end
	busy=true; box.Text=""
	line("<font color='"..HEX.accent.."'>›</font> <font color='"..HEX.text.."'>"..esc(req).."</font>", 12)
	local s=selInst()
	local ctx = s and ("Selected: "..s:GetFullName().." ("..s.ClassName..")"..(s:IsA("LuaSourceContainer") and ("\nIts source:\n"..s.Source) or "")) or "Nothing is selected."
	local think=line("<font color='"..HEX.accent.."'>✻</font> <font color='"..HEX.dim.."'>Thinking…</font>", 6)
	task.spawn(function()
		local system="You are Cortex, an AI that edits a Roblox place from inside Studio as a plugin. "
			.."Turn the user's request into a Luau snippet that performs it when run (create or modify Instances anywhere, "
			.."set properties, set a Script's .Source). Return ONLY Luau in one ```lua code block, no words outside it.\n\n"..ctx
		local reply,e=ask(system,req)
		if think then think:Destroy() end
		if not reply then
			line("<font color='"..HEX.faint.."'>⎿</font> <font color='"..HEX.err.."'>"..esc(e).."</font>", 4)
		else
			local code=code_of(reply)
			if code and #code>0 then
				line("<font color='"..HEX.faint.."'>⎿</font> <font color='"..HEX.dim.."'>применяю Luau</font>", 4)
				codeBlock(code)
				local rec=CHS:TryBeginRecording("Cortex: "..req:sub(1,40))
				local ok,err=runLua(code)
				if rec then CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end
				if ok then line("<font color='"..HEX.ok.."'>✔ готово</font> <font color='"..HEX.faint.."'>· Ctrl+Z отменить</font>", 6)
				else line("<font color='"..HEX.err.."'>✗ ошибка:</font> <font color='"..HEX.dim.."'>"..esc(tostring(err)).."</font>", 4) end
			else
				line("<font color='"..HEX.dim.."'>"..esc(reply).."</font>", 4)
			end
		end
		busy=false
	end)
end
box.FocusLost:Connect(function(enter) if enter then run() end end)

-- boot
line("<font color='"..HEX.dim.."'>готов.</font> <font color='"..HEX.faint.."'>опиши, что построить — соберу и запущу прямо в место.</font>")
if KEY:sub(1,4)~="osa-" then line("<font color='"..HEX.accent.."'>⚠ repo build — ключ не вшит</font>", 6) end

end
