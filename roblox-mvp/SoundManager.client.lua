-- LocalScript: paste into StarterPlayerScripts as "SoundManager"
-- Handles BGM loop + game-event sound effects.
--
-- HOW TO REPLACE PLACEHOLDER AUDIO IDs:
--   1. Open Roblox Studio → View → Toolbox → Creator Store → Audio
--   2. Search the keyword in each comment below
--   3. Filter "Free" → pick one → right-click → Copy Asset ID
--   4. Paste the ID (numbers only) into the rbxassetid:// string below

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService      = game:GetService("SoundService")

------------------------------------------------------------------
-- Audio IDs — replace these with real ones from Toolbox
------------------------------------------------------------------
-- search: "cartoon battle bgm" or "kids game music loop"
local BGM_ID         = "rbxassetid://1843671709"   -- Roblox Original loop (verify free)

-- search: "cartoon fanfare" or "score jingle"
local SCORE_ID       = "rbxassetid://4612371891"   -- short win jingle (verify free)

-- search: "flag capture" or "pickup chime"
local FLAG_PICKUP_ID = "rbxassetid://4612381877"   -- chime up (verify free)

-- search: "flag return" or "shield block"
local FLAG_RETURN_ID = "rbxassetid://4612381877"   -- same chime, different pitch OK

-- search: "cartoon death" or "game over blip"
local DEATH_ID       = "rbxassetid://4612381877"   -- placeholder (verify free)

------------------------------------------------------------------
-- Helper: create a pre-loaded Sound in SoundService
------------------------------------------------------------------
local function makeSound(id, volume, looped)
	local s = Instance.new("Sound")
	s.SoundId    = id
	s.Volume     = volume or 0.5
	s.Looped     = looped or false
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.Parent     = SoundService
	return s
end

local bgm        = makeSound(BGM_ID,         0.35, true)
local sfxScore   = makeSound(SCORE_ID,       0.8,  false)
local sfxPickup  = makeSound(FLAG_PICKUP_ID, 0.7,  false)
local sfxReturn  = makeSound(FLAG_RETURN_ID, 0.6,  false)
local sfxDeath   = makeSound(DEATH_ID,       0.5,  false)

-- Start BGM once the game is loaded
task.delay(1, function()
	bgm:Play()
end)

------------------------------------------------------------------
-- React to server game events
------------------------------------------------------------------
local SoundEvent = ReplicatedStorage:WaitForChild("SoundEvent")

SoundEvent.OnClientEvent:Connect(function(event)
	if event == "score" then
		sfxScore:Play()
	elseif event == "flagPickup" then
		sfxPickup:Play()
	elseif event == "flagReturn" then
		sfxReturn:Play()
	elseif event == "death" then
		sfxDeath:Play()
	end
end)
