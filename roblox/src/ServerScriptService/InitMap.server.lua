-- Server Script: ServerScriptService/InitMap
-- Runs once at server start. Creates Teams + auto-builds the arena
-- (ground, perimeter walls, two bases with spawn pads, two flags).
-- You can delete this script later and build the map by hand in Studio;
-- just keep the Tags (Base, Flag) and Attributes (Team, HomePosition) intact.

local Workspace = game:GetService("Workspace")
local Teams = game:GetService("Teams")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- Force Remotes to be created before any client tries to WaitForChild them
require(ReplicatedStorage:WaitForChild("Remotes"))

------------------------------------------------------------------
-- Teams
------------------------------------------------------------------
local function ensureTeam(name, color)
	local team = Teams:FindFirstChild(name)
	if not team then
		team = Instance.new("Team")
		team.Name = name
		team.TeamColor = color
		team.AutoAssignable = false
		team.Parent = Teams
	end
	return team
end
ensureTeam("Blue", BrickColor.new("Bright blue"))
ensureTeam("Red",  BrickColor.new("Really red"))

------------------------------------------------------------------
-- Clear any stock SpawnLocation so our team spawns take over
------------------------------------------------------------------
for _, inst in ipairs(Workspace:GetChildren()) do
	if inst:IsA("SpawnLocation") then inst:Destroy() end
end

------------------------------------------------------------------
-- Arena
------------------------------------------------------------------
local arena = Workspace:FindFirstChild("Arena")
if arena then arena:Destroy() end
arena = Instance.new("Folder")
arena.Name = "Arena"
arena.Parent = Workspace

local SIZE = GameConfig.ARENA_SIZE
local W, D = SIZE.X, SIZE.Z

-- Ground
local ground = Instance.new("Part")
ground.Name = "Ground"
ground.Size = Vector3.new(W, 2, D)
ground.Position = Vector3.new(0, 0, 0)
ground.Anchored = true
ground.Material = Enum.Material.Grass
ground.BrickColor = BrickColor.new("Bright green")
ground.TopSurface = Enum.SurfaceType.Smooth
ground.Parent = arena

-- Perimeter walls
local function makeWall(size, pos)
	local w = Instance.new("Part")
	w.Size = size; w.Position = pos; w.Anchored = true
	w.Material = Enum.Material.Wood
	w.BrickColor = BrickColor.new("Reddish brown")
	w.Parent = arena
end
local wh = 10
makeWall(Vector3.new(W, wh, 2), Vector3.new(0, wh/2, D/2))
makeWall(Vector3.new(W, wh, 2), Vector3.new(0, wh/2, -D/2))
makeWall(Vector3.new(2, wh, D), Vector3.new(W/2, wh/2, 0))
makeWall(Vector3.new(2, wh, D), Vector3.new(-W/2, wh/2, 0))

-- A few obstacle rocks for cover
local function makeRock(x, z, r)
	local rock = Instance.new("Part")
	rock.Shape = Enum.PartType.Ball
	rock.Size = Vector3.new(r, r, r)
	rock.Position = Vector3.new(x, r/2, z)
	rock.Anchored = true
	rock.Material = Enum.Material.Slate
	rock.BrickColor = BrickColor.new("Medium stone grey")
	rock.Parent = arena
end
math.randomseed(1234)
for i = 1, 8 do
	local x = math.random(-W/2 + 30, W/2 - 30)
	local z = math.random(-D/2 + 15, D/2 - 15)
	if math.abs(x) > 35 then
		makeRock(x, z, math.random(6, 10))
	end
end

------------------------------------------------------------------
-- Base + Flag builder
------------------------------------------------------------------
local function buildBase(teamName, color, xPos)
	local folder = Instance.new("Folder")
	folder.Name = teamName .. "Base"
	folder.Parent = arena

	-- Score plate (bring enemy flag here to score)
	local plate = Instance.new("Part")
	plate.Name = "Plate"
	plate.Size = Vector3.new(24, 1, 24)
	plate.Position = Vector3.new(xPos, 1.5, 0)
	plate.Anchored = true
	plate.Material = Enum.Material.SmoothPlastic
	plate.BrickColor = color
	plate.Transparency = 0.3
	plate.Parent = folder
	plate:SetAttribute("Team", teamName)
	CollectionService:AddTag(plate, "Base")

	-- Team SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = teamName .. "Spawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(xPos, 2.5, 0)
	spawn.Anchored = true
	spawn.TeamColor = color
	spawn.BrickColor = color
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.4
	spawn.Neutral = false
	spawn.AllowTeamChangeOnTouch = false
	spawn.Parent = folder

	-- Flag pole
	local polePos = Vector3.new(xPos, 7, -8)
	local pole = Instance.new("Part")
	pole.Name = "FlagPole"
	pole.Size = Vector3.new(0.5, 12, 0.5)
	pole.Position = polePos
	pole.Anchored = true
	pole.Material = Enum.Material.Wood
	pole.BrickColor = BrickColor.new("Dark orange")
	pole.Parent = folder

	-- Flag part
	local flagPos = polePos + Vector3.new(2, 4, 0)
	local flag = Instance.new("Part")
	flag.Name = "Flag"
	flag.Size = Vector3.new(4, 3, 0.2)
	flag.Position = flagPos
	flag.Anchored = true
	flag.CanCollide = false
	flag.Material = Enum.Material.Fabric
	flag.BrickColor = color
	flag:SetAttribute("Team", teamName)
	flag:SetAttribute("AtHome", true)
	flag:SetAttribute("CarrierUserId", 0)
	flag:SetAttribute("HomePosition", flagPos)
	CollectionService:AddTag(flag, "Flag")
	flag.Parent = folder

	-- Floating label above flag so you can see whose it is
	local bb = Instance.new("BillboardGui")
	bb.Adornee = pole
	bb.Size = UDim2.new(0, 120, 0, 40)
	bb.StudsOffset = Vector3.new(0, 8, 0)
	bb.AlwaysOnTop = true
	bb.Parent = pole
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = teamName:upper() .. " FLAG"
	lbl.TextColor3 = color.Color
	lbl.TextStrokeTransparency = 0
	lbl.TextScaled = true
	lbl.Font = Enum.Font.SourceSansBold
	lbl.Parent = bb
end

buildBase("Blue", BrickColor.new("Bright blue"), -W/2 + 20)
buildBase("Red",  BrickColor.new("Really red"),   W/2 - 20)

print("[InitMap] Arena ready.")
