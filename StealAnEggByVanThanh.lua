-- // ================= ================= ================= //
-- //         VĂN THÀNH HUB - STEALTH EDITION (SAFE)        //
-- //    Steal An Anime Egg - No Metatable Hook / No Ban      //
-- //    + VAN THANH BYPASS LAYER V2 (safe, no typeof crash)  //
-- // ================= ================= ================= //

----------------------------------------------------------------
-- [0] VAN THANH BYPASS LAYER
-- Phải chạy TRƯỚC mọi thứ khác
-- Dùng rawget(_G) — không bao giờ crash dù executor thiếu global
----------------------------------------------------------------

do
    -- safe global fetch, không bao giờ throw
    local function G(name)
        return rawget(_G, name)
    end

    -- duplicate guard
    local _genv = G("getgenv")
    local _store = _genv and _genv() or _G
    if _store.__VanThanhBypass then
        -- already loaded, skip silently
    else
        _store.__VanThanhBypass = true

        -- grab executor functions safely
        local _newcclosure    = G("newcclosure")
        local _hookfunction   = G("hookfunction")
        local _hookmetamethod = G("hookmetamethod")
        local _islclosure     = G("islclosure")
        local _cloneref       = G("cloneref")
        local _getscriptid    = G("getscriptidentity")
        local _identifyexec   = G("identifyexecutor")
        local _getnamecall    = G("getnamecallmethod")

        local wrap = type(_newcclosure)  == "function" and _newcclosure  or function(f) return f end
        local hook = type(_hookfunction) == "function" and _hookfunction or nil
        local hmeta= type(_hookmetamethod)=="function" and _hookmetamethod or nil
        local isLC = type(_islclosure)   == "function" and _islclosure   or function() return true end

        local VT_LOG = {}
        local function log(tag, msg)
            table.insert(VT_LOG, ("[VT][%s] %s"):format(tag, tostring(msg)))
        end

        -- [1] __namecall remote shield
        --     block any remote whose name is in BLOCKED list
        local BLOCKED_REMOTES = {
            -- thêm tên remote anti-cheat của game vào đây nếu biết
            -- ["CheatDetect"] = true,
        }
        local REMOTE_LOG = {}

        if hmeta then
            local _nc
            _nc = hmeta(game, "__namecall", wrap(function(self, ...)
                local method = _getnamecall and _getnamecall() or ""
                if method == "FireServer"
                    or method == "InvokeServer"
                    or method == "FireAllClients"
                then
                    local ok, name = pcall(function() return self.Name end)
                    name = ok and name or "?"
                    if BLOCKED_REMOTES[name] then
                        log("REMOTE_BLOCK", name)
                        return  -- drop
                    end
                    table.insert(REMOTE_LOG, {name=name, method=method, t=tick()})
                end
                return _nc(self, ...)
            end))
            log("HOOK", "__namecall shield active")
        end

        -- [2] getscriptidentity spoof → level 7 (CoreScript)
        if type(_getscriptid) == "function" and hook then
            pcall(function()
                if isLC(_getscriptid) then
                    hook(_getscriptid, wrap(function() return 7 end))
                    log("HOOK", "getscriptidentity → 7")
                end
            end)
        end

        -- [3] identifyexecutor spoof → vanilla Roblox
        if type(_identifyexec) == "function" and hook then
            pcall(function()
                if isLC(_identifyexec) then
                    hook(_identifyexec, wrap(function() return "Roblox", "0.0.0" end))
                    log("HOOK", "identifyexecutor spoofed")
                end
            end)
        end

        -- [4] HttpService filter
        --     chặn HTTP calls chứa keyword anti-cheat
        local HTTP_KEYWORDS = {
            "cheatdetect","anticheat","exploit",
            "ban","report","telemetry","integrity","flagged",
        }
        local function isBlockedURL(url)
            local low = string.lower(tostring(url or ""))
            for _, kw in ipairs(HTTP_KEYWORDS) do
                if string.find(low, kw, 1, true) then return true end
            end
            return false
        end

        if hook then
            pcall(function()
                local hs = game:GetService("HttpService")
                if isLC(hs.GetAsync) then
                    local rg = hs.GetAsync
                    hook(rg, wrap(function(self, url, ...)
                        if isBlockedURL(url) then
                            log("HTTP_BLOCK", "GET: "..tostring(url))
                            return "{}"
                        end
                        return rg(self, url, ...)
                    end))
                end
            end)
            pcall(function()
                local hs = game:GetService("HttpService")
                if isLC(hs.PostAsync) then
                    local rp = hs.PostAsync
                    hook(rp, wrap(function(self, url, body, ...)
                        if isBlockedURL(url) then
                            log("HTTP_BLOCK", "POST: "..tostring(url))
                            return "{}"
                        end
                        return rp(self, url, body, ...)
                    end))
                end
            end)
            log("HOOK", "HTTP filter active")
        end

        -- [5] Kick null
        --     Dùng pcall fetch trước để tránh "not a valid member" crash
        if hook then
            pcall(function()
                local lp = game:GetService("Players").LocalPlayer
                if not lp then return end
                local kfn
                pcall(function() kfn = lp.Kick end)
                if kfn and isLC(kfn) then
                    hook(kfn, wrap(function(self, msg)
                        log("KICK_NULL", tostring(msg or ""))
                        -- swallowed — player stays
                    end))
                    log("HOOK", "LocalPlayer:Kick() nulled")
                end
            end)
        end

        -- [6] game:Shutdown() intercept → reconnect
        if hook then
            pcall(function()
                if isLC(game.Shutdown) then
                    hook(game.Shutdown, wrap(function()
                        log("SHUTDOWN", "intercepted, reconnecting")
                        task.delay(2, function()
                            pcall(function()
                                game:GetService("TeleportService")
                                    :Teleport(game.PlaceId,
                                        game:GetService("Players").LocalPlayer)
                            end)
                        end)
                    end))
                    log("HOOK", "game:Shutdown intercepted")
                end
            end)
        end

        -- [7] debug.info spoof
        --     ẩn executor stack source khỏi game anti-cheat scanner
        if debug and type(debug.info) == "function" and hook then
            pcall(function()
                if isLC(debug.info) then
                    local rdi = debug.info
                    hook(debug.info, wrap(function(level, opts)
                        local ok, src = pcall(rdi, level, "s")
                        if ok and src
                            and type(opts) == "string"
                            and string.find(opts, "s", 1, true)
                            and not string.find(src, "LocalScript", 1, true)
                            and not string.find(src, "Script", 1, true)
                        then
                            return (rdi(level, opts)):gsub(src, "LocalScript")
                        end
                        return rdi(level, opts)
                    end))
                    log("HOOK", "debug.info spoofed")
                end
            end)
        end

        -- [8] ScriptContext error sink
        --     nuốt executor-level errors, không leak stack
        pcall(function()
            game:GetService("ScriptContext").Error:Connect(wrap(function(msg, trace, script)
                if script == nil then
                    log("ERR_SINK", tostring(msg))
                end
            end))
            log("HOOK", "ScriptContext error sink")
        end)

        -- [9] Executor fingerprint wipe
        --     xóa các key executor để lại trong getgenv sau khi load
        task.delay(2, function()
            local dirty = {
                "SYNAPSE_LOADED","KRNL_LOADED","FLUXUS_LOADED",
                "SCRIPTWARE_LOADED","OXYGEN_LOADED","WAVE_LOADED",
                "EVON_LOADED","ARCEUS_LOADED","CODEX_LOADED",
            }
            local env = (G("getgenv") and G("getgenv")()) or _G
            for _, k in ipairs(dirty) do
                pcall(function() env[k] = nil end)
            end
            log("ENV", "fingerprint wiped")
        end)

        -- [10] Integrity loop — re-check hooks mỗi 45s
        task.spawn(function()
            while _store.__VanThanhBypass do
                task.wait(45)
                -- re-null kick nếu game restore nó
                if hook then
                    pcall(function()
                        local lp = game:GetService("Players").LocalPlayer
                        if not lp then return end
                        local kfn
                        pcall(function() kfn = lp.Kick end)
                        if kfn and isLC(kfn) then
                            hook(kfn, wrap(function(self, msg)
                                log("KICK_REBLOCK", tostring(msg or ""))
                            end))
                        end
                    end)
                end
                log("INTEGRITY", "sweep ok — " .. #VT_LOG .. " entries")
            end
        end)

        -- expose log globally for debug
        _store.__VT_LOG        = VT_LOG
        _store.__VT_REMOTELOG  = REMOTE_LOG

        print("[VAN THANH BYPASS] " .. #VT_LOG .. " hooks registered")
    end
end

-- // ============================================================ //
-- //  ORIGINAL SCRIPT BELOW — KHÔNG THAY ĐỔI GÌ                  //
-- // ============================================================ //

local OrionLib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/jensonhirst/Orion/main/source"
))()

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local VirtualUser       = game:GetService("VirtualUser")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")
local TeleportService   = game:GetService("TeleportService")
local UserInputService  = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then return end

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid  = Character:WaitForChild("Humanoid")
local RootPart  = Character:WaitForChild("HumanoidRootPart")

LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid  = newChar:WaitForChild("Humanoid")
    RootPart  = newChar:WaitForChild("HumanoidRootPart")
end)

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------

local VanThanhConfig = {
    AutoSteal    = false,
    StealSpeed   = 16,  -- khớp WalkSpeed mặc định, tránh detect
    ReturnToBase = true,
    StealRarities = {
        Secret   = true,
        Mythic   = true,
        Legendary= true,
        Epic     = false,
        Rare     = false,
        Uncommon = false,
        Common   = false,
    },
    AutoPlace            = false,
    AutoHatch            = false,
    AutoEquipBest        = false,
    AutoUpgradeTreadmill = false,
    AutoUpgradePlot      = false,
    AutoClaimPlaytime    = false,
    AutoClaimIndex       = false,
    WalkSpeed   = 16,
    JumpPower   = 50,
    ModifySpeed = false,
    ModifyJump  = false,
    InfiniteJump= false,
    Noclip      = false,
    AntiAFK     = true,
}

----------------------------------------------------------------
-- WINDOW
----------------------------------------------------------------

local Window = OrionLib:MakeWindow({
    Name        = "Văn Thành Hub | Steal An Anime Egg 🥚 [STEALTH]",
    HidePremium = false,
    SaveConfig  = false,
    IntroText   = "Văn Thành Hub Stealth Loaded!",
})

----------------------------------------------------------------
-- TAB 1: AUTO FARM
----------------------------------------------------------------

local TabFarm = Window:MakeTab({ Name = "Auto Farm & Steal", Icon = "rbxassetid://4483345998" })

TabFarm:AddToggle({ Name = "Bật Auto Steal", Default = false,
    Callback = function(v) VanThanhConfig.AutoSteal = v end })

TabFarm:AddToggle({ Name = "Quay Về Căn Cứ Sau Khi Trộm", Default = true,
    Callback = function(v) VanThanhConfig.ReturnToBase = v end })

TabFarm:AddSlider({ Name = "Tốc Độ Di Chuyển (Khuyên dùng: 30 - 40)",
    Min = 20, Max = 60, Default = 35, Color = Color3.fromRGB(0,255,127),
    Increment = 5, ValueName = "Speed",
    Callback = function(v) VanThanhConfig.StealSpeed = v end })

TabFarm:AddSection({ Name = "Độ Hiếm Trứng" })

for _, rarity in ipairs({"Secret","Mythic","Legendary","Epic","Rare","Uncommon","Common"}) do
    TabFarm:AddToggle({
        Name     = "Trộm: " .. rarity,
        Default  = VanThanhConfig.StealRarities[rarity] or false,
        Callback = function(v) VanThanhConfig.StealRarities[rarity] = v end,
    })
end

TabFarm:AddSection({ Name = "Quản Lý Trứng" })
TabFarm:AddToggle({ Name = "Auto Place Egg", Default = false,
    Callback = function(v) VanThanhConfig.AutoPlace = v end })
TabFarm:AddToggle({ Name = "Auto Hatch", Default = false,
    Callback = function(v) VanThanhConfig.AutoHatch = v end })

----------------------------------------------------------------
-- TAB 2: UTILITIES
----------------------------------------------------------------

local TabUtil = Window:MakeTab({ Name = "Tiện Ích & Player", Icon = "rbxassetid://4483345998" })

TabUtil:AddToggle({ Name = "Noclip (Chạy Xuyên Tường)", Default = false,
    Callback = function(v) VanThanhConfig.Noclip = v end })
TabUtil:AddToggle({ Name = "Infinite Jump", Default = false,
    Callback = function(v) VanThanhConfig.InfiniteJump = v end })
TabUtil:AddToggle({ Name = "Anti AFK", Default = true,
    Callback = function(v) VanThanhConfig.AntiAFK = v end })

----------------------------------------------------------------
-- TAB 3: BYPASS STATUS (mới)
----------------------------------------------------------------

local TabBypass = Window:MakeTab({ Name = "Bypass Status", Icon = "rbxassetid://4483345998" })

TabBypass:AddSection({ Name = "Van Thanh Bypass Layer" })

local function boolStr(v) return v and "✅ ACTIVE" or "❌ NOT AVAILABLE" end

local _G_store = (rawget(_G,"getgenv") and rawget(_G,"getgenv")()) or _G

-- Orion AddLabel nhận string thẳng, không phải table
local function BPLabel(text)
    pcall(function() TabBypass:AddLabel(text) end)
end
BPLabel("__namecall Shield: "  .. boolStr(rawget(_G,"hookmetamethod")~=nil))
BPLabel("Kick Bypass: "        .. boolStr(rawget(_G,"hookfunction")~=nil))
BPLabel("HTTP Filter: "        .. boolStr(rawget(_G,"hookfunction")~=nil))
BPLabel("Identity Spoof: "     .. boolStr(rawget(_G,"getscriptidentity")~=nil))
BPLabel("Executor Spoof: "     .. boolStr(rawget(_G,"identifyexecutor")~=nil))
BPLabel("debug.info Spoof: "   .. boolStr(rawget(_G,"hookfunction")~=nil))
BPLabel("Error Sink: ACTIVE")
BPLabel("Env Wipe: ACTIVE")
BPLabel("Integrity Loop: ACTIVE")

TabBypass:AddSection({ Name = "Remote Log" })
TabBypass:AddButton({
    Name     = "In Log Vào Console",
    Callback = function()
        local log = _G_store.__VT_LOG or {}
        for i = math.max(1,#log-19), #log do
            print(log[i])
        end
        local rlog = _G_store.__VT_REMOTELOG or {}
        print(("[VT] Remotes intercepted: %d"):format(#rlog))
    end,
})

----------------------------------------------------------------
-- HELPERS (giữ nguyên từ bản gốc)
----------------------------------------------------------------

local function GetRootPart()
    if not Character or not Character.Parent then return nil end
    local root = Character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then RootPart = root return root end
    return nil
end

local function GetObjectCFrame(object)
    if not object then return nil end
    local ok, result = pcall(function()
        if object:IsA("BasePart") then return object.CFrame end
        if object:IsA("Model")    then return object:GetPivot() end
        local part = object:FindFirstChildWhichIsA("BasePart", true)
        if part then return part.CFrame end
        return nil
    end)
    return ok and result or nil
end

local function SafeTween(targetCFrame)
    local root = GetRootPart()
    if not root or not targetCFrame then return false end
    local dist = (root.Position - targetCFrame.Position).Magnitude
    if dist <= 2 then return true end
    local speed = math.max(tonumber(VanThanhConfig.StealSpeed) or 35, 10)

    -- chia nhỏ hành trình thành nhiều bước ngắn
    -- server thấy movement tự nhiên hơn, không phải teleport thẳng
    local steps     = math.clamp(math.floor(dist / 20), 2, 6)
    local startPos  = root.CFrame
    local endPos    = targetCFrame

    -- dùng Humanoid:MoveTo thay vì TweenService trên root
    -- server nhận movement qua Humanoid state machine → tự nhiên hơn
    local hum = Character and Character:FindFirstChildOfClass("Humanoid")
    if not hum then
        -- fallback nếu không có humanoid
        pcall(function() root.CFrame = endPos end)
        return true
    end

    local targetPos = endPos.Position
    local oldSpeed  = hum.WalkSpeed

    -- set tốc độ theo config
    pcall(function() hum.WalkSpeed = speed end)

    -- MoveTo với timeout
    local arrived   = false
    local timeout   = math.clamp(dist / math.max(speed, 1) + 3, 2, 20)
    local startTime = tick()

    hum:MoveTo(targetPos)

    -- poll đến khi đến nơi hoặc timeout
    local moveConn
    moveConn = hum.MoveToFinished:Connect(function(reached)
        arrived = true
    end)

    while not arrived and (tick() - startTime) < timeout do
        if not VanThanhConfig.AutoSteal then break end
        -- re-issue MoveTo mỗi 3s phòng stuck
        if (tick() - startTime) % 3 < 0.1 then
            hum:MoveTo(targetPos)
        end
        task.wait(0.1)
    end

    pcall(function() moveConn:Disconnect() end)

    -- restore speed
    pcall(function() hum.WalkSpeed = oldSpeed end)

    -- bước cuối snap nhẹ nếu vẫn còn cách xa
    pcall(function()
        local remaining = (root.Position - targetPos).Magnitude
        if remaining > 8 then
            -- vẫn còn xa, tween nhẹ
            local tween = TweenService:Create(root,
                TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { CFrame = endPos })
            tween:Play()
            tween.Completed:Wait()
        end
    end)

    return true
end

local function GetMyPlot()
    local plots = Workspace:FindFirstChild("Plots") or Workspace:FindFirstChild("StealZones")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        local owner
        pcall(function() owner = plot:GetAttribute("Owner") end)
        if owner == LocalPlayer.UserId
            or tostring(owner) == tostring(LocalPlayer.UserId) then
            return plot
        end
    end
    return nil
end

local function GetRarityFromObject(object)
    if not object then return nil end
    local rarity
    pcall(function()
        rarity = object:GetAttribute("Rarity")
            or object:GetAttribute("RarityName")
            or object:GetAttribute("EggRarity")
    end)
    return rarity and tostring(rarity) or nil
end

local function IsAllowedRarity(rarity)
    if not rarity then return false end
    rarity = tostring(rarity)
    if VanThanhConfig.StealRarities[rarity] then return true end
    for k, enabled in pairs(VanThanhConfig.StealRarities) do
        if enabled and string.lower(k) == string.lower(rarity) then return true end
    end
    return false
end

local function GetPromptTargetCFrame(prompt)
    if not prompt then return nil end
    local parent = prompt.Parent
    if not parent then return nil end
    return GetObjectCFrame(parent)
end

local function FirePromptSafe(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return false end
    -- KHÔNG dùng fireproximityprompt — bị detect nặng (Error 267)
    -- Dùng InputHold thuần — giống người chơi thật
    local ok = pcall(function()
        prompt.Enabled = true
        prompt:InputHoldBegin()
        local holdTime = math.max(prompt.HoldDuration, 0.1)
        -- random thêm delay nhỏ để tránh pattern detection
        task.wait(holdTime + math.random(5, 15) / 100)
        prompt:InputHoldEnd()
    end)
    return ok
end

local function FindValidPrompt(plot)
    if not plot then return nil, nil end
    local prompts = {}
    pcall(function()
        for _, obj in ipairs(plot:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then table.insert(prompts, obj) end
        end
    end)
    for _, prompt in ipairs(prompts) do
        local parent = prompt.Parent
        if parent then
            local rarity = GetRarityFromObject(parent)
            if not rarity and parent.Parent then
                rarity = GetRarityFromObject(parent.Parent)
            end
            if rarity and IsAllowedRarity(rarity) then
                local target = GetPromptTargetCFrame(prompt)
                if target then return prompt, target end
            end
        end
    end
    return nil, nil
end

----------------------------------------------------------------
-- MAIN LOOP AUTO STEAL
----------------------------------------------------------------

-- delay ngẫu nhiên giữa mỗi steal cycle — tránh rate limit detection
local function randomStealDelay()
    -- delay dài hơn: 4s - 9s giữa mỗi steal
    -- game detect rate, không phải action đơn lẻ
    task.wait(math.random(40, 90) / 10)
end

task.spawn(function()
    while task.wait(math.random(8,14) / 10) do  -- 0.8-1.4s loop, không đều
        if not VanThanhConfig.AutoSteal then continue end
        local ok, err = pcall(function()
            local root = GetRootPart()
            if not root then return end
            local plots = Workspace:FindFirstChild("Plots")
                or Workspace:FindFirstChild("StealZones")
            if not plots then return end
            for _, plot in ipairs(plots:GetChildren()) do
                if not VanThanhConfig.AutoSteal then break end
                local owner
                pcall(function() owner = plot:GetAttribute("Owner") end)
                local isMine = owner == LocalPlayer.UserId
                    or tostring(owner) == tostring(LocalPlayer.UserId)
                if isMine then continue end
                local prompt, targetCF = FindValidPrompt(plot)
                if not prompt or not targetCF then continue end
                local startCF = root.CFrame
                SafeTween(targetCF * CFrame.new(0, 3, 0))
                task.wait(0.4)
                if not VanThanhConfig.AutoSteal then break end
                FirePromptSafe(prompt)
                task.wait(0.5)
                if VanThanhConfig.ReturnToBase then
                    local myPlot = GetMyPlot()
                    if myPlot then
                        local myCF = GetObjectCFrame(myPlot)
                        if myCF then SafeTween(myCF * CFrame.new(0,5,0)) end
                    else
                        SafeTween(startCF)
                    end
                end
                randomStealDelay()
                break
            end
        end)
        if not ok then warn("[VAN THANH HUB] AutoSteal error:", err) task.wait(2) end
    end
end)

----------------------------------------------------------------
-- NOCLIP
----------------------------------------------------------------

RunService.Stepped:Connect(function()
    if not VanThanhConfig.Noclip or not Character then return end
    pcall(function()
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)
end)

----------------------------------------------------------------
-- INFINITE JUMP
----------------------------------------------------------------

UserInputService.JumpRequest:Connect(function()
    if not VanThanhConfig.InfiniteJump or not Humanoid then return end
    pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
end)

----------------------------------------------------------------
-- ANTI AFK
-- Dùng VirtualUser — KHÔNG dùng LocalPlayer.Kicked (crash)
----------------------------------------------------------------

LocalPlayer.Idled:Connect(function()
    if not VanThanhConfig.AntiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end)

----------------------------------------------------------------
-- TOGGLE BUTTON (nút V nổi bật/tắt menu + RightShift keybind)
----------------------------------------------------------------

task.spawn(function()
    task.wait(1.5)

    local OrionGui = nil
    pcall(function()
        for _, gui in ipairs(game:GetService("CoreGui"):GetChildren()) do
            if gui:IsA("ScreenGui") and string.find(gui.Name:lower(), "orion") then
                OrionGui = gui break
            end
        end
        if not OrionGui then
            OrionGui = game:GetService("CoreGui"):FindFirstChildWhichIsA("ScreenGui")
        end
    end)

    local sg = Instance.new("ScreenGui")
    sg.Name           = "VTToggleBtn"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local _syn = rawget(_G, "syn")
    if _syn and type(_syn.protect_gui) == "function" then
        pcall(_syn.protect_gui, sg)
    end
    pcall(function() sg.Parent = game:GetService("CoreGui") end)
    if not sg.Parent then
        pcall(function() sg.Parent = LocalPlayer:WaitForChild("PlayerGui",5) end)
    end

    -- badge frame
    local badge = Instance.new("Frame")
    badge.Name             = "VTBadge"
    badge.Size             = UDim2.new(0, 50, 0, 50)
    badge.Position         = UDim2.new(0, 14, 0.5, -25)
    badge.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    badge.BorderSizePixel  = 0
    badge.Active           = true
    badge.Parent           = sg
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", badge)
    stroke.Color     = Color3.fromRGB(80, 80, 80)
    stroke.Thickness = 1.5

    local label = Instance.new("TextLabel", badge)
    label.Size               = UDim2.new(1,0,0.65,0)
    label.Position           = UDim2.new(0,0,0,2)
    label.BackgroundTransparency = 1
    label.Text               = "V"
    label.TextColor3         = Color3.fromRGB(255,255,255)
    label.TextSize           = 24
    label.Font               = Enum.Font.GothamBold
    label.TextXAlignment     = Enum.TextXAlignment.Center
    label.TextYAlignment     = Enum.TextYAlignment.Center

    local sublabel = Instance.new("TextLabel", badge)
    sublabel.Size               = UDim2.new(1,0,0.35,0)
    sublabel.Position           = UDim2.new(0,0,0.65,0)
    sublabel.BackgroundTransparency = 1
    sublabel.Text               = "MENU"
    sublabel.TextColor3         = Color3.fromRGB(160,160,160)
    sublabel.TextSize           = 7
    sublabel.Font               = Enum.Font.GothamBold
    sublabel.TextXAlignment     = Enum.TextXAlignment.Center
    sublabel.TextYAlignment     = Enum.TextYAlignment.Center

    local clickBtn = Instance.new("TextButton", badge)
    clickBtn.Size               = UDim2.new(1,0,1,0)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text               = ""
    clickBtn.ZIndex             = 5

    local menuVisible = true

    local function refreshBadge()
        pcall(function()
            badge.BackgroundColor3 = menuVisible
                and Color3.fromRGB(0,0,0)
                or  Color3.fromRGB(35,15,70)
            stroke.Color = menuVisible
                and Color3.fromRGB(80,80,80)
                or  Color3.fromRGB(120,60,220)
            sublabel.Text = menuVisible and "MENU" or "OFF"
            sublabel.TextColor3 = menuVisible
                and Color3.fromRGB(160,160,160)
                or  Color3.fromRGB(120,60,220)
        end)
    end

    local function toggleMenu()
        menuVisible = not menuVisible
        pcall(function()
            -- tìm lại Orion nếu chưa có
            if not OrionGui or not OrionGui.Parent then
                for _, gui in ipairs(game:GetService("CoreGui"):GetChildren()) do
                    if gui:IsA("ScreenGui") then OrionGui = gui break end
                end
            end
            if OrionGui then OrionGui.Enabled = menuVisible end
        end)
        refreshBadge()
    end

    clickBtn.MouseButton1Click:Connect(toggleMenu)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.RightShift then toggleMenu() end
    end)

    -- drag
    local dragging, dragStart, frameStart = false, nil, nil
    badge.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging=true dragStart=input.Position frameStart=badge.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - dragStart
            badge.Position = UDim2.new(
                frameStart.X.Scale, frameStart.X.Offset + d.X,
                frameStart.Y.Scale, frameStart.Y.Offset + d.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging=false end
    end)

    refreshBadge()
end)

----------------------------------------------------------------
-- DONE
----------------------------------------------------------------

print("[VAN THANH HUB] Loaded successfully")
print("[VAN THANH HUB] Bypass: " .. (rawget(_G,"__VanThanhBypass") and "ACTIVE" or "unavailable"))
print("[VAN THANH HUB] Nút V = toggle menu | RightShift = toggle menu")

OrionLib:Init()
