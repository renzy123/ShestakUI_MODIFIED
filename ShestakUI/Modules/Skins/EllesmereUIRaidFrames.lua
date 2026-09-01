local T, C, L = unpack(ShestakUI)
if C.skins.ellesmere_raidframes ~= true or not C_AddOns.IsAddOnLoaded("EllesmereUIRaidFrames") then return end

----------------------------------------------------------------------------------------
--	EllesmereUIRaidFrames 皮肤模块（实现 ShestakUI 1px 像素边框、暗色背景与材质统一）
----------------------------------------------------------------------------------------
local function CreateBorderFrame(frame, point)
	if not frame then return end
	if point == nil then point = frame end
	if point.backdrop then return end

	-- 1. 创建暗色背景层
	frame.backdrop = frame:CreateTexture(nil, "BORDER")
	frame.backdrop:SetDrawLayer("BORDER", -8)
	frame.backdrop:SetPoint("TOPLEFT", point, "TOPLEFT", -T.noscalemult * 3, T.noscalemult * 3)
	frame.backdrop:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", T.noscalemult * 3, -T.noscalemult * 3)
	local r, g, b, a = unpack(C.media.backdrop_color)
	frame.backdrop:SetColorTexture(r, g, b + 0.01, a)

	-- 2. 创建 1px 边框材质
	frame.bordertop = frame:CreateTexture(nil, "BORDER")
	frame.bordertop:SetPoint("TOPLEFT", point, "TOPLEFT", -T.noscalemult * 2, T.noscalemult * 2)
	frame.bordertop:SetPoint("TOPRIGHT", point, "TOPRIGHT", T.noscalemult * 2, T.noscalemult * 2)
	frame.bordertop:SetHeight(T.noscalemult)
	frame.bordertop:SetColorTexture(unpack(C.media.border_color))
	frame.bordertop:SetDrawLayer("BORDER", -7)

	frame.borderbottom = frame:CreateTexture(nil, "BORDER")
	frame.borderbottom:SetPoint("BOTTOMLEFT", point, "BOTTOMLEFT", -T.noscalemult * 2, -T.noscalemult * 2)
	frame.borderbottom:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", T.noscalemult * 2, -T.noscalemult * 2)
	frame.borderbottom:SetHeight(T.noscalemult)
	frame.borderbottom:SetColorTexture(unpack(C.media.border_color))
	frame.borderbottom:SetDrawLayer("BORDER", -7)

	frame.borderleft = frame:CreateTexture(nil, "BORDER")
	frame.borderleft:SetPoint("TOPLEFT", point, "TOPLEFT", -T.noscalemult * 2, T.noscalemult * 2)
	frame.borderleft:SetPoint("BOTTOMLEFT", point, "BOTTOMLEFT", T.noscalemult * 2, -T.noscalemult * 2)
	frame.borderleft:SetWidth(T.noscalemult)
	frame.borderleft:SetColorTexture(unpack(C.media.border_color))
	frame.borderleft:SetDrawLayer("BORDER", -7)

	frame.borderright = frame:CreateTexture(nil, "BORDER")
	frame.borderright:SetPoint("TOPRIGHT", point, "TOPRIGHT", T.noscalemult * 2, T.noscalemult * 2)
	frame.borderright:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", -T.noscalemult * 2, -T.noscalemult * 2)
	frame.borderright:SetWidth(T.noscalemult)
	frame.borderright:SetColorTexture(unpack(C.media.border_color))
	frame.borderright:SetDrawLayer("BORDER", -7)

	if frame.border then
		frame.border:SetAlpha(0)
	end
end

-- 对单个 Ellesmere 团队/小队单元框体应用美化
local function SkinRaidButton(button)
	if not button or button.shestakStyled then return end
	button.shestakStyled = true

	-- 主单元框体边框与暗色背景
	CreateBorderFrame(button)

	-- 替换各状态条材质
	local children = { button:GetChildren() }
	for _, child in ipairs(children) do
		if child:IsObjectType("StatusBar") then
			child:SetStatusBarTexture(C.media.texture)
		end
	end

	-- 检查并美化内部绑定的血条与能量条
	local d = button._euiData
	if d then
		if d.health and d.health.SetStatusBarTexture then
			d.health:SetStatusBarTexture(C.media.texture)
		end
		if d.power and d.power.SetStatusBarTexture then
			d.power:SetStatusBarTexture(C.media.texture)
		end
		if d.absorbBar and d.absorbBar.SetStatusBarTexture then
			d.absorbBar:SetStatusBarTexture(C.media.texture)
		end
	end
end

-- 周期轮询检查当前活动的团队框体实例
local function onUpdate(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed < 0.2 then return end
	self.elapsed = 0

	local ns = EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS["EllesmereUIRaidFrames"]
	if ns and ns._euiUnitButtons then
		for button in pairs(ns._euiUnitButtons) do
			SkinRaidButton(button)
		end
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_ENTERING_WORLD" then
		self:SetScript("OnUpdate", onUpdate)
	end
end)
