-- // ================= ================= ================= //
-- //         VĂN THÀNH HUB - STEALTH EDITION (SAFE)        //
-- //    Steal An Anime Egg - No Metatable Hook / No Ban      //
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

LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid")
    RootPart = newChar:WaitForChild("HumanoidRootPart")
end)

-- Cấu hình mặc định an toàn
local VanThanhConfig = {
    AutoSteal = false,
    StealSpeed = 35, -- Mức an toàn (tránh BAC-6517)
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
    AutoPlace = false,
    AutoHatch = false,
    AutoEquipBest = false,
    AutoUpgradeTreadmill = false,
    AutoUpgradePlot = false,
    AutoClaimPlaytime = false,
    AutoClaimIndex = false,
    WalkSpeed = 16,
    JumpPower = 50,
    ModifySpeed = false,
    ModifyJump = false,
    InfiniteJump = false,
    Noclip = false,
    AntiAFK = true
}

local Window = OrionLib:MakeWindow({
    Name = "Văn Thành Hub | Steal An Anime Egg 🥚 [STEALTH]",
    HidePremium = false,
    SaveConfig = false,
    IntroText = "Văn Thành Hub Stealth Loaded!"
})

-- TAB 1: AUTO FARM
local TabFarm = Window:MakeTab({ Name = "Auto Farm & Steal", Icon = "rbxassetid://4483345998" })

TabFarm:AddToggle({
    Name = "Bật Auto Steal",
    Default = false,
    Callback = function(Value) VanThanhConfig.AutoSteal = Value end
})

TabFarm:AddToggle({
    Name = "Quay Về Căn Cứ Sau Khi Trộm",
    Default = true,
    Callback = function(Value) VanThanhConfig.ReturnToBase = Value end
})

TabFarm:AddSlider({
    Name = "Tốc Độ Di Chuyển (Khuyên dùng: 30 - 40)",
    Min = 20,
    Max = 60,
    Default = 35,
    Color = Color3.fromRGB(0, 255, 127),
    Increment = 5,
    ValueName = "Speed",
    Callback = function(Value) VanThanhConfig.StealSpeed = Value end
})

TabFarm:AddSection({ Name = "Độ Hiếm Trứng" })
local Rarities = {"Secret", "Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common"}
for _, rarity in ipairs(Rarities) do
    TabFarm:AddToggle({
        Name = "Trộm: " .. rarity,
        Default = VanThanhConfig.StealRarities[rarity] or false,
        Callback = function(Value) VanThanhConfig.StealRarities[rarity] = Value end
    })
end

TabFarm:AddSection({ Name = "Quản Lý Trứng" })
TabFarm:AddToggle({
    Name = "Auto Place Egg",
    Default = false,
    Callback = function(Value) VanThanhConfig.AutoPlace = Value end
})
TabFarm:AddToggle({
    Name = "Auto Hatch",
    Default = false,
    Callback = function(Value) VanThanhConfig.AutoHatch = Value end
})

-- TAB 2: UTILITIES
local TabUtil = Window:MakeTab({ Name = "Tiện Ích & Player", Icon = "rbxassetid://4483345998" })

TabUtil:AddToggle({
    Name = "Noclip (Chạy Xuyên Tường)",
    Default = false,
    Callback = function(Value) VanThanhConfig.Noclip = Value end
})

TabUtil:AddToggle({
    Name = "Infinite Jump",
    Default = false,
    Callback = function(Value) VanThanhConfig.InfiniteJump = Value end
})

TabUtil:AddToggle({
    Name = "Anti AFK",
    Default = true,
    Callback = function(Value) VanThanhConfig.AntiAFK = Value end
})

-- LOGIC DI CHUYỂN AN TOÀN
local function SafeTween(targetCFrame)
    if not RootPart then return end
    local distance = (RootPart.Position - targetCFrame.Position).Magnitude
    local duration = distance / math.max(VanThanhConfig.StealSpeed, 10)
    
    local tween = TweenService:Create(RootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
    tween:Play()
    tween.Completed:Wait()
end

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

-- MAIN LOOP AUTO STEAL
task.spawn(function()
    while task.wait(0.5) do
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
                                    local startCFrame = RootPart.CFrame
                                    
                                    SafeTween(parent.CFrame + Vector3.new(0, 3, 0))
                                    task.wait(0.4) -- Delay an toàn để Server ghi nhận vị trí
                                    
                                    fireproximityprompt(prompt)
                                    task.wait(0.5)
                                    
                                    if VanThanhConfig.ReturnToBase then
                                        local myPlot = GetMyPlot()
                                        if myPlot then
                                            SafeTween(myPlot:GetPivot() + Vector3.new(0, 5, 0))
                                        else
                                            SafeTween(startCFrame)
                                        end
                                    end
                                    task.wait(1) -- Khoảng nghỉ giữa các lần trộm
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

-- NOCLIP & JUMP
RunService.Stepped:Connect(function()
    if VanThanhConfig.Noclip and Character then
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if VanThanhConfig.InfiniteJump and Humanoid then
        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- ANTI AFK
LocalPlayer.Idled:Connect(function()
    if VanThanhConfig.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end
end)

OrionLib:Init()
