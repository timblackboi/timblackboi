local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

local AimbotEnabled = false
local EspEnabled = false
local FullbrightEnabled = false
local FOV = 100 -- FOV radius in pixels

-- Create FOV circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Radius = FOV
FOVCircle.Color = Color3.new(0, 1, 0)
FOVCircle.Thickness = 1
FOVCircle.Filled = false
FOVCircle.Transparency = 0.5

-- Table to hold ESP boxes and text
local ESPObjects = {}

-- Fullbright original settings backup
local OriginalLightingSettings = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    GlobalShadows = Lighting.GlobalShadows,
}

-- Anti-detection measures
-- Use minimal footprint, avoid hooking core functions directly
-- Use RenderStepped for smooth updates
-- Randomize some timings to avoid pattern detection

local function isAlive(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function getClosestTarget()
    local closestPlayer = nil
    local shortestDistance = math.huge
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and isAlive(player.Character) then
            local head = player.Character:FindFirstChild("Head")
            if head then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local pos2d = Vector2.new(screenPos.X, screenPos.Y)
                    local dist = (pos2d - mousePos).Magnitude
                    if dist < FOV and dist < shortestDistance then
                        closestPlayer = player
                        shortestDistance = dist
                    end
                end
            end
        end
    end
    return closestPlayer
end

local function aimAt(target)
    if not target or not target.Character then return end
    local head = target.Character:FindFirstChild("Head")
    if not head then return end
    local cameraCFrame = Camera.CFrame
    local direction = (head.Position - cameraCFrame.Position).Unit
    local newCFrame = CFrame.new(cameraCFrame.Position, cameraCFrame.Position + direction)
    Camera.CFrame = newCFrame
end

local function createESP(player)
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = Color3.new(1, 0, 0)
    box.Thickness = 2
    box.Filled = false

    local distanceText = Drawing.new("Text")
    distanceText.Visible = false
    distanceText.Color = Color3.new(1, 1, 1)
    distanceText.Size = 14
    distanceText.Center = true
    distanceText.Outline = true
    distanceText.Font = 2

    ESPObjects[player] = {Box = box, DistanceText = distanceText}
end

local function removeESP(player)
    if ESPObjects[player] then
        ESPObjects[player].Box:Remove()
        ESPObjects[player].DistanceText:Remove()
        ESPObjects[player] = nil
    end
end

local function updateESP()
    for player, objects in pairs(ESPObjects) do
        if player.Character and isAlive(player.Character) then
            local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
            local head = player.Character:FindFirstChild("Head")
            if rootPart and head then
                local rootPos, onScreenRoot = Camera:WorldToViewportPoint(rootPart.Position)
                local headPos, onScreenHead = Camera:WorldToViewportPoint(head.Position)
                if onScreenRoot and onScreenHead then
                    local boxHeight = math.abs(headPos.Y - rootPos.Y)
                    local boxWidth = boxHeight / 2
                    local boxX = rootPos.X - boxWidth / 2
                    local boxY = headPos.Y

                    objects.Box.Visible = true
                    objects.Box.Size = Vector2.new(boxWidth, boxHeight)
                    objects.Box.Position = Vector2.new(boxX, boxY)

                    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude
                    local distanceMeters = math.floor(distance)
                    objects.DistanceText.Visible = true
                    objects.DistanceText.Position = Vector2.new(rootPos.X, rootPos.Y + boxHeight + 15)
                    objects.DistanceText.Text = distanceMeters .. "m"
                else
                    objects.Box.Visible = false
                    objects.DistanceText.Visible = false
                end
            else
                objects.Box.Visible = false
                objects.DistanceText.Visible = false
            end
        else
            objects.Box.Visible = false
            objects.DistanceText.Visible = false
        end
    end
end

local function toggleFullbright(enable)
    if enable then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.GlobalShadows = false
    else
        Lighting.Brightness = OriginalLightingSettings.Brightness
        Lighting.ClockTime = OriginalLightingSettings.ClockTime
        Lighting.FogEnd = OriginalLightingSettings.FogEnd
        Lighting.Ambient = OriginalLightingSettings.Ambient
        Lighting.OutdoorAmbient = OriginalLightingSettings.OutdoorAmbient
        Lighting.GlobalShadows = OriginalLightingSettings.GlobalShadows
    end
end

-- Initialize ESP for all players
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        createESP(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        createESP(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
end)

-- Toggle script on RightShift
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        AimbotEnabled = not AimbotEnabled
        EspEnabled = AimbotEnabled
        FullbrightEnabled = AimbotEnabled
        FOVCircle.Visible = AimbotEnabled
        toggleFullbright(FullbrightEnabled)
    end
end)

-- Main loop
RunService.RenderStepped:Connect(function()
    if AimbotEnabled then
        local target = getClosestTarget()
        if target then
            aimAt(target)
        end
    end

    if EspEnabled then
        updateESP()
    else
        for _, objects in pairs(ESPObjects) do
            objects.Box.Visible = false
            objects.DistanceText.Visible = false
        end
    end

    if FullbrightEnabled then
        -- Keep fullbright active (in case lighting changes)
        toggleFullbright(true)
    end

    -- Update FOV circle position
    if FOVCircle.Visible then
        FOVCircle.Position = Vector2.new(Mouse.X, Mouse.Y)
    end
end)
