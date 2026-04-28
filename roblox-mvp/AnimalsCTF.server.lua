-- Server Script: paste into ServerScriptService as a single Script named "AnimalsCTF"
-- Animals CTF — Phase A MVP (bots + melee attack + F-key fix + sounds)
-- Also add roblox-mvp/AttackInput.client.lua and roblox-mvp/SoundManager.client.lua
-- to StarterPlayerScripts.

local Players           = game:GetService("Players")
local Teams             = game:GetService("Teams")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------------------------------------------------------
-- Config
------------------------------------------------------------------
local SCORE_LIMIT         = 3
local ROUND_SECONDS       = 180
local INTERMISSION        = 8
local CAPTURE_RADIUS      = 10
local ARENA_SIZE          = Vector3.new(200, 2, 140)

-- Attack
local ATTACK_RANGE    = 8     -- studs to hit
local ATTACK_DAMAGE   = 20
local ATTACK_COOLDOWN = 0.6   -- seconds between swings per player

-- Bots
local BOTS_PER_TEAM  = 3
local SIGHT_RADIUS   = 80
local THINK_INTERVAL = 0.3
local RESPAWN_DELAY  = 4

------------------------------------------------------------------
-- Animal roster (inline — no module required)
------------------------------------------------------------------
local ANIMALS = {
	{ id = "lion",     emoji = "🦁", speed = 22, hp = 120, atk = 22, range = 8 },
	{ id = "elephant", emoji = "🐘", speed = 14, hp = 220, atk = 28, range = 9 },
	{ id = "fox",      emoji = "🦊", speed = 32, hp = 80,  atk = 14, range = 7 },
	{ id = "gorilla",  emoji = "🦍", speed = 18, hp = 180, atk = 26, range = 8 },
	{ id = "kangaroo", emoji = "🦘", speed = 26, hp = 110, atk = 18, range = 7 },
	{ id = "cheetah",  emoji = "🐆", speed = 36, hp = 75,  atk = 15, range = 7 },
	{ id = "bear",     emoji = "🐻", speed = 20, hp = 170, atk = 24, range = 8 },
}
local TEAM_COLORS = {
	Blue = BrickColor.new("Bright blue"),
	Red  = BrickColor.new("Really red"),
}

------------------------------------------------------------------
-- RemoteEvents
------------------------------------------------------------------
local AttackFired = Instance.new("RemoteEvent")
AttackFired.Name   = "AttackFired"
AttackFired.Parent = ReplicatedStorage

-- SoundEvent: server notifies all clients of game events for sound playback
-- Payload: (eventName: string, arg: string?)
-- Events: "flagPickup", "flagReturn", "score", "death"
local SoundEvent = Instance.new("RemoteEvent")
SoundEvent.Name   = "SoundEvent"
SoundEvent.Parent = ReplicatedStorage

------------------------------------------------------------------
-- Teams
------------------------------------------------------------------
local function ensureTeam(name, color)
	local t = Teams:FindFirstChild(name)
	if not t then
		t = Instance.new("Team")
		t.Name = name
		t.TeamColor = color
		t.AutoAssignable = false
		t.Parent = Teams
	end
	return t
end
ensureTeam("Blue", BrickColor.new("Bright blue"))
ensureTeam("Red",  BrickColor.new("Really red"))

------------------------------------------------------------------
-- Remove stock spawn, build arena from scratch
------------------------------------------------------------------
for _, i in ipairs(Workspace:GetChildren()) do
	if i:IsA("SpawnLocation") then i:Destroy() end
end

local arena = Workspace:FindFirstChild("Arena")
if arena then arena:Destroy() end
arena = Instance.new("Folder")
arena.Name = "Arena"
arena.Parent = Workspace

local W, D = ARENA_SIZE.X, ARENA_SIZE.Z

local ground = Instance.new("Part")
ground.Name, ground.Size = "Ground", Vector3.new(W, 2, D)
ground.Position, ground.Anchored = Vector3.new(0, 0, 0), true
ground.Material, ground.BrickColor = Enum.Material.Grass, BrickColor.new("Bright green")
ground.TopSurface = Enum.SurfaceType.Smooth
ground.Parent = arena

local function wall(size, pos)
	local p = Instance.new("Part")
	p.Size, p.Position, p.Anchored = size, pos, true
	p.Material, p.BrickColor = Enum.Material.Wood, BrickColor.new("Reddish brown")
	p.Parent = arena
end
local wh = 10
wall(Vector3.new(W, wh, 2), Vector3.new(0, wh/2,  D/2))
wall(Vector3.new(W, wh, 2), Vector3.new(0, wh/2, -D/2))
wall(Vector3.new(2, wh, D), Vector3.new( W/2, wh/2, 0))
wall(Vector3.new(2, wh, D), Vector3.new(-W/2, wh/2, 0))

local function buildBase(teamName, color, xPos)
	local folder = Instance.new("Folder")
	folder.Name = teamName .. "Base"
	folder.Parent = arena

	local plate = Instance.new("Part")
	plate.Name, plate.Size = "Plate", Vector3.new(24, 1, 24)
	plate.Position, plate.Anchored = Vector3.new(xPos, 1.5, 0), true
	plate.Material, plate.BrickColor = Enum.Material.SmoothPlastic, color
	plate.Transparency = 0.3
	plate:SetAttribute("Team", teamName)
	CollectionService:AddTag(plate, "Base")
	plate.Parent = folder

	local sp = Instance.new("SpawnLocation")
	sp.Name, sp.Size = teamName .. "Spawn", Vector3.new(8, 1, 8)
	sp.Position, sp.Anchored = Vector3.new(xPos, 2.5, 0), true
	sp.TeamColor, sp.BrickColor = color, color
	sp.Material, sp.Transparency = Enum.Material.Neon, 0.4
	sp.Neutral, sp.AllowTeamChangeOnTouch = false, false
	sp.Parent = folder

	local polePos = Vector3.new(xPos, 7, -8)
	local pole = Instance.new("Part")
	pole.Name, pole.Size = "Pole", Vector3.new(0.5, 12, 0.5)
	pole.Position, pole.Anchored = polePos, true
	pole.Material = Enum.Material.Wood
	pole.BrickColor = BrickColor.new("Dark orange")
	pole.Parent = folder

	local flagPos = polePos + Vector3.new(2, 4, 0)
	local flag = Instance.new("Part")
	flag.Name, flag.Size = "Flag", Vector3.new(4, 3, 0.2)
	flag.Position, flag.Anchored = flagPos, true
	flag.CanCollide = false
	flag.Material, flag.BrickColor = Enum.Material.Fabric, color
	flag:SetAttribute("Team", teamName)
	flag:SetAttribute("AtHome", true)
	flag:SetAttribute("CarrierUserId", 0)
	flag:SetAttribute("HomePosition", flagPos)
	CollectionService:AddTag(flag, "Flag")
	flag.Parent = folder

	local bb = Instance.new("BillboardGui")
	bb.Adornee, bb.Size = pole, UDim2.new(0, 140, 0, 40)
	bb.StudsOffset, bb.AlwaysOnTop = Vector3.new(0, 8, 0), true
	bb.Parent = pole
	local lbl = Instance.new("TextLabel")
	lbl.Size, lbl.BackgroundTransparency = UDim2.new(1, 0, 1, 0), 1
	lbl.Text, lbl.TextColor3 = teamName:upper() .. " FLAG", color.Color
	lbl.TextStrokeTransparency, lbl.TextScaled = 0, true
	lbl.Font = Enum.Font.SourceSansBold
	lbl.Parent = bb
end
buildBase("Blue", BrickColor.new("Bright blue"), -W/2 + 20)
buildBase("Red",  BrickColor.new("Really red"),   W/2 - 20)

------------------------------------------------------------------
-- Game state
------------------------------------------------------------------
local phase = "playing"
local timeLeft = ROUND_SECONDS
local scores = { Blue = 0, Red = 0 }

local function getFlag(team)
	for _, f in ipairs(CollectionService:GetTagged("Flag")) do
		if f:GetAttribute("Team") == team then return f end
	end
end
local function getPlate(team)
	for _, b in ipairs(CollectionService:GetTagged("Base")) do
		if b:GetAttribute("Team") == team then return b end
	end
end

------------------------------------------------------------------
-- Flag mechanics
------------------------------------------------------------------
local function clearWelds(flag)
	for _, c in ipairs(flag:GetChildren()) do
		if c:IsA("WeldConstraint") then c:Destroy() end
	end
end
local function returnHome(flag)
	clearWelds(flag)
	flag.Anchored, flag.CanCollide = true, false
	flag.Position = flag:GetAttribute("HomePosition")
	flag:SetAttribute("CarrierUserId", 0)
	flag:SetAttribute("AtHome", true)
end
local function drop(flag, pos)
	clearWelds(flag)
	flag.Anchored, flag.CanCollide = true, false
	flag.Position = pos + Vector3.new(0, 3, 0)
	flag:SetAttribute("CarrierUserId", 0)
	flag:SetAttribute("AtHome", false)
end
local function attach(flag, char)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	clearWelds(flag)
	flag.Anchored, flag.CanCollide = false, false
	flag.CFrame = hrp.CFrame * CFrame.new(0, 6, 0)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = hrp, flag
	w.Parent = flag
end
local function dropHeldBy(uid, pos)
	for _, f in ipairs(CollectionService:GetTagged("Flag")) do
		if f:GetAttribute("CarrierUserId") == uid then drop(f, pos) end
	end
end

for _, flag in ipairs(CollectionService:GetTagged("Flag")) do
	flag.Touched:Connect(function(hit)
		if phase ~= "playing" then return end
		local char = hit.Parent
		local plr = Players:GetPlayerFromCharacter(char)
		if not plr or not plr.Team then return end
		if flag:GetAttribute("CarrierUserId") ~= 0 then return end

		local fTeam, pTeam = flag:GetAttribute("Team"), plr.Team.Name
		if pTeam ~= fTeam then
			flag:SetAttribute("CarrierUserId", plr.UserId)
			flag:SetAttribute("AtHome", false)
			attach(flag, char)
			SoundEvent:FireAllClients("flagPickup", pTeam)
		elseif not flag:GetAttribute("AtHome") then
			returnHome(flag)
			SoundEvent:FireAllClients("flagReturn", fTeam)
		end
	end)
end

------------------------------------------------------------------
-- Match control
------------------------------------------------------------------
local function resetRound()
	scores.Blue, scores.Red = 0, 0
	timeLeft = ROUND_SECONDS
	for _, f in ipairs(CollectionService:GetTagged("Flag")) do returnHome(f) end
	for _, p in ipairs(Players:GetPlayers()) do
		p:LoadCharacter()
		local ls = p:FindFirstChild("leaderstats")
		if ls then
			if ls:FindFirstChild("Blue") then ls.Blue.Value = 0 end
			if ls:FindFirstChild("Red")  then ls.Red.Value  = 0 end
		end
	end
end

local function updateLeaderstats()
	for _, p in ipairs(Players:GetPlayers()) do
		local ls = p:FindFirstChild("leaderstats")
		if ls then
			if ls:FindFirstChild("Blue") then ls.Blue.Value = scores.Blue end
			if ls:FindFirstChild("Red")  then ls.Red.Value  = scores.Red  end
		end
	end
end

local function endRound(winner)
	phase = "ended"
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character and p.Character:FindFirstChild("Head") then
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.new(0, 400, 0, 60)
			bb.StudsOffset = Vector3.new(0, 4, 0)
			bb.AlwaysOnTop = true
			bb.Adornee = p.Character.Head
			bb.Parent = p.Character.Head
			local l = Instance.new("TextLabel")
			l.Size, l.BackgroundTransparency = UDim2.new(1,0,1,0), 0.3
			l.BackgroundColor3 = Color3.new(0,0,0)
			l.TextColor3 = Color3.new(1,1,1)
			l.TextScaled = true
			l.Font = Enum.Font.SourceSansBold
			l.Text = winner == "Draw"
				and string.format("DRAW  %d – %d", scores.Blue, scores.Red)
				or  string.format("%s WINS!  %d – %d", winner:upper(), scores.Blue, scores.Red)
			l.Parent = bb
			task.delay(INTERMISSION - 1, function() bb:Destroy() end)
		end
	end
	task.wait(INTERMISSION)
	resetRound()
	phase = "playing"
end

local function awardScore(team)
	scores[team] = scores[team] + 1
	updateLeaderstats()
	SoundEvent:FireAllClients("score", team)
	if scores[team] >= SCORE_LIMIT then endRound(team) end
end

-- Capture check
RunService.Heartbeat:Connect(function()
	if phase ~= "playing" then return end
	for _, f in ipairs(CollectionService:GetTagged("Flag")) do
		local uid = f:GetAttribute("CarrierUserId")
		if uid ~= 0 then
			local carrier = Players:GetPlayerByUserId(uid)
			if carrier and carrier.Character and carrier.Team then
				local hrp = carrier.Character:FindFirstChild("HumanoidRootPart")
				local ownPlate = getPlate(carrier.Team.Name)
				local ownFlag  = getFlag(carrier.Team.Name)
				if hrp and ownPlate and ownFlag and ownFlag:GetAttribute("AtHome") then
					if (hrp.Position - ownPlate.Position).Magnitude < CAPTURE_RADIUS then
						returnHome(f)
						awardScore(carrier.Team.Name)
					end
				end
			end
		end
	end
end)

-- Timer
task.spawn(function()
	while #Players:GetPlayers() == 0 do task.wait(1) end
	task.wait(3)
	while true do
		task.wait(1)
		if phase == "playing" then
			timeLeft = timeLeft - 1
			if timeLeft <= 0 then
				local w
				if scores.Blue > scores.Red then w = "Blue"
				elseif scores.Red > scores.Blue then w = "Red"
				else w = "Draw" end
				endRound(w)
			end
		end
	end
end)

------------------------------------------------------------------
-- Player join / team balance / leaderstats
------------------------------------------------------------------
local lastAttackTimes = {}

Players.PlayerAdded:Connect(function(player)
	local b, r = 0, 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Team then
			if p.Team.Name == "Blue" then b = b + 1
			elseif p.Team.Name == "Red" then r = r + 1 end
		end
	end
	local team = (b <= r) and Teams.Blue or Teams.Red
	player.Team = team
	player.TeamColor = team.TeamColor

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	local blue = Instance.new("IntValue"); blue.Name = "Blue"; blue.Value = scores.Blue; blue.Parent = ls
	local red  = Instance.new("IntValue"); red.Name  = "Red";  red.Value  = scores.Red;  red.Parent  = ls

	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		hum.Died:Connect(function()
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then dropHeldBy(player.UserId, hrp.Position) end
			SoundEvent:FireClient(player, "death")
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttackTimes[player.UserId] = nil
	if player.Character then
		local hrp = player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then dropHeldBy(player.UserId, hrp.Position) end
	end
end)

------------------------------------------------------------------
-- Player attack handler (F key fires AttackFired from client)
------------------------------------------------------------------
local bots = {}  -- populated below

AttackFired.OnServerEvent:Connect(function(player)
	if phase ~= "playing" then return end
	if not player.Character or not player.Team then return end

	local now = tick()
	if (now - (lastAttackTimes[player.UserId] or 0)) < ATTACK_COOLDOWN then return end
	lastAttackTimes[player.UserId] = now

	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Hit enemy players
	for _, target in ipairs(Players:GetPlayers()) do
		if target ~= player and target.Team and target.Team.Name ~= player.Team.Name then
			if target.Character then
				local tHrp = target.Character:FindFirstChild("HumanoidRootPart")
				local tHum = target.Character:FindFirstChildOfClass("Humanoid")
				if tHrp and tHum and tHum.Health > 0 then
					if (tHrp.Position - hrp.Position).Magnitude <= ATTACK_RANGE then
						tHum:TakeDamage(ATTACK_DAMAGE)
						tHrp.AssemblyLinearVelocity = (tHrp.Position - hrp.Position).Unit * 30 + Vector3.new(0, 10, 0)
					end
				end
			end
		end
	end

	-- Hit enemy bots
	for _, bot in ipairs(bots) do
		if bot.Parent and bot:GetAttribute("Team") ~= player.Team.Name then
			local bHrp = bot.PrimaryPart
			local bHum = bot:FindFirstChildOfClass("Humanoid")
			if bHrp and bHum and bHum.Health > 0 then
				if (bHrp.Position - hrp.Position).Magnitude <= ATTACK_RANGE then
					bHum:TakeDamage(ATTACK_DAMAGE)
				end
			end
		end
	end
end)

------------------------------------------------------------------
-- Bot system (AI teammates)
-- Bots wander toward enemy base, chase nearest enemy, attack melee.
-- Tuning: BOTS_PER_TEAM / SIGHT_RADIUS / THINK_INTERVAL / RESPAWN_DELAY
------------------------------------------------------------------
local function randomAnimal()
	return ANIMALS[math.random(1, #ANIMALS)]
end

local function buildBotRig(animal, teamName)
	local model = Instance.new("Model")
	model.Name = "Bot_" .. animal.id

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

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.BrickColor = hrp.BrickColor
	head.CFrame = hrp.CFrame * CFrame.new(0, 1.6, 0)
	head.Parent = model
	local hw = Instance.new("WeldConstraint")
	hw.Part0, hw.Part1 = hrp, head
	hw.Parent = head

	local hum = Instance.new("Humanoid")
	hum.WalkSpeed = animal.speed
	hum.MaxHealth = animal.hp
	hum.Health = animal.hp
	hum.Parent = model

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 60, 0, 60)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = true
	bb.Parent = head
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = animal.emoji
	lbl.TextScaled = true
	lbl.Font = Enum.Font.SourceSansBold
	lbl.Parent = bb

	CollectionService:AddTag(model, "Bot")
	model:SetAttribute("Team", teamName)
	model:SetAttribute("AnimalId", animal.id)
	model:SetAttribute("AnimalRange", animal.range)
	model:SetAttribute("AnimalAtk", animal.atk)
	model:SetAttribute("LastAttack", 0)

	return model, hum
end

local spawnBot
spawnBot = function(teamName)
	local animal = randomAnimal()
	local rig, hum = buildBotRig(animal, teamName)
	local plate = getPlate(teamName)
	rig.Parent = Workspace
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
end

local function findBotTarget(bot)
	local hrp = bot.PrimaryPart
	if not hrp then return nil, math.huge end
	local myTeam = bot:GetAttribute("Team")
	local best, bestDist = nil, SIGHT_RADIUS

	for _, p in ipairs(Players:GetPlayers()) do
		if p.Team and p.Team.Name ~= myTeam and p.Character then
			local pHrp = p.Character:FindFirstChild("HumanoidRootPart")
			local pHum = p.Character:FindFirstChildOfClass("Humanoid")
			if pHrp and pHum and pHum.Health > 0 then
				local d = (pHrp.Position - hrp.Position).Magnitude
				if d < bestDist then best = pHrp; bestDist = d end
			end
		end
	end
	for _, b in ipairs(bots) do
		if b ~= bot and b:GetAttribute("Team") ~= myTeam then
			local bHrp = b.PrimaryPart
			local bHum = b:FindFirstChildOfClass("Humanoid")
			if bHrp and bHum and bHum.Health > 0 then
				local d = (bHrp.Position - hrp.Position).Magnitude
				if d < bestDist then best = bHrp; bestDist = d end
			end
		end
	end
	return best, bestDist
end

local function botTick(bot)
	local hum = bot:FindFirstChildOfClass("Humanoid")
	local hrp = bot.PrimaryPart
	if not hum or not hrp or hum.Health <= 0 then return end

	local target, dist = findBotTarget(bot)
	if not target then
		local enemyPlate = getPlate(bot:GetAttribute("Team") == "Blue" and "Red" or "Blue")
		if enemyPlate then
			hum:MoveTo(enemyPlate.Position + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8)))
		end
		return
	end

	hum:MoveTo(target.Position)

	local range = bot:GetAttribute("AnimalRange") or 8
	local atk   = bot:GetAttribute("AnimalAtk")   or 20
	if dist <= range + 2 then
		local last = bot:GetAttribute("LastAttack")
		if tick() - last >= ATTACK_COOLDOWN then
			bot:SetAttribute("LastAttack", tick())
			local tHum = target.Parent:FindFirstChildOfClass("Humanoid")
			if tHum and tHum.Health > 0 then
				tHum:TakeDamage(atk)
				target.AssemblyLinearVelocity = (target.Position - hrp.Position).Unit * 30 + Vector3.new(0, 10, 0)
			end
		end
	end
end

local botAccum = 0
RunService.Heartbeat:Connect(function(dt)
	botAccum = botAccum + dt
	if botAccum < THINK_INTERVAL then return end
	botAccum = 0
	for _, bot in ipairs(bots) do
		if bot.Parent then botTick(bot) end
	end
end)

-- Spawn initial bots once the arena is ready
task.spawn(function()
	while #CollectionService:GetTagged("Base") < 2 do task.wait(0.1) end
	task.wait(2)
	if BOTS_PER_TEAM > 0 then
		for _, teamName in ipairs({"Blue", "Red"}) do
			for _ = 1, BOTS_PER_TEAM do
				spawnBot(teamName)
				task.wait(0.3)
			end
		end
	end
end)

print("[AnimalsCTF] Phase A ready — bots enabled, F-key attack active.")
