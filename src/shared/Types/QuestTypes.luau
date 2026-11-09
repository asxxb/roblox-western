--!strict
--[[
	QuestTypes.luau
	Data models for quests, objectives, progression states, and rewards.
]]

export type ObjectiveType = "Collect" | "Visit" | "Deliver" | "Talk"

export type QuestObjective = {
	Type: ObjectiveType,
	Description: string,
	TargetId: string,           -- Target item, location tag/name, or NPC ID
	TargetCount: number,
}

export type QuestReward = {
	Coins: number,
	Items: { { ItemId: string, Quantity: number } }?,
	Experience: number?,
}

export type QuestDefinition = {
	Id: string,
	Title: string,
	Description: string,
	GiverNPCId: string,
	PrerequisiteQuestIds: { string },
	Objectives: { QuestObjective },
	Rewards: QuestReward,
	Repeatable: boolean,
}

return {}

