-- Server Script: paste into ServerScriptService as a single Script named "TowerRunner"
-- Tower Runner — Phase 1 SOLO skeleton
--   Vertical tower with two alternating segment styles:
--     1. Tower stage  — manual jumping platforms (Tower-of-Hell-style)
--     2. Runner stage — moving conveyor floor that pushes you forward
--   Checkpoints at the TOP of each segment. Falling teleports you back to
--   your last checkpoint, not all the way down.
--
--   Phase 1 scope: solo only, 3 segments hard-coded, no GUI mode picker.
--   Phase 2 will add multi-player race + mode selection.

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

------------------------------------------------------------------
-- Config
------------------------------------------------------------------
local SEGMENT_HEIGHT      = 40    -- studs each segment occupies vertically
local TOWER_PLATFORMS     = 6     -- platforms inside a tower segment
local TOWER_PLATFORM_SIZE = Vector3.new(8, 1, 8)
local TOWER_GAP_VERTICAL  = SEGMENT_HEIGHT / TOWER_PLATFORMS

local RUNNER_LENGTH       = 60    -- forward studs of a runner segment
local RUNNER_WIDTH        = 14
local RUNNER_SPEED        = 18    -- conveyor push speed (studs/sec)

local LAVA_DAMAGE         = 9999  -- one-shot kill

local SPAWN_OFFSET        = Vector3.new(0, 5, 0)

-- Segment definition: ordered top-to-bottom in code, but we'll build
-- bottom-to-top by reversing.
-- "tower" or "runner"
local SEGMENTS = { "tower", "runner", "tower" }

------------------------------------------------------------------
-- Color palette (warm cartoon)
------------------------------------------------------------------
local C = {
	Lava       = Color3.fromRGB(220,  90,  60),
	Platform   = Color3.fromRGB(140, 195, 235),  -- soft sky blue
	PlatformAlt= Color3.fromRGB(245, 195,  90),  -- warm yellow
	Conveyor   = Color3.fromRGB(170, 140, 220),  -- soft purple
	Wall       = Color3.fromRGB(180, 150, 110),
	Checkpoint = Color3.fromRGB( 90, 220, 130),  -- mint green
}

------------------------------------------------------------------
-- Build arena
------------------------------------------------------------------
for _, child in ipairs(Workspace:GetChildren()) do
	if child:IsA("SpawnLocation") then child:Destroy() end
end

local existing = Workspace:FindFirstChild("Tower")
if existing then existing:Destroy() end

local tower = Instance.new("Folder")
tower.Name = "Tower"
tower.Parent = Workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = tower
	return p
end

------------------------------------------------------------------
-- Lava floor (kills if you fall)
------------------------------------------------------------------
local lava = part {
	Name = "Lava",
	Size = Vector3.new(120, 4, 120),
	Position = Vector3.new(0, -2, 0),
	Material = Enum.Material.Neon,
	Color = C.Lava,
	Transparency = 0.1,
}
CollectionService:AddTag(lava, "Lava")

------------------------------------------------------------------
-- Spawn pad (start of run)
------------------------------------------------------------------
local startY = 4
local spawnPad = part {
	Name = "StartPad",
	Size = Vector3.new(16, 1, 16),
	Position = Vector3.new(0, startY, 0),
	Material = Enum.Material.SmoothPlastic,
	Color = C.Checkpoint,
}
local startSpawn = Instance.new("SpawnLocation")
startSpawn.Name = "StartSpawn"
startSpawn.Anchored = true
startSpawn.Size = Vector3.new(6, 1, 6)
startSpawn.Position = Vector3.new(0, startY + 1, 0)
startSpawn.Material = Enum.Material.Neon
startSpawn.BrickColor = BrickColor.new("Lime green")
startSpawn.Transparency = 0.4
startSpawn.Neutral = true
startSpawn.AllowTeamChangeOnTouch = false
startSpawn.Parent = tower

------------------------------------------------------------------
-- Build segments bottom-to-top
------------------------------------------------------------------
local checkpointPositions = {}  -- index 1 = start, 2 = top of seg 1, etc.
table.insert(checkpointPositions, Vector3.new(0, startY + 3, 0))

local function buildTowerSegment(yBase, segIndex)
	local x = 0  -- platforms zig-zag left/right
	for i = 1, TOWER_PLATFORMS do
		local side = (i % 2 == 0) and 1 or -1
		x = side * (4 + (i % 3) * 2)
		local p = part {
			Name = string.format("Tower%d_Platform%d", segIndex, i),
			Size = TOWER_PLATFORM_SIZE,
			Position = Vector3.new(x, yBase + i * TOWER_GAP_VERTICAL, 0),
			Material = Enum.Material.SmoothPlastic,
			Color = (i % 2 == 0) and C.PlatformAlt or C.Platform,
		}
	end
end

local function buildRunnerSegment(yBase, segIndex)
	local floor = part {
		Name = string.format("Runner%d_Floor", segIndex),
		Size = Vector3.new(RUNNER_WIDTH, 1, RUNNER_LENGTH),
		Position = Vector3.new(0, yBase + 4, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = C.Conveyor,
	}
	CollectionService:AddTag(floor, "Conveyor")

	-- Side walls so you can't fall off sideways during the runner stage
	for _, dx in ipairs({ -RUNNER_WIDTH/2 - 0.5, RUNNER_WIDTH/2 + 0.5 }) do
		part {
			Name = string.format("Runner%d_Wall", segIndex),
			Size = Vector3.new(1, 6, RUNNER_LENGTH),
			Position = Vector3.new(dx, yBase + 7, 0),
			Material = Enum.Material.SmoothPlastic,
			Color = C.Wall,
		}
	end

	-- A few low jump-over obstacles
	for i = 1, 3 do
		part {
			Name = string.format("Runner%d_Obstacle%d", segIndex, i),
			Size = Vector3.new(RUNNER_WIDTH * 0.7, 2, 1),
			Position = Vector3.new(0, yBase + 5.5, -RUNNER_LENGTH/2 + i * (RUNNER_LENGTH/4)),
			Material = Enum.Material.SmoothPlastic,
			Color = C.PlatformAlt,
		}
	end

	-- Top platform of segment doubles as checkpoint
	local top = part {
		Name = string.format("Runner%d_Top", segIndex),
		Size = Vector3.new(RUNNER_WIDTH, 1, 8),
		Position = Vector3.new(0, yBase + SEGMENT_HEIGHT - 4, RUNNER_LENGTH/2 + 4),
		Material = Enum.Material.SmoothPlastic,
		Color = C.Checkpoint,
	}
	CollectionService:AddTag(top, "Checkpoint")
	top:SetAttribute("CheckpointIndex", segIndex + 1)
	table.insert(checkpointPositions, top.Position + Vector3.new(0, 3, 0))
end

local function buildTowerSegmentTop(yBase, segIndex)
	-- Tower segment top platform also acts as checkpoint
	local top = part {
		Name = string.format("Tower%d_Top", segIndex),
		Size = Vector3.new(16, 1, 16),
		Position = Vector3.new(0, yBase + SEGMENT_HEIGHT, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = C.Checkpoint,
	}
	CollectionService:AddTag(top, "Checkpoint")
	top:SetAttribute("CheckpointIndex", segIndex + 1)
	table.insert(checkpointPositions, top.Position + Vector3.new(0, 3, 0))
end

local currentY = startY
for segIndex, segType in ipairs(SEGMENTS) do
	if segType == "tower" then
		buildTowerSegment(currentY, segIndex)
		buildTowerSegmentTop(currentY, segIndex)
	else
		buildRunnerSegment(currentY, segIndex)
	end
	currentY = currentY + SEGMENT_HEIGHT
end

-- Goal pad at the very top
local goal = part {
	Name = "Goal",
	Size = Vector3.new(20, 1, 20),
	Position = Vector3.new(0, currentY + 4, 0),
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(255, 220, 80),
	Transparency = 0.2,
}
CollectionService:AddTag(goal, "Goal")

local goalSign = Instance.new("BillboardGui")
goalSign.Adornee = goal
goalSign.Size = UDim2.new(0, 240, 0, 60)
goalSign.StudsOffset = Vector3.new(0, 6, 0)
goalSign.AlwaysOnTop = true
goalSign.Parent = goal
local goalLbl = Instance.new("TextLabel")
goalLbl.Size = UDim2.new(1, 0, 1, 0)
goalLbl.BackgroundTransparency = 1
goalLbl.Text = "🏁 GOAL"
goalLbl.TextColor3 = Color3.new(1, 1, 1)
goalLbl.TextStrokeTransparency = 0
goalLbl.TextScaled = true
goalLbl.Font = Enum.Font.SourceSansBold
goalLbl.Parent = goalSign

------------------------------------------------------------------
-- Per-player checkpoint tracking
------------------------------------------------------------------
local playerCheckpoint = {}  -- [UserId] = index into checkpointPositions

local function teleportToCheckpoint(player)
	if not player.Character then return end
	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local idx = playerCheckpoint[player.UserId] or 1
	local pos = checkpointPositions[idx]
	if pos then hrp.CFrame = CFrame.new(pos) end
end

local function setCheckpoint(player, idx)
	local current = playerCheckpoint[player.UserId] or 1
	if idx > current then
		playerCheckpoint[player.UserId] = idx
		-- Lightweight feedback: tint character briefly
		if player.Character then
			local head = player.Character:FindFirstChild("Head")
			if head then
				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.new(0, 200, 0, 40)
				bb.StudsOffset = Vector3.new(0, 3, 0)
				bb.AlwaysOnTop = true
				bb.Adornee = head
				bb.Parent = head
				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, 0, 1, 0)
				lbl.BackgroundTransparency = 1
				lbl.Text = "✓ Checkpoint!"
				lbl.TextColor3 = C.Checkpoint
				lbl.TextStrokeTransparency = 0
				lbl.TextScaled = true
				lbl.Font = Enum.Font.SourceSansBold
				lbl.Parent = bb
				game.Debris:AddItem(bb, 1.5)
			end
		end
	end
end

------------------------------------------------------------------
-- Wire up checkpoint, lava, goal touches
------------------------------------------------------------------
for _, cp in ipairs(CollectionService:GetTagged("Checkpoint")) do
	cp.Touched:Connect(function(hit)
		local plr = Players:GetPlayerFromCharacter(hit.Parent)
		if plr then setCheckpoint(plr, cp:GetAttribute("CheckpointIndex")) end
	end)
end

lava.Touched:Connect(function(hit)
	local plr = Players:GetPlayerFromCharacter(hit.Parent)
	if not plr then return end
	local hum = hit.Parent:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum:TakeDamage(LAVA_DAMAGE)
	end
end)

goal.Touched:Connect(function(hit)
	local plr = Players:GetPlayerFromCharacter(hit.Parent)
	if not plr then return end
	if plr:GetAttribute("Finished") then return end
	plr:SetAttribute("Finished", true)
	-- Banner
	local head = hit.Parent:FindFirstChild("Head")
	if head then
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 320, 0, 80)
		bb.StudsOffset = Vector3.new(0, 5, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = head
		bb.Parent = head
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 0.3
		lbl.BackgroundColor3 = Color3.new(0, 0, 0)
		lbl.Text = "🏆 You finished!"
		lbl.TextColor3 = Color3.new(1, 1, 0.4)
		lbl.TextScaled = true
		lbl.Font = Enum.Font.SourceSansBold
		lbl.Parent = bb
		game.Debris:AddItem(bb, 5)
	end
	-- Reset for next run after a short delay
	task.delay(4, function()
		plr:SetAttribute("Finished", false)
		playerCheckpoint[plr.UserId] = 1
		teleportToCheckpoint(plr)
	end)
end)

------------------------------------------------------------------
-- Conveyor push: server simulation each Heartbeat
-- Players standing on conveyor parts get a forward velocity component.
-- Forward direction is +Z (toward the segment top). We push along world +Z.
------------------------------------------------------------------
local function onConveyor(hrp)
	for _, conv in ipairs(CollectionService:GetTagged("Conveyor")) do
		local cPos = conv.Position
		local cSize = conv.Size
		local dx = math.abs(hrp.Position.X - cPos.X)
		local dz = math.abs(hrp.Position.Z - cPos.Z)
		if dx <= cSize.X / 2 + 1 and dz <= cSize.Z / 2 + 1 then
			local dy = hrp.Position.Y - cPos.Y
			if dy > 0 and dy < 6 then
				return conv  -- player is above and within bounds
			end
		end
	end
	return nil
end

RunService.Heartbeat:Connect(function(dt)
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if not char then continue end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end
		if onConveyor(hrp) then
			local v = hrp.AssemblyLinearVelocity
			-- Add forward push (world +Z direction); preserve vertical/horizontal
			hrp.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, RUNNER_SPEED)
		end
	end
end)

------------------------------------------------------------------
-- Player lifecycle
------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	playerCheckpoint[player.UserId] = 1
	player.RespawnLocation = startSpawn

	player.CharacterAdded:Connect(function(char)
		task.wait(0.2)
		teleportToCheckpoint(player)
		local hum = char:WaitForChild("Humanoid")
		hum.Died:Connect(function()
			-- Auto-respawn happens via Roblox; we just ensure they go to checkpoint
			task.wait(1.5)
		end)
	end)

	-- Leaderstats: show highest checkpoint reached
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	local stage = Instance.new("IntValue")
	stage.Name = "Stage"
	stage.Value = 0
	stage.Parent = ls
end)

Players.PlayerRemoving:Connect(function(player)
	playerCheckpoint[player.UserId] = nil
end)

-- Update leaderstats periodically
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, plr in ipairs(Players:GetPlayers()) do
			local ls = plr:FindFirstChild("leaderstats")
			if ls and ls:FindFirstChild("Stage") then
				ls.Stage.Value = (playerCheckpoint[plr.UserId] or 1) - 1
			end
		end
	end
end)

print("[TowerRunner] Phase 1 ready — solo skeleton, " .. #SEGMENTS .. " segments, " .. #checkpointPositions .. " checkpoints.")
