--!strict
--[[
	NetworkTypes.luau
	Typed network contracts for RemoteFunctions and RemoteEvents.
]]

export type NetworkResponse<T> = {
	Success: boolean,
	ErrorMessage: string?,
	Data: T?,
}

export type InteractionRequestPayload = {
	TargetInstance: Instance,
}

export type ShopTransactionRequest = {
	ItemId: string,
	Quantity: number,
	TransactionType: "Buy" | "Sell",
}

export type DialogueChoiceRequest = {
	NPCId: string,
	NodeId: string,
	ChoiceIndex: number,
}

return {}

