--!strict
--[[
	ItemDefinitions.luau
	Authoritative registry of all items in Wild West Frontier.
]]

local ItemEnums = require(script.Parent.Parent.Constants.ItemEnums)
local InventoryTypes = require(script.Parent.Parent.Types.InventoryTypes)

type ItemDefinition = InventoryTypes.ItemDefinition

local ItemDefinitions: { [string]: ItemDefinition } = {
	[ItemEnums.Ids.SupplyCrate] = {
		Id = ItemEnums.Ids.SupplyCrate,
		Name = "Frontier Supply Crate",
		Description = "A sturdy wooden crate packed with essential frontier goods.",
		Category = "Resource",
		MaxStack = 10,
		BaseValue = 15,
		BuyPrice = 30,
		IconAssetId = "rbxassetid://13847209706",
	},

	[ItemEnums.Ids.GoldNugget] = {
		Id = ItemEnums.Ids.GoldNugget,
		Name = "Raw Gold Nugget",
		Description = "Panned from the dry creek bed. Shines with high intrinsic value.",
		Category = "Resource",
		MaxStack = 20,
		BaseValue = 40,
		BuyPrice = nil, -- Cannot be bought, only found or mined
		IconAssetId = "rbxassetid://13847210115",
	},

	[ItemEnums.Ids.Canteen] = {
		Id = ItemEnums.Ids.Canteen,
		Name = "Leather Canteen",
		Description = "Restores vitality and stamina in the blazing desert heat.",
		Category = "Consumable",
		MaxStack = 5,
		BaseValue = 10,
		BuyPrice = 20,
		IconAssetId = "rbxassetid://13847210512",
	},

	[ItemEnums.Ids.HealthSalve] = {
		Id = ItemEnums.Ids.HealthSalve,
		Name = "Herbal Healing Salve",
		Description = "Soothing desert herbal ointment. Restores 35 Health.",
		Category = "Consumable",
		MaxStack = 5,
		BaseValue = 12,
		BuyPrice = 25,
		IconAssetId = "rbxassetid://13847210889",
	},

	[ItemEnums.Ids.BanditWatch] = {
		Id = ItemEnums.Ids.BanditWatch,
		Name = "Engraved Pocket Watch",
		Description = "A stolen gold pocket watch belonging to Sheriff Cooper.",
		Category = "QuestItem",
		MaxStack = 1,
		BaseValue = 0,
		BuyPrice = nil,
		IconAssetId = "rbxassetid://13847211244",
	},

	[ItemEnums.Ids.SheriffBadge] = {
		Id = ItemEnums.Ids.SheriffBadge,
		Name = "Deputy Star Badge",
		Description = "Awarded by Sheriff Cooper to trusted allies of the frontier.",
		Category = "Equipment",
		MaxStack = 1,
		BaseValue = 100,
		BuyPrice = nil,
		EquipmentSlot = "Hat",
		IconAssetId = "rbxassetid://13847211603",
	},

	[ItemEnums.Ids.Pickaxe] = {
		Id = ItemEnums.Ids.Pickaxe,
		Name = "Iron Miner's Pick",
		Description = "Forged iron pickaxe capable of cracking mineral veins.",
		Category = "Equipment",
		MaxStack = 1,
		BaseValue = 35,
		BuyPrice = 75,
		EquipmentSlot = "Handheld",
		IconAssetId = "rbxassetid://13847212001",
	},

	[ItemEnums.Ids.CowboyHat] = {
		Id = ItemEnums.Ids.CowboyHat,
		Name = "Stetson Cowboy Hat",
		Description = "Classic wide-brimmed felt hat, keeping the noon sun at bay.",
		Category = "Equipment",
		MaxStack = 1,
		BaseValue = 45,
		BuyPrice = 90,
		EquipmentSlot = "Hat",
		IconAssetId = "rbxassetid://13847212351",
	},

	[ItemEnums.Ids.MerchantLedger] = {
		Id = ItemEnums.Ids.MerchantLedger,
		Name = "Silas's Trade Ledger",
		Description = "Trade records and shipment accounts for the General Store.",
		Category = "QuestItem",
		MaxStack = 1,
		BaseValue = 0,
		BuyPrice = nil,
		IconAssetId = "rbxassetid://13847212689",
	},
}

local ItemDefinitionsModule = {}

function ItemDefinitionsModule.Get(itemId: string): ItemDefinition?
	return ItemDefinitions[itemId]
end

function ItemDefinitionsModule.GetAll(): { [string]: ItemDefinition }
	return ItemDefinitions
end

return ItemDefinitionsModule
