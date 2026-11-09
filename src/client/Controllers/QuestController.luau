--!strict
--[[
	QuestController.luau
	Client-side quest tracking, state caching, and local UI dispatching.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetworkRouter = require(Shared.Network.NetworkRouter)
local Signal = require(Shared.Utilities.Signal)

type ClientQuestData = {
	QuestId: string,
	State: "Inactive" | "Active" | "Completed",
	ObjectiveProgress: { [number]: number },
}

local QuestController = {
	Name = "QuestController",
	QuestUpdated = Signal.new() :: Signal.Signal<string, string, { [number]: number }>,
}

local questCache: { [string]: ClientQuestData } = {}

function QuestController:Init()
	-- Initialization
end

function QuestController:Start()
	local questEvent = NetworkRouter.GetEvent(NetworkRouter.Names.Events.QuestUpdate)
	questEvent.OnClientEvent:Connect(function(questId: string, state: any, progress: any)
		questCache[questId] = {
			QuestId = questId,
			State = state,
			ObjectiveProgress = progress or {},
		}
		self.QuestUpdated:Fire(questId, state, progress or {})
	end)
end

function QuestController:GetQuest(questId: string): ClientQuestData?
	return questCache[questId]
end

function QuestController:GetAllQuests(): { [string]: ClientQuestData }
	return questCache
end

function QuestController:GetActiveQuests(): { ClientQuestData }
	local active = {}
	for _, q in pairs(questCache) do
		if q.State == "Active" then
			table.insert(active, q)
		end
	end
	return active
end

return QuestController
