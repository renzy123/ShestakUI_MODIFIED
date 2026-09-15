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

-- 强制锁定状态条材质为 Shestak 材质，防御暴雪原生更新与重用时回退为默认材质
local function EnforceStatusBarTexture(bar, targetTexture)
	if not bar or not bar.SetStatusBarTexture then return end

	-- 1. 立即设置一次状态条材质
	bar:SetStatusBarTexture(targetTexture)

	-- 2. 挂载安全钩子，防止暴雪原生逻辑（如 CompactUnitFrame / NamePlateDriver）再次将其改写回默认材质
	if not bar._shetsakTexHooked then
		bar._shetsakTexHooked = true
		hooksecurefunc(bar, "SetStatusBarTexture", function(self, texture)
			if texture ~= targetTexture then
				self:SetStatusBarTexture(targetTexture)
			end
		end)
	end

	-- 3. 兼容魔兽世界 11.0+ 暴雪 NamePlateHealthBar 的内部 barTexture 与 Atlas
	local fillTex = bar.barTexture or (bar.GetStatusBarTexture and bar:GetStatusBarTexture())
	if fillTex and not fillTex._shetsakTexHooked then
		fillTex._shetsakTexHooked = true
		if fillTex.SetTexture then
			hooksecurefunc(fillTex, "SetTexture", function(self, tex)
				if tex ~= targetTexture then
					self:SetTexture(targetTexture)
				end
			end)
		end
		if fillTex.SetAtlas then
			hooksecurefunc(fillTex, "SetAtlas", function(self)
				self:SetTexture(targetTexture)
			end)
		end
	end
end

-- 获取暴雪原生姓名板生命条与施法条（兼容 11.0+ 与传统结构）
local function GetBlizzardHealthBar(uf)
	if not uf then return nil end
	return (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar) or uf.healthBar
end

local function GetBlizzardCastBar(uf)
	if not uf then return nil end
	return (uf.CastBarsContainer and uf.CastBarsContainer.castBar) or uf.castBar
end

-- 对单个 Ellesmere 姓名板实例应用美化
local function SkinPlate(plate)
	if not plate then return end

	-- 生命条美化与材质锁定
	if plate.health and plate.health.SetStatusBarTexture then
		EnforceStatusBarTexture(plate.health, C.media.texture)
		if not plate.health.styled then
			CreateBorderFrame(plate.health)
			plate.health.styled = true
		end
	end

	-- 施法条美化与材质锁定
	if plate.cast and plate.cast.SetStatusBarTexture then
		EnforceStatusBarTexture(plate.cast, C.media.texture)
		if not plate.cast.styled then
			CreateBorderFrame(plate.cast)
			plate.cast.styled = true
		end
		local castIcon = plate.castIcon or (plate.cast and plate.cast.Icon)
		if castIcon and not castIcon.styled then
			CreateBorderFrame(plate.cast, castIcon)
			if castIcon.SetTexCoord then
				castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end
			castIcon.styled = true
		end
	end

	-- 能量条美化与材质锁定
	if plate.power and plate.power.SetStatusBarTexture then
		EnforceStatusBarTexture(plate.power, C.media.texture)
		if not plate.power.styled then
			CreateBorderFrame(plate.power)
			plate.power.styled = true
		end
	end
end

-- 对原生暴雪姓名板实例应用美化与材质锁定（覆盖友方或副本中未被 Ellesmere 接管的原生姓名板）
local function SkinNativeNameplate(nameplate)
	if not nameplate or not nameplate.UnitFrame then return end
	local uf = nameplate.UnitFrame

	local blizzHp = GetBlizzardHealthBar(uf)
	if blizzHp and blizzHp.SetStatusBarTexture then
		EnforceStatusBarTexture(blizzHp, C.media.texture)
		if not blizzHp.styled then
			CreateBorderFrame(blizzHp)
			blizzHp.styled = true
		end
	end

	local blizzCast = GetBlizzardCastBar(uf)
	if blizzCast and blizzCast.SetStatusBarTexture then
		EnforceStatusBarTexture(blizzCast, C.media.texture)
		if not blizzCast.styled then
			CreateBorderFrame(blizzCast)
			blizzCast.styled = true
		end
	end
end

-- 周期轮询检查当前活动的姓名板实例
local function onUpdate(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed < 0.2 then return end
	self.elapsed = 0

	local ns = _G.EllesmereNameplates_NS
	if ns and ns.plates then
		for _, plate in pairs(ns.plates) do
			SkinPlate(plate)
		end
	end

	-- 扫描当前屏幕上所有原生姓名板
	local plates = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates()
	if plates then
		for _, plate in ipairs(plates) do
			SkinNativeNameplate(plate)
		end
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("NAME_PLATE_CREATED")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:SetScript("OnEvent", function(self, event, arg1)
	if event == "PLAYER_ENTERING_WORLD" then
		f:SetScript("OnUpdate", onUpdate)
	elseif event == "NAME_PLATE_CREATED" and type(arg1) == "table" then
		SkinNativeNameplate(arg1)
	elseif event == "NAME_PLATE_UNIT_ADDED" and type(arg1) == "string" then
		if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
			local plate = C_NamePlate.GetNamePlateForUnit(arg1)
			if plate then
				SkinNativeNameplate(plate)
			end
		end
	end
end)
