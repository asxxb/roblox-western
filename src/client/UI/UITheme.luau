--!strict
--[[
	UITheme.luau
	Stylized Western design system: typography, warm parchment palette, borders, and animations.
]]

local UITheme = {
	Colors = {
		BackgroundDark = Color3.fromRGB(36, 26, 20),
		BackgroundParchment = Color3.fromRGB(244, 233, 212),
		ParchmentLight = Color3.fromRGB(250, 243, 228),
		BorderGold = Color3.fromRGB(212, 168, 75),
		BorderWood = Color3.fromRGB(94, 62, 38),
		TextDark = Color3.fromRGB(48, 32, 20),
		TextLight = Color3.fromRGB(250, 240, 225),
		TextMuted = Color3.fromRGB(140, 120, 105),
		GoldCoin = Color3.fromRGB(255, 200, 45),
		HealthGreen = Color3.fromRGB(85, 175, 80),
		StaminaYellow = Color3.fromRGB(240, 180, 50),
		ButtonNormal = Color3.fromRGB(72, 48, 32),
		ButtonHover = Color3.fromRGB(105, 72, 48),
		ButtonPressed = Color3.fromRGB(48, 30, 18),
		AccentRed = Color3.fromRGB(180, 50, 40),
		SuccessGreen = Color3.fromRGB(60, 150, 70),
	},

	Fonts = {
		Title = Enum.Font.Antique,
		Body = Enum.Font.SourceSansSemibold,
		Monospace = Enum.Font.RobotoMono,
	},

	Animation = {
		Quick = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Standard = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		Smooth = TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
	},
}

return UITheme

