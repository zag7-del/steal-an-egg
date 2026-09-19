--[[
 ██╗   ██╗
 ██║   ██║   VAN THANH EXECUTOR
 ╚██╗ ██╔╝   Steal An Egg V4
  ╚████╔╝    Full Stack: Farm · Cheat · ESP · Bypass
   ╚═══╝
]]

----------------------------------------------------------------
-- SAFE GLOBAL FETCH
-- Never call typeof/type on a global that might not exist
-- Use rawget(_G, name) — always safe in any Lua 5.1 env
----------------------------------------------------------------

local function G(name)
    return rawget(_G, name)
end

-- duplicate guard
local _getgenv = G("getgenv")
local _ENV_G = _G
if type(_getgenv) == "function" then
    local ok, env = pcall(_getgenv)
    if ok and type(env) == "table" then
        _ENV_G = env
    end
end
if _ENV_G.__VanThanhV4 then
    if G("warn") then warn("[VT] Already loaded") end
    return
end
_ENV_G.__VanThanhV4 = true

----------------------------------------------------------------
-- COMPAT
----------------------------------------------------------------

local _cloneref       = G("cloneref")
local _newcclosure    = G("newcclosure")
local _hookfunction   = G("hookfunction")
local _hookmetamethod = G("hookmetamethod")
local _islclosure     = G("islclosure")
local _gethui         = G("gethui")
local _syn            = G("syn")
local _fpp            = G("fireproximityprompt")
local _fcd            = G("fireclickdetector")
local _setclipboard   = G("setclipboard")
local _getscriptid    = G("getscriptidentity")
local _identifyexec   = G("identifyexecutor")
local _getnamecall    = G("getnamecallmethod")
local _VIM            = G("VirtualInputManager")

local safeRef = type(_cloneref) == "function"
    and _cloneref or function(x) return x end

local safeClosure = type(_newcclosure) == "function"
    and _newcclosure or function(f) return f end

local safeHook = type(_hookfunction) == "function"
    and _hookfunction or nil

local hookMeta = type(_hookmetamethod) == "function"
    and _hookmetamethod or nil

local isLClosure = type(_islclosure) == "function"
    and _islclosure or function() return true end

----------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------

local Players          = safeRef(game:GetService("Players"))
local Workspace        = safeRef(game:GetService("Workspace"))
local RunService       = safeRef(game:GetService("RunService"))
local UserInputService = safeRef(game:GetService("UserInputService"))
local TeleportService  = safeRef(game:GetService("TeleportService"))
local HttpService      = safeRef(game:GetService("HttpService"))
local ScriptContext    = safeRef(game:GetService("ScriptContext"))
local CoreGui          = safeRef(game:GetService("CoreGui"))
local LocalPlayer      = Players.LocalPlayer

----------------------------------------------------------------
-- INTERNAL LOG
----------------------------------------------------------------

local VT_LOG = {}
local function vtLog(tag, msg)
    local entry = ("[VT][%s] %s"):format(tag, tostring(msg))
    table.insert(VT_LOG, entry)
    if _ENV_G.__VT_DEV and G("print") then print(entry) end
end

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------

local CONFIG = {
    CHECK_INTERVAL   = 0.35,
    TREADMILL_CFRAME = CFrame.new(0, 10, 0),
    WATERFALL_CFRAME = CFrame.new(150, 5, -800),
    MOVE_MODE        = "ZigZag",
    ZIGZAG_OFFSET    = 6,
    STEP_SIZE        = 18,
    RARITY_PRIORITY  = {"Secret","Eternal","Divine","Light","Dark"},
    TARGET_RARITIES  = {Secret=true,Eternal=true,Divine=true,Light=true,Dark=true},
    EXTRA_EGG_PATTERNS = {},
    ANTI = {
        AFK_INTERVAL     = 55,
        RECONNECT        = true,
        PROPERTY_GUARD   = true,
        HUMANOID_RESTORE = true,
        WALK_SPEED       = 16,
        JUMP_POWER       = 50,
        TELEPORT_DELAY   = 0.07,
    },
    BOSS = {
        SCAN_NAMES   = {"Boss","Events","EggBoss","GiantEgg"},
        ATTACK_DELAY = 0.3,
        MAX_RETRIES  = 5,
    },
    SESSION = { START_TICK = tick() },
}

----------------------------------------------------------------
-- FLAGS
----------------------------------------------------------------

local FLAGS = {
    AutoFarm       = false,
    AutoBoss       = false,
    ReturnTreadmill= true,
    Running        = true,
    EggsCollected  = 0,
    BossAttacks    = 0,
    EggsPerMinute  = 0,
    LastEggTick    = tick(),
    CurrentStatus  = "Idle",
    NotifyOnRare   = true,
}

----------------------------------------------------------------
-- CONNECTIONS
----------------------------------------------------------------

local Connections = {}
local function addConn(c)
    if c then table.insert(Connections, c) end
    return c
end

local function cleanupAll()
    FLAGS.Running        = false
    _ENV_G.__VanThanhV4  = nil
    for _, c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    Connections = {}
end

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------

local function getRoot()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function safeConnect(signal, fn)
    if not signal then return nil end
    local ok, conn = pcall(function() return signal:Connect(fn) end)
    if ok and conn then return addConn(conn) end
    return nil
end

local function firePrompt(prompt)
    if not prompt then return end
    if type(_fpp) == "function" then
        pcall(_fpp, prompt)
    elseif type(_fcd) == "function" then
        local cd = prompt.Parent
            and prompt.Parent:FindFirstChildOfClass("ClickDetector")
        if cd then pcall(_fcd, cd) end
    else
        pcall(function()
            prompt:InputHoldBegin()
            task.wait((prompt.HoldDuration or 1) + 0.05)
            prompt:InputHoldEnd()
        end)
    end
end

local function toClipboard(text)
    if type(_setclipboard) == "function" then
        pcall(_setclipboard, text)
    elseif _syn and type(_syn.write_clipboard) == "function" then
        pcall(_syn.write_clipboard, text)
    end
end

local function updateStatus(text)
    FLAGS.CurrentStatus = text
    -- StatusBox filled in after UI builds
end

local function getRarity(obj)
    local attr = obj:GetAttribute("Rarity")
        or obj:GetAttribute("RarityName")
        or obj:GetAttribute("EggRarity")
    if attr then return tostring(attr) end
    local name = string.lower(obj.Name)
    for _, r in ipairs(CONFIG.RARITY_PRIORITY) do
        if string.find(name, string.lower(r)) then return r end
    end
    return nil
end

----------------------------------------------------------------
-- MOVEMENT
----------------------------------------------------------------

local function moveTarget(targetCF)
    local root = getRoot()
    if not root then return end
    if CONFIG.MOVE_MODE == "Direct" then
        root.CFrame = targetCF
        task.wait(CONFIG.ANTI.TELEPORT_DELAY)
        return
    end
    local startPos = root.Position
    local endPos   = targetCF.Position
    local diff     = endPos - startPos
    local dist     = diff.Magnitude
    if dist < 1 then root.CFrame = targetCF return end
    local steps = math.clamp(math.floor(dist/15), 2, 12)
    local dir   = diff.Unit
    local right = dir:Cross(Vector3.new(0,1,0))
    if right.Magnitude < 0.01 then right = Vector3.new(1,0,0)
    else right = right.Unit end
    for i = 1, steps do
        if not FLAGS.Running then break end
        local alpha  = i / steps
        local pos    = startPos:Lerp(endPos, alpha)
        local offset = (CONFIG.MOVE_MODE == "ZigZag")
            and ((i%2==0) and CONFIG.ZIGZAG_OFFSET or -CONFIG.ZIGZAG_OFFSET) or 0
        root.CFrame = CFrame.new(pos + right * offset)
        task.wait(CONFIG.ANTI.TELEPORT_DELAY)
    end
    root.CFrame = targetCF
end

----------------------------------------------------------------
-- ANTI-AFK
----------------------------------------------------------------

task.spawn(safeClosure(function()
    while FLAGS.Running do
        task.wait(CONFIG.ANTI.AFK_INTERVAL)
        if not FLAGS.Running then break end
        pcall(function()
            if _VIM then
                _VIM:SendMouseButtonEvent(0,0,0,true,game,1)
                task.wait(0.05)
                _VIM:SendMouseButtonEvent(0,0,0,false,game,1)
            end
        end)
        pcall(function()
            local hum = getHumanoid()
            if hum then hum.Jump = true end
        end)
    end
end))

----------------------------------------------------------------
-- PROPERTY GUARD
----------------------------------------------------------------

local function guardHumanoid(hum)
    if not hum then return end
    safeConnect(hum:GetPropertyChangedSignal("WalkSpeed"), safeClosure(function()
        task.defer(function()
            pcall(function()
                if hum.WalkSpeed ~= CONFIG.ANTI.WALK_SPEED then
                    hum.WalkSpeed = CONFIG.ANTI.WALK_SPEED
                end
            end)
        end)
    end))
    safeConnect(hum:GetPropertyChangedSignal("JumpPower"), safeClosure(function()
        task.defer(function()
            pcall(function()
                if hum.JumpPower ~= CONFIG.ANTI.JUMP_POWER then
                    hum.JumpPower = CONFIG.ANTI.JUMP_POWER
                end
            end)
        end)
    end))
end

if CONFIG.ANTI.PROPERTY_GUARD then
    pcall(function()
        local char = LocalPlayer.Character
        if char then guardHumanoid(char:FindFirstChildOfClass("Humanoid")) end
    end)
    safeConnect(LocalPlayer.CharacterAdded, safeClosure(function(char)
        pcall(function()
            local hum = char:WaitForChild("Humanoid", 5)
            if not hum then return end
            guardHumanoid(hum)
            if CONFIG.ANTI.HUMANOID_RESTORE then
                task.wait(0.2)
                pcall(function()
                    hum.WalkSpeed = CONFIG.ANTI.WALK_SPEED
                    hum.JumpPower = CONFIG.ANTI.JUMP_POWER
                end)
            end
        end)
    end))
end

----------------------------------------------------------------
-- RECONNECT
----------------------------------------------------------------

local function doReconnect()
    vtLog("RECONNECT", "Reconnecting to " .. tostring(game.PlaceId))
    task.wait(2.5)
    pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
end

if CONFIG.ANTI.RECONNECT then
    safeConnect(LocalPlayer.Kicked, safeClosure(function(reason)
        vtLog("KICKED", tostring(reason or "nil"))
        doReconnect()
    end))
end

----------------------------------------------------------------
-- VAN THANH BYPASS LAYER
-- TEMP BUILD: disabled so the UI/farm/utility portions can run without
-- installing anti-cheat-evasion hooks.
local VT_RemoteLog = {}
local VT_BlockedRemotes = {}
vtLog("BYPASS", "Disabled in temporary compatibility build")

----------------------------------------------------------------
-- FARM LOGIC
----------------------------------------------------------------

local function findPriorityEgg()
    local root = getRoot()
    if not root then return nil end
    local bestEgg,bestPri,bestDist = nil,math.huge,math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local isEgg = (obj:IsA("BasePart") or obj:IsA("Model"))
            and string.find(string.lower(obj.Name),"egg")
            and not string.find(string.lower(obj.Name),"hatch")
        if not isEgg then continue end
        local rarity = getRarity(obj)
        if not rarity or not CONFIG.TARGET_RARITIES[rarity] then continue end
        local pri = math.huge
        for i,r in ipairs(CONFIG.RARITY_PRIORITY) do if r==rarity then pri=i break end end
        local pos = obj:IsA("Model") and obj:GetPivot().Position or obj.Position
        local dist = (root.Position - pos).Magnitude
        if pri < bestPri or (pri==bestPri and dist < bestDist) then
            bestPri=pri bestDist=dist bestEgg=obj
        end
    end
    return bestEgg
end

local function collectEgg(obj)
    if not obj then return end
    local rarity = getRarity(obj) or "?"
    updateStatus("Collecting "..rarity..": "..obj.Name)
    local cf = obj:IsA("Model") and obj:GetPivot() or obj.CFrame
    moveTarget(cf + Vector3.new(0,3,0))
    task.wait(0.15)
    local prompt
    if obj:IsA("Model") then
        prompt = obj:FindFirstChildOfClass("ProximityPrompt")
        if not prompt then
            for _,d in ipairs(obj:GetDescendants()) do
                if d:IsA("ProximityPrompt") then prompt=d break end
            end
        end
    else
        prompt = obj:FindFirstChildOfClass("ProximityPrompt")
            or (obj.Parent and obj.Parent:FindFirstChildOfClass("ProximityPrompt"))
    end
    if prompt then
        firePrompt(prompt)
        FLAGS.EggsCollected += 1
        local elapsed = tick() - CONFIG.SESSION.START_TICK
        FLAGS.EggsPerMinute = math.floor(FLAGS.EggsCollected / math.max(elapsed/60, 0.01))
    end
end

local function goToTreadmill()
    updateStatus("Going to treadmill...")
    moveTarget(CONFIG.TREADMILL_CFRAME)
    for _, p in ipairs(Workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.Parent then
            if string.find(string.lower(p.Parent.Name),"treadmill") then
                firePrompt(p) break
            end
        end
    end
end

local function handleBoss()
    updateStatus("Fighting Boss...")
    local bossFolder
    for _,name in ipairs(CONFIG.BOSS.SCAN_NAMES) do
        bossFolder = Workspace:FindFirstChild(name)
        if bossFolder then break end
    end
    if not bossFolder then updateStatus("Boss not found") return end
    local boss = bossFolder:FindFirstChildOfClass("Model")
    if not boss then return end
    local broot = boss:FindFirstChild("HumanoidRootPart")
    if not broot then return end
    moveTarget(broot.CFrame + Vector3.new(0,5,-8))
    task.wait(CONFIG.BOSS.ATTACK_DELAY)
    local char = LocalPlayer.Character
    if not char then return end
    for _,item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") then pcall(function() item:Activate() end) end
    end
    for _,d in ipairs(boss:GetDescendants()) do
        if d:IsA("ClickDetector") then
            pcall(function() if type(_fcd)=="function" then _fcd(d) end end)
        end
        if d:IsA("ProximityPrompt") then firePrompt(d) end
    end
    FLAGS.BossAttacks += 1
    updateStatus("Boss attacked #"..FLAGS.BossAttacks)
end

----------------------------------------------------------------
-- UI BUILDER
----------------------------------------------------------------

local function getUIParent()
    if type(_gethui)=="function" then
        local ok,h = pcall(_gethui)
        if ok and h then return h end
    end
    local ok,cg = pcall(function() return CoreGui end)
    if ok and cg then return cg end
    return LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
end

-- safe Instance creator — never throws
local function N(class, props, parent)
    local obj
    pcall(function() obj = Instance.new(class) end)
    if not obj then return nil end
    if props then
        for k,v in pairs(props) do pcall(function() obj[k]=v end) end
    end
    if parent then pcall(function() obj.Parent=parent end) end
    return obj
end

-- safe button connect — handles nil or dummy objects
local function onClick(obj, fn)
    if not obj then return end
    pcall(function() obj.MouseButton1Click:Connect(fn) end)
end

local UIParent = getUIParent()
if not UIParent then UIParent = CoreGui end

-- clean old
pcall(function()
    local old = CoreGui:FindFirstChild("StealEggHubV4")
    if old then old:Destroy() end
end)

local ScreenGui = N("ScreenGui",{
    Name="StealEggHubV4", ResetOnSpawn=false,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
}, UIParent)
if not ScreenGui then
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "StealEggHubV4"
    pcall(function() ScreenGui.Parent = CoreGui end)
end
if _syn and type(_syn.protect_gui)=="function" then pcall(_syn.protect_gui, ScreenGui) end

local MainFrame = N("Frame",{
    Name="MainFrame", Size=UDim2.new(0,640,0,450),
    Position=UDim2.new(0.5,-320,0.5,-225),
    BackgroundColor3=Color3.fromRGB(13,13,18),
    BorderSizePixel=0, Active=true, Draggable=true,
}, ScreenGui)
N("UICorner",{CornerRadius=UDim.new(0,12)},MainFrame)
N("UIStroke",{Color=Color3.fromRGB(50,50,70),Thickness=1},MainFrame)

local TopBar = N("Frame",{
    Size=UDim2.new(1,0,0,62),
    BackgroundColor3=Color3.fromRGB(18,18,26), BorderSizePixel=0,
}, MainFrame)
N("UICorner",{CornerRadius=UDim.new(0,12)},TopBar)

-- Logo
local LogoBox = N("Frame",{
    Size=UDim2.new(0,36,0,36), Position=UDim2.new(0,14,0,13),
    BackgroundColor3=Color3.fromRGB(0,0,0), BorderSizePixel=0,
}, TopBar)
N("UICorner",{CornerRadius=UDim.new(0,6)},LogoBox)
N("UIStroke",{Color=Color3.fromRGB(70,70,70),Thickness=1},LogoBox)
N("TextLabel",{
    Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
    Text="V", TextColor3=Color3.fromRGB(255,255,255),
    TextSize=20, Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Center,
    TextYAlignment=Enum.TextYAlignment.Center,
}, LogoBox)

N("TextLabel",{
    Size=UDim2.new(1,-160,0,22), Position=UDim2.new(0,58,0,8),
    BackgroundTransparency=1, Text="VAN THANH  ·  STEAL AN EGG",
    TextColor3=Color3.fromRGB(255,255,255), TextSize=14,
    Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left,
}, TopBar)
N("TextLabel",{
    Size=UDim2.new(1,-160,0,16), Position=UDim2.new(0,58,0,32),
    BackgroundTransparency=1, Text="V4 · Bypass · Farm · Cheat · ESP",
    TextColor3=Color3.fromRGB(100,200,120), TextSize=9,
    Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left,
}, TopBar)

local CloseBtn = N("TextButton",{
    Size=UDim2.new(0,34,0,34), Position=UDim2.new(1,-45,0,14),
    BackgroundColor3=Color3.fromRGB(160,40,50),
    Text="x", TextColor3=Color3.fromRGB(255,255,255),
    TextSize=20, Font=Enum.Font.GothamBold, BorderSizePixel=0,
}, TopBar)
N("UICorner",{CornerRadius=UDim.new(0,8)},CloseBtn)

local Sidebar = N("Frame",{
    Size=UDim2.new(0,148,1,-72), Position=UDim2.new(0,10,0,72),
    BackgroundColor3=Color3.fromRGB(18,18,26), BorderSizePixel=0,
}, MainFrame)
N("UICorner",{CornerRadius=UDim.new(0,9)},Sidebar)

local Content = N("Frame",{
    Size=UDim2.new(1,-173,1,-72), Position=UDim2.new(0,163,0,72),
    BackgroundTransparency=1,
}, MainFrame)

----------------------------------------------------------------
-- TAB / PAGE SYSTEM
----------------------------------------------------------------

local Tabs,Pages = {},{}

local function makePage(name)
    local page = N("ScrollingFrame",{
        Name=name.."Page", Size=UDim2.new(1,-10,1,-10),
        Position=UDim2.new(0,5,0,5), BackgroundTransparency=1,
        BorderSizePixel=0, ScrollBarThickness=3,
        CanvasSize=UDim2.new(0,0,0,0), Visible=false,
    }, Content)
    local layout = N("UIListLayout",{
        Padding=UDim.new(0,8), SortOrder=Enum.SortOrder.LayoutOrder,
    }, page)
    if page and layout then
        safeConnect(layout:GetPropertyChangedSignal("AbsoluteContentSize"),function()
            pcall(function()
                page.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+15)
            end)
        end)
    end
    Pages[name] = page
    return page
end

local function showPage(name)
    for k,p in pairs(Pages) do pcall(function() p.Visible = k==name end) end
    for k,b in pairs(Tabs) do
        pcall(function()
            if k==name then
                b.BackgroundColor3=Color3.fromRGB(60,45,130)
                b.TextColor3=Color3.fromRGB(255,255,255)
            else
                b.BackgroundColor3=Color3.fromRGB(24,24,33)
                b.TextColor3=Color3.fromRGB(155,155,170)
            end
        end)
    end
end

local function makeTab(name, text, order)
    local btn = N("TextButton",{
        Name=name.."Tab",
        Size=UDim2.new(1,-16,0,34),
        Position=UDim2.new(0,8,0,order*40+8),
        BackgroundColor3=Color3.fromRGB(24,24,33),
        BorderSizePixel=0, Text=text,
        TextColor3=Color3.fromRGB(155,155,170),
        TextSize=9, Font=Enum.Font.GothamMedium,
    }, Sidebar)
    N("UICorner",{CornerRadius=UDim.new(0,7)},btn)
    Tabs[name] = btn
    onClick(btn, function() showPage(name) end)
    return btn
end

-- UI helpers
local function Sec(parent,text)
    return N("TextLabel",{
        Size=UDim2.new(1,-10,0,24), BackgroundTransparency=1, Text=text,
        TextColor3=Color3.fromRGB(200,200,220), TextSize=10,
        Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left,
    }, parent)
end

local function Btn(parent,text)
    local b = N("TextButton",{
        Size=UDim2.new(1,-10,0,34), BackgroundColor3=Color3.fromRGB(28,28,38),
        BorderSizePixel=0, Text=text,
        TextColor3=Color3.fromRGB(225,225,230), TextSize=10,
        Font=Enum.Font.GothamMedium,
    }, parent)
    N("UICorner",{CornerRadius=UDim.new(0,7)},b)
    return b
end

local function Lbl(parent,text)
    local l = N("TextLabel",{
        Size=UDim2.new(1,-10,0,28), BackgroundColor3=Color3.fromRGB(22,22,31),
        BorderSizePixel=0, Text=text,
        TextColor3=Color3.fromRGB(175,175,190), TextSize=9,
        Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left,
    }, parent)
    N("UICorner",{CornerRadius=UDim.new(0,6)},l)
    return l
end

local function Toggle(parent,text,init,cb)
    local on = init
    local b  = Btn(parent, text..": "..(on and "ON" or "OFF"))
    local function refresh()
        pcall(function()
            b.Text = text..": "..(on and "ON" or "OFF")
            b.BackgroundColor3 = on and Color3.fromRGB(38,130,65) or Color3.fromRGB(28,28,38)
        end)
    end
    onClick(b, function()
        on = not on refresh()
        if cb then pcall(cb,on) end
    end)
    refresh()
    return b
end

-- PAGES
local HomePage     = makePage("Home")
local FarmPage     = makePage("Farm")
local MovementPage = makePage("Movement")
local BossPage     = makePage("Boss")
local TeleportPage = makePage("Teleport")
local AntiPage     = makePage("Anti")
local BypassPage   = makePage("Bypass")
local CheatPage    = makePage("Cheat")
local ESPPage      = makePage("ESP")
local SettingsPage = makePage("Settings")

-- TABS
makeTab("Home",     "HOME",     0)
makeTab("Farm",     "FARM",     1)
makeTab("Movement", "MOVEMENT", 2)
makeTab("Boss",     "BOSS",     3)
makeTab("Teleport", "TELEPORT", 4)
makeTab("Anti",     "ANTI",     5)
makeTab("Bypass",   "BYPASS",   6)
makeTab("Cheat",    "CHEATS",   7)
makeTab("ESP",      "ESP",      8)
makeTab("Settings", "SETTINGS", 9)

----------------------------------------------------------------
-- HOME PAGE
----------------------------------------------------------------

Sec(HomePage,"DASHBOARD")
local StatusBox   = Lbl(HomePage,"  Status: Idle")
local FarmBox     = Lbl(HomePage,"  Auto Farm: OFF")
local BossBox     = Lbl(HomePage,"  Auto Boss: OFF")
local EggCounter  = Lbl(HomePage,"  Eggs: 0")
local EPMLabel    = Lbl(HomePage,"  Eggs/min: 0")
local SessionLabel= Lbl(HomePage,"  Session: 0m 0s")

local function _updateStatus(text)
    FLAGS.CurrentStatus = text
    pcall(function() StatusBox.Text = "  Status: "..text end)
end

-- override stub
updateStatus = _updateStatus

local function updateDash()
    pcall(function() FarmBox.Text   = "  Auto Farm: "..(FLAGS.AutoFarm and "ON" or "OFF") end)
    pcall(function() BossBox.Text   = "  Auto Boss: "..(FLAGS.AutoBoss and "ON" or "OFF") end)
    pcall(function() EggCounter.Text= "  Eggs: "..FLAGS.EggsCollected end)
    pcall(function() EPMLabel.Text  = "  Eggs/min: "..FLAGS.EggsPerMinute end)
    pcall(function()
        local e = math.floor(tick()-CONFIG.SESSION.START_TICK)
        SessionLabel.Text = ("  Session: %dm %ds"):format(math.floor(e/60),e%60)
    end)
end

Sec(HomePage,"CONTROLS")
local function setFarm(v) FLAGS.AutoFarm=v updateStatus(v and "Farm ON" or "Farm OFF") updateDash() end
local function setBoss(v) FLAGS.AutoBoss=v updateStatus(v and "Boss ON" or "Boss OFF") updateDash() end

onClick(Btn(HomePage,"Toggle Auto Farm"), function() setFarm(not FLAGS.AutoFarm) end)
onClick(Btn(HomePage,"Toggle Auto Boss"), function() setBoss(not FLAGS.AutoBoss) end)

----------------------------------------------------------------
-- FARM PAGE
----------------------------------------------------------------

Sec(FarmPage,"AUTO FARM")
Toggle(FarmPage,"Auto Egg",false,setFarm)
Toggle(FarmPage,"Return Treadmill",true,function(v) FLAGS.ReturnTreadmill=v end)
Toggle(FarmPage,"Notify Rare",true,function(v) FLAGS.NotifyOnRare=v end)
Sec(FarmPage,"RARITY FILTER")
for _,r in ipairs(CONFIG.RARITY_PRIORITY) do
    Toggle(FarmPage,r,CONFIG.TARGET_RARITIES[r],function(v) CONFIG.TARGET_RARITIES[r]=v end)
end

----------------------------------------------------------------
-- MOVEMENT PAGE
----------------------------------------------------------------

Sec(MovementPage,"MODE")
local ModeBtn = Btn(MovementPage,"Mode: ZIGZAG")
onClick(ModeBtn,function()
    CONFIG.MOVE_MODE = CONFIG.MOVE_MODE=="ZigZag" and "Direct" or "ZigZag"
    pcall(function() ModeBtn.Text="Mode: "..string.upper(CONFIG.MOVE_MODE) end)
end)

Sec(MovementPage,"SAVED POS")
local SaveBtn = Btn(MovementPage,"Save Position")
local GoBtn   = Btn(MovementPage,"Go To Saved")
onClick(SaveBtn,function()
    local r=getRoot() if r then CONFIG.TREADMILL_CFRAME=r.CFrame end
    pcall(function() SaveBtn.Text="Saved ✓" end)
    task.delay(1.5,function() pcall(function() SaveBtn.Text="Save Position" end) end)
end)
onClick(GoBtn,function() moveTarget(CONFIG.TREADMILL_CFRAME) end)

Sec(MovementPage,"TELEPORT DELAY")
local TdLbl = Lbl(MovementPage,"  Delay: "..CONFIG.ANTI.TELEPORT_DELAY)
onClick(Btn(MovementPage,"Faster"),function()
    CONFIG.ANTI.TELEPORT_DELAY=math.max(0.01,CONFIG.ANTI.TELEPORT_DELAY-0.01)
    pcall(function() TdLbl.Text=("  Delay: %.2f"):format(CONFIG.ANTI.TELEPORT_DELAY) end)
end)
onClick(Btn(MovementPage,"Slower"),function()
    CONFIG.ANTI.TELEPORT_DELAY=math.min(0.3,CONFIG.ANTI.TELEPORT_DELAY+0.01)
    pcall(function() TdLbl.Text=("  Delay: %.2f"):format(CONFIG.ANTI.TELEPORT_DELAY) end)
end)

----------------------------------------------------------------
-- BOSS PAGE
----------------------------------------------------------------

Sec(BossPage,"AUTO BOSS")
Toggle(BossPage,"Auto Boss",false,setBoss)
onClick(Btn(BossPage,"Attack Once"),function() pcall(handleBoss) end)

----------------------------------------------------------------
-- TELEPORT PAGE
----------------------------------------------------------------

Sec(TeleportPage,"LOCATIONS")
onClick(Btn(TeleportPage,"Secret Waterfall"),function()
    moveTarget(CONFIG.WATERFALL_CFRAME) updateStatus("Waterfall")
end)
onClick(Btn(TeleportPage,"Treadmill"),function()
    moveTarget(CONFIG.TREADMILL_CFRAME) updateStatus("Treadmill")
end)

----------------------------------------------------------------
-- ANTI PAGE
----------------------------------------------------------------

Sec(AntiPage,"STATUS")
Lbl(AntiPage,"  Anti-AFK: ON")
Lbl(AntiPage,"  Reconnect: "..(CONFIG.ANTI.RECONNECT and "ON" or "OFF"))
Lbl(AntiPage,"  Property Guard: "..(CONFIG.ANTI.PROPERTY_GUARD and "ON" or "OFF"))
Sec(AntiPage,"WALK SPEED")
local WsLbl = Lbl(AntiPage,"  WalkSpeed: "..CONFIG.ANTI.WALK_SPEED)
onClick(Btn(AntiPage,"Speed +2"),function()
    CONFIG.ANTI.WALK_SPEED+=2
    pcall(function() WsLbl.Text="  WalkSpeed: "..CONFIG.ANTI.WALK_SPEED end)
    pcall(function() local h=getHumanoid() if h then h.WalkSpeed=CONFIG.ANTI.WALK_SPEED end end)
end)
onClick(Btn(AntiPage,"Speed -2"),function()
    CONFIG.ANTI.WALK_SPEED=math.max(4,CONFIG.ANTI.WALK_SPEED-2)
    pcall(function() WsLbl.Text="  WalkSpeed: "..CONFIG.ANTI.WALK_SPEED end)
    pcall(function() local h=getHumanoid() if h then h.WalkSpeed=CONFIG.ANTI.WALK_SPEED end end)
end)

----------------------------------------------------------------
-- BYPASS PAGE
----------------------------------------------------------------

Sec(BypassPage,"COMPAT STATUS")
local function BPLbl(text,active)
    local l=Lbl(BypassPage,"  "..text)
    pcall(function()
        l.TextColor3=active and Color3.fromRGB(80,210,110) or Color3.fromRGB(200,80,80)
    end)
    return l
end
BPLbl("Bypass hooks", false)
BPLbl("Bypass disabled", true)
BPLbl("Executor compatibility", true)
BPLbl("Safe mode", true)
BPLbl("HTTP interception", false)
BPLbl("Kick interception", false)
BPLbl("Shutdown interception", false)
BPLbl("Gravity hook", false)
BPLbl("Error logging", true)
BPLbl("Environment cleanup", true)
BPLbl("Integrity hooks", false)

Sec(BypassPage,"REMOTE LOG")
local RmtLbl = Lbl(BypassPage,"  Remotes: 0")
onClick(Btn(BypassPage,"Copy Log"),function()
    toClipboard(table.concat(VT_LOG,"\n")) updateStatus("Log copied")
end)

----------------------------------------------------------------
-- CHEAT PAGE
----------------------------------------------------------------

local CHEAT = {
    Fly=false, FlySpeed=60,
    Noclip=false, SpeedHack=false, SpeedValue=60,
    InfJump=false, GodMode=false,
    PullEggs=false, PullRadius=80, AutoCollect=false,
}

-- Fly
local flyConn
local function startFly()
    local char=LocalPlayer.Character if not char then return end
    local root=char:FindFirstChild("HumanoidRootPart")
    local hum=char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    hum.PlatformStand=true
    local bv=Instance.new("BodyVelocity")
    bv.Velocity=Vector3.zero bv.MaxForce=Vector3.new(1e5,1e5,1e5) bv.P=1e4 bv.Parent=root
    local bg=Instance.new("BodyGyro")
    bg.MaxTorque=Vector3.new(1e5,1e5,1e5) bg.P=1e4 bg.D=500 bg.CFrame=root.CFrame bg.Parent=root
    local cam=workspace.CurrentCamera
    flyConn=RunService.Heartbeat:Connect(safeClosure(function()
        if not CHEAT.Fly then
            pcall(function() bv:Destroy() bg:Destroy() hum.PlatformStand=false end)
            flyConn:Disconnect() flyConn=nil return
        end
        local mv=Vector3.zero local cf=cam.CFrame local sp=CHEAT.FlySpeed
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv-cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv-cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv=mv+Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv=mv-Vector3.new(0,1,0) end
        bv.Velocity = mv.Magnitude>0 and mv.Unit*sp or Vector3.zero
        bg.CFrame=cf
    end))
end

-- Noclip
local noclipConn
local function startNoclip()
    noclipConn=RunService.Stepped:Connect(safeClosure(function()
        if not CHEAT.Noclip then
            noclipConn:Disconnect() noclipConn=nil
            pcall(function()
                local c=LocalPlayer.Character if not c then return end
                for _,p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide=true end
                end
            end)
            return
        end
        pcall(function()
            local c=LocalPlayer.Character if not c then return end
            for _,p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then
                    p.CanCollide=false
                end
            end
        end)
    end))
end

-- Inf jump
local ijConn
local function startInfJump()
    ijConn=UserInputService.JumpRequest:Connect(safeClosure(function()
        if not CHEAT.InfJump then ijConn:Disconnect() ijConn=nil return end
        local h=getHumanoid()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end))
end

-- God
local godConn
local function startGod()
    godConn=RunService.Heartbeat:Connect(safeClosure(function()
        if not CHEAT.GodMode then godConn:Disconnect() godConn=nil return end
        pcall(function()
            local h=getHumanoid()
            if h and h.Health<h.MaxHealth then h.Health=h.MaxHealth end
        end)
    end))
end

-- Pull
local pullConn
local function startPull()
    pullConn=RunService.Heartbeat:Connect(safeClosure(function()
        if not CHEAT.PullEggs then pullConn:Disconnect() pullConn=nil return end
        local root=getRoot() if not root then return end
        for _,obj in ipairs(Workspace:GetDescendants()) do
            local isEgg=(obj:IsA("BasePart") or obj:IsA("Model"))
                and string.find(string.lower(obj.Name),"egg")
                and not string.find(string.lower(obj.Name),"hatch")
            if not isEgg then continue end
            local pos=obj:IsA("Model") and obj:GetPivot().Position or obj.Position
            if (root.Position-pos).Magnitude<=CHEAT.PullRadius then
                pcall(function()
                    if obj:IsA("Model") then
                        obj:PivotTo(CFrame.new(root.Position+Vector3.new(0,2,0)))
                    else
                        obj.CFrame=CFrame.new(root.Position+Vector3.new(0,2,0))
                    end
                end)
                if CHEAT.AutoCollect then pcall(collectEgg,obj) end
            end
        end
    end))
end

Sec(CheatPage,"FLY")
Toggle(CheatPage,"Fly",false,function(v)
    CHEAT.Fly=v if v then startFly() end
    updateStatus(v and "Fly ON" or "Fly OFF")
end)
local FlySpLbl=Lbl(CheatPage,"  Fly Speed: "..CHEAT.FlySpeed)
onClick(Btn(CheatPage,"Speed +10"),function()
    CHEAT.FlySpeed=math.min(500,CHEAT.FlySpeed+10)
    pcall(function() FlySpLbl.Text="  Fly Speed: "..CHEAT.FlySpeed end)
end)
onClick(Btn(CheatPage,"Speed -10"),function()
    CHEAT.FlySpeed=math.max(10,CHEAT.FlySpeed-10)
    pcall(function() FlySpLbl.Text="  Fly Speed: "..CHEAT.FlySpeed end)
end)

Sec(CheatPage,"MOVEMENT")
Toggle(CheatPage,"Noclip",false,function(v)
    CHEAT.Noclip=v if v then startNoclip() end
    updateStatus(v and "Noclip ON" or "Noclip OFF")
end)
Toggle(CheatPage,"Infinite Jump",false,function(v)
    CHEAT.InfJump=v if v then startInfJump() end
    updateStatus(v and "Inf Jump ON" or "Inf Jump OFF")
end)

Sec(CheatPage,"SPEED HACK")
local HkSpLbl=Lbl(CheatPage,"  Hack Speed: "..CHEAT.SpeedValue)
Toggle(CheatPage,"Speed Hack",false,function(v)
    CHEAT.SpeedHack=v
    local h=getHumanoid()
    if h then h.WalkSpeed=v and CHEAT.SpeedValue or CONFIG.ANTI.WALK_SPEED end
    updateStatus(v and "SpeedHack ON" or "SpeedHack OFF")
end)
onClick(Btn(CheatPage,"+10"),function()
    CHEAT.SpeedValue=math.min(500,CHEAT.SpeedValue+10)
    pcall(function() HkSpLbl.Text="  Hack Speed: "..CHEAT.SpeedValue end)
    if CHEAT.SpeedHack then pcall(function()
        local h=getHumanoid() if h then h.WalkSpeed=CHEAT.SpeedValue end
    end) end
end)
onClick(Btn(CheatPage,"-10"),function()
    CHEAT.SpeedValue=math.max(16,CHEAT.SpeedValue-10)
    pcall(function() HkSpLbl.Text="  Hack Speed: "..CHEAT.SpeedValue end)
    if CHEAT.SpeedHack then pcall(function()
        local h=getHumanoid() if h then h.WalkSpeed=CHEAT.SpeedValue end
    end) end
end)

Sec(CheatPage,"SURVIVAL")
Toggle(CheatPage,"God Mode",false,function(v)
    CHEAT.GodMode=v if v then startGod() end
    updateStatus(v and "God ON" or "God OFF")
end)

Sec(CheatPage,"EGG VACUUM")
local PrLbl=Lbl(CheatPage,"  Radius: "..CHEAT.PullRadius)
Toggle(CheatPage,"Egg Pull",false,function(v)
    CHEAT.PullEggs=v if v then startPull() end
    updateStatus(v and "Pull ON" or "Pull OFF")
end)
Toggle(CheatPage,"Auto Collect",false,function(v) CHEAT.AutoCollect=v end)
onClick(Btn(CheatPage,"Radius +20"),function()
    CHEAT.PullRadius=math.min(500,CHEAT.PullRadius+20)
    pcall(function() PrLbl.Text="  Radius: "..CHEAT.PullRadius end)
end)
onClick(Btn(CheatPage,"Radius -20"),function()
    CHEAT.PullRadius=math.max(20,CHEAT.PullRadius-20)
    pcall(function() PrLbl.Text="  Radius: "..CHEAT.PullRadius end)
end)

----------------------------------------------------------------
-- ESP PAGE
----------------------------------------------------------------

local ESP={Players=false,Eggs=false,MaxDist=500,Tags={},Boxes={}}
local ESPFolder=N("Folder",{Name="VT_ESP"},CoreGui)

local ESP_COLORS={
    Secret=Color3.fromRGB(255,215,0), Eternal=Color3.fromRGB(180,0,255),
    Divine=Color3.fromRGB(255,120,0), Light=Color3.fromRGB(200,230,255),
    Dark=Color3.fromRGB(80,0,160),    Player=Color3.fromRGB(255,80,80),
    Default=Color3.fromRGB(255,255,255),
}

local function makeTag(adornee,text,color,key)
    if not adornee or ESP.Tags[key] then return end
    local bb=N("BillboardGui",{
        Name="VT_ESP",Size=UDim2.new(0,120,0,40),
        StudsOffset=Vector3.new(0,3,0),AlwaysOnTop=true,Adornee=adornee,
    },ESPFolder)
    if not bb then return end
    local fr=N("Frame",{
        Size=UDim2.new(1,0,1,0),BackgroundColor3=Color3.fromRGB(0,0,0),
        BackgroundTransparency=0.4,BorderSizePixel=0,
    },bb)
    N("UICorner",{CornerRadius=UDim.new(0,4)},fr)
    N("TextLabel",{
        Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=text,
        TextColor3=color,TextSize=10,Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Center,
        TextYAlignment=Enum.TextYAlignment.Center,
    },fr)
    ESP.Tags[key]=bb
end

local function makeBox(adornee,color,key)
    if not adornee or ESP.Boxes[key] then return end
    local sb=N("SelectionBox",{
        Color3=color,LineThickness=0.05,
        SurfaceTransparency=0.8,SurfaceColor3=color,Adornee=adornee,
    },ESPFolder)
    ESP.Boxes[key]=sb
end

local function removeESP(key)
    if ESP.Tags[key] then pcall(function() ESP.Tags[key]:Destroy() end) ESP.Tags[key]=nil end
    if ESP.Boxes[key] then pcall(function() ESP.Boxes[key]:Destroy() end) ESP.Boxes[key]=nil end
end

local function clearESP()
    for k in pairs(ESP.Tags) do removeESP(k) end
    if ESPFolder then pcall(function() ESPFolder:ClearAllChildren() end) end
end

local espConn
local function startESP()
    if espConn then return end
    espConn=RunService.Heartbeat:Connect(safeClosure(function()
        if not ESP.Players and not ESP.Eggs then
            espConn:Disconnect() espConn=nil clearESP() return
        end
        local root=getRoot()
        local myPos=root and root.Position or Vector3.zero
        if ESP.Players then
            for _,plr in ipairs(Players:GetPlayers()) do
                if plr==LocalPlayer then continue end
                local char=plr.Character
                local pr=char and char:FindFirstChild("HumanoidRootPart")
                if not pr then removeESP(plr.UserId) continue end
                local dist=(myPos-pr.Position).Magnitude
                if dist>ESP.MaxDist then removeESP(plr.UserId) continue end
                makeTag(pr,plr.Name.."\n["..math.floor(dist).."]",ESP_COLORS.Player,plr.UserId)
                makeBox(char,ESP_COLORS.Player,"box_"..plr.UserId)
            end
        end
        if ESP.Eggs then
            local seen={}
            for _,obj in ipairs(Workspace:GetDescendants()) do
                local isEgg=(obj:IsA("BasePart") or obj:IsA("Model"))
                    and string.find(string.lower(obj.Name),"egg")
                    and not string.find(string.lower(obj.Name),"hatch")
                if not isEgg then continue end
                local pos=obj:IsA("Model") and obj:GetPivot().Position or obj.Position
                local dist=(myPos-pos).Magnitude
                if dist>ESP.MaxDist then continue end
                local rarity=getRarity(obj) or "?"
                local color=ESP_COLORS[rarity] or ESP_COLORS.Default
                local key=tostring(obj)
                local adornee=obj:IsA("Model")
                    and (obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart"))
                    or obj
                if adornee then
                    makeTag(adornee,rarity.."\n["..math.floor(dist).."]",color,key)
                    makeBox(adornee,color,"box_"..key)
                end
                seen[key]=true
            end
            for key in pairs(ESP.Tags) do
                if not seen[key] and not tostring(key):find("^%d+$") then
                    removeESP(key) removeESP("box_"..key)
                end
            end
        end
    end))
end

Sec(ESPPage,"PLAYER ESP")
Toggle(ESPPage,"Player ESP",false,function(v)
    ESP.Players=v if v then startESP() end
    updateStatus(v and "Player ESP ON" or "Player ESP OFF")
end)
Sec(ESPPage,"EGG ESP")
Toggle(ESPPage,"Egg ESP",false,function(v)
    ESP.Eggs=v if v then startESP() end
    updateStatus(v and "Egg ESP ON" or "Egg ESP OFF")
end)
Sec(ESPPage,"SETTINGS")
local EDLbl=Lbl(ESPPage,"  Max Dist: "..ESP.MaxDist)
onClick(Btn(ESPPage,"Dist +50"),function()
    ESP.MaxDist=math.min(2000,ESP.MaxDist+50)
    pcall(function() EDLbl.Text="  Max Dist: "..ESP.MaxDist end)
end)
onClick(Btn(ESPPage,"Dist -50"),function()
    ESP.MaxDist=math.max(50,ESP.MaxDist-50)
    pcall(function() EDLbl.Text="  Max Dist: "..ESP.MaxDist end)
end)
onClick(Btn(ESPPage,"Clear ESP"),function() clearESP() end)
Sec(ESPPage,"COLORS")
Lbl(ESPPage,"  Gold=Secret  Purple=Eternal  Orange=Divine")
Lbl(ESPPage,"  Blue=Light   Dark=Dark        Red=Player")

----------------------------------------------------------------
-- SETTINGS PAGE
----------------------------------------------------------------

Sec(SettingsPage,"UI")
onClick(Btn(SettingsPage,"Hide UI"),function()
    pcall(function() MainFrame.Visible=false end)
end)
onClick(Btn(SettingsPage,"Reset Stats"),function()
    FLAGS.EggsCollected=0 FLAGS.BossAttacks=0
    FLAGS.EggsPerMinute=0 CONFIG.SESSION.START_TICK=tick()
    updateDash() updateStatus("Reset")
end)
onClick(Btn(SettingsPage,"Unload"),function()
    cleanupAll()
    pcall(function() ScreenGui:Destroy() end)
    print("[VAN THANH V4] Unloaded")
end)
Lbl(SettingsPage,"  RightShift = toggle UI")

----------------------------------------------------------------
-- CLOSE / KEYBIND
----------------------------------------------------------------

onClick(CloseBtn, function() pcall(function() MainFrame.Visible=false end) end)

safeConnect(UserInputService.InputBegan, safeClosure(function(input, processed)
    if processed then return end
    if input.KeyCode==Enum.KeyCode.RightShift then
        pcall(function() MainFrame.Visible=not MainFrame.Visible end)
    end
end))

----------------------------------------------------------------
-- FLOATING BADGE
----------------------------------------------------------------

task.spawn(safeClosure(function()
    local sg2=N("ScreenGui",{Name="VTBadge",ResetOnSpawn=false,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling,},UIParent)
    if not sg2 then return end
    if _syn and type(_syn.protect_gui)=="function" then pcall(_syn.protect_gui,sg2) end

    local badge=N("Frame",{
        Size=UDim2.new(0,46,0,46), Position=UDim2.new(1,-60,0,12),
        BackgroundColor3=Color3.fromRGB(0,0,0), BorderSizePixel=0, Active=true,
    },sg2)
    if not badge then return end
    N("UICorner",{CornerRadius=UDim.new(0,8)},badge)
    N("UIStroke",{Color=Color3.fromRGB(55,55,55),Thickness=1},badge)
    N("TextLabel",{
        Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
        Text="V", TextColor3=Color3.fromRGB(255,255,255),
        TextSize=24, Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Center,
        TextYAlignment=Enum.TextYAlignment.Center,
    },badge)
    local cb=N("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=""},badge)
    onClick(cb,function() pcall(function() MainFrame.Visible=not MainFrame.Visible end) end)

    -- drag
    local dragging,ds,fp=false,nil,nil
    safeConnect(badge.InputBegan,function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true ds=inp.Position fp=badge.Position
        end
    end)
    safeConnect(UserInputService.InputChanged,function(inp)
        if dragging and inp.UserInputType==Enum.UserInputType.MouseMovement then
            local d=inp.Position-ds
            pcall(function()
                badge.Position=UDim2.new(fp.X.Scale,fp.X.Offset+d.X,fp.Y.Scale,fp.Y.Offset+d.Y)
            end)
        end
    end)
    safeConnect(UserInputService.InputEnded,function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end)
end))

----------------------------------------------------------------
-- MAIN LOOP
----------------------------------------------------------------

task.spawn(safeClosure(function()
    while FLAGS.Running do
        if FLAGS.AutoBoss then
            pcall(handleBoss)
        elseif FLAGS.AutoFarm then
            pcall(function()
                local egg=findPriorityEgg()
                if egg then collectEgg(egg)
                elseif FLAGS.ReturnTreadmill then goToTreadmill()
                else updateStatus("Waiting...") end
            end)
        else
            if FLAGS.CurrentStatus~="Idle" then updateStatus("Idle") end
        end
        task.wait(CONFIG.CHECK_INTERVAL)
    end
end))

-- REFRESH LOOP
task.spawn(safeClosure(function()
    while FLAGS.Running do
        updateDash()
        pcall(function() RmtLbl.Text="  Remotes: "..#VT_RemoteLog end)
        task.wait(0.5)
    end
end))

----------------------------------------------------------------
-- INIT
----------------------------------------------------------------

showPage("Home")
updateDash()
updateStatus("Ready")
print("[VAN THANH V4 TEMP] Loaded. Bypass hooks disabled.")
