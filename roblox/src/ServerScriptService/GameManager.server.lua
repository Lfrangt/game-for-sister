-- Server Script: ServerScriptService/GameManager
-- Owns all gameplay state: team assignment, animal stats, combat,
-- flag pickup/drop/return/score, match timer and win condition.

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(ReplicatedStorage:WaitForChild("Animals"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

-- Wait until InitMap has placed flags/bases
while #CollectionService:GetTagged("Flag") < 2 or #CollectionService:GetTagged("Base") < 2 do
	task.wait(0.1)
end

------------------------------------------------------------------
-- Match state
------------------------------------------------------------------
local matchState = {
	phase = "waiting",   -- waiting | playing | ended
	timeLeft = 0,
	scores = { Blue = 0, Red = 0 },
}
local playerStates = {} -- [Player] = { lastAttack = number }

local function findAnimal(id)
	for _, a in ipairs(Animals) do
		if a.id == id then return a end
	end
	return Animals[1]
end

local function getTeam(name) return Teams:FindFirstChild(name) end

local function getFlag(teamName)
	for _, f in ipairs(CollectionService:GetTagged("Flag")) do
		if f:GetAttribute("Team") == teamName then return f end
	end
end

local function getBasePlate(teamName)
	for _, b in ipairs(CollectionService:GetTagged("Base")) do
		if b:GetAttribute("Team") == teamName then return b end
	end
end

------------------------------------------------------------------
-- Team assignment
------------------------------------------------------------------
local function assignTeam(player)
	local blue, red = 0, 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Team then
			if p.Team.Name == "Blue" then blue = blue + 1
			elseif p.Team.Name == "Red" then red = red + 1 end
		end
	end
	local team = (blue <= red) and getTeam("Blue") or getTeam("Red")
	player.Team = team
	player.TeamColor = team.TeamColor
end

------------------------------------------------------------------
-- Apply animal stats + floating emoji label
------------------------------------------------------------------
local function applyAnimalStats(player, animalId)
	local animal = findAnimal(animalId)
	player:SetAttribute("AnimalId", animal.id)

	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum.WalkSpeed = animal.speed
	hum.MaxHealth = animal.hp
	hum.Health = animal.hp

	local head = char:FindFirstChild("Head")
	if head then
		local old = head:FindFirstChild("AnimalLabel")
		if old then old:Destroy() end
		local bb = Instance.new("BillboardGui")
		bb.Name = "AnimalLabel"
		bb.Size = UDim2.new(0, 80, 0, 80)
		bb.StudsOffset = Vector3.new(0, 2.5, 0)
		bb.AlwaysOnTop = true
		bb.Parent = head
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 1, 0)
		l.BackgroundTransparency = 1
		l.Text = animal.emoji
		l.TextScaled = true
		l.Font = Enum.Font.SourceSansBold
		l.Parent = bb
	end
end

local function respawnAtBase(player)
	if not player.Team or not player.Character then return end
	local plate = getBasePlate(player.Team.Name)
	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if plate and hrp then
		hrp.CFrame = CFrame.new(plate.Position + Vector3.new(math.random(-6, 6), 6, math.random(-6, 6)))
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

local function returnFlagHome(flag)
	clearWelds(flag)
	flag.Anchored = true
	flag.CanCollide = false
	flag.Position = flag:GetAttribute("HomePosition")
	flag:SetAttribute("CarrierUserId", 0)
	flag:SetAttribute("AtHome", true)
end

local function dropFlag(flag, position)
	clearWelds(flag)
	flag.Anchored = true
	flag.CanCollide = false
	flag.Position = position + Vector3.new(0, 3, 0)
	flag:SetAttribute("CarrierUserId", 0)
	flag:SetAttribute("AtHome", false)
end

local function attachFlagTo(flag, character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	clearWelds(flag)
	flag.Anchored = false
	flag.CanCollide = false
	flag.CFrame = hrp.CFrame * CFrame.new(0, 6, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = flag
	weld.Parent = flag
end

local function dropFlagsHeldBy(userId, position)
	for _, f in ipairs(CollectionService:GetTagged("Flag")) do
		if f:GetAttribute("CarrierUserId") == userId then
			dropFlag(f, position)
			Remotes.FlagEvent:FireAllClients({ type = "drop", team = f:GetAttribute("Team") })
		end
	end
end

local wiredFlags = {}
local function wireFlag(flag)
	if wiredFlags[flag] then return end
	wiredFlags[flag] = true
	flag.Touched:Connect(function(hit)
		if matchState.phase ~= "playing" then return end
		local char = hit.Parent
		local player = Players:GetPlayerFromCharacter(char)
		if not player or not player.Team then return end
		if flag:GetAttribute("CarrierUserId") ~= 0 then return end

		local flagTeam = flag:GetAttribute("Team")
		local pTeam = player.Team.Name

		if pTeam ~= flagTeam then
			-- Enemy grabs flag
			flag:SetAttribute("CarrierUserId", player.UserId)
			flag:SetAttribute("AtHome", false)
			attachFlagTo(flag, char)
			Remotes.FlagEvent:FireAllClients({ type = "pickup", team = flagTeam, playerName = player.Name })
		else
			-- Friendly returning a dropped own-flag
			if not flag:GetAttribute("AtHome") then
				returnFlagHome(flag)
				Remotes.FlagEvent:FireAllClients({ type = "return", team = flagTeam, playerName = player.Name })
			end
		end
	end)
end
for _, f in ipairs(CollectionService:GetTagged("Flag")) do wireFlag(f) end
CollectionService:GetInstanceAddedSignal("Flag"):Connect(wireFlag)

------------------------------------------------------------------
-- Match control
------------------------------------------------------------------
local function broadcastState()
	local blueFlag = getFlag("Blue")
	local redFlag = getFlag("Red")
	Remotes.MatchState:FireAllClients({
		phase = matchState.phase,
		timeLeft = matchState.timeLeft,
		scores = matchState.scores,
		flags = {
			Blue = { atHome = blueFlag and blueFlag:GetAttribute("AtHome") or false },
			Red  = { atHome = redFlag  and redFlag:GetAttribute("AtHome")  or false },
		},
	})
end

local function resetRound()
	matchState.scores.Blue = 0
	matchState.scores.Red = 0
	matchState.timeLeft = GameConfig.ROUND_LENGTH
	for _, f in ipairs(CollectionService:GetTagged("Flag")) do returnFlagHome(f) end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.Health = hum.MaxHealth end
			respawnAtBase(p)
		end
	end
end

local function endRound(winner)
	matchState.phase = "ended"
	Remotes.MatchEnded:FireAllClients({ winner = winner, scores = matchState.scores })
	broadcastState()
	task.wait(GameConfig.INTERMISSION)
	resetRound()
	matchState.phase = "playing"
end

local function awardScore(teamName)
	matchState.scores[teamName] = matchState.scores[teamName] + 1
	if matchState.scores[teamName] >= GameConfig.SCORE_LIMIT then
		endRound(teamName)
	end
end

-- Score-check heartbeat: carrier touching own plate AND own flag at home = score
RunService.Heartbeat:Connect(function()
	if matchState.phase ~= "playing" then return end
	for _, f in ipairs(CollectionService:GetTagged("Flag")) do
		local cid = f:GetAttribute("CarrierUserId")
		if cid and cid ~= 0 then
			local carrier = Players:GetPlayerByUserId(cid)
			if carrier and carrier.Character and carrier.Team then
				local hrp = carrier.Character:FindFirstChild("HumanoidRootPart")
				local ownPlate = getBasePlate(carrier.Team.Name)
				local ownFlag = getFlag(carrier.Team.Name)
				if hrp and ownPlate and ownFlag and ownFlag:GetAttribute("AtHome") then
					local dist = (hrp.Position - ownPlate.Position).Magnitude
					if dist < GameConfig.FLAG_CAPTURE_RADIUS then
						returnFlagHome(f)
						Remotes.FlagEvent:FireAllClients({ type = "score", team = carrier.Team.Name, playerName = carrier.Name })
						awardScore(carrier.Team.Name)
					end
				end
			end
		end
	end
end)

-- Timer + broadcast loop
task.spawn(function()
	while #Players:GetPlayers() == 0 do task.wait(1) end
	task.wait(5)
	matchState.phase = "playing"
	matchState.timeLeft = GameConfig.ROUND_LENGTH

	while true do
		if matchState.phase == "playing" then
			matchState.timeLeft = matchState.timeLeft - 1
			if matchState.timeLeft <= 0 then
				local winner
				if matchState.scores.Blue > matchState.scores.Red then winner = "Blue"
				elseif matchState.scores.Red > matchState.scores.Blue then winner = "Red"
				else winner = "Draw" end
				endRound(winner)
			end
		end
		broadcastState()
		task.wait(1)
	end
end)

------------------------------------------------------------------
-- Combat
------------------------------------------------------------------
local function doAttack(player)
	if matchState.phase ~= "playing" then return end
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 then return end

	local st = playerStates[player]
	if not st then return end
	if tick() - (st.lastAttack or 0) < GameConfig.ATTACK_COOLDOWN then return end
	st.lastAttack = tick()

	local animal = findAnimal(player:GetAttribute("AnimalId") or "lion")
	local origin = hrp.Position
	local forward = hrp.CFrame.LookVector

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Team and player.Team and p.Team ~= player.Team then
			local tc = p.Character
			if tc then
				local tHum = tc:FindFirstChildOfClass("Humanoid")
				local tHrp = tc:FindFirstChild("HumanoidRootPart")
				if tHum and tHrp and tHum.Health > 0 then
					local to = tHrp.Position - origin
					local dist = to.Magnitude
					if dist <= animal.range + 2 and dist > 0 then
						if to.Unit:Dot(forward) > 0.3 then
							tHum:TakeDamage(animal.atk)
							tHrp.AssemblyLinearVelocity = to.Unit * 30 + Vector3.new(0, 10, 0)
						end
					end
				end
			end
		end
	end
end

Remotes.AttackFired.OnServerEvent:Connect(doAttack)

Remotes.AnimalChosen.OnServerEvent:Connect(function(player, animalId)
	if type(animalId) ~= "string" then return end
	if not findAnimal(animalId) then return end
	applyAnimalStats(player, animalId)
end)

------------------------------------------------------------------
-- Player lifecycle
------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	playerStates[player] = { lastAttack = 0 }
	assignTeam(player)

	player.CharacterAdded:Connect(function(char)
		task.wait(0.3)
		applyAnimalStats(player, player:GetAttribute("AnimalId") or "lion")
		respawnAtBase(player)

		local hum = char:WaitForChild("Humanoid")
		hum.Died:Connect(function()
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then dropFlagsHeldBy(player.UserId, hrp.Position) end
		end)
	end)

	-- Open picker on join
	task.wait(2)
	Remotes.ShowPicker:FireClient(player)
end)

Players.PlayerRemoving:Connect(function(player)
	playerStates[player] = nil
	if player.Character then
		local hrp = player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then dropFlagsHeldBy(player.UserId, hrp.Position) end
	end
end)
