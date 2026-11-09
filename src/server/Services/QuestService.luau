--!strict
--[[
	QuestService.luau
	Authoritative quest management: acceptance, multi-objective tracking, completion validation, and reward distribution.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local QuestDefinitions = require(Shared.Definitions.QuestDefinitions)
local QuestTypes = require(Shared.Types.QuestTypes)
local PlayerDataTypes = require(Shared.Types.PlayerDataTypes)
local NetworkRouter = require(Shared.Network.NetworkRouter)
local Signal = require(Shared.Utilities.Signal)

type QuestProgress = PlayerDataTypes.QuestProgress

local PlayerDataService: any
local InventoryService: any
local EconomyService: any

local QuestService = {
	Name = "QuestService",
	QuestAccepted = Signal.new() :: Signal.Signal<Player, string>,
	QuestAdvanced = Signal.new() :: Signal.Signal<Player, string, number, number>,
	QuestCompleted = Signal.new() :: Signal.Signal<Player, string>,
}

function QuestService:Init()
	PlayerDataService = require(script.Parent.PlayerDataService)
	InventoryService = require(script.Parent.InventoryService)
	EconomyService = require(script.Parent.EconomyService)
end

function QuestService:Start()
	-- Sync quests upon player data load
	PlayerDataService.ProfileLoaded:Connect(function(player: Player, profile: any)
		self:SyncAllQuests(player)
	end)
end

function QuestService:SyncAllQuests(player: Player)
	local profile = PlayerDataService:GetProfile(player)
	if not profile then
		return
	end

	local questEvent = NetworkRouter.GetEvent(NetworkRouter.Names.Events.QuestUpdate)
	for questId, progress in pairs(profile.Quests) do
		questEvent:FireClient(player, questId, progress.State, progress.ObjectiveProgress)
	end
end

function QuestService:GetQuestProgress(player: Player, questId: string): QuestProgress?
	local profile = PlayerDataService:GetProfile(player)
	if not profile then
		return nil
	end
	return profile.Quests[questId]
end

function QuestService:IsQuestActive(player: Player, questId: string): boolean
	local progress = self:GetQuestProgress(player, questId)
	return progress ~= nil and progress.State == "Active"
end

function QuestService:IsQuestCompleted(player: Player, questId: string): boolean
	local progress = self:GetQuestProgress(player, questId)
	return progress ~= nil and progress.State == "Completed"
end

function QuestService:AcceptQuest(player: Player, questId: string): (boolean, string?)
	local def = QuestDefinitions.Get(questId)
	if not def then
		return false, "Quest not found"
	end

	local profile = PlayerDataService:GetProfile(player)
	if not profile then
		return false, "Player data not loaded"
	end

	local currentProgress = profile.Quests[questId]
	if currentProgress then
		if currentProgress.State == "Completed" and not def.Repeatable then
			return false, "Quest already completed"
		elseif currentProgress.State == "Active" then
			return false, "Quest is already in progress"
		end
	end

	-- Check prerequisite quests
	for _, prereqId in ipairs(def.PrerequisiteQuestIds) do
		if not self:IsQuestCompleted(player, prereqId) then
			return false, "Prerequisite quests not met"
		end
	end

	-- Initialize objectives progress table
	local objProgress: { [number]: number } = {}
	for idx, obj in ipairs(def.Objectives) do
		-- If objective is Collect, check if player already has some in inventory
		if obj.Type == "Collect" then
			local currentCount = InventoryService:GetItemCount(player, obj.TargetId)
			objProgress[idx] = math.min(obj.TargetCount, currentCount)
		else
			objProgress[idx] = 0
		end
	end

	profile.Quests[questId] = {
		QuestId = questId,
		State = "Active",
		ObjectiveProgress = objProgress,
		StartedTimestamp = os.time(),
		CompletedTimestamp = nil,
	}

	self.QuestAccepted:Fire(player, questId)

	local questEvent = NetworkRouter.GetEvent(NetworkRouter.Names.Events.QuestUpdate)
	questEvent:FireClient(player, questId, "Active", objProgress)

	local notifEvent = NetworkRouter.GetEvent(NetworkRouter.Names.Events.ShowNotification)
	notifEvent:FireClient(player, "QuestAccepted", string.format("Quest Accepted: %s", def.Title))

	return true, nil
end

function QuestService:OnItemCollected(player: Player, itemId: string, count: number)
	local profile = PlayerDataService:GetProfile(player)
	if not profile then
		return
	end

	for questId, progress in pairs(profile.Quests) do
		if progress.State == "Active" then
			local def = QuestDefinitions.Get(questId)
			if def then
				for idx, obj in ipairs(def.Objectives) do
					if obj.Type == "Collect" and obj.TargetId == itemId then
						local current = progress.ObjectiveProgress[idx] or 0
						local newCount = math.min(obj.TargetCount, current + count)
						if newCount ~= current then
							progress.ObjectiveProgress[idx] = newCount
							self:NotifyObjectiveProgress(player, questId, idx, newCount, obj.TargetCount)
						end
					end
				end
			end
		end
	end
end

function QuestService:VisitLocation(player: Player, locationId: string)
	local profile = PlayerDataService:GetProfile(player)
	if not profile then
		return
	end

	profile.UnlockedLocations[locationId] = true

	for questId, progress in pairs(profile.Quests) do
		if progress.State == "Active" then
			local def = QuestDefinitions.Get(questId)
			if def then
				for idx, obj in ipairs(def.Objectives) do
					if obj.Type == "Visit" and obj.TargetId == locationId then
						local current = progress.ObjectiveProgress[idx] or 0
						if current < obj.TargetCount then
							progress.ObjectiveProgress[idx] = obj.TargetCount
							self:NotifyObjectiveProgress(player, questId, idx, obj.TargetCount, obj.TargetCount)
						end
					end
				end
			end
		end
	end
end

function QuestService:NotifyObjectiveProgress(
	player: Player,
	questId: string,
	objIndex: number,
	current: number,
	target: number
)
	local profile = PlayerDataService:GetProfile(player)
	if not profile then
		return
	end

	local progress = profile.Quests[questId]
	if not progress then
		return
	end

	self.QuestAdvanced:Fire(player, questId, objIndex, current)

	local questEvent = NetworkRouter.GetEvent(NetworkRouter.Names.Events.QuestUpdate)
	questEvent:FireClient(player, questId, progress.State, progress.ObjectiveProgress)

	local notifEvent = NetworkRouter.GetEvent(NetworkRouter.Names.Events.ShowNotification)
	notifEvent:FireClient(player, "QuestProgress", string.format("Objective Updated: %d/%d", current, target))
end

function QuestService:CanCompleteQuest(player: Player, questId: string): boolean
	local def = QuestDefinitions.Get(questId)
	if not def then
		return false
	end

	local progress = self:GetQuestProgress(player, questId)
	if not progress or progress.State ~= "Active" then
		return false
	end

	for idx, obj in ipairs(def.Objectives) do
		local cur = progress.ObjectiveProgress[idx] or 0
		if obj.Type == "Collect" then
			-- Verify player currently has items in inventory
			local countInBag = InventoryService:GetItemCount(player, obj.TargetId)
			if countInBag < obj.TargetCount then
				return false
			end
		elseif cur < obj.TargetCount then
			return false
		end
	end

	return true
end

function QuestService:CompleteQuest(player: Player, questId: string): (boolean, string?)
	local def = QuestDefinitions.Get(questId)
	if not def then
		return false, "Quest not found"
	end

	if not self:CanCompleteQuest(player, questId) then
		return false, "Quest objectives are not yet complete"
	end

	local profile = PlayerDataService:GetProfile(player)
	if not profile then
		return false, "Profile not loaded"
	end

	-- Deduct required items if objective was Collect
	for _, obj in ipairs(def.Objectives) do
		if obj.Type == "Collect" then
			InventoryService:RemoveItem(player, obj.TargetId, obj.TargetCount)
		end
	end

	-- Update quest state
	local progress = profile.Quests[questId]
	progress.State = "Completed"
	progress.CompletedTimestamp = os.time()
	profile.CompletedQuestCount += 1

	-- Distribute rewards
	if def.Rewards.Coins > 0 then
		EconomyService:RewardCoins(player, def.Rewards.Coins, def.Title)
	end

	if def.Rewards.Items then
		for _, itemReward in ipairs(def.Rewards.Items) do
			InventoryService:AddItem(player, itemReward.ItemId, itemReward.Quantity)
		end
	end

	self.QuestCompleted:Fire(player, questId)

	local questEvent = NetworkRouter.GetEvent(NetworkRouter.Names.Events.QuestUpdate)
	questEvent:FireClient(player, questId, "Completed", progress.ObjectiveProgress)

	local notifEvent = NetworkRouter.GetEvent(NetworkRouter.Names.Events.ShowNotification)
	notifEvent:FireClient(player, "QuestComplete", string.format("QUEST COMPLETE: %s!", def.Title))

	return true, nil
end

return QuestService
