--!strict
--[[
	TestRunner.server.luau
	Automated test executor for Roblox Studio & server startup.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UnitTestSuite = require(Shared:WaitForChild("Tests"):WaitForChild("UnitTestSuite"))

task.defer(function()
	task.wait(1.0) -- Allow bootstrap to finish logging
	print("--------------------------------------------------")
	print("🧪 RUNNING AUTOMATED UNIT TESTS...")
	print("--------------------------------------------------")

	local report = UnitTestSuite.RunAll()

	for _, result in ipairs(report.Results) do
		if result.Passed then
			print(string.format("  [PASS] ✓ %s", result.Name))
		else
			warn(string.format("  [FAIL] ✗ %s: %s", result.Name, tostring(result.ErrorMessage)))
		end
	end

	print("--------------------------------------------------")
	if report.Failed == 0 then
		print(string.format("✅ ALL %d TESTS PASSED SUCCESSFULLY!", report.Passed))
	else
		warn(string.format("❌ %d TESTS FAILED (%d PASSED)", report.Failed, report.Passed))
	end
	print("--------------------------------------------------")
end)

