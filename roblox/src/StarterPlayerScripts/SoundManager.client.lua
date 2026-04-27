-- LocalScript: StarterPlayerScripts/SoundManager
-- Plays sound effects on this player's client when flag events fire.
-- Hooks into the existing Remotes.FlagEvent.OnClientEvent — no server change.
--
-- BEFORE SHIPPING: replace placeholder asset IDs with real Roblox audio.
-- To find IDs: Roblox Studio → Toolbox → Audio → search "free" → drag a
-- sound into the explorer → copy its SoundId attribute (rbxassetid://NNNN).

local SoundService      = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

-- Placeholder IDs — REPLACE before shipping. Many free audio assets get
-- delisted, so test in Studio after pasting the final IDs.
local SOUND_IDS = {
	flagPickup = "rbxassetid://6890585181",
	flagDrop   = "rbxassetid://6890585181",
	flagReturn = "rbxassetid://6890585181",
	score      = "rbxassetid://9120386436",
	attackHit  = "rbxassetid://9118823106",
}

local function makeSound(name, id, volume)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = volume or 0.5
	s.Parent = SoundService
	return s
end

local sfx = {}
for key, id in pairs(SOUND_IDS) do
	sfx[key] = makeSound("SFX_" .. key, id, key == "score" and 0.7 or 0.5)
end

-- Existing GameManager already calls FlagEvent:FireAllClients with payloads
-- like { type = "pickup" | "drop" | "return" | "score", team, playerName }.
Remotes.FlagEvent.OnClientEvent:Connect(function(payload)
	if payload.type == "pickup" then sfx.flagPickup:Play()
	elseif payload.type == "drop"   then sfx.flagDrop:Play()
	elseif payload.type == "return" then sfx.flagReturn:Play()
	elseif payload.type == "score"  then sfx.score:Play()
	end
end)

-- For attack hits: requires a tiny server-side patch to fire a new remote on
-- every successful hit. Recommended addition to GameManager.server.lua:
--
--   -- Add near the top, with the other Remote requires:
--   local HitSfxRemote = ReplicatedStorage:FindFirstChild("HitSfxRemote") or (function()
--     local r = Instance.new("RemoteEvent"); r.Name = "HitSfxRemote"; r.Parent = ReplicatedStorage; return r
--   end)()
--
--   -- Inside doAttack(), right after tHum:TakeDamage(animal.atk):
--   HitSfxRemote:FireAllClients()
--
-- Then this client listens:
local hitRemote = ReplicatedStorage:WaitForChild("HitSfxRemote", 10)
if hitRemote then
	hitRemote.OnClientEvent:Connect(function() sfx.attackHit:Play() end)
end
