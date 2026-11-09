--!strict
--[[
	QuestDefinitions.luau
	Authoritative registry of all quest definitions, prerequisites, objectives, and rewards.
]]

local ItemEnums = require(script.Parent.Parent.Constants.ItemEnums)
local QuestEnums = require(script.Parent.Parent.Constants.QuestEnums)
local QuestTypes = require(script.Parent.Parent.Types.QuestTypes)

type QuestDefinition = QuestTypes.QuestDefinition

local QuestDefinitions: { [string]: QuestDefinition } = {
	[QuestEnums.Ids.MissingSupplies] = {
		Id = QuestEnums.Ids.MissingSupplies,
		Title = "Missing Town Supplies",
		Description = "A supply wagon was ransacked outside town! Search the frontier alleys and outskirts to recover 5 scattered supply crates.",
		GiverNPCId = "npc_merchant",
		PrerequisiteQuestIds = {},
		Objectives = {
			{
				Type = "Collect",
				Description = "Collect missing supply crates around town",
				TargetId = ItemEnums.Ids.SupplyCrate,
				TargetCount = 5,
			},
		},
		Rewards = {
			Coins = 100,
			Items = {
				{ ItemId = ItemEnums.Ids.Canteen, Quantity = 1 },
			},
			Experience = 50,
		},
		Repeatable = false,
	},

	[QuestEnums.Ids.SheriffRequest] = {
		Id = QuestEnums.Ids.SheriffRequest,
		Title = "Sheriff's Stolen Watch",
		Description = "Outlaws raided the station and stole Sheriff Cooper's engraved pocket watch. Retrieve it from the desert outpost cache and return it.",
		GiverNPCId = "npc_sheriff",
		PrerequisiteQuestIds = {},
		Objectives = {
			{
				Type = "Collect",
				Description = "Find the stolen pocket watch at the desert outpost",
				TargetId = ItemEnums.Ids.BanditWatch,
				TargetCount = 1,
			},
			{
				Type = "Deliver",
				Description = "Return the watch to Sheriff Cooper",
				TargetId = "npc_sheriff",
				TargetCount = 1,
			},
		},
		Rewards = {
			Coins = 150,
			Items = {
				{ ItemId = ItemEnums.Ids.SheriffBadge, Quantity = 1 },
			},
			Experience = 100,
		},
		Repeatable = false,
	},

	[QuestEnums.Ids.FrontierExplorer] = {
		Id = QuestEnums.Ids.FrontierExplorer,
		Title = "Frontier Town Explorer",
		Description = "Get your bearings on the frontier. Visit the 4 key landmarks: the Dusty Spur Saloon, Sheriff's Office, General Store, and Town Stables.",
		GiverNPCId = "npc_bartender",
		PrerequisiteQuestIds = {},
		Objectives = {
			{
				Type = "Visit",
				Description = "Visit the Dusty Spur Saloon",
				TargetId = QuestEnums.Locations.Saloon,
				TargetCount = 1,
			},
			{
				Type = "Visit",
				Description = "Visit the Sheriff's Office",
				TargetId = QuestEnums.Locations.SheriffOffice,
				TargetCount = 1,
			},
			{
				Type = "Visit",
				Description = "Visit Silas's General Store",
				TargetId = QuestEnums.Locations.GeneralStore,
				TargetCount = 1,
			},
			{
				Type = "Visit",
				Description = "Visit the Frontier Stables",
				TargetId = QuestEnums.Locations.Stables,
				TargetCount = 1,
			},
		},
		Rewards = {
			Coins = 80,
			Items = {
				{ ItemId = ItemEnums.Ids.HealthSalve, Quantity = 2 },
			},
			Experience = 75,
		},
		Repeatable = false,
	},

	[QuestEnums.Ids.MerchantDelivery] = {
		Id = QuestEnums.Ids.MerchantDelivery,
		Title = "Merchant Trade Delivery",
		Description = "Rancher Jesse needs a trade ledger delivered to Silas at the General Store across the town square.",
		GiverNPCId = "npc_stablemaster",
		PrerequisiteQuestIds = {},
		Objectives = {
			{
				Type = "Deliver",
				Description = "Deliver the trade ledger to Silas at the General Store",
				TargetId = "npc_merchant",
				TargetCount = 1,
			},
		},
		Rewards = {
			Coins = 60,
			Items = {
				{ ItemId = ItemEnums.Ids.GoldNugget, Quantity = 1 },
			},
			Experience = 40,
		},
		Repeatable = false,
	},
}

local QuestDefinitionsModule = {}

function QuestDefinitionsModule.Get(questId: string): QuestDefinition?
	return QuestDefinitions[questId]
end

function QuestDefinitionsModule.GetAll(): { [string]: QuestDefinition }
	return QuestDefinitions
end

return QuestDefinitionsModule

