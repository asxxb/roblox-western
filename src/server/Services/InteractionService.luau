--!strict
--[[
	InteractionService.luau
	Authoritative spatial interaction validation, cooldown enforcement, and world object interactions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local SpatialUtil = require(Shared.Utilities.SpatialUtil)
local Signal = require(Shared.Utilities.Signal)
local NetworkRouter = require(Shared.Network.NetworkRouter)

local InventoryService: any
local QuestService: any

local InteractionService = {
	Name = "InteractionService",
	OnInteracted = Signal.new() :: Signal.Signal<Player, Instance>,
}

local playerCooldowns: { [Player]: number } = {}

function InteractionService:Init()
	InventoryService = require(script.Parent.InventoryService)
	QuestService = require(script.Parent.QuestService)
end

function InteractionService:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		playerCooldowns[player] = nil
	end)

	local requestFunc = NetworkRouter.GetFunction(NetworkRouter.Names.Functions.RequestInteraction)
	requestFunc.OnServerInvoke = function(player: Player, targetInstance: any)
		if typeof(targetInstance) ~= "Instance" then
			return false, "Invalid target instance"
		end
		return self:ProcessInteraction(player, targetInstance)
	end
end

function InteractionService:ProcessInteraction(player: Player, target: Instance): (boolean, string?)
	local now = os.clock()
	local lastTime = playerCooldowns[player] or 0
	if (now - lastTime) < GameConfig.Interaction.InteractCooldown then
		return false, "Interaction on cooldown"
	end
	playerCooldowns[player] = now

	-- Validate distance with latency buffer
	local maxDist = GameConfig.Interaction.DefaultMaxDistance
	if not SpatialUtil.IsWithinDistance(player, target, maxDist, GameConfig.Interaction.PingTolerance) then
		return false, "Too far away to interact"
	end

	-- Check if target is an Interactable item node (e.g., Supply Crate or Gold Nugget)
	if CollectionService:HasTag(target, "Interactable") or target:GetAttribute("Interactable") == true then
		local itemId = target:GetAttribute("ItemId") :: string?
		if itemId then
			local count = target:GetAttribute("Quantity") or 1
			local addOk, addErr = InventoryService:AddItem(player, itemId, count)
			if not addOk then
				return false, addErr or "Failed to pick up item"
			end

			-- Notify QuestService to evaluate "Collect" objectives
			QuestService:OnItemCollected(player, itemId, count)

			-- Handle item node despawn / respawn
			self:HandleNodePickup(target)
			self.OnInteracted:Fire(player, target)
			return true, nil
		end
	end

	self.OnInteracted:Fire(player, target)
	return true, nil
end

function InteractionService:HandleNodePickup(target: Instance)
	local isPart = target:IsA("BasePart")
	local parts: { BasePart } = {}

	if isPart then
		table.insert(parts, target :: BasePart)
	elseif target:IsA("Model") then
		for _, desc in ipairs(target:GetDescendants()) do
			if desc:IsA("BasePart") then
				table.insert(parts, desc)
			end
		end
	end

	local prompt = target:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end

	-- Hide and disable collision temporarily
	for _, p in ipairs(parts) do
		p.Transparency = 1
		p.CanCollide = false
	end

	-- Respawn node after 20 seconds so the frontier world remains dynamic
	task.delay(20, function()
		if target.Parent then
			for _, p in ipairs(parts) do
				p.Transparency = 0
				p.CanCollide = true
			end
			if prompt then
				prompt.Enabled = true
			end
		end
	end)
end

return InteractionService

