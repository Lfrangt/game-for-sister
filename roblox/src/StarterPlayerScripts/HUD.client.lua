-- LocalScript: StarterPlayerScripts/HUD
-- Top scoreboard (Blue score · timer · flag status · Red score)
-- plus a big center banner for flag events and round results.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.Parent = pg

local bar = Instance.new("Frame")
bar.Size = UDim2.new(0, 560, 0, 52)
bar.Position = UDim2.new(0.5, -280, 0, 12)
bar.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
bar.BackgroundTransparency = 0.2
bar.BorderSizePixel = 0
bar.Parent = gui
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 10)

local function label(parent, text, x, w, color)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(0, w, 1, -8)
	l.Position = UDim2.new(0, x, 0, 4)
	l.BackgroundTransparency = 1
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.SourceSansBold
	l.Parent = parent
	return l
end

local blueLbl = label(bar, "Blue  0", 10, 130, Color3.fromRGB(110, 170, 255))
local timeLbl = label(bar, "3:00",   150, 90)
local flagLbl = label(bar, "Flags: Home", 245, 180)
local redLbl  = label(bar, "Red  0", 430, 120, Color3.fromRGB(255, 110, 100))

-- center banner
local banner = Instance.new("TextLabel")
banner.Size = UDim2.new(0, 520, 0, 90)
banner.Position = UDim2.new(0.5, -260, 0.38, -45)
banner.BackgroundColor3 = Color3.new(0, 0, 0)
banner.BackgroundTransparency = 0.35
banner.BorderSizePixel = 0
banner.TextColor3 = Color3.new(1, 1, 1)
banner.TextScaled = true
banner.Font = Enum.Font.SourceSansBold
banner.Text = ""
banner.Visible = false
banner.Parent = gui
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 12)

local bannerToken = 0
local function showBanner(text, duration)
	bannerToken = bannerToken + 1
	local me = bannerToken
	banner.Text = text
	banner.Visible = true
	task.delay(duration, function()
		if bannerToken == me then banner.Visible = false end
	end)
end

Remotes.MatchState.OnClientEvent:Connect(function(s)
	blueLbl.Text = "Blue  " .. s.scores.Blue
	redLbl.Text  = "Red  "  .. s.scores.Red
	local m = math.floor(s.timeLeft / 60)
	local sec = math.floor(s.timeLeft % 60)
	timeLbl.Text = string.format("%d:%02d", m, sec)

	local bh, rh = s.flags.Blue.atHome, s.flags.Red.atHome
	if bh and rh then
		flagLbl.Text = "Flags: Both Home"
	elseif not bh and not rh then
		flagLbl.Text = "Both Flags Taken!"
	elseif not bh then
		flagLbl.Text = "Blue Flag Taken!"
	else
		flagLbl.Text = "Red Flag Taken!"
	end
end)

Remotes.FlagEvent.OnClientEvent:Connect(function(d)
	if d.type == "score" then
		showBanner(d.team .. " SCORES!  (" .. d.playerName .. ")", 3)
	elseif d.type == "pickup" then
		showBanner(d.playerName .. " took the " .. d.team .. " flag!", 2)
	elseif d.type == "return" then
		showBanner(d.team .. " flag returned by " .. d.playerName, 1.5)
	elseif d.type == "drop" then
		showBanner(d.team .. " flag dropped", 1.5)
	end
end)

Remotes.MatchEnded.OnClientEvent:Connect(function(d)
	local msg
	if d.winner == "Draw" then
		msg = string.format("DRAW   %d – %d", d.scores.Blue, d.scores.Red)
	else
		msg = string.format("%s TEAM WINS!   %d – %d", d.winner:upper(), d.scores.Blue, d.scores.Red)
	end
	showBanner(msg, 8)
end)
