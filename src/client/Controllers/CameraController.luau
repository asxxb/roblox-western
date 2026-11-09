--!strict
--[[
	CameraController.luau
	Client camera effects: cinematic NPC dialogue framing, smooth transitions, and field of view modulation.
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local camera = workspace.CurrentCamera
local localPlayer = Players.LocalPlayer

local CameraController = {
	Name = "CameraController",
}

local originalCameraType: Enum.CameraType = Enum.CameraType.Custom
local isFocusingNPC = false

function CameraController:Init()
	if not camera then
		camera = workspace.CurrentCamera
	end
end

function CameraController:Start()
	-- Initial setup
end

function CameraController:FocusOnNPC(npcModel: Model)
	if not camera or isFocusingNPC then
		return
	end

	local npcHead = npcModel:FindFirstChild("Head") :: BasePart?
	local playerChar = localPlayer.Character
	local playerRoot = if playerChar then playerChar:FindFirstChild("HumanoidRootPart") :: BasePart? else nil

	if not npcHead or not playerRoot then
		return
	end

	isFocusingNPC = true
	originalCameraType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable

	-- Compute an over-the-shoulder framing CFrame
	local npcPos = npcHead.Position
	local playerPos = playerRoot.Position
	local lookDirection = (npcPos - playerPos).Unit
	local rightVector = Vector3.new(-lookDirection.Z, 0, lookDirection.X).Unit

	local cameraTargetPos = playerPos + (rightVector * 2.2) + Vector3.new(0, 1.8, 0) - (lookDirection * 1.5)
	local targetCFrame = CFrame.new(cameraTargetPos, npcPos)

	local tweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	TweenService:Create(camera, tweenInfo, { CFrame = targetCFrame }):Play()
end

function CameraController:ResetCamera()
	if not camera or not isFocusingNPC then
		return
	end

	local playerChar = localPlayer.Character
	local humanoid = if playerChar then playerChar:FindFirstChildOfClass("Humanoid") else nil

	isFocusingNPC = false
	camera.CameraType = originalCameraType

	if humanoid then
		camera.CameraSubject = humanoid
	end
end

return CameraController

