--!strict
--[[
	InventoryTypes.luau
	Data models for inventory items, categories, definitions, and operations.
]]

export type ItemCategory = "Resource" | "Consumable" | "Equipment" | "QuestItem"

export type EquipmentSlotType = "Hat" | "Outfit" | "Handheld"

export type ItemDefinition = {
	Id: string,
	Name: string,
	Description: string,
	Category: ItemCategory,
	MaxStack: number,
	BaseValue: number,          -- Sell value in coins
	BuyPrice: number?,          -- Buy price in coins (nil if not purchasable in shop)
	IconAssetId: string,
	EquipmentSlot: EquipmentSlotType?,
	Attributes: { [string]: any }?,
}

export type InventoryTransactionResult = {
	Success: boolean,
	Reason: string?,
	RemainingQuantity: number?,
}

return {}

