do
    local function nuke(p)
       
            end
        end
    end
    pcall(nuke,game:GetService("CoreGui"))
    pcall(nuke,game:GetService("Players").LocalPlayer.PlayerGui)
    if getgenv and getgenv()._PB_Destroy then pcall(getgenv()._PB_Destroy); getgenv()._PB_Destroy=nil end
    task.wait(0.15)
end

if getgenv then
    getgenv()._PB_SessionStart = getgenv()._PB_SessionStart or tick()
end
local _sessionStart = (getgenv and getgenv()._PB_SessionStart) or tick()

local Players  = game:GetService("Players")
local RS       = game:GetService("ReplicatedStorage")
local UIS      = game:GetService("UserInputService")
local WS       = game:GetService("Workspace")
local Run      = game:GetService("RunService")
local TS       = game:GetService("TeleportService")
local MS       = game:GetService("MarketplaceService")
local VU       = game:GetService("VirtualUser")
local LP       = Players.LocalPlayer
local Cam      = WS.CurrentCamera
local IsMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled



local POTION_NAMES     = {"HealthFlask", "DragonFlask", "EnergyFlask"}
local INTERVAL_OPTIONS = {1, 5, 10, 20, 30}
local INTERVAL_STRS    = {"1s", "5s", "10s", "20s", "30s"}

local MAX_TARGETS  = 10
local MIN_INTERVAL = 0.08

local BOSS_DAMAGE = {
    BookHand = 5000,
    Throne9  = 5000,
}

getgenv().S = getgenv().S or {
    KillAura=false, AuraRange=100, WalkSpeed=50, JumpPower=100, AttackSpeed=0.15,
    AntiAFK=false, ESP=false, Tracers=false,
    ESPColor=Color3.fromRGB(255,0,0), TracerColor=Color3.fromRGB(0,255,0),
    ShowNames=true, ShowHealth=true, ShowDistance=true, TracerOrigin="Bottom",
    UITransparency=0,
    AutoDrink=false, DrinkPotions={}, DrinkThreshold=50,
    AutoBuy=false, BuyPotions={}, BuyInterval=10, BuyQty=1, BuyMax=0, BuyTotal=0,
}
local S  = getgenv().S
local KB = { KillAura=Enum.KeyCode.L }

local fps, ping = 0, 0
local _fpsFrames, _fpsDt = 0, 0
local _pi; pcall(function() _pi=game:GetService("Stats").Network.ServerStatsItem["Data Ping"] end)
local function getPing()
    if _pi then local ok,v=pcall(_pi.GetValue,_pi); if ok and v then return math.floor(v) end end; return 0
end
Run.RenderStepped:Connect(function(dt)
    _fpsFrames=_fpsFrames+1; _fpsDt=_fpsDt+dt
    if _fpsDt>=0.5 then fps=math.floor(_fpsFrames/_fpsDt); ping=getPing(); _fpsFrames=0; _fpsDt=0 end
end)

local conns = {}
local function Cn(c) conns[#conns+1]=c; return c end
local function KillConns() for _,c in ipairs(conns) do pcall(c.Disconnect,c) end; conns={} end

local Win = NexusUI:CreateWindow({
    Title="Pixel Blade", Subtitle="By vhxLUA  v9",
    Theme="Midnight", ToggleKey=Enum.KeyCode.RightControl,
    Profile="PixelBlade",
})

local Rem     = RS:FindFirstChild("remotes")
local HitEv   = Rem and Rem:FindFirstChild("onHit")
local ClaimEv = Rem and Rem:FindFirstChild("claimCode")
local DrinkEv = Rem and Rem:FindFirstChild("drinkPotion")
local BuyEv   = Rem and Rem:FindFirstChild("requestPurchase")

local _enemies  = {}
local _enemySet = {}

local function _refreshEnemies()
    local char = LP.Character
    local myRP = char and char:FindFirstChild("HumanoidRootPart")
    if not myRP or not (S.KillAura or S.ESP or S.Tracers) then _enemies={}; _enemySet={}; return end
    local myPos     = myRP.Position
    local scanRange = math.max(S.AuraRange, (S.ESP or S.Tracers) and 2000 or 0)
    local newE, newSet = {}, {}
    for _, m in ipairs(WS:GetDescendants()) do
        if not m:IsA("Model") or m == char or newSet[m] then continue end
        local h = m:FindFirstChildOfClass("Humanoid")
        if not h or h.Health <= 0 then continue end
        if char and m:IsDescendantOf(char) then continue end
        local rp = m:FindFirstChild("HumanoidRootPart")
                or m:FindFirstChild("Torso")
                or m:FindFirstChild("UpperTorso")
                or m.PrimaryPart
        if not rp or (myPos - rp.Position).Magnitude <= scanRange then
            newSet[m] = true
            newE[#newE+1] = {model=m, humanoid=h, root=rp}
        end
    end
    _enemies = newE; _enemySet = newSet
end

task.spawn(function() while true do task.wait(0.25); _refreshEnemies() end end)

local LevelStartEv = Rem and Rem:FindFirstChild("levelStart")
if LevelStartEv then
    Cn(LevelStartEv.OnClientEvent:Connect(function()
        _enemies = {}
        _enemySet = {}
        task.wait(0.5)
        _refreshEnemies()
    end))
end

local ESP={}
local function clearESP()
    for _,d in next,ESP do
        if d then
            for _,l in next,d.box do pcall(l.Remove,l) end
            for _,k in next,{"nl","hb","hf","dl","tr"} do if d[k] then pcall(d[k].Remove,d[k]) end end
        end
    end; ESP={}
end
local function mkESP(m)
    if ESP[m] then return end
    local d={box={}}
    for i=1,4 do local l=Drawing.new("Line"); l.Thickness=1.5; l.Visible=false; l.ZIndex=5; d.box[i]=l end
    local function txt() local t=Drawing.new("Text"); t.Size=13; t.Outline=true; t.OutlineColor=Color3.new(0,0,0); t.Center=true; t.Visible=false; t.ZIndex=6; return t end
    local function ln(th,z) local l=Drawing.new("Line"); l.Thickness=th; l.Visible=false; l.ZIndex=z; return l end
    d.nl=txt(); d.hb=ln(3,5); d.hb.Color=Color3.new(0,0,0); d.hf=ln(3,6); d.dl=txt(); d.dl.Size=11; d.tr=ln(1,4)
    ESP[m]=d
end
local function rmESP(m)
    local d=ESP[m]; if not d then return end
    for _,l in next,d.box do pcall(l.Remove,l) end
    for _,k in next,{"nl","hb","hf","dl","tr"} do if d[k] then pcall(d[k].Remove,d[k]) end end
    ESP[m]=nil
end
local HW,HH=2,2.75
local function bounds(m)
    local r=m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart; if not r then return nil end
    local cf=r.CFrame; local x0,y0,x1,y1=math.huge,math.huge,-math.huge,-math.huge
    for _,o in next,{Vector3.new(-HW,-HH,0),Vector3.new(HW,-HH,0),Vector3.new(HW,HH,0),Vector3.new(-HW,HH,0)} do
        local sp,vis=Cam:WorldToViewportPoint((cf*CFrame.new(o)).Position)
        if not vis then return nil end
        if sp.X<x0 then x0=sp.X end; if sp.Y<y0 then y0=sp.Y end
        if sp.X>x1 then x1=sp.X end; if sp.Y>y1 then y1=sp.Y end
    end
    return x0,y0,x1,y1
end
task.spawn(function()
    while true do
        task.wait(1/30)
        local act=S.ESP or S.Tracers
        if not act then
            for _,d in next,ESP do
                for _,l in next,d.box do l.Visible=false end
                d.nl.Visible=false; d.hb.Visible=false; d.hf.Visible=false; d.dl.Visible=false; d.tr.Visible=false
            end; continue
        end
        local char=LP.Character
        local myR=char and char:FindFirstChild("HumanoidRootPart")
        local vp=Cam.ViewportSize
        local tO=S.TracerOrigin~="Center" and Vector2.new(vp.X*.5,vp.Y) or Vector2.new(vp.X*.5,vp.Y*.5)
        local activeModels={}
        for _,e in ipairs(_enemies) do
            local m=e.model; local h=e.humanoid
            if m and m.Parent and h and h.Health>0 then activeModels[m]=true; if not ESP[m] then mkESP(m) end end
        end
        for m in next,ESP do if not activeModels[m] then rmESP(m) end end
        for m,d in next,ESP do
            local h=m:FindFirstChildOfClass("Humanoid"); local r=m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
            if not r or not h then
                for _,l in next,d.box do l.Visible=false end
                d.nl.Visible=false; d.hb.Visible=false; d.hf.Visible=false; d.dl.Visible=false; d.tr.Visible=false
                continue
            end
            local sp,vis=Cam:WorldToViewportPoint(r.Position)
            local ctr=Vector2.new(sp.X,sp.Y)
            local dist=myR and (myR.Position-r.Position).Magnitude or 0
            if S.ESP then
                local x0,y0,x1,y1=bounds(m)
                if x0 and vis then
                    local ec=S.ESPColor; local b=d.box
                    b[1].From=Vector2.new(x0,y0); b[1].To=Vector2.new(x1,y0); b[1].Color=ec; b[1].Visible=true
                    b[2].From=Vector2.new(x0,y1); b[2].To=Vector2.new(x1,y1); b[2].Color=ec; b[2].Visible=true
                    b[3].From=Vector2.new(x0,y0); b[3].To=Vector2.new(x0,y1); b[3].Color=ec; b[3].Visible=true
                    b[4].From=Vector2.new(x1,y0); b[4].To=Vector2.new(x1,y1); b[4].Color=ec; b[4].Visible=true
                    if S.ShowNames then d.nl.Text=m.Name; d.nl.Color=ec; d.nl.Position=Vector2.new((x0+x1)*.5,y0-18); d.nl.Visible=true else d.nl.Visible=false end
                    local hr=math.clamp(h.Health/h.MaxHealth,0,1)
                    if S.ShowHealth then
                        d.hb.From=Vector2.new(x0-6,y0); d.hb.To=Vector2.new(x0-6,y1); d.hb.Visible=true
                        d.hf.From=Vector2.new(x0-6,y1); d.hf.To=Vector2.new(x0-6,y1-(y1-y0)*hr)
                        d.hf.Color=Color3.fromRGB(math.floor((1-hr)*255),math.floor(hr*255),0); d.hf.Visible=true
                    else d.hb.Visible=false; d.hf.Visible=false end
                    if S.ShowDistance then d.dl.Text=math.floor(dist).."m"; d.dl.Position=Vector2.new((x0+x1)*.5,y1+3); d.dl.Visible=true else d.dl.Visible=false end
                else
                    for _,l in next,d.box do l.Visible=false end
                    d.nl.Visible=false; d.hb.Visible=false; d.hf.Visible=false; d.dl.Visible=false
                end
            else
                for _,l in next,d.box do l.Visible=false end
                d.nl.Visible=false; d.hb.Visible=false; d.hf.Visible=false; d.dl.Visible=false
            end
            if S.Tracers and vis then d.tr.From=tO; d.tr.To=ctr; d.tr.Color=S.TracerColor; d.tr.Visible=true else d.tr.Visible=false end
        end
    end
end)

local function applySpeed()
    local c=LP.Character; if not c then return end
    local h=c:FindFirstChildOfClass("Humanoid"); if not h then return end
    h.WalkSpeed=S.WalkSpeed; h.JumpPower=S.JumpPower
end
local function hookCharacter(char)
    local h=char:WaitForChild("Humanoid",5); if not h then return end
    applySpeed()
    Cn(h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if math.abs(h.WalkSpeed-S.WalkSpeed)>0.5 then h.WalkSpeed=S.WalkSpeed end
    end))
    Cn(h:GetPropertyChangedSignal("JumpPower"):Connect(function()
        if math.abs(h.JumpPower-S.JumpPower)>0.5 then h.JumpPower=S.JumpPower end
    end))
end
if LP.Character then hookCharacter(LP.Character) end
Cn(LP.CharacterAdded:Connect(hookCharacter))

local _auraTimer = 0

local function _getDmg(m)
    if m.Name == "BookHand" then return BOSS_DAMAGE.BookHand end
    if m.Name == "Throne9"  then return BOSS_DAMAGE.Throne9  end
    return 5000
end

Cn(Run.Heartbeat:Connect(function(dt)
    if not S.KillAura or not HitEv or not HitEv.Parent then return end
    _auraTimer=_auraTimer+dt
    local iv=math.max(S.AttackSpeed,MIN_INTERVAL)
    if _auraTimer<iv then return end
    _auraTimer=0

    local char=LP.Character; if not char then return end
    local myR=char:FindFirstChild("HumanoidRootPart"); if not myR then return end
    local myPos=myR.Position
    local count=0

    for _,e in ipairs(_enemies) do
        if count>=MAX_TARGETS then break end
        local h=e.humanoid; local rp=e.root; local m=e.model
        if h and h.Parent and h.Health>0 then
            if not rp or (myPos-rp.Position).Magnitude<=S.AuraRange then
                pcall(HitEv.FireServer, HitEv, h, _getDmg(m), {}, 0)
                count=count+1
            end
        end
    end
end))

local _drinkThread=nil
local function stopDrink() if _drinkThread then task.cancel(_drinkThread); _drinkThread=nil end end
local function startDrink()
    stopDrink()
    if not DrinkEv or not DrinkEv.Parent then
        Win:Notify({Title="Auto Drink",Content="drinkPotion remote not found!",Duration=3}); return
    end
    _drinkThread=task.spawn(function()
        while S.AutoDrink do
            task.wait(0.1)
            local char=LP.Character
            local h=char and char:FindFirstChildOfClass("Humanoid")
            if h and h.Health>0 and h.MaxHealth>0 then
                local pct=(h.Health/h.MaxHealth)*100
                if pct<=S.DrinkThreshold then
                    pcall(DrinkEv.FireServer,DrinkEv)
                    task.wait(0.5)
                end
            end
        end
    end)
end

local _buyThread=nil
local function stopBuy() if _buyThread then task.cancel(_buyThread); _buyThread=nil end end
local function startBuy()
    stopBuy()
    if not BuyEv or not BuyEv.Parent then
        Win:Notify({Title="Auto Buy",Content="requestPurchase remote not found!",Duration=3}); return
    end
    S.BuyTotal=0
    _buyThread=task.spawn(function()
        while S.AutoBuy do
            if #S.BuyPotions==0 then task.wait(1); continue end
            if S.BuyMax>0 and S.BuyTotal>=S.BuyMax then
                S.AutoBuy=false
                Win:Notify({Title="Auto Buy",Content="Max purchases ("..S.BuyMax..") reached!",Duration=4}); break
            end
            local qty=math.max(1,S.BuyQty)
            if S.BuyMax>0 then qty=math.min(qty,S.BuyMax-S.BuyTotal) end
            for _,pn in ipairs(S.BuyPotions) do
                for i=1,qty do pcall(BuyEv.FireServer,BuyEv,pn,"potion"); task.wait(0.15) end
            end
            S.BuyTotal=S.BuyTotal+qty*math.max(1,#S.BuyPotions)
            task.wait(S.BuyInterval)
        end
    end)
end

local afkConn
local function setAFK(v)
    S.AntiAFK=v
    if afkConn then afkConn:Disconnect(); afkConn=nil end
    if v then afkConn=Run.Heartbeat:Connect(function() pcall(VU.CaptureController,VU); pcall(VU.ClickButton2,VU,Vector2.new()) end) end
end

local Codes={"BREAKABLES","AncientSands","PLUSHIE","625K","CrimsonNightmare","600K","575K","550K","FREEWISH","World4","525K","Rings","Alpha","Theo","FBG"}
local claimed=false
local function claim()
    if claimed then return end
    if not ClaimEv or not ClaimEv.Parent then Win:Notify({Title="Codes",Content="Remote not found.",Duration=3}); return end
    claimed=true
    for _,code in next,Codes do pcall(ClaimEv.InvokeServer,ClaimEv,code); task.wait(0.3) end
end

local function optimizeGraphics()
    pcall(function() settings().Rendering.QualityLevel=Enum.QualityLevel.Level01 end)
    pcall(function()
        local L=game:GetService("Lighting"); L.GlobalShadows=false; L.FogEnd=100000
        for _,v in ipairs(L:GetChildren()) do
            if v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("SunRaysEffect")
            or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") then v.Enabled=false end
        end
    end)
    pcall(function()
        for _,p in ipairs(WS:GetDescendants()) do
            if p:IsA("ParticleEmitter") or p:IsA("Trail") then p.Enabled=false end
        end
    end)
    Win:Notify({Title="Optimize",Content="Graphics lowered. FPS should improve.",Duration=4})
end

local okCG,CG=pcall(game.GetService,game,"CoreGui")
local OGui=Instance.new("ScreenGui"); OGui.Name="PB_Overlay"; OGui.ResetOnSpawn=false; OGui.DisplayOrder=1000
OGui.Parent=okCG and CG or LP.PlayerGui
local OF=Instance.new("Frame"); OF.Size=UDim2.new(0,118,0,46); OF.Position=UDim2.new(0,80,0,10)
OF.BackgroundColor3=Color3.fromRGB(10,10,18); OF.BorderSizePixel=0; OF.Parent=OGui
Instance.new("UICorner",OF).CornerRadius=UDim.new(0,8); Instance.new("UIStroke",OF).Color=Color3.fromRGB(30,30,50)
local FL=Instance.new("TextLabel"); FL.Size=UDim2.new(1,-8,0,20); FL.Position=UDim2.new(0,6,0,2)
FL.BackgroundTransparency=1; FL.Text="FPS: --"; FL.TextColor3=Color3.fromRGB(140,100,255)
FL.TextSize=11; FL.Font=Enum.Font.GothamBold; FL.TextXAlignment=Enum.TextXAlignment.Left; FL.Parent=OF
local PL_=Instance.new("TextLabel"); PL_.Size=UDim2.new(1,-8,0,20); PL_.Position=UDim2.new(0,6,0,24)
PL_.BackgroundTransparency=1; PL_.Text="Ping: --ms"; PL_.TextColor3=Color3.fromRGB(120,115,150)
PL_.TextSize=11; PL_.Font=Enum.Font.Gotham; PL_.TextXAlignment=Enum.TextXAlignment.Left; PL_.Parent=OF
local _of,_op=-1,-1
task.spawn(function()
    while true do task.wait(0.5)
        if fps~=_of  then _of=fps;  if FL  and FL.Parent  then FL.Text="FPS: "..fps    end end
        if ping~=_op then _op=ping; if PL_ and PL_.Parent then PL_.Text="Ping: "..ping.."ms" end end
    end
end)

local function rejoin()
    pcall(function() TS:Teleport(game.PlaceId,LP) end)
    task.delay(2,function() pcall(function() TS:TeleportToPlaceInstance(game.PlaceId,game.JobId,LP) end) end)
end

local CT  = Win:CreateTab({Title="Combat",   Icon="sword"   })
local ET  = Win:CreateTab({Title="ESP",      Icon="eye"     })
local MT  = Win:CreateTab({Title="Movement", Icon="zap"     })
local PT  = Win:CreateTab({Title="Potions",  Icon="heart"   })
local MiT = Win:CreateTab({Title="Misc",     Icon="shield"  })
local IT  = Win:CreateTab({Title="Info",     Icon="info"    })
local ST  = Win:CreateTab({Title="Settings", Icon="settings"})

local CS = CT:CreateSection({Title="Kill Aura"})

CS:CreateParagraph({
    Title="Boss Warning",
    Content="Turn off Kill Aura while a boss is spawning (intro cutscene). Firing the hit remote during spawn can desync boss state, causing no damage or a server kick.",
})

local AuraToggle = CS:CreateToggle({
    Title="Kill Aura",
    Description="Hits nearby enemies - bosses use exact damage values",
    Flag="ka_enabled", Default=S.KillAura,
    Callback=function(v) S.KillAura=v end,
})
CS:CreateSlider({
    Title="Aura Range", Range={0,1000}, Default=S.AuraRange, Suffix=" studs",
    Flag="ka_range", Callback=function(v) S.AuraRange=v end,
})
CS:CreateSlider({
    Title="Attack Interval", Range={80,2000}, Default=math.floor(S.AttackSpeed*1000), Suffix=" ms",
    Flag="ka_interval",
    Callback=function(v) S.AttackSpeed=v/1000 end,
})
CS:CreateLabel({Title="Max Targets", Value=MAX_TARGETS.." per burst", Icon="star"})

local RaidS = CT:CreateSection({Title="Raid"})
RaidS:CreateToggle({
    Title="Auto Replay",
    Flag="raid_replay", Default=false,
    Callback=function(v)
        if v then
            local ReplayEv = game:GetService("ReplicatedStorage").remotes.gameEndVote
            pcall(ReplayEv.FireServer, ReplayEv, "replay")
        end
    end,
})

local VS=ET:CreateSection({Title="Visuals"})
VS:CreateToggle({Title="ESP Boxes",     Description="Boxes + health bars", Flag="esp_boxes",
    Default=S.ESP,     Callback=function(v) S.ESP=v;     if not v and not S.Tracers then clearESP() end end})
VS:CreateToggle({Title="Tracers",       Description="Lines to enemies",    Flag="esp_tracers",
    Default=S.Tracers, Callback=function(v) S.Tracers=v; if not v and not S.ESP     then clearESP() end end})
VS:CreateToggle({Title="Show Names",    Flag="esp_names",   Default=S.ShowNames,   Callback=function(v) S.ShowNames=v    end})
VS:CreateToggle({Title="Show Health",   Flag="esp_health",  Default=S.ShowHealth,  Callback=function(v) S.ShowHealth=v   end})
VS:CreateToggle({Title="Show Distance", Flag="esp_dist",    Default=S.ShowDistance,Callback=function(v) S.ShowDistance=v end})
local ColS=ET:CreateSection({Title="Colors"})
ColS:CreateColorPicker({Title="ESP Color",    Flag="esp_color",  Default=S.ESPColor,    Callback=function(v) S.ESPColor=v    end})
ColS:CreateColorPicker({Title="Tracer Color", Flag="esp_tcolor", Default=S.TracerColor, Callback=function(v) S.TracerColor=v end})
ColS:CreateDropdown({Title="Tracer Origin", Options={"Bottom","Center"}, Flag="esp_torigin",
    Default=S.TracerOrigin, Callback=function(v) S.TracerOrigin=v end})

local ChS=MT:CreateSection({Title="Character"})
ChS:CreateSlider({Title="Walk Speed", Range={16,500}, Default=S.WalkSpeed, Suffix=" sp",
    Flag="mv_speed", Callback=function(v) S.WalkSpeed=v; applySpeed() end})
ChS:CreateSlider({Title="Jump Power", Range={50,500}, Default=S.JumpPower,
    Flag="mv_jump",  Callback=function(v) S.JumpPower=v; applySpeed() end})

local DrinkSec=PT:CreateSection({Title="Auto Drink Potion"})
DrinkSec:CreateToggle({
    Title="Auto Drink", Description="Automatically drink a potion when health falls below threshold",
    Flag="drink_enabled", Default=S.AutoDrink,
    Callback=function(v) S.AutoDrink=v; if v then startDrink() else stopDrink() end end,
})
DrinkSec:CreateSlider({
    Title="Health Threshold", Range={1,100}, Default=S.DrinkThreshold, Suffix="%",
    Flag="drink_threshold",
    Callback=function(v) S.DrinkThreshold=v end,
})
DrinkSec:CreateDropdown({Title="Potions to Drink", Options=POTION_NAMES, MultiSelect=true,
    Flag="drink_potions", Default=S.DrinkPotions, Callback=function(v) S.DrinkPotions=v end})

local BuySec=PT:CreateSection({Title="Auto Buy Potion"})
BuySec:CreateToggle({
    Title="Auto Buy", Description="Automatically purchase potions on a timer",
    Flag="buy_enabled", Default=S.AutoBuy,
    Callback=function(v) S.AutoBuy=v; if v then startBuy() else stopBuy() end end,
})
BuySec:CreateDropdown({Title="Potions to Buy", Options=POTION_NAMES, MultiSelect=true,
    Flag="buy_potions", Default=S.BuyPotions, Callback=function(v) S.BuyPotions=v end})
BuySec:CreateDropdown({Title="Buy Interval", Options=INTERVAL_STRS, Flag="buy_interval", Default="10s",
    Callback=function(v) for i,s in ipairs(INTERVAL_STRS) do if s==v then S.BuyInterval=INTERVAL_OPTIONS[i]; break end end end})
BuySec:CreateInput({Title="Qty per Buy", Placeholder="1", Default=tostring(S.BuyQty),
    NumbersOnly=true, Flag="buy_qty",
    Callback=function(v) local n=tonumber(v); if n and n>=1 then S.BuyQty=math.floor(n) end end})
BuySec:CreateInput({Title="Max Purchases (0=inf)", Placeholder="0", Default="0",
    NumbersOnly=true, Flag="buy_max",
    Callback=function(v) local n=tonumber(v); S.BuyMax=(n and n>=0) and math.floor(n) or 0 end})

local MiS=MiT:CreateSection({Title="Utility"})
MiS:CreateToggle({Title="Anti-AFK", Description="Prevents idle kick",
    Flag="util_afk", Default=S.AntiAFK, Callback=function(v) setAFK(v) end})
MiS:CreateButton({Title="Rejoin Server", Description="Reconnects to a fresh instance", Icon="refresh",
    Callback=function() Win:Notify({Title="Rejoin",Content="Rejoining...",Duration=3}); task.delay(0.5,rejoin) end})
MiT:CreateSection({Title="Codes"}):CreateButton({
    Title="Claim All Codes", Description="Attempts all "..#Codes.." known codes", Icon="key",
    Callback=function()
        Win:Notify({Title="Codes",Content="Claiming "..#Codes.." codes...",Duration=3})
        task.spawn(function() claimed=false; claim() end)
    end,
})

local function fmtTime(s)
    s=math.floor(s)
    local h=math.floor(s/3600); local m=math.floor((s%3600)/60); local sc=s%60
    if h>0 then return string.format("%dh %02dm",h,m) elseif m>0 then return string.format("%dm %02ds",m,sc) else return sc.."s" end
end
local function fmtDate(t)
    local d=os.date("*t",t); return string.format("%d/%02d/%02d",d.year,d.month,d.day)
end
local initStats=Win:GetStats()

local _cardSec  =IT:CreateSection({Title="Player"})
local avatarImg =_cardSec:CreateImage({Image="rbxthumb://type=AvatarHeadShot&id="..LP.UserId.."&w=150&h=150", Size=68, Circle=true})
local lDispName =_cardSec:CreateLabel({Title="Display",    Value=LP.DisplayName,            Icon="user"   })
local lUserName =_cardSec:CreateLabel({Title="Username",   Value="@"..LP.Name,              Icon="tag"    })
local lExecCard =_cardSec:CreateLabel({Title="Executions", Value=initStats.executions.."x", Icon="refresh"})
local lSessCard =_cardSec:CreateLabel({Title="Session",    Value="0s",                      Icon="time"   })

local IS    =IT:CreateSection({Title="Server"})
local lGame =IS:CreateLabel({Title="Game",    Value="Loading..."})
local lPl   =IS:CreateLabel({Title="Players", Value="..."})
local lPing =IS:CreateLabel({Title="Ping",    Value="..."})
local lFPS  =IS:CreateLabel({Title="FPS",     Value="..."})
local lUp   =IS:CreateLabel({Title="Uptime",  Value="00:00"})

local StS    =IT:CreateSection({Title="Usage Stats"})
local lTTime =StS:CreateLabel({Title="Total Time",   Value=fmtTime(initStats.total_time)})
local lSTime =StS:CreateLabel({Title="Session Time", Value="0s"})
local lExecS =StS:CreateLabel({Title="Executions",   Value=initStats.executions.."x"})
local lFirst =StS:CreateLabel({Title="First Run",    Value=fmtDate(initStats.first_run)})
local lLast  =StS:CreateLabel({Title="Last Run",     Value=fmtDate(initStats.last_run)})

local ProfS =IT:CreateSection({Title="Account"})
local iAge  =ProfS:CreateLabel({Title="Acct Age",  Value="..."})
local iJoin =ProfS:CreateLabel({Title="Est. Join",  Value="..."})
local iTeam =ProfS:CreateLabel({Title="Team",       Value="None"})
local iUID  =ProfS:CreateLabel({Title="User ID",    Value=tostring(LP.UserId)})

local IFS   =IT:CreateSection({Title="Friends"})
local lFIn  =IFS:CreateLabel({Title="In Server",   Value="..."})
local lFOn  =IFS:CreateLabel({Title="Online",      Value="..."})
local lFAll =IFS:CreateLabel({Title="All Friends", Value="..."})

local hbTick=0
Cn(Run.Heartbeat:Connect(function(dt)
    hbTick=hbTick+dt; if hbTick<1 then return end; hbTick=0
    local stats    =Win:GetStats()
    local realSess =math.floor(tick()-_sessionStart)
    local sessStr  =fmtTime(realSess)
    lSessCard:Set(sessStr); lSTime:Set(sessStr)
    lTTime:Set(fmtTime(stats.total_time))
    lExecCard:Set(stats.executions.."x"); lExecS:Set(stats.executions.."x")
    lPing:Set(ping.."ms"); lFPS:Set(fps.." fps")
    lUp:Set(string.format("%02d:%02d",math.floor(realSess/60),realSess%60))
end))

task.spawn(function()
    task.wait(1)
    avatarImg:Set("rbxthumb://type=AvatarHeadShot&id="..LP.UserId.."&w=150&h=150")
    lDispName:Set(LP.DisplayName); lUserName:Set("@"..LP.Name)
    iUID:Set(tostring(LP.UserId)); iAge:Set(LP.AccountAge.." days")
    iJoin:Set("~"..tostring(os.date("*t",os.time()-LP.AccountAge*86400).year))
    local function refreshTeam() local t=LP.Team; iTeam:Set(t and t.Name or "None") end
    refreshTeam(); Cn(LP:GetPropertyChangedSignal("Team"):Connect(refreshTeam))
    local ok,gi=pcall(MS.GetProductInfo,MS,game.PlaceId)
    lGame:Set(ok and gi and gi.Name or tostring(game.PlaceId))
    local function upPlayers() lPl:Set(#Players:GetPlayers().."/"..Players.MaxPlayers) end
    upPlayers()
    Cn(Players.PlayerAdded:Connect(upPlayers))
    Cn(Players.PlayerRemoving:Connect(function() task.wait(0.05); upPlayers() end))
    task.spawn(function()
        local inS,all,on=0,0,0
        pcall(function()
            local pg=Players:GetFriendsAsync(LP.UserId)
            repeat
                for _,f in next,pg:GetCurrentPage() do all=all+1; if f.IsOnline then on=on+1 end end
                if not pg.IsFinished then pg:AdvanceToNextPageAsync() end
            until pg.IsFinished
        end)
        for _,p in next,Players:GetPlayers() do
            if p~=LP then local ok2,fr=pcall(LP.IsFriendsWith,LP,p.UserId); if ok2 and fr then inS=inS+1 end end
        end
        lFIn:Set(inS.." in server"); lFOn:Set(on.." online"); lFAll:Set(all.." total")
    end)
end)

local SoS=ST:CreateSection({Title="Social"})
SoS:CreateButton({Title="Copy Discord", Description="discord.gg/AuQqvrJE79", Icon="copy",
    Callback=function()
        if setclipboard then pcall(setclipboard,"https://discord.gg/AuQqvrJE79") end
        Win:Notify({Title="Discord",Content="Invite copied!",Duration=3})
    end})

local UiS=ST:CreateSection({Title="Interface"})
UiS:CreateDropdown({Title="Theme", Options=Win:GetThemeNames(), Default="Midnight",
    Flag="ui_theme", Callback=function(v) Win:SetTheme(v) end})
UiS:CreateSlider({Title="UI Transparency", Range={0,95}, Default=math.floor(S.UITransparency*100),
    Suffix="%", Flag="ui_trans",
    Callback=function(v) S.UITransparency=v/100; Win:SetTransparency(S.UITransparency) end})
UiS:CreateButton({Title="Toggle UI", Icon="eye",
    Callback=function() Win:SetVisible(not Win:GetVisible()) end})

local PerfS=ST:CreateSection({Title="Performance"})
PerfS:CreateButton({Title="Optimize Graphics", Description="Reduces quality, disables shadows/FX", Icon="zap",
    Callback=optimizeGraphics})
PerfS:CreateButton({Title="Clear Particles", Description="Disables all particle emitters and trails", Icon="minus",
    Callback=function()
        local count=0
        for _,p in ipairs(WS:GetDescendants()) do
            if p:IsA("ParticleEmitter") or p:IsA("Trail") then p.Enabled=false; count=count+1 end
        end
        Win:Notify({Title="Particles",Content="Disabled "..count.." effects.",Duration=3})
    end})

if not IsMobile then
    local KbS=ST:CreateSection({Title="Keybinds"})
    KbS:CreateKeybind({Title="Kill Aura", Default=KB.KillAura, Flag="kb_killaura",
        Callback=function(kc) KB.KillAura=kc; Win:Notify({Title="Keybind",Content="Kill Aura -> "..kc.Name,Duration=2}) end})
    KbS:CreateKeybind({Title="Toggle UI", Default=Enum.KeyCode.RightControl, Flag="kb_toggleui",
        Callback=function(kc) Win:SetToggleKey(kc); Win:Notify({Title="Keybind",Content="Toggle UI -> "..kc.Name,Duration=2}) end})
    Cn(UIS.InputBegan:Connect(function(i,gpe)
        if gpe or i.UserInputType~=Enum.UserInputType.Keyboard then return end
        if UIS:GetFocusedTextBox() then return end
        if i.KeyCode==KB.KillAura then
            S.KillAura=not S.KillAura; AuraToggle:Set(S.KillAura)
            Win:Notify({Title="Kill Aura",Content=S.KillAura and "Enabled" or "Disabled",Duration=2})
        end
    end))
end

if getgenv then
    getgenv()._PB_Destroy=function()
        stopDrink(); stopBuy()
        if afkConn then afkConn:Disconnect(); afkConn=nil end
        clearESP(); KillConns()
        pcall(Win.Destroy, Win)
        pcall(OGui.Destroy, OGui)
    end
end

do
    local cfg = NexusUI:LoadConfig("PixelBlade")

    local function bool(v, default)
        if type(v) == "boolean" then return v end
        return default
    end
    local function num(v, default)
        return type(v) == "number" and v or default
    end

    S.KillAura     = bool(cfg.ka_enabled,   false)
    S.ESP          = bool(cfg.esp_boxes,    false)
    S.Tracers      = bool(cfg.esp_tracers,  false)
    S.ShowNames    = bool(cfg.esp_names,    true)
    S.ShowHealth   = bool(cfg.esp_health,   true)
    S.ShowDistance = bool(cfg.esp_dist,     true)
    S.AutoDrink    = bool(cfg.drink_enabled,false)
    S.AutoBuy      = bool(cfg.buy_enabled,  false)
    S.AntiAFK      = bool(cfg.util_afk,     false)

    S.AuraRange      = num(cfg.ka_range,        S.AuraRange)
    S.AttackSpeed    = cfg.ka_interval and cfg.ka_interval/1000 or S.AttackSpeed
    S.WalkSpeed      = num(cfg.mv_speed,        S.WalkSpeed)
    S.JumpPower      = num(cfg.mv_jump,         S.JumpPower)
    S.DrinkThreshold = num(cfg.drink_threshold, S.DrinkThreshold)
    S.BuyQty         = num(tonumber(cfg.buy_qty),S.BuyQty)
    S.BuyMax         = num(tonumber(cfg.buy_max),S.BuyMax)

    if type(cfg.drink_potions) == "table" then S.DrinkPotions = cfg.drink_potions end
    if type(cfg.buy_potions)   == "table" then S.BuyPotions   = cfg.buy_potions   end

    if type(cfg.esp_torigin) == "string" then S.TracerOrigin = cfg.esp_torigin end
    if cfg.ui_trans then S.UITransparency = num(cfg.ui_trans, 0) / 100 end

    if typeof(cfg.esp_color)  == "Color3" then S.ESPColor    = cfg.esp_color  end
    if typeof(cfg.esp_tcolor) == "Color3" then S.TracerColor = cfg.esp_tcolor end

    if S.AutoDrink then startDrink()  end
    if S.AutoBuy   then startBuy()    end
    if S.AntiAFK   then setAFK(true)  end

    applySpeed()

    if S.UITransparency > 0 then Win:SetTransparency(S.UITransparency) end
    if cfg.ui_theme then pcall(function() Win:SetTheme(cfg.ui_theme) end) end
end

Win:Notify({



local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local plr = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
local cam = Workspace.CurrentCamera

-- Проверка существования RemoteEvents
local remotes = ReplicatedStorage:FindFirstChild("remotes")
if not remotes then
    warn("remotes folder not found!")
    return
end

local swingRemote = remotes:FindFirstChild("swing")
local onHitRemote = remotes:FindFirstChild("onHit")
local blockRemote = remotes:FindFirstChild("block")

if not swingRemote or not onHitRemote or not blockRemote then
    warn("Some remotes not found!")
    return
end

-- Переменные
local auraEnabled = true
local auraRadius = 100
local AuraMode = "Nearest"
local BurstCooldown = 5
local lastBurst = 0

local speedOn = false
local speedValue = 20

local flyOn = false
local flySpeed = 40

local currentTarget
local currentHighlight
local IgnoredEnemies = {
    ["teeth trap"] = true, ["Teeth Trap"] = true,
    ["teeth_trap"] = true, ["Teeth_Trap"] = true
}

-- Функции
local function clearTarget()
    if currentHighlight and currentHighlight.Parent then 
        currentHighlight:Destroy() 
    end
    currentTarget = nil
    currentHighlight = nil
end

local function setTarget(m)
    if currentTarget == m then return end
    clearTarget()
    currentTarget = m
    local h = Instance.new("Highlight")
    h.FillTransparency = 1
    h.OutlineColor = Color3.fromRGB(170, 0, 0)
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = m
    currentHighlight = h
end

local function getNearbyEnemies(r)
    local t = {}
    for _, o in ipairs(Workspace:GetChildren()) do
        if o:IsA("Model") and o ~= char and not IgnoredEnemies[o.Name] then
            local h = o:FindFirstChild("Humanoid")
            local rp = o:FindFirstChild("HumanoidRootPart")
            if h and rp and h.Health > 0 then
                local d = (hrp.Position - rp.Position).Magnitude
                if d <= r then
                    table.insert(t, {obj = o, dist = d})
                end
            end
        end
    end
    table.sort(t, function(a, b) return a.dist < b.dist end)
    return t
end

local function filterByMode(list)
    if AuraMode == "Nearest" then return list end
    if AuraMode == "Cone" then
        local out = {}
        for _, e in ipairs(list) do
            local r = e.obj:FindFirstChild("HumanoidRootPart")
            if r then
                local dir = (r.Position - cam.CFrame.Position).Unit
                if cam.CFrame.LookVector:Dot(dir) >= math.cos(math.rad(45)) then
                    table.insert(out, e)
                end
            end
        end
        return out
    end
    if AuraMode == "Burst" then
        if tick() - lastBurst < BurstCooldown then return {} end
        lastBurst = tick()
        return list
    end
    return list
end

-- Aura loop
task.spawn(function()
    while task.wait(0.3) do
        if auraEnabled then
            local enemies = filterByMode(getNearbyEnemies(auraRadius))
            if #enemies > 0 then
                pcall(function()
                    swingRemote:FireServer()
                end)
                setTarget(enemies[1].obj)
                for _, e in ipairs(enemies) do
                    local h = e.obj:FindFirstChild("Humanoid")
                    if h then
                        pcall(function()
                            onHitRemote:FireServer(h, 9999999999, {}, 0)
                        end)
                    end
                end
            else
                clearTarget()
            end
        else
            clearTarget()
        end
    end
end)

-- Block loop
task.spawn(function()
    while task.wait(0.1) do
        pcall(function()
            blockRemote:FireServer(true)
        end)
    end
end)

-- Speed
RunService.Heartbeat:Connect(function()
    if speedOn and hum and hum.Parent then 
        hum.WalkSpeed = speedValue 
    end
end)

-- Fly функции
local function ensureFly()
    local bv = hrp:FindFirstChild("PB_BV")
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.Name = "PB_BV"
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Parent = hrp
    end
    
    local bg = hrp:FindFirstChild("PB_BG")
    if not bg then
        bg = Instance.new("BodyGyro")
        bg.Name = "PB_BG"
        bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        bg.Parent = hrp
    end
    return bv, bg
end

local function flyDir()
    local d = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then d = d + cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then d = d - cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then d = d - cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then d = d + cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then d = d - Vector3.new(0, 1, 0) end
    return d.Magnitude > 0 and d.Unit or Vector3.zero
end

-- Fly loop
task.spawn(function()
    while task.wait(0.02) do
        if flyOn and hrp and hrp.Parent then
            local bv, bg = ensureFly()
            bv.Velocity = flyDir() * flySpeed
            bg.CFrame = cam.CFrame
            hum.PlatformStand = true
        else
            if hum then hum.PlatformStand = false end
            local bv = hrp:FindFirstChild("PB_BV")
            local bg = hrp:FindFirstChild("PB_BG")
            if bv then bv:Destroy() end
            if bg then bg:Destroy() end
        end
    end
end)

-- UI Creation
local ui = Instance.new("ScreenGui")
ui.Parent = CoreGui
ui.ResetOnSpawn = false
ui.Name = "PIXEL_BLADE_UI"

local main = Instance.new("Frame", ui)
main.Size = UDim2.new(0, 300, 0, 330)
main.Position = UDim2.new(0.03, 0, 0.32, 0)
main.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
main.Active = true
main.Draggable = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 18)

local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(150, 0, 0)
stroke.Thickness = 3
stroke.Transparency = 0.35

-- Анимация границы
task.spawn(function()
    while true do
        TweenService:Create(stroke, TweenInfo.new(1.5), {Transparency = 0.6}):Play()
        task.wait(1.5)
        TweenService:Create(stroke, TweenInfo.new(1.5), {Transparency = 0.35}):Play()
        task.wait(1.5)
    end
end)

local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, 0, 0, 36)
title.Text = "PIXEL BLADE"
title.Font = Enum.Font.Fantasy
title.TextSize = 22
title.TextColor3 = Color3.fromRGB(170, 0, 0)
title.BackgroundTransparency = 1

local tabs = {}
local pages = {}
local tabNames = {"KILL", "MISC", "SETTINGS"}

for i, n in ipairs(tabNames) do
    local b = Instance.new("TextButton", main)
    b.Size = UDim2.new(0, 90, 0, 24)
    b.Position = UDim2.new(0, (i - 1) * 95 + 10, 0, 38)
    b.Text = n
    b.Font = Enum.Font.Fantasy
    b.TextSize = 14
    b.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    b.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)

    local p = Instance.new("Frame", main)
    p.Size = UDim2.new(1, -20, 1, -74)
    p.Position = UDim2.new(0, 10, 0, 70)
    p.BackgroundTransparency = 1
    p.Visible = false
    p.Name = n
    pages[n] = p

    b.MouseButton1Click:Connect(function()
        for _, pp in pairs(pages) do pp.Visible = false end
        p.Visible = true
    end)

    tabs[n] = b
end

pages["KILL"].Visible = true

-- Функция для создания слайдера
local function slider(parent, y, text, min, max, val, cb)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Position = UDim2.new(0, 0, 0, y - 14)
    lbl.Size = UDim2.new(1, 0, 0, 14)
    lbl.Text = text .. ": " .. val
    lbl.Font = Enum.Font.Fantasy
    lbl.TextSize = 13
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Name = "SliderLabel_" .. text

    local bar = Instance.new("Frame", parent)
    bar.Position = UDim2.new(0.05, 0, 0, y)
    bar.Size = UDim2.new(0.9, 0, 0, 8)
    bar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    bar.Name = "SliderBar_" .. text

    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new((val - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    fill.Name = "SliderFill_" .. text

    local drag = false
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then 
            drag = true 
        end
    end)
    
    bar.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then 
            drag = false 
        end
    end)
    
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local relX = i.Position.X - bar.AbsolutePosition.X
            local p = math.clamp(relX / bar.AbsoluteSize.X, 0, 1)
            fill.Size = UDim2.new(p, 0, 1, 0)
            local v = math.floor(min + (max - min) * p)
            lbl.Text = text .. ": " .. v
            cb(v)
        end
    end)
end

-- KILL TAB
local kill = pages["KILL"]

local auraBtn = Instance.new("TextButton", kill)
auraBtn.Size = UDim2.new(0.9, 0, 0, 26)
auraBtn.Position = UDim2.new(0.05, 0, 0, 0)
auraBtn.Text = "Aura : ON"
auraBtn.Font = Enum.Font.Fantasy
auraBtn.TextSize = 14
auraBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
auraBtn.TextColor3 = Color3.fromRGB(170, 0, 0)
Instance.new("UICorner", auraBtn).CornerRadius = UDim.new(1, 0)

auraBtn.MouseButton1Click:Connect(function()
    auraEnabled = not auraEnabled
    auraBtn.Text = "Aura : " .. (auraEnabled and "ON" or "OFF")
    auraBtn.TextColor3 = auraEnabled and Color3.fromRGB(170, 0, 0) or Color3.fromRGB(200, 200, 200)
end)

local modeBtn = Instance.new("TextButton", kill)
modeBtn.Size = UDim2.new(0.9, 0, 0, 26)
modeBtn.Position = UDim2.new(0.05, 0, 0, 34)
modeBtn.Text = "Mode : Nearest"
modeBtn.Font = Enum.Font.Fantasy
modeBtn.TextSize = 14
modeBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
modeBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", modeBtn).CornerRadius = UDim.new(1, 0)

modeBtn.MouseButton1Click:Connect(function()
    if AuraMode == "Nearest" then 
        AuraMode = "Cone"
    elseif AuraMode == "Cone" then 
        AuraMode = "Burst"
    else 
        AuraMode = "Nearest" 
    end
    modeBtn.Text = "Mode : " .. AuraMode
end)

slider(kill, 78, "Radius", 20, 200, auraRadius, function(v) auraRadius = v end)

-- MISC TAB
local misc = pages["MISC"]

local speedBtn = Instance.new("TextButton", misc)
speedBtn.Size = UDim2.new(0.9, 0, 0, 26)
speedBtn.Position = UDim2.new(0.05, 0, 0, 0)
speedBtn.Text = "Speed : OFF"
speedBtn.Font = Enum.Font.Fantasy
speedBtn.TextSize = 14
speedBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
speedBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
Instance.new("UICorner", speedBtn).CornerRadius = UDim.new(1, 0)

speedBtn.MouseButton1Click:Connect(function()
    speedOn = not speedOn
    speedBtn.Text = "Speed : " .. (speedOn and "ON" or "OFF")
    speedBtn.TextColor3 = speedOn and Color3.fromRGB(170, 0, 0) or Color3.fromRGB(200, 200, 200)
end)

slider(misc, 42, "Speed", 16, 60, speedValue, function(v) speedValue = v end)

local flyBtn = Instance.new("TextButton", misc)
flyBtn.Size = UDim2.new(0.9, 0, 0, 26)
flyBtn.Position = UDim2.new(0.05, 0, 0, 80)
flyBtn.Text = "Fly : OFF"
flyBtn.Font = Enum.Font.Fantasy
flyBtn.TextSize = 14
flyBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
flyBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
Instance.new("UICorner", flyBtn).CornerRadius = UDim.new(1, 0)

flyBtn.MouseButton1Click:Connect(function()
    flyOn = not flyOn
    flyBtn.Text = "Fly : " .. (flyOn and "ON" or "OFF")
    flyBtn.TextColor3 = flyOn and Color3.fromRGB(170, 0, 0) or Color3.fromRGB(200, 200, 200)
end)

slider(misc, 122, "Fly Speed", 16, 80, flySpeed, function(v) flySpeed = v end)

-- SETTINGS TAB
local set = pages["SETTINGS"]

local cfg = Instance.new("TextButton", set)
cfg.Size = UDim2.new(0.9, 0, 0, 26)
cfg.Position = UDim2.new(0.05, 0, 0, 0)
cfg.Text = "Config : Default"
cfg.Font = Enum.Font.Fantasy
cfg.TextSize = 14
cfg.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
cfg.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", cfg).CornerRadius = UDim.new(1, 0)

cfg.MouseButton1Click:Connect(function()
    if cfg.Text:find("Default") then
        auraRadius = 180
        speedValue = 45
        flySpeed = 70
        cfg.Text = "Config : Aggressive"
    else
        auraRadius = 100
        speedValue = 20
        flySpeed = 40
        cfg.Text = "Config : Default"
    end
end)

-- Theme button
local themeBtn = Instance.new("TextButton", set)
themeBtn.Size = UDim2.new(0.9, 0, 0, 26)
themeBtn.Position = UDim2.new(0.05, 0, 0, 35)
themeBtn.Text = "Theme: RED"
themeBtn.Font = Enum.Font.Fantasy
themeBtn.TextSize = 14
themeBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
themeBtn.TextColor3 = Color3.fromRGB(170, 0, 0)
Instance.new("UICorner", themeBtn).CornerRadius = UDim.new(1, 0)

local themes = {"RED", "DARK", "BLACK"}
local currentTheme = 1

local function applyTheme(theme)
    if theme == "RED" then
        main.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
        stroke.Color = Color3.fromRGB(150, 0, 0)
    elseif theme == "DARK" then
        main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        stroke.Color = Color3.fromRGB(100, 100, 100)
    elseif theme == "BLACK" then
        main.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
        stroke.Color = Color3.fromRGB(255, 255, 255)
    end
end

themeBtn.MouseButton1Click:Connect(function()
    currentTheme = currentTheme + 1
    if currentTheme > #themes then currentTheme = 1 end
    themeBtn.Text = "Theme: " .. themes[currentTheme]
    applyTheme(themes[currentTheme])
end)

-- Credits
local credits = Instance.new("TextLabel", set)
credits.Size = UDim2.new(1, 0, 0, 20)
credits.Position = UDim2.new(0, 0, 0, 70)
credits.BackgroundTransparency = 1
credits.Text = "discord: Fog1ch"
credits.Font = Enum.Font.Fantasy
credits.TextSize = 14
credits.TextColor3 = Color3.fromRGB(170, 0, 0)

-- Info text
local info = Instance.new("TextLabel", set)
info.Size = UDim2.new(1, -20, 0, 90)
info.Position = UDim2.new(0, 10, 0, 95)
info.BackgroundTransparency = 1
info.TextWrapped = true
info.TextYAlignment = Enum.TextYAlignment.Top
info.Font = Enum.Font.Fantasy
info.TextSize = 12
info.TextColor3 = Color3.fromRGB(200, 200, 200)
info.Text = "Info:\nWear sword with heavy damage skill.\nAll enemies take damage.\nChange distance in aura radius slider.\nAuto attack works when Aura is ON.\nDodge enemies and stay close."

-- Destroy button
local destroyBtn = Instance.new("TextButton", set)
destroyBtn.Size = UDim2.new(0.9, 0, 0, 26)
destroyBtn.Position = UDim2.new(0.05, 0, 0, 195)
destroyBtn.Text = "DESTROY"
destroyBtn.Font = Enum.Font.Fantasy
destroyBtn.TextSize = 14
destroyBtn.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
destroyBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", destroyBtn).CornerRadius = UDim.new(1, 0)

-- Confirm frame
local confirm = Instance.new("Frame", main)
confirm.Size = UDim2.new(0, 220, 0, 120)
confirm.Position = UDim2.new(0.5, -110, 0.5, -60)
confirm.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
confirm.Visible = false
confirm.ZIndex = 10
Instance.new("UICorner", confirm).CornerRadius = UDim.new(0, 14)

local cStroke = Instance.new("UIStroke", confirm)
cStroke.Color = Color3.fromRGB(170, 0, 0)
cStroke.Thickness = 2
cStroke.ZIndex = 10

local txt = Instance.new("TextLabel", confirm)
txt.Size = UDim2.new(1, -20, 0, 40)
txt.Position = UDim2.new(0, 10, 0, 10)
txt.BackgroundTransparency = 1
txt.Text = "Destroy script?"
txt.Font = Enum.Font.Fantasy
txt.TextSize = 16
txt.TextColor3 = Color3.new(1, 1, 1)
txt.ZIndex = 10

local yes = Instance.new("TextButton", confirm)
yes.Size = UDim2.new(0.4, 0, 0, 26)
yes.Position = UDim2.new(0.08, 0, 0, 70)
yes.Text = "YES"
yes.Font = Enum.Font.Fantasy
yes.TextSize = 14
yes.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
yes.TextColor3 = Color3.new(1, 1, 1)
yes.ZIndex = 10
Instance.new("UICorner", yes).CornerRadius = UDim.new(1, 0)

local no = Instance.new("TextButton", confirm)
no.Size = UDim2.new(0.4, 0, 0, 26)
no.Position = UDim2.new(0.52, 0, 0, 70)
no.Text = "NO"
no.Font = Enum.Font.Fantasy
no.TextSize = 14
no.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
no.TextColor3 = Color3.new(1, 1, 1)
no.ZIndex = 10
Instance.new("UICorner", no).CornerRadius = UDim.new(1, 0)

destroyBtn.MouseButton1Click:Connect(function()
    confirm.Visible = true
end)

no.MouseButton1Click:Connect(function()
    confirm.Visible = false
end)

yes.MouseButton1Click:Connect(function()
    confirm.Visible = false
    
    -- Cleanup
    clearTarget()
    
    if flyOn then
        local bv = hrp:FindFirstChild("PB_BV")
        local bg = hrp:FindFirstChild("PB_BG")
        if bv then bv:Destroy() end
        if bg then bg:Destroy() end
        if hum then hum.PlatformStand = false end
    end
    
    if hum then hum.WalkSpeed = 16 end
    
    -- Destroy UIs
    if ui and ui.Parent then ui:Destroy() end
    
    -- Destroy FPS UI if exists
    local fpsGui = CoreGui:FindFirstChild("FPS_PING_MINI")
    if fpsGui then fpsGui:Destroy() end
    
    warn("PIXEL BLADE DESTROYED")
end)

-- Toggle UI with RightShift
UserInputService.InputBegan:Connect(function(i, g)
    if g then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    elseif i.KeyCode == Enum.KeyCode.Backspace then
        confirm.Visible = true
    end
end)

-- ================= FPS/PING UI =================
local fpsGui = Instance.new("ScreenGui")
fpsGui.Name = "FPS_PING_MINI"
fpsGui.ResetOnSpawn = false
fpsGui.Parent = CoreGui

local fpsFrame = Instance.new("Frame", fpsGui)
fpsFrame.Size = UDim2.new(0, 180, 0, 30)
fpsFrame.Position = UDim2.new(1, -190, 0, 10)
fpsFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
fpsFrame.BackgroundTransparency = 0.1
fpsFrame.Active = true
fpsFrame.Draggable = true
Instance.new("UICorner", fpsFrame).CornerRadius = UDim.new(0, 12)

local fpsLabel = Instance.new("TextLabel", fpsFrame)
fpsLabel.Size = UDim2.new(0.45, 0, 1, 0)
fpsLabel.Position = UDim2.new(0.05, 0, 0, 0)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.TextSize = 14
fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
fpsLabel.Text = "FPS: --"
fpsLabel.TextColor3 = Color3.new(1, 1, 1)

local pingLabel = Instance.new("TextLabel", fpsFrame)
pingLabel.Size = UDim2.new(0.45, 0, 1, 0)
pingLabel.Position = UDim2.new(0.5, 0, 0, 0)
pingLabel.BackgroundTransparency = 1
pingLabel.Font = Enum.Font.GothamBold
pingLabel.TextSize = 14
pingLabel.TextXAlignment = Enum.TextXAlignment.Left
pingLabel.Text = "PING: --"
pingLabel.TextColor3 = Color3.new(1, 1, 1)

local themeBtnFPS = Instance.new("TextButton", fpsFrame)
themeBtnFPS.Size = UDim2.new(0, 20, 0, 20)
themeBtnFPS.Position = UDim2.new(0.9, 0, 0.15, 0)
themeBtnFPS.Text = "T"
themeBtnFPS.Font = Enum.Font.SourceSansBold
themeBtnFPS.TextSize = 14
themeBtnFPS.TextColor3 = Color3.new(1, 1, 1)
themeBtnFPS.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Instance.new("UICorner", themeBtnFPS).CornerRadius = UDim.new(0, 6)

local darkTheme = true
themeBtnFPS.MouseButton1Click:Connect(function()
    darkTheme = not darkTheme
    fpsFrame.BackgroundColor3 = darkTheme and Color3.fromRGB(15, 15, 15) or Color3.fromRGB(230, 230, 230)
    fpsLabel.TextColor3 = darkTheme and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
    pingLabel.TextColor3 = darkTheme and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
    themeBtnFPS.BackgroundColor3 = darkTheme and Color3.fromRGB(35, 35, 35) or Color3.fromRGB(180, 180, 180)
end)

-- FPS counter
local fps, frames, lastTime = 0, 0, tick()
RunService.RenderStepped:Connect(function()
    frames = frames + 1
    if tick() - lastTime >= 1 then
        fps = frames
        frames = 0
        lastTime = tick()
        fpsLabel.Text = "FPS: " .. fps
        fpsLabel.TextColor3 = fps >= 60 and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
    end
end)

-- Ping counter
task.spawn(function()
    while true do
        task.wait(1)
        local success, ping = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        
        if success then
            ping = math.floor(ping)
            pingLabel.Text = "PING: " .. ping .. "ms"
            if ping <= 80 then
                pingLabel.TextColor3 = Color3.fromRGB(0, 200, 0)
            elseif ping <= 150 then
                pingLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
            else
                pingLabel.TextColor3 = Color3.fromRGB(200, 0, 0)
            end
        end
    end
end)
    Title="Pixel Blade v9",
    Content=IsMobile and "Tap icon to toggle  |  Boss DMG fixed" or "L=Aura  RCtrl=Toggle",
    Duration=5,
})

recheckk

