-- ============================================================
-- ESP + AIMBOT + FOV + TEAM FILTER (Drawing Pool Version)
-- Fix untuk Xeno: hindari Remove(), pakai pool + Visible toggle
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- KONFIGURASI
-- ============================================================
local AimbotEnabled = true
local FOVRadius = 120
local FOVMin = 30
local FOVMax = 150
local AimPart = "Head"
local HoldingRightClick = false
local AimSmoothness = 0.25

local TEAM_SEEKER_NAMES = {"Seeker", "Seekers", "It", "Tag", "Tagger", "Seek"}
local TEAM_HIDER_NAMES = {"Hider", "Hiders", "Hide", "Runner", "Survivor", "Prop"}

local AimMode = "BOTH"

-- ============================================================
-- GLOBAL TRACKER — JANGAN REMOVE, hanya hide
-- ============================================================
if not getgenv().KryoDrawings then
    getgenv().KryoDrawings = {}
end

-- Bersihkan HANYA dari eksekusi lama (sebelum re-execute)
-- Kalau ini eksekusi pertama, tidak ada yang perlu dibersihkan
local function CleanupFromPreviousExecution()
    if getgenv().KryoDrawings then
        for _, d in ipairs(getgenv().KryoDrawings) do
            pcall(function()
                if typeof(d) == "userdata" then
                    d.Visible = false
                end
            end)
        end
    end
    getgenv().KryoDrawings = {}
end

CleanupFromPreviousExecution()

local ESPEnabled = true
local ESPObjects = {}    -- [player] = { slots... }
local CurrentAimTarget = nil
local FOVCircle = nil

-- ============================================================
-- DRAWING POOL — max 30 player sekaligus
-- ============================================================
local MAX_SLOTS = 30
local DrawingPool = {
    BoxOutline = {},   -- 30 slot Square
    Box = {},          -- 30 slot Square
    TeamName = {},     -- 30 slot Text
    Bones = {},        -- 30 x 14 slot Line
}

local function CreateDrawingOnce(type, table_ref)
    local d = Drawing.new(type)
    d.Visible = false
    table.insert(table_ref, d)
    table.insert(getgenv().KryoDrawings, d)
    return d
end

-- Pre-create 30 slot untuk Box, Outline, TeamName
for i = 1, MAX_SLOTS do
    local outline = Drawing.new("Square")
    outline.Visible = false
    outline.Color = Color3.new(0, 0, 0)
    outline.Thickness = 3
    outline.Filled = false
    DrawingPool.BoxOutline[i] = outline
    table.insert(getgenv().KryoDrawings, outline)
    
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = Color3.new(1, 1, 1)
    box.Thickness = 1
    box.Filled = false
    DrawingPool.Box[i] = box
    table.insert(getgenv().KryoDrawings, box)
    
    local name = Drawing.new("Text")
    name.Visible = false
    name.Center = true
    name.Outline = true
    name.OutlineColor = Color3.new(0, 0, 0)
    name.Size = 13
    name.Font = 2
    DrawingPool.TeamName[i] = name
    table.insert(getgenv().KryoDrawings, name)
end

-- Pre-create bones: 30 slot x 14 line
for i = 1, MAX_SLOTS do
    DrawingPool.Bones[i] = {}
    for j = 1, 14 do
        local line = Drawing.new("Line")
        line.Visible = false
        line.Color = Color3.new(1, 1, 1)
        line.Thickness = 1
        DrawingPool.Bones[i][j] = line
        table.insert(getgenv().KryoDrawings, line)
    end
end

-- ============================================================
-- SLOT ALLOCATOR — assign slot ke player
-- ============================================================
local SlotInUse = {}  -- [slot_index] = player

local function AllocSlot(player)
    -- Cari slot kosong
    for i = 1, MAX_SLOTS do
        if not SlotInUse[i] then
            SlotInUse[i] = player
            return i
        end
    end
    return nil
end

local function FreeSlot(player)
    for i = 1, MAX_SLOTS do
        if SlotInUse[i] == player then
            SlotInUse[i] = nil
            return i
        end
    end
    return nil
end

-- ============================================================
-- SEMBUNYIKAN SEMUA DRAWING (untuk toggle OFF)
-- ============================================================
local function HideAllDrawings()
    for i = 1, MAX_SLOTS do
        if DrawingPool.BoxOutline[i] then DrawingPool.BoxOutline[i].Visible = false end
        if DrawingPool.Box[i] then DrawingPool.Box[i].Visible = false end
        if DrawingPool.TeamName[i] then DrawingPool.TeamName[i].Visible = false end
        if DrawingPool.Bones[i] then
            for j = 1, 14 do
                if DrawingPool.Bones[i][j] then
                    DrawingPool.Bones[i][j].Visible = false
                end
            end
        end
    end
    FOVCircle = nil  -- nanti di-recreate
    CurrentAimTarget = nil
end

-- ============================================================
-- GUI
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ESPGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game.CoreGui

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 120, 0, 35)
ToggleButton.Position = UDim2.new(0, 10, 0, 10)
ToggleButton.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
ToggleButton.BorderSizePixel = 0
ToggleButton.Text = "ESP: ON"
ToggleButton.TextColor3 = Color3.fromRGB(85, 255, 127)
ToggleButton.TextSize = 14
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 6)
Corner.Parent = ToggleButton

local AimbotButton = Instance.new("TextButton")
AimbotButton.Size = UDim2.new(0, 120, 0, 35)
AimbotButton.Position = UDim2.new(0, 10, 0, 55)
AimbotButton.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
AimbotButton.BorderSizePixel = 0
AimbotButton.Text = "AIMBOT: ON"
AimbotButton.TextColor3 = Color3.fromRGB(85, 255, 127)
AimbotButton.TextSize = 14
AimbotButton.Font = Enum.Font.GothamBold
AimbotButton.Parent = ScreenGui

local AimbotCorner = Instance.new("UICorner")
AimbotCorner.CornerRadius = UDim.new(0, 6)
AimbotCorner.Parent = AimbotButton

local CleanButton = Instance.new("TextButton")
CleanButton.Size = UDim2.new(0, 120, 0, 28)
CleanButton.Position = UDim2.new(0, 10, 0, 100)
CleanButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
CleanButton.BorderSizePixel = 0
CleanButton.Text = "🧹 CLEAN"
CleanButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CleanButton.TextSize = 13
CleanButton.Font = Enum.Font.GothamBold
CleanButton.Parent = ScreenGui

local CleanCorner = Instance.new("UICorner")
CleanCorner.CornerRadius = UDim.new(0, 6)
CleanCorner.Parent = CleanButton

local FOVFrame = Instance.new("Frame")
FOVFrame.Size = UDim2.new(0, 120, 0, 45)
FOVFrame.Position = UDim2.new(0, 10, 0, 135)
FOVFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
FOVFrame.BorderSizePixel = 0
FOVFrame.Parent = ScreenGui

local FOVFrameCorner = Instance.new("UICorner")
FOVFrameCorner.CornerRadius = UDim.new(0, 6)
FOVFrameCorner.Parent = FOVFrame

local FOVLabel = Instance.new("TextLabel")
FOVLabel.Size = UDim2.new(1, 0, 0, 18)
FOVLabel.Position = UDim2.new(0, 0, 0, 2)
FOVLabel.BackgroundTransparency = 1
FOVLabel.Text = "FOV: " .. FOVRadius
FOVLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
FOVLabel.TextSize = 12
FOVLabel.Font = Enum.Font.GothamBold
FOVLabel.Parent = FOVFrame

local SliderBg = Instance.new("Frame")
SliderBg.Size = UDim2.new(0, 104, 0, 8)
SliderBg.Position = UDim2.new(0, 8, 0, 26)
SliderBg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
SliderBg.BorderSizePixel = 0
SliderBg.Parent = FOVFrame

local SliderBgCorner = Instance.new("UICorner")
SliderBgCorner.CornerRadius = UDim.new(1, 0)
SliderBgCorner.Parent = SliderBg

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new((FOVRadius - FOVMin) / (FOVMax - FOVMin), 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
SliderFill.BorderSizePixel = 0
SliderFill.Parent = SliderBg

local SliderFillCorner = Instance.new("UICorner")
SliderFillCorner.CornerRadius = UDim.new(1, 0)
SliderFillCorner.Parent = SliderFill

local SliderKnob = Instance.new("Frame")
SliderKnob.Size = UDim2.new(0, 12, 0, 12)
SliderKnob.Position = UDim2.new((FOVRadius - FOVMin) / (FOVMax - FOVMin), 0, 0.5, 0)
SliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
SliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
SliderKnob.BorderSizePixel = 0
SliderKnob.Parent = SliderBg

local SliderKnobCorner = Instance.new("UICorner")
SliderKnobCorner.CornerRadius = UDim.new(1, 0)
SliderKnobCorner.Parent = SliderKnob

local sliderDragging = false

local function UpdateSliderVisual(ratio)
    ratio = math.clamp(ratio, 0, 1)
    SliderFill.Size = UDim2.new(ratio, 0, 1, 0)
    SliderKnob.Position = UDim2.new(ratio, 0, 0.5, 0)
    FOVRadius = math.floor(FOVMin + (FOVMax - FOVMin) * ratio + 0.5)
    FOVLabel.Text = "FOV: " .. FOVRadius
    if FOVCircle then FOVCircle.Radius = FOVRadius end
end

SliderBg.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        sliderDragging = true
        UpdateSliderVisual(math.clamp((input.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1))
    end
end)
SliderKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        sliderDragging = true
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if sliderDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        UpdateSliderVisual(math.clamp((input.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1))
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        sliderDragging = false
    end
end)

-- Mode Frame
local ModeFrame = Instance.new("Frame")
ModeFrame.Size = UDim2.new(0, 120, 0, 90)
ModeFrame.Position = UDim2.new(0, 10, 0, 190)
ModeFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
ModeFrame.BorderSizePixel = 0
ModeFrame.Parent = ScreenGui

local ModeFrameCorner = Instance.new("UICorner")
ModeFrameCorner.CornerRadius = UDim.new(0, 6)
ModeFrameCorner.Parent = ModeFrame

local ModeLabel = Instance.new("TextLabel")
ModeLabel.Size = UDim2.new(1, 0, 0, 18)
ModeLabel.Position = UDim2.new(0, 0, 0, 2)
ModeLabel.BackgroundTransparency = 1
ModeLabel.Text = "AIM TARGET"
ModeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
ModeLabel.TextSize = 11
ModeLabel.Font = Enum.Font.GothamBold
ModeLabel.Parent = ModeFrame

local BothBtn = Instance.new("TextButton")
BothBtn.Size = UDim2.new(0, 104, 0, 20)
BothBtn.Position = UDim2.new(0, 8, 0, 22)
BothBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
BothBtn.BorderSizePixel = 0
BothBtn.Text = "BOTH"
BothBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
BothBtn.TextSize = 11
BothBtn.Font = Enum.Font.GothamBold
BothBtn.Parent = ModeFrame

local BothCorner = Instance.new("UICorner")
BothCorner.CornerRadius = UDim.new(0, 4)
BothCorner.Parent = BothBtn

local SeekerBtn = Instance.new("TextButton")
SeekerBtn.Size = UDim2.new(0, 104, 0, 20)
SeekerBtn.Position = UDim2.new(0, 8, 0, 44)
SeekerBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
SeekerBtn.BorderSizePixel = 0
SeekerBtn.Text = "SEEKER"
SeekerBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
SeekerBtn.TextSize = 11
SeekerBtn.Font = Enum.Font.GothamBold
SeekerBtn.Parent = ModeFrame

local SeekerCorner = Instance.new("UICorner")
SeekerCorner.CornerRadius = UDim.new(0, 4)
SeekerCorner.Parent = SeekerBtn

local HiderBtn = Instance.new("TextButton")
HiderBtn.Size = UDim2.new(0, 104, 0, 20)
HiderBtn.Position = UDim2.new(0, 8, 0, 66)
HiderBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
HiderBtn.BorderSizePixel = 0
HiderBtn.Text = "HIDER"
HiderBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
HiderBtn.TextSize = 11
HiderBtn.Font = Enum.Font.GothamBold
HiderBtn.Parent = ModeFrame

local HiderCorner = Instance.new("UICorner")
HiderCorner.CornerRadius = UDim.new(0, 4)
HiderCorner.Parent = HiderBtn

local TargetLabel = Instance.new("TextLabel")
TargetLabel.Size = UDim2.new(0, 120, 0, 20)
TargetLabel.Position = UDim2.new(0, 10, 0, 285)
TargetLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
TargetLabel.BorderSizePixel = 0
TargetLabel.Text = "Target: -"
TargetLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
TargetLabel.TextSize = 11
TargetLabel.Font = Enum.Font.GothamBold
TargetLabel.Parent = ScreenGui

local TargetLabelCorner = Instance.new("UICorner")
TargetLabelCorner.CornerRadius = UDim.new(0, 4)
TargetLabelCorner.Parent = TargetLabel

-- ============================================================
-- FOV CIRCLE
-- ============================================================
local function CreateFOVCircle()
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Radius = FOVRadius
    FOVCircle.Filled = false
    FOVCircle.Color = Color3.fromRGB(255, 85, 85)
    FOVCircle.Thickness = 2
    FOVCircle.Transparency = 1
    FOVCircle.Visible = AimbotEnabled
    FOVCircle.NumSides = 60
    local camera = workspace.CurrentCamera
    if camera then
        FOVCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    end
    table.insert(getgenv().KryoDrawings, FOVCircle)
end

CreateFOVCircle()

local function UpdateFOVCircleColor()
    if not FOVCircle then return end
    if AimMode == "BOTH" then
        FOVCircle.Color = Color3.fromRGB(255, 85, 85)
    elseif AimMode == "SEEKER" then
        FOVCircle.Color = Color3.fromRGB(255, 200, 0)
    elseif AimMode == "HIDER" then
        FOVCircle.Color = Color3.fromRGB(85, 170, 255)
    end
end

local function UpdateModeVisual()
    BothBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    BothBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    SeekerBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    SeekerBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    HiderBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    HiderBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    
    if AimMode == "BOTH" then
        BothBtn.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
        BothBtn.TextColor3 = Color3.fromRGB(20, 20, 25)
    elseif AimMode == "SEEKER" then
        SeekerBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
        SeekerBtn.TextColor3 = Color3.fromRGB(20, 20, 25)
    elseif AimMode == "HIDER" then
        HiderBtn.BackgroundColor3 = Color3.fromRGB(85, 170, 255)
        HiderBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
    UpdateFOVCircleColor()
end

BothBtn.MouseButton1Click:Connect(function() AimMode = "BOTH" UpdateModeVisual() end)
SeekerBtn.MouseButton1Click:Connect(function() AimMode = "SEEKER" UpdateModeVisual() end)
HiderBtn.MouseButton1Click:Connect(function() AimMode = "HIDER" UpdateModeVisual() end)

UpdateModeVisual()

local function UpdateFOVCirclePosition()
    if not FOVCircle then return end
    local camera = workspace.CurrentCamera
    if camera then
        FOVCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    end
end

workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateFOVCirclePosition)

-- ============================================================
-- TOGGLE ESP — OFF = HideAllDrawings, ON = rebuild
-- ============================================================
ToggleButton.MouseButton1Click:Connect(function()
    ESPEnabled = not ESPEnabled
    ToggleButton.Text = ESPEnabled and "ESP: ON" or "ESP: OFF"
    ToggleButton.TextColor3 = ESPEnabled and Color3.fromRGB(85, 255, 127) or Color3.fromRGB(255, 85, 85)
    
    if not ESPEnabled then
        -- Matikan: cukup hide, tidak remove
        HideAllDrawings()
        ESPObjects = {}
        SlotInUse = {}
    else
        -- Hidupkan: rebuild slot untuk semua player
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local slot = AllocSlot(player)
                if slot then
                    ESPObjects[player] = { Slot = slot, LastValidTime = tick() }
                end
            end
        end
    end
end)

CleanButton.MouseButton1Click:Connect(function()
    HideAllDrawings()
    ESPObjects = {}
    SlotInUse = {}
    
    if ESPEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local slot = AllocSlot(player)
                if slot then
                    ESPObjects[player] = { Slot = slot, LastValidTime = tick() }
                end
            end
        end
    end
    print("[ESP] Cleaned.")
end)

AimbotButton.MouseButton1Click:Connect(function()
    AimbotEnabled = not AimbotEnabled
    AimbotButton.Text = AimbotEnabled and "AIMBOT: ON" or "AIMBOT: OFF"
    AimbotButton.TextColor3 = AimbotEnabled and Color3.fromRGB(85, 255, 127) or Color3.fromRGB(255, 85, 85)
    if FOVCircle then FOVCircle.Visible = AimbotEnabled end
end)

-- ============================================================
-- DRAGGING
-- ============================================================
local function MakeDraggable(frame)
    local dragging, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    frame.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            if not sliderDragging then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end)
    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

MakeDraggable(ToggleButton)
MakeDraggable(AimbotButton)
MakeDraggable(CleanButton)
MakeDraggable(FOVFrame)
MakeDraggable(ModeFrame)

-- ============================================================
-- ESP LOGIC (pakai pool slot, bukan create/remove per player)
-- ============================================================
local function GetTeamColor(player)
    if player.Team then return player.Team.TeamColor.Color end
    return Color3.new(1, 1, 1)
end

local function WorldToScreen(position)
    local camera = workspace.CurrentCamera
    local screenPos, onScreen = camera:WorldToViewportPoint(position)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local function IsGameInRevealOrLobby()
    local camera = workspace.CurrentCamera
    if not camera then return true end
    if camera.CameraType == Enum.CameraType.Scriptable then return true end
    local myChar = LocalPlayer.Character
    local myHumanoid = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if myHumanoid and camera.CameraSubject ~= myHumanoid then return true end
    if not myChar or myChar.Parent ~= workspace then return true end
    return false
end

local function GetBodyPart(character, partName)
    if not character then return nil end
    local part = character:FindFirstChild(partName)
    if part and part:IsA("BasePart") then return part.Position end
    if partName == "Head" then
        part = character:FindFirstChild("Head")
    elseif partName == "UpperTorso" or partName == "LowerTorso" then
        part = character:FindFirstChild("Torso")
    elseif partName:find("Arm") or partName:find("Hand") then
        part = character:FindFirstChild("Left Arm") or character:FindFirstChild("Right Arm")
    elseif partName:find("Leg") or partName:find("Foot") then
        part = character:FindFirstChild("Left Leg") or character:FindFirstChild("Right Leg")
    end
    if part and part:IsA("BasePart") then return part.Position end
    return nil
end

local boneConnections = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"}, {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"}, {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
}

local function HideSlotDrawings(slot)
    if DrawingPool.BoxOutline[slot] then DrawingPool.BoxOutline[slot].Visible = false end
    if DrawingPool.Box[slot] then DrawingPool.Box[slot].Visible = false end
    if DrawingPool.TeamName[slot] then DrawingPool.TeamName[slot].Visible = false end
    if DrawingPool.Bones[slot] then
        for j = 1, 14 do
            DrawingPool.Bones[slot][j].Visible = false
        end
    end
end

local function UpdateESPForPlayer(player)
    if player == LocalPlayer then return end
    
    local obj = ESPObjects[player]
    if not obj then return end
    
    local slot = obj.Slot
    if not slot then return end
    
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    
    -- Validasi
    if not ESPEnabled 
       or not character 
       or character.Parent ~= workspace
       or not humanoid 
       or humanoid.Health <= 0 
       or not hrp then
        HideSlotDrawings(slot)
        return
    end
    
    local teamColor = GetTeamColor(player)
    if CurrentAimTarget == player then
        teamColor = Color3.fromRGB(255, 255, 0)
    end
    
    local headPos, headVisible = WorldToScreen(hrp.Position + Vector3.new(0, 3, 0))
    local footPos, footVisible = WorldToScreen(hrp.Position - Vector3.new(0, 3, 0))
    
    if headVisible and footVisible then
        local height = math.abs(headPos.Y - footPos.Y)
        local width = height * 0.6
        
        if height == height and width == width and height > 1 and width > 1 and height < 5000 then
            -- Box Outline
            DrawingPool.BoxOutline[slot].Size = Vector2.new(width, height)
            DrawingPool.BoxOutline[slot].Position = Vector2.new(footPos.X - width/2, headPos.Y)
            DrawingPool.BoxOutline[slot].Visible = true
            
            -- Box
            DrawingPool.Box[slot].Size = Vector2.new(width, height)
            DrawingPool.Box[slot].Position = Vector2.new(footPos.X - width/2, headPos.Y)
            DrawingPool.Box[slot].Color = teamColor
            DrawingPool.Box[slot].Visible = true
            
            -- Team Name
            local teamText = player.Team and player.Team.Name or "No Team"
            DrawingPool.TeamName[slot].Text = string.format("%s [%s]", player.Name, teamText)
            DrawingPool.TeamName[slot].Position = Vector2.new(footPos.X, headPos.Y - 15)
            DrawingPool.TeamName[slot].Color = teamColor
            DrawingPool.TeamName[slot].Visible = true
            
            obj.LastValidTime = tick()
        else
            HideSlotDrawings(slot)
        end
    else
        HideSlotDrawings(slot)
    end
    
    -- Bones
    if DrawingPool.Box[slot].Visible then
        for i, connection in ipairs(boneConnections) do
            local bone = DrawingPool.Bones[slot][i]
            local p1 = GetBodyPart(character, connection[1])
            local p2 = GetBodyPart(character, connection[2])
            if p1 and p2 then
                local s1, v1 = WorldToScreen(p1)
                local s2, v2 = WorldToScreen(p2)
                if v1 and v2 then
                    bone.From = s1
                    bone.To = s2
                    bone.Color = teamColor
                    bone.Visible = true
                else
                    bone.Visible = false
                end
            else
                bone.Visible = false
            end
        end
    else
        for i = 1, 14 do
            DrawingPool.Bones[slot][i].Visible = false
        end
    end
end

-- ============================================================
-- AIMBOT
-- ============================================================
local function MatchTeamName(teamName, list)
    if not teamName then return false end
    local lower = string.lower(teamName)
    for _, name in ipairs(list) do
        if lower == string.lower(name) then return true end
        if string.find(lower, string.lower(name), 1, true) then return true end
    end
    return false
end

local function IsValidAimTarget(player)
    if player == LocalPlayer then return false end
    if AimMode == "BOTH" then return true end
    local teamName = player.Team and player.Team.Name or ""
    if AimMode == "SEEKER" then
        return MatchTeamName(teamName, TEAM_SEEKER_NAMES)
    elseif AimMode == "HIDER" then
        return MatchTeamName(teamName, TEAM_HIDER_NAMES)
    end
    return false
end

local function GetClosestPlayerInFOV()
    local closestPlayer = nil
    local shortestDistance = FOVRadius
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    for _, player in ipairs(Players:GetPlayers()) do
        if IsValidAimTarget(player) and player.Character then
            local char = player.Character
            if char.Parent == workspace then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local tp = char:FindFirstChild(AimPart)
                if hum and hum.Health > 0 and tp then
                    local sp, onScreen = camera:WorldToViewportPoint(tp.Position)
                    if onScreen and sp.Z > 0 then
                        local dist = (Vector2.new(sp.X, sp.Y) - screenCenter).Magnitude
                        if dist < shortestDistance then
                            shortestDistance = dist
                            closestPlayer = player
                        end
                    end
                end
            end
        end
    end
    return closestPlayer
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then        HoldingRightClick = true
    end
end)
UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        HoldingRightClick = false
    end
end)

-- ============================================================
-- PLAYER MANAGEMENT
-- ============================================================
local function AddPlayerToESP(player)
    if player == LocalPlayer then return end
    if ESPObjects[player] then return end
    local slot = AllocSlot(player)
    if slot then
        ESPObjects[player] = { Slot = slot, LastValidTime = tick() }
    end
end

local function RemovePlayerFromESP(player)
    local obj = ESPObjects[player]
    if not obj then return end
    HideSlotDrawings(obj.Slot)
    FreeSlot(player)
    ESPObjects[player] = nil
end

local function RefreshESPPlayers()
    if not ESPEnabled then return end
    
    -- Hapus yang sudah tidak valid
    for player, _ in pairs(ESPObjects) do
        if player == LocalPlayer or player.Parent ~= Players then
            RemovePlayerFromESP(player)
        end
    end
    
    -- Tambah yang baru
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not ESPObjects[player] then
            AddPlayerToESP(player)
        end
    end
end

local function OnPlayerAdded(player)
    if player == LocalPlayer then return end
    player.CharacterAdded:Connect(function()
        if ESPEnabled and not ESPObjects[player] then
            AddPlayerToESP(player)
        end
    end)
    if ESPEnabled and player.Character then
        AddPlayerToESP(player)
    end
end

for _, player in pairs(Players:GetPlayers()) do OnPlayerAdded(player) end
Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
    RemovePlayerFromESP(player)
    if CurrentAimTarget == player then CurrentAimTarget = nil end
end)

-- ============================================================
-- MAIN LOOP
-- ============================================================
RunService.RenderStepped:Connect(function()
    UpdateFOVCirclePosition()
    
    if not ESPEnabled and not AimbotEnabled then return end
    
    if IsGameInRevealOrLobby() then
        for _, obj in pairs(ESPObjects) do
            HideSlotDrawings(obj.Slot)
        end
        CurrentAimTarget = nil
        TargetLabel.Text = "Target: -"
        return
    end
    
    if ESPEnabled then
        RefreshESPPlayers()
        for player, _ in pairs(ESPObjects) do
            pcall(UpdateESPForPlayer, player)
        end
    end
    
    if AimbotEnabled and HoldingRightClick then
        local target = GetClosestPlayerInFOV()
        CurrentAimTarget = target
        if target and target.Character then
            local tp = target.Character:FindFirstChild(AimPart)
            if tp then
                local camera = workspace.CurrentCamera
                camera.CFrame = camera.CFrame:Lerp(
                    CFrame.new(camera.CFrame.Position, tp.Position),
                    AimSmoothness
                )
            end
        end
    else
        CurrentAimTarget = nil
    end
    
    if CurrentAimTarget then
        TargetLabel.Text = "Target: " .. CurrentAimTarget.Name
    else
        TargetLabel.Text = "Target: -"
    end
end)
