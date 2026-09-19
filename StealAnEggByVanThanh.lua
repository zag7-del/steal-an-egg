-- // ================= ================= ================= //
-- //               VĂN THÀNH HUB - FULL EDITION            //
-- //          Steal An Anime Egg - Complete Feature Set    //
-- // ================= ================= ================= //

local OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/jensonhirst/Orion/main/source'))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

-- Cập nhật nhân vật khi respawn
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid")
    RootPart = newChar:WaitForChild("HumanoidRootPart")
end)

-- BẢNG CẤU HÌNH TOÀN BỘ HUB
local VanThanhConfig = {
    -- Steal Settings
    AutoSteal = false,
    StealSpeed = 85,
    ReturnToBase = true,
    StealRarities = {
        Secret = true,
        Mythic = true,
        Legendary = true,
        Epic = false,
        Rare = false,
        Uncommon = false,
        Common = false
    },
    
    -- Base & Egg Settings
    AutoPlace = false,
    AutoHatch = false,
    AutoEquipBest = false,
    AutoUpgradeSlots = false,
    
    -- Upgrades & Rewards
    AutoUpgradeTreadmill = false,
    AutoUpgradePlot = false,
    AutoClaimPlaytime = false,
    AutoClaimIndex = false,
    
    -- Player & Movement
    WalkSpeed = 16,
    JumpPower = 50,
    ModifySpeed = false,
    ModifyJump = false,
    InfiniteJump = false,
    Noclip = false,
    Fly = false,
    FlySpeed = 50,
    
    -- System & Performance
    AntiAFK = true,
    Disable3D = false,
    LowGraphics = false,
    RemoveEffects = false
}

-- KHỞI TẠO ORION UI (GIAO DIỆN VĂN THÀNH HUB)
local Window = OrionLib:MakeWindow({
    Name = "Văn Thành Hub | Steal An Anime Egg 🥚 [FULL]",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "VanThanhHub_Config",
    IntroText = "Văn Thành Hub Premium Loading..."
})

-- ==========================================
-- TAB 1: TỰ ĐỘNG FARM & TRỘM TRỨNG (AUTO FARM)
-- ==========================================
local TabFarm = Window:MakeTab({
    Name = "Auto Farm & Steal",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

TabFarm:AddSection({ Name = "🔥 Cấu Hình Trộm Trứng (Auto Steal)" })

TabFarm:AddToggle({
    Name = "Bật Tự Động Trộm Trứng (Auto Steal)",
    Default = VanThanhConfig.AutoSteal,
    Callback = function(Value)
        VanThanhConfig.AutoSteal = Value
    end
})

TabFarm:AddToggle({
    Name = "Tự Động Quay Về Căn Cứ Sau Khi Trộm",
    Default = VanThanhConfig.ReturnToBase,
    Callback = function(Value)
        VanThanhConfig.ReturnToBase = Value
    end
})

TabFarm:AddSlider({
    Name = "Tốc Độ Di Chuyển Trộm (Tween Speed)",
    Min = 30,
    Max = 180,
    Default = VanThanhConfig.StealSpeed,
    Color = Color3.fromRGB(255, 85, 85),
    Increment = 5,
    ValueName = "Speed",
    Callback = function(Value)
        VanThanhConfig.StealSpeed = Value
    end
})

TabFarm:AddSection({ Name = "🎯 Lọc Độ Hiếm Trứng Trộm" })

local Rarities = {"Secret", "Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common"}
for _, rarity in ipairs(Rarities) do
    TabFarm:AddToggle({
        Name = "Trộm Trứng: " .. rarity,
        Default = VanThanhConfig.StealRarities[rarity] or false,
        Callback = function(Value)
            VanThanhConfig.StealRarities[rarity] = Value
        end
    })
end

TabFarm:AddSection({ Name = "🥚 Quản Lý Trứng & Căn Cứ" })

TabFarm:AddToggle({
    Name = "Tự Động Đặt Trứng Vào Căn Cứ (Auto Place)",
    Default = VanThanhConfig.AutoPlace,
    Callback = function(Value)
        VanThanhConfig.AutoPlace = Value
    end
})

TabFarm:AddToggle({
    Name = "Tự Động Ấp Trứng Ngay (Auto Hatch)",
    Default = VanThanhConfig.AutoHatch,
    Callback = function(Value)
        VanThanhConfig.AutoHatch = Value
    end
})

TabFarm:AddToggle({
    Name = "Tự Động Trang Bị Anime Mạnh Nhất",
    Default = VanThanhConfig.AutoEquipBest,
    Callback = function(Value)
        VanThanhConfig.AutoEquipBest = Value
    end
})

-- ==========================================
-- TAB 2: NÂNG CẤP & NHẬN THƯỞNG (UPGRADES)
-- ==========================================
local TabUpgrades = Window:MakeTab({
    Name = "Nâng Cấp & Quà",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

TabUpgrades:AddSection({ Name = "⚡ Tự Động Nâng Cấp Base" })

TabUpgrades:AddToggle({
    Name = "Auto Upgrade Treadmill (Máy Chạy Tăng Tốc)",
    Default = VanThanhConfig.AutoUpgradeTreadmill,
    Callback = function(Value)
        VanThanhConfig.AutoUpgradeTreadmill = Value
    end
})

TabUpgrades:AddToggle({
    Name = "Auto Upgrade Plot (Mở Rộng Đất)",
    Default = VanThanhConfig.AutoUpgradePlot,
    Callback = function(Value)
        VanThanhConfig.AutoUpgradePlot = Value
    end
})

TabUpgrades:AddSection({ Name = "🎁 Tự Động Nhận Thưởng" })

TabUpgrades:AddToggle({
    Name = "Auto Claim Online Rewards (Quà Thời Gian)",
    Default = VanThanhConfig.AutoClaimPlaytime,
    Callback = function(Value)
        VanThanhConfig.AutoClaimPlaytime = Value
    end
})

TabUpgrades:AddToggle({
    Name = "Auto Claim Index / Bộ Sưu Tập",
    Default = VanThanhConfig.AutoClaimIndex,
    Callback = function(Value)
        VanThanhConfig.AutoClaimIndex = Value
    end
})

-- ==========================================
-- TAB 3: DI CHUYỂN & NHÂN VẬT (PLAYER)
-- ==========================================
local TabPlayer = Window:MakeTab({
    Name = "Nhân Vật / Hack",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

TabPlayer:AddSection({ Name = "🏃 Chi Số Di Chuyển" })

TabPlayer:AddToggle({
    Name = "Kích Hoạt Chỉnh WalkSpeed",
    Default = false,
    Callback = function(Value)
        VanThanhConfig.ModifySpeed = Value
    end
})

TabPlayer:AddSlider({
    Name = "Tốc Độ Chạy (WalkSpeed)",
    Min = 16,
    Max = 300,
    Default = 16,
    Color = Color3.fromRGB(0, 255, 127),
    Increment = 2,
    ValueName = "Speed",
    Callback = function(Value)
        VanThanhConfig.WalkSpeed = Value
    end
})

TabPlayer:AddToggle({
    Name = "Kích Hoạt Chỉnh JumpPower",
    Default = false,
    Callback = function(Value)
        VanThanhConfig.ModifyJump = Value
    end
})

TabPlayer:AddSlider({
    Name = "Sức Nhảy (JumpPower)",
    Min = 50,
    Max = 400,
    Default = 50,
    Color = Color3.fromRGB(0, 191, 255),
    Increment = 5,
    ValueName = "Power",
    Callback = function(Value)
        VanThanhConfig.JumpPower = Value
    end
})

TabPlayer:AddSection({ Name = "👻 Gian Lận Di Chuyển" })

TabPlayer:AddToggle({
    Name = "Nhảy Vô Tận (Infinite Jump)",
    Default = false,
    Callback = function(Value)
        VanThanhConfig.InfiniteJump = Value
    end
})

TabPlayer:AddToggle({
    Name = "Đi Xuyên Tường (Noclip)",
    Default = false,
    Callback = function(Value)
        VanThanhConfig.Noclip = Value
    end
})

-- ==========================================
-- TAB 4: DỊCH CHUYỂN (TELEPORT)
-- ==========================================
local TabTeleport = Window:MakeTab({
    Name = "Dịch Chuyển",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

TabTeleport:AddSection({ Name = "📌 Vị Trí Cố Định" })

local function GetMyPlot()
    local plots = Workspace:FindFirstChild("Plots") or Workspace:FindFirstChild("StealZones")
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            if plot:GetAttribute("Owner") == LocalPlayer.UserId then
                return plot
            end
        end
    end
    return nil
end

TabTeleport:AddButton({
    Name = "Về Căn Cứ Của Tôi",
    Callback = function()
        local myPlot = GetMyPlot()
        if myPlot and RootPart then
            RootPart.CFrame = myPlot:GetPivot() + Vector3.new(0, 5, 0)
        end
    end
})

TabTeleport:AddButton({
    Name = "Đến Khu Vực Trung Tâm (Spawn)",
    Callback = function()
        local spawnLocation = Workspace:FindFirstChild("SpawnLocation") or Workspace:FindFirstChild("Spawns")
        if spawnLocation and RootPart then
            RootPart.CFrame = spawnLocation:GetPivot() + Vector3.new(0, 5, 0)
        end
    end
})

-- ==========================================
-- TAB 5: TỐI ƯU & HỆ THỐNG (SYSTEM)
-- ==========================================
local TabSystem = Window:MakeTab({
    Name = "Tối Ưu & Hệ Thống",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

TabSystem:AddSection({ Name = "🚀 Tối Ưu Máy Treo Game (FPS Boost)" })

TabSystem:AddToggle({
    Name = "Tắt Render 3D (Giảm Lag Max CPU/GPU)",
    Default = false,
    Callback = function(Value)
        VanThanhConfig.Disable3D = Value
        RunService:Set3dRenderingEnabled(not Value)
    end
})

TabSystem:AddToggle({
    Name = "Xóa Chi Tiết Đồ Họa (Low Graphics)",
    Default = false,
    Callback = function(Value)
        VanThanhConfig.LowGraphics = Value
        if Value then
            for _, v in ipairs(Workspace:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.Material = Enum.Material.SmoothPlastic
                elseif v:IsA("Decal") or v:IsA("Texture") then
                    v:Destroy()
                end
            end
        end
    end
})

TabSystem:AddToggle({
    Name = "Chống AFK (Anti Disconnect)",
    Default = true,
    Callback = function(Value)
        VanThanhConfig.AntiAFK = Value
    end
})

TabSystem:AddSection({ Name = "🌐 Quản Lý Server" })

TabSystem:AddButton({
    Name = "Vào Lại Server (Rejoin)",
    Callback = function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end
})

TabSystem:AddButton({
    Name = "Đổi Server Khác (Server Hop)",
    Callback = function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
})

-- ==========================================
-- HỆ THỐNG LOGIC CHẠY NGẦM (CORE ENGINE)
-- ==========================================

-- 1. Hàm di chuyển mượt an toàn (Bypass Anti-Cheat Teleport Check)
local function VanThanhSafeMove(targetCFrame)
    if not RootPart then return end
    local distance = (RootPart.Position - targetCFrame.Position).Magnitude
    local duration = distance / math.max(VanThanhConfig.StealSpeed, 10)
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(RootPart, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
    tween.Completed:Wait()
end

-- 2. Anti-AFK
LocalPlayer.Idled:Connect(function()
    if VanThanhConfig.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end
end)

-- 3. Noclip & Infinite Jump & Speed Control
RunService.Stepped:Connect(function()
    if VanThanhConfig.Noclip and Character then
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
    
    if Humanoid then
        if VanThanhConfig.ModifySpeed then
            Humanoid.WalkSpeed = VanThanhConfig.WalkSpeed
        end
        if VanThanhConfig.ModifyJump then
            Humanoid.JumpPower = VanThanhConfig.JumpPower
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if VanThanhConfig.InfiniteJump and Humanoid then
        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- 4. Dynamic Auto Steal Loop
task.spawn(function()
    while task.wait(0.4) do
        if VanThanhConfig.AutoSteal then
            pcall(function()
                local plots = Workspace:FindFirstChild("Plots") or Workspace:FindFirstChild("StealZones")
                if not plots then return end

                for _, plot in ipairs(plots:GetChildren()) do
                    if plot:GetAttribute("Owner") ~= LocalPlayer.UserId then
                        for _, prompt in ipairs(plot:GetDescendants()) do
                            if prompt:IsA("ProximityPrompt") then
                                local parent = prompt.Parent
                                local rarity = parent and (parent:GetAttribute("Rarity") or parent.Name)
                                
                                if rarity and VanThanhConfig.StealRarities[rarity] then
                                    local originalCFrame = RootPart.CFrame
                                    
                                    -- Bay mượt tới trứng
                                    VanThanhSafeMove(parent.CFrame + Vector3.new(0, 3, 0))
                                    task.wait(0.2)
                                    fireproximityprompt(prompt)
                                    task.wait(0.3)
                                    
                                    -- Trở về Căn Cứ
                                    if VanThanhConfig.ReturnToBase then
                                        local myPlot = GetMyPlot()
                                        if myPlot then
                                            VanThanhSafeMove(myPlot:GetPivot() + Vector3.new(0, 5, 0))
                                        else
                                            VanThanhSafeMove(originalCFrame)
                                        end
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- 5. Auto Place & Hatch
task.spawn(function()
    while task.wait(1) do
        if VanThanhConfig.AutoPlace then
            pcall(function()
                local net = ReplicatedStorage:FindFirstChild("Network") or ReplicatedStorage:FindFirstChild("Events")
                local rem = net and (net:FindFirstChild("PlaceEgg") or net:FindFirstChild("Place"))
                if rem then rem:FireServer() end
            end)
        end

        if VanThanhConfig.AutoHatch then
            pcall(function()
                local net = ReplicatedStorage:FindFirstChild("Network") or ReplicatedStorage:FindFirstChild("Events")
                local rem = net and (net:FindFirstChild("HatchNow") or net:FindFirstChild("Hatch"))
                if rem then rem:FireServer() end
            end)
        end
    end
end)

-- 6. Upgrades & Rewards Loops
task.spawn(function()
    while task.wait(2) do
        if VanThanhConfig.AutoUpgradeTreadmill then
            pcall(function()
                local rem = ReplicatedStorage:FindFirstChild("UpgradeTreadmill", true)
                if rem then rem:FireServer() end
            end)
        end

        if VanThanhConfig.AutoUpgradePlot then
            pcall(function()
                local rem = ReplicatedStorage:FindFirstChild("UpgradePlot", true)
                if rem then rem:FireServer() end
            end)
        end

        if VanThanhConfig.AutoClaimPlaytime then
            pcall(function()
                local rem = ReplicatedStorage:FindFirstChild("ClaimPlaytime", true) or ReplicatedStorage:FindFirstChild("ClaimReward", true)
                if rem then rem:FireServer() end
            end)
        end
        
        if VanThanhConfig.AutoClaimIndex then
            pcall(function()
                local rem = ReplicatedStorage:FindFirstChild("ClaimIndex", true)
                if rem then rem:FireServer() end
            end)
        end
    end
end)

-- 7. Auto Equip Best Loop
task.spawn(function()
    while task.wait(5) do
        if VanThanhConfig.AutoEquipBest then
            pcall(function()
                local rem = ReplicatedStorage:FindFirstChild("EquipBest", true)
                if rem then rem:FireServer() end
            end)
        end
    end
end)

-- Khởi chạy giao diện Orion
OrionLib:Init()
