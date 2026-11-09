--!strict
--[[
	EconomyService.luau
	Authoritative economy management: secure shop transactions, anti-exploit rate limits, and reward distribution.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local ItemDefinitions = require(Shared.Definitions.ItemDefinitions)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local GameConfig = require(Shared.Config.GameConfig)
local NetworkRouter = require(Shared.Network.NetworkRouter)
local SpatialUtil = require(Shared.Utilities.SpatialUtil)
local Signal = require(Shared.Utilities.Signal)

local PlayerDataService: any
local InventoryService: any

local EconomyService = {
	Name = "EconomyService",
	TransactionCompleted = Signal.new() :: Signal.Signal<Player, string, string, number, number>,
}

local playerRateLimits: { [Player]: { LastTime: number, Count: number } } = {}

local function checkRateLimit(player: Player): boolean
	local now = os.clock()
	local record = playerRateLimits[player]

	if not record or (now - record.LastTime) >= 1.0 then
		playerRateLimits[player] = { LastTime = now, Count = 1 }
		return true
	end

	if record.Count >= EconomyConfig.Transaction.MaxTransactionsPerSecond then
		return false
	end

	record.Count += 1
	return true
end

function EconomyService:Init()
	PlayerDataService = require(script.Parent.PlayerDataService)
	InventoryService = require(script.Parent.InventoryService)
end

function EconomyService:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		playerRateLimits[player] = nil
	end)

	-- Register RemoteFunctions
	local purchaseFunc = NetworkRouter.GetFunction(NetworkRouter.Names.Functions.PurchaseItem)
	purchaseFunc.OnServerInvoke = function(player: Player, itemId: any, quantity: any)
		if typeof(itemId) ~= "string" or typeof(quantity) ~= "number" then
			return false, "Invalid transaction arguments"
		end
		return self:PurchaseItem(player, itemId, math.floor(quantity))
	end

	local sellFunc = NetworkRouter.GetFunction(NetworkRouter.Names.Functions.SellItem)
	sellFunc.OnServerInvoke = function(player: Player, itemId: any, quantity: any)
		if typeof(itemId) ~= "string" or typeof(quantity) ~= "number" then
			return false, "Invalid transaction arguments"
		end
		return self:SellItem(player, itemId, math.floor(quantity))
	end
end

function EconomyService:PurchaseItem(player: Player, itemId: string, quantity: number): (boolean, string?)
	if not checkRateLimit(player) then
		return false, "Transaction rate limit exceeded. Slow down!"
	end

	if quantity <= 0 or quantity > EconomyConfig.Transaction.MaxItemPurchaseQuantity then
		return false, "Invalid purchase quantity"
	end

	local def = ItemDefinitions.Get(itemId)
	if not def then
		return false, "Item does not exist"
	end

	if not def.BuyPrice then
		return false, "This item is not for sale"
	end

	local totalCost = def.BuyPrice * quantity
	local playerCoins = PlayerDataService:GetCoins(player)
	if playerCoins < totalCost then
		return false, "Insufficient coins"
	end

	-- Try adding item to inventory first to ensure capacity
	local addOk, addErr = InventoryService:AddItem(player, itemId, quantity)
	if not addOk then
		return false, addErr or "Could not add item to inventory"
	end

	-- Atomically deduct currency
	PlayerDataService:RemoveCoins(player, totalCost)

	self.TransactionCompleted:Fire(player, "Buy", itemId, quantity, totalCost)

	local notifEvent = NetworkRouter.GetEvent(NetworkRouter.Names.Events.ShowNotification)
	notifEvent:FireClient(player, "PurchaseSuccess", string.format("Purchased %dx %s for %d coins", quantity, def.Name, totalCost))

	return true, nil
end

function EconomyService:SellItem(player: Player, itemId: string, quantity: number): (boolean, string?)
	if not checkRateLimit(player) then
		return false, "Transaction rate limit exceeded"
	end

	if quantity <= 0 or quantity > 100 then
		return false, "Invalid sell quantity"
	end

	local def = ItemDefinitions.Get(itemId)
	if not def then
		return false, "Item does not exist"
	end

	if def.Category == "QuestItem" then
		return false, "Quest items cannot be sold"
	end

	if not InventoryService:HasItem(player, itemId, quantity) then
		return false, "You do not have enough items to sell"
	end

	local unitPrice = math.max(1, math.floor(def.BaseValue * EconomyConfig.SellValueMultiplier))
	local totalRevenue = unitPrice * quantity

	local removeOk, removeErr = InventoryService:RemoveItem(player, itemId, quantity)
	if not removeOk then
		return false, removeErr or "Failed to remove items from inventory"
	end

	PlayerDataService:AddCoins(player, totalRevenue)

	self.TransactionCompleted:Fire(player, "Sell", itemId, quantity, totalRevenue)

	local notifEvent = NetworkRouter.GetEvent(NetworkRouter.Names.Events.ShowNotification)
	notifEvent:FireClient(player, "CoinsReceived", string.format("Sold %dx %s for +%d coins", quantity, def.Name, totalRevenue))

	return true, nil
end

function EconomyService:RewardCoins(player: Player, amount: number, reason: string?)
	if amount <= 0 then
		return
	end

	PlayerDataService:AddCoins(player, amount)

	local notifEvent = NetworkRouter.GetEvent(NetworkRouter.Names.Events.ShowNotification)
	notifEvent:FireClient(player, "CoinsReceived", string.format("+%d Coins (%s)", amount, reason or "Reward"))
end

return EconomyService
