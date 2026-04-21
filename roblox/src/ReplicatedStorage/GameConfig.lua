-- ModuleScript: ReplicatedStorage/GameConfig

return {
	ROUND_LENGTH = 180,            -- seconds
	INTERMISSION = 10,             -- seconds between rounds
	SCORE_LIMIT = 3,               -- first team to this score wins
	ATTACK_COOLDOWN = 0.6,         -- seconds between attacks per player
	FLAG_CAPTURE_RADIUS = 8,       -- studs from own base plate to score
	ARENA_SIZE = Vector3.new(200, 2, 140),   -- ground plane size (X, Y, Z)
}
