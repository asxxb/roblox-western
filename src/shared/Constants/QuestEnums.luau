--!strict
--[[
	QuestEnums.luau
	Enumerations for quest IDs, states, and objective types.
]]

local QuestEnums = {
	States = {
		Inactive = "Inactive" :: "Inactive",
		Active = "Active" :: "Active",
		Completed = "Completed" :: "Completed",
	},

	ObjectiveTypes = {
		Collect = "Collect" :: "Collect",
		Visit = "Visit" :: "Visit",
		Deliver = "Deliver" :: "Deliver",
		Talk = "Talk" :: "Talk",
	},

	Ids = {
		MissingSupplies = "quest_missing_supplies",
		SheriffRequest = "quest_sheriff_request",
		FrontierExplorer = "quest_frontier_explorer",
		MerchantDelivery = "quest_merchant_delivery",
	},

	Locations = {
		TownSquare = "loc_town_square",
		Saloon = "loc_saloon",
		SheriffOffice = "loc_sheriff_office",
		GeneralStore = "loc_general_store",
		Stables = "loc_stables",
		DesertOutpost = "loc_desert_outpost",
	},
}

return QuestEnums

