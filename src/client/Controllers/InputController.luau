--!strict
--[[
	InputController.luau
	Client input handling: responsive movement, stamina-based sprinting, dynamic FOV, and mobile touch bindings.
]]

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Signal = require(Shared.Utilities.Signal)

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local InputController = {
	Name = "InputController",
	StaminaChanged = Signal.new() :: Signal.Signal<number, number>, -- (currentStamina, maxStamina)
	InventoryToggleRequested = Signal.new() :: Signal.Signal<()>,
	QuestJournalToggleRequested = Signal.new() :: Signal.Signal<()>,
}

local currentStamina = GameConfig.Player.Stamina.Max
local isSprinting = false
local lastSprintTime = 0

local function getCharacterHumanoid(): Humanoid?
	local char = localPlayer.Character
	if not char then
		return nil
	end
	return char:FindFirstChildOfClass("Humanoid")
end

local function setCameraFov(targetFov: number)
	if not camera then
		return
	end
	local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(camera, tweenInfo, { FieldOfView = targetFov }):Play()
end

function InputController:Init()
	-- Context Action Bindings
	ContextActionService:BindAction(
		"ToggleSprint",
		function(actionName, inputState, inputObj)
			if inputState == Enum.UserInputState.Begin then
				self:SetSprinting(true)
			elseif inputState == Enum.UserInputState.End then
				self:SetSprinting(false)
			end
			return Enum.ContextActionResult.Pass
		end,
		true,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.RightShift,
		Enum.KeyCode.ButtonL3
	)
	ContextActionService:SetTitle("ToggleSprint", "Sprint")

	ContextActionService:BindAction(
		"ToggleInventory",
		function(actionName, inputState, inputObj)
			if inputState == Enum.UserInputState.Begin then
				self.InventoryToggleRequested:Fire()
			end
			return Enum.ContextActionResult.Pass
		end,
		true,
		Enum.KeyCode.Tab,
		Enum.KeyCode.I
	)
	ContextActionService:SetTitle("ToggleInventory", "Bag")

	ContextActionService:BindAction(
		"ToggleQuestJournal",
		function(actionName, inputState, inputObj)
			if inputState == Enum.UserInputState.Begin then
				self.QuestJournalToggleRequested:Fire()
			end
			return Enum.ContextActionResult.Pass
		end,
		true,
		Enum.KeyCode.J
	)
	ContextActionService:SetTitle("ToggleQuestJournal", "Quests")
end

function InputController:Start()
	-- Stamina depletion and regeneration loop
	RunService.Heartbeat:Connect(function(dt: number)
		local humanoid = getCharacterHumanoid()
		if not humanoid then
			return
		end

		local isMoving = humanoid.MoveDirection.Magnitude > 0.1
		local maxStamina = GameConfig.Player.Stamina.Max

		if isSprinting and isMoving and currentStamina > 0 then
			-- Deplete stamina
			currentStamina = math.max(0, currentStamina - (GameConfig.Player.Stamina.DrainRate * dt))
			lastSprintTime = os.clock()
			humanoid.WalkSpeed = GameConfig.Player.SprintWalkSpeed

			if currentStamina <= 0 then
				self:SetSprinting(false)
			end
			self.StaminaChanged:Fire(currentStamina, maxStamina)
		else
			-- Regenerate stamina after delay
			local timeSinceSprint = os.clock() - lastSprintTime
			if timeSinceSprint >= GameConfig.Player.Stamina.RegenDelay and currentStamina < maxStamina then
				currentStamina = math.min(maxStamina, currentStamina + (GameConfig.Player.Stamina.RegenRate * dt))
				self.StaminaChanged:Fire(currentStamina, maxStamina)
			end

			if not isSprinting then
				humanoid.WalkSpeed = GameConfig.Player.NormalWalkSpeed
			end
		end
	end)

	localPlayer.CharacterAdded:Connect(function(char)
		currentStamina = GameConfig.Player.Stamina.Max
		self.StaminaChanged:Fire(currentStamina, GameConfig.Player.Stamina.Max)
		local humanoid = char:WaitForChild("Humanoid") :: Humanoid
		humanoid.WalkSpeed = GameConfig.Player.NormalWalkSpeed
		humanoid.JumpPower = GameConfig.Player.JumpPower
	end)
end

function InputController:SetSprinting(sprint: boolean)
	if sprint and currentStamina <= 5 then
		-- Cannot sprint when exhausted
		return
	end

	isSprinting = sprint
	local targetFov = if isSprinting then 78 else 70
	setCameraFov(targetFov)

	local humanoid = getCharacterHumanoid()
	if humanoid then
		humanoid.WalkSpeed = if isSprinting then GameConfig.Player.SprintWalkSpeed else GameConfig.Player.NormalWalkSpeed
	end
end

function InputController:GetStamina(): (number, number)
	return currentStamina, GameConfig.Player.Stamina.Max
end

return InputController
