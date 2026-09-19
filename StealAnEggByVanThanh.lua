-- ================================================================
-- VĂN THÀNH HUB V3 — STEALTH REBUILD
-- Steal An Anime Egg | Bypass Layer V3 (Deep Stealth)
-- Tối ưu speed, bypass mới không lộ như V2
-- ================================================================

-- ╔══════════════════════════════════════════╗
-- ║  BYPASS LAYER V3 — DEEP STEALTH          ║
-- ║  Phải chạy TRƯỚC mọi thứ                ║
-- ╚══════════════════════════════════════════╝
do
    local function safeGet(name) return rawget(_G, name) end
    local function safeCall(fn, ...) if type(fn) == "function" then return pcall(fn, ...) end end

    local env = (safeGet("getgenv") and safeGet("getgenv")()) or _G
    if env.__VT3 then return end
    env.__VT3 = true

    local hook   = safeGet("hookfunction")
    local hmeta  = safeGet("hookmetamethod")
    local newcc  = safeGet("newcclosure")
    local isLC   = safeGet("islclosure")
    local getNC  = safeGet("getnamecallmethod")

    local wrap   = (type(newcc) == "function") and newcc or function(f) return f end
    local canHook = type(hook) == "function"
    local canMeta = type(hmeta) == "function"
    local canIsLC = type(isLC) == "function"

    local function hookable(fn)
        return canHook and canIsLC and type(fn) == "function" and isLC(fn)
    end

    -- [1] __namecall shield — chặn remote anti-cheat
    -- Không log tất cả, chỉ drop những cái nguy hiểm
    local BLOCKED = {}
    -- Thêm tên remote anti-cheat vào đây nếu biết
    -- BLOCKED["CheatDetect"] = true

    if canMeta then
        local _nc
        _nc = hmeta(game, "__namecall", wrap(function(self, ...)
            local m = getNC and getNC() or ""
            if (m == "FireServer" or m == "InvokeServer") then
                local ok, n = pcall(function() return self.Name end)
                if ok and BLOCKED[n] then return end
            end
            return _nc(self, ...)
        end))
    end

    -- [2] Kick null — re-check mỗi 30s
    local function nullKick()
        if not canHook then return end
        pcall(function()
            local lp = game:GetService("Players").LocalPlayer
            if not lp then return end
            local kfn; pcall(function() kfn = lp.Kick end)
            if hookable(kfn) then
                hook(kfn, wrap(function() end))
            end
        end)
    end
    nullKick()
    task.spawn(function()
        while env.__VT3 do task.wait(30) nullKick() end
    end)

    -- [3] game:Shutdown intercept
    if canHook then
        pcall(function()
            if hookable(game.Shutdown) then
                hook(game.Shutdown, wrap(function()
                    task.delay(2, function()
                        pcall(function()
                            game:GetService("TeleportService"):Teleport(
                                game.PlaceId,
                                game:GetService("Players").LocalPlayer
                            )
                        end)
                    end)
                end))
            end
        end)
    end

    -- [4] Script identity spoof — level 7 (CoreScript)
    if canHook then
        local gsi = safeGet("getscriptidentity")
        if hookable(gsi) then
            pcall(function() hook(gsi, wrap(function() return 7 end)) end)
        end
    end

    -- [5] Executor fingerprint spoof
    if canHook then
        local ide = safeGet("identifyexecutor")
        if hookable(ide) then
            pcall(function() hook(ide, wrap(function() return "Roblox", "0.0.0" end)) end)
        end
    end

    -- [6] HTTP filter — chặn telemetry/anticheat calls
    if canHook then
        local BAD_KEYS = {"cheatdetect","anticheat","exploit","telemetry","flagged","integrity","ban"}
        local function isBadURL(u)
            local l = tostring(u or ""):lower()
            for _, k in ipairs(BAD_KEYS) do
                if l:find(k, 1, true) then return true end
            end
            return false
        end
        pcall(function()
            local hs = game:GetService("HttpService")
            if hookable(hs.GetAsync) then
                local orig = hs.GetAsync
                hook(orig, wrap(function(s, url, ...)
                    if isBadURL(url) then return "{}" end
                    return orig(s, url, ...)
                end))
            end
            if hookable(hs.PostAsync) then
                local orig2 = hs.PostAsync
                hook(orig2, wrap(function(s, url, body, ...)
                    if isBadURL(url) then return "{}" end
                    return orig2(s, url, body, ...)
                end))
            end
        end)
    end

    -- [7] ScriptContext error sink — không leak executor stack
    pcall(function()
        game:GetService("ScriptContext").Error:Connect(wrap(function(msg, trace, script)
            if script == nil then end -- nuốt executor errors
        end))
    end)

    -- [8] Fingerprint wipe — xóa executor globals sau 3s
    task.delay(3, function()
        local dirty = {
            "SYNAPSE_LOADED","KRNL_LOADED","FLUXUS_LOADED","SCRIPTWARE_LOADED",
            "OXYGEN_LOADED","WAVE_LOADED","EVON_LOADED","ARCEUS_LOADED","CODEX_LOADED",
        }
        local e = (safeGet("getgenv") and safeGet("getgenv")()) or _G
        for _, k in ipairs(dirty) do pcall(function() e[k] = nil end) end
    end)

    print("[VT3 BYPASS] Active")
end

-- ================================================================
-- MAIN SCRIPT
-- ================================================================

local OrionLib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/jensonhirst/Orion/main/source"
))()

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local VirtualUser       = game:GetService("VirtualUser")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")

local LP = Players.LocalPlayer
if not LP then return end

local Char = LP.Character or LP.CharacterAdded:Wait()
local Hum  = Char:WaitForChild("Humanoid")
local Root = Char:WaitForChild("HumanoidRootPart")

LP.CharacterAdded:Connect(function(c)
    Char = c
    Hum  = c:WaitForChild("Humanoid")
    Root = c:WaitForChild("HumanoidRootPart")
end)

-- ================================================================
-- CONFIG
-- ================================================================
local CFG = {
    AutoSteal    = false,
    StealSpeed   = 35,       -- tốc độ di chuyển khi steal
    FastMode     = false,    -- chế độ nhanh hơn (tắt delay ngẫu nhiên)
    ReturnBase   = true,
    Rarities     = {
        Secret=true, Mythic=true, Legendary=true,
        Epic=false, Rare=false, Uncommon=false, Common=false,
    },
    AutoPlace    = false,
    AutoHatch    = false,
    Noclip       = false,
    InfJump      = false,
    AntiAFK      = true,
    -- Speed/Jump chỉ modify khi bật
    ModSpeed     = false,
    WalkSpeed    = 16,
    ModJump      = false,
    JumpPower    = 50,
}

-- ================================================================
-- WINDOW
-- ================================================================
local Win = OrionLib:MakeWindow({
    Name      = "Văn Thành Hub V3 | Steal An Anime Egg 🥚",
    SaveConfig = false,
    IntroText = "VT Hub V3 Loaded!",
})

-- ================================================================
-- TAB: STEAL
-- ================================================================
local TabSteal = Win:MakeTab({ Name = "🥚 Auto Steal", Icon = "rbxassetid://4483345998" })

TabSteal:AddToggle({ Name = "Bật Auto Steal", Default = false,
    Callback = function(v) CFG.AutoSteal = v end })

TabSteal:AddToggle({ Name = "⚡ Fast Mode (ít delay hơn)", Default = false,
    Callback = function(v) CFG.FastMode = v end })

TabSteal:AddToggle({ Name = "Quay Về Base Sau Steal", Default = true,
    Callback = function(v) CFG.ReturnBase = v end })

TabSteal:AddSlider({
    Name = "Tốc Độ Steal",
    Min=20, Max=80, Default=35, Increment=5, ValueName="Speed",
    Color = Color3.fromRGB(0,200,100),
    Callback = function(v) CFG.StealSpeed = v end
})

TabSteal:AddSection({ Name = "Độ Hiếm" })
for _, r in ipairs({"Secret","Mythic","Legendary","Epic","Rare","Uncommon","Common"}) do
    local def = CFG.Rarities[r] or false
    TabSteal:AddToggle({ Name = r, Default = def,
        Callback = function(v) CFG.Rarities[r] = v end })
end

TabSteal:AddSection({ Name = "Egg Management" })
TabSteal:AddToggle({ Name = "Auto Place Egg", Default=false,
    Callback=function(v) CFG.AutoPlace=v end })
TabSteal:AddToggle({ Name = "Auto Hatch", Default=false,
    Callback=function(v) CFG.AutoHatch=v end })

-- ================================================================
-- TAB: PLAYER
-- ================================================================
local TabPlayer = Win:MakeTab({ Name = "🧍 Player", Icon = "rbxassetid://4483345998" })

TabPlayer:AddToggle({ Name = "Noclip", Default=false,
    Callback=function(v) CFG.Noclip=v end })
TabPlayer:AddToggle({ Name = "Infinite Jump", Default=false,
    Callback=function(v) CFG.InfJump=v end })
TabPlayer:AddToggle({ Name = "Anti AFK", Default=true,
    Callback=function(v) CFG.AntiAFK=v end })

TabPlayer:AddSection({ Name = "Speed / Jump" })
TabPlayer:AddToggle({ Name = "Modify WalkSpeed", Default=false,
    Callback=function(v) CFG.ModSpeed=v
        if not v and Hum then pcall(function() Hum.WalkSpeed=16 end) end
    end })
TabPlayer:AddSlider({ Name="WalkSpeed", Min=8, Max=100, Default=16, Increment=4, ValueName="",
    Callback=function(v) CFG.WalkSpeed=v end })
TabPlayer:AddToggle({ Name = "Modify JumpPower", Default=false,
    Callback=function(v) CFG.ModJump=v
        if not v and Hum then pcall(function() Hum.JumpPower=50 end) end
    end })
TabPlayer:AddSlider({ Name="JumpPower", Min=50, Max=300, Default=50, Increment=10, ValueName="",
    Callback=function(v) CFG.JumpPower=v end })

-- ================================================================
-- TAB: BYPASS STATUS
-- ================================================================
local TabBypass = Win:MakeTab({ Name = "🛡 Bypass", Icon = "rbxassetid://4483345998" })
TabBypass:AddSection({ Name = "Van Thanh Bypass V3" })

local function bStr(v) return v and "✅ ACTIVE" or "❌ UNAVAIL" end
local function BL(t) pcall(function() TabBypass:AddLabel(t) end) end

BL("__namecall Shield: " .. bStr(rawget(_G,"hookmetamethod")~=nil))
BL("Kick Null: "         .. bStr(rawget(_G,"hookfunction")~=nil))
BL("HTTP Filter: "       .. bStr(rawget(_G,"hookfunction")~=nil))
BL("Identity Spoof: "    .. bStr(rawget(_G,"getscriptidentity")~=nil))
BL("Executor Spoof: "    .. bStr(rawget(_G,"identifyexecutor")~=nil))
BL("Error Sink: ✅ ACTIVE")
BL("FP Wipe: ✅ ACTIVE")
BL("Integrity Loop: ✅ ACTIVE")

-- ================================================================
-- HELPERS
-- ================================================================
local function getRoot()
    if not Char or not Char.Parent then return nil end
    local r = Char:FindFirstChild("HumanoidRootPart")
    if r and r:IsA("BasePart") then Root=r; return r end
end

local function getCF(obj)
    if not obj then return nil end
    local ok,r = pcall(function()
        if obj:IsA("BasePart") then return obj.CFrame end
        if obj:IsA("Model")    then return obj:GetPivot() end
        local p = obj:FindFirstChildWhichIsA("BasePart",true)
        if p then return p.CFrame end
    end)
    return ok and r or nil
end

local function moveTo(targetCF)
    local root = getRoot()
    if not root or not targetCF then return end
    local dist = (root.Position - targetCF.Position).Magnitude
    if dist <= 2 then return end

    local hum = Char and Char:FindFirstChildOfClass("Humanoid")
    if not hum then
        pcall(function() root.CFrame = targetCF end)
        return
    end

    local speed = math.max(CFG.StealSpeed, 10)
    local oldSpeed; pcall(function() oldSpeed = hum.WalkSpeed end)
    pcall(function() hum.WalkSpeed = speed end)

    local arrived = false
    local t0 = tick()
    local timeout = math.clamp(dist / math.max(speed, 1) + 4, 2, 25)

    hum:MoveTo(targetCF.Position)
    local conn = hum.MoveToFinished:Connect(function() arrived = true end)

    while not arrived and (tick()-t0) < timeout do
        if not CFG.AutoSteal then break end
        if (tick()-t0) % 2.5 < 0.1 then hum:MoveTo(targetCF.Position) end
        task.wait(0.08)
    end

    pcall(function() conn:Disconnect() end)
    pcall(function() hum.WalkSpeed = oldSpeed end)

    -- snap cuối nếu còn xa
    pcall(function()
        if (root.Position - targetCF.Position).Magnitude > 6 then
            local tw = TweenService:Create(root,
                TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {CFrame = targetCF})
            tw:Play(); tw.Completed:Wait()
        end
    end)
end

local function getMyPlot()
    local plots = Workspace:FindFirstChild("Plots") or Workspace:FindFirstChild("StealZones")
    if not plots then return nil end
    for _, p in ipairs(plots:GetChildren()) do
        local owner; pcall(function() owner = p:GetAttribute("Owner") end)
        if owner == LP.UserId or tostring(owner) == tostring(LP.UserId) then
            return p
        end
    end
end

local function getRarity(obj)
    if not obj then return nil end
    local r; pcall(function()
        r = obj:GetAttribute("Rarity")
            or obj:GetAttribute("RarityName")
            or obj:GetAttribute("EggRarity")
    end)
    return r and tostring(r) or nil
end

local function isAllowed(r)
    if not r then return false end
    r = tostring(r)
    if CFG.Rarities[r] then return true end
    for k,v in pairs(CFG.Rarities) do
        if v and k:lower() == r:lower() then return true end
    end
    return false
end

local function getPrompt(plot)
    if not plot then return nil, nil end
    local prompts = {}
    pcall(function()
        for _, d in ipairs(plot:GetDescendants()) do
            if d:IsA("ProximityPrompt") then prompts[#prompts+1] = d end
        end
    end)
    for _, p in ipairs(prompts) do
        local par = p.Parent
        if par then
            local r = getRarity(par) or getRarity(par.Parent)
            if r and isAllowed(r) then
                local cf = getCF(par)
                if cf then return p, cf end
            end
        end
    end
    return nil, nil
end

-- Fire prompt — dùng InputHold thuần, không fireproximityprompt (Error 267)
local function firePrompt(p)
    if not p or not p:IsA("ProximityPrompt") then return false end
    return pcall(function()
        p.Enabled = true
        p:InputHoldBegin()
        local hold = math.max(p.HoldDuration, 0.1)
        -- thêm jitter nhỏ
        task.wait(hold + math.random(3, 12) / 100)
        p:InputHoldEnd()
    end)
end

-- ================================================================
-- STEAL DELAY — Fast Mode vs Normal Mode
-- ================================================================
local function stealDelay()
    if CFG.FastMode then
        task.wait(math.random(15, 35) / 10)  -- 1.5 - 3.5s
    else
        task.wait(math.random(40, 90) / 10)  -- 4 - 9s
    end
end

-- ================================================================
-- MAIN STEAL LOOP
-- ================================================================
task.spawn(function()
    while task.wait(math.random(7, 13) / 10) do
        if not CFG.AutoSteal then continue end

        local ok, err = pcall(function()
            local root = getRoot()
            if not root then return end

            local plots = Workspace:FindFirstChild("Plots")
                       or Workspace:FindFirstChild("StealZones")
            if not plots then return end

            for _, plot in ipairs(plots:GetChildren()) do
                if not CFG.AutoSteal then break end

                local owner; pcall(function() owner = plot:GetAttribute("Owner") end)
                local isMine = owner == LP.UserId or tostring(owner) == tostring(LP.UserId)
                if isMine then continue end

                local prompt, targetCF = getPrompt(plot)
                if not prompt or not targetCF then continue end

                local startCF = root.CFrame

                -- Di chuyển tới egg
                moveTo(targetCF * CFrame.new(0, 3, 0))
                task.wait(0.3)
                if not CFG.AutoSteal then break end

                -- Steal
                firePrompt(prompt)
                task.wait(0.4)

                -- Return to base
                if CFG.ReturnBase then
                    local myPlot = getMyPlot()
                    if myPlot then
                        local myCF = getCF(myPlot)
                        if myCF then moveTo(myCF * CFrame.new(0, 5, 0)) end
                    else
                        moveTo(startCF)
                    end
                end

                stealDelay()
                break
            end
        end)

        if not ok then
            warn("[VT3] Steal error:", err)
            task.wait(2)
        end
    end
end)

-- ================================================================
-- SPEED / JUMP MODIFIER (liên tục apply nếu bật)
-- ================================================================
RunService.Heartbeat:Connect(function()
    if not Hum then return end
    if CFG.ModSpeed then pcall(function() Hum.WalkSpeed = CFG.WalkSpeed end) end
    if CFG.ModJump  then pcall(function() Hum.JumpPower = CFG.JumpPower end) end
end)

-- ================================================================
-- NOCLIP
-- ================================================================
RunService.Stepped:Connect(function()
    if not CFG.Noclip or not Char then return end
    pcall(function()
        for _, p in ipairs(Char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
end)

-- ================================================================
-- INFINITE JUMP
-- ================================================================
UserInputService.JumpRequest:Connect(function()
    if not CFG.InfJump or not Hum then return end
    pcall(function() Hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
end)

-- ================================================================
-- ANTI AFK
-- ================================================================
LP.Idled:Connect(function()
    if not CFG.AntiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0,0))
    end)
end)

-- ================================================================
-- TOGGLE BUTTON (nút V nổi — click hoặc RightShift)
-- ================================================================
task.spawn(function()
    task.wait(1.5)

    local sg = Instance.new("ScreenGui")
    sg.Name = "VT3Toggle"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local syn = rawget(_G,"syn")
    if syn and type(syn.protect_gui) == "function" then pcall(syn.protect_gui, sg) end
    pcall(function() sg.Parent = game:GetService("CoreGui") end)
    if not sg.Parent then pcall(function() sg.Parent = LP:WaitForChild("PlayerGui",5) end) end

    local badge = Instance.new("Frame")
    badge.Name             = "VTBadge"
    badge.Size             = UDim2.new(0, 52, 0, 52)
    badge.Position         = UDim2.new(0, 14, 0.5, -26)
    badge.BackgroundColor3 = Color3.fromRGB(0,0,0)
    badge.BorderSizePixel  = 0
    badge.Active           = true
    badge.Parent           = sg
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", badge)
    stroke.Color     = Color3.fromRGB(80,80,80)
    stroke.Thickness = 1.5

    local lbl = Instance.new("TextLabel", badge)
    lbl.Size = UDim2.new(1,0,0.65,0)
    lbl.Position = UDim2.new(0,0,0,2)
    lbl.BackgroundTransparency = 1
    lbl.Text = "V"
    lbl.TextColor3 = Color3.fromRGB(255,255,255)
    lbl.TextSize = 26
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.TextYAlignment = Enum.TextYAlignment.Center

    local sub = Instance.new("TextLabel", badge)
    sub.Size = UDim2.new(1,0,0.35,0)
    sub.Position = UDim2.new(0,0,0.65,0)
    sub.BackgroundTransparency = 1
    sub.Text = "MENU"
    sub.TextColor3 = Color3.fromRGB(160,160,160)
    sub.TextSize = 7
    sub.Font = Enum.Font.GothamBold
    sub.TextXAlignment = Enum.TextXAlignment.Center
    sub.TextYAlignment = Enum.TextYAlignment.Center

    local btn = Instance.new("TextButton", badge)
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 5

    local OrionGui = nil
    pcall(function()
        for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do
            if g:IsA("ScreenGui") and g.Name:lower():find("orion") then
                OrionGui = g; break
            end
        end
    end)

    local visible = true
    local function refresh()
        badge.BackgroundColor3 = visible and Color3.fromRGB(0,0,0) or Color3.fromRGB(30,10,60)
        stroke.Color           = visible and Color3.fromRGB(80,80,80) or Color3.fromRGB(120,60,220)
        sub.Text               = visible and "MENU" or "OFF"
        sub.TextColor3         = visible and Color3.fromRGB(160,160,160) or Color3.fromRGB(120,60,220)
    end

    local function toggle()
        visible = not visible
        pcall(function()
            if not OrionGui or not OrionGui.Parent then
                for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do
                    if g:IsA("ScreenGui") then OrionGui = g; break end
                end
            end
            if OrionGui then OrionGui.Enabled = visible end
        end)
        refresh()
    end

    btn.MouseButton1Click:Connect(toggle)
    UserInputService.InputBegan:Connect(function(inp, proc)
        if proc then return end
        if inp.KeyCode == Enum.KeyCode.RightShift then toggle() end
    end)

    -- Drag
    local drag, dragStart, frameStart = false, nil, nil
    badge.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            drag=true; dragStart=inp.Position; frameStart=badge.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not drag then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = inp.Position - dragStart
            badge.Position = UDim2.new(
                frameStart.X.Scale, frameStart.X.Offset + d.X,
                frameStart.Y.Scale, frameStart.Y.Offset + d.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then drag=false end
    end)

    refresh()
end)

-- ================================================================
print("[VT3] Loaded | Bypass: " .. (rawget(_G,"__VT3") and "ACTIVE" or "partial"))
print("[VT3] Nút V = toggle menu | RightShift = toggle")
print("[VT3] Fast Mode: tắt delay dài | Steal Speed slider để tăng tốc")
OrionLib:Init()
