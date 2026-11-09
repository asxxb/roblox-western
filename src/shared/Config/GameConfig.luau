--!strict
--[[
	GameConfig.luau
	Central gameplay balancing, physics, interaction rules, and timing thresholds.
]]

local GameConfig = {
	Player = {
		NormalWalkSpeed = 16,
		SprintWalkSpeed = 26,
		JumpPower = 50,
		MaxHealth = 100,
		
		Stamina = {
			Max = 100,
			DrainRate = 18,       -- Stamina drained per second while sprinting
			RegenRate = 22,       -- Stamina recovered per second while resting
			RegenDelay = 1.0,     -- Seconds before stamina begins recovering
		},
	},

	Interaction = {
		DefaultMaxDistance = 14, -- Maximum distance in studs to trigger interactions
		PingTolerance = 6,       -- Server tolerance buffer for player network latency
		CratePickupHoldTime = 0.4,
		InteractCooldown = 0.25, -- Minimum seconds between client interaction requests
	},

	NPC = {
		MaxInteractionDistance = 14,
		WanderPauseMin = 3.0,
		WanderPauseMax = 7.0,
		PathfindingWaypointSpacing = 4.0,
		MaxPathfindingRetries = 2,
		WalkSpeed = 10,
	},

	DataStore = {
		KeyPrefix = "WWF_PlayerData_v1_",
		AutoSaveIntervalSeconds = 60,
		MaxSaveRetries = 3,
		RetryDelaySeconds = 2,
		SessionLockTimeoutSeconds = 180,
	},

	UI = {
		ToastDuration = 3.5,
		TypewriterCharDelay = 0.02,
		ModalTweenDuration = 0.25,
	},
}

return GameConfig

