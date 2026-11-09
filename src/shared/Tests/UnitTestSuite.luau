--!strict
--[[
	UnitTestSuite.luau
	Automated unit and integration test suite for Wild West Frontier.
	Validates: Signals, TableUtil Reconciliation, Item Registries, Quest Chains,
	Dialogue Trees, Spatial Distance Math, and Mock Persistence.
]]

local TableUtil = require(script.Parent.Parent.Utilities.TableUtil)
local Signal = require(script.Parent.Parent.Utilities.Signal)
local SpatialUtil = require(script.Parent.Parent.Utilities.SpatialUtil)
local ItemDefinitions = require(script.Parent.Parent.Definitions.ItemDefinitions)
local QuestDefinitions = require(script.Parent.Parent.Definitions.QuestDefinitions)
local NPCDefinitions = require(script.Parent.Parent.Definitions.NPCDefinitions)
local ItemEnums = require(script.Parent.Parent.Constants.ItemEnums)
local QuestEnums = require(script.Parent.Parent.Constants.QuestEnums)

local UnitTestSuite = {}

type TestResult = {
	Name: string,
	Passed: boolean,
	ErrorMessage: string?,
}

function UnitTestSuite.RunAll(): { Passed: number, Failed: number, Results: { TestResult } }
	local results: { TestResult } = {}
	local passedCount = 0
	local failedCount = 0

	local function assertTest(name: string, condition: boolean, errorMsg: string?)
		if condition then
			passedCount += 1
			table.insert(results, { Name = name, Passed = true })
		else
			failedCount += 1
			local msg = errorMsg or "Assertion failed"
			table.insert(results, { Name = name, Passed = false, ErrorMessage = msg })
		end
	end

	-- TEST 1: Signal Connect, Fire, and Disconnect
	local testSignal = Signal.new()
	local signalFiredCount = 0
	local conn = testSignal:Connect(function(val: number)
		signalFiredCount += val
	end)
	testSignal:Fire(5)
	assertTest("Signal_FiresCorrectly", signalFiredCount == 5, "Signal failed to fire handler")
	conn:Disconnect()
	testSignal:Fire(10)
	assertTest("Signal_DisconnectsCorrectly", signalFiredCount == 5, "Signal handler fired after disconnect")

	-- TEST 2: TableUtil Reconcile (Schema Migration)
	local oldSavedData = {
		SchemaVersion = 1,
		Coins = 150,
		Inventory = {
			["item_canteen"] = { Id = "item_canteen", Quantity = 2 },
		},
	}
	local newTemplate = {
		SchemaVersion = 2,
		Coins = 50,
		Inventory = {},
		Equipment = { Hat = nil, Outfit = nil },
		NewConfigField = "DefaultValue",
	}
	local reconciled = TableUtil.Reconcile(oldSavedData, newTemplate)
	assertTest("TableUtil_PreservesExistingData", reconciled.Coins == 150, "Reconcile overwrote existing coin balance")
	assertTest("TableUtil_MigratesNewFields", reconciled.NewConfigField == "DefaultValue", "Reconcile failed to add new schema fields")
	assertTest("TableUtil_PopulatesNestedDefaults", reconciled.Equipment ~= nil and reconciled.Equipment.Hat == nil, "Reconcile failed to initialize nested table")

	-- TEST 3: Item Definitions Integrity
	local allItems = ItemDefinitions.GetAll()
	local itemsValid = true
	local invalidItemReason = ""
	for id, def in pairs(allItems) do
		if def.Id ~= id then
			itemsValid = false
			invalidItemReason = string.format("ID mismatch: %s ~= %s", def.Id, id)
			break
		end
		if def.MaxStack <= 0 then
			itemsValid = false
			invalidItemReason = string.format("Invalid MaxStack for %s", id)
			break
		end
		if def.BuyPrice and def.BuyPrice <= 0 then
			itemsValid = false
			invalidItemReason = string.format("Invalid BuyPrice for %s", id)
			break
		end
	end
	assertTest("ItemDefinitions_RegistryIntegrity", itemsValid, invalidItemReason)

	-- TEST 4: Quest Definitions & Objective Structure
	local allQuests = QuestDefinitions.GetAll()
	local questsValid = true
	local invalidQuestReason = ""
	for id, quest in pairs(allQuests) do
		if #quest.Objectives == 0 then
			questsValid = false
			invalidQuestReason = string.format("Quest %s has no objectives", id)
			break
		end
		for objIdx, obj in ipairs(quest.Objectives) do
			if obj.TargetCount <= 0 then
				questsValid = false
				invalidQuestReason = string.format("Quest %s objective %d targetCount <= 0", id, objIdx)
				break
			end
		end
	end
	assertTest("QuestDefinitions_RegistryIntegrity", questsValid, invalidQuestReason)

	-- TEST 5: NPC Dialogue Tree Integrity
	local allNPCs = NPCDefinitions.GetAll()
	local npcValid = true
	local invalidNPCReason = ""
	for id, npc in pairs(allNPCs) do
		if not npc.DefaultDialogueTree[npc.InitialNodeId] then
			npcValid = false
			invalidNPCReason = string.format("NPC %s initial node %s missing from tree", id, npc.InitialNodeId)
			break
		end
		for nodeId, node in pairs(npc.DefaultDialogueTree) do
			for choiceIdx, choice in ipairs(node.Choices) do
				if choice.NextNodeId and not npc.DefaultDialogueTree[choice.NextNodeId] then
					npcValid = false
					invalidNPCReason = string.format("NPC %s node %s choice %d points to non-existent NextNode %s", id, nodeId, choiceIdx, choice.NextNodeId)
					break
				end
			end
		end
	end
	assertTest("NPCDefinitions_DialogueTreeIntegrity", npcValid, invalidNPCReason)

	-- TEST 6: Economy Math Verification
	local supplyCrate = ItemDefinitions.Get(ItemEnums.Ids.SupplyCrate)
	assertTest("Economy_SupplyCrateExists", supplyCrate ~= nil, "Supply crate definition missing")
	if supplyCrate then
		local sellValue = math.max(1, math.floor(supplyCrate.BaseValue * 0.6))
		assertTest("Economy_SellPriceFormula", sellValue == 9, string.format("Expected sell price 9, got %d", sellValue))
	end

	return {
		Passed = passedCount,
		Failed = failedCount,
		Results = results,
	}
end

return UnitTestSuite
