--!strict
--[[
	NetworkRouter.luau
	Centralized networking registry and remote access points for client-server communication.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTES_FOLDER_NAME = "WWF_Remotes"

local RemoteNames = {
	Events = {
		InventorySync = "InventorySync",
		QuestUpdate = "QuestUpdate",
		ShowNotification = "ShowNotification",
		PlayWorldSound = "PlayWorldSound",
		NPCStateUpdate = "NPCStateUpdate",
		PlayerStaminaUpdate = "PlayerStaminaUpdate",
	},

	Functions = {
		GetPlayerData = "GetPlayerData",
		RequestInteraction = "RequestInteraction",
		DialogueChoice = "DialogueChoice",
		PurchaseItem = "PurchaseItem",
		SellItem = "SellItem",
		UseItem = "UseItem",
		EquipItem = "EquipItem",
	},
}

local NetworkRouter = {}
NetworkRouter.Names = RemoteNames

local remotesFolder: Folder

local function getOrCreateRemotesFolder(): Folder
	if remotesFolder then
		return remotesFolder
	end

	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
		if existing and existing:IsA("Folder") then
			remotesFolder = existing
		else
			local folder = Instance.new("Folder")
			folder.Name = REMOTES_FOLDER_NAME
			folder.Parent = ReplicatedStorage
			remotesFolder = folder

			-- Populate Server RemoteEvents
			for _, eventName in pairs(RemoteNames.Events) do
				if not folder:FindFirstChild(eventName) then
					local event = Instance.new("RemoteEvent")
					event.Name = eventName
					event.Parent = folder
				end
			end

			-- Populate Server RemoteFunctions
			for _, funcName in pairs(RemoteNames.Functions) do
				if not folder:FindFirstChild(funcName) then
					local func = Instance.new("RemoteFunction")
					func.Name = funcName
					func.Parent = folder
				end
			end
		end
	else
		-- Client yields until the folder is replicated
		remotesFolder = ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME, 10) :: Folder
		if not remotesFolder then
			error("[NetworkRouter] Failed to find " .. REMOTES_FOLDER_NAME .. " on client!")
		end
	end

	return remotesFolder
end

function NetworkRouter.InitServer()
	assert(RunService:IsServer(), "[NetworkRouter] InitServer can only be called on the server")
	getOrCreateRemotesFolder()
end

function NetworkRouter.GetEvent(eventName: string): RemoteEvent
	local folder = getOrCreateRemotesFolder()
	if RunService:IsServer() then
		local event = folder:FindFirstChild(eventName) :: RemoteEvent?
		if not event then
			event = Instance.new("RemoteEvent")
			event.Name = eventName
			event.Parent = folder
		end
		return event
	else
		return folder:WaitForChild(eventName, 10) :: RemoteEvent
	end
end

function NetworkRouter.GetFunction(functionName: string): RemoteFunction
	local folder = getOrCreateRemotesFolder()
	if RunService:IsServer() then
		local func = folder:FindFirstChild(functionName) :: RemoteFunction?
		if not func then
			func = Instance.new("RemoteFunction")
			func.Name = functionName
			func.Parent = folder
		end
		return func
	else
		return folder:WaitForChild(functionName, 10) :: RemoteFunction
	end
end

return NetworkRouter

