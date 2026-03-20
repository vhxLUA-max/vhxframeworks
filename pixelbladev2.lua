do
    local function nuke(p)
        for _,v in ipairs(p:GetChildren()) do
            if v:IsA("ScreenGui") and (v.Name:find("NexusUI") or v.Name:find("NightLib") or v.Name:find("NebulaUI") or v.Name=="PB_Overlay") then
                pcall(v.Destroy,v)
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

local NexusUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/vhxLUA-max/vhxframework/refs/heads/main/LIB.lua"))()

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
    Flag="mv_jump",
