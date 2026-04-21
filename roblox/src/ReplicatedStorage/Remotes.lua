-- ModuleScript: ReplicatedStorage/Remotes
-- Lazily creates/fetches the RemoteEvents used across server and client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder then
	if RunService:IsServer() then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	else
		folder = ReplicatedStorage:WaitForChild("Remotes")
	end
end

local EVENT_NAMES = {
	"AnimalChosen",    -- client -> server: player picked animal id
	"AttackFired",     -- client -> server: attack button pressed
	"MatchState",      -- server -> clients: scores, timer, flag state
	"FlagEvent",       -- server -> clients: pickup/drop/return/score banner
	"MatchEnded",      -- server -> clients: round result
	"ShowPicker",      -- server -> one client: open picker UI
}

local M = {}
for _, name in ipairs(EVENT_NAMES) do
	local ev = folder:FindFirstChild(name)
	if not ev then
		if RunService:IsServer() then
			ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		else
			ev = folder:WaitForChild(name)
		end
	end
	M[name] = ev
end

return M
