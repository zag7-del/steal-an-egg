--[[
    VAN THANH - STEAL AN EGG V4 TEMP
    Temporary compatibility build
    - Fixed unsafe getgenv()
    - Fixed Player.Kicked crash
    - Fixed UI parent
    - Bypass hooks disabled
]]

----------------------------------------------------------------
-- SAFE GLOBALS
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
        warnFn("[VT] Already loaded")
    end
    return
end

ENV.__VanThanhV4 = true

----------------------------------------------------------------
-- COMPAT
----------------------------------------------------------------

local cloneref = G("cloneref")
local gethui = G("gethui")
local fireproximityprompt = G("fireproximityprompt")
local fireclickdetector = G("fireclickdetector")
local setclipboard = G("setclipboard")

local function safeRef(obj)
    if type(cloneref) == "function" then
        local ok, result = pcall(cloneref, obj)
        if ok and result then
            return result
        end
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

local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then
    warn("[VT] LocalPlayer not ready")
    return
end

----------------------------------------------------------------
-- LOG
----------------------------------------------------------------

local LOG = {}

local function log(tag, text)
    local msg = "[VT][" .. tostring(tag) .. "] " .. tostring(text)
    table.insert(LOG, msg)

    if ENV.__VT_DEV then
        print(msg)
    end
end

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------

local CONFIG = {
    CHECK_INTERVAL = 0.35,

    MOVE_MODE = "ZigZag",
    ZIGZAG_OFFSET = 6,
    TELEPORT_DELAY = 0.07,

    TREADMILL_CFRAME = CFrame.new(0, 10, 0),
    WATERFALL_CFRAME = CFrame.new(150, 5, -800),

    RARITY_PRIORITY = {
        "Secret",
        "Eternal",
        "Divine",
        "Light",
        "Dark"
    },

    TARGET_RARITIES = {
        Secret = true,
        Eternal = true,
        Divine = true,
        Light = true,
        Dark = true
    },

    WALK_SPEED = 16,
    JUMP_POWER = 50,

    RECONNECT = false
}

----------------------------------------------------------------
-- FLAGS
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
-- CONNECTIONS
----------------------------------------------------------------

local Connections = {}

local function connect(signal, callback)
    if not signal then
        return nil
    end

    local ok, connection = pcall(function()
        return signal:Connect(callback)
    end)

    if ok and connection then
        table.insert(Connections, connection)
        return connection
    end

    return nil
end

local function cleanup()
    FLAGS.Running = false
    ENV.__VanThanhV4 = nil

    for _, connection in ipairs(Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(Connections)
end

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------

local function getCharacter()
    return LocalPlayer.Character
end

local function getRoot()
    local character = getCharacter()

    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local character = getCharacter()

    if not character then
        return nil
    end

    return character:FindFirstChildOfClass("Humanoid")
end

local function setStatus(text)
    FLAGS.Status = tostring(text)

    if StatusLabel then
        pcall(function()
            StatusLabel.Text = "  Status: " .. FLAGS.Status
        end)
    end
end

local function getRarity(object)
    if not object then
        return nil
    end

    local rarity

    pcall(function()
        rarity =
            object:GetAttribute("Rarity")
            or object:GetAttribute("RarityName")
            or object:GetAttribute("EggRarity")
    end)

    if rarity then
        return tostring(rarity)
    end

    local name = string.lower(object.Name)

    for _, rarityName in ipairs(CONFIG.RARITY_PRIORITY) do
        if string.find(name, string.lower(rarityName), 1, true) then
            return rarityName
        end
    end

    return nil
end

----------------------------------------------------------------
-- PROMPT
----------------------------------------------------------------

local function firePrompt(prompt)
    if not prompt then
        return false
    end

    if type(fireproximityprompt) == "function" then
        local ok = pcall(fireproximityprompt, prompt)
        if ok then
            return true
        end
    end

    pcall(function()
        prompt:InputHoldBegin()
        task.wait((prompt.HoldDuration or 0.5) + 0.05)
        prompt:InputHoldEnd()
    end)

    return true
end

local function fireClick(detector)
    if not detector then
        return false
    end

    if type(fireclickdetector) == "function" then
        return pcall(fireclickdetector, detector)
    end

    return false
end

----------------------------------------------------------------
-- CLIPBOARD
----------------------------------------------------------------

local function copyText(text)
    if type(setclipboard) == "function" then
        pcall(setclipboard, text)
    end
end

----------------------------------------------------------------
-- MOVEMENT
----------------------------------------------------------------

local function moveTarget(targetCFrame)
    local root = getRoot()

    if not root or not targetCFrame then
        return
    end

    if CONFIG.MOVE_MODE == "Direct" then
        pcall(function()
            root.CFrame = targetCFrame
        end)

        task.wait(CONFIG.TELEPORT_DELAY)
        return
    end

    local startPosition = root.Position
    local endPosition = targetCFrame.Position

    local difference = endPosition - startPosition
    local distance = difference.Magnitude

    if distance < 1 then
        root.CFrame = targetCFrame
        return
    end

    local steps = math.clamp(math.floor(distance / 15), 2, 12)

    local direction = difference.Unit
    local right = direction:Cross(Vector3.new(0, 1, 0))

    if right.Magnitude < 0.01 then
        right = Vector3.new(1, 0, 0)
    else
        right = right.Unit
    end

    for i = 1, steps do
        if not FLAGS.Running then
            break
        end

        local alpha = i / steps
        local position = startPosition:Lerp(endPosition, alpha)

        local offset = 0

        if CONFIG.MOVE_MODE == "ZigZag" then
            if i % 2 == 0 then
                offset = CONFIG.ZIGZAG_OFFSET
            else
                offset = -CONFIG.ZIGZAG_OFFSET
            end
        end

        pcall(function()
            root.CFrame = CFrame.new(
                position + right * offset
            )
        end)

        task.wait(CONFIG.TELEPORT_DELAY)
    end

    pcall(function()
        root.CFrame = targetCFrame
    end)
end

----------------------------------------------------------------
-- FIND EGG
----------------------------------------------------------------

local function findPriorityEgg()
    local root = getRoot()

    if not root then
        return nil
    end

    local bestEgg = nil
    local bestPriority = math.huge
    local bestDistance = math.huge

    local descendants = Workspace:GetDescendants()

    for _, object in ipairs(descendants) do
        local isEgg = false

        pcall(function()
            if object:IsA("BasePart") or object:IsA("Model") then
                local name = string.lower(object.Name)

                if string.find(name, "egg", 1, true)
                    and not string.find(name, "hatch", 1, true) then
                    isEgg = true
                end
            end
        end)

        if isEgg then
            local rarity = getRarity(object)

            if rarity and CONFIG.TARGET_RARITIES[rarity] then
                local priority = math.huge

                for index, rarityName in ipairs(CONFIG.RARITY_PRIORITY) do
                    if rarityName == rarity then
                        priority = index
                        break
                    end
                end

                local position

                pcall(function()
                    if object:IsA("Model") then
                        position = object:GetPivot().Position
                    else
                        position = object.Position
                    end
                end)

                if position then
                    local distance =
                        (root.Position - position).Magnitude

                    if priority < bestPriority
                        or (
                            priority == bestPriority
                            and distance < bestDistance
                        ) then

                        bestEgg = object
                        bestPriority = priority
                        bestDistance = distance
                    end
                end
            end
        end
    end

    return bestEgg
end

----------------------------------------------------------------
-- COLLECT EGG
----------------------------------------------------------------

local function collectEgg(object)
    if not object or not object.Parent then
        return
    end

    local rarity = getRarity(object) or "?"

    setStatus(
        "Collecting " ..
        tostring(rarity) ..
        ": " ..
        tostring(object.Name)
    )

    local targetCFrame

    pcall(function()
        if object:IsA("Model") then
            targetCFrame = object:GetPivot()
        elseif object:IsA("BasePart") then
            targetCFrame = object.CFrame
        end
    end)

    if not targetCFrame then
        return
    end

    moveTarget(
        targetCFrame + Vector3.new(0, 3, 0)
    )

    task.wait(0.15)

    local prompt = nil

    pcall(function()
        if object:IsA("Model") then
            prompt = object:FindFirstChildOfClass(
                "ProximityPrompt"
            )

            if not prompt then
                for _, descendant in ipairs(
                    object:GetDescendants()
                ) do
                    if descendant:IsA("ProximityPrompt") then
                        prompt = descendant
                        break
                    end
                end
            end
        else
            prompt =
                object:FindFirstChildOfClass("ProximityPrompt")

            if not prompt and object.Parent then
                prompt =
                    object.Parent:FindFirstChildOfClass(
                        "ProximityPrompt"
                    )
            end
        end
    end)

    if prompt then
        firePrompt(prompt)

        FLAGS.EggsCollected += 1

        local elapsed =
            math.max(
                tick() - FLAGS.SessionStart,
                0.01
            )

        FLAGS.EggsPerMinute =
            math.floor(
                FLAGS.EggsCollected /
                (elapsed / 60)
            )
    end
end

----------------------------------------------------------------
-- TREADMILL
----------------------------------------------------------------

local function goToTreadmill()
    setStatus("Going to treadmill...")

    moveTarget(CONFIG.TREADMILL_CFRAME)

    for _, object in ipairs(
        Workspace:GetDescendants()
    ) do

        if object:IsA("ProximityPrompt") then
            local parent = object.Parent

            if parent then
                local name =
                    string.lower(parent.Name)

                if string.find(
                    name,
                    "treadmill",
                    1,
                    true
                ) then
                    firePrompt(object)
                    break
                end
            end
        end
    end
end

----------------------------------------------------------------
-- BOSS
----------------------------------------------------------------

local function attackBoss()
    setStatus("Fighting Boss...")

    local bossFolder

    local names = {
        "Boss",
        "Events",
        "EggBoss",
        "GiantEgg"
    }

    for _, name in ipairs(names) do
        bossFolder =
            Workspace:FindFirstChild(name)

        if bossFolder then
            break
        end
    end

    if not bossFolder then
        setStatus("Boss not found")
        return
    end

    local boss =
        bossFolder:FindFirstChildOfClass("Model")

    if not boss then
        setStatus("Boss model not found")
        return
    end

    local bossRoot =
        boss:FindFirstChild("HumanoidRootPart")

    if not bossRoot then
        setStatus("Boss root not found")
        return
    end

    moveTarget(
        bossRoot.CFrame +
        Vector3.new(0, 5, -8)
    )

    task.wait(0.3)

    local character = getCharacter()

    if not character then
        return
    end

    for _, item in ipairs(
        character:GetChildren()
    ) do

        if item:IsA("Tool") then
            pcall(function()
                item:Activate()
            end)
        end
    end

    for _, descendant in ipairs(
        boss:GetDescendants()
    ) do

        if descendant:IsA("ProximityPrompt") then
            firePrompt(descendant)
        elseif descendant:IsA("ClickDetector") then
            fireClick(descendant)
        end
    end

    FLAGS.BossAttacks += 1

    setStatus(
        "Boss attacked #" ..
        tostring(FLAGS.BossAttacks)
    )
end

----------------------------------------------------------------
-- ANTI AFK
----------------------------------------------------------------

task.spawn(function()
    while FLAGS.Running do
        task.wait(55)

        if not FLAGS.Running then
            break
        end

        pcall(function()
            local humanoid = getHumanoid()

            if humanoid then
                humanoid.Jump = true
            end
        end)
    end
end)

----------------------------------------------------------------
-- CHARACTER RESTORE
----------------------------------------------------------------

local function setupCharacter(character)
    task.wait(0.2)

    local humanoid =
        character:FindFirstChildOfClass(
            "Humanoid"
        )

    if not humanoid then
        return
    end

    pcall(function()
        humanoid.WalkSpeed =
            CONFIG.WALK_SPEED

        humanoid.JumpPower =
            CONFIG.JUMP_POWER
    end)
end

if LocalPlayer.Character then
    task.spawn(function()
        setupCharacter(
            LocalPlayer.Character
        )
    end)
end

connect(
    LocalPlayer.CharacterAdded,
    function(character)
        setupCharacter(character)
    end
)

----------------------------------------------------------------
-- IMPORTANT:
-- Player.Kicked DOES NOT EXIST.
-- Do NOT use LocalPlayer.Kicked.
-- Reconnect is manual in this temporary build.
----------------------------------------------------------------

local function manualReconnect()
    setStatus("Reconnecting...")

    task.wait(1)

    pcall(function()
        TeleportService:Teleport(
            game.PlaceId,
            LocalPlayer
        )
    end)
end

log(
    "RECONNECT",
    "Manual reconnect mode"
)

----------------------------------------------------------------
-- UI
----------------------------------------------------------------

local function getUIParent()
    if type(gethui) == "function" then
        local ok, result =
            pcall(gethui)

        if ok and result then
            return result
        end
    end

    local ok, result =
        pcall(function()
            return CoreGui
        end)

    if ok and result then
        return result
    end

    return LocalPlayer:FindFirstChild(
        "PlayerGui"
    )
end

local UIParent =
    getUIParent()

if not UIParent then
    warn("[VT] UI parent unavailable")
    return
end

pcall(function()
    local old =
        UIParent:FindFirstChild(
            "StealEggHubV4"
        )

    if old then
        old:Destroy()
    end
end)

local function New(className, properties, parent)
    local object

    local ok = pcall(function()
        object =
            Instance.new(className)
    end)

    if not ok or not object then
        return nil
    end

    if properties then
        for property, value in pairs(
            properties
        ) do
            pcall(function()
                object[property] = value
            end)
        end
    end

    if parent then
        pcall(function()
            object.Parent = parent
        end)
    end

    return object
end

local ScreenGui =
    New(
        "ScreenGui",
        {
            Name = "StealEggHubV4",
            ResetOnSpawn = false,
            ZIndexBehavior =
                Enum.ZIndexBehavior.Sibling
        },
        UIParent
    )

if not ScreenGui then
    warn("[VT] Could not create ScreenGui")
    return
end

local MainFrame =
    New(
        "Frame",
        {
            Size =
                UDim2.new(
                    0,
                    640,
                    0,
                    450
                ),

            Position =
                UDim2.new(
                    0.5,
                    -320,
                    0.5,
                    -225
                ),

            BackgroundColor3 =
                Color3.fromRGB(
                    13,
                    13,
                    18
                ),

            BorderSizePixel = 0,
            Active = true,
            Draggable = true
        },
        ScreenGui
    )

New(
    "UICorner",
    {
        CornerRadius =
            UDim.new(0, 12)
    },
    MainFrame
)

----------------------------------------------------------------
-- TOP BAR
----------------------------------------------------------------

local TopBar =
    New(
        "Frame",
        {
            Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    60
                ),

            BackgroundColor3 =
                Color3.fromRGB(
                    18,
                    18,
                    26
                ),

            BorderSizePixel = 0
        },
        MainFrame
    )

New(
    "UICorner",
    {
        CornerRadius =
            UDim.new(0, 12)
    },
    TopBar
)

New(
    "TextLabel",
    {
        Size =
            UDim2.new(
                1,
                -100,
                0,
                24
            ),

        Position =
            UDim2.new(
                0,
                18,
                0,
                8
            ),

        BackgroundTransparency = 1,

        Text =
            "VAN THANH  ·  STEAL AN EGG",

        TextColor3 =
            Color3.fromRGB(
                255,
                255,
                255
            ),

        TextSize = 14,
        Font =
            Enum.Font.GothamBold,

        TextXAlignment =
            Enum.TextXAlignment.Left
    },
    TopBar
)

New(
    "TextLabel",
    {
        Size =
            UDim2.new(
                1,
                -100,
                0,
                18
            ),

        Position =
            UDim2.new(
                0,
                18,
                0,
                32
            ),

        BackgroundTransparency = 1,

        Text =
            "V4 TEMP · Farm · Cheat · ESP",

        TextColor3 =
            Color3.fromRGB(
                100,
                200,
                120
            ),

        TextSize = 9,
        Font =
            Enum.Font.Gotham,

        TextXAlignment =
            Enum.TextXAlignment.Left
    },
    TopBar
)

local CloseButton =
    New(
        "TextButton",
        {
            Size =
                UDim2.new(
                    0,
                    34,
                    0,
                    34
                ),

            Position =
                UDim2.new(
                    1,
                    -45,
                    0,
                    13
                ),

            BackgroundColor3 =
                Color3.fromRGB(
                    160,
                    40,
                    50
                ),

            Text = "X",

            TextColor3 =
                Color3.fromRGB(
                    255,
                    255,
                    255
                ),

            TextSize = 18,
            Font =
                Enum.Font.GothamBold,

            BorderSizePixel = 0
        },
        TopBar
    )

New(
    "UICorner",
    {
        CornerRadius =
            UDim.new(0, 8)
    },
    CloseButton
)

----------------------------------------------------------------
-- SIDEBAR
----------------------------------------------------------------

local Sidebar =
    New(
        "Frame",
        {
            Size =
                UDim2.new(
                    0,
                    150,
                    1,
                    -70
                ),

            Position =
                UDim2.new(
                    0,
                    10,
                    0,
                    65
                ),

            BackgroundColor3 =
                Color3.fromRGB(
                    18,
                    18,
                    26
                ),

            BorderSizePixel = 0
        },
        MainFrame
    )

New(
    "UICorner",
    {
        CornerRadius =
            UDim.new(0, 9)
    },
    Sidebar
)

local Content =
    New(
        "Frame",
        {
            Size =
                UDim2.new(
                    1,
                    -175,
                    1,
                    -70
                ),

            Position =
                UDim2.new(
                    0,
                    165,
                    0,
                    65
                ),

            BackgroundTransparency = 1
        },
        MainFrame
    )

----------------------------------------------------------------
-- PAGE SYSTEM
----------------------------------------------------------------

local Pages = {}
local Tabs = {}

local function createPage(name)
    local page =
        New(
            "ScrollingFrame",
            {
                Name =
                    name .. "Page",

                Size =
                    UDim2.new(
                        1,
                        -10,
                        1,
                        -10
                    ),

                Position =
                    UDim2.new(
                        0,
                        5,
                        0,
                        5
                    ),

                BackgroundTransparency = 1,
                BorderSizePixel = 0,

                ScrollBarThickness = 3,

                CanvasSize =
                    UDim2.new(
                        0,
                        0,
                        0,
                        0
                    ),

                Visible = false
            },
            Content
        )

    local layout =
        New(
            "UIListLayout",
            {
                Padding =
                    UDim.new(
                        0,
                        7
                    ),

                SortOrder =
                    Enum.SortOrder.LayoutOrder
            },
            page
        )

    if layout then
        connect(
            layout:GetPropertyChangedSignal(
                "AbsoluteContentSize"
            ),
            function()
                pcall(function()
                    page.CanvasSize =
                        UDim2.new(
                            0,
                            0,
                            0,
                            layout.AbsoluteContentSize.Y
                                + 15
                        )
                end)
            end
        )
    end

    Pages[name] = page

    return page
end

local function createTab(
    name,
    text,
    order
)
    local button =
        New(
            "TextButton",
            {
                Name =
                    name .. "Tab",

                Size =
                    UDim2.new(
                        1,
                        -16,
                        0,
                        34
                    ),

                Position =
                    UDim2.new(
                        0,
                        8,
                        0,
                        order * 38 + 8
                    ),

                BackgroundColor3 =
                    Color3.fromRGB(
                        24,
                        24,
                        33
                    ),

                BorderSizePixel = 0,

                Text = text,

                TextColor3 =
                    Color3.fromRGB(
                        155,
                        155,
                        170
                    ),

                TextSize = 9,

                Font =
                    Enum.Font.GothamMedium
            },
            Sidebar
        )

    New(
        "UICorner",
        {
            CornerRadius =
                UDim.new(0, 7)
        },
        button
    )

    Tabs[name] = button

    connect(
        button.MouseButton1Click,
        function()
            for pageName, page in pairs(
                Pages
            ) do
                page.Visible =
                    pageName == name
            end

            for tabName, tab in pairs(
                Tabs
            ) do
                if tabName == name then
                    tab.BackgroundColor3 =
                        Color3.fromRGB(
                            60,
                            45,
                            130
                        )

                    tab.TextColor3 =
                        Color3.fromRGB(
                            255,
                            255,
                            255
                        )
                else
                    tab.BackgroundColor3 =
                        Color3.fromRGB(
                            24,
                            24,
                            33
                        )

                    tab.TextColor3 =
                        Color3.fromRGB(
                            155,
                            155,
                            170
                        )
                end
            end
        end
    )

    return button
end

local function section(parent, text)
    return New(
        "TextLabel",
        {
            Size =
                UDim2.new(
                    1,
                    -10,
                    0,
                    25
                ),

            BackgroundTransparency = 1,

            Text = text,

            TextColor3 =
                Color3.fromRGB(
                    200,
                    200,
                    220
                ),

            TextSize = 10,

            Font =
                Enum.Font.GothamBold,

            TextXAlignment =
                Enum.TextXAlignment.Left
        },
        parent
    )
end

local function button(parent, text)
    local b =
        New(
            "TextButton",
            {
                Size =
                    UDim2.new(
                        1,
                        -10,
                        0,
                        34
                    ),

                BackgroundColor3 =
                    Color3.fromRGB(
                        28,
                        28,
                        38
                    ),

                BorderSizePixel = 0,

                Text = text,

                TextColor3 =
                    Color3.fromRGB(
                        225,
                        225,
                        230
                    ),

                TextSize = 10,

                Font =
                    Enum.Font.GothamMedium
            },
            parent
        )

    New(
        "UICorner",
        {
            CornerRadius =
                UDim.new(0, 7)
        },
        b
    )

    return b
end

local function label(parent, text)
    return New(
        "TextLabel",
        {
            Size =
                UDim2.new(
                    1,
                    -10,
                    0,
                    28
                ),

            BackgroundColor3 =
                Color3.fromRGB(
                    22,
                    22,
                    31
                ),

            BorderSizePixel = 0,

            Text = text,

            TextColor3 =
                Color3.fromRGB(
                    175,
                    175,
                    190
                ),

            TextSize = 9,

            Font =
                Enum.Font.Gotham,

            TextXAlignment =
                Enum.TextXAlignment.Left
        },
        parent
    )
end

local function toggle(
    parent,
    text,
    initial,
    callback
)
    local state = initial

    local b =
        button(
            parent,
            text ..
            ": " ..
            (state and "ON" or "OFF")
        )

    local function refresh()
        b.Text =
            text ..
            ": " ..
            (state and "ON" or "OFF")

        b.BackgroundColor3 =
            state
            and Color3.fromRGB(
                38,
                130,
                65
            )
            or Color3.fromRGB(
                28,
                28,
                38
            )
    end

    connect(
        b.MouseButton1Click,
        function()
            state = not state
            refresh()

            if callback then
                pcall(
                    callback,
                    state
                )
            end
        end
    )

    refresh()

    return b
end

----------------------------------------------------------------
-- CREATE PAGES
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
createTab("Anti", "ANTI", 5)
createTab("Cheat", "CHEATS", 6)
createTab("ESP", "ESP", 7)
createTab("Settings", "SETTINGS", 8)

----------------------------------------------------------------
-- HOME
----------------------------------------------------------------

section(
    HomePage,
    "DASHBOARD"
)

StatusLabel =
    label(
        HomePage,
        "  Status: Ready"
    )

local FarmLabel =
    label(
        HomePage,
        "  Auto Farm: OFF"
    )

local BossLabel =
    label(
        HomePage,
        "  Auto Boss: OFF"
    )

local EggLabel =
    label(
        HomePage,
        "  Eggs: 0"
    )

local EPMLabel =
    label(
        HomePage,
        "  Eggs/min: 0"
    )

local SessionLabel =
    label(
        HomePage,
        "  Session: 0m 0s"
    )

local function updateDashboard()
    pcall(function()
        FarmLabel.Text =
            "  Auto Farm: " ..
            (
                FLAGS.AutoFarm
                and "ON"
                or "OFF"
            )

        BossLabel.Text =
            "  Auto Boss: " ..
            (
                FLAGS.AutoBoss
                and "ON"
                or "OFF"
            )

        EggLabel.Text =
            "  Eggs: " ..
            tostring(
                FLAGS.EggsCollected
            )

        EPMLabel.Text =
            "  Eggs/min: " ..
            tostring(
                FLAGS.EggsPerMinute
            )

        local elapsed =
            math.floor(
                tick() -
                FLAGS.SessionStart
            )

        SessionLabel.Text =
            string.format(
                "  Session: %dm %ds",
                math.floor(
                    elapsed / 60
                ),
                elapsed % 60
            )
    end)
end

section(
    HomePage,
    "CONTROLS"
)

local FarmToggle =
    button(
        HomePage,
        "Toggle Auto Farm"
    )

connect(
    FarmToggle.MouseButton1Click,
    function()
        FLAGS.AutoFarm =
            not FLAGS.AutoFarm

        setStatus(
            FLAGS.AutoFarm
            and "Farm ON"
            or "Farm OFF"
        )

        updateDashboard()
    end
)

local BossToggle =
    button(
        HomePage,
        "Toggle Auto Boss"
    )

connect(
    BossToggle.MouseButton1Click,
    function()
        FLAGS.AutoBoss =
            not FLAGS.AutoBoss

        setStatus(
            FLAGS.AutoBoss
            and "Boss ON"
            or "Boss OFF"
        )

        updateDashboard()
    end
)

----------------------------------------------------------------
-- FARM
----------------------------------------------------------------

section(
    FarmPage,
    "AUTO FARM"
)

toggle(
    FarmPage,
    "Auto Egg",
    false,
    function(value)
        FLAGS.AutoFarm = value
        updateDashboard()
    end
)

toggle(
    FarmPage,
    "Return Treadmill",
    true,
    function(value)
        FLAGS.ReturnTreadmill = value
    end
)

toggle(
    FarmPage,
    "Notify Rare",
    true,
    function(value)
        FLAGS.NotifyRare = value
    end
)

section(
    FarmPage,
    "RARITY FILTER"
)

for _, rarity in ipairs(
    CONFIG.RARITY_PRIORITY
) do

    toggle(
        FarmPage,
        rarity,
        CONFIG.TARGET_RARITIES[rarity],
        function(value)
            CONFIG.TARGET_RARITIES[rarity] =
                value
        end
    )
end

----------------------------------------------------------------
-- MOVEMENT
----------------------------------------------------------------

section(
    MovementPage,
    "MODE"
)

local ModeButton =
    button(
        MovementPage,
        "Mode: ZIGZAG"
    )

connect(
    ModeButton.MouseButton1Click,
    function()
        if CONFIG.MOVE_MODE == "ZigZag" then
            CONFIG.MOVE_MODE = "Direct"
        else
            CONFIG.MOVE_MODE = "ZigZag"
        end

        ModeButton.Text =
            "Mode: " ..
            string.upper(
                CONFIG.MOVE_MODE
            )
    end
)

section(
    MovementPage,
    "SAVED POSITION"
)

local SaveButton =
    button(
        MovementPage,
        "Save Position"
    )

local GoButton =
    button(
        MovementPage,
        "Go To Saved"
    )

connect(
    SaveButton.MouseButton1Click,
    function()
        local root = getRoot()

        if root then
            CONFIG.TREADMILL_CFRAME =
                root.CFrame

            SaveButton.Text =
                "Saved!"
        end

        task.delay(
            1.5,
            function()
                pcall(function()
                    SaveButton.Text =
                        "Save Position"
                end)
            end
        )
    end
)

connect(
    GoButton.MouseButton1Click,
    function()
        moveTarget(
            CONFIG.TREADMILL_CFRAME
        )
    end
)

section(
    MovementPage,
    "TELEPORT"
)

local DelayLabel =
    label(
        MovementPage,
        "  Delay: " ..
        tostring(
            CONFIG.TELEPORT_DELAY
        )
    )

local FasterButton =
    button(
        MovementPage,
        "Faster"
    )

connect(
    FasterButton.MouseButton1Click,
    function()
        CONFIG.TELEPORT_DELAY =
            math.max(
                0.01,
                CONFIG.TELEPORT_DELAY - 0.01
            )

        DelayLabel.Text =
            string.format(
                "  Delay: %.2f",
                CONFIG.TELEPORT_DELAY
            )
    end
)

local SlowerButton =
    button(
        MovementPage,
        "Slower"
    )

connect(
    SlowerButton.MouseButton1Click,
    function()
        CONFIG.TELEPORT_DELAY =
            math.min(
                0.30,
                CONFIG.TELEPORT_DELAY + 0.01
            )

        DelayLabel.Text =
            string.format(
                "  Delay: %.2f",
                CONFIG.TELEPORT_DELAY
            )
    end
)

----------------------------------------------------------------
-- BOSS
----------------------------------------------------------------

section(
    BossPage,
    "AUTO BOSS"
)

toggle(
    BossPage,
    "Auto Boss",
    false,
    function(value)
        FLAGS.AutoBoss = value
        updateDashboard()
    end
)

local AttackButton =
    button(
        BossPage,
        "Attack Once"
    )

connect(
    AttackButton.MouseButton1Click,
    function()
        task.spawn(
            attackBoss
        )
    end
)

----------------------------------------------------------------
-- TELEPORT
----------------------------------------------------------------

section(
    TeleportPage,
    "LOCATIONS"
)

local WaterfallButton =
    button(
        TeleportPage,
        "Secret Waterfall"
    )

connect(
    WaterfallButton.MouseButton1Click,
    function()
        moveTarget(
            CONFIG.WATERFALL_CFRAME
        )

        setStatus(
            "Waterfall"
        )
    end
)

local TreadmillButton =
    button(
        TeleportPage,
        "Treadmill"
    )

connect(
    TreadmillButton.MouseButton1Click,
    function()
        moveTarget(
            CONFIG.TREADMILL_CFRAME
        )

        setStatus(
            "Treadmill"
        )
    end
)

----------------------------------------------------------------
-- ANTI
----------------------------------------------------------------

section(
    AntiPage,
    "STATUS"
)

label(
    AntiPage,
    "  Anti-AFK: ON"
)

label(
    AntiPage,
    "  Reconnect: MANUAL"
)

label(
    AntiPage,
    "  Player.Kicked fix: ACTIVE"
)

section(
    AntiPage,
    "WALK SPEED"
)

local SpeedLabel =
    label(
        AntiPage,
        "  WalkSpeed: " ..
        tostring(
            CONFIG.WALK_SPEED
        )
    )

local SpeedUp =
    button(
        AntiPage,
        "Speed +2"
    )

connect(
    SpeedUp.MouseButton1Click,
    function()
        CONFIG.WALK_SPEED += 2

        SpeedLabel.Text =
            "  WalkSpeed: " ..
            tostring(
                CONFIG.WALK_SPEED
            )

        local humanoid =
            getHumanoid()

        if humanoid then
            humanoid.WalkSpeed =
                CONFIG.WALK_SPEED
        end
    end
)

local SpeedDown =
    button(
        AntiPage,
        "Speed -2"
    )

connect(
    SpeedDown.MouseButton1Click,
    function()
        CONFIG.WALK_SPEED =
            math.max(
                4,
                CONFIG.WALK_SPEED - 2
            )

        SpeedLabel.Text =
            "  WalkSpeed: " ..
            tostring(
                CONFIG.WALK_SPEED
            )

        local humanoid =
            getHumanoid()

        if humanoid then
            humanoid.WalkSpeed =
                CONFIG.WALK_SPEED
        end
    end
)

local ReconnectButton =
    button(
        AntiPage,
        "Manual Reconnect"
    )

connect(
    ReconnectButton.MouseButton1Click,
    function()
        task.spawn(
            manualReconnect
        )
    end
)

----------------------------------------------------------------
-- CHEAT
----------------------------------------------------------------

section(
    CheatPage,
    "MOVEMENT"
)

local CheatState = {
    Fly = false,
    Noclip = false,
    InfiniteJump = false,
    SpeedHack = false,
    GodMode = false,

    FlySpeed = 60,
    Speed = 60
}

local flyConnection
local noclipConnection
local jumpConnection
local godConnection

local function stopFly()
    CheatState.Fly = false

    if flyConnection then
        pcall(function()
            flyConnection:Disconnect()
        end)

        flyConnection = nil
    end

    local humanoid =
        getHumanoid()

    if humanoid then
        humanoid.PlatformStand = false
    end
end

local function startFly()
    if flyConnection then
        return
    end

    local root = getRoot()
    local humanoid = getHumanoid()

    if not root or not humanoid then
        return
    end

    humanoid.PlatformStand = true

    local bodyVelocity =
        Instance.new(
            "BodyVelocity"
        )

    bodyVelocity.MaxForce =
        Vector3.new(
            100000,
            100000,
            100000
        )

    bodyVelocity.Velocity =
        Vector3.zero

    bodyVelocity.Parent =
        root

    flyConnection =
        RunService.Heartbeat:Connect(
            function()
                if not CheatState.Fly then
                    pcall(function()
                        bodyVelocity:Destroy()
                    end)

                    stopFly()
                    return
                end

                local camera =
                    Workspace.CurrentCamera

                if not camera then
                    return
                end

                local movement =
                    Vector3.zero

                if UserInputService:IsKeyDown(
                    Enum.KeyCode.W
                ) then
                    movement +=
                        camera.CFrame.LookVector
                end

                if UserInputService:IsKeyDown(
                    Enum.KeyCode.S
                ) then
                    movement -=
                        camera.CFrame.LookVector
                end

                if UserInputService:IsKeyDown(
                    Enum.KeyCode.A
                ) then
                    movement -=
                        camera.CFrame.RightVector
                end

                if UserInputService:IsKeyDown(
                    Enum.KeyCode.D
                ) then
                    movement +=
                        camera.CFrame.RightVector
                end

                if UserInputService:IsKeyDown(
                    Enum.KeyCode.Space
                ) then
                    movement +=
                        Vector3.new(
                            0,
                            1,
                            0
                        )
                end

                if UserInputService:IsKeyDown(
                    Enum.KeyCode.LeftControl
                ) then
                    movement -=
                        Vector3.new(
                            0,
                            1,
                            0
                        )
                end

                if movement.Magnitude > 0 then
                    bodyVelocity.Velocity =
                        movement.Unit *
                        CheatState.FlySpeed
                else
                    bodyVelocity.Velocity =
                        Vector3.zero
                end
            end
        )
end

toggle(
    CheatPage,
    "Fly",
    false,
    function(value)
        CheatState.Fly = value

        if value then
            startFly()
        else
            stopFly()
        end
    end
)

local FlySpeedLabel =
    label(
        CheatPage,
        "  Fly Speed: 60"
    )

local FlySpeedUp =
    button(
        CheatPage,
        "Fly Speed +10"
    )

connect(
    FlySpeedUp.MouseButton1Click,
    function()
        CheatState.FlySpeed =
            math.min(
                500,
                CheatState.FlySpeed + 10
            )

        FlySpeedLabel.Text =
            "  Fly Speed: " ..
            tostring(
                CheatState.FlySpeed
            )
    end
)

local FlySpeedDown =
    button(
        CheatPage,
        "Fly Speed -10"
    )

connect(
    FlySpeedDown.MouseButton1Click,
    function()
        CheatState.FlySpeed =
            math.max(
                10,
                CheatState.FlySpeed - 10
            )

        FlySpeedLabel.Text =
            "  Fly Speed: " ..
            tostring(
                CheatState.FlySpeed
            )
    end
)

toggle(
    CheatPage,
    "Noclip",
    false,
    function(value)
        CheatState.Noclip = value

        if not value then
            if noclipConnection then
                noclipConnection:Disconnect()
                noclipConnection = nil
            end

            return
        end

        if noclipConnection then
            return
        end

        noclipConnection =
            RunService.Stepped:Connect(
                function()
                    local character =
                        getCharacter()

                    if not character then
                        return
                    end

                    for _, part in ipairs(
                        character:GetDescendants()
                    ) do
                        if part:IsA("BasePart") then
                            part.CanCollide =
                                not CheatState.Noclip
                        end
                    end
                end
            )
    end
)

toggle(
    CheatPage,
    "Infinite Jump",
    false,
    function(value)
        CheatState.InfiniteJump = value

        if jumpConnection then
            jumpConnection:Disconnect()
            jumpConnection = nil
        end

        if value then
            jumpConnection =
                UserInputService.JumpRequest:Connect(
                    function()
                        local humanoid =
                            getHumanoid()

                        if humanoid then
                            humanoid:ChangeState(
                                Enum.HumanoidStateType.Jumping
                            )
                        end
                    end
                )
        end
    end
)

----------------------------------------------------------------
-- ESP
----------------------------------------------------------------

local ESP = {
    Players = false,
    Eggs = false,
    Distance = 500,
    Objects = {}
}

local ESPFolder =
    New(
        "Folder",
        {
            Name = "VT_ESP"
        },
        CoreGui
    )

local function clearESP()
    for key, object in pairs(
        ESP.Objects
    ) do
        pcall(function()
            object:Destroy()
        end)

        ESP.Objects[key] = nil
    end
end

local function addESP(
    key,
    adornee,
    text,
    color
)
    if not adornee then
        return
    end

    if ESP.Objects[key] then
        return
    end

    local billboard =
        New(
            "BillboardGui",
            {
                Name = "VT_ESP",
                Size =
                    UDim2.new(
                        0,
                        130,
                        0,
                        40
                    ),

                StudsOffset =
                    Vector3.new(
                        0,
                        3,
                        0
                    ),

                AlwaysOnTop = true,
                Adornee = adornee
            },
            ESPFolder
        )

    if not billboard then
        return
    end

    local textLabel =
        New(
            "TextLabel",
            {
                Size =
                    UDim2.new(
                        1,
                        0,
                        1,
                        0
                    ),

                BackgroundTransparency = 1,

                Text = text,

                TextColor3 = color,

                TextSize = 10,

                Font =
                    Enum.Font.GothamBold
            },
            billboard
        )

    ESP.Objects[key] =
        billboard
end

local function updateESP()
    if not ESP.Players
        and not ESP.Eggs then

        clearESP()
        return
    end

    local root = getRoot()

    if not root then
        return
    end

    local myPosition =
        root.Position

    if ESP.Players then
        for _, player in ipairs(
            Players:GetPlayers()
        ) do

            if player ~= LocalPlayer then
                local character =
                    player.Character

                local playerRoot =
                    character
                    and character:FindFirstChild(
                        "HumanoidRootPart"
                    )

                if playerRoot then
                    local distance =
                        (
                            myPosition -
                            playerRoot.Position
                        ).Magnitude

                    if distance <= ESP.Distance then
                        addESP(
                            "PLAYER_" ..
                            tostring(
                                player.UserId
                            ),

                            playerRoot,

                            player.Name ..
                            "\n[" ..
                            math.floor(
                                distance
                            ) ..
                            "]",

                            Color3.fromRGB(
                                255,
                                80,
                                80
                            )
                        )
                    end
                end
            end
        end
    end

    if ESP.Eggs then
        for _, object in ipairs(
            Workspace:GetDescendants()
        ) do

            local isEgg = false

            if object:IsA("BasePart")
                or object:IsA("Model") then

                local name =
                    string.lower(
                        object.Name
                    )

                isEgg =
                    string.find(
                        name,
                        "egg",
                        1,
                        true
                    ) ~= nil
                    and
                    string.find(
                        name,
                        "hatch",
                        1,
                        true
                    ) == nil
            end

            if isEgg then
                local position

                pcall(function()
                    if object:IsA("Model") then
                        position =
                            object:GetPivot().Position
                    else
                        position =
                            object.Position
                    end
                end)

                if position then
                    local distance =
                        (
                            myPosition -
                            position
                        ).Magnitude

                    if distance <= ESP.Distance then
                        local rarity =
                            getRarity(object)
                            or "?"

                        local adornee =
                            object

                        if object:IsA("Model") then
                            adornee =
                                object.PrimaryPart
                                or object:FindFirstChildWhichIsA(
                                    "BasePart"
                                )
                        end

                        if adornee then
                            addESP(
                                "EGG_" ..
                                tostring(
                                    object
                                ),

                                adornee,

                                rarity ..
                                "\n[" ..
                                math.floor(
                                    distance
                                ) ..
                                "]",

                                Color3.fromRGB(
                                    255,
                                    215,
                                    0
                                )
                            )
                        end
                    end
                end
            end
        end
    end
end

section(
    ESPPage,
    "ESP"
)

toggle(
    ESPPage,
    "Player ESP",
    false,
    function(value)
        ESP.Players = value

        if not value then
            clearESP()
        end
    end
)

toggle(
    ESPPage,
    "Egg ESP",
    false,
    function(value)
        ESP.Eggs = value

        if not value then
            clearESP()
        end
    end
)

local ESPDistanceLabel =
    label(
        ESPPage,
        "  Distance: 500"
    )

local ESPDistanceUp =
    button(
        ESPPage,
        "Distance +50"
    )

connect(
    ESPDistanceUp.MouseButton1Click,
    function()
        ESP.Distance =
            math.min(
                2000,
                ESP.Distance + 50
            )

        ESPDistanceLabel.Text =
            "  Distance: " ..
            tostring(
                ESP.Distance
            )
    end
)

local ESPDistanceDown =
    button(
        ESPPage,
        "Distance -50"
    )

connect(
    ESPDistanceDown.MouseButton1Click,
    function()
        ESP.Distance =
            math.max(
                50,
                ESP.Distance - 50
            )

        ESPDistanceLabel.Text =
            "  Distance: " ..
            tostring(
                ESP.Distance
            )
    end
)

local ClearESPButton =
    button(
        ESPPage,
        "Clear ESP"
    )

connect(
    ClearESPButton.MouseButton1Click,
    function()
        clearESP()
    end
)

----------------------------------------------------------------
-- SETTINGS
----------------------------------------------------------------

section(
    SettingsPage,
    "SETTINGS"
)

local CopyLogButton =
    button(
        SettingsPage,
        "Copy Log"
    )

connect(
    CopyLogButton.MouseButton1Click,
    function()
        copyText(
            table.concat(
                LOG,
                "\n"
            )
        )

        setStatus(
            "Log copied"
        )
    end
)

local ResetButton =
    button(
        SettingsPage,
        "Reset Stats"
    )

connect(
    ResetButton.MouseButton1Click,
    function()
        FLAGS.EggsCollected = 0
        FLAGS.BossAttacks = 0
        FLAGS.EggsPerMinute = 0
        FLAGS.SessionStart = tick()

        updateDashboard()

        setStatus(
            "Stats reset"
        )
    end
)

local HideButton =
    button(
        SettingsPage,
        "Hide UI"
    )

connect(
    HideButton.MouseButton1Click,
    function()
        MainFrame.Visible = false
    end
)

local UnloadButton =
    button(
        SettingsPage,
        "Unload"
    )

connect(
    UnloadButton.MouseButton1Click,
    function()
        cleanup()

        pcall(function()
            ScreenGui:Destroy()
        end)

        pcall(function()
            ESPFolder:Destroy()
        end)
    end
)

label(
    SettingsPage,
    "  RightShift = Toggle UI"
)

----------------------------------------------------------------
-- CLOSE
----------------------------------------------------------------

connect(
    CloseButton.MouseButton1Click,
    function()
        MainFrame.Visible = false
    end
)

----------------------------------------------------------------
-- RIGHT SHIFT
----------------------------------------------------------------

connect(
    UserInputService.InputBegan,
    function(input, processed)
        if processed then
            return
        end

        if input.KeyCode ==
            Enum.KeyCode.RightShift then

            MainFrame.Visible =
                not MainFrame.Visible
        end
    end
)

----------------------------------------------------------------
-- ESP LOOP
----------------------------------------------------------------

task.spawn(function()
    while FLAGS.Running do
        if ESP.Players or ESP.Eggs then
            pcall(updateESP)
        end

        task.wait(0.75)
    end
end)

----------------------------------------------------------------
-- DASHBOARD LOOP
----------------------------------------------------------------

task.spawn(function()
    while FLAGS.Running do
        pcall(updateDashboard)
        task.wait(0.5)
    end
end)

----------------------------------------------------------------
-- MAIN FARM LOOP
----------------------------------------------------------------

task.spawn(function()
    while FLAGS.Running do

        if FLAGS.AutoBoss then
            pcall(attackBoss)

        elseif FLAGS.AutoFarm then

            pcall(function()
                local egg =
                    findPriorityEgg()

                if egg then
                    collectEgg(egg)

                elseif FLAGS.ReturnTreadmill then
                    goToTreadmill()

                else
                    setStatus(
                        "Waiting for egg..."
                    )
                end
            end)

        else
            if FLAGS.Status ~= "Ready" then
                setStatus("Ready")
            end
        end

        task.wait(
            CONFIG.CHECK_INTERVAL
        )
    end
end)

----------------------------------------------------------------
-- INIT
----------------------------------------------------------------

for name, page in pairs(Pages) do
    page.Visible = false
end

Pages.Home.Visible = true

Tabs.Home.BackgroundColor3 =
    Color3.fromRGB(
        60,
        45,
        130
    )

Tabs.Home.TextColor3 =
    Color3.fromRGB(
        255,
        255,
        255
    )

updateDashboard()

setStatus(
    "Ready - TEMP BUILD"
)

print(
    "[VAN THANH V4 TEMP] Loaded successfully"
)

print(
    "[VAN THANH V4 TEMP] Player.Kicked crash fixed"
)

print(
    "[VAN THANH V4 TEMP] Bypass hooks disabled"
)
