--!strict
--[[
	SpatialUtil.luau
	Spatial calculations, line-of-sight checks, and server-side distance validation.
]]

local Workspace = game:GetService("Workspace")

local SpatialUtil = {}

-- Safely retrieves the primary position of a player character
function SpatialUtil.GetPlayerPosition(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if rootPart then
		return rootPart.Position
	end

	local primaryPart = character.PrimaryPart
	if primaryPart then
		return primaryPart.Position
	end

	return nil
end

-- Safely retrieves the position of any target instance (BasePart, Model, or Attachment)
function SpatialUtil.GetInstancePosition(target: Instance): Vector3?
	if target:IsA("BasePart") then
		return target.Position
	elseif target:IsA("Model") then
		local primary = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
		if primary then
			return primary.Position
		end
	elseif target:IsA("Attachment") then
		return target.WorldPosition
	end
	return nil
end

-- Validates whether a player is within allowed distance of a target instance.
-- Includes latency compensation (tolerance buffer) to avoid false positives for high-ping players.
function SpatialUtil.IsWithinDistance(
	player: Player,
	target: Instance,
	maxDistance: number,
	pingTolerance: number?
): boolean
	local playerPos = SpatialUtil.GetPlayerPosition(player)
	if not playerPos then
		return false
	end

	local targetPos = SpatialUtil.GetInstancePosition(target)
	if not targetPos then
		return false
	end

	local tolerance = pingTolerance or 5.0 -- 5 studs default latency buffer
	local effectiveMax = maxDistance + tolerance
	local distanceSquared = (playerPos - targetPos).Magnitude

	return distanceSquared <= effectiveMax
end

-- Performs a raycast check between two points to verify line of sight
function SpatialUtil.HasLineOfSight(
	origin: Vector3,
	destination: Vector3,
	ignoreList: { Instance }?
): boolean
	local direction = destination - origin
	local params = RaycastParams.new()
	params.FilterType = RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList or {}
	params.IgnoreWater = true

	local result = Workspace:Raycast(origin, direction, params)
	if not result then
		return true
	end

	-- If the hit part is very close to destination, consider line of sight clear
	return (result.Position - destination).Magnitude <= 1.0
end

return SpatialUtil
