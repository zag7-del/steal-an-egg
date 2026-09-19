--[[
    VAN THANH - STEAL AN EGG V4 FULL
    Updated & Enhanced Version
    - Anti-Cheat & Kick Bypass Enabled
    - Fixed Fly & Noclip Physics
    - Advanced Color-coded Egg ESP
    - Auto Reconnect System Integrated
]]

----------------------------------------------------------------
-- SAFE GLOBALS & ENVIRONMENT CHECK
----------------------------------------------------------------

local function G(name)
    return rawget(_G, name)
end

local _getgenv = G("getgenv")
local ENV = _G

if type(_getgenv) == "function" then
    local ok, result = pcall(_getgenv)
    if ok and type(result) == "table" then
        ENV = result
    end
end

if ENV.__VanThanhV4 then
    local warnFn = G("warn")
    if type(warnFn) == "function" then
        warnFn("[VT] Already loaded!")
    end
    return
end

ENV.__VanThanhV4 = true

----------------------------------------------------------------
-- COMPATIBILITY WRAPPERS
----------------------------------------------------------------

local cloneref = G("cloneref") or function(v) return v end
local gethui = G("gethui")
local fireproximityprompt = G("fireproximityprompt")
local fireclickdetector = G("fireclickdetector")
local setclipboard = G("setclipboard")
local hookmetamethod = G("hookmetamethod")
local getnamecallmethod = G("getnamecallmethod")
local checkcaller = G("checkcaller")

local function safeRef(obj)
    if type(cloneref) == "function" then
        local ok, result = pcall(cloneref, obj)
        if ok and result then return result end
    end
    return obj
end

----------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------

local Players = safeRef(game:GetService("Players"))
local Workspace = safeRef(game:GetService("Workspace"))
local RunService = safeRef(game:GetService("RunService"))
local UserInputService = safeRef(game:GetService("UserInputService"))
local TeleportService = safeRef(game:GetService("TeleportService"))
local CoreGui = safeRef(game:GetService("CoreGui"))
local GuiService = safeRef(game:GetService("GuiService"))

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

----------------------------------------------------------------
-- LOG SYSTEM
----------------------------------------------------------------

local LOG = {}
local function log(tag, text)
    local msg = string.format("[VT][%s] %s", tostring(tag), tostring(text))
    table.insert(LOG, msg)
    if ENV.__VT_DEV then
        print(msg)
    end
end

----------------------------------------------------------------
-- ANTI-CHEAT & BYPASS LAYER
----------------------------------------------------------------

local function initBypass()
    if type(hookmetamethod) == "function" and type(getnamecallmethod) == "function" then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if not (checkcaller and checkcaller()) then
                -- Block Kick
                if method == "Kick" or method == "kick" then
                    log("BYPASS", "Blocked LocalPlayer:Kick() attempt")
                    return nil
                end

                -- Block Anti-Cheat Remote Signals
                if method == "FireServer" or method == "InvokeServer" then
                    local remoteName = string.lower(tostring(self))
                    if string.find(remoteName, "cheat") or string.find(remoteName, "ban") 
                       or string.find(remoteName, "detect") or string.find(remoteName, "flag") 
                       or string.find(remoteName, "exploit") then
                        log("BYPASS", "Blocked Anti-Cheat Remote: " .. tostring(self))
                        return nil
                    end
                end
            end

            return oldNamecall(self, ...)
        end)

        log("BYPASS", "Metamethod Anti-Cheat Bypass Active")
    else
        log("BYPASS", "Executor does not support hookmetamethod - Skipping Metamethod Bypass")
    end
end

task.spawn(initBypass)

----------------------------------------------------------------
-- CONFIGURATION
----------------------------------------------------------------

local CONFIG = {
    CHECK_INTERVAL = 0.25,
    MOVE_MODE = "ZigZag",
    ZIGZAG_OFFSET = 5,
    TELEPORT_DELAY = 0.05,

    TREADMILL_CFRAME = CFrame.new(0, 10, 0),
    WATERFALL_CFRAME = CFrame.new(150, 5, -800),

    RARITY_PRIORITY = {"Secret", "Eternal", "Divine", "Light", "Dark"},
    TARGET_RARITIES = {
        Secret = true,
        Eternal = true,
        Divine = true,
        Light = true,
        Dark = true
    },

    RARITY_COLORS = {
        Secret = Color3.fromRGB(255, 0, 128),
        Eternal = Color3.fromRGB(255, 215, 0),
        Divine = Color3.fromRGB(0, 230, 255),
        Light = Color3.fromRGB(255, 255, 180),
        Dark = Color3.fromRGB(130, 50, 200)
    },

    WALK_SPEED = 16,
    JUMP_POWER = 50,
    AUTO_RECONNECT = true
}

----------------------------------------------------------------
-- RUNTIME FLAGS
----------------------------------------------------------------

local FLAGS = {
    Running = true,
    AutoFarm = false,
    AutoBoss = false,
    ReturnTreadmill = true,
    NotifyRare = true,

    EggsCollected = 0,
    BossAttacks = 0,
    EggsPerMinute = 0,

    SessionStart = tick(),
    Status = "Ready"
}

----------------------------------------------------------------
-- CONNECTION MANAGEMENT
----------------------------------------------------------------

local Connections = {}
local function connect(signal, callback)
    if not signal then return nil end
    local ok, conn = pcall(function() return signal:Connect(callback) end)
    if ok and conn then
        table.insert(Connections, conn)
        return conn
    end
    return nil
end

local function cleanup()
    FLAGS.Running = false
    ENV.__VanThanhV4 = nil
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(Connections)
end

----------------------------------------------------------------
-- HELPER FUNCTIONS
----------------------------------------------------------------

local function getCharacter() return LocalPlayer.Character end
local function getRoot()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end
local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local StatusLabel
local function setStatus(text)
    FLAGS.Status = tostring(text)
    if StatusLabel then
        pcall(function() StatusLabel.Text = "  Status: " .. FLAGS.Status end)
    end
end

local function getRarity(object)
    if not object then return nil end
    local rarity
    pcall(function()
        rarity = object:GetAttribute("Rarity") 
              or object:GetAttribute("RarityName") 
              or object:GetAttribute("EggRarity")
    end)
    if rarity then return tostring(rarity) end

    local name = string.lower(object.Name)
    for _, rarityName in ipairs(CONFIG.RARITY_PRIORITY) do
        if string.find(name, string.lower(rarityName), 1, true) then
            return rarityName
        end
    end
    return nil
end

----------------------------------------------------------------
-- PROMPT & ACTION HELPERS
----------------------------------------------------------------

local function firePrompt(prompt)
    if not prompt or not prompt.Parent then return false end
    if type(fireproximityprompt) == "function" then
        local ok = pcall(fireproximityprompt, prompt)
        if ok then return true end
    end
    pcall(function()
        prompt:InputHoldBegin()
        task.wait((prompt.HoldDuration or 0.2) + 0.02)
        prompt:InputHoldEnd()
    end)
    return true
end

local function fireClick(detector)
    if not detector or not detector.Parent then return false end
    if type(fireclickdetector) == "function" then
        return pcall(fireclickdetector, detector)
    end
    return false
end

local function copyText(text)
    if type(setclipboard) == "function" then
        pcall(setclipboard, text)
    end
end

----------------------------------------------------------------
-- MOVEMENT ENGINE
----------------------------------------------------------------

local function moveTarget(targetCFrame)
    local root = getRoot()
    if not root or not targetCFrame then return end

    if CONFIG.MOVE_MODE == "Direct" then
        pcall(function() root.CFrame = targetCFrame end)
        task.wait(CONFIG.TELEPORT_DELAY)
        return
    end

    local startPos = root.Position
    local endPos = targetCFrame.Position
    local diff = endPos - startPos
    local dist = diff.Magnitude

    if dist < 2 then
        root.CFrame = targetCFrame
        return
    end

    local steps = math.clamp(math.floor(dist / 12), 2, 10)
    local dir = diff.Unit
    local right = dir:Cross(Vector3.new(0, 1, 0))
    right = (right.Magnitude < 0.01) and Vector3.new(1, 0, 0) or right.Unit

    for i = 1, steps do
        if not FLAGS.Running then break end
        local alpha = i / steps
        local pos = startPos:Lerp(endPos, alpha)
        local offset = (i % 2 == 0) and CONFIG.ZIGZAG_OFFSET or -CONFIG.ZIGZAG_OFFSET
        pcall(function()
            root.CFrame = CFrame.new(pos + right * offset)
        end)
        task.wait(CONFIG.TELEPORT_DELAY)
    end

    pcall(function() root.CFrame = targetCFrame end)
end

----------------------------------------------------------------
-- FARMING LOGIC
----------------------------------------------------------------

local function findPriorityEgg()
    local root = getRoot()
    if not root then return nil end

    local bestEgg = nil
    local bestPriority = math.huge
    local bestDistance = math.huge

    for _, object in ipairs(Workspace:GetDescendants()) do
        local isEgg = false
        pcall(function()
            if object:IsA("BasePart") or object:IsA("Model") then
                local name = string.lower(object.Name)
                if string.find(name, "egg", 1, true) and not string.find(name, "hatch", 1, true) then
                    isEgg = true
                end
            end
        end)

        if isEgg then
            local rarity = getRarity(object)
            if rarity and CONFIG.TARGET_RARITIES[rarity] then
                local priority = math.huge
                for idx, rarityName in ipairs(CONFIG.RARITY_PRIORITY) do
                    if rarityName == rarity then priority = idx; break end
                end

                local pos
                pcall(function()
                    pos = object:IsA("Model") and object:GetPivot().Position or object.Position
                end)

                if pos then
                    local dist = (root.Position - pos).Magnitude
                    if priority < bestPriority or (priority == bestPriority and dist < bestDistance) then
                        bestEgg = object
                        bestPriority = priority
                        bestDistance = dist
                    end
                end
            end
        end
    end
    return bestEgg
end

local function collectEgg(object)
    if not object or not object.Parent then return end
    local rarity = getRarity(object) or "?"
    setStatus("Collecting " .. tostring(rarity) .. ": " .. tostring(object.Name))

    local targetCFrame
    pcall(function()
        targetCFrame = object:IsA("Model") and object:GetPivot() or object.CFrame
    end)
    if not targetCFrame then return end

    moveTarget(targetCFrame + Vector3.new(0, 3, 0))
    task.wait(0.1)

    local prompt = nil
    pcall(function()
        prompt = object:FindFirstChildOfClass("ProximityPrompt")
        if not prompt then
            for _, desc in ipairs(object:GetDescendants()) do
                if desc:IsA("ProximityPrompt") then prompt = desc; break end
            end
        end
    end)

    if prompt then
        firePrompt(prompt)
        FLAGS.EggsCollected += 1
        local elapsed = math.max(tick() - FLAGS.SessionStart, 0.01)
        FLAGS.EggsPerMinute = math.floor(FLAGS.EggsCollected / (elapsed / 60))
    end
end

local function goToTreadmill()
    setStatus("Returning to treadmill...")
    moveTarget(CONFIG.TREADMILL_CFRAME)

    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("ProximityPrompt") and object.Parent then
            if string.find(string.lower(object.Parent.Name), "treadmill", 1, true) then
                firePrompt(object)
                break
            end
        end
    end
end

----------------------------------------------------------------
-- BOSS FIGHT ENGINE
----------------------------------------------------------------

local function attackBoss()
    setStatus("Fighting Boss...")
    local bossFolder
    local names = {"Boss", "Events", "EggBoss", "GiantEgg"}

    for _, name in ipairs(names) do
        bossFolder = Workspace:FindFirstChild(name)
        if bossFolder then break end
    end

    if not bossFolder then setStatus("Boss not found"); return end
    local boss = bossFolder:FindFirstChildOfClass("Model")
    if not boss then setStatus("Boss model not found"); return end

    local bossRoot = boss:FindFirstChild("HumanoidRootPart") or boss.PrimaryPart
    if not bossRoot then setStatus("Boss root not found"); return end

    moveTarget(bossRoot.CFrame + Vector3.new(0, 5, -8))
    task.wait(0.2)

    local char = getCharacter()
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then
                pcall(function() item:Activate() end)
            end
        end
    end

    for _, desc in ipairs(boss:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            firePrompt(desc)
        elseif desc:IsA("ClickDetector") then
            fireClick(desc)
        end
    end

    FLAGS.BossAttacks += 1
    setStatus("Boss attacked #" .. tostring(FLAGS.BossAttacks))
end

----------------------------------------------------------------
-- ANTI-AFK & RECONNECT
----------------------------------------------------------------

task.spawn(function()
    while FLAGS.Running do
        task.wait(50)
        if not FLAGS.Running then break end
        pcall(function()
            local hum = getHumanoid()
            if hum then hum.Jump = true end
        end)
    end
end)

local function handleAutoReconnect()
    connect(GuiService.ErrorMessageChanged, function()
        if CONFIG.AUTO_RECONNECT then
            setStatus("Disconnected! Reconnecting...")
            task.wait(3)
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end
    end)
end
task.spawn(handleAutoReconnect)

----------------------------------------------------------------
-- CHARACTER RESTORATION
----------------------------------------------------------------

local function setupCharacter(char)
    task.wait(0.2)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum.WalkSpeed = CONFIG.WALK_SPEED
            hum.JumpPower = CONFIG.JUMP_POWER
        end)
    end
end

if LocalPlayer.Character then task.spawn(function() setupCharacter(LocalPlayer.Character) end) end
connect(LocalPlayer.CharacterAdded, setupCharacter)

----------------------------------------------------------------
-- UI FRAMEWORK
----------------------------------------------------------------

local function getUIParent()
    if type(gethui) == "function" then
        local ok, res = pcall(gethui)
        if ok and res then return res end
    end
    local ok, res = pcall(function() return CoreGui end)
    if ok and res then return res end
    return LocalPlayer:FindFirstChild("PlayerGui")
end

local UIParent = getUIParent()
if not UIParent then warn("[VT] Cannot find valid UIParent"); return end

pcall(function()
    local old = UIParent:FindFirstChild("StealEggHubV4")
    if old then old:Destroy() end
end)

local function New(class, props, parent)
    local obj = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            pcall(function() obj[k] = v end)
        end
    end
    if parent then pcall(function() obj.Parent = parent end) end
    return obj
end

local ScreenGui = New("ScreenGui", { Name = "StealEggHubV4", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, UIParent)
local MainFrame = New("Frame", {
    Size = UDim2.new(0, 640, 0, 450),
    Position = UDim2.new(0.5, -320, 0.5, -225),
    BackgroundColor3 = Color3.fromRGB(13, 13, 18),
    BorderSizePixel = 0, Active = true, Draggable = true
}, ScreenGui)
New("UICorner", { CornerRadius = UDim.new(0, 12) }, MainFrame)

-- TOP BAR
local TopBar = New("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = Color3.fromRGB(18, 18, 26), BorderSizePixel = 0 }, MainFrame)
New("UICorner", { CornerRadius = UDim.new(0, 12) }, TopBar)
New("TextLabel", { Size = UDim2.new(1, -100, 0, 24), Position = UDim2.new(0, 18, 0, 8), BackgroundTransparency = 1, Text = "VAN THANH  ·  STEAL AN EGG", TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left }, TopBar)
New("TextLabel", { Size = UDim2.new(1, -100, 0, 18), Position = UDim2.new(0, 18, 0, 32), BackgroundTransparency = 1, Text = "V4 FULL · Farm · Bypass · ESP", TextColor3 = Color3.fromRGB(100, 220, 140), TextSize = 9, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left }, TopBar)

local CloseBtn = New("TextButton", { Size = UDim2.new(0, 34, 0, 34), Position = UDim2.new(1, -45, 0, 13), BackgroundColor3 = Color3.fromRGB(180, 40, 50), Text = "X", TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 16, Font = Enum.Font.GothamBold, BorderSizePixel = 0 }, TopBar)
New("UICorner", { CornerRadius = UDim.new(0, 8) }, CloseBtn)

-- NAVIGATION & CONTAINERS
local Sidebar = New("Frame", { Size = UDim2.new(0, 150, 1, -70), Position = UDim2.new(0, 10, 0, 65), BackgroundColor3 = Color3.fromRGB(18, 18, 26), BorderSizePixel = 0 }, MainFrame)
New("UICorner", { CornerRadius = UDim.new(0, 9) }, Sidebar)
local Content = New("Frame", { Size = UDim2.new(1, -175, 1, -70), Position = UDim2.new(0, 165, 0, 65), BackgroundTransparency = 1 }, MainFrame)

local Pages, Tabs = {}, {}
local function createPage(name)
    local page = New("ScrollingFrame", { Name = name .. "Page", Size = UDim2.new(1, -10, 1, -10), Position = UDim2.new(0, 5, 0, 5), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0), Visible = false }, Content)
    local layout = New("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        pcall(function() page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 15) end)
    end)
    Pages[name] = page
    return page
end

local function createTab(name, text, order)
    local btn = New("TextButton", { Name = name .. "Tab", Size = UDim2.new(1, -16, 0, 32), Position = UDim2.new(0, 8, 0, order * 36 + 8), BackgroundColor3 = Color3.fromRGB(24, 24, 33), BorderSizePixel = 0, Text = text, TextColor3 = Color3.fromRGB(155, 155, 170), TextSize = 9, Font = Enum.Font.GothamMedium }, Sidebar)
    New("UICorner", { CornerRadius = UDim.new(0, 7) }, btn)
    Tabs[name] = btn

    connect(btn.MouseButton1Click, function()
        for pName, page in pairs(Pages) do page.Visible = (pName == name) end
        for tName, tab in pairs(Tabs) do
            tab.BackgroundColor3 = (tName == name) and Color3.fromRGB(60, 45, 130) or Color3.fromRGB(24, 24, 33)
            tab.TextColor3 = (tName == name) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(155, 155, 170)
        end
    end)
    return btn
end

local function section(parent, text)
    return New("TextLabel", { Size = UDim2.new(1, -10, 0, 22), BackgroundTransparency = 1, Text = text, TextColor3 = Color3.fromRGB(200, 200, 220), TextSize = 10, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left }, parent)
end
local function button(parent, text)
    local b = New("TextButton", { Size = UDim2.new(1, -10, 0, 32), BackgroundColor3 = Color3.fromRGB(28, 28, 38), BorderSizePixel = 0, Text = text, TextColor3 = Color3.fromRGB(225, 225, 230), TextSize = 10, Font = Enum.Font.GothamMedium }, parent)
    New("UICorner", { CornerRadius = UDim.new(0, 7) }, b)
    return b
end
local function label(parent, text)
    return New("TextLabel", { Size = UDim2.new(1, -10, 0, 26), BackgroundColor3 = Color3.fromRGB(22, 22, 31), BorderSizePixel = 0, Text = text, TextColor3 = Color3.fromRGB(175, 175, 190), TextSize = 9, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left }, parent)
end
local function toggle(parent, text, initial, callback)
    local state = initial
    local b = button(parent, text .. ": " .. (state and "ON" or "OFF"))
    local function refresh()
        b.Text = text .. ": " .. (state and "ON" or "OFF")
        b.BackgroundColor3 = state and Color3.fromRGB(38, 130, 65) or Color3.fromRGB(28, 28, 38)
    end
    connect(b.MouseButton1Click, function()
        state = not state
        refresh()
        if callback then pcall(callback, state) end
    end)
    refresh()
    return b
end

----------------------------------------------------------------
-- UI PAGES BUILD
----------------------------------------------------------------

local HomePage = createPage("Home")
local FarmPage = createPage("Farm")
local MovementPage = createPage("Movement")
local BossPage = createPage("Boss")
local TeleportPage = createPage("Teleport")
local AntiPage = createPage("Anti")
local CheatPage = createPage("Cheat")
local ESPPage = createPage("ESP")
local SettingsPage = createPage("Settings")

createTab("Home", "HOME", 0)
createTab("Farm", "FARM", 1)
createTab("Movement", "MOVEMENT", 2)
createTab("Boss", "BOSS", 3)
createTab("Teleport", "TELEPORT", 4)
createTab("Anti", "ANTI & BYPASS", 5)
createTab("Cheat", "CHEATS", 6)
createTab("ESP", "ESP", 7)
createTab("Settings", "SETTINGS", 8)

-- HOME DASHBOARD
section(HomePage, "DASHBOARD")
StatusLabel = label(HomePage, "  Status: Ready")
local FarmLabel = label(HomePage, "  Auto Farm: OFF")
local BossLabel = label(HomePage, "  Auto Boss: OFF")
local EggLabel = label(HomePage, "  Eggs Collected: 0")
local EPMLabel = label(HomePage, "  Eggs/Min: 0")
local SessionLabel = label(HomePage, "  Session: 0m 0s")

local function updateDashboard()
    pcall(function()
        FarmLabel.Text = "  Auto Farm: " .. (FLAGS.AutoFarm and "ON" or "OFF")
        BossLabel.Text = "  Auto Boss: " .. (FLAGS.AutoBoss and "ON" or "OFF")
        EggLabel.Text = "  Eggs Collected: " .. tostring(FLAGS.EggsCollected)
        EPMLabel.Text = "  Eggs/Min: " .. tostring(FLAGS.EggsPerMinute)
        local elapsed = math.floor(tick() - FLAGS.SessionStart)
        SessionLabel.Text = string.format("  Session: %dm %ds", math.floor(elapsed / 60), elapsed % 60)
    end)
end

section(HomePage, "QUICK TOGGLES")
local FarmToggle = button(HomePage, "Toggle Auto Farm")
connect(FarmToggle.MouseButton1Click, function()
    FLAGS.AutoFarm = not FLAGS.AutoFarm
    setStatus(FLAGS.AutoFarm and "Farm ON" or "Farm OFF")
    updateDashboard()
end)

local BossToggle = button(HomePage, "Toggle Auto Boss")
connect(BossToggle.MouseButton1Click, function()
    FLAGS.AutoBoss = not FLAGS.AutoBoss
    setStatus(FLAGS.AutoBoss and "Boss ON" or "Boss OFF")
    updateDashboard()
end)

-- FARM PAGE
section(FarmPage, "AUTOMATION")
toggle(FarmPage, "Auto Farm Eggs", false, function(v) FLAGS.AutoFarm = v; updateDashboard() end)
toggle(FarmPage, "Return to Treadmill", true, function(v) FLAGS.ReturnTreadmill = v end)

section(FarmPage, "RARITY FILTER")
for _, rarity in ipairs(CONFIG.RARITY_PRIORITY) do
    toggle(FarmPage, rarity, CONFIG.TARGET_RARITIES[rarity], function(v)
        CONFIG.TARGET_RARITIES[rarity] = v
    end)
end

-- MOVEMENT PAGE
section(MovementPage, "PATHFINDING MODE")
local ModeBtn = button(MovementPage, "Mode: ZIGZAG")
connect(ModeBtn.MouseButton1Click, function()
    CONFIG.MOVE_MODE = (CONFIG.MOVE_MODE == "ZigZag") and "Direct" or "ZigZag"
    ModeBtn.Text = "Mode: " .. string.upper(CONFIG.MOVE_MODE)
end)

section(MovementPage, "SAFE POSITION")
local SaveBtn = button(MovementPage, "Save Current Position")
connect(SaveBtn.MouseButton1Click, function()
    local root = getRoot()
    if root then CONFIG.TREADMILL_CFRAME = root.CFrame; SaveBtn.Text = "Saved!" end
    task.delay(1.5, function() pcall(function() SaveBtn.Text = "Save Current Position" end) end)
end)
local GoBtn = button(MovementPage, "Teleport Saved Position")
connect(GoBtn.MouseButton1Click, function() moveTarget(CONFIG.TREADMILL_CFRAME) end)

-- ANTI & BYPASS PAGE
section(AntiPage, "PROTECTIONS")
label(AntiPage, "  Anti-Cheat Bypass: ACTIVE")
label(AntiPage, "  Anti-AFK Protection: ACTIVE")
toggle(AntiPage, "Auto Reconnect", true, function(v) CONFIG.AUTO_RECONNECT = v end)

section(AntiPage, "CHARACTER STATS")
local SpeedLbl = label(AntiPage, "  WalkSpeed: " .. tostring(CONFIG.WALK_SPEED))
local SpeedUp = button(AntiPage, "Speed +2")
connect(SpeedUp.MouseButton1Click, function()
    CONFIG.WALK_SPEED += 2
    SpeedLbl.Text = "  WalkSpeed: " .. tostring(CONFIG.WALK_SPEED)
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = CONFIG.WALK_SPEED end
end)
local SpeedDown = button(AntiPage, "Speed -2")
connect(SpeedDown.MouseButton1Click, function()
    CONFIG.WALK_SPEED = math.max(4, CONFIG.WALK_SPEED - 2)
    SpeedLbl.Text = "  WalkSpeed: " .. tostring(CONFIG.WALK_SPEED)
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = CONFIG.WALK_SPEED end
end)

-- CHEATS PAGE
section(CheatPage, "MOVEMENT EXPLOITS")
local CheatState = { Fly = false, Noclip = false, InfJump = false, FlySpeed = 60 }
local flyConn, noclipConn, jumpConn

local function stopFly()
    CheatState.Fly = false
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    local hum = getHumanoid()
    if hum then hum.PlatformStand = false end
end

local function startFly()
    if flyConn then return end
    local root, hum = getRoot(), getHumanoid()
    if not root or not hum then return end

    hum.PlatformStand = true
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = Vector3.zero
    bv.Parent = root

    flyConn = RunService.Heartbeat:Connect(function()
        if not CheatState.Fly or not root.Parent then
            bv:Destroy()
            stopFly()
            return
        end
        local cam = Workspace.CurrentCamera
        if not cam then return end

        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0, 1, 0) end

        bv.Velocity = (move.Magnitude > 0) and (move.Unit * CheatState.FlySpeed) or Vector3.zero
    end)
end

toggle(CheatPage, "Fly", false, function(v) CheatState.Fly = v; if v then startFly() else stopFly() end end)
toggle(CheatPage, "Noclip", false, function(v)
    CheatState.Noclip = v
    if not v and noclipConn then noclipConn:Disconnect(); noclipConn = nil; return end
    if v and not noclipConn then
        noclipConn = RunService.Stepped:Connect(function()
            local char = getCharacter()
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end)
    end
end)
toggle(CheatPage, "Infinite Jump", false, function(v)
    CheatState.InfJump = v
    if jumpConn then jumpConn:Disconnect(); jumpConn = nil end
    if v then
        jumpConn = UserInputService.JumpRequest:Connect(function()
            local hum = getHumanoid()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end)

-- ESP SYSTEM
section(ESPPage, "VISUALS (ESP)")
local ESP = { Players = false, Eggs = false, Distance = 500, Objects = {} }
local ESPFolder = New("Folder", { Name = "VT_ESP" }, CoreGui)

local function clearESP()
    for k, v in pairs(ESP.Objects) do pcall(function() v:Destroy() end); ESP.Objects[k] = nil end
end

local function addESP(key, adornee, text, color)
    if not adornee or ESP.Objects[key] then return end
    local bb = New("BillboardGui", { Name = "VT_ESP", Size = UDim2.new(0, 130, 0, 40), StudsOffset = Vector3.new(0, 3, 0), AlwaysOnTop = true, Adornee = adornee }, ESPFolder)
    New("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = text, TextColor3 = color, TextSize = 10, Font = Enum.Font.GothamBold }, bb)
    ESP.Objects[key] = bb
end

local function updateESP()
    if not ESP.Players and not ESP.Eggs then clearESP(); return end
    local root = getRoot()
    if not root then return end
    local myPos = root.Position

    if ESP.Players then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local pRoot = plr.Character:FindFirstChild("HumanoidRootPart")
                if pRoot then
                    local dist = (myPos - pRoot.Position).Magnitude
                    if dist <= ESP.Distance then
                        addESP("PLR_" .. tostring(plr.UserId), pRoot, plr.Name .. "\n[" .. math.floor(dist) .. "m]", Color3.fromRGB(255, 80, 80))
                    end
                end
            end
        end
    end

    if ESP.Eggs then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("Model") then
                local name = string.lower(obj.Name)
                if string.find(name, "egg", 1, true) and not string.find(name, "hatch", 1, true) then
                    local pos = obj:IsA("Model") and obj:GetPivot().Position or obj.Position
                    if pos then
                        local dist = (myPos - pos).Magnitude
                        if dist <= ESP.Distance then
                            local rarity = getRarity(obj) or "?"
                            local color = CONFIG.RARITY_COLORS[rarity] or Color3.fromRGB(255, 255, 255)
                            local adornee = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj
                            if adornee then
                                addESP("EGG_" .. tostring(obj), adornee, rarity .. "\n[" .. math.floor(dist) .. "m]", color)
                            end
                        end
                    end
                end
            end
        end
    end
end

toggle(ESPPage, "Player ESP", false, function(v) ESP.Players = v; if not v then clearESP() end end)
toggle(ESPPage, "Egg ESP", false, function(v) ESP.Eggs = v; if not v then clearESP() end end)
local ClearESPBtn = button(ESPPage, "Clear Visuals")
connect(ClearESPBtn.MouseButton1Click, clearESP)

-- SETTINGS PAGE
section(SettingsPage, "HUB CONTROL")
local CopyLogBtn = button(SettingsPage, "Copy Debug Log")
connect(CopyLogBtn.MouseButton1Click, function() copyText(table.concat(LOG, "\n")); setStatus("Log Copied") end)

local UnloadBtn = button(SettingsPage, "Unload Script")
connect(UnloadBtn.MouseButton1Click, function()
    cleanup()
    pcall(function() ScreenGui:Destroy() end)
    pcall(function() ESPFolder:Destroy() end)
end)

label(SettingsPage, "  Hotkey: Right Shift to Toggle UI")

----------------------------------------------------------------
-- CONTROL LOOPS & INITIALIZATION
----------------------------------------------------------------

connect(CloseBtn.MouseButton1Click, function() MainFrame.Visible = false end)
connect(UserInputService.InputBegan, function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- LOOP: ESP
task.spawn(function()
    while FLAGS.Running do
        if ESP.Players or ESP.Eggs then pcall(updateESP) end
        task.wait(0.6)
    end
end)

-- LOOP: DASHBOARD
task.spawn(function()
    while FLAGS.Running do
        pcall(updateDashboard)
        task.wait(0.5)
    end
end)

-- LOOP: MAIN AUTOMATION
task.spawn(function()
    while FLAGS.Running do
        if FLAGS.AutoBoss then
            pcall(attackBoss)
        elseif FLAGS.AutoFarm then
            pcall(function()
                local egg = findPriorityEgg()
                if egg then
                    collectEgg(egg)
                elseif FLAGS.ReturnTreadmill then
                    goToTreadmill()
                else
                    setStatus("Waiting for priority egg...")
                end
            end)
        else
            if FLAGS.Status ~= "Ready" then setStatus("Ready") end
        end
        task.wait(CONFIG.CHECK_INTERVAL)
    end
end)

-- SHOW DEFAULT TAB
for name, page in pairs(Pages) do page.Visible = false end
Pages.Home.Visible = true
Tabs.Home.BackgroundColor3 = Color3.fromRGB(60, 45, 130)
Tabs.Home.TextColor3 = Color3.fromRGB(255, 255, 255)

updateDashboard()
setStatus("Ready - V4 FULL")
print("[VAN THANH V4] Loaded successfully with full Anti-Cheat bypass")
