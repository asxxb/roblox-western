--!strict
--[[
	InventoryService.luau
	Authoritative inventory management: item pickups, stacking, capacity checks, and item usage.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local ItemDefinitions = require(Shared.Definitions.ItemDefinitions)
local NetworkRouter = require(Shared.Network.NetworkRouter)
local Signal = require(Shared.Utilities.Signal)

local PlayerDataService: any

local InventoryService = {
	Name = "InventoryService",
	ItemAdded = Signal.new() :: Signal.Signal<Player, string, number>,
	ItemRemoved = Signal.new() :: Signal.Signal<Player, string, number>,
	ItemUsed = Signal.new() :: Signal.Signal<Player, string>,
}

function InventoryService:Init()
	PlayerDataService = require(script.Parent.PlayerDataService)
end

function InventoryService:Start()
	-- Connect remote handlers for item usage and equipment
	local useItemFunc = NetworkRouter.GetFunction(NetworkRouter.Names.Functions.UseItem)
	useItemFunc.OnServerInvoke = function(player: Player, itemId: any)
		if typeof(itemId) ~= "string" then
			return false, "Invalid argument"
		end
		return self:UseItem(player, itemId)
	end

	local equipItemFunc = NetworkRouter.GetFunction(NetworkRouter.Names.Functions.EquipItem)
	equipItemFunc.OnServerInvoke = function(player: Player, itemId: any)
		if typeof(itemId) ~= "string" then
			return false, "Invalid argument"
		end
		return self:EquipItem(player, itemId)
	end

	-- When player data loads, sync full inventory to client
	PlayerDataService.ProfileLoaded:Connect(function(player: Player, profile: any)
		self:SyncInventory(player)
	end)
end

function InventoryService:SyncInventory(player: Player)
	local profile = PlayerDataService:GetProfile(player)
	if not profile then
		return
	end

	local syncEvent = NetworkRouter.GetEvent(NetworkRouter.Names.Events.InventorySync)
	syncEvent:FireClient(player, {
		Inventory = profile.Inventory,
		Capacity = profile.InventoryCapacity,
		Equipment = profile.Equipment,
		Coins = profile.Coins,
	})
end

function InventoryService:GetItemCount(player: Player, itemId: string): number
	local profile = PlayerDataService:GetProfile(player)
	if not profile or not profile.Inventory[itemId] then
		return 0
	end
	return profile.Inventory[itemId].Quantity
end

function InventoryService:HasItem(player: Player, itemId: string, quantity: number): boolean
	local count = self:GetItemCount(player, itemId)
	return count >= quantity
end

function InventoryService:AddItem(player: Player, itemId: string, quantity: number): (boolean, string?)
	if quantity <= 0 or quantity ~= quantity or quantity == math.huge then
		return false, "Invalid quantity"
	end

	local def = ItemDefinitions.Get(itemId)
	if not def then
		return false, "Item does not exist"
	end

	local profile = PlayerDataService:GetProfile(player)
	if not profile then
		return false, "Player data not loaded"
	end

	local currentSlot = profile.Inventory[itemId]
	if currentSlot then
		-- Slot exists; check stack limits
		local newTotal = currentSlot.Quantity + quantity
		if newTotal > def.MaxStack then
			return false, "Exceeds maximum stack limit"
		end
		currentSlot.Quantity = newTotal
	else
		-- New slot; check capacity
		local currentSlotCount = 0
		for _ in pairs(profile.Inventory) do
			currentSlotCount += 1
		end

		if currentSlotCount >= profile.InventoryCapacity then
			return false, "Inventory is full"
		end

		profile.Inventory[itemId] = {
			Id = itemId,
			Quantity = quantity,
		}
	end

	self.ItemAdded:Fire(player, itemId, quantity)
	self:SyncInventory(player)

	local notifEvent = NetworkRouter.GetEvent(NetworkRouter.Names.Events.ShowNotification)
	notifEvent:FireClient(player, "ItemReceived", string.format("+%d %s", quantity, def.Name))

	return true, nil
end

function InventoryService:RemoveItem(player: Player, itemId: string, quantity: number): (boolean, string?)
	if quantity <= 0 or quantity ~= quantity or quantity == math.huge then
		return false, "Invalid quantity"
	end

	local profile = PlayerDataService:GetProfile(player)
	if not profile then
		return false, "Player data not loaded"
	end

	local slot = profile.Inventory[itemId]
	if not slot or slot.Quantity < quantity then
		return false, "Insufficient item quantity"
	end

	slot.Quantity -= quantity
	if slot.Quantity <= 0 then
		profile.Inventory[itemId] = nil
	end

	self.ItemRemoved:Fire(player, itemId, quantity)
	self:SyncInventory(player)

	return true, nil
end

function InventoryService:UseItem(player: Player, itemId: string): (boolean, string?)
	local def = ItemDefinitions.Get(itemId)
	if not def then
		return false, "Item not found"
	end

	if def.Category ~= "Consumable" then
		return false, "Item is not consumable"
	end

	if not self:HasItem(player, itemId, 1) then
		return false, "You do not own this item"
	end

	local character = player.Character
	if not character then
		return false, "Character not found"
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, "Invalid humanoid state"
	end

	if itemId == "item_health_salve" then
		if humanoid.Health >= humanoid.MaxHealth then
			return false, "Health is already full"
		end
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 35)
	elseif itemId == "item_canteen" then
		-- Stamina restoration is notified to client
		local notifEvent = NetworkRouter.GetEvent(NetworkRouter.Names.Events.ShowNotification)
		notifEvent:FireClient(player, "Info", "Refreshed by the cool canteen water!")
	end

	self:RemoveItem(player, itemId, 1)
	self.ItemUsed:Fire(player, itemId)

	return true, nil
end

function InventoryService:EquipItem(player: Player, itemId: string): (boolean, string?)
	local def = ItemDefinitions.Get(itemId)
	if not def then
		return false, "Item not found"
	end

	if def.Category ~= "Equipment" or not def.EquipmentSlot then
		return false, "Item cannot be equipped"
	end

	if not self:HasItem(player, itemId, 1) then
		return false, "You do not own this item"
	end

	local profile = PlayerDataService:GetProfile(player)
	if not profile then
		return false, "Profile not loaded"
	end

	local slotName = def.EquipmentSlot
	if profile.Equipment[slotName] == itemId then
		-- Unequip
		profile.Equipment[slotName] = nil
	else
		-- Equip
		profile.Equipment[slotName] = itemId
	end

	self:SyncInventory(player)
	return true, nil
end

return InventoryService

