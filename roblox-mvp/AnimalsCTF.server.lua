-- Server Script: paste into ServerScriptService as a single Script named "AnimalsCTF"
-- Animals CTF — minimal single-file MVP.
-- Creates teams, auto-builds the arena, handles flag pickup/drop/return/score,
-- match timer, win condition, respawn. No client scripts needed; uses
-- Roblox's built-in leaderstats for the scoreboard.

local Players           = game:GetService("Players")
local Teams             = game:GetService("Teams")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

------------------------------------------------------------------
-- Config
------------------------------------------------------------------
local SCORE_LIMIT         = 3
local ROUND_SECONDS       = 180
local INTERMISSION        = 8
local CAPTURE_RADIUS      = 10
local ARENA_SIZE          = Vector3.new(200, 2, 140)

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
local phase = "playing"  -- "playing" | "ended"
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
		elseif not flag:GetAttribute("AtHome") then
			returnHome(flag)
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
			ls:FindFirstChild("Blue").Value = 0
			ls:FindFirstChild("Red").Value = 0
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
	if scores[team] >= SCORE_LIMIT then endRound(team) end
end

-- capture check
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

-- timer
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
Players.PlayerAdded:Connect(function(player)
	-- team balance
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

	-- leaderstats for built-in scoreboard
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
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	if player.Character then
		local hrp = player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then dropHeldBy(player.UserId, hrp.Position) end
	end
end)

print("[AnimalsCTF] Ready. Good luck, have fun.")
