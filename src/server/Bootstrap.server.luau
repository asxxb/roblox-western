--!strict
--[[
	Bootstrap.server.luau
	Authoritative server lifecycle orchestrator.
	Deterministic two-phase execution: Init() -> Start() across all services.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetworkRouter = require(Shared.Network.NetworkRouter)

local startTime = os.clock()
print("==================================================")
print("🤠 WILD WEST FRONTIER — SERVER INITIALIZING...")
print("==================================================")

-- 1. Initialize Network Remotes
NetworkRouter.InitServer()
print("[ServerBootstrap] NetworkRouter initialized.")

-- 2. Discover Services
local servicesFolder = script.Parent:WaitForChild("Services")
local services: { [string]: any } = {}
local serviceLoadOrder: { any } = {}

-- Explicit dependency ordering to guarantee clean initialization
local preferredOrder = {
	"PlayerDataService",
	"InventoryService",
	"EconomyService",
	"QuestService",
	"NPCService",
	"InteractionService",
	"WorldSpawnService",
}

for _, serviceName in ipairs(preferredOrder) do
	local module = servicesFolder:FindFirstChild(serviceName)
	if module and module:IsA("ModuleScript") then
		local serviceInstance = require(module)
		services[serviceName] = serviceInstance
		table.insert(serviceLoadOrder, serviceInstance)
	end
end

-- Load any additional services not listed in preferredOrder
for _, child in ipairs(servicesFolder:GetChildren()) do
	if child:IsA("ModuleScript") and not services[child.Name] then
		local serviceInstance = require(child)
		services[child.Name] = serviceInstance
		table.insert(serviceLoadOrder, serviceInstance)
	end
end

-- 3. Phase 1: Init()
print("[ServerBootstrap] Phase 1: Initializing services...")
for _, service in ipairs(serviceLoadOrder) do
	if typeof(service.Init) == "function" then
		local success, err = pcall(function()
			service:Init()
		end)
		if not success then
			error(string.format("[ServerBootstrap] Service %s failed to Init: %s", tostring(service.Name), tostring(err)))
		end
	end
end

-- 4. Phase 2: Start()
print("[ServerBootstrap] Phase 2: Starting services...")
for _, service in ipairs(serviceLoadOrder) do
	if typeof(service.Start) == "function" then
		task.spawn(function()
			local success, err = pcall(function()
				service:Start()
			end)
			if not success then
				warn(string.format("[ServerBootstrap] Service %s encountered error in Start: %s", tostring(service.Name), tostring(err)))
			end
		end)
	end
end

local elapsedTime = math.floor((os.clock() - startTime) * 1000)
print(string.format("[ServerBootstrap] All %d services started in %d ms.", #serviceLoadOrder, elapsedTime))
print("==================================================")
