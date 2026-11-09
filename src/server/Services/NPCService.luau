--!strict
--[[
	NPCService.luau
	Authoritative NPC entity management: PathfindingService AI navigation, dialogue routing, and quest triggers.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local NPCDefinitions = require(Shared.Definitions.NPCDefinitions)
local NPCTypes = require(Shared.Types.NPCTypes)
local GameConfig = require(Shared.Config.GameConfig)
local SpatialUtil = require(Shared.Utilities.SpatialUtil)
local NetworkRouter = require(Shared.Network.NetworkRouter)
local Signal = require(Shared.Utilities.Signal)

type NPCDefinition = NPCTypes.NPCDefinition
type DialogueNode = NPCTypes.DialogueNode

local QuestService: any
local EconomyService: any

type ActiveNPC = {
	Definition: NPCDefinition,
	Model: Model,
	Humanoid: Humanoid,
	RootPart: BasePart,
	OriginCFrame: CFrame,
	IsBusy: boolean,
	CurrentNodeIndex: number,
}

local activeNPCs: { [string]: ActiveNPC } = {}

local NPCService = {
	Name = "NPCService",
	NPCInteracted = Signal.new() :: Signal.Signal<Player, string>,
}

function NPCService:Init()
	QuestService = require(script.Parent.QuestService)
	EconomyService = require(script.Parent.EconomyService)
end

function NPCService:Start()
	-- Register DialogueChoice RemoteFunction
	local dialogueFunc = NetworkRouter.GetFunction(NetworkRouter.Names.Functions.DialogueChoice)
	dialogueFunc.OnServerInvoke = function(player: Player, npcId: any, nodeId: any, choiceIndex: any)
		if typeof(npcId) ~= "string" or typeof(nodeId) ~= "string" or typeof(choiceIndex) ~= "number" then
			return { Success = false, ErrorMessage = "Invalid parameters" }
		end
		return self:ProcessDialogueChoice(player, npcId, nodeId, math.floor(choiceIndex))
	end
end

function NPCService:RegisterNPCModel(npcId: string, model: Model)
	local def = NPCDefinitions.Get(npcId)
	if not def then
		warn(string.format("[NPCService] Unknown NPC definition for ID: %s", npcId))
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?

	if not humanoid or not rootPart then
		warn(string.format("[NPCService] NPC %s is missing Humanoid or HumanoidRootPart!", npcId))
		return
	end

	humanoid.WalkSpeed = GameConfig.NPC.WalkSpeed

	local activeRecord: ActiveNPC = {
		Definition = def,
		Model = model,
		Humanoid = humanoid,
		RootPart = rootPart,
		OriginCFrame = rootPart.CFrame,
		IsBusy = false,
		CurrentNodeIndex = 1,
	}

	activeNPCs[npcId] = activeRecord

	-- Start autonomous AI pathfinding loop
	task.spawn(function()
		self:RunNPCLoop(activeRecord)
	end)

	print(string.format("[NPCService] Registered and started AI for NPC: %s (%s)", def.DisplayName, npcId))
end

function NPCService:RunNPCLoop(npc: ActiveNPC)
	local def = npc.Definition
	local path = PathfindingService:CreatePath({
		AgentRadius = 2.0,
		AgentHeight = 5.0,
		AgentCanJump = false,
		WaypointSpacing = GameConfig.NPC.PathfindingWaypointSpacing,
	})

	while npc.Model.Parent do
		-- Random pause between patrol/wander behaviors
		local waitTime = math.random(GameConfig.NPC.WanderPauseMin * 10, GameConfig.NPC.WanderPauseMax * 10) / 10
		task.wait(waitTime)

		if not npc.IsBusy then
			local destination: Vector3

			if def.PatrolWaypoints and #def.PatrolWaypoints > 0 then
				destination = def.PatrolWaypoints[npc.CurrentNodeIndex]
				npc.CurrentNodeIndex = (npc.CurrentNodeIndex % #def.PatrolWaypoints) + 1
			else
				-- Wander randomly within defined radius from origin
				local angle = math.random() * math.pi * 2
				local distance = math.random(2, math.max(3, def.WanderRadius))
				local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
				destination = npc.OriginCFrame.Position + offset
			end

			self:NavigateTo(npc, path, destination)
		end
	end
end

function NPCService:NavigateTo(npc: ActiveNPC, path: Path, destination: Vector3)
	local computeOk, _ = pcall(function()
		path:ComputeAsync(npc.RootPart.Position, destination)
	end)

	if not computeOk or path.Status ~= Enum.PathStatus.Success then
		return
	end

	local waypoints = path:GetWaypoints()
	for i = 2, #waypoints do
		if npc.IsBusy or not npc.Model.Parent then
			npc.Humanoid:MoveTo(npc.RootPart.Position)
			break
		end

		local wp = waypoints[i]
		npc.Humanoid:MoveTo(wp.Position)

		local reached = false
		local connection: RBXScriptConnection
		connection = npc.Humanoid.MoveToFinished:Connect(function(status)
			reached = true
		end)

		local startTime = os.clock()
		while not reached and (os.clock() - startTime) < 5.0 do
			if npc.IsBusy then
				break
			end
			task.wait(0.1)
		end

		if connection then
			connection:Disconnect()
		end

		if not reached then
			-- Stuck detection triggered; abort remaining path
			break
		end
	end
end

function NPCService:ProcessDialogueChoice(
	player: Player,
	npcId: string,
	nodeId: string,
	choiceIndex: number
): { Success: boolean, ErrorMessage: string?, NextNode: DialogueNode?, ActionTriggered: string?, ActionPayload: string? }
	local def = NPCDefinitions.Get(npcId)
	if not def then
		return { Success = false, ErrorMessage = "Unknown NPC" }
	end

	local npcRecord = activeNPCs[npcId]
	if npcRecord and not SpatialUtil.IsWithinDistance(player, npcRecord.RootPart, def.InteractionDistance, GameConfig.Interaction.PingTolerance) then
		return { Success = false, ErrorMessage = "Too far from NPC" }
	end

	local currentNode = def.DefaultDialogueTree[nodeId]
	if not currentNode then
		return { Success = false, ErrorMessage = "Dialogue node not found" }
	end

	local choice = currentNode.Choices[choiceIndex]
	if not choice then
		return { Success = false, ErrorMessage = "Invalid choice option" }
	end

	-- Execute special dialogue action if defined
	local actionTriggered = choice.Action
	local actionPayload = choice.ActionPayload

	if choice.Action == "AcceptQuest" and choice.ActionPayload then
		local ok, err = QuestService:AcceptQuest(player, choice.ActionPayload)
		if not ok then
			return { Success = false, ErrorMessage = err or "Could not accept quest" }
		end
	elseif choice.Action == "CompleteQuest" and choice.ActionPayload then
		local ok, err = QuestService:CompleteQuest(player, choice.ActionPayload)
		if not ok then
			return { Success = false, ErrorMessage = err or "Objectives not met" }
		end
	end

	local nextNode: DialogueNode? = nil
	if choice.NextNodeId then
		nextNode = def.DefaultDialogueTree[choice.NextNodeId]
	end

	self.NPCInteracted:Fire(player, npcId)

	return {
		Success = true,
		NextNode = nextNode,
		ActionTriggered = actionTriggered,
		ActionPayload = actionPayload,
	}
end

return NPCService
