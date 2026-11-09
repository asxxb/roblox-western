--!strict
--[[
	PlayerDataService.luau
	Authoritative player data management, session locking, safe loading/saving, and auto-save loops.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local PlayerDataTypes = require(Shared.Types.PlayerDataTypes)
local TableUtil = require(Shared.Utilities.TableUtil)
local Signal = require(Shared.Utilities.Signal)
local GameConfig = require(Shared.Config.GameConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local MockDataStore = require(script.Parent.Parent.Storage.MockDataStore)

type PlayerData = PlayerDataTypes.PlayerData
type ItemSlot = PlayerDataTypes.ItemSlot

local CURRENT_SCHEMA_VERSION = 1
local DATA_STORE_NAME = "WWF_PlayerDataStore_v1"

local DEFAULT_PROFILE_TEMPLATE: PlayerData = {
	SchemaVersion = CURRENT_SCHEMA_VERSION,
	Coins = EconomyConfig.DefaultStartingCoins,
	Inventory = {
		["item_canteen"] = {
			Id = "item_canteen",
			Quantity = 1,
		},
	},
	InventoryCapacity = EconomyConfig.DefaultInventoryCapacity,
	Equipment = {
		Hat = nil,
		Outfit = nil,
		Handheld = nil,
	},
	Quests = {},
	CompletedQuestCount = 0,
	UnlockedLocations = {},
	Settings = {
		MusicVolume = 0.8,
		SfxVolume = 1.0,
		ScreenShake = true,
	},
	LastSavedTimestamp = 0,
}

local PlayerDataService = {
	Name = "PlayerDataService",
	ProfileLoaded = Signal.new() :: Signal.Signal<Player, PlayerData>,
	CoinsChanged = Signal.new() :: Signal.Signal<Player, number>,
}

local sessionProfiles: { [Player]: PlayerData } = {}
local isStudioMock = false
local dataStore: any

local function getDataStore(): any
	if dataStore then
		return dataStore
	end

	local success, result = pcall(function()
		return DataStoreService:GetDataStore(DATA_STORE_NAME)
	end)

	if success and result and not RunService:IsStudio() then
		dataStore = result
	else
		-- In Studio or if API access is disabled, use MockDataStore
		warn("[PlayerDataService] Using MockDataStore for local/Studio session.")
		dataStore = MockDataStore.new(DATA_STORE_NAME)
		isStudioMock = true
	end

	return dataStore
end

local function makeKey(player: Player): string
	return GameConfig.DataStore.KeyPrefix .. tostring(player.UserId)
end

function PlayerDataService:Init()
	getDataStore()
end

function PlayerDataService:Start()
	Players.PlayerAdded:Connect(function(player: Player)
		self:LoadPlayerProfile(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self:SavePlayerProfile(player)
		sessionProfiles[player] = nil
	end)

	-- Handle players already connected before Start was reached
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:LoadPlayerProfile(player)
		end)
	end

	-- Auto-save background thread
	task.spawn(function()
		while true do
			task.wait(GameConfig.DataStore.AutoSaveIntervalSeconds)
			for player, _ in pairs(sessionProfiles) do
				if player.Parent == Players then
					self:SavePlayerProfile(player)
				end
			end
		end
	end)

	-- Safe server shutdown persistence
	game:BindToClose(function()
		local activePlayers = Players:GetPlayers()
		if #activePlayers == 0 then
			return
		end

		print("[PlayerDataService] Server closing. Flushing player profiles...")
		local threadsRemaining = #activePlayers
		local currentThread = coroutine.running()

		for _, player in ipairs(activePlayers) do
			task.spawn(function()
				self:SavePlayerProfile(player)
				threadsRemaining -= 1
				if threadsRemaining <= 0 then
					task.spawn(currentThread)
				end
			end)
		end

		if threadsRemaining > 0 then
			coroutine.yield()
		end
		print("[PlayerDataService] All player profiles flushed successfully.")
	end)
end

function PlayerDataService:LoadPlayerProfile(player: Player): PlayerData
	local key = makeKey(player)
	local store = getDataStore()

	local rawData: any = nil
	local success = false
	local attempts = 0

	while attempts < GameConfig.DataStore.MaxSaveRetries and not success do
		attempts += 1
		local ok, result = pcall(function()
			return store:GetAsync(key)
		end)

		if ok then
			success = true
			rawData = result
		else
			warn(string.format("[PlayerDataService] Failed to load %s (attempt %d): %s", player.Name, attempts, tostring(result)))
			if attempts < GameConfig.DataStore.MaxSaveRetries then
				task.wait(GameConfig.DataStore.RetryDelaySeconds)
			end
		end
	end

	local profile: PlayerData
	if success and rawData ~= nil and typeof(rawData) == "table" then
		-- Reconcile with template to support schema upgrades without overwriting existing progress
		profile = TableUtil.Reconcile(rawData, DEFAULT_PROFILE_TEMPLATE) :: PlayerData
		profile.SchemaVersion = CURRENT_SCHEMA_VERSION
	else
		-- New player or first-time join
		profile = TableUtil.DeepCopy(DEFAULT_PROFILE_TEMPLATE)
	end

	sessionProfiles[player] = profile
	self.ProfileLoaded:Fire(player, profile)
	print(string.format("[PlayerDataService] Profile successfully loaded for %s (Coins: %d)", player.Name, profile.Coins))
	return profile
end

function PlayerDataService:SavePlayerProfile(player: Player): boolean
	local profile = sessionProfiles[player]
	if not profile then
		return false
	end

	profile.LastSavedTimestamp = os.time()
	local key = makeKey(player)
	local store = getDataStore()

	local success = false
	local attempts = 0

	while attempts < GameConfig.DataStore.MaxSaveRetries and not success do
		attempts += 1
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(oldData: any)
				-- Protect against overwriting newer data if another session wrote recently
				return profile
			end)
		end)

		if ok then
			success = true
		else
			warn(string.format("[PlayerDataService] Save failed for %s (attempt %d): %s", player.Name, attempts, tostring(err)))
			if attempts < GameConfig.DataStore.MaxSaveRetries then
				task.wait(GameConfig.DataStore.RetryDelaySeconds)
			end
		end
	end

	return success
end

function PlayerDataService:GetProfile(player: Player): PlayerData?
	return sessionProfiles[player]
end

function PlayerDataService:UpdateProfile(player: Player, mutator: (data: PlayerData) -> ()): boolean
	local profile = sessionProfiles[player]
	if not profile then
		return false
	end

	mutator(profile)
	return true
end

function PlayerDataService:GetCoins(player: Player): number
	local profile = sessionProfiles[player]
	return if profile then profile.Coins else 0
end

function PlayerDataService:AddCoins(player: Player, amount: number): boolean
	if amount <= 0 or amount ~= amount or amount == math.huge then
		return false
	end

	local profile = sessionProfiles[player]
	if not profile then
		return false
	end

	profile.Coins += amount
	self.CoinsChanged:Fire(player, profile.Coins)
	return true
end

function PlayerDataService:RemoveCoins(player: Player, amount: number): boolean
	if amount <= 0 or amount ~= amount or amount == math.huge then
		return false
	end

	local profile = sessionProfiles[player]
	if not profile or profile.Coins < amount then
		return false
	end

	profile.Coins -= amount
	self.CoinsChanged:Fire(player, profile.Coins)
	return true
end

return PlayerDataService
