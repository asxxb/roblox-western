--!strict
--[[
	ItemEnums.luau
	Enumerations for item IDs, categories, and equipment slots.
]]

local ItemEnums = {
	Categories = {
		Resource = "Resource" :: "Resource",
		Consumable = "Consumable" :: "Consumable",
		Equipment = "Equipment" :: "Equipment",
		QuestItem = "QuestItem" :: "QuestItem",
	},

	Ids = {
		SupplyCrate = "item_supply_crate",
		GoldNugget = "item_gold_nugget",
		Canteen = "item_canteen",
		HealthSalve = "item_health_salve",
		BanditWatch = "item_bandit_watch",
		SheriffBadge = "item_sheriff_badge",
		Pickaxe = "item_pickaxe",
		CowboyHat = "item_cowboy_hat",
		MerchantLedger = "item_merchant_ledger",
	},

	EquipmentSlots = {
		Hat = "Hat" :: "Hat",
		Outfit = "Outfit" :: "Outfit",
		Handheld = "Handheld" :: "Handheld",
	},
}

return ItemEnums

