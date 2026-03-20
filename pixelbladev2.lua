do
    local function nuke(p)
        for _,v in ipairs(p:GetChildren()) do
            if v:IsA("ScreenGui") and (v.Name:find("Fluent") or v.Name=="PB_Overlay" or v.Name=="PB_FPS") then
                pcall(v.Destroy,v)
            end
        end
    end
    pcall(nuke,game:GetService("CoreGui"))
    pcall(nuke,game:GetService("Players").LocalPlayer.PlayerGui)
    if getgenv and getgenv()._PB_Destroy then pcall(getgenv()._PB_Destroy); getgenv()._PB_Destroy=nil end
    task.wait(0.15)
end

if getgenv then getgenv()._PB_SessionStart = getgenv()._PB_SessionStart or tick() end

-- ── Services ──────────────────────────────────────────────────────────────────
local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local UIS          = game:GetService("UserInputService")
local WS           = game:GetService("Workspace")
local Run          = game:GetService("RunService")
local TS           = game:GetService("TeleportService")
local VU           = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local Stats        = game:GetService("Stats")
local CoreGui      = game:GetService("CoreGui")
local HttpService  = game:GetService("HttpService")
local Lighting     = game:GetService("Lighting")
local LP           = Players.LocalPlayer
local Cam          = WS.CurrentCamera

-- ── Device detection ──────────────────────────────────────────────────────────
local IsMobile  = UIS.TouchEnabled and not UIS.KeyboardEnabled
local IsConsole = UIS.GamepadEnabled and not UIS.KeyboardEnabled and not UIS.TouchEnabled
local IsMac = false
do local ok,r = pcall(function() return string.lower(tostring(settings())) end); if ok and r then IsMac = r:find("mac") ~= nil end end

-- ── Low-end detection (fps measured before UI loads) ─────────────────────────
local _isLowEnd = false
do
    local samples, total, start = 0, 0, tick()
    local conn
    conn = Run.RenderStepped:Connect(function(dt)
        samples = samples + 1
        total   = total + dt
        if samples >= 20 then
            conn:Disconnect()
            local avgFps = samples / total
            _isLowEnd = avgFps < 35
        end
    end)
end

-- ── Logger ────────────────────────────────────────────────────────────────────
local SUPABASE_URL = "https://wmmslqlvgdpmruhdgbqf.supabase.co"
local SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndtbXNscWx2Z2RwbXJ1aGRnYnFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4OTIyNDUsImV4cCI6MjA4ODQ2ODI0NX0.Id_TLPX7GnJ9YCzspUUSYaNZSDzMK6vHQ6jGzxsbla4"
local httpReq = http_request or request or (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request) or nil
local _playerToken = nil

if httpReq then
    local CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local function genToken()
        local t = table.create(5)
        for i = 1,5 do t[i] = CHARS:sub(math.random(1,#CHARS),math.random(1,#CHARS)) end
        return table.concat(t)
    end
    local HDR = {["apikey"]=SUPABASE_KEY,["Authorization"]="Bearer "..SUPABASE_KEY}
    local function GET(ep)
        local ok,r = pcall(httpReq,{Url=SUPABASE_URL..ep,Method="GET",Headers=HDR})
        return ok and r or nil
    end
    local function POST(ep,body,prefer)
        local h = {["apikey"]=SUPABASE_KEY,["Authorization"]="Bearer "..SUPABASE_KEY,["Content-Type"]="application/json",["Prefer"]=prefer or "resolution=merge-duplicates,return=minimal"}
        pcall(httpReq,{Url=SUPABASE_URL..ep,Method="POST",Headers=h,Body=type(body)=="string" and body or HttpService:JSONEncode(body)})
    end
    task.spawn(function()
        local pid  = game.PlaceId
        local now  = os.date("!%Y-%m-%dT%H:%M:%SZ")
        POST("/rest/v1/rpc/increment_execution",'{"p_place_id":'..pid..'}')
        local res  = GET(("/rest/v1/unique_users?roblox_user_id=eq.%d&place_id=eq.%d&select=token,first_seen"):format(LP.UserId,pid))
        local token,firstSeen,isNew = nil,now,true
        if res and res.Body then
            local ok,data = pcall(HttpService.JSONDecode,HttpService,res.Body)
            if ok and data and #data>0 then token=data[1].token; firstSeen=data[1].first_seen or now; isNew=false end
        end
        token = token or genToken()
        local row = {roblox_user_id=LP.UserId,username=LP.Name,place_id=pid,execution_count=1,first_seen=firstSeen,last_seen=now}
        if isNew then row.token=token end
        POST("/rest/v1/unique_users?on_conflict=roblox_user_id,place_id",row)
        _playerToken = token
        if getgenv then getgenv()._vhxToken = token end
    end)
end

-- ── UI Libs ───────────────────────────────────────────────────────────────────
local Fluent           = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager      = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ── Constants (device-adaptive) ───────────────────────────────────────────────
local POTION_NAMES     = {"HealthFlask","DragonFlask","EnergyFlask"}
local INTERVAL_OPTIONS = {1,5,10,20,30}
local INTERVAL_STRS    = {"1s","5s","10s","20s","30s"}
local MAX_TARGETS      = _isLowEnd and 5 or 10
local MIN_INTERVAL     = 0.08
local BOSS_DAMAGE      = {BookHand=5000,Throne9=5000}
local POOL_SIZE        = _isLowEnd and 32 or 64
local RAID_POOL_SIZE   = _isLowEnd and 16 or 32
local V3Z              = Vector3.zero
local COS45            = math.cos(math.rad(45))
local ESP_INTERVAL     = _isLowEnd and 0.2 or 0.1
local CACHE_INTERVAL   = _isLowEnd and 1.0 or 0.5
local REFRESH_INTERVAL = _isLowEnd and 0.75 or 0.5

-- ── State ─────────────────────────────────────────────────────────────────────
getgenv().S = getgenv().S or {
    KillAura=false,AuraRange=100,WalkSpeed=50,JumpPower=100,AttackSpeed=0.15,
    AntiAFK=false,ESP=false,Tracers=false,
    ESPColor=Color3.fromRGB(255,0,0),TracerColor=Color3.fromRGB(0,255,0),
    ShowNames=true,ShowHealth=true,ShowDistance=true,TracerOrigin="Bottom",
    AutoDrink=false,DrinkPotions={},DrinkThreshold=50,
    AutoBuy=false,BuyPotions={},BuyInterval=10,BuyQty=1,BuyMax=0,BuyTotal=0,
    AutoTween=false,TweenSpeed=0.12,
    RaidAura=false,RaidAuraRange=100,RaidAuraMode="Nearest",RaidLastBurst=0,RaidBurstCD=5,
    AuraMode="Nearest",BurstCooldown=5,_lastBurst=0,
    Fly=false,FlySpeed=50,
    AutoOptimize=_isLowEnd,
}
local S = getgenv().S

-- ── Auto-optimize on low-end ──────────────────────────────────────────────────
local function optimizeGraphics()
    pcall(function() settings().Rendering.QualityLevel=Enum.QualityLevel.Level01 end)
    pcall(function()
        Lighting.GlobalShadows=false; Lighting.FogEnd=100000
        for _,v in ipairs(Lighting:GetChildren()) do
            if v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") then v.Enabled=false end
        end
    end)
    pcall(function()
        local descs = WS:GetDescendants()
        for i=1,#descs do
            local p=descs[i]
            if p:IsA("ParticleEmitter") or p:IsA("Trail") then p.Enabled=false end
        end
    end)
    if Fluent then Fluent:Notify({Title="Optimized",Content="Graphics lowered for performance.",Duration=4}) end
end

if _isLowEnd then task.spawn(optimizeGraphics) end

-- ── FPS Widget ────────────────────────────────────────────────────────────────
local _fpsGui   = Instance.new("ScreenGui")
_fpsGui.Name="PB_FPS"; _fpsGui.ResetOnSpawn=false; _fpsGui.DisplayOrder=999; _fpsGui.Parent=CoreGui
local _fpsFrame = Instance.new("Frame")
_fpsFrame.Size=UDim2.new(0,110,0,28)
_fpsFrame.Position=IsMobile and UDim2.new(0,10,0,10) or UDim2.new(1,-120,0,10)
_fpsFrame.BackgroundColor3=Color3.fromRGB(10,10,10); _fpsFrame.BackgroundTransparency=0.25
_fpsFrame.Active=true; _fpsFrame.Draggable=true; _fpsFrame.Parent=_fpsGui
Instance.new("UICorner",_fpsFrame).CornerRadius=UDim.new(0,8)
local _fpsLbl = Instance.new("TextLabel")
_fpsLbl.Size=UDim2.new(1,0,1,0); _fpsLbl.BackgroundTransparency=1
_fpsLbl.Font=Enum.Font.GothamBold; _fpsLbl.TextSize=13
_fpsLbl.TextColor3=Color3.new(1,1,1); _fpsLbl.Text="FPS: -- | --ms"; _fpsLbl.Parent=_fpsFrame

local _pi; pcall(function() _pi=Stats.Network.ServerStatsItem["Data Ping"] end)
local fps,ping,_fpsF,_fpsDt,_pingT = 0,0,0,0,0
local _fpsUpdateRate = _isLowEnd and 2 or 1

Run.RenderStepped:Connect(function(dt)
    _fpsF=_fpsF+1; _fpsDt=_fpsDt+dt
    if _fpsDt<_fpsUpdateRate then return end
    fps=math.floor(_fpsF/_fpsDt); _fpsF=0; _fpsDt=0
    _fpsLbl.TextColor3 = fps>=60 and Color3.fromRGB(0,220,0) or fps>=30 and Color3.fromRGB(255,170,0) or Color3.fromRGB(220,0,0)
    _fpsLbl.Text="FPS: "..fps.." | "..ping.."ms"
end)

-- ── Connection pool ───────────────────────────────────────────────────────────
local conns = {}
local function Cn(c) conns[#conns+1]=c; return c end
local function KillConns() for i=1,#conns do pcall(conns[i].Disconnect,conns[i]) end; conns={} end

-- ── Remotes ───────────────────────────────────────────────────────────────────
local Rem         = RS:FindFirstChild("remotes")
local HitEv       = Rem and Rem:FindFirstChild("onHit")
local ClaimEv     = Rem and Rem:FindFirstChild("claimCode")
local DrinkEv     = Rem and Rem:FindFirstChild("drinkPotion")
local BuyEv       = Rem and Rem:FindFirstChild("requestPurchase")
local swingRemote = Rem and Rem:FindFirstChild("swing")
local blockRemote = Rem and Rem:FindFirstChild("block")

-- ── Enemy pool ────────────────────────────────────────────────────────────────
local _enemies = table.create(POOL_SIZE)
for i=1,POOL_SIZE do _enemies[i]={model=nil,humanoid=nil,root=nil} end
local _enemyCount  = 0
local _cachedChar  = nil
local _wsDirty     = true
local _wsCache     = {}
local _wsCacheTimer,_refreshTimer = 0,0

local function _rebuildWSCache()
    table.clear(_wsCache)
    local n=0
    for _,v in ipairs(WS:GetDescendants()) do
        if v:IsA("Model") then n=n+1; _wsCache[n]=v end
    end
end

WS.DescendantAdded:Connect(function(d) if d:IsA("Model") then _wsDirty=true end end)
WS.DescendantRemoving:Connect(function(d) if d:IsA("Model") then _wsDirty=true end end)

local function _refreshEnemies()
    _cachedChar=LP.Character
    local char=_cachedChar
    local myRP=char and char:FindFirstChild("HumanoidRootPart")
    if not myRP or not (S.KillAura or S.ESP or S.Tracers or S.AutoTween) then _enemyCount=0; return end
    local myPos=myRP.Position
    local mx,my,mz=myPos.X,myPos.Y,myPos.Z
    local scanRange=(S.ESP or S.Tracers) and 2000 or S.AuraRange
    if S.AuraRange>scanRange then scanRange=S.AuraRange end
    local sr2=scanRange*scanRange
    local idx=0
    for i=1,#_wsCache do
        if idx>=POOL_SIZE then break end
        local m=_wsCache[i]
        if not m or not m.Parent or m==char then continue end
        local h=m:FindFirstChildOfClass("Humanoid")
        if not h or h.Health<=0 then continue end
        local rp=m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso") or m:FindFirstChild("UpperTorso") or m.PrimaryPart
        if not rp then continue end
        local rpos=rp.Position
        local dx,dy,dz=rpos.X-mx,rpos.Y-my,rpos.Z-mz
        if dx*dx+dy*dy+dz*dz<=sr2 then
            idx=idx+1
            local s=_enemies[idx]; s.model=m; s.humanoid=h; s.root=rp
        end
    end
    _enemyCount=idx
end

-- ── Master Heartbeat ──────────────────────────────────────────────────────────
Cn(Run.Heartbeat:Connect(function(dt)
    _pingT=_pingT+dt
    if _pingT>=2 then
        _pingT=0
        if _pi then local ok,v=pcall(_pi.GetValue,_pi); if ok and v then ping=math.floor(v) end end
    end
    _wsCacheTimer=_wsCacheTimer+dt
    if _wsDirty and _wsCacheTimer>=CACHE_INTERVAL then _wsCacheTimer=0; _wsDirty=false; _rebuildWSCache() end
    _refreshTimer=_refreshTimer+dt
    if _refreshTimer>=REFRESH_INTERVAL then _refreshTimer=0; _refreshEnemies() end
end))

local LevelStartEv=Rem and Rem:FindFirstChild("levelStart")
if LevelStartEv then
    Cn(LevelStartEv.OnClientEvent:Connect(function() _enemyCount=0; _wsDirty=true; task.wait(0.5); _refreshEnemies() end))
end

-- ── Damage confirmation ───────────────────────────────────────────────────────
local _damageable,_hpSnapshot,_cleanTimer = {},{},0
local function recordSnapshot()
    for i=1,_enemyCount do local e=_enemies[i]; if e.model then _hpSnapshot[e.model]=e.humanoid.Health end end
end
local function confirmDamageable()
    for i=1,_enemyCount do
        local e=_enemies[i]
        if e.model then local p=_hpSnapshot[e.model]; if p and e.humanoid.Health<p then _damageable[e.model]=true end end
    end
end
Cn(Run.Heartbeat:Connect(function(dt)
    _cleanTimer=_cleanTimer+dt
    if _cleanTimer<10 then return end
    _cleanTimer=0
    local alive={}
    for i=1,_enemyCount do if _enemies[i].model then alive[_enemies[i].model]=true end end
    for k in next,_damageable do if not alive[k] then _damageable[k]=nil end end
    for k in next,_hpSnapshot do if not alive[k] then _hpSnapshot[k]=nil end end
end))

-- ── AutoTween ─────────────────────────────────────────────────────────────────
local _activeTween,_tweenTarget,_tweenDiedConn=nil,nil,nil
local function stopTween()
    if _activeTween then _activeTween:Cancel(); _activeTween=nil end
    _tweenTarget=nil
    if _tweenDiedConn then _tweenDiedConn:Disconnect(); _tweenDiedConn=nil end
end
local function getNearestEnemy()
    local char=LP.Character
    local myR=char and char:FindFirstChild("HumanoidRootPart")
    if not myR then return nil end
    local myPos=myR.Position; local best,bestDist=nil,math.huge
    for i=1,_enemyCount do
        local e=_enemies[i]
        if e.humanoid and e.humanoid.Health>0 and e.root and _damageable[e.model] then
            local d=(myPos-e.root.Position).Magnitude
            if d<bestDist then bestDist=d; best=e end
        end
    end
    return best
end
Cn(Run.Heartbeat:Connect(function()
    if not S.AutoTween then if _activeTween then stopTween() end; return end
    local char=LP.Character
    local myR=char and char:FindFirstChild("HumanoidRootPart")
    if not myR then stopTween(); return end
    local e=getNearestEnemy()
    if not e or not e.root or not e.root.Parent then stopTween(); return end
    if _tweenTarget==e.model and _activeTween and _activeTween.PlaybackState==Enum.PlaybackState.Playing then return end
    stopTween()
    _tweenTarget=e.model
    local dir=e.root.Position-myR.Position; local dist=dir.Magnitude
    if dist<5 then return end
    local info=TweenInfo.new(math.clamp(dist/80,S.TweenSpeed,0.5),Enum.EasingStyle.Linear)
    _activeTween=TweenService:Create(myR,info,{CFrame=CFrame.new(e.root.Position-dir.Unit*4,e.root.Position)})
    _activeTween:Play()
    _tweenDiedConn=e.humanoid.Died:Connect(stopTween)
end))

-- ── Raid Aura ─────────────────────────────────────────────────────────────────
local RAID_IGNORED={["teeth trap"]=true,["Teeth Trap"]=true,["teeth_trap"]=true,["Teeth_Trap"]=true}
local _raidPool=table.create(RAID_POOL_SIZE)
for i=1,RAID_POOL_SIZE do _raidPool[i]={humanoid=nil} end

local function getRaidEnemies()
    local char=LP.Character
    local myR=char and char:FindFirstChild("HumanoidRootPart")
    if not myR then return _raidPool,0 end
    local mode=S.RaidAuraMode
    if mode=="Burst" then if tick()-S.RaidLastBurst<S.RaidBurstCD then return _raidPool,0 end; S.RaidLastBurst=tick() end
    local myPos=myR.Position; local mx,my,mz=myPos.X,myPos.Y,myPos.Z
    local r2=S.RaidAuraRange*S.RaidAuraRange
    local doCone=mode=="Cone"
    local camCF=doCone and Cam.CFrame or nil
    local lookVec=doCone and camCF.LookVector or nil
    local camPos=doCone and camCF.Position or nil
    local idx=0
    for i=1,#_wsCache do
        if idx>=RAID_POOL_SIZE then break end
        local m=_wsCache[i]
        if not m or not m.Parent or m==char or RAID_IGNORED[m.Name] then continue end
        local h=m:FindFirstChild("Humanoid"); local rp=m:FindFirstChild("HumanoidRootPart")
        if not h or not rp or h.Health<=0 then continue end
        local rpPos=rp.Position
        local dx,dy,dz=rpPos.X-mx,rpPos.Y-my,rpPos.Z-mz
        if dx*dx+dy*dy+dz*dz>r2 then continue end
        if doCone then
            local ex,ey,ez=rpPos.X-camPos.X,rpPos.Y-camPos.Y,rpPos.Z-camPos.Z
            local mag=math.sqrt(ex*ex+ey*ey+ez*ez)
            if mag>0 and lookVec.X*(ex/mag)+lookVec.Y*(ey/mag)+lookVec.Z*(ez/mag)<COS45 then continue end
        end
        idx=idx+1; _raidPool[idx].humanoid=h
    end
    return _raidPool,idx
end

local _raidTimer,_blockTimer=0,0
local _raidAttackInterval = _isLowEnd and 0.4 or 0.3
Cn(Run.Heartbeat:Connect(function(dt)
    if not S.RaidAura then return end
    _raidTimer=_raidTimer+dt; _blockTimer=_blockTimer+dt
    if _blockTimer>=0.1 then
        _blockTimer=0
        if blockRemote and blockRemote.Parent then local _=pcall(blockRemote.FireServer,blockRemote,true) end
    end
    if _raidTimer>=_raidAttackInterval then
        _raidTimer=0
        local list,n=getRaidEnemies()
        if n>0 then
            if swingRemote and swingRemote.Parent then local _=pcall(swingRemote.FireServer,swingRemote) end
            if HitEv and HitEv.Parent then
                for i=1,n do if list[i].humanoid then local _=pcall(HitEv.FireServer,HitEv,list[i].humanoid,9999999999,{},0) end end
            end
        end
    end
end))

-- ── Fly ───────────────────────────────────────────────────────────────────────
local _flyBV,_flyBG=nil,nil
local function stopFly()
    S.Fly=false
    local char=LP.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if hrp then local bv=hrp:FindFirstChild("PB_FlyBV"); if bv then bv:Destroy() end; local bg=hrp:FindFirstChild("PB_FlyBG"); if bg then bg:Destroy() end end
    if hum then hum.PlatformStand=false end
    _flyBV=nil; _flyBG=nil
end
local function startFly()
    stopFly(); S.Fly=true
    local char=LP.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    hum.PlatformStand=true
    _flyBV=Instance.new("BodyVelocity"); _flyBV.Name="PB_FlyBV"; _flyBV.MaxForce=Vector3.new(1e5,1e5,1e5); _flyBV.Velocity=V3Z; _flyBV.Parent=hrp
    _flyBG=Instance.new("BodyGyro"); _flyBG.Name="PB_FlyBG"; _flyBG.MaxTorque=Vector3.new(1e5,1e5,1e5); _flyBG.Parent=hrp
end

-- Mobile/Console fly support via virtual joystick direction
local function getFlyDirection()
    local dx,dy,dz=0,0,0
    local cf=Cam.CFrame
    if IsMobile or IsConsole then
        -- Use thumbstick for movement on mobile/console
        local ls=UIS:GetConnectedGamepads()[1]
        if ls then
            local lv=UIS:GetGamepadState(ls)
            for _,v in ipairs(lv) do
                if v.KeyCode==Enum.KeyCode.Thumbstick1 then
                    local pos=v.Position
                    dx=dx+cf.LookVector.X*pos.Y+cf.RightVector.X*pos.X
                    dy=dy+cf.LookVector.Y*pos.Y+cf.RightVector.Y*pos.X
                    dz=dz+cf.LookVector.Z*pos.Y+cf.RightVector.Z*pos.X
                end
            end
        end
        if UIS:IsKeyDown(Enum.KeyCode.ButtonA) then dy=dy+1 end
        if UIS:IsKeyDown(Enum.KeyCode.ButtonB) then dy=dy-1 end
    else
        if UIS:IsKeyDown(Enum.KeyCode.W)           then dx=dx+cf.LookVector.X; dy=dy+cf.LookVector.Y; dz=dz+cf.LookVector.Z end
        if UIS:IsKeyDown(Enum.KeyCode.S)           then dx=dx-cf.LookVector.X; dy=dy-cf.LookVector.Y; dz=dz-cf.LookVector.Z end
        if UIS:IsKeyDown(Enum.KeyCode.A)           then dx=dx-cf.RightVector.X; dy=dy-cf.RightVector.Y; dz=dz-cf.RightVector.Z end
        if UIS:IsKeyDown(Enum.KeyCode.D)           then dx=dx+cf.RightVector.X; dy=dy+cf.RightVector.Y; dz=dz+cf.RightVector.Z end
        if UIS:IsKeyDown(Enum.KeyCode.Space)       then dy=dy+1 end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dy=dy-1 end
    end
    return dx,dy,dz
end

Cn(Run.Heartbeat:Connect(function()
    if not S.Fly then return end
    local char=LP.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then stopFly(); return end
    if not _flyBV or not _flyBV.Parent then startFly(); return end
    hum.PlatformStand=true
    local dx,dy,dz=getFlyDirection()
    local mag=math.sqrt(dx*dx+dy*dy+dz*dz)
    _flyBV.Velocity=mag>0 and Vector3.new(dx/mag*S.FlySpeed,dy/mag*S.FlySpeed,dz/mag*S.FlySpeed) or V3Z
    _flyBG.CFrame=Cam.CFrame
end))
Cn(LP.CharacterAdded:Connect(function() _flyBV=nil; _flyBG=nil; if S.Fly then task.wait(1); startFly() end end))

-- ── ESP (skipped on low-end to save performance) ─────────────────────────────
local ESP,_activeModels={},{}
local function clearESP()
    for _,d in next,ESP do
        for i=1,4 do pcall(d.box[i].Remove,d.box[i]) end
        pcall(d.nl.Remove,d.nl); pcall(d.hb.Remove,d.hb); pcall(d.hf.Remove,d.hf); pcall(d.dl.Remove,d.dl); pcall(d.tr.Remove,d.tr)
    end
    table.clear(ESP)
end
local function mkESP(m)
    if ESP[m] then return end
    local function L(t,zi) local l=Drawing.new(t); l.Visible=false; l.ZIndex=zi; return l end
    local b1,b2,b3,b4=L("Line",5),L("Line",5),L("Line",5),L("Line",5)
    b1.Thickness=1.5; b2.Thickness=1.5; b3.Thickness=1.5; b4.Thickness=1.5
    local nl=L("Text",6); nl.Size=9; nl.Outline=true; nl.OutlineColor=Color3.new(0,0,0); nl.Center=true
    local hb=L("Line",5); hb.Thickness=3; hb.Color=Color3.new(0,0,0)
    local hf=L("Line",6); hf.Thickness=3
    local dl=L("Text",6); dl.Size=8; dl.Outline=true; dl.OutlineColor=Color3.new(0,0,0); dl.Center=true
    local tr=L("Line",4); tr.Thickness=1
    ESP[m]={box={b1,b2,b3,b4},nl=nl,hb=hb,hf=hf,dl=dl,tr=tr}
end
local function rmESP(m)
    local d=ESP[m]; if not d then return end
    for i=1,4 do pcall(d.box[i].Remove,d.box[i]) end
    pcall(d.nl.Remove,d.nl); pcall(d.hb.Remove,d.hb); pcall(d.hf.Remove,d.hf); pcall(d.dl.Remove,d.dl); pcall(d.tr.Remove,d.tr)
    ESP[m]=nil
end
local HW,HH=2,2.75
local _corners={Vector3.new(-HW,-HH,0),Vector3.new(HW,-HH,0),Vector3.new(HW,HH,0),Vector3.new(-HW,HH,0)}
local function bounds(r)
    local cf=r.CFrame; local x0,y0,x1,y1=math.huge,math.huge,-math.huge,-math.huge
    for i=1,4 do
        local sp,vis=Cam:WorldToViewportPoint((cf*CFrame.new(_corners[i])).Position)
        if not vis then return nil end
        if sp.X<x0 then x0=sp.X end; if sp.Y<y0 then y0=sp.Y end
        if sp.X>x1 then x1=sp.X end; if sp.Y>y1 then y1=sp.Y end
    end
    return x0,y0,x1,y1
end
local function hideESPEntry(d)
    for i=1,4 do d.box[i].Visible=false end
    d.nl.Visible=false; d.hb.Visible=false; d.hf.Visible=false; d.dl.Visible=false; d.tr.Visible=false
end
local _espTimer=0
Cn(Run.Heartbeat:Connect(function(dt)
    _espTimer=_espTimer+dt
    if _espTimer<ESP_INTERVAL then return end
    _espTimer=0
    if not S.ESP and not S.Tracers then
        for _,d in next,ESP do hideESPEntry(d) end; return
    end
    local char=_cachedChar or LP.Character
    local myR=char and char:FindFirstChild("HumanoidRootPart")
    local vp=Cam.ViewportSize
    local tO=S.TracerOrigin~="Center" and Vector2.new(vp.X*.5,vp.Y) or Vector2.new(vp.X*.5,vp.Y*.5)
    table.clear(_activeModels)
    for i=1,_enemyCount do
        local e=_enemies[i]
        if e.model and e.model.Parent and e.humanoid and e.humanoid.Health>0 then
            _activeModels[e.model]=true
            if not ESP[e.model] then mkESP(e.model) end
        end
    end
    for m in next,ESP do if not _activeModels[m] then rmESP(m) end end
    for m,d in next,ESP do
        local h=m:FindFirstChildOfClass("Humanoid")
        local r=m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
        if not r or not h then hideESPEntry(d); continue end
        local sp,vis=Cam:WorldToViewportPoint(r.Position)
        local dist=myR and (myR.Position-r.Position).Magnitude or 0
        if S.ESP then
            local x0,y0,x1,y1=bounds(r)
            if x0 and vis then
                local ec=S.ESPColor; local b=d.box; local mx=(x0+x1)*.5
                b[1].From=Vector2.new(x0,y0); b[1].To=Vector2.new(x1,y0); b[1].Color=ec; b[1].Visible=true
                b[2].From=Vector2.new(x0,y1); b[2].To=Vector2.new(x1,y1); b[2].Color=ec; b[2].Visible=true
                b[3].From=Vector2.new(x0,y0); b[3].To=Vector2.new(x0,y1); b[3].Color=ec; b[3].Visible=true
                b[4].From=Vector2.new(x1,y0); b[4].To=Vector2.new(x1,y1); b[4].Color=ec; b[4].Visible=true
                if S.ShowNames then d.nl.Text=m.Name; d.nl.Color=ec; d.nl.Position=Vector2.new(mx,y0-18); d.nl.Visible=true else d.nl.Visible=false end
                if S.ShowHealth then
                    local hr=math.clamp(h.Health/h.MaxHealth,0,1)
                    d.hb.From=Vector2.new(x0-6,y0); d.hb.To=Vector2.new(x0-6,y1); d.hb.Visible=true
                    d.hf.From=Vector2.new(x0-6,y1); d.hf.To=Vector2.new(x0-6,y1-(y1-y0)*hr)
                    d.hf.Color=Color3.fromRGB(math.floor((1-hr)*255),math.floor(hr*255),0); d.hf.Visible=true
                else d.hb.Visible=false; d.hf.Visible=false end
                if S.ShowDistance then d.dl.Text=math.floor(dist).."m"; d.dl.Position=Vector2.new(mx,y1+3); d.dl.Visible=true else d.dl.Visible=false end
            else
                for i=1,4 do d.box[i].Visible=false end
                d.nl.Visible=false; d.hb.Visible=false; d.hf.Visible=false; d.dl.Visible=false
            end
        else
            for i=1,4 do d.box[i].Visible=false end
            d.nl.Visible=false; d.hb.Visible=false; d.hf.Visible=false; d.dl.Visible=false
        end
        if S.Tracers and vis then d.tr.From=tO; d.tr.To=Vector2.new(sp.X,sp.Y); d.tr.Color=S.TracerColor; d.tr.Visible=true else d.tr.Visible=false end
    end
end))

-- ── Speed / Character ─────────────────────────────────────────────────────────
local function applySpeed()
    local c=LP.Character; if not c then return end
    local h=c:FindFirstChildOfClass("Humanoid"); if not h then return end
    h.WalkSpeed=S.WalkSpeed; h.JumpPower=S.JumpPower
end
local function hookCharacter(char)
    local h=char:WaitForChild("Humanoid",5); if not h then return end
    applySpeed()
    Cn(h:GetPropertyChangedSignal("WalkSpeed"):Connect(function() if math.abs(h.WalkSpeed-S.WalkSpeed)>0.5 then h.WalkSpeed=S.WalkSpeed end end))
    Cn(h:GetPropertyChangedSignal("JumpPower"):Connect(function() if math.abs(h.JumpPower-S.JumpPower)>0.5 then h.JumpPower=S.JumpPower end end))
end
if LP.Character then hookCharacter(LP.Character) end
Cn(LP.CharacterAdded:Connect(hookCharacter))

-- ── Kill Aura ─────────────────────────────────────────────────────────────────
local _auraTimer=0
local function _getDmg(m) return BOSS_DAMAGE[m.Name] or 5000 end
Cn(Run.Heartbeat:Connect(function(dt)
    if not S.KillAura or not HitEv or not HitEv.Parent then return end
    _auraTimer=_auraTimer+dt
    local interval=math.max(S.AttackSpeed,MIN_INTERVAL)
    if _auraTimer<interval then return end
    _auraTimer=0
    local char=LP.Character; if not char then return end
    local myR=char:FindFirstChild("HumanoidRootPart"); if not myR then return end
    local myPos=myR.Position; local count=0
    local mode=S.AuraMode
    if mode=="Burst" then if tick()-S._lastBurst<S.BurstCooldown then return end; S._lastBurst=tick() end
    local camCF=Cam.CFrame; local lookVec=camCF.LookVector; local camPos=camCF.Position
    local range=S.AuraRange; local range2=range*range
    recordSnapshot()
    for i=1,_enemyCount do
        if count>=MAX_TARGETS then break end
        local e=_enemies[i]
        local h,rp,m=e.humanoid,e.root,e.model
        if not h or not h.Parent or h.Health<=0 or not rp then continue end
        local dx,dy,dz=rp.Position.X-myPos.X,rp.Position.Y-myPos.Y,rp.Position.Z-myPos.Z
        if dx*dx+dy*dy+dz*dz>range2 then continue end
        if mode=="Cone" then
            local ex,ey,ez=rp.Position.X-camPos.X,rp.Position.Y-camPos.Y,rp.Position.Z-camPos.Z
            local mag=math.sqrt(ex*ex+ey*ey+ez*ez)
            if mag>0 and lookVec.X*(ex/mag)+lookVec.Y*(ey/mag)+lookVec.Z*(ez/mag)<COS45 then continue end
        end
        local _=pcall(HitEv.FireServer,HitEv,h,_getDmg(m),{},0); count=count+1
    end
    task.delay(0.2,confirmDamageable)
end))

-- ── Auto Drink ────────────────────────────────────────────────────────────────
local _drinkThread=nil
local function stopDrink() if _drinkThread then task.cancel(_drinkThread); _drinkThread=nil end end
local function startDrink()
    stopDrink()
    if not DrinkEv or not DrinkEv.Parent then Fluent:Notify({Title="Auto Drink",Content="drinkPotion remote not found!",Duration=3}); return end
    _drinkThread=task.spawn(function()
        while S.AutoDrink do
            task.wait(0.5)
            local char=LP.Character; local h=char and char:FindFirstChildOfClass("Humanoid")
            if h and h.Health>0 and h.MaxHealth>0 and (h.Health/h.MaxHealth)*100<=S.DrinkThreshold then
                local _=pcall(DrinkEv.FireServer,DrinkEv); task.wait(0.5)
            end
        end
    end)
end

-- ── Auto Buy ──────────────────────────────────────────────────────────────────
local _buyThread=nil
local function stopBuy() if _buyThread then task.cancel(_buyThread); _buyThread=nil end end
local function startBuy()
    stopBuy()
    if not BuyEv or not BuyEv.Parent then Fluent:Notify({Title="Auto Buy",Content="requestPurchase remote not found!",Duration=3}); return end
    S.BuyTotal=0
    _buyThread=task.spawn(function()
        while S.AutoBuy do
            if #S.BuyPotions==0 then task.wait(1); continue end
            if S.BuyMax>0 and S.BuyTotal>=S.BuyMax then
                S.AutoBuy=false; Fluent:Notify({Title="Auto Buy",Content="Max purchases ("..S.BuyMax..") reached!",Duration=4}); break
            end
            local qty=math.max(1,S.BuyQty)
            if S.BuyMax>0 then qty=math.min(qty,S.BuyMax-S.BuyTotal) end
            for _,pn in ipairs(S.BuyPotions) do
                for i=1,qty do local _=pcall(BuyEv.FireServer,BuyEv,pn,"potion"); task.wait(0.15) end
            end
            S.BuyTotal=S.BuyTotal+qty*math.max(1,#S.BuyPotions)
            task.wait(S.BuyInterval)
        end
    end)
end

-- ── Anti-AFK ──────────────────────────────────────────────────────────────────
local afkConn
local function setAFK(v)
    S.AntiAFK=v
    if afkConn then afkConn:Disconnect(); afkConn=nil end
    if v then afkConn=Run.Heartbeat:Connect(function()
        local _=pcall(VU.CaptureController,VU)
        local _2=pcall(VU.ClickButton2,VU,Vector2.new())
    end) end
end

-- ── Misc helpers ──────────────────────────────────────────────────────────────
local Codes={"BREAKABLES","AncientSands","PLUSHIE","625K","CrimsonNightmare","600K","575K","550K","FREEWISH","World4","525K","Rings","Alpha","Theo","FBG"}
local claimed=false
local function claim()
    if claimed or not ClaimEv or not ClaimEv.Parent then
        if not ClaimEv then Fluent:Notify({Title="Codes",Content="Remote not found.",Duration=3}) end; return
    end
    claimed=true
    for _,code in next,Codes do local _=pcall(ClaimEv.InvokeServer,ClaimEv,code); task.wait(0.3) end
end

local function rejoin()
    pcall(function() TS:Teleport(game.PlaceId,LP) end)
    task.delay(2,function() pcall(function() TS:TeleportToPlaceInstance(game.PlaceId,game.JobId,LP) end) end)
end

-- ── Window (size adaptive) ────────────────────────────────────────────────────
local winW = IsMobile and 480 or 580
local winH = IsMobile and 400 or 460

local Win = Fluent:CreateWindow({
    Title="Pixel Blade",SubTitle="By vhxLUA",
    TabWidth=160,Size=UDim2.fromOffset(winW,winH),
    Acrylic=not _isLowEnd,
    Theme="Dark",
    MinimizeKey=Enum.KeyCode.RightControl,
})

local Tabs={
    Combat   = Win:AddTab({Title="Combat",   Icon="sword"   }),
    Raid     = Win:AddTab({Title="Raid",     Icon="flame"   }),
    ESP      = Win:AddTab({Title="ESP",      Icon="eye"     }),
    Movement = Win:AddTab({Title="Movement", Icon="zap"     }),
    Potions  = Win:AddTab({Title="Potions",  Icon="heart"   }),
    Misc     = Win:AddTab({Title="Misc",     Icon="shield"  }),
    Settings = Win:AddTab({Title="Settings", Icon="settings"}),
}
local CT=Tabs.Combat; local RT=Tabs.Raid; local ET=Tabs.ESP
local MT=Tabs.Movement; local PT=Tabs.Potions; local MiT=Tabs.Misc; local ST=Tabs.Settings

-- Combat
CT:AddParagraph({Title="Boss Warning",Content="Disable Kill Aura during boss spawn cutscenes."})
local AuraToggle=CT:AddToggle("KillAura",{Title="Kill Aura",Description="Hits nearby enemies",Default=S.KillAura,Callback=function(v) S.KillAura=v end})
CT:AddSlider("AuraRange",{Title="Aura Range",Min=0,Max=1000,Default=S.AuraRange,Suffix=" studs",Rounding=0,Callback=function(v) S.AuraRange=v end})
CT:AddSlider("AttackInterval",{Title="Attack Interval",Min=80,Max=2000,Default=math.floor(S.AttackSpeed*1000),Suffix=" ms",Rounding=0,Callback=function(v) S.AttackSpeed=v/1000 end})
CT:AddDropdown("AuraMode",{Title="Aura Mode",Values={"Nearest","Cone","Burst"},Default=S.AuraMode,Callback=function(v) S.AuraMode=v end})
CT:AddSlider("BurstCooldown",{Title="Burst Cooldown",Min=1,Max=30,Default=S.BurstCooldown,Suffix="s",Rounding=0,Callback=function(v) S.BurstCooldown=v end})
CT:AddToggle("AutoTween",{Title="Auto Tween",Description="Moves to nearest enemy",Default=S.AutoTween,Callback=function(v) S.AutoTween=v; if not v then stopTween() end end})
CT:AddSlider("TweenSpeed",{Title="Tween Base Speed",Min=5,Max=100,Default=math.floor(S.TweenSpeed*100),Suffix=" ms",Rounding=0,Callback=function(v) S.TweenSpeed=v/100 end})
CT:AddToggle("AutoReplay",{Title="Auto Replay",Default=false,Callback=function(v)
    if v then local ev=RS.remotes.gameEndVote; pcall(ev.FireServer,ev,"replay") end
end})

-- Raid
RT:AddParagraph({Title="Note",Content="Eye of Smite is the best sword for Raid mode."})
RT:AddToggle("RaidAura",{Title="Raid Aura Kill",Default=S.RaidAura,Callback=function(v) S.RaidAura=v end})
RT:AddSlider("RaidAuraRange",{Title="Raid Aura Range",Min=10,Max=500,Default=S.RaidAuraRange,Suffix=" studs",Rounding=0,Callback=function(v) S.RaidAuraRange=v end})
RT:AddDropdown("RaidAuraMode",{Title="Aura Mode",Values={"Nearest","Cone","Burst"},Default=S.RaidAuraMode,Callback=function(v) S.RaidAuraMode=v end})
RT:AddSlider("RaidBurstCD",{Title="Burst Cooldown",Min=1,Max=30,Default=S.RaidBurstCD,Suffix="s",Rounding=0,Callback=function(v) S.RaidBurstCD=v end})

-- ESP
ET:AddToggle("ESPBoxes",{Title="ESP Boxes",Description="Boxes + health bars",Default=S.ESP,Callback=function(v) S.ESP=v; if not v and not S.Tracers then clearESP() end end})
ET:AddToggle("Tracers",{Title="Tracers",Description="Lines to enemies",Default=S.Tracers,Callback=function(v) S.Tracers=v; if not v and not S.ESP then clearESP() end end})
ET:AddToggle("ShowNames",{Title="Show Names",Default=S.ShowNames,Callback=function(v) S.ShowNames=v end})
ET:AddToggle("ShowHealth",{Title="Show Health",Default=S.ShowHealth,Callback=function(v) S.ShowHealth=v end})
ET:AddToggle("ShowDistance",{Title="Show Distance",Default=S.ShowDistance,Callback=function(v) S.ShowDistance=v end})
ET:AddColorpicker("ESPColor",{Title="ESP Color",Default=S.ESPColor,Callback=function(v) S.ESPColor=v end})
ET:AddColorpicker("TracerColor",{Title="Tracer Color",Default=S.TracerColor,Callback=function(v) S.TracerColor=v end})
ET:AddDropdown("TracerOrigin",{Title="Tracer Origin",Values={"Bottom","Center"},Default=S.TracerOrigin,Callback=function(v) S.TracerOrigin=v end})

-- Movement
MT:AddSlider("WalkSpeed",{Title="Walk Speed",Min=16,Max=500,Default=S.WalkSpeed,Suffix=" sp",Rounding=0,Callback=function(v) S.WalkSpeed=v; applySpeed() end})
MT:AddSlider("JumpPower",{Title="Jump Power",Min=50,Max=500,Default=S.JumpPower,Rounding=0,Callback=function(v) S.JumpPower=v; applySpeed() end})
MT:AddToggle("FlyToggle",{Title="Fly",Description=IsMobile and "Toggle fly (gamepad: A up, B down)" or IsConsole and "Toggle fly (A up, B down)" or "W/A/S/D + Space (up) + LCtrl (down)",Default=S.Fly,Callback=function(v) if v then startFly() else stopFly() end end})
MT:AddSlider("FlySpeed",{Title="Fly Speed",Min=10,Max=300,Default=S.FlySpeed,Suffix=" sp",Rounding=0,Callback=function(v) S.FlySpeed=v end})

-- Potions
PT:AddToggle("AutoDrink",{Title="Auto Drink",Description="Drink when health falls below threshold",Default=S.AutoDrink,Callback=function(v) S.AutoDrink=v; if v then startDrink() else stopDrink() end end})
PT:AddSlider("DrinkThreshold",{Title="Health Threshold",Min=1,Max=100,Default=S.DrinkThreshold,Suffix="%",Rounding=0,Callback=function(v) S.DrinkThreshold=v end})
PT:AddDropdown("DrinkPotions",{Title="Potions to Drink",Values=POTION_NAMES,Multi=true,Default={},Callback=function(v) S.DrinkPotions=v end})
PT:AddToggle("AutoBuy",{Title="Auto Buy",Description="Purchase potions on a timer",Default=S.AutoBuy,Callback=function(v) S.AutoBuy=v; if v then startBuy() else stopBuy() end end})
PT:AddDropdown("BuyPotions",{Title="Potions to Buy",Values=POTION_NAMES,Multi=true,Default={},Callback=function(v) S.BuyPotions=v end})
PT:AddDropdown("BuyInterval",{Title="Buy Interval",Values=INTERVAL_STRS,Default="10s",Callback=function(v)
    for i,s in ipairs(INTERVAL_STRS) do if s==v then S.BuyInterval=INTERVAL_OPTIONS[i]; break end end
end})
PT:AddInput("BuyQty",{Title="Qty per Buy",Default=tostring(S.BuyQty),Numeric=true,Callback=function(v) local n=tonumber(v); if n and n>=1 then S.BuyQty=math.floor(n) end end})
PT:AddInput("BuyMax",{Title="Max Purchases (0=inf)",Default="0",Numeric=true,Callback=function(v) local n=tonumber(v); S.BuyMax=(n and n>=0) and math.floor(n) or 0 end})

-- Misc
MiT:AddToggle("AntiAFK",{Title="Anti-AFK",Description="Prevents idle kick",Default=S.AntiAFK,Callback=function(v) setAFK(v) end})
MiT:AddToggle("AutoOptimize",{Title="Auto Optimize",Description="Auto-lowers graphics on low FPS",Default=_isLowEnd,Callback=function(v)
    S.AutoOptimize=v; if v then optimizeGraphics() end
end})
MiT:AddButton({Title="Rejoin Server",Description="Reconnects to a fresh instance",Callback=function()
    Fluent:Notify({Title="Rejoin",Content="Rejoining...",Duration=3}); task.delay(0.5,rejoin)
end})
MiT:AddButton({Title="Claim All Codes",Description="Attempts all "..#Codes.." known codes",Callback=function()
    Fluent:Notify({Title="Codes",Content="Claiming "..#Codes.." codes...",Duration=3})
    task.spawn(function() claimed=false; claim() end)
end})
MiT:AddButton({Title="Optimize Graphics",Description="Reduces quality, disables shadows/FX",Callback=optimizeGraphics})
MiT:AddButton({Title="Clear Particles",Description="Disables all particle emitters and trails",Callback=function()
    local count=0
    for _,p in ipairs(WS:GetDescendants()) do if p:IsA("ParticleEmitter") or p:IsA("Trail") then p.Enabled=false; count=count+1 end end
    Fluent:Notify({Title="Particles",Content="Disabled "..count.." effects.",Duration=3})
end})

-- Device info paragraph
MiT:AddParagraph({
    Title="Device Info",
    Content=string.format("Platform: %s | Low-end: %s | FPS cap: ~%d",
        IsMobile and "Mobile" or IsConsole and "Console" or "PC/Mac",
        _isLowEnd and "Yes (optimized)" or "No",
        _isLowEnd and 30 or 60
    )
})

-- Settings
ST:AddButton({Title="Copy Discord Link",Description="discord.gg/AuQqvrJE79",Callback=function()
    if setclipboard then pcall(setclipboard,"https://discord.gg/AuQqvrJE79") end
    Fluent:Notify({Title="Discord",Content="Invite link copied!",Duration=3})
end})
ST:AddButton({Title="Copy My Token",Description="Copy your dashboard token to clipboard",Callback=function()
    local tok=_playerToken or (getgenv and getgenv()._vhxToken)
    if not tok then Fluent:Notify({Title="Token",Content="Token loading, wait a moment.",Duration=3}); return end
    if setclipboard then pcall(setclipboard,tok) end
    Fluent:Notify({Title="Token Copied!",Content="Your token: "..tok,Duration=5})
end})

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreFlags({"AutoReplay"})
SaveManager:BuildConfigSection(ST)
InterfaceManager:BuildInterfaceSection(ST)

-- Keybinds (PC/Mac only — mobile/console use UI buttons)
if not IsMobile and not IsConsole then
    ST:AddKeybind("ToggleUI",{Title="Toggle UI",Default=Enum.KeyCode.RightControl,Callback=function() Win:SetVisible(not Win:GetVisible()) end})
    ST:AddKeybind("KillAuraKey",{Title="Kill Aura Toggle",Default=Enum.KeyCode.L,Callback=function()
        S.KillAura=not S.KillAura; AuraToggle:SetValue(S.KillAura)
        Fluent:Notify({Title="Kill Aura",Content=S.KillAura and "Enabled" or "Disabled",Duration=2})
    end})
end

-- Console gamepad toggle
if IsConsole then
    Cn(UIS.GamepadButtonDown:Connect(function(_, btn)
        if btn==Enum.KeyCode.ButtonSelect then Win:SetVisible(not Win:GetVisible()) end
        if btn==Enum.KeyCode.ButtonR3 then
            S.KillAura=not S.KillAura; AuraToggle:SetValue(S.KillAura)
            Fluent:Notify({Title="Kill Aura",Content=S.KillAura and "Enabled" or "Disabled",Duration=2})
        end
    end))
end

SaveManager:LoadAutoloadConfig()

-- Dynamic FPS-based quality scaling for mid-game drops
local _qualityTimer=0
Cn(Run.Heartbeat:Connect(function(dt)
    if not S.AutoOptimize then return end
    _qualityTimer=_qualityTimer+dt
    if _qualityTimer<30 then return end
    _qualityTimer=0
    if fps>0 and fps<25 then optimizeGraphics() end
end))

if getgenv then
    getgenv()._PB_Destroy=function()
        stopDrink(); stopBuy(); stopTween(); stopFly()
        if afkConn then afkConn:Disconnect(); afkConn=nil end
        clearESP(); KillConns()
        table.clear(_damageable); table.clear(_hpSnapshot)
        _enemyCount=0
        pcall(_fpsGui.Destroy,_fpsGui)
        pcall(_toggleGui.Destroy,_toggleGui)
        pcall(Win.Destroy,Win)
    end
end

-- ── Draggable floating toggle button (mobile + all platforms) ────────────────
local _toggleGui = Instance.new("ScreenGui")
_toggleGui.Name="PB_Toggle"; _toggleGui.ResetOnSpawn=false; _toggleGui.DisplayOrder=9998
_toggleGui.IgnoreGuiInset=true; _toggleGui.Parent=CoreGui

local _toggleBtn = Instance.new("ImageButton")
_toggleBtn.Size=UDim2.new(0,54,0,54)
_toggleBtn.Position=IsMobile and UDim2.new(0,10,0.5,-27) or UDim2.new(1,-70,0,60)
_toggleBtn.BackgroundColor3=Color3.fromRGB(99,102,241)
_toggleBtn.BorderSizePixel=0; _toggleBtn.Active=true; _toggleBtn.Draggable=false
_toggleBtn.Parent=_toggleGui
Instance.new("UICorner",_toggleBtn).CornerRadius=UDim.new(0,14)
local _stroke2=Instance.new("UIStroke",_toggleBtn)
_stroke2.Color=Color3.fromRGB(139,92,246); _stroke2.Thickness=2

local _toggleLbl=Instance.new("TextLabel")
_toggleLbl.Size=UDim2.new(1,0,1,0); _toggleLbl.BackgroundTransparency=1
_toggleLbl.Text="⚔"; _toggleLbl.Font=Enum.Font.GothamBold
_toggleLbl.TextSize=22; _toggleLbl.TextColor3=Color3.new(1,1,1)
_toggleLbl.Parent=_toggleBtn

-- Drag logic
local _dragging,_dragStart,_startPos=false,nil,nil
_toggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        _dragging=true; _dragStart=input.Position
        _startPos=_toggleBtn.Position
    end
end)
_toggleBtn.InputChanged:Connect(function(input)
    if _dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
        local delta=input.Position-_dragStart
        local vp=Cam.ViewportSize
        local nx=math.clamp(_startPos.X.Offset+delta.X,0,vp.X-54)
        local ny=math.clamp(_startPos.Y.Offset+delta.Y,0,vp.Y-54)
        _toggleBtn.Position=UDim2.new(0,nx,0,ny)
    end
end)
_toggleBtn.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        local delta=input.Position-_dragStart
        if delta.Magnitude<6 then
            -- tap = toggle UI
            Win:SetVisible(not Win:GetVisible())
        end
        _dragging=false
    end
end)
if IsMobile    then notifMsg="Tap the UI to toggle panels"
elseif IsConsole then notifMsg="Select = Toggle UI  |  R3 = Kill Aura"
else notifMsg="L = Kill Aura  |  RCtrl = Toggle UI" end
if _isLowEnd then notifMsg=notifMsg.."  |  Low-end mode ON" end

Fluent:Notify({Title="Pixel Blade v9",Content=notifMsg,Duration=6})
