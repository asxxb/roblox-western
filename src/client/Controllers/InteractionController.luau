--!strict
--[[
	InteractionController.luau
	Client interaction handling: ProximityPrompt dispatching, dialogue activation, and visual highlights.
]]

local ProximityPromptService = game:GetService("ProximityPromptService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetworkRouter = require(Shared.Network.NetworkRouter)

local UIController: any
local CameraController: any

local InteractionController = {
	Name = "InteractionController",
}

local localPlayer = Players.LocalPlayer

function InteractionController:Init()
	UIController = require(script.Parent.UIController)
	CameraController = require(script.Parent.CameraController)
end

function InteractionController:Start()
	-- Listen to ProximityPrompt activations
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if player ~= localPlayer then
			return
		end

		local parentPart = prompt.Parent
		if not parentPart then
			return
		end

		local model = parentPart:FindFirstAncestorOfClass("Model")
		local targetInstance = model or parentPart

		-- 1. Check if NPC
		if targetInstance and (CollectionService:HasTag(targetInstance, "NPC") or targetInstance.Parent == workspace:FindFirstChild("NPCs")) then
			local npcId = targetInstance.Name
			CameraController:FocusOnNPC(targetInstance :: Model)
			UIController:OpenDialogue(npcId, targetInstance :: Model)
			return
		end

		-- 2. Check if Interactable world object (Supply Crate, Bandit Cache, etc.)
		local requestFunc = NetworkRouter.GetFunction(NetworkRouter.Names.Functions.RequestInteraction)
		task.spawn(function()
			local ok, err = requestFunc:InvokeServer(targetInstance)
			if not ok and err then
				warn("[InteractionController] Interaction failed: " .. tostring(err))
			end
		end)
	end)

	-- Location Landmark Zone Detection for Quests
	self:SetupLocationTriggers()
end

function InteractionController:SetupLocationTriggers()
	local function bindTrigger(part: BasePart)
		local locationId = part:GetAttribute("LocationId") :: string?
		if not locationId then
			return
		end

		part.Touched:Connect(function(hit)
			local char = localPlayer.Character
			if char and hit:IsDescendantOf(char) then
				local requestFunc = NetworkRouter.GetFunction(NetworkRouter.Names.Functions.RequestInteraction)
				requestFunc:InvokeServer(part)
			end
		end)
	end

	for _, instance in ipairs(CollectionService:GetTagged("QuestLocation")) do
		if instance:IsA("BasePart") then
			bindTrigger(instance)
		end
	end

	CollectionService:GetInstanceAddedSignal("QuestLocation"):Connect(function(instance)
		if instance:IsA("BasePart") then
			bindTrigger(instance)
		end
	end)
end

return InteractionController

