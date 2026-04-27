-- Server Script: ServerScriptService/BotManager
-- Spawns AI teammates so a single human player isn't alone on a team.
-- Bots wander toward enemy base, chase the nearest enemy, and attack in melee.
-- Bots do NOT pick up flags (yet) — they are combat support.
--
-- Tunable constants are at the top.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(ReplicatedStorage:WaitForChild("Animals"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

------------------------------------------------------------------
-- Tuning
------------------------------------------------------------------
local BOTS_PER_TEAM   = 3      -- set 0 to disable
local SIGHT_RADIUS    = 80     -- studs an enemy must be within to be a target
local THINK_INTERVAL  = 0.3    -- seconds between bot brain ticks
local RESPAWN_DELAY   = 4      -- seconds dead before respawning

local TEAM_COLORS = {
	Blue = BrickColor.new("Bright blue"),
	Red  = BrickColor.new("Bright red"),
}

local bots = {}  -- list of bot Models currently alive

------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------
local function randomAnimal()
	return Animals[math.random(1, #Animals)]
end

local function findAnimal(id)
	for _, a in ipairs(Animals) do
		if a.id == id then return a end
	end
	return Animals[1]
end

local function getBasePlate(teamName)
	for _, b in ipairs(CollectionService:GetTagged("Base")) do
		if b:GetAttribute("Team") == teamName then return b end
	end
end

local function enemyOf(teamName)
	return teamName == "Blue" and "Red" or "Blue"
end

------------------------------------------------------------------
-- Build a simple humanoid rig (block character)
------------------------------------------------------------------
local function buildRig(animal, teamName)
	local model = Instance.new("Model")
	model.Name = "Bot_" .. animal.id

	-- HumanoidRootPart (the torso Roblox uses to move characters)
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.BrickColor = TEAM_COLORS[teamName] or TEAM_COLORS.Blue
	hrp.Material = Enum.Material.SmoothPlastic
	hrp.TopSurface = Enum.SurfaceType.Smooth
	hrp.BottomSurface = Enum.SurfaceType.Smooth
	hrp.CanCollide = true
	hrp.Parent = model
	model.PrimaryPart = hrp

	-- Head — used to anchor the floating animal label
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.BrickColor = hrp.BrickColor
	head.CFrame = hrp.CFrame * CFrame.new(0, 1.6, 0)
	head.Parent = model
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = hrp
	headWeld.Part1 = head
	headWeld.Parent = head

	-- Humanoid — gives the rig walking, health, and damage handling
	local hum = Instance.new("Humanoid")
	hum.WalkSpeed = animal.speed
	hum.MaxHealth = animal.hp
	hum.Health = animal.hp
	hum.Parent = model

	-- Floating animal emoji (matches what players have)
	local bb = Instance.new("BillboardGui")
	bb.Name = "AnimalLabel"
	bb.Size = UDim2.new(0, 80, 0, 80)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = true
	bb.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = animal.emoji
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Parent = bb

	-- Tags + attributes
	CollectionService:AddTag(model, "Bot")
	model:SetAttribute("Team", teamName)
	model:SetAttribute("AnimalId", animal.id)
	model:SetAttribute("LastAttack", 0)

	return model, hum
end

------------------------------------------------------------------
-- Spawning + lifecycle
------------------------------------------------------------------
local spawnBot  -- forward declare for self-reference

spawnBot = function(teamName)
	local animal = randomAnimal()
	local rig, hum = buildRig(animal, teamName)
	local plate = getBasePlate(teamName)
	rig.Parent = workspace
	if plate then
		local jitter = Vector3.new(math.random(-6, 6), 4, math.random(-6, 6))
		rig:PivotTo(CFrame.new(plate.Position + jitter))
	end
	table.insert(bots, rig)

	hum.Died:Connect(function()
		for i, b in ipairs(bots) do
			if b == rig then table.remove(bots, i); break end
		end
		task.wait(RESPAWN_DELAY)
		if rig.Parent then rig:Destroy() end
		spawnBot(teamName)
	end)

	return rig
end

------------------------------------------------------------------
-- Targeting
------------------------------------------------------------------
local function findTarget(bot)
	local hrp = bot.PrimaryPart
	if not hrp then return nil end
	local myTeam = bot:GetAttribute("Team")
	local nearestPart, bestDist = nil, SIGHT_RADIUS

	-- Players on the enemy team
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Team and p.Team.Name ~= myTeam and p.Character then
			local pHrp = p.Character:FindFirstChild("HumanoidRootPart")
			local pHum = p.Character:FindFirstChildOfClass("Humanoid")
			if pHrp and pHum and pHum.Health > 0 then
				local d = (pHrp.Position - hrp.Position).Magnitude
				if d < bestDist then nearestPart = pHrp; bestDist = d end
			end
		end
	end

	-- Enemy bots
	for _, b in ipairs(bots) do
		if b ~= bot and b:GetAttribute("Team") ~= myTeam then
			local bHrp = b.PrimaryPart
			local bHum = b:FindFirstChildOfClass("Humanoid")
			if bHrp and bHum and bHum.Health > 0 then
				local d = (bHrp.Position - hrp.Position).Magnitude
				if d < bestDist then nearestPart = bHrp; bestDist = d end
			end
		end
	end

	return nearestPart, bestDist
end

------------------------------------------------------------------
-- One bot's brain tick
------------------------------------------------------------------
local function botUpdate(bot)
	local hum = bot:FindFirstChildOfClass("Humanoid")
	local hrp = bot.PrimaryPart
	if not hum or not hrp or hum.Health <= 0 then return end

	local target, distance = findTarget(bot)

	if not target then
		-- No enemy in sight: drift toward enemy base so the action goes somewhere
		local enemyBase = getBasePlate(enemyOf(bot:GetAttribute("Team")))
		if enemyBase then
			local jitter = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
			hum:MoveTo(enemyBase.Position + jitter)
		end
		return
	end

	-- Walk toward the target
	hum:MoveTo(target.Position)

	-- Attack if within melee range
	local animal = findAnimal(bot:GetAttribute("AnimalId"))
	if distance <= animal.range + 2 then
		local lastAttack = bot:GetAttribute("LastAttack")
		if tick() - lastAttack >= GameConfig.ATTACK_COOLDOWN then
			bot:SetAttribute("LastAttack", tick())
			local targetHum = target.Parent:FindFirstChildOfClass("Humanoid")
			if targetHum and targetHum.Health > 0 then
				targetHum:TakeDamage(animal.atk)
				local knockback = (target.Position - hrp.Position).Unit * 30 + Vector3.new(0, 10, 0)
				target.AssemblyLinearVelocity = knockback
			end
		end
	end
end

------------------------------------------------------------------
-- Heartbeat (throttled)
------------------------------------------------------------------
local accum = 0
RunService.Heartbeat:Connect(function(dt)
	accum = accum + dt
	if accum < THINK_INTERVAL then return end
	accum = 0
	for _, bot in ipairs(bots) do
		if bot.Parent then botUpdate(bot) end
	end
end)

------------------------------------------------------------------
-- Boot
------------------------------------------------------------------
while #CollectionService:GetTagged("Base") < 2 do task.wait(0.1) end
task.wait(3) -- give InitMap and the first players a moment

if BOTS_PER_TEAM > 0 then
	for _, teamName in ipairs({"Blue", "Red"}) do
		for _ = 1, BOTS_PER_TEAM do
			spawnBot(teamName)
			task.wait(0.3)
		end
	end
end
