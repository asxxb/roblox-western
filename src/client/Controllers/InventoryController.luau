--!strict
--[[
	InventoryController.luau
	Client-side inventory cache, item actions, equipment toggling, and trading invocations.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetworkRouter = require(Shared.Network.NetworkRouter)
local Signal = require(Shared.Utilities.Signal)

local InventoryController = {
	Name = "InventoryController",
	InventoryUpdated = Signal.new() :: Signal.Signal<()>,
	CoinsUpdated = Signal.new() :: Signal.Signal<number>,
}

local cachedInventory: { [string]: { Id: string, Quantity: number } } = {}
local cachedEquipment: { [string]: string? } = {}
local cachedCapacity = 20
local cachedCoins = 0

function InventoryController:Init()
	-- Init
end

function InventoryController:Start()
	local syncEvent = NetworkRouter.GetEvent(NetworkRouter.Names.Events.InventorySync)
	syncEvent.OnClientEvent:Connect(function(data: any)
		if data.Inventory then
			cachedInventory = data.Inventory
		end
		if data.Capacity then
			cachedCapacity = data.Capacity
		end
		if data.Equipment then
			cachedEquipment = data.Equipment
		end
		if data.Coins ~= nil then
			local changed = cachedCoins ~= data.Coins
			cachedCoins = data.Coins
			if changed then
				self.CoinsUpdated:Fire(cachedCoins)
			end
		end

		self.InventoryUpdated:Fire()
	end)
end

function InventoryController:GetCoins(): number
	return cachedCoins
end

function InventoryController:GetInventory(): { [string]: { Id: string, Quantity: number } }
	return cachedInventory
end

function InventoryController:GetCapacity(): number
	return cachedCapacity
end

function InventoryController:GetEquipment(): { [string]: string? }
	return cachedEquipment
end

function InventoryController:UseItem(itemId: string): (boolean, string?)
	local func = NetworkRouter.GetFunction(NetworkRouter.Names.Functions.UseItem)
	return func:InvokeServer(itemId)
end

function InventoryController:EquipItem(itemId: string): (boolean, string?)
	local func = NetworkRouter.GetFunction(NetworkRouter.Names.Functions.EquipItem)
	return func:InvokeServer(itemId)
end

function InventoryController:PurchaseItem(itemId: string, quantity: number): (boolean, string?)
	local func = NetworkRouter.GetFunction(NetworkRouter.Names.Functions.PurchaseItem)
	return func:InvokeServer(itemId, quantity)
end

function InventoryController:SellItem(itemId: string, quantity: number): (boolean, string?)
	local func = NetworkRouter.GetFunction(NetworkRouter.Names.Functions.SellItem)
	return func:InvokeServer(itemId, quantity)
end

return InventoryController
