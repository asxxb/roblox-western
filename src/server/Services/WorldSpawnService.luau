--!strict
--[[
	WorldSpawnService.luau
	Procedural 3D Western world generator: constructs the frontier town, stylized buildings,
	lighting, interactive quest nodes, supply crates, and NPC rigs.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ItemEnums = require(Shared.Constants.ItemEnums)
local QuestEnums = require(Shared.Constants.QuestEnums)
local NPCDefinitions = require(Shared.Definitions.NPCDefinitions)

local NPCService: any

local WorldSpawnService = {
	Name = "WorldSpawnService",
}

-- Western Color Palette
local PALETTE = {
	Dirt = Color3.fromRGB(168, 126, 84),
	WoodPlank = Color3.fromRGB(139, 94, 60),
	DarkWood = Color3.fromRGB(94, 62, 38),
	LightWood = Color3.fromRGB(194, 150, 105),
	RedWood = Color3.fromRGB(140, 52, 40),
	Sand = Color3.fromRGB(218, 184, 134),
	Stone = Color3.fromRGB(130, 120, 110),
	Gold = Color3.fromRGB(245, 190, 45),
	Iron = Color3.fromRGB(60, 60, 65),
	RoofTile = Color3.fromRGB(120, 70, 45),
	CactusGreen = Color3.fromRGB(75, 120, 65),
}

local function createPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.WoodPlanks
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function WorldSpawnService:Init()
	NPCService = require(script.Parent.NPCService)
end

function WorldSpawnService:Start()
	self:SetupAtmosphericLighting()

	local mapFolder = Workspace:FindFirstChild("Map")
	if not mapFolder then
		mapFolder = Instance.new("Folder")
		mapFolder.Name = "Map"
		mapFolder.Parent = Workspace

		self:BuildGroundAndRoads(mapFolder)
		self:BuildSaloon(mapFolder)
		self:BuildSheriffOffice(mapFolder)
		self:BuildGeneralStore(mapFolder)
		self:BuildStables(mapFolder)
		self:BuildDesertOutpost(mapFolder)
		self:SpawnSupplyCrates(mapFolder)
		self:SpawnTownFoliageAndProps(mapFolder)
	end

	self:SpawnNPCs()
end

function WorldSpawnService:SetupAtmosphericLighting()
	Lighting.ClockTime = 17.65 -- Golden hour frontier sunset
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.2
	Lighting.OutdoorAmbient = Color3.fromRGB(160, 130, 110)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 215, 160)
	Lighting.ColorShift_Bottom = Color3.fromRGB(140, 100, 70)
	Lighting.ShadowSoftness = 0.2

	-- Atmosphere
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.35
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(235, 175, 125)
	atmosphere.Decay = Color3.fromRGB(180, 105, 75)
	atmosphere.Glare = 0.5
	atmosphere.Haze = 1.8

	-- ColorCorrection
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Parent = Lighting
	end
	cc.TintColor = Color3.fromRGB(255, 240, 220)
	cc.Contrast = 0.12
	cc.Saturation = 0.15

	-- Bloom
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 0.85

	-- SunRays
	local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if not sunRays then
		sunRays = Instance.new("SunRaysEffect")
		sunRays.Parent = Lighting
	end
	sunRays.Intensity = 0.18
	sunRays.Spread = 0.75
end

function WorldSpawnService:BuildGroundAndRoads(parent: Folder)
	-- Main Desert Terrain Slab
	createPart(parent, "DesertBase", Vector3.new(240, 4, 240), CFrame.new(0, -2, 0), PALETTE.Sand, Enum.Material.Sand)

	-- Dirt Main Street
	createPart(parent, "MainStreet", Vector3.new(34, 0.4, 180), CFrame.new(0, 0.2, 0), PALETTE.Dirt, Enum.Material.Ground)

	-- Wooden Boardwalk Sidewalks (West & East)
	createPart(parent, "BoardwalkWest", Vector3.new(10, 0.8, 160), CFrame.new(-22, 0.4, 0), PALETTE.WoodPlank, Enum.Material.WoodPlanks)
	createPart(parent, "BoardwalkEast", Vector3.new(10, 0.8, 160), CFrame.new(22, 0.4, 0), PALETTE.WoodPlank, Enum.Material.WoodPlanks)

	-- Town Square Centerpiece (Hitching post and stone trough)
	local centerCFrame = CFrame.new(0, 1, 0)
	createPart(parent, "HitchingPost_Beam", Vector3.new(16, 0.8, 0.8), centerCFrame * CFrame.new(0, 2.5, 0), PALETTE.DarkWood)
	createPart(parent, "HitchingPost_Leg1", Vector3.new(0.8, 3, 0.8), centerCFrame * CFrame.new(-7, 1.5, 0), PALETTE.DarkWood)
	createPart(parent, "HitchingPost_Leg2", Vector3.new(0.8, 3, 0.8), centerCFrame * CFrame.new(7, 1.5, 0), PALETTE.DarkWood)
end

function WorldSpawnService:BuildSaloon(parent: Folder)
	local saloon = Instance.new("Model")
	saloon.Name = "Building_Saloon"
	saloon.Parent = parent

	local baseCF = CFrame.new(-42, 0, -35)

	-- Floor & Porch
	createPart(saloon, "Floor", Vector3.new(32, 1, 36), baseCF * CFrame.new(0, 0.5, 0), PALETTE.DarkWood)
	createPart(saloon, "Porch", Vector3.new(32, 0.8, 8), baseCF * CFrame.new(0, 0.4, 22), PALETTE.WoodPlank)

	-- Walls
	createPart(saloon, "Wall_Back", Vector3.new(32, 16, 1.5), baseCF * CFrame.new(0, 8.5, -18), PALETTE.WoodPlank)
	createPart(saloon, "Wall_Left", Vector3.new(1.5, 16, 36), baseCF * CFrame.new(-16, 8.5, 0), PALETTE.WoodPlank)
	createPart(saloon, "Wall_Right", Vector3.new(1.5, 16, 36), baseCF * CFrame.new(16, 8.5, 0), PALETTE.WoodPlank)

	-- Front Wall with Doorway
	createPart(saloon, "Wall_Front_L", Vector3.new(12, 16, 1.5), baseCF * CFrame.new(-10, 8.5, 18), PALETTE.WoodPlank)
	createPart(saloon, "Wall_Front_R", Vector3.new(12, 16, 1.5), baseCF * CFrame.new(10, 8.5, 18), PALETTE.WoodPlank)
	createPart(saloon, "Wall_Front_Top", Vector3.new(8, 6, 1.5), baseCF * CFrame.new(0, 13.5, 18), PALETTE.WoodPlank)

	-- Western False Facade & Roof
	createPart(saloon, "Facade", Vector3.new(34, 6, 1), baseCF * CFrame.new(0, 19, 18), PALETTE.WoodPlank)
	createPart(saloon, "Roof", Vector3.new(34, 1.5, 40), baseCF * CFrame.new(0, 16.5, 0), PALETTE.RoofTile)

	-- Saloon Signboard
	local sign = createPart(saloon, "Signboard", Vector3.new(20, 3, 0.6), baseCF * CFrame.new(0, 18.5, 18.6), PALETTE.LightWood)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.Parent = sign
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Text = "THE DUSTY SPUR SALOON"
	textLabel.Font = Enum.Font.Antique
	textLabel.TextScaled = true
	textLabel.TextColor3 = PALETTE.DarkWood
	textLabel.BackgroundTransparency = 1
	textLabel.Parent = surfaceGui

	-- Interior Bar Counter
	createPart(saloon, "BarCounter", Vector3.new(20, 3.5, 3), baseCF * CFrame.new(0, 2.25, -10), PALETTE.DarkWood)

	-- Spatial Landmark Trigger for Quest
	local trigger = createPart(saloon, "Trigger_Saloon", Vector3.new(16, 8, 16), baseCF * CFrame.new(0, 4, 10), Color3.new(1, 1, 1))
	trigger.Transparency = 1
	trigger.CanCollide = false
	trigger:SetAttribute("LocationId", QuestEnums.Locations.Saloon)
	CollectionService:AddTag(trigger, "QuestLocation")
end

function WorldSpawnService:BuildSheriffOffice(parent: Folder)
	local sheriffOffice = Instance.new("Model")
	sheriffOffice.Name = "Building_SheriffOffice"
	sheriffOffice.Parent = parent

	local baseCF = CFrame.new(42, 0, -35)

	-- Floor & Walls
	createPart(sheriffOffice, "Floor", Vector3.new(28, 1, 30), baseCF * CFrame.new(0, 0.5, 0), PALETTE.DarkWood)
	createPart(sheriffOffice, "Wall_Back", Vector3.new(28, 14, 1.5), baseCF * CFrame.new(0, 7.5, -15), PALETTE.WoodPlank)
	createPart(sheriffOffice, "Wall_Left", Vector3.new(1.5, 14, 30), baseCF * CFrame.new(-14, 7.5, 0), PALETTE.WoodPlank)
	createPart(sheriffOffice, "Wall_Right", Vector3.new(1.5, 14, 30), baseCF * CFrame.new(14, 7.5, 0), PALETTE.WoodPlank)
	createPart(sheriffOffice, "Wall_Front_L", Vector3.new(10, 14, 1.5), baseCF * CFrame.new(-9, 7.5, 15), PALETTE.WoodPlank)
	createPart(sheriffOffice, "Wall_Front_R", Vector3.new(10, 14, 1.5), baseCF * CFrame.new(9, 7.5, 15), PALETTE.WoodPlank)
	createPart(sheriffOffice, "Wall_Front_Top", Vector3.new(8, 5, 1.5), baseCF * CFrame.new(0, 12, 15), PALETTE.WoodPlank)
	createPart(sheriffOffice, "Roof", Vector3.new(30, 1.5, 34), baseCF * CFrame.new(0, 14.5, 0), PALETTE.RoofTile)

	-- Jail Cell Iron Bars
	for i = -10, -2, 2 do
		createPart(sheriffOffice, "JailBar_" .. i, Vector3.new(0.4, 12, 0.4), baseCF * CFrame.new(i, 6.5, -5), PALETTE.Iron, Enum.Material.Metal)
	end

	-- Sheriff Sign
	local sign = createPart(sheriffOffice, "SheriffSign", Vector3.new(16, 2.8, 0.5), baseCF * CFrame.new(0, 16.5, 15.5), PALETTE.LightWood)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "SHERIFF & JAIL"
	label.Font = Enum.Font.Antique
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(180, 30, 20)
	label.BackgroundTransparency = 1
	label.Parent = surfaceGui

	-- Spatial Landmark Trigger
	local trigger = createPart(sheriffOffice, "Trigger_Sheriff", Vector3.new(14, 8, 14), baseCF * CFrame.new(0, 4, 8), Color3.new(1, 1, 1))
	trigger.Transparency = 1
	trigger.CanCollide = false
	trigger:SetAttribute("LocationId", QuestEnums.Locations.SheriffOffice)
	CollectionService:AddTag(trigger, "QuestLocation")
end

function WorldSpawnService:BuildGeneralStore(parent: Folder)
	local store = Instance.new("Model")
	store.Name = "Building_GeneralStore"
	store.Parent = parent

	local baseCF = CFrame.new(-42, 0, 35)

	-- Floor & Structure
	createPart(store, "Floor", Vector3.new(30, 1, 32), baseCF * CFrame.new(0, 0.5, 0), PALETTE.DarkWood)
	createPart(store, "Wall_Back", Vector3.new(30, 14, 1.5), baseCF * CFrame.new(0, 7.5, 16), PALETTE.WoodPlank)
	createPart(store, "Wall_Left", Vector3.new(1.5, 14, 32), baseCF * CFrame.new(-15, 7.5, 0), PALETTE.WoodPlank)
	createPart(store, "Wall_Right", Vector3.new(1.5, 14, 32), baseCF * CFrame.new(15, 7.5, 0), PALETTE.WoodPlank)
	createPart(store, "Wall_Front_L", Vector3.new(11, 14, 1.5), baseCF * CFrame.new(-9.5, 7.5, -16), PALETTE.WoodPlank)
	createPart(store, "Wall_Front_R", Vector3.new(11, 14, 1.5), baseCF * CFrame.new(9.5, 7.5, -16), PALETTE.WoodPlank)
	createPart(store, "Wall_Front_Top", Vector3.new(8, 5, 1.5), baseCF * CFrame.new(0, 12, -16), PALETTE.WoodPlank)
	createPart(store, "Roof", Vector3.new(32, 1.5, 36), baseCF * CFrame.new(0, 14.5, 0), PALETTE.RoofTile)

	-- Store Counter
	createPart(store, "StoreCounter", Vector3.new(16, 3.2, 3), baseCF * CFrame.new(0, 2.1, 0), PALETTE.DarkWood)

	-- Sign
	local sign = createPart(store, "StoreSign", Vector3.new(22, 3, 0.5), baseCF * CFrame.new(0, 16.5, -16.5), PALETTE.LightWood)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Back
	surfaceGui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "SILAS'S GENERAL STORE"
	label.Font = Enum.Font.Antique
	label.TextScaled = true
	label.TextColor3 = PALETTE.DarkWood
	label.BackgroundTransparency = 1
	label.Parent = surfaceGui

	-- Landmark Trigger
	local trigger = createPart(store, "Trigger_GeneralStore", Vector3.new(14, 8, 14), baseCF * CFrame.new(0, 4, -8), Color3.new(1, 1, 1))
	trigger.Transparency = 1
	trigger.CanCollide = false
	trigger:SetAttribute("LocationId", QuestEnums.Locations.GeneralStore)
	CollectionService:AddTag(trigger, "QuestLocation")
end

function WorldSpawnService:BuildStables(parent: Folder)
	local stables = Instance.new("Model")
	stables.Name = "Building_Stables"
	stables.Parent = parent

	local baseCF = CFrame.new(44, 0, 35)

	-- Dirt Base & Barn Pillars
	createPart(stables, "DirtBed", Vector3.new(34, 0.4, 36), baseCF * CFrame.new(0, 0.2, 0), PALETTE.Dirt, Enum.Material.Ground)
	createPart(stables, "Post1", Vector3.new(2, 14, 2), baseCF * CFrame.new(-16, 7, -16), PALETTE.DarkWood)
	createPart(stables, "Post2", Vector3.new(2, 14, 2), baseCF * CFrame.new(16, 7, -16), PALETTE.DarkWood)
	createPart(stables, "Post3", Vector3.new(2, 14, 2), baseCF * CFrame.new(-16, 7, 16), PALETTE.DarkWood)
	createPart(stables, "Post4", Vector3.new(2, 14, 2), baseCF * CFrame.new(16, 7, 16), PALETTE.DarkWood)

	-- Barn Roof (Pitched Canopy)
	createPart(stables, "Canopy", Vector3.new(36, 1.5, 38), baseCF * CFrame.new(0, 14.5, 0), PALETTE.RoofTile)

	-- Hay Bales
	createPart(stables, "HayBale1", Vector3.new(6, 4, 4), baseCF * CFrame.new(-10, 2, 8), Color3.fromRGB(215, 185, 80), Enum.Material.Fabric)
	createPart(stables, "HayBale2", Vector3.new(5, 3.5, 4), baseCF * CFrame.new(-9, 5.5, 8), Color3.fromRGB(215, 185, 80), Enum.Material.Fabric)

	-- Stables Sign
	local sign = createPart(stables, "StableSign", Vector3.new(18, 2.5, 0.5), baseCF * CFrame.new(0, 15.5, -18.5), PALETTE.LightWood)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Back
	surfaceGui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "FRONTIER STABLES"
	label.Font = Enum.Font.Antique
	label.TextScaled = true
	label.TextColor3 = PALETTE.DarkWood
	label.BackgroundTransparency = 1
	label.Parent = surfaceGui

	-- Landmark Trigger
	local trigger = createPart(stables, "Trigger_Stables", Vector3.new(16, 8, 16), baseCF * CFrame.new(0, 4, 0), Color3.new(1, 1, 1))
	trigger.Transparency = 1
	trigger.CanCollide = false
	trigger:SetAttribute("LocationId", QuestEnums.Locations.Stables)
	CollectionService:AddTag(trigger, "QuestLocation")
end

function WorldSpawnService:BuildDesertOutpost(parent: Folder)
	local outpost = Instance.new("Model")
	outpost.Name = "DesertOutpost"
	outpost.Parent = parent

	local baseCF = CFrame.new(0, 0, 95)

	-- Outpost Rocks & Terrain
	createPart(outpost, "OutpostRock1", Vector3.new(18, 8, 14), baseCF * CFrame.new(-12, 4, 0), PALETTE.Stone, Enum.Material.Slate)
	createPart(outpost, "OutpostRock2", Vector3.new(14, 10, 16), baseCF * CFrame.new(12, 5, 4), PALETTE.Stone, Enum.Material.Slate)

	-- Bandit Cache Chest (Contains Stolen Watch for Sheriff's Request Quest)
	local cacheChest = createPart(outpost, "BanditCacheChest", Vector3.new(3, 2.5, 2.5), baseCF * CFrame.new(0, 1.25, 2), PALETTE.DarkWood)
	cacheChest:SetAttribute("ItemId", ItemEnums.Ids.BanditWatch)
	cacheChest:SetAttribute("Quantity", 1)
	cacheChest:SetAttribute("Interactable", true)
	CollectionService:AddTag(cacheChest, "Interactable")

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Bandit Cache"
	prompt.ActionText = "Recover Stolen Pocket Watch"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.Parent = cacheChest
end

function WorldSpawnService:SpawnSupplyCrates(parent: Folder)
	local crateFolder = Instance.new("Folder")
	crateFolder.Name = "SupplyCrates"
	crateFolder.Parent = parent

	-- 5 Supply Crate spawn positions around town
	local positions = {
		Vector3.new(-24, 1.5, -12),
		Vector3.new(24, 1.5, -10),
		Vector3.new(-18, 1.5, 20),
		Vector3.new(22, 1.5, 18),
		Vector3.new(2, 1.5, -45),
	}

	for i, pos in ipairs(positions) do
		local crate = createPart(crateFolder, "SupplyCrate_" .. i, Vector3.new(2.5, 2.5, 2.5), CFrame.new(pos), PALETTE.WoodPlank)
		crate:SetAttribute("ItemId", ItemEnums.Ids.SupplyCrate)
		crate:SetAttribute("Quantity", 1)
		crate:SetAttribute("Interactable", true)
		CollectionService:AddTag(crate, "Interactable")

		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = "Supply Crate"
		prompt.ActionText = "Collect"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 12
		prompt.Parent = crate
	end
end

function WorldSpawnService:SpawnTownFoliageAndProps(parent: Folder)
	local propsFolder = Instance.new("Folder")
	propsFolder.Name = "Props"
	propsFolder.Parent = parent

	-- Cacti on outskirts
	local cactusPositions = {
		Vector3.new(-70, 0, -50),
		Vector3.new(-65, 0, 40),
		Vector3.new(70, 0, -45),
		Vector3.new(65, 0, 50),
		Vector3.new(-30, 0, 90),
		Vector3.new(35, 0, 95),
	}

	for i, pos in ipairs(cactusPositions) do
		local stem = createPart(propsFolder, "Cactus_" .. i, Vector3.new(2, 10, 2), CFrame.new(pos + Vector3.new(0, 5, 0)), PALETTE.CactusGreen, Enum.Material.Grass)
		-- Cactus Arm
		createPart(propsFolder, "CactusArm_" .. i, Vector3.new(4, 1.5, 1.5), stem.CFrame * CFrame.new(2, 1, 0), PALETTE.CactusGreen, Enum.Material.Grass)
	end
end

function WorldSpawnService:SpawnNPCs()
	local npcFolder = Workspace:FindFirstChild("NPCs")
	if not npcFolder then
		npcFolder = Instance.new("Folder")
		npcFolder.Name = "NPCs"
		npcFolder.Parent = Workspace
	end

	local npcSpawnData = {
		{
			Id = "npc_sheriff",
			Name = "Sheriff Cooper",
			Position = Vector3.new(35, 3.5, -28),
			Color = Color3.fromRGB(120, 80, 50),
		},
		{
			Id = "npc_merchant",
			Name = "Silas Vance",
			Position = Vector3.new(-38, 3.5, 30),
			Color = Color3.fromRGB(60, 100, 140),
		},
		{
			Id = "npc_bartender",
			Name = "Cole Holloway",
			Position = Vector3.new(-38, 3.5, -30),
			Color = Color3.fromRGB(150, 40, 40),
		},
		{
			Id = "npc_stablemaster",
			Name = "Rancher Jesse",
			Position = Vector3.new(38, 3.5, 28),
			Color = Color3.fromRGB(90, 110, 60),
		},
	}

	for _, data in ipairs(npcSpawnData) do
		local model = Instance.new("Model")
		model.Name = data.Id
		model.Parent = npcFolder

		-- HumanoidRootPart
		local hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.Size = Vector3.new(2, 2, 1)
		hrp.CFrame = CFrame.new(data.Position)
		hrp.Transparency = 1
		hrp.CanCollide = false
		hrp.Anchored = false
		hrp.Parent = model
		model.PrimaryPart = hrp

		-- Torso
		local torso = createPart(model, "Torso", Vector3.new(2, 2, 1), hrp.CFrame, data.Color, Enum.Material.Fabric)
		torso.Anchored = false
		local motorTorso = Instance.new("Motor6D")
		motorTorso.Part0 = hrp
		motorTorso.Part1 = torso
		motorTorso.Parent = hrp

		-- Head
		local head = createPart(model, "Head", Vector3.new(1.2, 1.2, 1.2), hrp.CFrame * CFrame.new(0, 1.5, 0), Color3.fromRGB(230, 185, 145), Enum.Material.SmoothPlastic)
		head.Anchored = false
		local motorHead = Instance.new("Motor6D")
		motorHead.Part0 = torso
		motorHead.Part1 = head
		motorHead.C0 = CFrame.new(0, 1.5, 0)
		motorHead.Parent = torso

		-- Stetson Hat
		local hat = createPart(model, "StetsonHat", Vector3.new(2.4, 0.4, 2.4), head.CFrame * CFrame.new(0, 0.7, 0), PALETTE.DarkWood)
		hat.Anchored = false
		local weldHat = Instance.new("WeldConstraint")
		weldHat.Part0 = head
		weldHat.Part1 = hat
		weldHat.Parent = hat

		-- Humanoid
		local humanoid = Instance.new("Humanoid")
		humanoid.MaxHealth = 100
		humanoid.Health = 100
		humanoid.DisplayName = data.Name
		humanoid.Parent = model

		-- Overhead Name & Role Tag
		local headGui = Instance.new("BillboardGui")
		headGui.Size = UDim2.fromScale(4, 1.2)
		headGui.StudsOffset = Vector3.new(0, 2.5, 0)
		headGui.AlwaysOnTop = true
		headGui.Parent = head

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.fromScale(1, 1)
		titleLabel.Text = string.format("<b>%s</b>", data.Name)
		titleLabel.RichText = true
		titleLabel.Font = Enum.Font.Antique
		titleLabel.TextColor3 = Color3.fromRGB(255, 230, 160)
		titleLabel.TextStrokeTransparency = 0.2
		titleLabel.TextScaled = true
		titleLabel.BackgroundTransparency = 1
		titleLabel.Parent = headGui

		-- ProximityPrompt for Interaction
		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = data.Name
		prompt.ActionText = "Talk"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = hrp

		CollectionService:AddTag(model, "NPC")

		-- Register with NPCService
		NPCService:RegisterNPCModel(data.Id, model)
	end
end

return WorldSpawnService

