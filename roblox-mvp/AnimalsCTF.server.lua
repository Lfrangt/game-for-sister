-- Server Script: paste into ServerScriptService as a single Script named "AnimalsCTF"
-- Animals CTF — Polish v1 (server-only: bots + touch-attack + BGM + SFX + lighting)
--
-- ⚡ NO LocalScripts required. F-key support kept as optional bonus
--    (works if AttackInput LocalScript is also installed; no harm if not).
--
-- What's new vs Phase A MVP:
--   • Touch-based attack — walking into an enemy auto-deals damage (with cooldown)
--   • Server-side BGM + SFX via SoundService (no client script needed)
--   • Lighting + Atmosphere for warm "cartoon battlefield" feel
--   • Stone arena walls + animated floating flags + PointLights at bases
--   • Round timer on a center BillboardGui visible to everyone
--   • Win screen with team color burst

local Players           = game:GetService("Players")
local Teams             = game:GetService("Teams")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")
local SoundService      = game:GetService("SoundService")
local TweenService      = game:GetService("TweenService")

------------------------------------------------------------------
-- Config
------------------------------------------------------------------
local SCORE_LIMIT         = 3
local ROUND_SECONDS       = 180
local INTERMISSION        = 8
local CAPTURE_RADIUS      = 10
local ARENA_SIZE          = Vector3.new(200, 2, 140)

-- Attack
local ATTACK_RANGE     = 8        -- studs to hit (F-key)
local ATTACK_DAMAGE    = 20
local ATTACK_COOLDOWN  = 0.6      -- seconds between swings per actor
local TOUCH_RANGE      = 4.5      -- studs for auto touch attack
local TOUCH_COOLDOWN   = 0.9      -- per-pair cooldown so touch doesn't spam
local TOUCH_DAMAGE     = 14       -- weaker than F-key so F still rewarding

-- Bots
local BOTS_PER_TEAM    = 3
local SIGHT_RADIUS     = 80
local THINK_INTERVAL   = 0.3
local RESPAWN_DELAY    = 4

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

local TEAM_C3 = {
	Blue = Color3.fromRGB(58, 140, 232),
	Red  = Color3.fromRGB(232, 78, 64),
}
local TEAM_BC = {
	Blue = BrickColor.new("Bright blue"),
	Red  = BrickColor.new("Really red"),
}

------------------------------------------------------------------
-- Lighting / Atmosphere — warm cartoon battlefield
------------------------------------------------------------------
do
	Lighting.Ambient            = Color3.fromRGB(120, 110, 100)
	Lighting.OutdoorAmbient     = Color3.fromRGB(150, 140, 120)
	Lighting.Brightness         = 2
	Lighting.ClockTime          = 16            -- soft late afternoon
	Lighting.GeographicLatitude = 30
	Lighting.GlobalShadows      = true
	Lighting.FogColor           = Color3.fromRGB(220, 200, 170)
	Lighting.FogStart           = 200
	Lighting.FogEnd             = 1000
	Lighting.EnvironmentDiffuseScale  = 0.6
	Lighting.EnvironmentSpecularScale = 0.4

	-- Atmosphere for warm haze
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density    = 0.32
	atmosphere.Offset     = 0.25
	atmosphere.Color      = Color3.fromRGB(255, 220, 190)
	atmosphere.Decay      = Color3.fromRGB(106, 80, 60)
	atmosphere.Glare      = 0.4
	atmosphere.Haze       = 1.5
end

------------------------------------------------------------------
-- Sounds — real Roblox-library-style asset IDs (server-side, no LocalScript).
-- If any specific ID 404s, the game keeps playing silent for that one.
-- Replace SoundIds with your own Toolbox finds anytime — just edit SOUNDS table.
------------------------------------------------------------------
local SOUNDS = {
	bgm        = { id = "rbxassetid://1840684529", volume = 0.45, looped = true },
	flagPickup = { id = "rbxassetid://6042164976", volume = 1.0  },
	flagReturn = { id = "rbxassetid://3398620867", volume = 0.9  },
	score      = { id = "rbxassetid://9119706896", volume = 1.0  },
	win        = { id = "rbxassetid://6048967691", volume = 1.0  },
	hit        = { id = "rbxassetid://5852433734", volume = 0.6  },
}

local soundFolder = SoundService:FindFirstChild("AnimalsCTF") or Instance.new("Folder")
soundFolder.Name   = "AnimalsCTF"
soundFolder.Parent = SoundService

local soundInstances = {}
for key, cfg in pairs(SOUNDS) do
	local s = Instance.new("Sound")
	s.Name     = key
	s.SoundId  = cfg.id
	s.Volume   = cfg.volume or 1
	s.Looped   = cfg.looped or false
	s.Parent   = soundFolder
	soundInstances[key] = s
end

local function playSfx(name)
	local s = soundInstances[name]
	if not s then return end
	if s.Looped then
		if not s.IsPlaying then s:Play() end
	else
		-- Play a clone so overlapping events don't cut each other off
		local c = s:Clone()
		c.Looped = false
		c.Parent = soundFolder
		c:Play()
		c.Ended:Connect(function() c:Destroy() end)
		task.delay(8, function() if c.Parent then c:Destroy() end end)
	end
end

-- Start BGM on boot (will idle silently if SoundId fails to load)
task.spawn(function()
	task.wait(1)
	playSfx("bgm")
end)

------------------------------------------------------------------
-- RemoteEvents (kept ONLY for optional F-key client; safe if unused)
------------------------------------------------------------------
local AttackFired = ReplicatedStorage:FindFirstChild("AttackFired")
	or Instance.new("RemoteEvent")
AttackFired.Name   = "AttackFired"
AttackFired.Parent = ReplicatedStorage

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
ensureTeam("Blue", TEAM_BC.Blue)
ensureTeam("Red",  TEAM_BC.Red)

------------------------------------------------------------------
-- Build arena from scratch (cartoon battlefield style)
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

-- Ground (smoother grass)
local ground = Instance.new("Part")
ground.Name           = "Ground"
ground.Size           = Vector3.new(W, 2, D)
ground.Position       = Vector3.new(0, 0, 0)
ground.Anchored       = true
ground.Material       = Enum.Material.LeafyGrass
ground.Color          = Color3.fromRGB(110, 168, 92)
ground.TopSurface     = Enum.SurfaceType.Smooth
ground.BottomSurface  = Enum.SurfaceType.Smooth
ground.Parent         = arena

-- Stone perimeter walls
local function wall(size, pos)
	local p = Instance.new("Part")
	p.Size           = size
	p.Position       = pos
	p.Anchored       = true
	p.Material       = Enum.Material.Slate
	p.Color          = Color3.fromRGB(125, 125, 130)
	p.TopSurface     = Enum.SurfaceType.Smooth
	p.BottomSurface  = Enum.SurfaceType.Smooth
	p.Parent         = arena
end
local wh = 10
wall(Vector3.new(W, wh, 2), Vector3.new(0, wh/2,  D/2))
wall(Vector3.new(W, wh, 2), Vector3.new(0, wh/2, -D/2))
wall(Vector3.new(2, wh, D), Vector3.new( W/2, wh/2, 0))
wall(Vector3.new(2, wh, D), Vector3.new(-W/2, wh/2, 0))

-- Decorative center stone divider (low, just visual)
do
	local divider = Instance.new("Part")
	divider.Size      = Vector3.new(2, 0.4, D - 6)
	divider.Position  = Vector3.new(0, 1.2, 0)
	divider.Anchored  = true
	divider.Material  = Enum.Material.Cobblestone
	divider.Color     = Color3.fromRGB(180, 170, 150)
	divider.Parent    = arena
end

local floatingFlags = {}  -- for sin-bob animation

local function buildBase(teamName, c3, bc, xPos)
	local folder = Instance.new("Folder")
	folder.Name   = teamName .. "Base"
	folder.Parent = arena

	-- Plate (capture pad — glows in team color)
	local plate = Instance.new("Part")
	plate.Name          = "Plate"
	plate.Size          = Vector3.new(28, 1, 28)
	plate.Position      = Vector3.new(xPos, 1.5, 0)
	plate.Anchored      = true
	plate.Material      = Enum.Material.Neon
	plate.Color         = c3
	plate.Transparency  = 0.25
	plate:SetAttribute("Team", teamName)
	CollectionService:AddTag(plate, "Base")
	plate.Parent = folder

	-- Spawn (placed slightly off the plate so flag dropoff zone is clear)
	local sp = Instance.new("SpawnLocation")
	sp.Name           = teamName .. "Spawn"
	sp.Size           = Vector3.new(8, 1, 8)
	sp.Position       = Vector3.new(xPos + (xPos < 0 and -10 or 10), 2.5, 10)
	sp.Anchored       = true
	sp.TeamColor      = bc
	sp.BrickColor     = bc
	sp.Material       = Enum.Material.SmoothPlastic
	sp.Transparency   = 0.5
	sp.Neutral        = false
	sp.AllowTeamChangeOnTouch = false
	sp.Parent = folder

	-- Pole
	local polePos = Vector3.new(xPos, 7, -8)
	local pole = Instance.new("Part")
	pole.Name      = "Pole"
	pole.Size      = Vector3.new(0.5, 12, 0.5)
	pole.Position  = polePos
	pole.Anchored  = true
	pole.Material  = Enum.Material.Wood
	pole.Color     = Color3.fromRGB(94, 70, 50)
	pole.Parent    = folder

	-- PointLight on pole (atmosphere)
	local pl = Instance.new("PointLight")
	pl.Color     = c3
	pl.Range     = 24
	pl.Brightness = 2
	pl.Parent    = pole

	-- Flag (Neon glow + animated bob)
	local flagPos = polePos + Vector3.new(2, 4, 0)
	local flag = Instance.new("Part")
	flag.Name          = "Flag"
	flag.Size          = Vector3.new(4, 3, 0.2)
	flag.Position      = flagPos
	flag.Anchored      = true
	flag.CanCollide    = false
	flag.Material      = Enum.Material.Neon
	flag.Color         = c3
	flag:SetAttribute("Team", teamName)
	flag:SetAttribute("AtHome", true)
	flag:SetAttribute("CarrierUserId", 0)
	flag:SetAttribute("HomePosition", flagPos)
	CollectionService:AddTag(flag, "Flag")
	flag.Parent = folder

	-- Floating bob registration
	floatingFlags[flag] = flagPos

	-- Label
	local bb = Instance.new("BillboardGui")
	bb.Adornee, bb.Size = pole, UDim2.new(0, 160, 0, 44)
	bb.StudsOffset      = Vector3.new(0, 8, 0)
	bb.AlwaysOnTop      = true
	bb.Parent           = pole
	local lbl = Instance.new("TextLabel")
	lbl.Size                  = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text                  = teamName:upper() .. " FLAG"
	lbl.TextColor3            = c3
	lbl.TextStrokeTransparency = 0
	lbl.TextStrokeColor3      = Color3.new(0, 0, 0)
	lbl.TextScaled            = true
	lbl.Font                  = Enum.Font.GothamBold
	lbl.Parent                = bb
end

buildBase("Blue", TEAM_C3.Blue, TEAM_BC.Blue, -W/2 + 24)
buildBase("Red",  TEAM_C3.Red,  TEAM_BC.Red,   W/2 - 24)

-- Center round timer billboard (visible to all)
local centerSign  -- forward declare
do
	local pole = Instance.new("Part")
	pole.Name     = "CenterSign"
	pole.Size     = Vector3.new(2, 14, 2)
	pole.Position = Vector3.new(0, 7, 0)
	pole.Anchored = true
	pole.CanCollide = false
	pole.Transparency = 1
	pole.Parent = arena

	local bb = Instance.new("BillboardGui")
	bb.Adornee     = pole
	bb.Size        = UDim2.new(0, 360, 0, 96)
	bb.StudsOffset = Vector3.new(0, 8, 0)
	bb.AlwaysOnTop = true
	bb.Parent      = pole

	local frame = Instance.new("Frame")
	frame.Size            = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0.35
	frame.BorderSizePixel = 0
	frame.Parent = bb
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 12); corner.Parent = frame

	local time = Instance.new("TextLabel")
	time.Size                 = UDim2.new(1, 0, 0.55, 0)
	time.Position             = UDim2.new(0, 0, 0, 0)
	time.BackgroundTransparency = 1
	time.Text                 = "3:00"
	time.TextColor3           = Color3.new(1, 1, 1)
	time.TextScaled           = true
	time.Font                 = Enum.Font.GothamBold
	time.Parent               = frame

	local score = Instance.new("TextLabel")
	score.Size                 = UDim2.new(1, 0, 0.45, 0)
	score.Position             = UDim2.new(0, 0, 0.55, 0)
	score.BackgroundTransparency = 1
	score.Text                 = "BLUE 0  •  RED 0"
	score.TextColor3           = Color3.fromRGB(255, 230, 180)
	score.TextScaled           = true
	score.Font                 = Enum.Font.Gotham
	score.Parent               = frame

	centerSign = { time = time, score = score }
end

------------------------------------------------------------------
-- Game state
------------------------------------------------------------------
local phase    = "playing"
local timeLeft = ROUND_SECONDS
local scores   = { Blue = 0, Red = 0 }

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

local function refreshCenterSign()
	if not centerSign then return end
	local m = math.floor(timeLeft / 60)
	local s = timeLeft % 60
	centerSign.time.Text  = string.format("%d:%02d", m, s)
	centerSign.score.Text = string.format("BLUE %d  •  RED %d", scores.Blue, scores.Red)
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
			playSfx("flagPickup")
		elseif not flag:GetAttribute("AtHome") then
			returnHome(flag)
			playSfx("flagReturn")
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
	refreshCenterSign()
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
	playSfx("win")

	-- Winner-color burst on the center sign
	if centerSign then
		local color = (winner == "Blue" and TEAM_C3.Blue)
			or (winner == "Red" and TEAM_C3.Red)
			or Color3.fromRGB(220, 220, 220)
		centerSign.time.Text     = (winner == "Draw") and "DRAW"
			or string.format("%s WINS!", winner:upper())
		centerSign.time.TextColor3 = color
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character and p.Character:FindFirstChild("Head") then
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.new(0, 420, 0, 64)
			bb.StudsOffset = Vector3.new(0, 4, 0)
			bb.AlwaysOnTop = true
			bb.Adornee = p.Character.Head
			bb.Parent = p.Character.Head
			local f = Instance.new("Frame")
			f.Size = UDim2.new(1, 0, 1, 0)
			f.BackgroundColor3 = Color3.new(0, 0, 0)
			f.BackgroundTransparency = 0.25
			f.BorderSizePixel = 0
			f.Parent = bb
			local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = f
			local l = Instance.new("TextLabel")
			l.Size                 = UDim2.new(1, 0, 1, 0)
			l.BackgroundTransparency = 1
			l.TextColor3           = Color3.new(1, 1, 1)
			l.TextScaled           = true
			l.Font                 = Enum.Font.GothamBold
			l.Text = winner == "Draw"
				and string.format("DRAW  %d – %d", scores.Blue, scores.Red)
				or  string.format("%s WINS!  %d – %d", winner:upper(), scores.Blue, scores.Red)
			l.Parent = f
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
	refreshCenterSign()
	playSfx("score")
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

-- Flag bobbing animation (small floating motion when at home)
RunService.Heartbeat:Connect(function()
	local t = tick()
	for flag, home in pairs(floatingFlags) do
		if flag.Parent and flag:GetAttribute("AtHome") then
			flag.Position = home + Vector3.new(0, math.sin(t * 2) * 0.4, 0)
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
			refreshCenterSign()
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
	player.Team      = team
	player.TeamColor = team.TeamColor

	local ls = Instance.new("Folder")
	ls.Name   = "leaderstats"
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
	lastAttackTimes[player.UserId] = nil
	if player.Character then
		local hrp = player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then dropHeldBy(player.UserId, hrp.Position) end
	end
end)

------------------------------------------------------------------
-- F-key attack (still works if AttackInput LocalScript is installed —
-- harmless if not, since the RemoteEvent simply has no client firing it)
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

	local hitSomething = false

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
						hitSomething = true
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
					hitSomething = true
				end
			end
		end
	end

	if hitSomething then playSfx("hit") end
end)

------------------------------------------------------------------
-- TOUCH-BASED ATTACK — server-only fallback when F-key isn't available.
-- Walking into an enemy auto-deals damage (with per-pair cooldown).
-- This makes the game playable WITHOUT any client LocalScript installed.
------------------------------------------------------------------
local touchPairCooldown = {}  -- key: "uidA-uidB" -> tick()

local function pairKey(a, b) return tostring(a) .. "-" .. tostring(b) end

local function tryTouchAttack(attackerKey, attackerHrp, attackerTeam, targetHrp, targetHum, targetKey)
	if not attackerHrp or not targetHrp or not targetHum then return end
	if targetHum.Health <= 0 then return end

	local key = pairKey(attackerKey, targetKey)
	local last = touchPairCooldown[key] or 0
	local now = tick()
	if (now - last) < TOUCH_COOLDOWN then return end

	local d = (attackerHrp.Position - targetHrp.Position).Magnitude
	if d > TOUCH_RANGE then return end

	touchPairCooldown[key] = now
	targetHum:TakeDamage(TOUCH_DAMAGE)
	targetHrp.AssemblyLinearVelocity =
		(targetHrp.Position - attackerHrp.Position).Unit * 25 + Vector3.new(0, 8, 0)
	playSfx("hit")
end

-- Heartbeat: every 0.15s scan player↔enemy(player+bot) pairs at close range.
do
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		if phase ~= "playing" then return end
		accum = accum + dt
		if accum < 0.15 then return end
		accum = 0

		local players = Players:GetPlayers()
		for i = 1, #players do
			local p = players[i]
			if p.Team and p.Character then
				local pHrp = p.Character:FindFirstChild("HumanoidRootPart")
				if pHrp then
					-- vs enemy players
					for j = i + 1, #players do
						local q = players[j]
						if q.Team and q.Team.Name ~= p.Team.Name and q.Character then
							local qHrp = q.Character:FindFirstChild("HumanoidRootPart")
							local qHum = q.Character:FindFirstChildOfClass("Humanoid")
							local pHum = p.Character:FindFirstChildOfClass("Humanoid")
							if qHrp and qHum and pHum then
								tryTouchAttack(p.UserId, pHrp, p.Team.Name, qHrp, qHum, q.UserId)
								tryTouchAttack(q.UserId, qHrp, q.Team.Name, pHrp, pHum, p.UserId)
							end
						end
					end
					-- vs enemy bots — players damage bots only (bot→player damage handled in botTick)
					for _, bot in ipairs(bots) do
						if bot.Parent and bot:GetAttribute("Team") ~= p.Team.Name then
							local bHrp = bot.PrimaryPart
							local bHum = bot:FindFirstChildOfClass("Humanoid")
							if bHrp and bHum then
								tryTouchAttack(p.UserId, pHrp, p.Team.Name, bHrp, bHum, "bot:" .. bot.Name)
							end
						end
					end
				end
			end
		end
	end)
end

------------------------------------------------------------------
-- Bot system (AI teammates) — unchanged behavior; lighting + colors only
------------------------------------------------------------------
local function randomAnimal()
	return ANIMALS[math.random(1, #ANIMALS)]
end

local function buildBotRig(animal, teamName)
	local model = Instance.new("Model")
	model.Name = "Bot_" .. animal.id

	local hrp = Instance.new("Part")
	hrp.Name        = "HumanoidRootPart"
	hrp.Size        = Vector3.new(2, 2, 1)
	hrp.Color       = TEAM_C3[teamName]
	hrp.Material    = Enum.Material.SmoothPlastic
	hrp.TopSurface  = Enum.SurfaceType.Smooth
	hrp.BottomSurface = Enum.SurfaceType.Smooth
	hrp.CanCollide  = true
	hrp.Parent      = model
	model.PrimaryPart = hrp

	local head = Instance.new("Part")
	head.Name     = "Head"
	head.Size     = Vector3.new(1.2, 1.2, 1.2)
	head.Color    = TEAM_C3[teamName]
	head.Material = Enum.Material.SmoothPlastic
	head.CFrame   = hrp.CFrame * CFrame.new(0, 1.6, 0)
	head.Parent   = model
	local hw = Instance.new("WeldConstraint"); hw.Part0, hw.Part1 = hrp, head; hw.Parent = head

	local hum = Instance.new("Humanoid")
	hum.WalkSpeed  = animal.speed
	hum.MaxHealth  = animal.hp
	hum.Health     = animal.hp
	hum.Parent     = model

	-- Floating animal emoji
	local bb = Instance.new("BillboardGui")
	bb.Size        = UDim2.new(0, 60, 0, 60)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = true
	bb.Parent      = head
	local lbl = Instance.new("TextLabel")
	lbl.Size                  = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text                  = animal.emoji
	lbl.TextScaled            = true
	lbl.Font                  = Enum.Font.GothamBold
	lbl.Parent                = bb

	CollectionService:AddTag(model, "Bot")
	model:SetAttribute("Team",        teamName)
	model:SetAttribute("AnimalId",    animal.id)
	model:SetAttribute("AnimalRange", animal.range)
	model:SetAttribute("AnimalAtk",   animal.atk)
	model:SetAttribute("LastAttack",  0)

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
				playSfx("hit")
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

print("[AnimalsCTF] Polish v1 ready — touch attack + BGM + SFX + lighting active.")
