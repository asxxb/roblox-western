--!strict
--[[
	UIController.luau
	Master client presentation controller: coordinates Main HUD, Dialogue modal,
	Inventory grid, Quest Journal, Shop trading interface, and Floating Notifications.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UITheme = require(script.Parent.Parent.UI.UITheme)
local ItemDefinitions = require(Shared.Definitions.ItemDefinitions)
local QuestDefinitions = require(Shared.Definitions.QuestDefinitions)
local NPCDefinitions = require(Shared.Definitions.NPCDefinitions)
local NetworkRouter = require(Shared.Network.NetworkRouter)

local InputController: any
local CameraController: any
local InventoryController: any
local QuestController: any

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local UIController = {
	Name = "UIController",
}

-- UI State Elements
local screenGui: ScreenGui
local coinTextLabel: TextLabel
local healthFillBar: Frame
local staminaFillBar: Frame
local questTrackerTitle: TextLabel
local questTrackerList: Frame

-- Modals
local dialogueFrame: Frame
local dialogueSpeakerLabel: TextLabel
local dialogueBodyLabel: TextLabel
local dialogueChoicesContainer: Frame
local currentActiveNPCId: string?
local currentActiveNodeId: string?

local inventoryFrame: Frame
local inventoryGrid: Frame
local itemInspectContainer: Frame
local selectedInventoryItemId: string?

local questJournalFrame: Frame
local questJournalList: ScrollingFrame
local questJournalDetails: Frame

local shopFrame: Frame
local shopItemsList: ScrollingFrame
local shopTab: "Buy" | "Sell" = "Buy"

local toastContainer: Frame

function UIController:Init()
	InputController = require(script.Parent.InputController)
	CameraController = require(script.Parent.CameraController)
	InventoryController = require(script.Parent.InventoryController)
	QuestController = require(script.Parent.QuestController)
end

function UIController:Start()
	self:BuildMainScreenGui()
	self:BuildMainHUD()
	self:BuildDialogueUI()
	self:BuildInventoryUI()
	self:BuildQuestJournalUI()
	self:BuildShopUI()
	self:BuildToastContainer()

	-- Connect Input and State Listeners
	InputController.StaminaChanged:Connect(function(current: number, max: number)
		self:UpdateStaminaBar(current, max)
	end)

	InputController.InventoryToggleRequested:Connect(function()
		self:ToggleInventory()
	end)

	InputController.QuestJournalToggleRequested:Connect(function()
		self:ToggleQuestJournal()
	end)

	InventoryController.CoinsUpdated:Connect(function(coins: number)
		self:UpdateCoinsDisplay(coins)
	end)

	InventoryController.InventoryUpdated:Connect(function()
		self:RefreshInventoryGrid()
		self:UpdateCoinsDisplay(InventoryController:GetCoins())
		if shopFrame.Visible then
			self:RefreshShopView()
		end
	end)

	QuestController.QuestUpdated:Connect(function(questId: string, state: string, progress: any)
		self:RefreshQuestTracker()
		if questJournalFrame.Visible then
			self:RefreshQuestJournal()
		end
	end)

	-- Health changes
	local function bindCharacter(char: Model)
		local humanoid = char:WaitForChild("Humanoid") :: Humanoid
		humanoid.HealthChanged:Connect(function(health: number)
			self:UpdateHealthBar(health, humanoid.MaxHealth)
		end)
		self:UpdateHealthBar(humanoid.Health, humanoid.MaxHealth)
	end

	if localPlayer.Character then
		bindCharacter(localPlayer.Character)
	end
	localPlayer.CharacterAdded:Connect(bindCharacter)

	-- Notification remote
	local notifEvent = NetworkRouter.GetEvent(NetworkRouter.Names.Events.ShowNotification)
	notifEvent.OnClientEvent:Connect(function(notifType: string, message: string)
		self:ShowToast(notifType, message)
	end)

	-- Initial Refresh
	self:RefreshQuestTracker()
end

function UIController:BuildMainScreenGui()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WWF_MainScreenGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui
end

function UIController:BuildMainHUD()
	-- Top-Left Status Bar (Coins, Health, Stamina)
	local statusBar = Instance.new("Frame")
	statusBar.Name = "StatusBar"
	statusBar.Size = UDim2.new(0, 240, 0, 110)
	statusBar.Position = UDim2.new(0, 20, 0, 20)
	statusBar.BackgroundColor3 = UITheme.Colors.BackgroundDark
	statusBar.BackgroundTransparency = 0.25
	statusBar.BorderSizePixel = 0
	statusBar.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = statusBar

	local stroke = Instance.new("UIStroke")
	stroke.Color = UITheme.Colors.BorderGold
	stroke.Thickness = 1.5
	stroke.Parent = statusBar

	-- Coins Counter
	local coinIcon = Instance.new("TextLabel")
	coinIcon.Text = "🪙"
	coinIcon.Size = UDim2.new(0, 28, 0, 28)
	coinIcon.Position = UDim2.new(0, 12, 0, 10)
	coinIcon.BackgroundTransparency = 1
	coinIcon.TextScaled = true
	coinIcon.Parent = statusBar

	coinTextLabel = Instance.new("TextLabel")
	coinTextLabel.Name = "CoinText"
	coinTextLabel.Size = UDim2.new(0, 180, 0, 28)
	coinTextLabel.Position = UDim2.new(0, 46, 0, 10)
	coinTextLabel.Text = "50 COINS"
	coinTextLabel.Font = UITheme.Fonts.Title
	coinTextLabel.TextColor3 = UITheme.Colors.GoldCoin
	coinTextLabel.TextSize = 20
	coinTextLabel.TextXAlignment = Enum.TextXAlignment.Left
	coinTextLabel.BackgroundTransparency = 1
	coinTextLabel.Parent = statusBar

	-- Health Bar
	local healthBg = Instance.new("Frame")
	healthBg.Size = UDim2.new(0, 216, 0, 14)
	healthBg.Position = UDim2.new(0, 12, 0, 46)
	healthBg.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
	healthBg.BorderSizePixel = 0
	healthBg.Parent = statusBar

	local hCorner = Instance.new("UICorner")
	hCorner.CornerRadius = UDim.new(0, 4)
	hCorner.Parent = healthBg

	healthFillBar = Instance.new("Frame")
	healthFillBar.Size = UDim2.new(1, 0, 1, 0)
	healthFillBar.BackgroundColor3 = UITheme.Colors.HealthGreen
	healthFillBar.BorderSizePixel = 0
	healthFillBar.Parent = healthBg

	local hFillCorner = Instance.new("UICorner")
	hFillCorner.CornerRadius = UDim.new(0, 4)
	hFillCorner.Parent = healthFillBar

	-- Stamina Bar
	local staminaBg = Instance.new("Frame")
	staminaBg.Size = UDim2.new(0, 216, 0, 14)
	staminaBg.Position = UDim2.new(0, 12, 0, 68)
	staminaBg.BackgroundColor3 = Color3.fromRGB(50, 40, 15)
	staminaBg.BorderSizePixel = 0
	staminaBg.Parent = statusBar

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 4)
	sCorner.Parent = staminaBg

	staminaFillBar = Instance.new("Frame")
	staminaFillBar.Size = UDim2.new(1, 0, 1, 0)
	staminaFillBar.BackgroundColor3 = UITheme.Colors.StaminaYellow
	staminaFillBar.BorderSizePixel = 0
	staminaFillBar.Parent = staminaBg

	local sFillCorner = Instance.new("UICorner")
	sFillCorner.CornerRadius = UDim.new(0, 4)
	sFillCorner.Parent = staminaFillBar

	-- Top-Right Active Quest Tracker
	local questTracker = Instance.new("Frame")
	questTracker.Name = "QuestTracker"
	questTracker.Size = UDim2.new(0, 280, 0, 140)
	questTracker.Position = UDim2.new(1, -300, 0, 20)
	questTracker.BackgroundColor3 = UITheme.Colors.BackgroundDark
	questTracker.BackgroundTransparency = 0.25
	questTracker.BorderSizePixel = 0
	questTracker.Parent = screenGui

	local qtCorner = Instance.new("UICorner")
	qtCorner.CornerRadius = UDim.new(0, 8)
	qtCorner.Parent = questTracker

	local qtStroke = Instance.new("UIStroke")
	qtStroke.Color = UITheme.Colors.BorderGold
	qtStroke.Thickness = 1.5
	qtStroke.Parent = questTracker

	questTrackerTitle = Instance.new("TextLabel")
	questTrackerTitle.Size = UDim2.new(1, -20, 0, 26)
	questTrackerTitle.Position = UDim2.new(0, 12, 0, 8)
	questTrackerTitle.Text = "ACTIVE QUEST"
	questTrackerTitle.Font = UITheme.Fonts.Title
	questTrackerTitle.TextColor3 = UITheme.Colors.BorderGold
	questTrackerTitle.TextSize = 18
	questTrackerTitle.TextXAlignment = Enum.TextXAlignment.Left
	questTrackerTitle.BackgroundTransparency = 1
	questTrackerTitle.Parent = questTracker

	questTrackerList = Instance.new("Frame")
	questTrackerList.Size = UDim2.new(1, -20, 1, -40)
	questTrackerList.Position = UDim2.new(0, 12, 0, 36)
	questTrackerList.BackgroundTransparency = 1
	questTrackerList.Parent = questTracker

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = questTrackerList

	-- Bottom Navigation Buttons (Bag, Quests)
	local navContainer = Instance.new("Frame")
	navContainer.Size = UDim2.new(0, 260, 0, 45)
	navContainer.Position = UDim2.new(0.5, -130, 1, -65)
	navContainer.BackgroundTransparency = 1
	navContainer.Parent = screenGui

	local function createNavBtn(title: string, hotkey: string, posX: number, callback: () -> ())
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 120, 1, 0)
		btn.Position = UDim2.new(0, posX, 0, 0)
		btn.BackgroundColor3 = UITheme.Colors.BackgroundDark
		btn.Text = string.format("<b>%s</b> [%s]", title, hotkey)
		btn.RichText = true
		btn.Font = UITheme.Fonts.Body
		btn.TextColor3 = UITheme.Colors.TextLight
		btn.TextSize = 14
		btn.Parent = navContainer

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 6)
		bCorner.Parent = btn

		local bStroke = Instance.new("UIStroke")
		bStroke.Color = UITheme.Colors.BorderGold
		bStroke.Thickness = 1.2
		bStroke.Parent = btn

		btn.MouseButton1Click:Connect(callback)
	end

	createNavBtn("BAG", "TAB", 0, function()
		self:ToggleInventory()
	end)

	createNavBtn("QUESTS", "J", 135, function()
		self:ToggleQuestJournal()
	end)
end

function UIController:UpdateCoinsDisplay(coins: number)
	if coinTextLabel then
		coinTextLabel.Text = string.format("%d COINS", coins)
	end
end

function UIController:UpdateHealthBar(current: number, max: number)
	if healthFillBar then
		local percent = math.clamp(current / math.max(1, max), 0, 1)
		TweenService:Create(healthFillBar, UITheme.Animation.Quick, { Size = UDim2.new(percent, 0, 1, 0) }):Play()
	end
end

function UIController:UpdateStaminaBar(current: number, max: number)
	if staminaFillBar then
		local percent = math.clamp(current / math.max(1, max), 0, 1)
		TweenService:Create(staminaFillBar, UITheme.Animation.Quick, { Size = UDim2.new(percent, 0, 1, 0) }):Play()
	end
end

function UIController:RefreshQuestTracker()
	if not questTrackerList then
		return
	end

	for _, child in ipairs(questTrackerList:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local activeQuests = QuestController:GetActiveQuests()
	if #activeQuests == 0 then
		questTrackerTitle.Text = "NO ACTIVE QUEST"
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Text = "Talk to NPCs in town to accept quests."
		emptyLabel.Font = UITheme.Fonts.Body
		emptyLabel.TextColor3 = UITheme.Colors.TextMuted
		emptyLabel.TextSize = 13
		emptyLabel.Size = UDim2.new(1, 0, 0, 20)
		emptyLabel.TextXAlignment = Enum.TextXAlignment.Left
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.Parent = questTrackerList
		return
	end

	local firstQuest = activeQuests[1]
	local def = QuestDefinitions.Get(firstQuest.QuestId)
	if not def then
		return
	end

	questTrackerTitle.Text = string.upper(def.Title)

	for idx, obj in ipairs(def.Objectives) do
		local cur = firstQuest.ObjectiveProgress[idx] or 0
		local isDone = cur >= obj.TargetCount
		local icon = if isDone then "✓ " else "• "

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 22)
		label.Text = string.format("%s%s (%d/%d)", icon, obj.Description, cur, obj.TargetCount)
		label.Font = UITheme.Fonts.Body
		label.TextColor3 = if isDone then UITheme.Colors.SuccessGreen else UITheme.Colors.TextLight
		label.TextSize = 13
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.BackgroundTransparency = 1
		label.Parent = questTrackerList
	end
end

-- ==============================================================================
-- DIALOGUE SYSTEM UI
-- ==============================================================================

function UIController:BuildDialogueUI()
	dialogueFrame = Instance.new("Frame")
	dialogueFrame.Name = "DialogueModal"
	dialogueFrame.Size = UDim2.new(0, 680, 0, 220)
	dialogueFrame.Position = UDim2.new(0.5, -340, 1, -240)
	dialogueFrame.BackgroundColor3 = UITheme.Colors.BackgroundDark
	dialogueFrame.BackgroundTransparency = 0.05
	dialogueFrame.Visible = false
	dialogueFrame.Parent = screenGui

	local dCorner = Instance.new("UICorner")
	dCorner.CornerRadius = UDim.new(0, 10)
	dCorner.Parent = dialogueFrame

	local dStroke = Instance.new("UIStroke")
	dStroke.Color = UITheme.Colors.BorderGold
	dStroke.Thickness = 2.0
	dStroke.Parent = dialogueFrame

	dialogueSpeakerLabel = Instance.new("TextLabel")
	dialogueSpeakerLabel.Name = "SpeakerName"
	dialogueSpeakerLabel.Size = UDim2.new(1, -40, 0, 30)
	dialogueSpeakerLabel.Position = UDim2.new(0, 20, 0, 12)
	dialogueSpeakerLabel.Font = UITheme.Fonts.Title
	dialogueSpeakerLabel.TextColor3 = UITheme.Colors.BorderGold
	dialogueSpeakerLabel.TextSize = 22
	dialogueSpeakerLabel.TextXAlignment = Enum.TextXAlignment.Left
	dialogueSpeakerLabel.BackgroundTransparency = 1
	dialogueSpeakerLabel.Parent = dialogueFrame

	dialogueBodyLabel = Instance.new("TextLabel")
	dialogueBodyLabel.Name = "DialogueBody"
	dialogueBodyLabel.Size = UDim2.new(1, -40, 0, 65)
	dialogueBodyLabel.Position = UDim2.new(0, 20, 0, 48)
	dialogueBodyLabel.Font = UITheme.Fonts.Body
	dialogueBodyLabel.TextColor3 = UITheme.Colors.TextLight
	dialogueBodyLabel.TextSize = 16
	dialogueBodyLabel.TextWrapped = true
	dialogueBodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	dialogueBodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	dialogueBodyLabel.BackgroundTransparency = 1
	dialogueBodyLabel.Parent = dialogueFrame

	dialogueChoicesContainer = Instance.new("Frame")
	dialogueChoicesContainer.Name = "ChoicesContainer"
	dialogueChoicesContainer.Size = UDim2.new(1, -40, 0, 85)
	dialogueChoicesContainer.Position = UDim2.new(0, 20, 0, 120)
	dialogueChoicesContainer.BackgroundTransparency = 1
	dialogueChoicesContainer.Parent = dialogueFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = dialogueChoicesContainer
end

function UIController:OpenDialogue(npcId: string, npcModel: Model?)
	local def = NPCDefinitions.Get(npcId)
	if not def then
		return
	end

	currentActiveNPCId = npcId
	currentActiveNodeId = def.InitialNodeId

	dialogueSpeakerLabel.Text = string.format("%s  •  %s", def.DisplayName, def.RoleTitle)
	dialogueFrame.Visible = true

	self:DisplayDialogueNode(def.DefaultDialogueTree[def.InitialNodeId])
end

function UIController:DisplayDialogueNode(node: any)
	if not node then
		self:CloseDialogue()
		return
	end

	currentActiveNodeId = node.NodeId
	dialogueBodyLabel.Text = node.Text

	for _, child in ipairs(dialogueChoicesContainer:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for idx, choice in ipairs(node.Choices) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 32)
		btn.BackgroundColor3 = UITheme.Colors.ButtonNormal
		btn.Text = string.format("  ➤ %s", choice.Text)
		btn.Font = UITheme.Fonts.Body
		btn.TextColor3 = UITheme.Colors.TextLight
		btn.TextSize = 14
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.Parent = dialogueChoicesContainer

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 5)
		bCorner.Parent = btn

		local bStroke = Instance.new("UIStroke")
		bStroke.Color = UITheme.Colors.BorderGold
		bStroke.Thickness = 1
		bStroke.Parent = btn

		btn.MouseEnter:Connect(function()
			btn.BackgroundColor3 = UITheme.Colors.ButtonHover
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundColor3 = UITheme.Colors.ButtonNormal
		end)

		btn.MouseButton1Click:Connect(function()
			self:SubmitDialogueChoice(idx)
		end)
	end
end

function UIController:SubmitDialogueChoice(choiceIndex: number)
	if not currentActiveNPCId or not currentActiveNodeId then
		return
	end

	local func = NetworkRouter.GetFunction(NetworkRouter.Names.Functions.DialogueChoice)
	task.spawn(function()
		local result = func:InvokeServer(currentActiveNPCId, currentActiveNodeId, choiceIndex)
		if result and result.Success then
			if result.ActionTriggered == "OpenShop" then
				self:CloseDialogue()
				self:OpenShop()
			elseif result.NextNode then
				self:DisplayDialogueNode(result.NextNode)
			else
				self:CloseDialogue()
			end
		else
			self:CloseDialogue()
		end
	end)
end

function UIController:CloseDialogue()
	dialogueFrame.Visible = false
	currentActiveNPCId = nil
	currentActiveNodeId = nil
	CameraController:ResetCamera()
end

-- ==============================================================================
-- INVENTORY SYSTEM UI
-- ==============================================================================

function UIController:BuildInventoryUI()
	inventoryFrame = Instance.new("Frame")
	inventoryFrame.Name = "InventoryModal"
	inventoryFrame.Size = UDim2.new(0, 640, 0, 420)
	inventoryFrame.Position = UDim2.new(0.5, -320, 0.5, -210)
	inventoryFrame.BackgroundColor3 = UITheme.Colors.BackgroundDark
	inventoryFrame.Visible = false
	inventoryFrame.Parent = screenGui

	local iCorner = Instance.new("UICorner")
	iCorner.CornerRadius = UDim.new(0, 10)
	iCorner.Parent = inventoryFrame

	local iStroke = Instance.new("UIStroke")
	iStroke.Color = UITheme.Colors.BorderGold
	iStroke.Thickness = 2
	iStroke.Parent = inventoryFrame

	-- Title
	local title = Instance.new("TextLabel")
	title.Text = "SADDLEBAG & INVENTORY"
	title.Font = UITheme.Fonts.Title
	title.TextColor3 = UITheme.Colors.BorderGold
	title.TextSize = 22
	title.Size = UDim2.new(1, -60, 0, 36)
	title.Position = UDim2.new(0, 20, 0, 12)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.BackgroundTransparency = 1
	title.Parent = inventoryFrame

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -42, 0, 12)
	closeBtn.BackgroundColor3 = UITheme.Colors.AccentRed
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Font = UITheme.Fonts.Title
	closeBtn.TextSize = 16
	closeBtn.Parent = inventoryFrame

	local cbCorner = Instance.new("UICorner")
	cbCorner.CornerRadius = UDim.new(0, 6)
	cbCorner.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(function()
		self:ToggleInventory()
	end)

	-- 20 Slot Grid (Left)
	inventoryGrid = Instance.new("Frame")
	inventoryGrid.Size = UDim2.new(0, 360, 0, 330)
	inventoryGrid.Position = UDim2.new(0, 20, 0, 60)
	inventoryGrid.BackgroundTransparency = 1
	inventoryGrid.Parent = inventoryFrame

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 64, 0, 64)
	gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = inventoryGrid

	-- Item Inspect Pane (Right)
	itemInspectContainer = Instance.new("Frame")
	itemInspectContainer.Size = UDim2.new(0, 210, 0, 330)
	itemInspectContainer.Position = UDim2.new(1, -230, 0, 60)
	itemInspectContainer.BackgroundColor3 = Color3.fromRGB(24, 18, 14)
	itemInspectContainer.Parent = inventoryFrame

	local iiCorner = Instance.new("UICorner")
	iiCorner.CornerRadius = UDim.new(0, 6)
	iiCorner.Parent = itemInspectContainer
end

function UIController:ToggleInventory()
	inventoryFrame.Visible = not inventoryFrame.Visible
	if inventoryFrame.Visible then
		self:RefreshInventoryGrid()
	end
end

function UIController:RefreshInventoryGrid()
	if not inventoryGrid then
		return
	end

	for _, child in ipairs(inventoryGrid:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local inventory = InventoryController:GetInventory()
	local capacity = InventoryController:GetCapacity()
	local equipment = InventoryController:GetEquipment()

	local itemsList = {}
	for _, slot in pairs(inventory) do
		table.insert(itemsList, slot)
	end

	for i = 1, capacity do
		local slotBtn = Instance.new("TextButton")
		slotBtn.BackgroundColor3 = Color3.fromRGB(45, 32, 24)
		slotBtn.BorderSizePixel = 0
		slotBtn.Text = ""
		slotBtn.Parent = inventoryGrid

		local sCorner = Instance.new("UICorner")
		sCorner.CornerRadius = UDim.new(0, 6)
		sCorner.Parent = slotBtn

		local slotData = itemsList[i]
		if slotData then
			local def = ItemDefinitions.Get(slotData.Id)
			if def then
				local label = Instance.new("TextLabel")
				label.Size = UDim2.new(1, -4, 0, 26)
				label.Position = UDim2.new(0, 2, 0, 4)
				label.Text = def.Name
				label.Font = UITheme.Fonts.Body
				label.TextColor3 = UITheme.Colors.TextLight
				label.TextSize = 10
				label.TextWrapped = true
				label.BackgroundTransparency = 1
				label.Parent = slotBtn

				local qtyLabel = Instance.new("TextLabel")
				qtyLabel.Size = UDim2.new(0, 24, 0, 16)
				qtyLabel.Position = UDim2.new(1, -26, 1, -18)
				qtyLabel.Text = tostring(slotData.Quantity)
				qtyLabel.Font = UITheme.Fonts.Monospace
				qtyLabel.TextColor3 = UITheme.Colors.GoldCoin
				qtyLabel.TextSize = 12
				qtyLabel.BackgroundTransparency = 1
				qtyLabel.Parent = slotBtn

				slotBtn.MouseButton1Click:Connect(function()
					self:InspectItem(slotData.Id)
				end)
			end
		end
	end
end

function UIController:InspectItem(itemId: string)
	selectedInventoryItemId = itemId
	local def = ItemDefinitions.Get(itemId)
	if not def then
		return
	end

	for _, child in ipairs(itemInspectContainer:GetChildren()) do
		if not child:IsA("UICorner") then
			child:Destroy()
		end
	end

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -16, 0, 30)
	name.Position = UDim2.new(0, 8, 0, 8)
	name.Text = def.Name
	name.Font = UITheme.Fonts.Title
	name.TextColor3 = UITheme.Colors.BorderGold
	name.TextSize = 16
	name.TextWrapped = true
	name.BackgroundTransparency = 1
	name.Parent = itemInspectContainer

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -16, 0, 90)
	desc.Position = UDim2.new(0, 8, 0, 42)
	desc.Text = def.Description
	desc.Font = UITheme.Fonts.Body
	desc.TextColor3 = UITheme.Colors.TextLight
	desc.TextSize = 13
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.BackgroundTransparency = 1
	desc.Parent = itemInspectContainer

	if def.Category == "Consumable" then
		local useBtn = Instance.new("TextButton")
		useBtn.Size = UDim2.new(1, -20, 0, 32)
		useBtn.Position = UDim2.new(0, 10, 1, -44)
		useBtn.BackgroundColor3 = UITheme.Colors.SuccessGreen
		useBtn.Text = "USE ITEM"
		useBtn.Font = UITheme.Fonts.Body
		useBtn.TextColor3 = Color3.new(1, 1, 1)
		useBtn.TextSize = 14
		useBtn.Parent = itemInspectContainer

		local ubCorner = Instance.new("UICorner")
		ubCorner.CornerRadius = UDim.new(0, 5)
		ubCorner.Parent = useBtn

		useBtn.MouseButton1Click:Connect(function()
			InventoryController:UseItem(itemId)
		end)
	elseif def.Category == "Equipment" then
		local equipBtn = Instance.new("TextButton")
		equipBtn.Size = UDim2.new(1, -20, 0, 32)
		equipBtn.Position = UDim2.new(0, 10, 1, -44)
		equipBtn.BackgroundColor3 = UITheme.Colors.BorderGold
		equipBtn.Text = "EQUIP / UNEQUIP"
		equipBtn.Font = UITheme.Fonts.Body
		equipBtn.TextColor3 = UITheme.Colors.BackgroundDark
		equipBtn.TextSize = 14
		equipBtn.Parent = itemInspectContainer

		local ebCorner = Instance.new("UICorner")
		ebCorner.CornerRadius = UDim.new(0, 5)
		ebCorner.Parent = equipBtn

		equipBtn.MouseButton1Click:Connect(function()
			InventoryController:EquipItem(itemId)
		end)
	end
end

-- ==============================================================================
-- QUEST JOURNAL UI
-- ==============================================================================

function UIController:BuildQuestJournalUI()
	questJournalFrame = Instance.new("Frame")
	questJournalFrame.Name = "QuestJournalModal"
	questJournalFrame.Size = UDim2.new(0, 680, 0, 440)
	questJournalFrame.Position = UDim2.new(0.5, -340, 0.5, -220)
	questJournalFrame.BackgroundColor3 = UITheme.Colors.BackgroundDark
	questJournalFrame.Visible = false
	questJournalFrame.Parent = screenGui

	local qCorner = Instance.new("UICorner")
	qCorner.CornerRadius = UDim.new(0, 10)
	qCorner.Parent = questJournalFrame

	local qStroke = Instance.new("UIStroke")
	qStroke.Color = UITheme.Colors.BorderGold
	qStroke.Thickness = 2
	qStroke.Parent = questJournalFrame

	local title = Instance.new("TextLabel")
	title.Text = "FRONTIER QUEST JOURNAL"
	title.Font = UITheme.Fonts.Title
	title.TextColor3 = UITheme.Colors.BorderGold
	title.TextSize = 22
	title.Size = UDim2.new(1, -60, 0, 36)
	title.Position = UDim2.new(0, 20, 0, 12)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.BackgroundTransparency = 1
	title.Parent = questJournalFrame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -42, 0, 12)
	closeBtn.BackgroundColor3 = UITheme.Colors.AccentRed
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Font = UITheme.Fonts.Title
	closeBtn.TextSize = 16
	closeBtn.Parent = questJournalFrame

	local cbCorner = Instance.new("UICorner")
	cbCorner.CornerRadius = UDim.new(0, 6)
	cbCorner.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(function()
		self:ToggleQuestJournal()
	end)

	questJournalList = Instance.new("ScrollingFrame")
	questJournalList.Size = UDim2.new(0, 260, 0, 350)
	questJournalList.Position = UDim2.new(0, 20, 0, 60)
	questJournalList.BackgroundTransparency = 1
	questJournalList.ScrollBarThickness = 4
	questJournalList.Parent = questJournalFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = questJournalList

	questJournalDetails = Instance.new("Frame")
	questJournalDetails.Size = UDim2.new(0, 360, 0, 350)
	questJournalDetails.Position = UDim2.new(1, -380, 0, 60)
	questJournalDetails.BackgroundColor3 = Color3.fromRGB(24, 18, 14)
	questJournalDetails.Parent = questJournalFrame

	local qdCorner = Instance.new("UICorner")
	qdCorner.CornerRadius = UDim.new(0, 6)
	qdCorner.Parent = questJournalDetails
end

function UIController:ToggleQuestJournal()
	questJournalFrame.Visible = not questJournalFrame.Visible
	if questJournalFrame.Visible then
		self:RefreshQuestJournal()
	end
end

function UIController:RefreshQuestJournal()
	if not questJournalList then
		return
	end

	for _, child in ipairs(questJournalList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local allQuests = QuestDefinitions.GetAll()
	for questId, def in pairs(allQuests) do
		local userQuest = QuestController:GetQuest(questId)
		local statusText = "Available"
		local statusColor = UITheme.Colors.TextMuted

		if userQuest then
			if userQuest.State == "Active" then
				statusText = "In Progress"
				statusColor = UITheme.Colors.GoldCoin
			elseif userQuest.State == "Completed" then
				statusText = "Completed"
				statusColor = UITheme.Colors.SuccessGreen
			end
		end

		local card = Instance.new("TextButton")
		card.Size = UDim2.new(1, -10, 0, 48)
		card.BackgroundColor3 = UITheme.Colors.ButtonNormal
		card.Text = ""
		card.Parent = questJournalList

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 6)
		cCorner.Parent = card

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.new(1, -16, 0, 22)
		titleLabel.Position = UDim2.new(0, 8, 0, 4)
		titleLabel.Text = def.Title
		titleLabel.Font = UITheme.Fonts.Body
		titleLabel.TextColor3 = UITheme.Colors.TextLight
		titleLabel.TextSize = 13
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.BackgroundTransparency = 1
		titleLabel.Parent = card

		local statusLabel = Instance.new("TextLabel")
		statusLabel.Size = UDim2.new(1, -16, 0, 16)
		statusLabel.Position = UDim2.new(0, 8, 0, 26)
		statusLabel.Text = statusText
		statusLabel.Font = UITheme.Fonts.Monospace
		statusLabel.TextColor3 = statusColor
		statusLabel.TextSize = 11
		statusLabel.TextXAlignment = Enum.TextXAlignment.Left
		statusLabel.BackgroundTransparency = 1
		statusLabel.Parent = card

		card.MouseButton1Click:Connect(function()
			self:DisplayQuestDetails(questId)
		end)
	end
end

function UIController:DisplayQuestDetails(questId: string)
	local def = QuestDefinitions.Get(questId)
	if not def then
		return
	end

	for _, child in ipairs(questJournalDetails:GetChildren()) do
		if not child:IsA("UICorner") then
			child:Destroy()
		end
	end

	local userQuest = QuestController:GetQuest(questId)

	local qTitle = Instance.new("TextLabel")
	qTitle.Size = UDim2.new(1, -20, 0, 30)
	qTitle.Position = UDim2.new(0, 10, 0, 10)
	qTitle.Text = def.Title
	qTitle.Font = UITheme.Fonts.Title
	qTitle.TextColor3 = UITheme.Colors.BorderGold
	qTitle.TextSize = 18
	qTitle.TextXAlignment = Enum.TextXAlignment.Left
	qTitle.BackgroundTransparency = 1
	qTitle.Parent = questJournalDetails

	local qDesc = Instance.new("TextLabel")
	qDesc.Size = UDim2.new(1, -20, 0, 80)
	qDesc.Position = UDim2.new(0, 10, 0, 44)
	qDesc.Text = def.Description
	qDesc.Font = UITheme.Fonts.Body
	qDesc.TextColor3 = UITheme.Colors.TextLight
	qDesc.TextSize = 13
	qDesc.TextWrapped = true
	qDesc.TextXAlignment = Enum.TextXAlignment.Left
	qDesc.TextYAlignment = Enum.TextYAlignment.Top
	qDesc.BackgroundTransparency = 1
	qDesc.Parent = questJournalDetails

	local objHeader = Instance.new("TextLabel")
	objHeader.Size = UDim2.new(1, -20, 0, 20)
	objHeader.Position = UDim2.new(0, 10, 0, 130)
	objHeader.Text = "OBJECTIVES"
	objHeader.Font = UITheme.Fonts.Title
	objHeader.TextColor3 = UITheme.Colors.BorderGold
	objHeader.TextSize = 14
	objHeader.TextXAlignment = Enum.TextXAlignment.Left
	objHeader.BackgroundTransparency = 1
	objHeader.Parent = questJournalDetails

	local yOffset = 155
	for idx, obj in ipairs(def.Objectives) do
		local cur = if userQuest and userQuest.ObjectiveProgress then userQuest.ObjectiveProgress[idx] or 0 else 0
		local isDone = cur >= obj.TargetCount
		local icon = if isDone then "✓ " else "• "

		local oLabel = Instance.new("TextLabel")
		oLabel.Size = UDim2.new(1, -20, 0, 20)
		oLabel.Position = UDim2.new(0, 10, 0, yOffset)
		oLabel.Text = string.format("%s%s (%d/%d)", icon, obj.Description, cur, obj.TargetCount)
		oLabel.Font = UITheme.Fonts.Body
		oLabel.TextColor3 = if isDone then UITheme.Colors.SuccessGreen else UITheme.Colors.TextLight
		oLabel.TextSize = 12
		oLabel.TextXAlignment = Enum.TextXAlignment.Left
		oLabel.BackgroundTransparency = 1
		oLabel.Parent = questJournalDetails

		yOffset += 24
	end

	-- Rewards
	local rewLabel = Instance.new("TextLabel")
	rewLabel.Size = UDim2.new(1, -20, 0, 30)
	rewLabel.Position = UDim2.new(0, 10, 1, -40)
	rewLabel.Text = string.format("REWARD: +%d Coins", def.Rewards.Coins)
	rewLabel.Font = UITheme.Fonts.Title
	rewLabel.TextColor3 = UITheme.Colors.GoldCoin
	rewLabel.TextSize = 14
	rewLabel.TextXAlignment = Enum.TextXAlignment.Left
	rewLabel.BackgroundTransparency = 1
	rewLabel.Parent = questJournalDetails
end

-- ==============================================================================
-- SHOP UI (Silas's Trading Post)
-- ==============================================================================

function UIController:BuildShopUI()
	shopFrame = Instance.new("Frame")
	shopFrame.Name = "ShopModal"
	shopFrame.Size = UDim2.new(0, 640, 0, 420)
	shopFrame.Position = UDim2.new(0.5, -320, 0.5, -210)
	shopFrame.BackgroundColor3 = UITheme.Colors.BackgroundDark
	shopFrame.Visible = false
	shopFrame.Parent = screenGui

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 10)
	sCorner.Parent = shopFrame

	local sStroke = Instance.new("UIStroke")
	sStroke.Color = UITheme.Colors.BorderGold
	sStroke.Thickness = 2
	sStroke.Parent = shopFrame

	local title = Instance.new("TextLabel")
	title.Text = "SILAS'S TRADING POST"
	title.Font = UITheme.Fonts.Title
	title.TextColor3 = UITheme.Colors.BorderGold
	title.TextSize = 22
	title.Size = UDim2.new(1, -60, 0, 36)
	title.Position = UDim2.new(0, 20, 0, 12)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.BackgroundTransparency = 1
	title.Parent = shopFrame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -42, 0, 12)
	closeBtn.BackgroundColor3 = UITheme.Colors.AccentRed
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Font = UITheme.Fonts.Title
	closeBtn.TextSize = 16
	closeBtn.Parent = shopFrame

	local cbCorner = Instance.new("UICorner")
	cbCorner.CornerRadius = UDim.new(0, 6)
	cbCorner.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(function()
		self:CloseShop()
	end)

	-- Tabs (Buy / Sell)
	local buyTabBtn = Instance.new("TextButton")
	buyTabBtn.Size = UDim2.new(0, 120, 0, 32)
	buyTabBtn.Position = UDim2.new(0, 20, 0, 52)
	buyTabBtn.BackgroundColor3 = UITheme.Colors.BorderGold
	buyTabBtn.Text = "BUY GOODS"
	buyTabBtn.Font = UITheme.Fonts.Title
	buyTabBtn.TextColor3 = UITheme.Colors.BackgroundDark
	buyTabBtn.TextSize = 14
	buyTabBtn.Parent = shopFrame

	local sellTabBtn = Instance.new("TextButton")
	sellTabBtn.Size = UDim2.new(0, 120, 0, 32)
	sellTabBtn.Position = UDim2.new(0, 150, 0, 52)
	sellTabBtn.BackgroundColor3 = UITheme.Colors.ButtonNormal
	sellTabBtn.Text = "SELL ITEMS"
	sellTabBtn.Font = UITheme.Fonts.Title
	sellTabBtn.TextColor3 = UITheme.Colors.TextLight
	sellTabBtn.TextSize = 14
	sellTabBtn.Parent = shopFrame

	buyTabBtn.MouseButton1Click:Connect(function()
		shopTab = "Buy"
		buyTabBtn.BackgroundColor3 = UITheme.Colors.BorderGold
		buyTabBtn.TextColor3 = UITheme.Colors.BackgroundDark
		sellTabBtn.BackgroundColor3 = UITheme.Colors.ButtonNormal
		sellTabBtn.TextColor3 = UITheme.Colors.TextLight
		self:RefreshShopView()
	end)

	sellTabBtn.MouseButton1Click:Connect(function()
		shopTab = "Sell"
		sellTabBtn.BackgroundColor3 = UITheme.Colors.BorderGold
		sellTabBtn.TextColor3 = UITheme.Colors.BackgroundDark
		buyTabBtn.BackgroundColor3 = UITheme.Colors.ButtonNormal
		buyTabBtn.TextColor3 = UITheme.Colors.TextLight
		self:RefreshShopView()
	end)

	shopItemsList = Instance.new("ScrollingFrame")
	shopItemsList.Size = UDim2.new(1, -40, 0, 310)
	shopItemsList.Position = UDim2.new(0, 20, 0, 95)
	shopItemsList.BackgroundTransparency = 1
	shopItemsList.ScrollBarThickness = 4
	shopItemsList.Parent = shopFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = shopItemsList
end

function UIController:OpenShop()
	shopFrame.Visible = true
	self:RefreshShopView()
end

function UIController:CloseShop()
	shopFrame.Visible = false
end

function UIController:RefreshShopView()
	if not shopItemsList then
		return
	end

	for _, child in ipairs(shopItemsList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	if shopTab == "Buy" then
		local allItems = ItemDefinitions.GetAll()
		for itemId, def in pairs(allItems) do
			if def.BuyPrice then
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, -10, 0, 52)
				row.BackgroundColor3 = Color3.fromRGB(45, 32, 24)
				row.Parent = shopItemsList

				local rCorner = Instance.new("UICorner")
				rCorner.CornerRadius = UDim.new(0, 6)
				rCorner.Parent = row

				local name = Instance.new("TextLabel")
				name.Size = UDim2.new(0, 240, 0, 24)
				name.Position = UDim2.new(0, 12, 0, 6)
				name.Text = def.Name
				name.Font = UITheme.Fonts.Body
				name.TextColor3 = UITheme.Colors.TextLight
				name.TextSize = 14
				name.TextXAlignment = Enum.TextXAlignment.Left
				name.BackgroundTransparency = 1
				name.Parent = row

				local price = Instance.new("TextLabel")
				price.Size = UDim2.new(0, 120, 0, 20)
				price.Position = UDim2.new(0, 12, 0, 28)
				price.Text = string.format("Price: %d Coins", def.BuyPrice)
				price.Font = UITheme.Fonts.Monospace
				price.TextColor3 = UITheme.Colors.GoldCoin
				price.TextSize = 12
				price.TextXAlignment = Enum.TextXAlignment.Left
				price.BackgroundTransparency = 1
				price.Parent = row

				local buyBtn = Instance.new("TextButton")
				buyBtn.Size = UDim2.new(0, 90, 0, 32)
				buyBtn.Position = UDim2.new(1, -100, 0, 10)
				buyBtn.BackgroundColor3 = UITheme.Colors.SuccessGreen
				buyBtn.Text = "BUY"
				buyBtn.Font = UITheme.Fonts.Title
				buyBtn.TextColor3 = Color3.new(1, 1, 1)
				buyBtn.TextSize = 14
				buyBtn.Parent = row

				local bbCorner = Instance.new("UICorner")
				bbCorner.CornerRadius = UDim.new(0, 5)
				bbCorner.Parent = buyBtn

				buyBtn.MouseButton1Click:Connect(function()
					InventoryController:PurchaseItem(itemId, 1)
				end)
			end
		end
	else
		-- Sell Tab
		local inventory = InventoryController:GetInventory()
		for itemId, slot in pairs(inventory) do
			local def = ItemDefinitions.Get(itemId)
			if def and def.Category ~= "QuestItem" then
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, -10, 0, 52)
				row.BackgroundColor3 = Color3.fromRGB(45, 32, 24)
				row.Parent = shopItemsList

				local rCorner = Instance.new("UICorner")
				rCorner.CornerRadius = UDim.new(0, 6)
				rCorner.Parent = row

				local name = Instance.new("TextLabel")
				name.Size = UDim2.new(0, 240, 0, 24)
				name.Position = UDim2.new(0, 12, 0, 6)
				name.Text = string.format("%s (x%d)", def.Name, slot.Quantity)
				name.Font = UITheme.Fonts.Body
				name.TextColor3 = UITheme.Colors.TextLight
				name.TextSize = 14
				name.TextXAlignment = Enum.TextXAlignment.Left
				name.BackgroundTransparency = 1
				name.Parent = row

				local unitPrice = math.max(1, math.floor(def.BaseValue * 0.6))
				local price = Instance.new("TextLabel")
				price.Size = UDim2.new(0, 120, 0, 20)
				price.Position = UDim2.new(0, 12, 0, 28)
				price.Text = string.format("Sell for: +%d Coins", unitPrice)
				price.Font = UITheme.Fonts.Monospace
				price.TextColor3 = UITheme.Colors.GoldCoin
				price.TextSize = 12
				price.TextXAlignment = Enum.TextXAlignment.Left
				price.BackgroundTransparency = 1
				price.Parent = row

				local sellBtn = Instance.new("TextButton")
				sellBtn.Size = UDim2.new(0, 90, 0, 32)
				sellBtn.Position = UDim2.new(1, -100, 0, 10)
				sellBtn.BackgroundColor3 = UITheme.Colors.BorderGold
				sellBtn.Text = "SELL (1)"
				sellBtn.Font = UITheme.Fonts.Title
				sellBtn.TextColor3 = UITheme.Colors.BackgroundDark
				sellBtn.TextSize = 14
				sellBtn.Parent = row

				local sbCorner = Instance.new("UICorner")
				sbCorner.CornerRadius = UDim.new(0, 5)
				sbCorner.Parent = sellBtn

				sellBtn.MouseButton1Click:Connect(function()
					InventoryController:SellItem(itemId, 1)
				end)
			end
		end
	end
end

-- ==============================================================================
-- FLOATING NOTIFICATIONS (TOASTS)
-- ==============================================================================

function UIController:BuildToastContainer()
	toastContainer = Instance.new("Frame")
	toastContainer.Name = "ToastContainer"
	toastContainer.Size = UDim2.new(0, 320, 0, 300)
	toastContainer.Position = UDim2.new(0.5, -160, 0, 30)
	toastContainer.BackgroundTransparency = 1
	toastContainer.Parent = screenGui

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Parent = toastContainer
end

function UIController:ShowToast(toastType: string, message: string)
	if not toastContainer then
		return
	end

	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(1, 0, 0, 42)
	toast.BackgroundColor3 = UITheme.Colors.BackgroundDark
	toast.BackgroundTransparency = 0.15
	toast.Parent = toastContainer

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 8)
	tCorner.Parent = toast

	local strokeColor = UITheme.Colors.BorderGold
	if toastType == "QuestComplete" or toastType == "CoinsReceived" then
		strokeColor = UITheme.Colors.GoldCoin
	elseif toastType == "Error" then
		strokeColor = UITheme.Colors.AccentRed
	end

	local tStroke = Instance.new("UIStroke")
	tStroke.Color = strokeColor
	tStroke.Thickness = 1.5
	tStroke.Parent = toast

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.Text = message
	label.Font = UITheme.Fonts.Body
	label.TextColor3 = UITheme.Colors.TextLight
	label.TextSize = 14
	label.BackgroundTransparency = 1
	label.Parent = toast

	task.delay(3.5, function()
		if toast.Parent then
			local fade = TweenService:Create(toast, UITheme.Animation.Quick, { BackgroundTransparency = 1 })
			fade:Play()
			fade.Completed:Connect(function()
				toast:Destroy()
			end)
		end
	end)
end

return UIController

