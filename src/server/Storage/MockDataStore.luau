--!strict
--[[
	MockDataStore.luau
	In-memory mock implementation of Roblox GlobalDataStore.
	Provides offline, seamless Studio testing when API services are disabled.
]]

local TableUtil = require(game:GetService("ReplicatedStorage").Shared.Utilities.TableUtil)

type MockDataStore = {
	GetAsync: (self: MockDataStore, key: string) -> any?,
	SetAsync: (self: MockDataStore, key: string, value: any) -> (),
	UpdateAsync: (self: MockDataStore, key: string, transformFunction: (oldValue: any?) -> any?) -> any?,
	RemoveAsync: (self: MockDataStore, key: string) -> any?,
}

local MockDataStoreModule = {}
MockDataStoreModule.__index = MockDataStoreModule

local stores: { [string]: { [string]: any } } = {}

function MockDataStoreModule.new(storeName: string): MockDataStore
	if not stores[storeName] then
		stores[storeName] = {}
	end

	local self = setmetatable({
		_storeName = storeName,
		_data = stores[storeName],
	}, MockDataStoreModule)

	return (self :: any) :: MockDataStore
end

function MockDataStoreModule:GetAsync(key: string): any?
	local raw = self._data[key]
	if raw == nil then
		return nil
	end
	return TableUtil.DeepCopy(raw)
end

function MockDataStoreModule:SetAsync(key: string, value: any)
	self._data[key] = TableUtil.DeepCopy(value)
end

function MockDataStoreModule:UpdateAsync(key: string, transformFunction: (oldValue: any?) -> any?): any?
	local current = self:GetAsync(key)
	local updated = transformFunction(current)
	if updated ~= nil then
		self:SetAsync(key, updated)
	end
	return updated
end

function MockDataStoreModule:RemoveAsync(key: string): any?
	local old = self._data[key]
	self._data[key] = nil
	return old
end

return MockDataStoreModule

