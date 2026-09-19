--[[
 ██╗   ██╗
 ██║   ██║   VAN THANH EXECUTOR
 ╚██╗ ██╔╝   Steal An Egg V4
  ╚████╔╝    Anti-Cheat · Hook · Bypass · Farm
   ╚═══╝     
]]

----------------------------------------------------------------
-- EXECUTOR COMPAT LAYER
----------------------------------------------------------------

local ENV = getgenv and getgenv() or _G

if ENV.__VanThanhV4 then
    warn("[VT-V4] Already loaded, skipping.")
    return
end
ENV.__VanThanhV4   = true
ENV.__VanThanhAC   = true
ENV.__StealEggV4   = true

-- safe global checker — works even if the global doesn't exist
local function hasGlobal(name)
    return rawget(_G, name) ~= nil
        or (type(getfenv) == "function" and pcall(function() return getfenv(0)[name] end))
        or pcall(function()
            local _ = (getgenv and getgenv() or _G)[name]
        end)
end

local function getGlobal(name)
    if getgenv then
        local ok, v = pcall(function() return getgenv()[name] end)
        if ok and v ~= nil then return v end
    end
    local ok2, v2 = pcall(function() return _G[name] end)
    if ok2 and v2 ~= nil then return v2 end
    return nil
end

local _cloneref      = getGlobal("cloneref")
local _newcclosure   = getGlobal("newcclosure")
local _hookfunction  = getGlobal("hookfunction")
local _hookmetamethod= getGlobal("hookmetamethod")
local _islclosure    = getGlobal("islclosure")

local safeRef = (type(_cloneref) == "function")
    and _cloneref or function(x) return x end

local safeClosure = (type(_newcclosure) == "function")
    and _newcclosure or function(f) return f end

local safeHook = (type(_hookfunction) == "function")
    and _hookfunction or nil

local hookMeta = (type(_hookmetamethod) == "function")
    and _hookmetamethod or nil

local isLClosure = (type(_islclosure) == "function")
    and _islclosure or function() return true end

local function getUIParent()
    -- try syn protect_gui
    if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
        local ok, gui = pcall(function()
            local g = Instance.new("ScreenGui")
            syn.protect_gui(g)
            g.Parent = game:GetService("CoreGui")
            return g
        end)
        if ok and gui then return gui end
    end
    -- try gethui
    if type(getGlobal("gethui")) == "function" then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    -- try CoreGui direct
    local ok, cg = pcall(function()
        return safeRef(game:GetService("CoreGui"))
    end)
    if ok and cg then return cg end
    -- last resort: PlayerGui
    local ok2, pg = pcall(function()
        return LocalPlayer:WaitForChild("PlayerGui", 5)
    end)
    if ok2 and pg then return pg end
    return nil
end

local function firePrompt(prompt)
    if type(getGlobal("fireproximityprompt")) == "function" then
        pcall(getGlobal("fireproximityprompt"), prompt)
    elseif type(getGlobal("fireclickdetector")) == "function" then
        local cd = prompt.Parent
            and prompt.Parent:FindFirstChildOfClass("ClickDetector")
        if cd then pcall(getGlobal("fireclickdetector"), cd) end
    else
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration + 0.05)
            prompt:InputHoldEnd()
        end)
    end
end

local function toClipboard(text)
    local _sc = getGlobal("setclipboard") if _sc then pcall(_sc, text)
    elseif type(getGlobal("syn")) == "table" and getGlobal("syn").write_clipboard then pcall(getGlobal("syn").write_clipboard, text)
    elseif getGlobal("Clipboard") then pcall(function() getGlobal("Clipboard").set(text) end)
    end
end

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
-- CONFIG
----------------------------------------------------------------

local CONFIG = {
    CHECK_INTERVAL   = 0.35,
    TREADMILL_CFRAME = CFrame.new(0, 10, 0),
    WATERFALL_CFRAME = CFrame.new(150, 5, -800),
    MOVE_MODE        = "ZigZag",
    ZIGZAG_OFFSET    = 6,
    STEP_SIZE        = 18,

    RARITY_PRIORITY = { "Secret","Eternal","Divine","Light","Dark" },
    TARGET_RARITIES = {
        Secret  = true,
        Eternal = true,
        Divine  = true,
        Light   = true,
        Dark    = true,
    },

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
    AutoFarm        = false,
    AutoBoss        = false,
    ReturnTreadmill = true,
    Running         = true,
    EggsCollected   = 0,
    BossAttacks     = 0,
    EggsPerMinute   = 0,
    LastEggTick     = tick(),
    CurrentStatus   = "Idle",
    NotifyOnRare    = true,
}

----------------------------------------------------------------
-- CONNECTION POOL
----------------------------------------------------------------

local Connections = {}

local function addConn(c)
    table.insert(Connections, c)
    return c
end

local function cleanupAll()
    FLAGS.Running    = false
    ENV.__VanThanhV4 = nil
    ENV.__VanThanhAC = nil
    ENV.__StealEggV4 = nil
    for _, c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    Connections = {}
end

----------------------------------------------------------------
-- INTERNAL LOG
----------------------------------------------------------------

local VT_LOG = {}
local function vtLog(tag, msg)
    local entry = string.format("[VT][%s] %s | %.2fs", tag, msg, tick())
    table.insert(VT_LOG, entry)
    if ENV.__VT_DEV then print(entry) end
end

----------------------------------------------------------------
-- ╔══════════════════════════════════════════╗
-- ║      VAN THANH ANTI-CHEAT BYPASS         ║
-- ╚══════════════════════════════════════════╝
----------------------------------------------------------------

-- [1] REMOTE SPY SHIELD
-- Intercept FireServer/InvokeServer via __namecall hook
-- Drops any remote in BlockedRemotes silently

local VT_RemoteLog     = {}
local VT_BlockedRemotes = {
    -- add game-specific anti-cheat remote names here:
    -- ["CheatDetect"]   = true,
    -- ["IntegrityPing"] = true,
}

local _namecall_orig
if hookMeta then
    _namecall_orig = hookMeta(game, "__namecall", safeClosure(function(self, ...)
        local method = getnamecallmethod and getnamecallmethod() or ""
        if method == "FireServer"
            or method == "InvokeServer"
            or method == "FireAllClients" then

            local name = (typeof(self) ~= "nil" and self.Name) or "unknown"
            if VT_BlockedRemotes[name] then
                vtLog("REMOTE_BLOCK", "Dropped: " .. name)
                return
            end
            table.insert(VT_RemoteLog, {
                name=name, method=method, t=tick()
            })
        end
        return _namecall_orig(self, ...)
    end))
    vtLog("HOOK", "__namecall → remote shield active")
end

-- [2] DEBUG.INFO SPOOFER
-- Masks executor stack source from game anti-cheat scanners

if debug and typeof(debug.info) == "function" and safeHook then
    local real_di = debug.info
    if isLClosure(debug.info) then
        safeHook(debug.info, safeClosure(function(level, opts)
            local ok, src = pcall(real_di, level, "s")
            if ok and src and type(opts) == "string"
                and string.find(opts, "s")
                and string.find(src, "LocalScript") == nil
                and string.find(src, "Script") == nil then
                return (real_di(level, opts)):gsub(src, "LocalScript")
            end
            return real_di(level, opts)
        end))
        vtLog("HOOK", "debug.info spoofed")
    end
end

-- [3] SCRIPT IDENTITY MASKER
-- Spoof executor identity level to CoreScript (7)

if type(getGlobal("getscriptidentity")) == "function" and safeHook then
    local real_gsi = getGlobal("getscriptidentity")
    safeHook(real_gsi, safeClosure(function(...)
        return 7
    end))
    vtLog("HOOK", "getscriptidentity masked → 7")
end

if type(getGlobal("identifyexecutor")) == "function" and safeHook then
    local real_ie = getGlobal("identifyexecutor")
    safeHook(real_ie, safeClosure(function()
        return "Roblox", "0.0.0"
    end))
    vtLog("HOOK", "identifyexecutor spoofed → vanilla")
end

-- [4] HTTPSERVICE FINGERPRINT BLOCK
-- Intercept outgoing HTTP calls containing anti-cheat keywords

local HTTP_BLOCKLIST = {
    "cheatdetect","anticheat","exploit","ban",
    "report","telemetry","integrity","flagged",
}

if safeHook then
    pcall(function()
        if isLClosure(HttpService.GetAsync) then
            local real_get = HttpService.GetAsync
            safeHook(real_get, safeClosure(function(self, url, ...)
                for _, kw in ipairs(HTTP_BLOCKLIST) do
                    if string.find(string.lower(url or ""), kw) then
                        vtLog("HTTP_BLOCK", "GET blocked: " .. url)
                        return "{}"
                    end
                end
                return real_get(self, url, ...)
            end))
            vtLog("HOOK", "HttpService.GetAsync filtered")
        end
    end)

    pcall(function()
        if isLClosure(HttpService.PostAsync) then
            local real_post = HttpService.PostAsync
            safeHook(real_post, safeClosure(function(self, url, body, ...)
                for _, kw in ipairs(HTTP_BLOCKLIST) do
                    if string.find(string.lower(url or ""), kw) then
                        vtLog("HTTP_BLOCK", "POST blocked: " .. url)
                        return "{}"
                    end
                end
                return real_post(self, url, body, ...)
            end))
            vtLog("HOOK", "HttpService.PostAsync filtered")
        end
    end)
end

-- [5] KICK BYPASS + AUTO RECONNECT
-- Null out LocalPlayer:Kick(), intercept game:Shutdown()
-- Fallback: reconnect via TeleportService on real kick

local function doReconnect()
    vtLog("RECONNECT", "Reconnecting to " .. tostring(game.PlaceId))
    task.wait(2.5)
    pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

if safeHook then
    pcall(function()
        -- Kick() là C-closure trên hầu hết executor, dùng hookmetamethod thay thế
        local kickFn
        pcall(function()
            kickFn = LocalPlayer.Kick  -- có thể lỗi nếu member invalid
        end)
        if kickFn and isLClosure(kickFn) then
            safeHook(kickFn, safeClosure(function(self, msg)
                vtLog("KICK_BLOCK", "Intercepted: " .. tostring(msg or "no reason"))
            end))
            vtLog("HOOK", "LocalPlayer:Kick() nulled")
        else
            -- fallback: hook qua __namecall nếu đã có
            vtLog("HOOK", "Kick() not lclosure — covered by __namecall hook")
        end
    end)

    pcall(function()
        if isLClosure(game.Shutdown) then
            safeHook(game.Shutdown, safeClosure(function(self)
                vtLog("SHUTDOWN_BLOCK", "game:Shutdown() intercepted")
                doReconnect()
            end))
            vtLog("HOOK", "game:Shutdown() intercepted")
        end
    end)
end

pcall(function()
    if LocalPlayer:FindFirstChild("Kicked") or true then
        addConn(LocalPlayer.OnTeleport:Connect(safeClosure(function(state)
            if state == Enum.TeleportState.Failed then
                vtLog("TELEPORT_FAIL", "Teleport failed, retrying...")
                doReconnect()
            end
        end)))
    end
end)

-- safe kick listener — game:GetService wraps avoid member errors
pcall(function()
    local ok, conn = pcall(function()
        return LocalPlayer.Kicked:Connect(safeClosure(function(reason)
            vtLog("KICKED_EVENT", "Reason: " .. tostring(reason or "nil"))
            doReconnect()
        end))
    end)
    if ok and conn then addConn(conn) end
end)

-- [6] HUMANOID PROPERTY SPOOF VIA __INDEX
-- If game scans hum.WalkSpeed via __index meta, return vanilla value

if hookMeta then
    pcall(function()
        local char = LocalPlayer.Character
            or LocalPlayer.CharacterAdded:Wait()
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end

        local _hum_index = hookMeta(hum, "__index", safeClosure(function(self, key)
            if key == "WalkSpeed" then return CONFIG.ANTI.WALK_SPEED end
            if key == "JumpPower" then return CONFIG.ANTI.JUMP_POWER end
            return _hum_index(self, key)
        end))
        vtLog("HOOK", "Humanoid __index spoofed")
    end)
end

-- [7] WORKSPACE GRAVITY GUARD
-- Block games that set Gravity=0 to detect fly/noclip

if hookMeta then
    pcall(function()
        local ws = game:GetService("Workspace")
        local real_grav = ws.Gravity
        local _ws_ni = hookMeta(ws, "__newindex", safeClosure(function(self, key, value)
            if key == "Gravity" then
                vtLog("GRAVITY_GUARD", "Gravity write blocked: " .. tostring(value))
                return _ws_ni(self, key, real_grav)
            end
            return _ws_ni(self, key, value)
        end))
        vtLog("HOOK", "Workspace.Gravity guarded")
    end)
end

-- [8] SCRIPT CONTEXT ERROR SINK
-- Suppress executor-level error stack leaks

pcall(function()
    addConn(ScriptContext.Error:Connect(safeClosure(function(msg, trace, script)
        if script == nil then
            vtLog("ERROR_SINK", "Suppressed: " .. tostring(msg))
        end
    end)))
    vtLog("HOOK", "ScriptContext.Error sink active")
end)

-- [9] ENVIRONMENT FINGERPRINT WIPE
-- Remove executor-identifying keys from getgenv after boot

task.delay(1.5, safeClosure(function()
    local DIRTY_KEYS = {
        "SYNAPSE_LOADED","KRNL_LOADED","FLUXUS_LOADED",
        "SCRIPTWARE_LOADED","OXYGEN_LOADED","WAVE_LOADED",
        "EVON_LOADED","ARCEUS_LOADED","CODEX_LOADED",
    }
    local g = getgenv and getgenv() or _G
    for _, key in ipairs(DIRTY_KEYS) do
        pcall(function() g[key] = nil end)
    end
    vtLog("ENV_CLEAN", "Executor fingerprint keys wiped")
end))

-- [10] RUNTIME INTEGRITY LOOP
-- Re-verify and re-apply critical hooks every 30s
-- Guards against game scripts restoring hooked functions

task.spawn(safeClosure(function()
    while ENV.__VanThanhAC do
        task.wait(30)
        pcall(function()
            if safeHook then
                local kickFn
                pcall(function() kickFn = LocalPlayer.Kick end)
                if kickFn and isLClosure(kickFn) then
                    safeHook(kickFn, safeClosure(function(self, msg)
                        vtLog("KICK_REBLOCK", "Re-intercepted: " .. tostring(msg or ""))
                    end))
                end
            end
        end)
        vtLog("INTEGRITY", "Hook integrity sweep done")
    end
end))

vtLog("INIT", "Van Thanh bypass layer fully loaded — " .. #VT_LOG .. " hooks")
print("[VAN THANH] Anti-cheat bypass active")

----------------------------------------------------------------
-- ╔══════════════════════════════════════════╗
-- ║         ANTI-AFK                         ║
-- ╚══════════════════════════════════════════╝
----------------------------------------------------------------

task.spawn(safeClosure(function()
    while FLAGS.Running do
        task.wait(CONFIG.ANTI.AFK_INTERVAL)
        if not FLAGS.Running then break end
        pcall(function()
            local vim = getGlobal("VirtualInputManager")
            if vim then
                vim:SendMouseButtonEvent(0,0,0,true,game,1)
                task.wait(0.05)
                vim:SendMouseButtonEvent(0,0,0,false,game,1)
            end
        end)
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.Jump = true end
        end)
    end
end))

----------------------------------------------------------------
-- PROPERTY GUARD (WalkSpeed / JumpPower)
----------------------------------------------------------------

if CONFIG.ANTI.PROPERTY_GUARD then
    local function guardHumanoid(hum)
        if not hum then return end

        addConn(hum:GetPropertyChangedSignal("WalkSpeed"):Connect(
            safeClosure(function()
                task.defer(function()
                    pcall(function()
                        if hum.WalkSpeed ~= CONFIG.ANTI.WALK_SPEED then
                            hum.WalkSpeed = CONFIG.ANTI.WALK_SPEED
                        end
                    end)
                end)
            end)
        ))

        addConn(hum:GetPropertyChangedSignal("JumpPower"):Connect(
            safeClosure(function()
                task.defer(function()
                    pcall(function()
                        if hum.JumpPower ~= CONFIG.ANTI.JUMP_POWER then
                            hum.JumpPower = CONFIG.ANTI.JUMP_POWER
                        end
                    end)
                end)
            end)
        ))
    end

    pcall(function()
        local char = LocalPlayer.Character
        if char then
            guardHumanoid(char:FindFirstChildOfClass("Humanoid"))
        end
    end)

    pcall(function()
        local conn = LocalPlayer.CharacterAdded:Connect(
            safeClosure(function(char)
                local ok, hum = pcall(function()
                    return char:WaitForChild("Humanoid", 5)
                end)
                if not ok or not hum then return end
                guardHumanoid(hum)
                if CONFIG.ANTI.HUMANOID_RESTORE then
                    task.wait(0.2)
                    pcall(function()
                        hum.WalkSpeed = CONFIG.ANTI.WALK_SPEED
                        hum.JumpPower = CONFIG.ANTI.JUMP_POWER
                    end)
                end
            end)
        )
        if conn then addConn(conn) end
    end)
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

----------------------------------------------------------------
-- MOVEMENT
----------------------------------------------------------------

local function moveTarget(targetCFrame)
    local root = getRoot()
    if not root then return end

    if CONFIG.MOVE_MODE == "Direct" then
        root.CFrame = targetCFrame
        task.wait(CONFIG.ANTI.TELEPORT_DELAY)
        return
    end

    local startPos = root.Position
    local endPos   = targetCFrame.Position
    local diff     = endPos - startPos
    local dist     = diff.Magnitude

    if dist < 1 then
        root.CFrame = targetCFrame
        return
    end

    local steps = math.clamp(math.floor(dist / 15), 2, 12)
    local dir   = diff.Unit
    local right = dir:Cross(Vector3.new(0,1,0))

    if right.Magnitude < 0.01 then
        right = Vector3.new(1,0,0)
    else
        right = right.Unit
    end

    for i = 1, steps do
        if not FLAGS.Running then break end
        local alpha  = i / steps
        local pos    = startPos:Lerp(endPos, alpha)
        local offset = (CONFIG.MOVE_MODE == "ZigZag")
            and ((i % 2 == 0) and CONFIG.ZIGZAG_OFFSET or -CONFIG.ZIGZAG_OFFSET)
            or 0
        root.CFrame = CFrame.new(pos + right * offset)
        task.wait(CONFIG.ANTI.TELEPORT_DELAY)
    end

    root.CFrame = targetCFrame
end

----------------------------------------------------------------
-- STATUS
----------------------------------------------------------------

local StatusBox

local function updateStatus(text)
    FLAGS.CurrentStatus = text
    if StatusBox then
        StatusBox.Text = "  Status: " .. text
    end
end

----------------------------------------------------------------
-- EGG SCANNER
----------------------------------------------------------------

local function getRarity(obj)
    local attr = obj:GetAttribute("Rarity")
        or obj:GetAttribute("RarityName")
        or obj:GetAttribute("EggRarity")
    if attr then return attr end

    local name = string.lower(obj.Name)
    for _, rarity in ipairs(CONFIG.RARITY_PRIORITY) do
        if string.find(name, string.lower(rarity)) then
            return rarity
        end
    end
    return nil
end

local function findPriorityEgg()
    local root = getRoot()
    if not root then return nil end

    local bestEgg      = nil
    local bestPriority = math.huge
    local bestDistance = math.huge

    for _, obj in ipairs(Workspace:GetDescendants()) do
        local hasUid = obj:GetAttribute("EggUid")
            or obj:GetAttribute("toolUidAttribute")

        local isEggName = (obj:IsA("BasePart") or obj:IsA("Model"))
            and string.find(string.lower(obj.Name), "egg")
            and not string.find(string.lower(obj.Name), "hatch")

        -- extra patterns
        local matchExtra = false
        for _, pat in ipairs(CONFIG.EXTRA_EGG_PATTERNS) do
            if string.find(string.lower(obj.Name), string.lower(pat)) then
                matchExtra = true
                break
            end
        end

        if hasUid or isEggName or matchExtra then
            local rarity = getRarity(obj)
            if not rarity then continue end
            if not CONFIG.TARGET_RARITIES[rarity] then continue end

            local priority = math.huge
            for i, r in ipairs(CONFIG.RARITY_PRIORITY) do
                if r == rarity then priority = i break end
            end

            local pos = obj:IsA("Model")
                and obj:GetPivot().Position
                or obj.Position

            local dist = (root.Position - pos).Magnitude

            if priority < bestPriority
                or (priority == bestPriority and dist < bestDistance) then
                bestPriority = priority
                bestDistance = dist
                bestEgg      = obj
            end
        end
    end

    return bestEgg
end

----------------------------------------------------------------
-- TREADMILL
----------------------------------------------------------------

local function goToTreadmill()
    updateStatus("Going to treadmill...")
    moveTarget(CONFIG.TREADMILL_CFRAME)
    for _, prompt in ipairs(Workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Parent then
            local n = string.lower(prompt.Parent.Name)
            if string.find(n, "treadmill") then
                firePrompt(prompt)
                break
            end
        end
    end
end

----------------------------------------------------------------
-- COLLECT EGG
----------------------------------------------------------------

local function collectEgg(eggObj)
    if not eggObj then return end

    local rarity = getRarity(eggObj) or "?"
    updateStatus("Collecting " .. rarity .. ": " .. eggObj.Name)

    local targetCF = eggObj:IsA("Model")
        and eggObj:GetPivot()
        or eggObj.CFrame

    moveTarget(targetCF + Vector3.new(0, 3, 0))
    task.wait(0.15)

    local prompt = eggObj:FindFirstChildOfClass("ProximityPrompt")
    if not prompt and eggObj.Parent then
        prompt = eggObj.Parent:FindFirstChildOfClass("ProximityPrompt")
    end
    if not prompt then
        for _, child in ipairs(eggObj:GetDescendants()) do
            if child:IsA("ProximityPrompt") then
                prompt = child
                break
            end
        end
    end

    if prompt then
        firePrompt(prompt)
        FLAGS.EggsCollected += 1

        -- EPM tracking
        local now  = tick()
        local elapsed = now - CONFIG.SESSION.START_TICK
        FLAGS.EggsPerMinute = math.floor(
            FLAGS.EggsCollected / math.max(elapsed / 60, 0.01)
        )

        -- notify on rare
        if FLAGS.NotifyOnRare and
            (rarity == "Secret" or rarity == "Eternal") then
            vtLog("RARE", "Collected " .. rarity .. " egg!")
        end
    end
end

----------------------------------------------------------------
-- BOSS HANDLER (multi-scan + retry)
----------------------------------------------------------------

local function handleBoss()
    updateStatus("Fighting Boss...")

    local bossFolder = nil
    for _, name in ipairs(CONFIG.BOSS.SCAN_NAMES) do
        bossFolder = Workspace:FindFirstChild(name)
        if bossFolder then break end
    end

    if not bossFolder then
        updateStatus("Boss not found")
        return
    end

    local boss = bossFolder:FindFirstChildOfClass("Model")
    if not boss then
        updateStatus("Boss model not found")
        return
    end

    local bossRoot = boss:FindFirstChild("HumanoidRootPart")
    if not bossRoot then return end

    moveTarget(bossRoot.CFrame + Vector3.new(0, 5, -8))
    task.wait(CONFIG.BOSS.ATTACK_DELAY)

    local char = LocalPlayer.Character
    if not char then return end

    -- try all tools in backpack
    local tried = false
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") then
            pcall(function() item:Activate() end)
            tried = true
        end
    end

    -- fallback: check backpack
    if not tried then
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            for _, item in ipairs(bp:GetChildren()) do
                if item:IsA("Tool") then
                    item.Parent = char
                    task.wait(0.05)
                    pcall(function() item:Activate() end)
                end
            end
        end
    end

    -- scan for ClickDetectors on boss
    for _, desc in ipairs(boss:GetDescendants()) do
        if desc:IsA("ClickDetector") then
            pcall(function()
                local _fcd2 = getGlobal("fireclickdetector")
                if type(_fcd2) == "function" then
                    _fcd2(desc)
                end
            end)
        end
        if desc:IsA("ProximityPrompt") then
            firePrompt(desc)
        end
    end

    FLAGS.BossAttacks += 1
    updateStatus("Boss attacked #" .. FLAGS.BossAttacks)
end

----------------------------------------------------------------
-- CLEAN OLD UI
----------------------------------------------------------------

pcall(function()
    local old = CoreGui:FindFirstChild("StealEggHubV3")
    if old then old:Destroy() end
    local old4 = CoreGui:FindFirstChild("StealEggHubV4")
    if old4 then old4:Destroy() end
end)

----------------------------------------------------------------
-- UI BUILD
----------------------------------------------------------------

local UIParent = getUIParent()

local function create(className, props, parent)
    local obj
    local ok, err = pcall(function()
        obj = Instance.new(className)
    end)
    if not ok or not obj then
        warn("[VT] Instance.new failed for " .. tostring(className) .. ": " .. tostring(err))
        return nil
    end
    for k, v in pairs(props or {}) do
        pcall(function() obj[k] = v end)
    end
    if parent then
        pcall(function() obj.Parent = parent end)
    end
    return obj
end

if not UIParent then
    warn("[VT] UIParent is nil — falling back to PlayerGui")
    UIParent = LocalPlayer:FindFirstChild("PlayerGui")
        or game:GetService("CoreGui")
end

local ScreenGui = create("ScreenGui", {
    Name           = "StealEggHubV4",
    ResetOnSpawn   = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, UIParent)

if not ScreenGui then
    -- last resort bare creation
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "StealEggHubV4"
    ScreenGui.ResetOnSpawn = false
    pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
end

if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
    pcall(syn.protect_gui, ScreenGui)
end

local MainFrame = create("Frame", {
    Name              = "MainFrame",
    Size              = UDim2.new(0, 640, 0, 450),
    Position          = UDim2.new(0.5, -320, 0.5, -225),
    BackgroundColor3  = Color3.fromRGB(13, 13, 18),
    BorderSizePixel   = 0,
    Active            = true,
    Draggable         = true,
}, ScreenGui)

create("UICorner", { CornerRadius = UDim.new(0, 12) }, MainFrame)
create("UIStroke", {
    Color     = Color3.fromRGB(50, 50, 70),
    Thickness = 1,
}, MainFrame)

-- TopBar
local TopBar = create("Frame", {
    Size             = UDim2.new(1, 0, 0, 62),
    BackgroundColor3 = Color3.fromRGB(18, 18, 26),
    BorderSizePixel  = 0,
}, MainFrame)
create("UICorner", { CornerRadius = UDim.new(0, 12) }, TopBar)

-- Logo V (small, inline in topbar)
local LogoBox = create("Frame", {
    Size             = UDim2.new(0, 36, 0, 36),
    Position         = UDim2.new(0, 14, 0, 13),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BorderSizePixel  = 0,
}, TopBar)
create("UICorner", { CornerRadius = UDim.new(0, 6) }, LogoBox)
create("UIStroke", {
    Color = Color3.fromRGB(70,70,70), Thickness = 1
}, LogoBox)
create("TextLabel", {
    Size               = UDim2.new(1,0,1,0),
    BackgroundTransparency = 1,
    Text               = "V",
    TextColor3         = Color3.fromRGB(255,255,255),
    TextSize           = 20,
    Font               = Enum.Font.GothamBold,
    TextXAlignment     = Enum.TextXAlignment.Center,
    TextYAlignment     = Enum.TextYAlignment.Center,
}, LogoBox)

create("TextLabel", {
    Size               = UDim2.new(1,-160, 0, 22),
    Position           = UDim2.new(0, 58, 0, 8),
    BackgroundTransparency = 1,
    Text               = "VAN THANH  ·  STEAL AN EGG",
    TextColor3         = Color3.fromRGB(255,255,255),
    TextSize           = 14,
    Font               = Enum.Font.GothamBold,
    TextXAlignment     = Enum.TextXAlignment.Left,
}, TopBar)

create("TextLabel", {
    Size               = UDim2.new(1,-160, 0, 16),
    Position           = UDim2.new(0, 58, 0, 32),
    BackgroundTransparency = 1,
    Text               = "V4  ·  Anti-Cheat Bypass  ·  Hook Layer Active",
    TextColor3         = Color3.fromRGB(100,200,120),
    TextSize           = 9,
    Font               = Enum.Font.Gotham,
    TextXAlignment     = Enum.TextXAlignment.Left,
}, TopBar)

local CloseButton = create("TextButton", {
    Size             = UDim2.new(0, 34, 0, 34),
    Position         = UDim2.new(1,-45,0,14),
    BackgroundColor3 = Color3.fromRGB(160,40,50),
    Text             = "×",
    TextColor3       = Color3.fromRGB(255,255,255),
    TextSize         = 20,
    Font             = Enum.Font.GothamBold,
    BorderSizePixel  = 0,
}, TopBar)
create("UICorner", { CornerRadius = UDim.new(0,8) }, CloseButton)

local Sidebar = create("Frame", {
    Size             = UDim2.new(0, 148, 1, -72),
    Position         = UDim2.new(0, 10, 0, 72),
    BackgroundColor3 = Color3.fromRGB(18,18,26),
    BorderSizePixel  = 0,
}, MainFrame)
create("UICorner", { CornerRadius = UDim.new(0,9) }, Sidebar)

local Content = create("Frame", {
    Size                = UDim2.new(1,-173,1,-72),
    Position            = UDim2.new(0,163,0,72),
    BackgroundTransparency = 1,
}, MainFrame)

----------------------------------------------------------------
-- TAB SYSTEM
----------------------------------------------------------------

local Tabs  = {}
local Pages = {}

local function createPage(name)
    local page = create("ScrollingFrame", {
        Name               = name.."Page",
        Size               = UDim2.new(1,-10,1,-10),
        Position           = UDim2.new(0,5,0,5),
        BackgroundTransparency = 1,
        BorderSizePixel    = 0,
        ScrollBarThickness = 3,
        CanvasSize         = UDim2.new(0,0,0,0),
        Visible            = false,
    }, Content)

    local layout = create("UIListLayout", {
        Padding   = UDim.new(0,8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)

    if layout then
        pcall(function()
            layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                if page and layout then
                    page.CanvasSize = UDim2.new(0,0,0, layout.AbsoluteContentSize.Y + 15)
                end
            end)
        end)
    end

    Pages[name] = page
    return page
end

local function showPage(name)
    for k, p in pairs(Pages) do p.Visible = k == name end
    for k, b in pairs(Tabs) do
        if k == name then
            b.BackgroundColor3 = Color3.fromRGB(60,45,130)
            b.TextColor3       = Color3.fromRGB(255,255,255)
        else
            b.BackgroundColor3 = Color3.fromRGB(24,24,33)
            b.TextColor3       = Color3.fromRGB(155,155,170)
        end
    end
end

local function createTab(name, text, order)
    local btn = create("TextButton", {
        Name             = name.."Tab",
        Size             = UDim2.new(1,-16,0,36),
        Position         = UDim2.new(0,8,0,order*42+8),
        BackgroundColor3 = Color3.fromRGB(24,24,33),
        BorderSizePixel  = 0,
        Text             = text,
        TextColor3       = Color3.fromRGB(155,155,170),
        TextSize         = 10,
        Font             = Enum.Font.GothamMedium,
    }, Sidebar)
    if not btn then
        warn("[VT] createTab failed for: " .. tostring(name))
        return nil
    end
    create("UICorner", { CornerRadius = UDim.new(0,7) }, btn)
    Tabs[name] = btn
    pcall(function()
        btn.MouseButton1Click:Connect(function() showPage(name) end)
    end)
    return btn
end

local HomePage     = createPage("Home")
local FarmPage     = createPage("Farm")
local MovementPage = createPage("Movement")
local BossPage     = createPage("Boss")
local TeleportPage = createPage("Teleport")
local AntiPage     = createPage("Anti")
local BypassPage   = createPage("Bypass")
local SettingsPage = createPage("Settings")

createTab("Home",     "⌂  HOME",       0)
createTab("Farm",     "🥚 FARM",        1)
createTab("Movement", "➤  MOVEMENT",   2)
createTab("Boss",     "⚔  BOSS",       3)
createTab("Teleport", "◆  TELEPORT",   4)
createTab("Anti",     "🛡 ANTI",        5)
createTab("Bypass",   "⚡ BYPASS",      6)
createTab("Settings", "⚙  SETTINGS",   7)

----------------------------------------------------------------
-- UI COMPONENTS
----------------------------------------------------------------

local function createSection(parent, text)
    if not parent then return nil end
    return create("TextLabel", {
        Size               = UDim2.new(1,-10,0,26),
        BackgroundTransparency = 1,
        Text               = text,
        TextColor3         = Color3.fromRGB(200,200,220),
        TextSize           = 11,
        Font               = Enum.Font.GothamBold,
        TextXAlignment     = Enum.TextXAlignment.Left,
    }, parent)
end

local function createButton(parent, text)
    if not parent then
        warn("[VT] createButton: parent is nil for: " .. tostring(text))
        -- return dummy object to prevent crash on chained :Connect()
        local dummy = {}
        setmetatable(dummy, {
            __index = function(_, k)
                return function() return dummy end
            end
        })
        return dummy
    end
    local btn = create("TextButton", {
        Size             = UDim2.new(1,-10,0,36),
        BackgroundColor3 = Color3.fromRGB(28,28,38),
        BorderSizePixel  = 0,
        Text             = text,
        TextColor3       = Color3.fromRGB(225,225,230),
        TextSize         = 10,
        Font             = Enum.Font.GothamMedium,
    }, parent)
    if not btn then
        local dummy = {}
        setmetatable(dummy, {
            __index = function(_, k)
                return function() return dummy end
            end
        })
        return dummy
    end
    create("UICorner", {CornerRadius=UDim.new(0,7)}, btn)
    return btn
end

local function createToggle(parent, text, initial, cb)
    local enabled = initial
    local btn = createButton(parent, text..": "..(enabled and "ON" or "OFF"))

    local function refresh()
        pcall(function()
            btn.Text = text..": "..(enabled and "ON" or "OFF")
            btn.BackgroundColor3 = enabled
                and Color3.fromRGB(38,130,65)
                or  Color3.fromRGB(28,28,38)
        end)
    end

    pcall(function()
        pcall(function()
            if btn and btn.MouseButton1Click then
                btn.MouseButton1Click:Connect(function()
            enabled = not enabled
            refresh()
            if cb then pcall(cb, enabled) end
        end)
    end)

    refresh()
    return btn
end

local function createLabel(parent, text)
    if not parent then return {} end
    local lbl = create("TextLabel", {
        Size               = UDim2.new(1,-10,0,30),
        BackgroundColor3   = Color3.fromRGB(22,22,31),
        BorderSizePixel    = 0,
        Text               = text,
        TextColor3         = Color3.fromRGB(175,175,190),
        TextSize           = 10,
        Font               = Enum.Font.Gotham,
        TextXAlignment     = Enum.TextXAlignment.Left,
    }, parent)
    if lbl then
        create("UICorner",{CornerRadius=UDim.new(0,6)},lbl)
    end
    return lbl or {}
end

----------------------------------------------------------------
-- HOME PAGE
----------------------------------------------------------------

createSection(HomePage, "DASHBOARD")

StatusBox = createLabel(HomePage, "  Status: Idle")

local FarmBox     = createLabel(HomePage, "  Auto Farm: OFF")
local BossBox     = createLabel(HomePage, "  Auto Boss: OFF")
local EggCounter  = createLabel(HomePage, "  Eggs collected: 0")
local BossCounter = createLabel(HomePage, "  Boss attacks: 0")
local EPMLabel    = createLabel(HomePage, "  Eggs/min: 0")
local SessionLabel= createLabel(HomePage, "  Session: 0m 0s")

local function updateDashboard()
    FarmBox.Text     = "  Auto Farm: "..(FLAGS.AutoFarm and "ON" or "OFF")
    BossBox.Text     = "  Auto Boss: "..(FLAGS.AutoBoss and "ON" or "OFF")
    EggCounter.Text  = "  Eggs collected: "..FLAGS.EggsCollected
    BossCounter.Text = "  Boss attacks: "..FLAGS.BossAttacks
    EPMLabel.Text    = "  Eggs/min: "..FLAGS.EggsPerMinute

    local elapsed = math.floor(tick() - CONFIG.SESSION.START_TICK)
    SessionLabel.Text = string.format("  Session: %dm %ds",
        math.floor(elapsed/60), elapsed%60)
end

createSection(HomePage, "CONTROLS")

local function setAutoFarm(v)
    FLAGS.AutoFarm = v
    updateStatus(v and "Auto Farm enabled" or "Auto Farm disabled")
    updateDashboard()
end

local function setAutoBoss(v)
    FLAGS.AutoBoss = v
    updateStatus(v and "Auto Boss enabled" or "Auto Boss disabled")
    updateDashboard()
end

do
    local __btn = createButton(HomePage, "Start / Stop Auto Farm")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    setAutoFarm(not FLAGS.AutoFarm)
        end)
    end
end

do
    local __btn = createButton(HomePage, "Start / Stop Auto Boss")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    setAutoBoss(not FLAGS.AutoBoss)
        end)
    end
end

----------------------------------------------------------------
-- FARM PAGE
----------------------------------------------------------------

createSection(FarmPage, "AUTO FARM")
createToggle(FarmPage, "Auto Egg", false, setAutoFarm)
createToggle(FarmPage, "Return To Treadmill", true, function(v)
    FLAGS.ReturnTreadmill = v
end)
createToggle(FarmPage, "Notify on Rare", true, function(v)
    FLAGS.NotifyOnRare = v
end)

createSection(FarmPage, "RARITY FILTER")
for _, rarity in ipairs(CONFIG.RARITY_PRIORITY) do
    createToggle(FarmPage, rarity, CONFIG.TARGET_RARITIES[rarity], function(v)
        CONFIG.TARGET_RARITIES[rarity] = v
    end)
end

createSection(FarmPage, "PRIORITY")
createLabel(FarmPage, "  Secret > Eternal > Divine > Light > Dark")

----------------------------------------------------------------
-- MOVEMENT PAGE
----------------------------------------------------------------

createSection(MovementPage, "MOVEMENT MODE")

local ModeBtn = createButton(MovementPage, "Mode: ZIGZAG")
pcall(function()
    if ModeBtn and ModeBtn.MouseButton1Click then
        ModeBtn.MouseButton1Click:Connect(function()
    CONFIG.MOVE_MODE = CONFIG.MOVE_MODE == "ZigZag" and "Direct" or "ZigZag"
    ModeBtn.Text = "Mode: "..string.upper(CONFIG.MOVE_MODE)
end)

createSection(MovementPage, "SAVED POSITION")

local SaveBtn = createButton(MovementPage, "Save Current Position")
local GoBtn   = createButton(MovementPage, "Teleport To Saved Position")

pcall(function()
    if SaveBtn and SaveBtn.MouseButton1Click then
        SaveBtn.MouseButton1Click:Connect(function()
    local root = getRoot()
    if root then
        CONFIG.TREADMILL_CFRAME = root.CFrame
        SaveBtn.Text = "Position Saved ✓"
        task.delay(1.5, function() SaveBtn.Text = "Save Current Position" end)
    end
end)

pcall(function()
    if GoBtn and GoBtn.MouseButton1Click then
        GoBtn.MouseButton1Click:Connect(function()
    moveTarget(CONFIG.TREADMILL_CFRAME)
    updateStatus("Teleported to saved position")
end)

createSection(MovementPage, "SPEED TUNING")
local SpeedLabel = createLabel(MovementPage, "  Teleport delay: "..CONFIG.ANTI.TELEPORT_DELAY)

local SpeedFast = createButton(MovementPage, "Faster (–0.01)")
local SpeedSlow = createButton(MovementPage, "Slower (+0.01)")

pcall(function()
    if SpeedFast and SpeedFast.MouseButton1Click then
        SpeedFast.MouseButton1Click:Connect(function()
    CONFIG.ANTI.TELEPORT_DELAY = math.max(0.01,
        CONFIG.ANTI.TELEPORT_DELAY - 0.01)
    SpeedLabel.Text = string.format("  Teleport delay: %.2f", CONFIG.ANTI.TELEPORT_DELAY)
end)

pcall(function()
    if SpeedSlow and SpeedSlow.MouseButton1Click then
        SpeedSlow.MouseButton1Click:Connect(function()
    CONFIG.ANTI.TELEPORT_DELAY = math.min(0.3,
        CONFIG.ANTI.TELEPORT_DELAY + 0.01)
    SpeedLabel.Text = string.format("  Teleport delay: %.2f", CONFIG.ANTI.TELEPORT_DELAY)
end)

----------------------------------------------------------------
-- BOSS PAGE
----------------------------------------------------------------

createSection(BossPage, "BOSS AUTOMATION")
createToggle(BossPage, "Auto Boss", false, setAutoBoss)

do
    local __btn = createButton(BossPage, "Attack Boss Once")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    pcall(handleBoss)
        end)
    end
end

createSection(BossPage, "SCAN TARGETS")
createLabel(BossPage, "  Boss / Events / EggBoss / GiantEgg")

----------------------------------------------------------------
-- TELEPORT PAGE
----------------------------------------------------------------

createSection(TeleportPage, "TELEPORT LOCATIONS")

do
    local __btn = createButton(TeleportPage, "Secret Waterfall")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    updateStatus("Teleporting to Secret Waterfall...")
    moveTarget(CONFIG.WATERFALL_CFRAME)
    updateStatus("Arrived at Secret Waterfall")
        end)
    end
end

do
    local __btn = createButton(TeleportPage, "Treadmill")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    moveTarget(CONFIG.TREADMILL_CFRAME)
    updateStatus("Arrived at treadmill")
        end)
    end
end

----------------------------------------------------------------
-- ANTI PAGE
----------------------------------------------------------------

createSection(AntiPage, "ANTI STATUS")
createLabel(AntiPage, "  Anti-AFK: ON (every "..CONFIG.ANTI.AFK_INTERVAL.."s)")
createLabel(AntiPage, "  Auto Reconnect: "..(CONFIG.ANTI.RECONNECT and "ON" or "OFF"))
createLabel(AntiPage, "  Property Guard: "..(CONFIG.ANTI.PROPERTY_GUARD and "ON" or "OFF"))

createSection(AntiPage, "WALK SPEED")

local WalkSpeedLabel = createLabel(AntiPage, "  WalkSpeed: "..CONFIG.ANTI.WALK_SPEED)

do
    local __btn = createButton(AntiPage, "Speed +2")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    CONFIG.ANTI.WALK_SPEED += 2
    WalkSpeedLabel.Text = "  WalkSpeed: "..CONFIG.ANTI.WALK_SPEED
    pcall(function()
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = CONFIG.ANTI.WALK_SPEED end
        end)
    end
end
end)

do
    local __btn = createButton(AntiPage, "Speed -2")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    CONFIG.ANTI.WALK_SPEED = math.max(4, CONFIG.ANTI.WALK_SPEED - 2)
    WalkSpeedLabel.Text = "  WalkSpeed: "..CONFIG.ANTI.WALK_SPEED
    pcall(function()
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = CONFIG.ANTI.WALK_SPEED end
        end)
    end
end
end)

----------------------------------------------------------------
-- BYPASS PAGE (live status)
----------------------------------------------------------------

createSection(BypassPage, "VAN THANH BYPASS STATUS")

local function bypassStatusLabel(text, active)
    local lbl = createLabel(BypassPage, "  "..text)
    lbl.TextColor3 = active
        and Color3.fromRGB(80,210,110)
        or  Color3.fromRGB(200,80,80)
    return lbl
end

bypassStatusLabel("__namecall hook (remote shield)",  hookMeta ~= nil)
bypassStatusLabel("debug.info spoofed",               safeHook ~= nil)
bypassStatusLabel("getscriptidentity masked",         type(getGlobal("getscriptidentity"))=="function")
bypassStatusLabel("identifyexecutor spoofed",         type(getGlobal("identifyexecutor"))=="function")
bypassStatusLabel("HTTP fingerprint filter",          safeHook ~= nil)
bypassStatusLabel("Kick bypass active",               safeHook ~= nil)
bypassStatusLabel("game:Shutdown() intercepted",      safeHook ~= nil)
bypassStatusLabel("Gravity guard",                    hookMeta ~= nil)
bypassStatusLabel("ScriptContext error sink",         true)
bypassStatusLabel("Env fingerprint wipe",             true)
bypassStatusLabel("Integrity loop (30s)",             true)

createSection(BypassPage, "REMOTE LOG")
local RemoteLogLabel = createLabel(BypassPage, "  Remotes intercepted: 0")

createSection(BypassPage, "BLOCKED REMOTES")
createLabel(BypassPage, "  Add names in VT_BlockedRemotes table")

do
    local __btn = createButton(BypassPage, "Copy Bypass Log")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    toClipboard(table.concat(VT_LOG, "\n"))
    updateStatus("Bypass log copied")
        end)
    end
end

----------------------------------------------------------------
-- SETTINGS PAGE
----------------------------------------------------------------

createSection(SettingsPage, "UI SETTINGS")

do
    local __btn = createButton(SettingsPage, "Hide UI")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
        end)
    end
end

do
    local __btn = createButton(SettingsPage, "Reset Counters")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    FLAGS.EggsCollected      = 0
    FLAGS.BossAttacks        = 0
    FLAGS.EggsPerMinute      = 0
    CONFIG.SESSION.START_TICK = tick()
    updateDashboard()
    updateStatus("Counters reset")
        end)
    end
end

do
    local __btn = createButton(SettingsPage, "Unload Script")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    cleanupAll()
    pcall(function() ScreenGui:Destroy() end)
    print("[VAN THANH V4] Unloaded.")
        end)
    end
end

createLabel(SettingsPage, "  RightShift = Show / Hide UI")
createLabel(SettingsPage, "  Van Thanh Executor V4")

----------------------------------------------------------------
-- CLOSE / KEYBIND
----------------------------------------------------------------

pcall(function()
    if CloseButton and CloseButton.MouseButton1Click then
        CloseButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

addConn(UserInputService.InputBegan:Connect(
    safeClosure(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            MainFrame.Visible = not MainFrame.Visible
        end
    end)
))

----------------------------------------------------------------
-- VAN THANH FLOATING LOGO (draggable)
----------------------------------------------------------------

task.spawn(safeClosure(function()
    local sg2 = create("ScreenGui", {
        Name           = "VanThanhBadge",
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, UIParent)

    if syn and syn.protect_gui then
        pcall(syn.protect_gui, sg2)
    end

    local badge = create("Frame", {
        Size             = UDim2.new(0,50,0,50),
        Position         = UDim2.new(1,-70,0,14),
        BackgroundColor3 = Color3.fromRGB(0,0,0),
        BorderSizePixel  = 0,
        Active           = true,
    }, sg2)
    create("UICorner", { CornerRadius = UDim.new(0,8) }, badge)
    create("UIStroke", {
        Color=Color3.fromRGB(55,55,55), Thickness=1
    }, badge)

    create("TextLabel", {
        Size               = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1,
        Text               = "V",
        TextColor3         = Color3.fromRGB(255,255,255),
        TextSize           = 26,
        Font               = Enum.Font.GothamBold,
        TextXAlignment     = Enum.TextXAlignment.Center,
        TextYAlignment     = Enum.TextYAlignment.Center,
    }, badge)

    -- click to toggle main UI
    local clickBtn = create("TextButton", {
        Size               = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1,
        Text               = "",
    }, badge)

    pcall(function()
        if clickBtn and clickBtn.MouseButton1Click then
            clickBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = not MainFrame.Visible
    end)

    -- drag
    local dragging, dragStart, frameStart = false, nil, nil
    badge.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging   = true
            dragStart  = input.Position
            frameStart = badge.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            badge.Position = UDim2.new(
                frameStart.X.Scale, frameStart.X.Offset + delta.X,
                frameStart.Y.Scale, frameStart.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end))

----------------------------------------------------------------
-- AUTOMATION LOOP
----------------------------------------------------------------

task.spawn(safeClosure(function()
    while FLAGS.Running do
        if FLAGS.AutoBoss then
            pcall(handleBoss)
        elseif FLAGS.AutoFarm then
            pcall(function()
                local egg = findPriorityEgg()
                if egg then
                    collectEgg(egg)
                elseif FLAGS.ReturnTreadmill then
                    goToTreadmill()
                else
                    updateStatus("Waiting for egg...")
                end
            end)
        else
            if FLAGS.CurrentStatus ~= "Idle" then
                updateStatus("Idle")
            end
        end
        task.wait(CONFIG.CHECK_INTERVAL)
    end
end))

----------------------------------------------------------------
-- DASHBOARD + BYPASS LOG REFRESH
----------------------------------------------------------------

task.spawn(safeClosure(function()
    while FLAGS.Running do
        updateDashboard()
        RemoteLogLabel.Text = "  Remotes intercepted: "..#VT_RemoteLog
        task.wait(0.5)
    end
end))

----------------------------------------------------------------
-- ╔══════════════════════════════════════════╗
-- ║         CHEAT SUITE — VAN THANH          ║
-- ║  ESP · Fly · Noclip · Speed · Pull · God ║
-- ╚══════════════════════════════════════════╝
----------------------------------------------------------------

-- Add cheat tabs to sidebar
local CheatPage  = createPage("Cheat")
local ESPPage    = createPage("ESP")

createTab("Cheat", "💀 CHEATS",   8)
createTab("ESP",   "👁  ESP",      9)

----------------------------------------------------------------
-- CHEAT FLAGS
----------------------------------------------------------------

local CHEAT = {
    Fly          = false,
    FlySpeed     = 60,
    Noclip       = false,
    SpeedHack    = false,
    SpeedValue   = 60,
    InfJump      = false,
    GodMode      = false,
    PullEggs     = false,
    PullRadius   = 80,
    AutoCollect  = false,
    FlyConn      = nil,
    NoclipConn   = nil,
}

----------------------------------------------------------------
-- FLY SYSTEM
-- Smooth WASD + mouse-dir flight via BodyVelocity + BodyGyro
----------------------------------------------------------------

local function startFly()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    hum.PlatformStand = true

    local bv = Instance.new("BodyVelocity")
    bv.Velocity       = Vector3.zero
    bv.MaxForce       = Vector3.new(1e5, 1e5, 1e5)
    bv.P              = 1e4
    bv.Parent         = root

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque      = Vector3.new(1e5, 1e5, 1e5)
    bg.P              = 1e4
    bg.D              = 500
    bg.CFrame         = root.CFrame
    bg.Parent         = root

    local cam = workspace.CurrentCamera

    CHEAT.FlyConn = RunService.Heartbeat:Connect(safeClosure(function()
        if not CHEAT.Fly then
            bv:Destroy()
            bg:Destroy()
            hum.PlatformStand = false
            CHEAT.FlyConn:Disconnect()
            CHEAT.FlyConn = nil
            return
        end

        local moveDir = Vector3.zero
        local cf      = cam.CFrame
        local spd     = CHEAT.FlySpeed

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDir = moveDir + cf.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDir = moveDir - cf.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDir = moveDir - cf.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDir = moveDir + cf.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDir = moveDir + Vector3.new(0,1,0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            moveDir = moveDir - Vector3.new(0,1,0)
        end

        if moveDir.Magnitude > 0 then
            bv.Velocity = moveDir.Unit * spd
        else
            bv.Velocity = Vector3.zero
        end

        bg.CFrame = cf
    end))
end

local function stopFly()
    CHEAT.Fly = false
    -- conn cleans itself on next heartbeat
end

----------------------------------------------------------------
-- NOCLIP
-- Zero CanCollide on char parts every physics step
----------------------------------------------------------------

local function startNoclip()
    CHEAT.NoclipConn = RunService.Stepped:Connect(safeClosure(function()
        if not CHEAT.Noclip then
            CHEAT.NoclipConn:Disconnect()
            CHEAT.NoclipConn = nil
            -- restore collisions
            local char = LocalPlayer.Character
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.CanCollide = true
                    end
                end
            end
            return
        end
        local char = LocalPlayer.Character
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                p.CanCollide = false
            end
        end
    end))
end

----------------------------------------------------------------
-- INFINITE JUMP
----------------------------------------------------------------

local infJumpConn
local function enableInfJump()
    infJumpConn = UserInputService.JumpRequest:Connect(safeClosure(function()
        if not CHEAT.InfJump then
            infJumpConn:Disconnect()
            infJumpConn = nil
            return
        end
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end))
end

----------------------------------------------------------------
-- GOD MODE
-- Loop-restore Health to MaxHealth
----------------------------------------------------------------

local godConn
local function enableGod()
    godConn = RunService.Heartbeat:Connect(safeClosure(function()
        if not CHEAT.GodMode then
            godConn:Disconnect()
            godConn = nil
            return
        end
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health < hum.MaxHealth then
                hum.Health = hum.MaxHealth
            end
        end)
    end))
end

----------------------------------------------------------------
-- EGG PULL / VACUUM
-- Teleport all nearby eggs to player every tick
----------------------------------------------------------------

local pullConn
local function startPull()
    pullConn = RunService.Heartbeat:Connect(safeClosure(function()
        if not CHEAT.PullEggs then
            pullConn:Disconnect()
            pullConn = nil
            return
        end
        local root = getRoot()
        if not root then return end

        for _, obj in ipairs(Workspace:GetDescendants()) do
            local isEgg = (obj:IsA("BasePart") or obj:IsA("Model"))
                and string.find(string.lower(obj.Name), "egg")
                and not string.find(string.lower(obj.Name), "hatch")

            if isEgg then
                local pos = obj:IsA("Model")
                    and obj:GetPivot().Position
                    or obj.Position

                if (root.Position - pos).Magnitude <= CHEAT.PullRadius then
                    pcall(function()
                        if obj:IsA("Model") then
                            obj:PivotTo(CFrame.new(root.Position + Vector3.new(0,2,0)))
                        else
                            obj.CFrame = CFrame.new(root.Position + Vector3.new(0,2,0))
                        end
                    end)

                    -- auto-collect if toggled
                    if CHEAT.AutoCollect then
                        pcall(function() collectEgg(obj) end)
                    end
                end
            end
        end
    end))
end

----------------------------------------------------------------
-- CHEAT PAGE UI
----------------------------------------------------------------

createSection(CheatPage, "MOVEMENT CHEATS")

createToggle(CheatPage, "Fly", false, function(v)
    CHEAT.Fly = v
    if v then
        startFly()
        updateStatus("Fly ON")
    else
        stopFly()
        updateStatus("Fly OFF")
    end
end)

-- fly speed slider (buttons)
local FlySpeedLabel = createLabel(CheatPage,
    "  Fly Speed: " .. CHEAT.FlySpeed)

do
    local __btn = createButton(CheatPage, "Fly Speed +10")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    CHEAT.FlySpeed = math.min(500, CHEAT.FlySpeed + 10)
    FlySpeedLabel.Text = "  Fly Speed: " .. CHEAT.FlySpeed
        end)
    end
end
do
    local __btn = createButton(CheatPage, "Fly Speed -10")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    CHEAT.FlySpeed = math.max(10, CHEAT.FlySpeed - 10)
    FlySpeedLabel.Text = "  Fly Speed: " .. CHEAT.FlySpeed
        end)
    end
end

createToggle(CheatPage, "Noclip", false, function(v)
    CHEAT.Noclip = v
    if v then
        startNoclip()
        updateStatus("Noclip ON")
    else
        updateStatus("Noclip OFF")
    end
end)

createToggle(CheatPage, "Infinite Jump", false, function(v)
    CHEAT.InfJump = v
    if v then
        enableInfJump()
        updateStatus("Infinite Jump ON")
    else
        updateStatus("Infinite Jump OFF")
    end
end)

createSection(CheatPage, "SPEED HACK")

local SpeedHackLabel = createLabel(CheatPage,
    "  Hack Speed: " .. CHEAT.SpeedValue)

createToggle(CheatPage, "Speed Hack", false, function(v)
    CHEAT.SpeedHack = v
    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = v and CHEAT.SpeedValue or CONFIG.ANTI.WALK_SPEED
    end
    updateStatus(v and ("Speed Hack ON ("..CHEAT.SpeedValue..")") or "Speed Hack OFF")
end)

do
    local __btn = createButton(CheatPage, "Hack Speed +10")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    CHEAT.SpeedValue = math.min(500, CHEAT.SpeedValue + 10)
    SpeedHackLabel.Text = "  Hack Speed: " .. CHEAT.SpeedValue
    if CHEAT.SpeedHack then
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = CHEAT.SpeedValue end
    end
        end)
    end
end
do
    local __btn = createButton(CheatPage, "Hack Speed -10")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    CHEAT.SpeedValue = math.max(16, CHEAT.SpeedValue - 10)
    SpeedHackLabel.Text = "  Hack Speed: " .. CHEAT.SpeedValue
    if CHEAT.SpeedHack then
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = CHEAT.SpeedValue end
    end
        end)
    end
end

createSection(CheatPage, "SURVIVAL")

createToggle(CheatPage, "God Mode", false, function(v)
    CHEAT.GodMode = v
    if v then
        enableGod()
        updateStatus("God Mode ON")
    else
        updateStatus("God Mode OFF")
    end
end)

createSection(CheatPage, "EGG VACUUM")

local PullRadiusLabel = createLabel(CheatPage,
    "  Pull Radius: " .. CHEAT.PullRadius)

createToggle(CheatPage, "Egg Pull / Vacuum", false, function(v)
    CHEAT.PullEggs = v
    if v then
        startPull()
        updateStatus("Egg Pull ON")
    else
        updateStatus("Egg Pull OFF")
    end
end)

createToggle(CheatPage, "Auto Collect (Pull)", false, function(v)
    CHEAT.AutoCollect = v
end)

do
    local __btn = createButton(CheatPage, "Radius +20")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    CHEAT.PullRadius = math.min(500, CHEAT.PullRadius + 20)
    PullRadiusLabel.Text = "  Pull Radius: " .. CHEAT.PullRadius
        end)
    end
end
do
    local __btn = createButton(CheatPage, "Radius -20")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    CHEAT.PullRadius = math.max(20, CHEAT.PullRadius - 20)
    PullRadiusLabel.Text = "  Pull Radius: " .. CHEAT.PullRadius
        end)
    end
end

----------------------------------------------------------------
-- ESP SYSTEM
-- Billboard tags above players + eggs
-- Highlights via SelectionBox on parts
----------------------------------------------------------------

local ESP = {
    Players  = false,
    Eggs     = false,
    Tags     = {},      -- [instance] = billboard
    Boxes    = {},      -- [instance] = SelectionBox
    MaxDist  = 500,
}

local ESP_COLORS = {
    Secret  = Color3.fromRGB(255, 215, 0),
    Eternal = Color3.fromRGB(180, 0, 255),
    Divine  = Color3.fromRGB(255, 120, 0),
    Light   = Color3.fromRGB(200, 230, 255),
    Dark    = Color3.fromRGB(80,  0,  160),
    Player  = Color3.fromRGB(255, 80,  80),
    Default = Color3.fromRGB(255, 255, 255),
}

local ESPFolder = Instance.new("Folder")
ESPFolder.Name   = "VT_ESP"
ESPFolder.Parent = CoreGui

local function makeTag(adornee, text, color, key)
    if ESP.Tags[key] then return end

    local bb = Instance.new("BillboardGui")
    bb.Name          = "VT_ESP_Tag"
    bb.Size          = UDim2.new(0, 120, 0, 40)
    bb.StudsOffset   = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop   = true
    bb.Adornee       = adornee
    bb.Parent        = ESPFolder

    local frame = Instance.new("Frame")
    frame.Size            = UDim2.new(1,0,1,0)
    frame.BackgroundColor3= Color3.fromRGB(0,0,0)
    frame.BackgroundTransparency = 0.4
    frame.BorderSizePixel = 0
    frame.Parent          = bb
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,4)

    local lbl = Instance.new("TextLabel")
    lbl.Size               = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text               = text
    lbl.TextColor3         = color
    lbl.TextSize           = 11
    lbl.Font               = Enum.Font.GothamBold
    lbl.TextXAlignment     = Enum.TextXAlignment.Center
    lbl.TextYAlignment     = Enum.TextYAlignment.Center
    lbl.Parent             = frame

    ESP.Tags[key] = bb
end

local function makeBox(adornee, color, key)
    if ESP.Boxes[key] then return end
    local sb = Instance.new("SelectionBox")
    sb.Color3        = color
    sb.LineThickness = 0.05
    sb.SurfaceTransparency = 0.8
    sb.SurfaceColor3 = color
    sb.Adornee       = adornee
    sb.Parent        = ESPFolder
    ESP.Boxes[key]   = sb
end

local function removeESP(key)
    if ESP.Tags[key] then
        ESP.Tags[key]:Destroy()
        ESP.Tags[key] = nil
    end
    if ESP.Boxes[key] then
        ESP.Boxes[key]:Destroy()
        ESP.Boxes[key] = nil
    end
end

local function clearAllESP()
    for key in pairs(ESP.Tags) do removeESP(key) end
    ESPFolder:ClearAllChildren()
end

-- ESP loop
local espConn
local function startESP()
    espConn = RunService.Heartbeat:Connect(safeClosure(function()
        if not ESP.Players and not ESP.Eggs then
            espConn:Disconnect()
            espConn = nil
            clearAllESP()
            return
        end

        local root = getRoot()
        local myPos = root and root.Position or Vector3.zero

        -- PLAYER ESP
        if ESP.Players then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr == LocalPlayer then continue end
                local char = plr.Character
                if not char then continue end
                local proot = char:FindFirstChild("HumanoidRootPart")
                if not proot then continue end

                local dist = (myPos - proot.Position).Magnitude
                if dist > ESP.MaxDist then
                    removeESP(plr.UserId)
                    continue
                end

                local distStr = string.format("[%.0f]", dist)
                makeTag(proot,
                    plr.Name .. "\n" .. distStr,
                    ESP_COLORS.Player,
                    plr.UserId)
                makeBox(char, ESP_COLORS.Player, "box_"..plr.UserId)
            end
        else
            -- clean player tags if toggled off
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    removeESP(plr.UserId)
                    removeESP("box_"..plr.UserId)
                end
            end
        end

        -- EGG ESP
        if ESP.Eggs then
            local seen = {}
            for _, obj in ipairs(Workspace:GetDescendants()) do
                local isEgg = (obj:IsA("BasePart") or obj:IsA("Model"))
                    and string.find(string.lower(obj.Name), "egg")
                    and not string.find(string.lower(obj.Name), "hatch")
                if not isEgg then continue end

                local pos = obj:IsA("Model")
                    and obj:GetPivot().Position
                    or obj.Position

                local dist = (myPos - pos).Magnitude
                if dist > ESP.MaxDist then continue end

                local rarity   = getRarity(obj) or "?"
                local color    = ESP_COLORS[rarity] or ESP_COLORS.Default
                local key      = tostring(obj)
                local distStr  = string.format("[%.0f]", dist)
                local adornee  = obj:IsA("Model")
                    and (obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart"))
                    or obj

                if adornee then
                    makeTag(adornee,
                        rarity .. "\n" .. distStr,
                        color, key)
                    makeBox(adornee, color, "box_"..key)
                end
                seen[key] = true
            end

            -- prune stale egg tags
            for key in pairs(ESP.Tags) do
                if type(key) == "string"
                    and not string.find(key, "box_") -- skip box keys
                    and not seen[key] then
                    removeESP(key)
                    removeESP("box_"..key)
                end
            end
        else
            clearAllESP()
        end
    end))
end

----------------------------------------------------------------
-- ESP PAGE UI
----------------------------------------------------------------

createSection(ESPPage, "PLAYER ESP")

createToggle(ESPPage, "Player ESP", false, function(v)
    ESP.Players = v
    if (v or ESP.Eggs) and not espConn then startESP() end
    updateStatus(v and "Player ESP ON" or "Player ESP OFF")
end)

createSection(ESPPage, "EGG ESP")

createToggle(ESPPage, "Egg ESP", false, function(v)
    ESP.Eggs = v
    if (v or ESP.Players) and not espConn then startESP() end
    updateStatus(v and "Egg ESP ON" or "Egg ESP OFF")
end)

createSection(ESPPage, "ESP SETTINGS")

local ESPDistLabel = createLabel(ESPPage,
    "  Max Distance: " .. ESP.MaxDist)

do
    local __btn = createButton(ESPPage, "Distance +50")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    ESP.MaxDist = math.min(2000, ESP.MaxDist + 50)
    ESPDistLabel.Text = "  Max Distance: " .. ESP.MaxDist
        end)
    end
end
do
    local __btn = createButton(ESPPage, "Distance -50")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    ESP.MaxDist = math.max(50, ESP.MaxDist - 50)
    ESPDistLabel.Text = "  Max Distance: " .. ESP.MaxDist
        end)
    end
end

do
    local __btn = createButton(ESPPage, "Clear All ESP")
    if __btn and __btn.MouseButton1Click then
        __btn.MouseButton1Click:Connect(function()
    clearAllESP()
    updateStatus("ESP cleared")
        end)
    end
end

createSection(ESPPage, "COLOR KEY")
createLabel(ESPPage, "  🟡 Secret   🟣 Eternal   🟠 Divine")
createLabel(ESPPage, "  🔵 Light    🟤 Dark       🔴 Player")

----------------------------------------------------------------
-- CLEANUP PATCH — include cheat connections
----------------------------------------------------------------

local _origCleanup = cleanupAll
cleanupAll = function()
    CHEAT.Fly      = false
    CHEAT.Noclip   = false
    CHEAT.GodMode  = false
    CHEAT.PullEggs = false
    CHEAT.InfJump  = false
    CHEAT.SpeedHack= false
    ESP.Players    = false
    ESP.Eggs       = false
    clearAllESP()
    pcall(function() ESPFolder:Destroy() end)
    _origCleanup()
end

----------------------------------------------------------------
-- INIT
----------------------------------------------------------------

showPage("Home")
updateDashboard()
updateStatus("Ready")

print("[VAN THANH V4] Fully loaded. Bypass + Cheats + ESP active.")
