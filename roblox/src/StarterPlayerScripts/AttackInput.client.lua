-- LocalScript: StarterPlayerScripts/AttackInput
-- Space (desktop) / touch button (mobile) / F (gamepad) -> fire attack.

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local function fire()
	Remotes.AttackFired:FireServer()
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.F then
		fire()
	end
end)

ContextActionService:BindAction("AnimalsCTF_Attack", function(_, state)
	if state == Enum.UserInputState.Begin then fire() end
end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
ContextActionService:SetTitle("AnimalsCTF_Attack", "Attack")
ContextActionService:SetPosition("AnimalsCTF_Attack", UDim2.new(1, -130, 1, -180))
