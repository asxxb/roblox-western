--!strict
--[[
	PlayerDataTypes.luau
	Authoritative player data types, schema versioning, and state shapes.
]]

export type ItemSlot = {
	Id: string,
	Quantity: number,
	Metadata: { [string]: any }?,
}

export type QuestProgress = {
	QuestId: string,
	State: "Inactive" | "Active" | "Completed",
	ObjectiveProgress: { [number]: number }, -- Maps objective index to current count
	StartedTimestamp: number,
	CompletedTimestamp: number?,
}

export type PlayerSettings = {
	MusicVolume: number,
	SfxVolume: number,
	ScreenShake: boolean,
}

export type PlayerData = {
	SchemaVersion: number,
	Coins: number,
	Inventory: { [string]: ItemSlot },      -- Keyed by ItemId
	InventoryCapacity: number,
	Equipment: {
		Hat: string?,
		Outfit: string?,
		Handheld: string?,
	},
	Quests: { [string]: QuestProgress },    -- Keyed by QuestId
	CompletedQuestCount: number,
	UnlockedLocations: { [string]: boolean },
	Settings: PlayerSettings,
	LastSavedTimestamp: number,
}

return {}

