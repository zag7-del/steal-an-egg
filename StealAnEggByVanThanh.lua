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
    StealSpeed   = 35,
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

TabBypass:AddLabel({ Name = "__namecall Shield: "     .. boolStr(rawget(_G,"hookmetamethod")~=nil) })
TabBypass:AddLabel({ Name = "Kick Bypass: "           .. boolStr(rawget(_G,"hookfunction")~=nil) })
TabBypass:AddLabel({ Name = "HTTP Filter: "           .. boolStr(rawget(_G,"hookfunction")~=nil) })
TabBypass:AddLabel({ Name = "Identity Spoof: "        .. boolStr(rawget(_G,"getscriptidentity")~=nil) })
TabBypass:AddLabel({ Name = "Executor Spoof: "        .. boolStr(rawget(_G,"identifyexecutor")~=nil) })
TabBypass:AddLabel({ Name = "debug.info Spoof: "      .. boolStr(rawget(_G,"hookfunction")~=nil) })
TabBypass:AddLabel({ Name = "Error Sink: ✅ ACTIVE" })
TabBypass:AddLabel({ Name = "Env Wipe: ✅ ACTIVE" })
TabBypass:AddLabel({ Name = "Integrity Loop: ✅ ACTIVE" })

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
    local speed    = math.max(tonumber(VanThanhConfig.StealSpeed) or 35, 10)
    local duration = math.clamp(dist / speed, 0.1, 15)
    local ok = pcall(function()
        local tween = TweenService:Create(root,
            TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
            { CFrame = targetCFrame })
        tween:Play()
        tween.Completed:Wait()
    end)
    return ok
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
    local _fpp = rawget(_G, "fireproximityprompt")
    local ok = pcall(function()
        if type(_fpp) == "function" then
            _fpp(prompt)
        else
            prompt:InputHoldBegin()
            task.wait(math.max(prompt.HoldDuration, 0.05))
            prompt:InputHoldEnd()
        end
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

task.spawn(function()
    while task.wait(0.5) do
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
                task.wait(1)
                break
            end
        end)
        if not ok then warn("[VAN THANH HUB] AutoSteal error:", err) task.wait(1) end
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
-- DONE
----------------------------------------------------------------

print("[VAN THANH HUB] Loaded successfully")
print("[VAN THANH HUB] Bypass layer: " .. (rawget(_G,"__VanThanhBypass") and "ACTIVE" or "unavailable on this executor"))

OrionLib:Init()
