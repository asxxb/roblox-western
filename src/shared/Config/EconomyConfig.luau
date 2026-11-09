--!strict
--[[
	EconomyConfig.luau
	Currency balancing, inventory capacity, and trading transaction limits.
]]

local EconomyConfig = {
	DefaultStartingCoins = 50,
	DefaultInventoryCapacity = 20,
	
	Transaction = {
		MaxTransactionsPerSecond = 3,
		MaxItemPurchaseQuantity = 50,
	},

	SellValueMultiplier = 0.6, -- Players sell items for 60% of base value
}

return EconomyConfig

