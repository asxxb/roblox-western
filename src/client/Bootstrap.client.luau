--!strict
--[[
	Bootstrap.client.luau
	Authoritative client lifecycle orchestrator.
	Deterministic two-phase execution: Init() -> Start() across all client controllers.
]]

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local startTime = os.clock()
print("==================================================")
print("🤠 WILD WEST FRONTIER — CLIENT INITIALIZING...")
print("==================================================")

local controllersFolder = script.Parent:WaitForChild("Controllers")
local controllers: { [string]: any } = {}
local controllerLoadOrder: { any } = {}

-- Explicit dependency ordering to guarantee clean initialization
local preferredOrder = {
	"InputController",
	"CameraController",
	"InventoryController",
	"QuestController",
	"UIController",
	"InteractionController",
}

for _, controllerName in ipairs(preferredOrder) do
	local module = controllersFolder:FindFirstChild(controllerName)
	if module and module:IsA("ModuleScript") then
		local controllerInstance = require(module)
		controllers[controllerName] = controllerInstance
		table.insert(controllerLoadOrder, controllerInstance)
	end
end

-- Load any additional controllers
for _, child in ipairs(controllersFolder:GetChildren()) do
	if child:IsA("ModuleScript") and not controllers[child.Name] then
		local controllerInstance = require(child)
		controllers[child.Name] = controllerInstance
		table.insert(controllerLoadOrder, controllerInstance)
	end
end

-- 1. Phase 1: Init()
print("[ClientBootstrap] Phase 1: Initializing controllers...")
for _, controller in ipairs(controllerLoadOrder) do
	if typeof(controller.Init) == "function" then
		local success, err = pcall(function()
			controller:Init()
		end)
		if not success then
			error(string.format("[ClientBootstrap] Controller %s failed to Init: %s", tostring(controller.Name), tostring(err)))
		end
	end
end

-- 2. Phase 2: Start()
print("[ClientBootstrap] Phase 2: Starting controllers...")
for _, controller in ipairs(controllerLoadOrder) do
	if typeof(controller.Start) == "function" then
		task.spawn(function()
			local success, err = pcall(function()
				controller:Start()
			end)
			if not success then
				warn(string.format("[ClientBootstrap] Controller %s encountered error in Start: %s", tostring(controller.Name), tostring(err)))
			end
		end)
	end
end

local elapsedTime = math.floor((os.clock() - startTime) * 1000)
print(string.format("[ClientBootstrap] All %d controllers started in %d ms.", #controllerLoadOrder, elapsedTime))
print("==================================================")

