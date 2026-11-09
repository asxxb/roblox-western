--!strict
--[[
	TableUtil.luau
	Robust table utilities for immutability, deep copying, and schema reconciliation.
]]

local TableUtil = {}

-- Returns a deep clone of a table, preserving nested dictionaries and arrays
function TableUtil.DeepCopy<T>(target: T): T
	if typeof(target) ~= "table" then
		return target
	end

	local copy = {}
	for key, value in pairs(target :: any) do
		if typeof(value) == "table" then
			copy[key] = TableUtil.DeepCopy(value)
		else
			copy[key] = value
		end
	end

	return (copy :: any) :: T
end

-- Reconciles a target table against a template.
-- Any keys in the template that do not exist in the target are copied into target.
-- Existing target keys are never overwritten.
function TableUtil.Reconcile(target: { [any]: any }, template: { [any]: any }): { [any]: any }
	assert(typeof(target) == "table", "Target must be a table")
	assert(typeof(template) == "table", "Template must be a table")

	for key, defaultValue in pairs(template) do
		if target[key] == nil then
			if typeof(defaultValue) == "table" then
				target[key] = TableUtil.DeepCopy(defaultValue)
			else
				target[key] = defaultValue
			end
		elseif typeof(target[key]) == "table" and typeof(defaultValue) == "table" then
			TableUtil.Reconcile(target[key], defaultValue)
		end
	end

	return target
end

-- Recursively freezes a table to prevent modification
function TableUtil.DeepFreeze<T>(tbl: T): T
	if typeof(tbl) ~= "table" then
		return tbl
	end

	table.freeze(tbl :: any)
	for _, value in pairs(tbl :: any) do
		if typeof(value) == "table" and not table.isfrozen(value) then
			TableUtil.DeepFreeze(value)
		end
	end

	return tbl
end

return TableUtil
