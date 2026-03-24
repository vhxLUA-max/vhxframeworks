-- ╔══════════════════════════════════════════════════════╗
-- ║         PIXEL BLADE v2  |  by vhxLUA               ║
-- ║         Optimized for all devices                   ║
-- ╚══════════════════════════════════════════════════════╝

-- ── Fluent UI Bootstrap ──────────────────────────────────────────────────────
local Fluent        = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager   = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ── Services (cached once, never repeated) ───────────────────────────────────
local Players        = game:GetService("Players")
local RS             = game:GetService("ReplicatedStorage")
local UIS            = game:GetService("UserInputService")
local WS             = game:GetService("Workspace")
local Run            = game:GetService("RunService")
local TS_            = game:GetService("TeleportService")
local MS             = game:GetService("MarketplaceService")
local VU             = game:GetService("VirtualUser")
local TweenService   = game:GetService("TweenService")
local CoreGui        = game:GetService("CoreGui")
local StatsService   = game:GetService("Stats")

-- ── Locals (avoids repeated global lookups) ───────────────────────────────────
local LP             = Players.LocalPlayer
local Cam            = WS.CurrentCamera
local mFloor         = math.floor
local mMax           = math.max
local mMin           = math.min
local mClamp         = math.clamp
local mCos           = math.cos
local mRad           = math.rad
local mAbs           = math.abs
local tInsert        = table.insert
local tSort          = table.sort
local strFormat      = string.format
local IsMobile       = UIS.TouchEnabled and not UIS.KeyboardEnabled

-- ── Remotes ───────────────────────────────────────────────────────────────────
local Rem     = RS:FindFirstChild("remotes")
local HitEv   = Rem and Rem:FindFirstChild("onHit")
local ClaimEv = Rem and Rem:FindFirstChild("claimCode")
local DrinkEv = Rem and Rem:FindFirstChild("drinkPotion")
local BuyEv   = Rem and Rem:FindFirstChild("requestPurchase")
local SwingEv = Rem and Rem:FindFirstChild("swing")
local BlockEv = Rem and Rem:FindFirstChild("block")

-- ── Session ───────────────────────────────────────────────────────────────────
if getgenv then
    getgenv()._PB_SessionStart = getgenv()._PB_SessionStart or tick()
end
local _sessionStart = (getgenv and getgenv()._PB_SessionStart) or tick()

-- ── Constants ─────────────────────────────────────────────────────────────────
local POTION_NAMES     = {"HealthFlask","DragonFlask","EnergyFlask"}
local INTERVAL_OPTIONS = {1,5,10,20,30}
local INTERVAL_STRS    = {"1s","5s","10s","20s","30s"}
local MAX_TARGETS      = 10
local MIN_INTERVAL     = 0.08
local BOSS_DAMAGE      = {BookHand=5000, Throne9=5000}
local AURA_MODES       = {"Nearest","Cone","Burst"}
local BURST_COOLDOWN   = 5

local Codes = {
    "BREAKABLES","AncientSands","PLUSHIE","625K","CrimsonNightmare",
    "600K","575K","550K","FREEWISH","World4","525K","Rings","Alpha","Theo","FBG"
}

-- ── State ─────────────────────────────────────────────────────────────────────
getgenv().S = getgenv().S or {
    -- Kill Aura
    KillAura=false, AuraRange=100, AttackSpeed=0.15, AuraMode="Nearest",
    -- Movement
    WalkSpeed=50, JumpPower=100,
    -- Fly
    FlyEnabled=false, FlySpeed=40,
    -- Speed
    SpeedEnabled=false, SpeedValue=20,
    -- ESP
    ESP=false, Tracers=false, ESPColor=Color3.fromRGB(255,0,0),
    TracerColor=Color3.fromRGB(0,255,0), ShowNames=true,
    ShowHealth=true, ShowDistance=true, TracerOrigin="Bottom",
    -- Potions
    AutoDrink=false, DrinkPotions={}, DrinkThreshold=50,
    AutoBuy=false, BuyPotions={}, BuyInterval=10, BuyQty=1, BuyMax=0, BuyTotal=0,
    -- Misc
    AntiAFK=false, UITransparency=0,
}
local S  = getgenv().S
local KB = {KillAura=Enum.KeyCode.L, ToggleUI=Enum.KeyCode.RightControl}

-- ── Connection pool ───────────────────────────────────────────────────────────
local conns = {}
local function Cn(c) conns[#conns+1]=c; return c end
local function KillConns()
    for _,c in ipairs(conns) do pcall(c.Disconnect,c) end
    conns = {}
end

-- ── FPS / Ping (single unified counter) ──────────────────────────────────────
local fps, ping = 0, 0
local _fpsFrames, _fpsDt = 0, 0
local _pingItem
pcall(function() _pingItem = StatsService.Network.ServerStatsItem["Data Ping"] end)

local function getPing()
    if _pingItem then
        local ok,v = pcall(_pingItem.GetValue, _pingItem)
        if ok and v then return mFloor(v) end
    end
    return 0
end

Cn(Run.RenderStepped:Connect(function(dt)
    _fpsFrames = _fpsFrames + 1
    _fpsDt     = _fpsDt + dt
    if _fpsDt >= 0.5 then
        fps        = mFloor(_fpsFrames / _fpsDt)
        ping       = getPing()
        _fpsFrames = 0
        _fpsDt     = 0
    end
end))

-- ── Destroy old instance ──────────────────────────────────────────────────────
do
    if getgenv and getgenv()._PB_Destroy then
        pcall(getgenv()._PB_Destroy)
        getgenv()._PB_Destroy = nil
    end
    -- Clean up old GUIs
    for _, name in ipairs({"PIXEL_BLADE_UI","FPS_PING_MINI","PB_Overlay"}) do
        local g = CoreGui:FindFirstChild(name)
        if g then pcall(g.Destroy, g) end
        local pg = LP.PlayerGui:FindFirstChild(name)
        if pg then pcall(pg.Destroy, pg) end
    end
    task.wait(0.1)
end

-- ── Enemy cache (refreshed every 0.25s, not every frame) ─────────────────────
local _enemies   = {}
local _enemySet  = {}
local _lastBurst = 0

local IgnoredEnemies = {
    ["teeth trap"]=true, ["Teeth Trap"]=true,
    ["teeth_trap"]=true, ["Teeth_Trap"]=true,
}

local function _refreshEnemies()
    local char = LP.Character
    local myRP = char and char:FindFirstChild("HumanoidRootPart")
    if not myRP then _enemies={}; _enemySet={}; return end
    local myPos     = myRP.Position
    local scanRange = mMax(S.AuraRange, (S.ESP or S.Tracers) and 2000 or 0)
    local newE, newSet = {}, {}
    -- Use GetChildren (faster than GetDescendants; enemies are direct WS children)
    for _, m in ipairs(WS:GetChildren()) do
        if not m:IsA("Model") or m == char or newSet[m] or IgnoredEnemies[m.Name] then continue end
        local h = m:FindFirstChildOfClass("Humanoid")
        if not h or h.Health <= 0 then continue end
        local rp = m:FindFirstChild("HumanoidRootPart")
                or m:FindFirstChild("Torso")
                or m:FindFirstChild("UpperTorso")
                or m.PrimaryPart
        if rp and (myPos - rp.Position).Magnitude <= scanRange then
            newSet[m] = true
            newE[#newE+1] = {model=m, humanoid=h, root=rp, dist=(myPos-rp.Position).Magnitude}
        end
    end
    _enemies = newE
    _enemySet = newSet
end

task.spawn(function()
    while true do task.wait(0.25); _refreshEnemies() end
end)

-- Refresh on level change
local LevelStartEv = Rem and Rem:FindFirstChild("levelStart")
if LevelStartEv then
    Cn(LevelStartEv.OnClientEvent:Connect(function()
        _enemies = {}; _enemySet = {}
        task.wait(0.5); _refreshEnemies()
    end))
end

-- ── Target highlight ──────────────────────────────────────────────────────────
local currentTarget, currentHighlight

local function clearTarget()
    if currentHighlight and currentHighlight.Parent then
        currentHighlight:Destroy()
    end
    currentTarget   = nil
    currentHighlight = nil
end

local function setTarget(m)
    if currentTarget == m then return end
    clearTarget()
    currentTarget = m
    local h = Instance.new("Highlight")
    h.FillTransparency = 1
    h.OutlineColor     = Color3.fromRGB(170,0,0)
    h.DepthMode        = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent           = m
    currentHighlight   = h
end

-- ── ESP (Drawing-based) ───────────────────────────────────────────────────────
local ESP = {}
local HW, HH = 2, 2.75

local function mkESP(m)
    if ESP[m] then return end
    local d = {box={}}
    for i = 1,4 do
        local l = Drawing.new("Line")
        l.Thickness=1.5; l.Visible=false; l.ZIndex=5
        d.box[i] = l
    end
    local function txt()
        local t = Drawing.new("Text")
        t.Size=13; t.Outline=true; t.OutlineColor=Color3.new(0,0,0)
        t.Center=true; t.Visible=false; t.ZIndex=6
        return t
    end
    local function ln(th,z)
        local l = Drawing.new("Line")
        l.Thickness=th; l.Visible=false; l.ZIndex=z
        return l
    end
    d.nl = txt()
    d.hb = ln(3,5); d.hb.Color = Color3.new(0,0,0)
    d.hf = ln(3,6)
    d.dl = txt(); d.dl.Size = 11
    d.tr = ln(1,4)
    ESP[m] = d
end

local function rmESP(m)
    local d = ESP[m]; if not d then return end
    for _,l in next,d.box do pcall(l.Remove,l) end
    for _,k in next,{"nl","hb","hf","dl","tr"} do
        if d[k] then pcall(d[k].Remove, d[k]) end
    end
    ESP[m] = nil
end

local function clearESP()
    for m in next,ESP do rmESP(m) end
    ESP = {}
end

local function bounds(m)
    local r = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
    if not r then return nil end
    local cf = r.CFrame
    local x0,y0,x1,y1 = math.huge,math.huge,-math.huge,-math.huge
    local corners = {
        Vector3.new(-HW,-HH,0), Vector3.new(HW,-HH,0),
        Vector3.new(HW,HH,0),   Vector3.new(-HW,HH,0),
    }
    for _,o in next,corners do
        local sp,vis = Cam:WorldToViewportPoint((cf*CFrame.new(o)).Position)
        if not vis then return nil end
        if sp.X<x0 then x0=sp.X end; if sp.Y<y0 then y0=sp.Y end
        if sp.X>x1 then x1=sp.X end; if sp.Y>y1 then y1=sp.Y end
    end
    return x0,y0,x1,y1
end

-- ESP render at 30fps cap (easy on low-end devices)
local _espTimer = 0
Cn(Run.Heartbeat:Connect(function(dt)
    _espTimer = _espTimer + dt
    if _espTimer < (1/30) then return end
    _espTimer = 0

    local act = S.ESP or S.Tracers
    if not act then
        for _,d in next,ESP do
            for _,l in next,d.box do l.Visible=false end
            d.nl.Visible=false; d.hb.Visible=false
            d.hf.Visible=false; d.dl.Visible=false; d.tr.Visible=false
        end
        return
    end

    local char = LP.Character
    local myR  = char and char:FindFirstChild("HumanoidRootPart")
    local vp   = Cam.ViewportSize
    local tO   = S.TracerOrigin ~= "Center"
        and Vector2.new(vp.X*.5, vp.Y)
        or  Vector2.new(vp.X*.5, vp.Y*.5)

    local activeModels = {}
    for _,e in ipairs(_enemies) do
        local m,h = e.model, e.humanoid
        if m and m.Parent and h and h.Health > 0 then
            activeModels[m] = true
            if not ESP[m] then mkESP(m) end
        end
    end
    for m in next,ESP do
        if not activeModels[m] then rmESP(m) end
    end

    for m,d in next,ESP do
        local h  = m:FindFirstChildOfClass("Humanoid")
        local r  = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
        if not r or not h then
            for _,l in next,d.box do l.Visible=false end
            d.nl.Visible=false; d.hb.Visible=false
            d.hf.Visible=false; d.dl.Visible=false; d.tr.Visible=false
            continue
        end
        local sp,vis = Cam:WorldToViewportPoint(r.Position)
        local ctr    = Vector2.new(sp.X, sp.Y)
        local dist   = myR and (myR.Position - r.Position).Magnitude or 0

        if S.ESP then
            local x0,y0,x1,y1 = bounds(m)
            if x0 and vis then
                local ec = S.ESPColor; local b = d.box
                b[1].From=Vector2.new(x0,y0); b[1].To=Vector2.new(x1,y0); b[1].Color=ec; b[1].Visible=true
                b[2].From=Vector2.new(x0,y1); b[2].To=Vector2.new(x1,y1); b[2].Color=ec; b[2].Visible=true
                b[3].From=Vector2.new(x0,y0); b[3].To=Vector2.new(x0,y1); b[3].Color=ec; b[3].Visible=true
                b[4].From=Vector2.new(x1,y0); b[4].To=Vector2.new(x1,y1); b[4].Color=ec; b[4].Visible=true
                if S.ShowNames then
                    d.nl.Text=m.Name; d.nl.Color=ec
                    d.nl.Position=Vector2.new((x0+x1)*.5, y0-18); d.nl.Visible=true
                else d.nl.Visible=false end
                local hr = mClamp(h.Health/h.MaxHealth, 0, 1)
                if S.ShowHealth then
                    d.hb.From=Vector2.new(x0-6,y0); d.hb.To=Vector2.new(x0-6,y1); d.hb.Visible=true
                    d.hf.From=Vector2.new(x0-6,y1)
                    d.hf.To=Vector2.new(x0-6, y1-(y1-y0)*hr)
                    d.hf.Color=Color3.fromRGB(mFloor((1-hr)*255), mFloor(hr*255), 0)
                    d.hf.Visible=true
                else d.hb.Visible=false; d.hf.Visible=false end
                if S.ShowDistance then
                    d.dl.Text=mFloor(dist).."m"
                    d.dl.Position=Vector2.new((x0+x1)*.5, y1+3); d.dl.Visible=true
                else d.dl.Visible=false end
            else
                for _,l in next,d.box do l.Visible=false end
                d.nl.Visible=false; d.hb.Visible=false; d.hf.Visible=false; d.dl.Visible=false
            end
        else
            for _,l in next,d.box do l.Visible=false end
            d.nl.Visible=false; d.hb.Visible=false; d.hf.Visible=false; d.dl.Visible=false
        end
        if S.Tracers and vis then
            d.tr.From=tO; d.tr.To=ctr; d.tr.Color=S.TracerColor; d.tr.Visible=true
        else d.tr.Visible=false end
    end
end))

-- ── Kill Aura ─────────────────────────────────────────────────────────────────
local function _getDmg(m)
    return BOSS_DAMAGE[m.Name] or 5000
end

local function _filterByMode(list)
    if S.AuraMode == "Nearest" then return list end
    if S.AuraMode == "Cone" then
        local out = {}
        for _,e in ipairs(list) do
            local r = e.root
            if r then
                local dir = (r.Position - Cam.CFrame.Position).Unit
                if Cam.CFrame.LookVector:Dot(dir) >= mCos(mRad(45)) then
                    tInsert(out, e)
                end
            end
        end
        return out
    end
    if S.AuraMode == "Burst" then
        if tick() - _lastBurst < BURST_COOLDOWN then return {} end
        _lastBurst = tick()
        return list
    end
    return list
end

local _auraTimer = 0
Cn(Run.Heartbeat:Connect(function(dt)
    if not S.KillAura then return end
    if not HitEv or not HitEv.Parent then return end
    _auraTimer = _auraTimer + dt
    local iv = mMax(S.AttackSpeed, MIN_INTERVAL)
    if _auraTimer < iv then return end
    _auraTimer = 0

    local char = LP.Character; if not char then return end
    local myR  = char:FindFirstChild("HumanoidRootPart"); if not myR then return end
    local myPos = myR.Position

    -- Swing remote (once per burst)
    if SwingEv and SwingEv.Parent then
        pcall(SwingEv.FireServer, SwingEv)
    end

    local filtered = _filterByMode(_enemies)
    local count = 0
    for _,e in ipairs(filtered) do
        if count >= MAX_TARGETS then break end
        local h,rp,m = e.humanoid, e.root, e.model
        if h and h.Parent and h.Health > 0 then
            if not rp or (myPos - rp.Position).Magnitude <= S.AuraRange then
                pcall(HitEv.FireServer, HitEv, h, _getDmg(m), {}, 0)
                count = count + 1
                setTarget(m)
            end
        end
    end
    if count == 0 then clearTarget() end
end))

-- ── Block loop ────────────────────────────────────────────────────────────────
local _blockTimer = 0
Cn(Run.Heartbeat:Connect(function(dt)
    if not BlockEv or not BlockEv.Parent then return end
    _blockTimer = _blockTimer + dt
    if _blockTimer < 0.1 then return end
    _blockTimer = 0
    pcall(BlockEv.FireServer, BlockEv, true)
end))

-- ── Speed / WalkSpeed ─────────────────────────────────────────────────────────
local function applySpeed()
    local c = LP.Character; if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid"); if not h then return end
    h.WalkSpeed = S.WalkSpeed; h.JumpPower = S.JumpPower
end

local function hookCharacter(char)
    local h = char:WaitForChild("Humanoid", 5); if not h then return end
    applySpeed()
    Cn(h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if mAbs(h.WalkSpeed - S.WalkSpeed) > 0.5 then h.WalkSpeed = S.WalkSpeed end
    end))
    Cn(h:GetPropertyChangedSignal("JumpPower"):Connect(function()
        if mAbs(h.JumpPower - S.JumpPower) > 0.5 then h.JumpPower = S.JumpPower end
    end))
end

if LP.Character then hookCharacter(LP.Character) end
Cn(LP.CharacterAdded:Connect(hookCharacter))

-- ── Fly ───────────────────────────────────────────────────────────────────────
local function ensureFly()
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil end
    local bv = hrp:FindFirstChild("PB_BV")
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.Name="PB_BV"; bv.MaxForce=Vector3.new(1e5,1e5,1e5); bv.Parent=hrp
    end
    local bg = hrp:FindFirstChild("PB_BG")
    if not bg then
        bg = Instance.new("BodyGyro")
        bg.Name="PB_BG"; bg.MaxTorque=Vector3.new(1e5,1e5,1e5); bg.Parent=hrp
    end
    return bv, bg
end

local function flyDir()
    local d = Vector3.zero
    if UIS:IsKeyDown(Enum.KeyCode.W) then d = d + Cam.CFrame.LookVector  end
    if UIS:IsKeyDown(Enum.KeyCode.S) then d = d - Cam.CFrame.LookVector  end
    if UIS:IsKeyDown(Enum.KeyCode.A) then d = d - Cam.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.D) then d = d + Cam.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.Space)      then d = d + Vector3.new(0,1,0) end
    if UIS:IsKeyDown(Enum.KeyCode.LeftShift)  then d = d - Vector3.new(0,1,0) end
    return d.Magnitude > 0 and d.Unit or Vector3.zero
end

local function stopFly()
    local char = LP.Character; if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local bv   = hrp:FindFirstChild("PB_BV")
    local bg   = hrp:FindFirstChild("PB_BG")
    if bv then bv:Destroy() end
    if bg then bg:Destroy() end
    local h = char:FindFirstChildOfClass("Humanoid")
    if h then h.PlatformStand = false end
end

local _flyTimer = 0
Cn(Run.Heartbeat:Connect(function(dt)
    _flyTimer = _flyTimer + dt
    if _flyTimer < 0.02 then return end
    _flyTimer = 0
    local char = LP.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if S.FlyEnabled and hrp and hrp.Parent then
        local bv, bg = ensureFly()
        if bv then bv.Velocity = flyDir() * S.FlySpeed end
        if bg then bg.CFrame = Cam.CFrame end
        if hum then hum.PlatformStand = true end
    elseif not S.FlyEnabled then
        if hum then hum.PlatformStand = false end
        if hrp then
            local bv = hrp:FindFirstChild("PB_BV")
            local bg = hrp:FindFirstChild("PB_BG")
            if bv then bv:Destroy() end
            if bg then bg:Destroy() end
        end
    end
end))

-- ── Anti-AFK ──────────────────────────────────────────────────────────────────
local afkConn
local function setAFK(v)
    S.AntiAFK = v
    if afkConn then afkConn:Disconnect(); afkConn = nil end
    if v then
        afkConn = Run.Heartbeat:Connect(function()
            pcall(VU.CaptureController, VU)
            pcall(VU.ClickButton2, VU, Vector2.new())
        end)
    end
end

-- ── Auto Drink ────────────────────────────────────────────────────────────────
local _drinkThread
local function stopDrink()
    if _drinkThread then task.cancel(_drinkThread); _drinkThread=nil end
end
local function startDrink()
    stopDrink()
    if not DrinkEv or not DrinkEv.Parent then return end
    _drinkThread = task.spawn(function()
        while S.AutoDrink do
            task.wait(0.1)
            local char = LP.Character
            local h    = char and char:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 and h.MaxHealth > 0 then
                if (h.Health/h.MaxHealth)*100 <= S.DrinkThreshold then
                    pcall(DrinkEv.FireServer, DrinkEv)
                    task.wait(0.5)
                end
            end
        end
    end)
end

-- ── Auto Buy ─────────────────────────────────────────────────────────────────
local _buyThread
local function stopBuy()
    if _buyThread then task.cancel(_buyThread); _buyThread=nil end
end
local function startBuy()
    stopBuy()
    if not BuyEv or not BuyEv.Parent then return end
    S.BuyTotal = 0
    _buyThread = task.spawn(function()
        while S.AutoBuy do
            if #S.BuyPotions == 0 then task.wait(1); continue end
            if S.BuyMax > 0 and S.BuyTotal >= S.BuyMax then
                S.AutoBuy = false; break
            end
            local qty = mMax(1, S.BuyQty)
            if S.BuyMax > 0 then qty = mMin(qty, S.BuyMax - S.BuyTotal) end
            for _,pn in ipairs(S.BuyPotions) do
                for _ = 1,qty do
                    pcall(BuyEv.FireServer, BuyEv, pn, "potion")
                    task.wait(0.15)
                end
            end
            S.BuyTotal = S.BuyTotal + qty * mMax(1, #S.BuyPotions)
            task.wait(S.BuyInterval)
        end
    end)
end

-- ── Codes ─────────────────────────────────────────────────────────────────────
local claimed = false
local function claimCodes()
    if claimed then return end
    if not ClaimEv or not ClaimEv.Parent then return end
    claimed = true
    for _,code in next,Codes do
        pcall(ClaimEv.InvokeServer, ClaimEv, code)
        task.wait(0.3)
    end
end

-- ── Graphics Optimize ─────────────────────────────────────────────────────────
local function optimizeGraphics()
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function()
        local L = game:GetService("Lighting")
        L.GlobalShadows = false; L.FogEnd = 100000
        for _,v in ipairs(L:GetChildren()) do
            if v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect")
            or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect")
            or v:IsA("BloomEffect") then
                v.Enabled = false
            end
        end
    end)
    local count = 0
    for _,p in ipairs(WS:GetDescendants()) do
        if p:IsA("ParticleEmitter") or p:IsA("Trail") then
            p.Enabled = false; count = count + 1
        end
    end
    return count
end

-- ── Rejoin ────────────────────────────────────────────────────────────────────
local function rejoin()
    pcall(function() TS_:Teleport(game.PlaceId, LP) end)
    task.delay(2, function()
        pcall(function() TS_:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end)
    end)
end

-- ── FPS/Ping overlay (lightweight, no TweenService loop) ─────────────────────
local OGui = Instance.new("ScreenGui")
OGui.Name="PB_Overlay"; OGui.ResetOnSpawn=false; OGui.DisplayOrder=1000
local okCG, CG = pcall(game.GetService, game, "CoreGui")
OGui.Parent = okCG and CG or LP.PlayerGui

local OF = Instance.new("Frame",OGui)
OF.Size=UDim2.new(0,130,0,46); OF.Position=UDim2.new(0,80,0,10)
OF.BackgroundColor3=Color3.fromRGB(10,10,18); OF.BorderSizePixel=0; OF.Active=true; OF.Draggable=true
Instance.new("UICorner",OF).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",OF).Color=Color3.fromRGB(30,30,50)

local FL = Instance.new("TextLabel",OF)
FL.Size=UDim2.new(1,-8,0,20); FL.Position=UDim2.new(0,6,0,2)
FL.BackgroundTransparency=1; FL.Text="FPS: --"
FL.TextColor3=Color3.fromRGB(140,100,255); FL.TextSize=11
FL.Font=Enum.Font.GothamBold; FL.TextXAlignment=Enum.TextXAlignment.Left

local PL_ = Instance.new("TextLabel",OF)
PL_.Size=UDim2.new(1,-8,0,20); PL_.Position=UDim2.new(0,6,0,24)
PL_.BackgroundTransparency=1; PL_.Text="Ping: --ms"
PL_.TextColor3=Color3.fromRGB(120,115,150); PL_.TextSize=11
PL_.Font=Enum.Font.Gotham; PL_.TextXAlignment=Enum.TextXAlignment.Left

local _ofv, _opv = -1, -1
local _overlayTimer = 0
Cn(Run.Heartbeat:Connect(function(dt)
    _overlayTimer = _overlayTimer + dt
    if _overlayTimer < 0.5 then return end
    _overlayTimer = 0
    if fps ~= _ofv then _ofv=fps; if FL and FL.Parent then
        FL.Text="FPS: "..fps
        FL.TextColor3 = fps>=60 and Color3.fromRGB(0,200,0) or Color3.fromRGB(200,80,80)
    end end
    if ping ~= _opv then _opv=ping; if PL_ and PL_.Parent then
        PL_.Text="Ping: "..ping.."ms"
        PL_.TextColor3 = ping<=80 and Color3.fromRGB(0,200,0)
            or ping<=150 and Color3.fromRGB(255,170,0)
            or Color3.fromRGB(200,80,80)
    end end
end))

-- ═══════════════════════════════════════════════════════════════════
-- ── Fluent UI Window ─────────────────────────────────────────────
-- ═══════════════════════════════════════════════════════════════════
local Win = Fluent:CreateWindow({
    Title        = "Pixel Blade",
    SubTitle     = "by vhxLUA  v2",
    TabWidth     = 160,
    Size         = UDim2.fromOffset(580, 460),
    Acrylic      = true,
    Theme        = "Dark",
    MinimizeKey  = KB.ToggleUI,
})

-- ── Tabs ──────────────────────────────────────────────────────────
local Tabs = {
    Combat   = Win:AddTab({Title="Combat",   Icon="sword"   }),
    ESP      = Win:AddTab({Title="ESP",      Icon="eye"     }),
    Movement = Win:AddTab({Title="Movement", Icon="zap"     }),
    Potions  = Win:AddTab({Title="Potions",  Icon="heart"   }),
    Misc     = Win:AddTab({Title="Misc",     Icon="shield"  }),
    Settings = Win:AddTab({Title="Settings", Icon="settings"}),
}

-- ════════════════ COMBAT ════════════════
do
    local T = Tabs.Combat
    T:AddParagraph({
        Title   = "⚠ Boss Warning",
        Content = "Disable Kill Aura during boss spawn cutscene. Firing hit remote during intro can desync boss state.",
    })

    local AuraTog = T:AddToggle("KillAura",{
        Title   = "Kill Aura",
        Description = "Hits nearby enemies each interval",
        Default = S.KillAura,
    })
    AuraTog:OnChanged(function(v) S.KillAura=v end)

    T:AddSlider("AuraRange",{
        Title   = "Aura Range",
        Min=0, Max=1000, Default=S.AuraRange, Suffix=" studs", Rounding=0,
    }):OnChanged(function(v) S.AuraRange=v end)

    T:AddSlider("AttackInterval",{
        Title   = "Attack Interval",
        Min=80, Max=2000, Default=mFloor(S.AttackSpeed*1000), Suffix=" ms", Rounding=0,
    }):OnChanged(function(v) S.AttackSpeed=v/1000 end)

    T:AddDropdown("AuraMode",{
        Title   = "Aura Mode",
        Values  = AURA_MODES,
        Default = S.AuraMode,
    }):OnChanged(function(v) S.AuraMode=v end)

    -- Keybind toggle (desktop only)
    if not IsMobile then
        Cn(UIS.InputBegan:Connect(function(i, gpe)
            if gpe then return end
            if UIS:GetFocusedTextBox() then return end
            if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if i.KeyCode == KB.KillAura then
                S.KillAura = not S.KillAura
                AuraTog:SetValue(S.KillAura)
                Win:Notify({Title="Kill Aura", Content=S.KillAura and "Enabled" or "Disabled", Duration=2})
            end
        end))
    end

    -- Auto Replay
    T:AddToggle("AutoReplay",{Title="Auto Replay (Raid)", Default=false}):OnChanged(function(v)
        if v then
            local ReplayEv = pcall(function() return RS.remotes.gameEndVote end)
            if ReplayEv then pcall(ReplayEv.FireServer, ReplayEv, "replay") end
        end
    end)
end

-- ════════════════ ESP ════════════════
do
    local T = Tabs.ESP
    T:AddToggle("ESPBoxes",{Title="ESP Boxes", Description="Boxes + health + name + distance", Default=S.ESP
    }):OnChanged(function(v) S.ESP=v; if not v and not S.Tracers then clearESP() end end)

    T:AddToggle("Tracers",{Title="Tracers", Description="Lines to enemies", Default=S.Tracers
    }):OnChanged(function(v) S.Tracers=v; if not v and not S.ESP then clearESP() end end)

    T:AddToggle("ShowNames",   {Title="Show Names",    Default=S.ShowNames   }):OnChanged(function(v) S.ShowNames=v    end)
    T:AddToggle("ShowHealth",  {Title="Show Health",   Default=S.ShowHealth  }):OnChanged(function(v) S.ShowHealth=v   end)
    T:AddToggle("ShowDistance",{Title="Show Distance", Default=S.ShowDistance}):OnChanged(function(v) S.ShowDistance=v end)

    T:AddColorpicker("ESPColor",   {Title="ESP Color",    Default=S.ESPColor   }):OnChanged(function(v) S.ESPColor=v    end)
    T:AddColorpicker("TracerColor",{Title="Tracer Color", Default=S.TracerColor}):OnChanged(function(v) S.TracerColor=v end)

    T:AddDropdown("TracerOrigin",{
        Title="Tracer Origin", Values={"Bottom","Center"}, Default=S.TracerOrigin,
    }):OnChanged(function(v) S.TracerOrigin=v end)
end

-- ════════════════ MOVEMENT ════════════════
do
    local T = Tabs.Movement
    T:AddSlider("WalkSpeed",{Title="Walk Speed", Min=16, Max=500, Default=S.WalkSpeed, Suffix=" sp", Rounding=0
    }):OnChanged(function(v) S.WalkSpeed=v; applySpeed() end)

    T:AddSlider("JumpPower",{Title="Jump Power", Min=50, Max=500, Default=S.JumpPower, Rounding=0
    }):OnChanged(function(v) S.JumpPower=v; applySpeed() end)

    T:AddToggle("FlyEnabled",{Title="Fly", Description="WASD + Space/Shift to fly", Default=S.FlyEnabled
    }):OnChanged(function(v) S.FlyEnabled=v; if not v then stopFly() end end)

    T:AddSlider("FlySpeed",{Title="Fly Speed", Min=16, Max=200, Default=S.FlySpeed, Rounding=0
    }):OnChanged(function(v) S.FlySpeed=v end)
end

-- ════════════════ POTIONS ════════════════
do
    local T = Tabs.Potions

    -- Auto Drink
    T:AddToggle("AutoDrink",{Title="Auto Drink", Description="Drink when HP% drops below threshold", Default=S.AutoDrink
    }):OnChanged(function(v) S.AutoDrink=v; if v then startDrink() else stopDrink() end end)

    T:AddSlider("DrinkThreshold",{Title="Health Threshold", Min=1, Max=100, Default=S.DrinkThreshold, Suffix="%", Rounding=0
    }):OnChanged(function(v) S.DrinkThreshold=v end)

    T:AddDropdown("DrinkPotions",{Title="Potions to Drink", Values=POTION_NAMES, Multi=true, Default=S.DrinkPotions
    }):OnChanged(function(v) S.DrinkPotions=v end)

    -- Auto Buy
    T:AddToggle("AutoBuy",{Title="Auto Buy", Description="Purchase potions on a timer", Default=S.AutoBuy
    }):OnChanged(function(v) S.AutoBuy=v; if v then startBuy() else stopBuy() end end)

    T:AddDropdown("BuyPotions",{Title="Potions to Buy", Values=POTION_NAMES, Multi=true, Default=S.BuyPotions
    }):OnChanged(function(v) S.BuyPotions=v end)

    T:AddDropdown("BuyInterval",{Title="Buy Interval", Values=INTERVAL_STRS, Default="10s"
    }):OnChanged(function(v)
        for i,s in ipairs(INTERVAL_STRS) do
            if s==v then S.BuyInterval=INTERVAL_OPTIONS[i]; break end
        end
    end)

    T:AddInput("BuyQty",{Title="Qty Per Buy", Default=tostring(S.BuyQty), Numeric=true, Finished=false
    }):OnChanged(function(v) local n=tonumber(v); if n and n>=1 then S.BuyQty=mFloor(n) end end)

    T:AddInput("BuyMax",{Title="Max Purchases (0=∞)", Default="0", Numeric=true, Finished=false
    }):OnChanged(function(v) local n=tonumber(v); S.BuyMax=(n and n>=0) and mFloor(n) or 0 end)
end

-- ════════════════ MISC ════════════════
do
    local T = Tabs.Misc

    T:AddToggle("AntiAFK",{Title="Anti-AFK", Description="Prevents idle kick", Default=S.AntiAFK
    }):OnChanged(function(v) setAFK(v) end)

    T:AddButton({
        Title="Claim All Codes",
        Description="Attempts all "..#Codes.." known codes",
        Callback=function()
            Win:Notify({Title="Codes", Content="Claiming codes...", Duration=3})
            task.spawn(function() claimed=false; claimCodes() end)
        end,
    })

    T:AddButton({
        Title="Rejoin Server",
        Description="Reconnects to a fresh instance",
        Callback=function()
            Win:Notify({Title="Rejoin", Content="Rejoining...", Duration=3})
            task.delay(0.5, rejoin)
        end,
    })

    -- Player info
    T:AddParagraph({Title="Player",    Content=strFormat("@%s  |  ID: %d  |  Age: %d days", LP.Name, LP.UserId, LP.AccountAge)})
    T:AddParagraph({Title="Display",   Content=LP.DisplayName})
    T:AddParagraph({Title="Session",   Content="Loaded"})

    -- Server info (async)
    task.spawn(function()
        task.wait(1)
        local ok, gi = pcall(MS.GetProductInfo, MS, game.PlaceId)
        if ok and gi then
            T:AddParagraph({Title="Game", Content=gi.Name})
        end
    end)
end

-- ════════════════ SETTINGS ════════════════
do
    local T = Tabs.Settings

    T:AddButton({
        Title="Optimize Graphics",
        Description="Lowers quality, disables shadows/FX/particles",
        Callback=function()
            local n = optimizeGraphics()
            Win:Notify({Title="Optimized", Content="Disabled "..n.." effects. FPS should improve.", Duration=4})
        end,
    })

    T:AddButton({
        Title="Clear Particles",
        Description="Disables all active ParticleEmitters and Trails",
        Callback=function()
            local count = 0
            for _,p in ipairs(WS:GetDescendants()) do
                if p:IsA("ParticleEmitter") or p:IsA("Trail") then
                    p.Enabled=false; count=count+1
                end
            end
            Win:Notify({Title="Particles", Content="Disabled "..count.." effects.", Duration=3})
        end,
    })

    T:AddButton({
        Title="Copy Discord",
        Description="discord.gg/AuQqvrJE79",
        Callback=function()
            if setclipboard then pcall(setclipboard,"https://discord.gg/AuQqvrJE79") end
            Win:Notify({Title="Discord", Content="Link copied!", Duration=3})
        end,
    })

    T:AddButton({
        Title="Destroy Script",
        Description="Cleanly removes all hooks and GUIs",
        Callback=function()
            if getgenv and getgenv()._PB_Destroy then
                pcall(getgenv()._PB_Destroy)
            end
        end,
    })

    -- Keybinds (desktop)
    if not IsMobile then
        T:AddKeybind("KBAura",{Title="Kill Aura Toggle", Default=KB.KillAura}):OnChanged(function(v)
            KB.KillAura = v
        end)
        T:AddKeybind("KBToggleUI",{Title="Toggle UI", Default=KB.ToggleUI}):OnChanged(function(v)
            KB.ToggleUI = v
            Win:SetMinimizeKey(v)
        end)
    end
end

-- ── SaveManager / InterfaceManager ───────────────────────────────────────────
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("PixelBlade")
SaveManager:SetFolder("PixelBlade/saves")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

SaveManager:LoadAutoloadConfig()

-- ── Destroy handler ───────────────────────────────────────────────────────────
if getgenv then
    getgenv()._PB_Destroy = function()
        stopDrink(); stopBuy(); stopFly()
        setAFK(false)
        clearESP(); clearTarget()
        KillConns()
        pcall(Win.Destroy, Win)
        pcall(OGui.Destroy, OGui)
    end
end

-- ── Apply saved state ─────────────────────────────────────────────────────────
if S.AutoDrink then startDrink()  end
if S.AutoBuy   then startBuy()    end
if S.AntiAFK   then setAFK(true)  end
applySpeed()

-- ── Notify ready ─────────────────────────────────────────────────────────────
Win:Notify({
    Title    = "Pixel Blade v2",
    Content  = IsMobile and "Loaded  |  Boss DMG patched" or "L = Aura  |  RCtrl = Toggle UI",
    Duration = 5,
})
