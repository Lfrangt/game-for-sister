-- LocalScript: paste into StarterPlayerScripts as "AttackInput"
-- F (desktop) / mobile ⚔ button / gamepad R2 → fires melee attack.
-- Space is intentionally NOT bound — Roblox uses it for jump.

local UserInputService     = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local SoundService         = game:GetService("SoundService")

local AttackFired = ReplicatedStorage:WaitForChild("AttackFired")

-- Attack swing sound (played locally on button press, no server round-trip needed)
-- REPLACE the SoundId below: search "sword swing" or "punch" in Toolbox → Creator Store → Audio → Free
local swingSound = Instance.new("Sound")
swingSound.SoundId = "rbxassetid://9125409831"  -- free hit SFX (verify in Toolbox)
swingSound.Volume  = 0.6
swingSound.Parent  = SoundService

local function fire()
	swingSound:Play()
	AttackFired:FireServer()
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.F then fire() end
end)

ContextActionService:BindAction("AnimalsCTF_Attack", function(_, state)
	if state == Enum.UserInputState.Begin then fire() end
end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)

ContextActionService:SetTitle("AnimalsCTF_Attack", "⚔")
-- Mobile button: left of the jump button so thumbs don't conflict
ContextActionService:SetPosition("AnimalsCTF_Attack", UDim2.new(1, -180, 1, -90))
