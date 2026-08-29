local T, C, L = unpack(ShestakUI)
if C.skins.ellesmere_nameplates ~= true or not C_AddOns.IsAddOnLoaded("EllesmereUINameplates") then return end

----------------------------------------------------------------------------------------
--	EllesmereUINameplates 皮肤模块（参照 Plater 风格实现 1px 像素边框与暗色背景）
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

-- 对单个 Ellesmere 姓名板实例应用美化
local function SkinPlate(plate)
	if not plate then return end

	-- 生命条美化
	if plate.health and not plate.health.styled then
		CreateBorderFrame(plate.health)
		plate.health.styled = true
	end

	-- 施法条美化
	if plate.cast and not plate.cast.styled then
		CreateBorderFrame(plate.cast)
		local castIcon = plate.castIcon or (plate.cast and plate.cast.Icon)
		if castIcon and not castIcon.styled then
			CreateBorderFrame(plate.cast, castIcon)
			if castIcon.SetTexCoord then
				castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end
			castIcon.styled = true
		end
		plate.cast.styled = true
	end

	-- 能量条美化
	if plate.power and not plate.power.styled then
		CreateBorderFrame(plate.power)
		plate.power.styled = true
	end
end

-- 周期轮询检查当前活动的姓名板实例
local function onUpdate(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed < 0.2 then return end
	self.elapsed = 0

	local ns = _G.EllesmereNameplates_NS
	if not (ns and ns.plates) then return end

	for _, plate in pairs(ns.plates) do
		SkinPlate(plate)
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
	f:SetScript("OnUpdate", onUpdate)
end)
