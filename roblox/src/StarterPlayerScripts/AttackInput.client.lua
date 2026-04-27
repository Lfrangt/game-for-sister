-- LocalScript: StarterPlayerScripts/AttackInput
-- F (desktop) / touch button (mobile) / R2 (gamepad) -> fire attack.
--
-- NOTE: Space is intentionally NOT bound. Roblox uses Space for jump and
-- double-binding it caused players to attack every time they jumped. Use F
-- on desktop, the on-screen button on mobile, or R2 on a gamepad.

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local function fire()
	Remotes.AttackFired:FireServer()
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.F then
		fire()
	end
end)

ContextActionService:BindAction("AnimalsCTF_Attack", function(_, state)
	if state == Enum.UserInputState.Begin then fire() end
end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)

ContextActionService:SetTitle("AnimalsCTF_Attack", "⚔")

-- Mobile button placement
-- Roblox's default jump button sits roughly UDim2.new(1, -75, 1, -75) with
-- a ~70px size. We anchor the Attack button further LEFT and slightly UP so
-- the thumbs don't fight for the same screen real estate.
ContextActionService:SetPosition("AnimalsCTF_Attack", UDim2.new(1, -180, 1, -90))
