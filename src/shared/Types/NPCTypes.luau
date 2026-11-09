--!strict
--[[
	NPCTypes.luau
	Data models for NPC definitions, archetypes, dialogue trees, and state.
]]

export type NPCArchetype = "Sheriff" | "Merchant" | "QuestGiver" | "TownCitizen" | "StableMaster"

export type DialogueAction = "AcceptQuest" | "CompleteQuest" | "OpenShop" | "Custom" | "None"

export type DialogueChoice = {
	Text: string,
	NextNodeId: string?,        -- nil terminates dialogue
	Action: DialogueAction?,
	ActionPayload: string?,     -- e.g. QuestId or ShopType
	RequirementQuestId: string?, -- Optional requirement to see/select this choice
}

export type DialogueNode = {
	NodeId: string,
	Text: string,
	Choices: { DialogueChoice },
}

export type NPCDefinition = {
	Id: string,
	DisplayName: string,
	RoleTitle: string,
	Archetype: NPCArchetype,
	DefaultDialogueTree: { [string]: DialogueNode },
	InitialNodeId: string,
	PatrolWaypoints: { Vector3 }?,
	WanderRadius: number,
	InteractionDistance: number,
}

return {}
