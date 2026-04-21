-- LocalScript: StarterPlayerScripts/AnimalPickerUI
-- Modal animal picker. Opens on spawn and when P key is pressed.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(ReplicatedStorage:WaitForChild("Animals"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "AnimalPicker"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Enabled = false
gui.Parent = pg

local bg = Instance.new("Frame")
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.new(0, 0, 0)
bg.BackgroundTransparency = 0.35
bg.BorderSizePixel = 0
bg.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 70)
title.Position = UDim2.new(0, 0, 0.06, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "Pick Your Animal"
title.TextScaled = true
title.Font = Enum.Font.SourceSansBold
title.Parent = bg

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, 0, 0, 24)
hint.Position = UDim2.new(0, 0, 0.14, 0)
hint.BackgroundTransparency = 1
hint.TextColor3 = Color3.fromRGB(210, 210, 210)
hint.Text = "Press P to change animal any time · Space / F to attack"
hint.TextScaled = true
hint.Font = Enum.Font.SourceSans
hint.Parent = bg

local grid = Instance.new("Frame")
grid.Size = UDim2.new(0.82, 0, 0.64, 0)
grid.Position = UDim2.new(0.09, 0, 0.2, 0)
grid.BackgroundTransparency = 1
grid.Parent = bg

local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.new(0, 180, 0, 200)
layout.CellPadding = UDim2.new(0, 10, 0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Parent = grid

for i, a in ipairs(Animals) do
	local btn = Instance.new("TextButton")
	btn.LayoutOrder = i
	btn.BackgroundColor3 = Color3.fromRGB(55, 60, 80)
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.AutoButtonColor = true
	btn.Parent = grid

	local corner = Instance.new("UICorner", btn)
	corner.CornerRadius = UDim.new(0, 8)

	local emoji = Instance.new("TextLabel")
	emoji.Size = UDim2.new(1, 0, 0.55, 0)
	emoji.BackgroundTransparency = 1
	emoji.Text = a.emoji
	emoji.TextColor3 = Color3.new(1, 1, 1)
	emoji.TextScaled = true
	emoji.Font = Enum.Font.SourceSansBold
	emoji.Parent = btn

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0.18, 0)
	name.Position = UDim2.new(0, 0, 0.55, 0)
	name.BackgroundTransparency = 1
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = a.name
	name.TextScaled = true
	name.Font = Enum.Font.SourceSansBold
	name.Parent = btn

	local stats = Instance.new("TextLabel")
	stats.Size = UDim2.new(1, -10, 0.22, 0)
	stats.Position = UDim2.new(0, 5, 0.75, 0)
	stats.BackgroundTransparency = 1
	stats.TextColor3 = Color3.fromRGB(220, 220, 220)
	stats.Text = string.format("SPD %d  HP %d  ATK %d", a.speed, a.hp, a.atk)
	stats.TextScaled = true
	stats.Font = Enum.Font.SourceSans
	stats.Parent = btn

	btn.MouseButton1Click:Connect(function()
		Remotes.AnimalChosen:FireServer(a.id)
		gui.Enabled = false
	end)
end

Remotes.ShowPicker.OnClientEvent:Connect(function()
	gui.Enabled = true
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.P then
		gui.Enabled = not gui.Enabled
	end
end)
