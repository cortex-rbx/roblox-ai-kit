--!nonstrict
--[[ Cortex — AI terminal for Roblox Studio. Config-driven, free/pro, chats. ]]
return function(plugin, KEY)

local HttpService = game:GetService("HttpService")
local Selection   = game:GetService("Selection")
local CHS         = game:GetService("ChangeHistoryService")
local Tween       = game:GetService("TweenService")
-- Плагины в Studio могут сами включить HTTP — чтобы юзеру не лезть в Game Settings.
pcall(function() HttpService.HttpEnabled = true end)

local ROOT = "https://alishergiyasov100boop--280269849ac811f18ca91607ee4eb77e.web.val.run"
local BASE = ROOT.."/npc"
local CFG_URL = "https://raw.githubusercontent.com/cortex-rbx/roblox-ai-kit/master/plugin/config.json"
local SYSTEM = "You are Cortex, an AI that edits a Roblox place from inside Studio as a plugin. Turn the user's request into a Luau snippet that performs it when run. Return ONLY Luau in one ```lua code block, no words outside it."

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
C.hover=C.bg:Lerp(C.panel,0.55)
local RAD=CFG.size.corner or 0
local F=Enum.Font.Code
local WM=Enum.Font.GothamBold
local FS=CFG.size.font
local function hx(n) return "#"..CFG.colors[n] end
local hexA="#"..CFG.colors.accent
local LOGO="rbxassetid://129227232422535"

local function new(cls,p,par) local o=Instance.new(cls); for k,v in pairs(p or {}) do o[k]=v end; if par then o.Parent=par end; return o end
local function esc(s) return (tostring(s):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")) end
-- ── motion (Apple-smooth: soft ease-out) ──
local SOFT=TweenInfo.new(0.34,Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
local SNAP=TweenInfo.new(0.14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
local PULSE=TweenInfo.new(0.85,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true)
local function tw(o,info,props) local t=Tween:Create(o,info,props); t:Play(); return t end
-- element enters with a soft fade + settle-down; kind: "text" | "frame"
-- pop: temp UIScale that self-destructs on finish, so text renders crisp at rest
local function pop(o,from,info)
	local sc=new("UIScale",{Scale=from},o)
	tw(sc,info or SOFT,{Scale=1}).Completed:Connect(function() sc:Destroy() end)
end
local function enter(o,kind,fade)
	pop(o,0.99)
	if kind=="text" then o.TextTransparency=1; tw(o,SOFT,{TextTransparency=fade or 0})
	elseif kind=="frame" then o.BackgroundTransparency=1; tw(o,SOFT,{BackgroundTransparency=fade or 0}) end
end
local function httpJSON(method,url,key,body)
	local ok,res=pcall(function()
		local h={["Content-Type"]="application/json",["User-Agent"]="Roblox/Studio"}
		if key then h["Authorization"]="Bearer "..key end
		return HttpService:RequestAsync({Url=url,Method=method,Headers=h,Body=body and HttpService:JSONEncode(body) or nil})
	end)
	if not ok then return nil, tostring(res) end
	if not res.Success then return nil, (res.Body~="" and res.Body) or ("HTTP "..tostring(res.StatusCode)) end
	local g,d=pcall(function() return HttpService:JSONDecode(res.Body) end)
	if not g then return nil, "bad json" end
	return d
end

-- ── key + plan + limits ──
local key = (type(KEY)=="string" and KEY:sub(1,4)=="osa-") and KEY or plugin:GetSetting("cortex_key")
if type(key)~="string" or key:sub(1,4)~="osa-" then
	local d=httpJSON("POST",ROOT.."/shop/free",nil,{})
	if d and d.key then key=d.key; plugin:SetSetting("cortex_key",key) end
end
local PLAN,usedToday,DAILY,unitsLeft="free",0,15,0
do local b=httpJSON("GET",ROOT.."/v1/balance",key)
	if b then PLAN=b.plan or "free"; usedToday=b.msgs_today or 0; DAILY=b.daily or 15; unitsLeft=b.units_left or 0 end
end

local L={ cortex="129227232422535",claude="119672220329569",gpt="75948684097269",
	deepseek="87294705657934",qwen="110320732028053",doubao="81749567095455",
	grok="79089215554482",glm="76066601672091",llama="87203537265732",
	minimax="96077423727438",mistral="88824165054695",gemini="118291541782496" }
local ALL={ {"OSA Ultra","osa-ultra",L.cortex},{"OSA Fast","osa-fast",L.cortex},{"Claude","claude",L.claude},{"Fable 5","fable-5",L.claude},
	{"Opus 4.8","claude-opus-4-8",L.claude},{"Sonnet 5","claude-sonnet-5",L.claude},{"GPT-5","gpt-5",L.gpt},
	{"DeepSeek V4","deepseek-v4-pro",L.deepseek},{"Qwen 3.7","qwen3.7-plus",L.qwen},{"Doubao","doubao",L.doubao},
	{"Grok 4","grok-4",L.grok},{"Llama 3.3","llama-3.3-70b",L.llama},{"MiniMax","minimax",L.minimax},{"Mistral","mistral-large",L.mistral} }
-- GLM 5 временно убран из линейки: таймаутит с облачного IP Val.town, вернём после cloud-надёжного хоста
local FREE={["osa-fast"]=true,["qwen3.7-plus"]=true,["deepseek-v4-pro"]=true}
local MODELS={}
if PLAN=="pro" then MODELS=ALL else for _,m in ipairs(ALL) do if FREE[m[2]] then table.insert(MODELS,m) end end end
if #MODELS==0 then MODELS={{"OSA Fast","osa-fast",L.cortex}} end
local mi=1

-- ── widget ──
local toolbar=plugin:CreateToolbar("Cortex")
local button=toolbar:CreateButton("Cortex","AI terminal","")
local info=DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right,true,false,420,600,320,420)
local widget=plugin:CreateDockWidgetPluginGui("CortexTerm_v4",info); widget.Title="Cortex"
local root=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.bg,BorderSizePixel=0,ClipsDescendants=true},widget)
if RAD>0 then new("UICorner",{CornerRadius=UDim.new(0,RAD)},root) end
button.Click:Connect(function()
	widget.Enabled=not widget.Enabled
	if widget.Enabled then pop(root,0.985) end
end)

-- ── header ──
local HH=CFG.size.headerH
local bar=new("Frame",{Size=UDim2.new(1,0,0,HH),BackgroundColor3=C.panel,BorderSizePixel=0},root)
if RAD>0 then new("UICorner",{CornerRadius=UDim.new(0,RAD)},bar)
	new("Frame",{Size=UDim2.new(1,0,0,RAD),Position=UDim2.new(0,0,1,-RAD),BackgroundColor3=C.panel,BorderSizePixel=0,ZIndex=0},bar) end
new("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=C.line,BorderSizePixel=0},bar)
for i,col in ipairs({"6fae57","e05650","4a9eff"}) do
	local d=new("Frame",{Size=UDim2.new(0,12,0,12),Position=UDim2.new(0,14+(i-1)*18,0.5,-6),BackgroundColor3=Color3.fromHex(col),BorderSizePixel=0},bar)
	new("UICorner",{CornerRadius=UDim.new(1,0)},d)
end
local wm=new("Frame",{Size=UDim2.new(0,150,1,0),Position=UDim2.new(1,-160,0,0),BackgroundTransparency=1},bar)
new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Right,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,6)},wm)
new("TextLabel",{BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,0,20),Font=WM,TextSize=17,TextColor3=C.text,Text=CFG.title,LayoutOrder=1},wm)
new("TextLabel",{BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,0,16),Font=F,TextSize=12,TextColor3=C.accent,Text="code",LayoutOrder=2},wm)
local modelBtn=new("TextButton",{AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,0,26),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),BackgroundColor3=C.bg,BorderSizePixel=0,AutoButtonColor=false,Text=""},bar)
new("UICorner",{CornerRadius=UDim.new(0,8)},modelBtn)
local mStroke=new("UIStroke",{Color=C.line,Thickness=1},modelBtn)
new("UIPadding",{PaddingLeft=UDim.new(0,9),PaddingRight=UDim.new(0,9)},modelBtn)
new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,6)},modelBtn)
local mLogo=new("ImageLabel",{Size=UDim2.new(0,15,0,15),BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit,LayoutOrder=1},modelBtn)
local mName=new("TextLabel",{AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,0,16),BackgroundTransparency=1,Font=F,TextSize=12,TextColor3=C.accent,LayoutOrder=2},modelBtn)
new("TextLabel",{AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,0,16),BackgroundTransparency=1,Font=F,TextSize=12,TextColor3=C.faint,Text="▾",LayoutOrder=3},modelBtn)
local function refM() mLogo.Image="rbxassetid://"..MODELS[mi][3]; mName.Text=MODELS[mi][1] end; refM()
modelBtn.MouseEnter:Connect(function() tw(modelBtn,SNAP,{BackgroundColor3=C.hover}); tw(mStroke,SNAP,{Color=C.accentD}) end)
modelBtn.MouseLeave:Connect(function() tw(modelBtn,SNAP,{BackgroundColor3=C.bg}); tw(mStroke,SNAP,{Color=C.line}) end)
modelBtn.MouseButton1Click:Connect(function()
	mi=(mi%#MODELS)+1
	pop(modelBtn,0.92)
	tw(mLogo,SNAP,{ImageTransparency=1}); tw(mName,SNAP,{TextTransparency=1})
	task.delay(0.14,function() refM(); tw(mLogo,SNAP,{ImageTransparency=0}); tw(mName,SNAP,{TextTransparency=0}) end)
end)

-- ── chats bar ──
local CB=30
local cbar=new("Frame",{Size=UDim2.new(1,0,0,CB),Position=UDim2.new(0,0,0,HH),BackgroundColor3=C.bg,BorderSizePixel=0},root)
new("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,0),BackgroundColor3=C.line,BorderSizePixel=0},cbar)
local tabsHold=new("ScrollingFrame",{Size=UDim2.new(1,-90,1,0),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollingDirection=Enum.ScrollingDirection.X},cbar)
new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,6)},tabsHold)
local limitTxt=new("TextLabel",{Size=UDim2.new(0,80,1,0),Position=UDim2.new(1,-84,0,0),BackgroundTransparency=1,Font=F,TextSize=11,TextXAlignment=Enum.TextXAlignment.Right,TextYAlignment=Enum.TextYAlignment.Center,RichText=true},cbar)
local function refLimit()
	if PLAN=="pro" then limitTxt.Text="<font color='"..hx("ok").."'>Pro ∞</font>"
	else
		local col=usedToday>=DAILY and hx("err") or (usedToday>=DAILY-3 and "#d98a3d" or hx("dim"))
		limitTxt.Text="<font color='"..col.."'>"..usedToday.."/"..DAILY.."</font>"
	end
end; refLimit()

-- ── log ──
local IH=CFG.size.inputH
local logF=new("ScrollingFrame",{Size=UDim2.new(1,0,1,-HH-CB-IH),Position=UDim2.new(0,0,0,HH+CB),BackgroundColor3=C.bg,BorderSizePixel=0,ScrollBarThickness=5,ScrollBarImageColor3=C.line,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y},root)
new("UIPadding",{PaddingTop=UDim.new(0,CFG.size.logPad),PaddingBottom=UDim.new(0,10),PaddingLeft=UDim.new(0,CFG.size.logPad),PaddingRight=UDim.new(0,CFG.size.logPad)},logF)
local lay=new("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},logF)
local content={}
local ord=0
local function scroll() task.defer(function() tw(logF,SNAP,{CanvasPosition=Vector2.new(0,lay.AbsoluteContentSize.Y)}) end) end
local function line(rich,gap)
	ord+=1
	local l=new("TextLabel",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Font=F,TextSize=FS,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,RichText=true,Text=rich,LayoutOrder=ord},logF)
	if gap then new("UIPadding",{PaddingTop=UDim.new(0,gap)},l) end
	enter(l,"text")
	table.insert(content,l); scroll(); return l
end
local function codeBlock(src)
	if not CFG.show.codeBlock then return end
	ord+=1
	local h=new("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=C.rail,BorderSizePixel=0,LayoutOrder=ord},logF)
	new("UICorner",{CornerRadius=UDim.new(0,6)},h)
	new("UIPadding",{PaddingTop=UDim.new(0,6),PaddingBottom=UDim.new(0,6),PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,8)},h)
	new("Frame",{Size=UDim2.new(0,2,1,0),BackgroundColor3=C.line,BorderSizePixel=0},h)
	local tl=new("TextLabel",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Font=F,TextSize=FS-2,TextColor3=C.dim,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,Text=src},h)
	enter(h,"frame"); tl.TextTransparency=1; tw(tl,SOFT,{TextTransparency=0})
	table.insert(content,h); scroll()
end
local function thinkLine()
	ord+=1
	local h=new("Frame",{Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,LayoutOrder=ord},logF)
	new("UIPadding",{PaddingTop=UDim.new(0,6)},h)
	new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,7)},h)
	local img=new("ImageLabel",{BackgroundTransparency=1,Size=UDim2.new(0,15,0,15),Image=LOGO,ScaleType=Enum.ScaleType.Fit,LayoutOrder=1},h)
	local txt=new("TextLabel",{BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,0,16),Font=F,TextSize=FS,TextColor3=C.dim,Text="Thinking…",LayoutOrder=2},h)
	img.ImageTransparency=1; txt.TextTransparency=1
	tw(img,SOFT,{ImageTransparency=0}); tw(txt,SOFT,{TextTransparency=0})
	task.delay(0.34,function() if txt.Parent then tw(txt,PULSE,{TextTransparency=0.55}); tw(img,PULSE,{ImageTransparency=0.4}) end end)
	table.insert(content,h); scroll(); return h
end
local splash
local function showSplash()
	splash=new("Frame",{Size=UDim2.new(1,0,0,220),BackgroundTransparency=1,LayoutOrder=0},logF)
	local col=new("Frame",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1},splash)
	new("UIListLayout",{FillDirection=Enum.FillDirection.Vertical,HorizontalAlignment=Enum.HorizontalAlignment.Center,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,6)},col)
	new("ImageLabel",{BackgroundTransparency=1,Size=UDim2.new(0,76,0,76),Image=LOGO,ScaleType=Enum.ScaleType.Fit,LayoutOrder=1},col)
	new("TextLabel",{BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.XY,Font=WM,TextSize=18,TextColor3=C.text,Text=CFG.title,LayoutOrder=2},col)
	new("TextLabel",{BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.XY,Font=F,TextSize=13,TextColor3=C.dim,Text="опиши, что построить",LayoutOrder=3},col)
	if PLAN~="pro" then new("TextLabel",{BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.XY,Font=F,TextSize=12,TextColor3=C.faint,Text="Free · "..DAILY.." сообщений/день · 3 модели",LayoutOrder=4},col) end
	pop(col,0.94)
	for _,ch in ipairs(col:GetChildren()) do
		if ch:IsA("TextLabel") then ch.TextTransparency=1; tw(ch,SOFT,{TextTransparency=0})
		elseif ch:IsA("ImageLabel") then ch.ImageTransparency=1; tw(ch,SOFT,{ImageTransparency=0}) end
	end
	table.insert(content,splash)
end
local function clearContent()
	for _,it in ipairs(content) do pcall(function() it:Destroy() end) end
	content={}; ord=0; splash=nil
end

-- ── logic ──
local function selInst() return Selection:Get()[1] end
local function code_of(r) if not r then return nil end; return r:match("```lua%s*\n(.-)```") or r:match("```luau%s*\n(.-)```") or r:match("```%s*\n(.-)```") end
local function runLua(src)
	if loadstring then local fn=loadstring(src); if fn then return pcall(fn) end end
	local ms=Instance.new("ModuleScript"); ms.Name="CortexRun"; ms.Source=src.."\nreturn true"; ms.Parent=game:GetService("ServerStorage")
	local ok,res=pcall(require,ms); pcall(function() ms:Destroy() end); return ok,res
end
local function renderUser(t) line("<font color='"..hexA.."'>›</font> <font color='"..hx("text").."'>"..esc(t).."</font>", 12) end
local function renderAssistant(reply,doRun,req)
	local code=code_of(reply)
	if code and #code>0 then
		line("<font color='"..hx("faint").."'>⎿</font> <font color='"..hx("dim").."'>"..(doRun and "применяю Luau" or "Luau").."</font>", 4)
		codeBlock(code)
		if doRun then
			local rec=CHS:TryBeginRecording("Cortex: "..tostring(req):sub(1,40))
			local ok,err=runLua(code)
			if rec then CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end
			if ok then line("<font color='"..hx("ok").."'>✔ готово</font> <font color='"..hx("faint").."'>· Ctrl+Z</font>", 6)
			else line("<font color='"..hx("err").."'>✗ ошибка:</font> <font color='"..hx("dim").."'>"..esc(tostring(err)).."</font>", 4) end
		else line("<font color='"..hx("faint").."'>✔ применено ранее</font>", 6) end
	else line("<font color='"..hx("dim").."'>"..esc(reply).."</font>", 4) end
end

-- ── chats ──
local chats={}; local cur=1
local renderChats
local function rebuildLog()
	clearContent()
	local ch=chats[cur]
	if #ch.hist==0 then showSplash()
	else for _,m in ipairs(ch.hist) do
		if m.role=="user" then renderUser(m.content) else renderAssistant(m.content,false,nil) end
	end end
end
local function switchTo(i) if i==cur then return end; cur=i; renderChats(); rebuildLog() end
local function newChat() table.insert(chats,{name="Chat "..(#chats+1),hist={}}); cur=#chats; renderChats(); rebuildLog() end
renderChats=function()
	for _,c in ipairs(tabsHold:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
	for i,ch in ipairs(chats) do
		local active=i==cur
		local pill=new("TextButton",{AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,0,20),BackgroundColor3=active and C.panel or C.bg,BorderSizePixel=0,AutoButtonColor=false,Font=F,TextSize=11,TextColor3=active and C.accent or C.dim,Text="  "..ch.name.."  ",LayoutOrder=i},tabsHold)
		new("UICorner",{CornerRadius=UDim.new(0,8)},pill)
		local ps=new("UIStroke",{Color=active and C.accentD or C.line,Thickness=1},pill)
		if not active then
			pill.MouseEnter:Connect(function() tw(pill,SNAP,{BackgroundColor3=C.hover}); tw(ps,SNAP,{Color=C.accentD}) end)
			pill.MouseLeave:Connect(function() tw(pill,SNAP,{BackgroundColor3=C.bg}); tw(ps,SNAP,{Color=C.line}) end)
		end
		pill.MouseButton1Click:Connect(function() switchTo(i) end)
	end
	local plus=new("TextButton",{Size=UDim2.new(0,22,0,20),BackgroundColor3=C.bg,BorderSizePixel=0,AutoButtonColor=false,Font=F,TextSize=14,TextColor3=C.dim,Text="+",LayoutOrder=999},tabsHold)
	new("UICorner",{CornerRadius=UDim.new(0,8)},plus); local plusStroke=new("UIStroke",{Color=C.line,Thickness=1},plus)
	plus.MouseEnter:Connect(function() tw(plus,SNAP,{BackgroundColor3=C.hover}); tw(plusStroke,SNAP,{Color=C.accentD}) end)
	plus.MouseLeave:Connect(function() tw(plus,SNAP,{BackgroundColor3=C.bg}); tw(plusStroke,SNAP,{Color=C.line}) end)
	plus.MouseButton1Click:Connect(newChat)
end

local function ask(hist,ctx)
	local d,eb=httpJSON("POST",BASE,key,{system=SYSTEM.."\n\n"..ctx,messages=hist,tier=MODELS[mi][2]})
	if not d then
		local e=tostring(eb or "")
		if e:find("not enabled") or e:find("HttpEnabled") or e:find("Http requests") then
			return nil,"HTTP выключен → Game Settings ▸ Security ▸ Allow HTTP Requests (или в Command Bar: game:GetService('HttpService').HttpEnabled=true)"
		end
		return nil,"ошибка сети: "..e:sub(1,140)
	end
	if d.error then return nil,tostring(type(d.error)=="table" and d.error.message or d.error) end
	return d.text
end

-- ── input ──
local prow=new("Frame",{Size=UDim2.new(1,0,0,IH),Position=UDim2.new(0,0,1,-IH),BackgroundColor3=C.panel,BorderSizePixel=0},root)
if RAD>0 then new("UICorner",{CornerRadius=UDim.new(0,RAD)},prow)
	new("Frame",{Size=UDim2.new(1,0,0,RAD),Position=UDim2.new(0,0,0,0),BackgroundColor3=C.panel,BorderSizePixel=0,ZIndex=0},prow) end
new("Frame",{Size=UDim2.new(1,0,0,1),BackgroundColor3=C.line,BorderSizePixel=0},prow)
new("UIPadding",{PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14)},prow)
local pchar=new("TextLabel",{Size=UDim2.new(0,14,1,0),BackgroundTransparency=1,Font=F,TextSize=FS+1,TextColor3=C.accent,Text="›",TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center},prow)
local rightW=CFG.show.runHint and 90 or 20
local boxx=new("TextBox",{Size=UDim2.new(1,-6-rightW,1,-14),Position=UDim2.new(0,20,0,7),BackgroundTransparency=1,TextColor3=C.text,PlaceholderColor3=C.faint,PlaceholderText="опиши, что построить…",Font=F,TextSize=FS,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,ClearTextOnFocus=false,TextWrapped=true,Text=""},prow)
if CFG.show.runHint then new("TextLabel",{Size=UDim2.new(0,70,1,0),Position=UDim2.new(1,-70,0,0),BackgroundTransparency=1,Font=F,TextSize=11,TextXAlignment=Enum.TextXAlignment.Right,TextYAlignment=Enum.TextYAlignment.Center,RichText=true,Text="<font color='"..hx("faint").."'>Enter </font><font color='"..hexA.."'>run</font>"},prow) end
boxx.Focused:Connect(function() tw(pchar,SNAP,{TextColor3=C.text}) end)
boxx.FocusLost:Connect(function() tw(pchar,SNAP,{TextColor3=C.accent}) end)

local busy=false
local function run()
	if busy then return end
	local req=boxx.Text; if #req==0 then return end
	if PLAN~="pro" and usedToday>=DAILY then line("<font color='"..hexA.."'>🔒 лимит "..DAILY.."/день исчерпан. Завтра снова, или апгрейд на Pro.</font>", 8); return end
	if splash then pcall(function() splash:Destroy() end); splash=nil end
	busy=true; boxx.Text=""
	local ch=chats[cur]
	table.insert(ch.hist,{role="user",content=req})
	renderUser(req)
	local s=selInst()
	local ctx=s and ("Selected: "..s:GetFullName().." ("..s.ClassName..")"..(s:IsA("LuaSourceContainer") and ("\nIts source:\n"..s.Source) or "")) or "Nothing is selected."
	local think=thinkLine()
	task.spawn(function()
		local reply,e=ask(ch.hist,ctx)
		if think then pcall(function() think:Destroy() end) end
		if not reply then
			line("<font color='"..hx("faint").."'>⎿</font> <font color='"..hx("err").."'>"..esc(e).."</font>", 4)
			if tostring(e):find("Pro") then line("<font color='"..hexA.."'>🔒 апгрейд на Pro открывает все 12 моделей + OSA Ultra</font>", 4) end
			table.remove(ch.hist)
		else
			table.insert(ch.hist,{role="assistant",content=reply})
			renderAssistant(reply,true,req)
			if PLAN~="pro" then usedToday+=1; refLimit() end
		end
		busy=false
	end)
end
boxx.FocusLost:Connect(function(enter) if enter then run() end end)

-- init
newChat()

end
