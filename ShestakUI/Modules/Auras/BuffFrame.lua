local T, C, L = unpack(ShestakUI)
if C.aura.player_auras ~= true then return end

----------------------------------------------------------------------------------------
--	Style player buff(by Tukz)
----------------------------------------------------------------------------------------
local rowbuffs = 16
local alpha = 0
local space = 3

local GetFormattedTime = function(s)
	if s >= 86400 then
		return format("%dd", floor(s / 86400 + 0.5))
	elseif s >= 3600 then
		return format("%dh", floor(s / 3600 + 0.5))
	elseif s >= 60 then
		return format("%dm", floor(s / 60 + 0.5))
	end
	return floor(s + 0.5)
end

local BuffsAnchor = CreateFrame("Frame", "BuffsAnchor", UIParent)
BuffsAnchor:SetPoint(unpack(C.position.player_buffs))
BuffsAnchor:SetSize((15 * C.aura.player_buff_size) + 42, (C.aura.player_buff_size * 2) + space)

-- 玩家 DEBUFF 锚点（沿用 PrivateAnchor 注册名称，无缝兼容 /moveui 移动与保存）
local DebuffsAnchor = CreateFrame("Frame", "PrivateAnchor", UIParent)
DebuffsAnchor:SetSize((15 * C.aura.player_buff_size) + 42, (C.aura.player_buff_size * 2) + space)
local PrivateAnchor = DebuffsAnchor

-- 动态更新 DEBUFF 锚点位置：默认紧随 BUFF 栏下方（未被 /moveui 自定义移动时）
local function UpdateDebuffsAnchor(numBuffs)
	local positionTable = T.CurrentProfile()
	if positionTable and positionTable["PrivateAnchor"] then return end

	if not numBuffs then
		numBuffs = BuffFrame.auraFrames and #BuffFrame.auraFrames or 0
	end
	-- 当 BUFF 数量不超过 1 行（<= 16 个）时紧随第 1 行下方；超过 1 行时自动随第 2 行下移
	local rows = numBuffs > rowbuffs and 2 or 1
	local buffHeight = (rows * C.aura.player_buff_size) + ((rows - 1) * space)
	local left = T.IsFramePositionedLeft(BuffsAnchor)

	DebuffsAnchor:ClearAllPoints()
	if left then
		DebuffsAnchor:SetPoint("TOPLEFT", BuffsAnchor, "TOPLEFT", 0, -(buffHeight + space + 2))
	else
		DebuffsAnchor:SetPoint("TOPRIGHT", BuffsAnchor, "TOPRIGHT", 0, -(buffHeight + space + 2))
	end
end
UpdateDebuffsAnchor(0)

local function UpdateDuration(aura, timeLeft)
	local duration = aura.Duration
	if timeLeft and C.aura.show_timer == true then
		duration:SetVertexColor(1, 1, 1)
		if canaccessvalue(timeLeft) then -- BETA
			duration:SetFormattedText(GetFormattedTime(timeLeft))
		end
	else
		duration:Hide()
	end
end

-- Reposition
C_Timer.After(0.2, function()
	local left = T.IsFramePositionedLeft(BuffsAnchor)
	if left then
		local previousBuff, aboveBuff
		for index, aura in ipairs(BuffFrame.auraFrames) do
			aura:ClearAllPoints()
			if (index > 1) and (mod(index, rowbuffs) == 1) then
				aura:SetPoint("TOP", aboveBuff, "BOTTOM", 0, -space)
				aboveBuff = aura
			elseif index == 1 then
				aura:SetPoint("TOPLEFT", BuffsAnchor, "TOPLEFT", 0, 0)
				aboveBuff = aura
			else
				aura:SetPoint("LEFT", previousBuff, "RIGHT", space, 0)
			end
			previousBuff = aura
		end
	end
	UpdateDebuffsAnchor()
end)

hooksecurefunc(BuffFrame.AuraContainer, "UpdateGridLayout", function(_, auras)
	UpdateDebuffsAnchor(#auras)

	local previousBuff, aboveBuff
	local left = T.IsFramePositionedLeft(BuffsAnchor)
	for index, aura in ipairs(auras) do
		aura:SetSize(C.aura.player_buff_size, C.aura.player_buff_size)
		aura:SetTemplate("Default")

		aura.TempEnchantBorder:SetAlpha(0)
		hooksecurefunc(aura.TempEnchantBorder, "Show", function()
			aura:SetBackdropBorderColor(0.6, 0.1, 0.6)
		end)

		hooksecurefunc(aura.TempEnchantBorder, "Hide", function()
			if C.aura.classcolor_border == true then
				aura:SetBackdropBorderColor(unpack(C.media.classborder_color))
			else
				aura:SetBackdropBorderColor(unpack(C.media.border_color))
			end
		end)

		aura:ClearAllPoints()
		if left then
			if (index > 1) and (mod(index, rowbuffs) == 1) then
				aura:SetPoint("TOP", aboveBuff, "BOTTOM", 0, -space)
				aboveBuff = aura
			elseif index == 1 then
				aura:SetPoint("TOPLEFT", BuffsAnchor, "TOPLEFT", 0, 0)
				aboveBuff = aura
			else
				aura:SetPoint("LEFT", previousBuff, "RIGHT", space, 0)
			end
		else
			if (index > 1) and (mod(index, rowbuffs) == 1) then
				aura:SetPoint("TOP", aboveBuff, "BOTTOM", 0, -space)
				aboveBuff = aura
			elseif index == 1 then
				aura:SetPoint("TOPRIGHT", BuffsAnchor, "TOPRIGHT", 0, 0)
				aboveBuff = aura
			else
				aura:SetPoint("RIGHT", previousBuff, "LEFT", -space, 0)
			end
		end

		previousBuff = aura

		aura.Icon:CropIcon()
		aura.Icon:SetDrawLayer("BORDER")

		local duration = aura.Duration
		duration:ClearAllPoints()
		duration:SetPoint("CENTER", 2, 1)
		duration:SetDrawLayer("ARTWORK")
		duration:SetFont(C.font.auras_font, C.font.auras_font_size, C.font.auras_font_style)
		duration:SetShadowOffset(C.font.auras_font_shadow and 1 or 0, C.font.auras_font_shadow and -1 or 0)

		if not aura.hook then
			hooksecurefunc(aura, "UpdateDuration", function(aura, timeLeft)
				UpdateDuration(aura, timeLeft)
			end)
			if C.aura.player_buff_mouseover then
				aura:SetParent(BuffsAnchor)
				aura:HookScript("OnEnter", function()
					BuffsAnchor:SetAlpha(1)
				end)
				aura:HookScript("OnLeave", function()
					BuffsAnchor:SetAlpha(alpha)
				end)
			end
			aura.hook = true
		end

		if aura.Count then -- need to check exist to prevent error in EditMode
			aura.Count:ClearAllPoints()
			aura.Count:SetPoint("BOTTOMRIGHT", 2, 0)
			aura.Count:SetDrawLayer("ARTWORK")
			aura.Count:SetFont(C.font.auras_font, C.font.auras_font_size, C.font.auras_font_style)
			aura.Count:SetShadowOffset(C.font.auras_font_shadow and 1 or 0, C.font.auras_font_shadow and -1 or 0)
		end
	end
end)

-- Mouseover
if C.aura.player_buff_mouseover then
	BuffsAnchor:SetAlpha(alpha)
	BuffsAnchor:HookScript("OnEnter", function()
		BuffsAnchor:SetAlpha(1)
	end)
	BuffsAnchor:HookScript("OnLeave", function()
		BuffsAnchor:SetAlpha(alpha)
	end)
end

-- Hide collapse button
BuffFrame.CollapseAndExpandButton:Kill()

-- 样式化并重定位玩家 DEBUFF（显示在 BUFF 栏下方）
hooksecurefunc(DebuffFrame.AuraContainer, "UpdateGridLayout", function(_, auras)
	UpdateDebuffsAnchor()

	local previousBuff, aboveBuff
	local left = T.IsFramePositionedLeft(BuffsAnchor)
	for index, aura in ipairs(auras) do
		aura:SetSize(C.aura.player_buff_size, C.aura.player_buff_size)
		aura:SetTemplate("Default")

		-- 根据减益类型（魔法、诅咒、中毒、疾病、物理等）为边框着色
		local debuffBorder = aura.Border or aura.DebuffBorder
		if debuffBorder then
			debuffBorder:SetAlpha(0)
			if not aura.borderHook then
				hooksecurefunc(debuffBorder, "SetVertexColor", function(_, r, g, b)
					if C.aura.debuff_color_type then
						aura:SetBackdropBorderColor(r, g, b)
					else
						aura:SetBackdropBorderColor(1, 0, 0)
					end
				end)
				aura.borderHook = true
			end
			if C.aura.debuff_color_type then
				local r, g, b = debuffBorder:GetVertexColor()
				if r and g and b then
					aura:SetBackdropBorderColor(r, g, b)
				else
					aura:SetBackdropBorderColor(1, 0, 0)
				end
			else
				aura:SetBackdropBorderColor(1, 0, 0)
			end
		else
			aura:SetBackdropBorderColor(1, 0, 0)
		end

		aura:ClearAllPoints()
		if left then
			if (index > 1) and (mod(index, rowbuffs) == 1) then
				aura:SetPoint("TOP", aboveBuff, "BOTTOM", 0, -space)
				aboveBuff = aura
			elseif index == 1 then
				aura:SetPoint("TOPLEFT", DebuffsAnchor, "TOPLEFT", 0, 0)
				aboveBuff = aura
			else
				aura:SetPoint("LEFT", previousBuff, "RIGHT", space, 0)
			end
		else
			if (index > 1) and (mod(index, rowbuffs) == 1) then
				aura:SetPoint("TOP", aboveBuff, "BOTTOM", 0, -space)
				aboveBuff = aura
			elseif index == 1 then
				aura:SetPoint("TOPRIGHT", DebuffsAnchor, "TOPRIGHT", 0, 0)
				aboveBuff = aura
			else
				aura:SetPoint("RIGHT", previousBuff, "LEFT", -space, 0)
			end
		end

		previousBuff = aura

		aura.Icon:CropIcon()
		aura.Icon:SetDrawLayer("BORDER")

		local duration = aura.Duration
		if duration then
			duration:ClearAllPoints()
			duration:SetPoint("CENTER", 2, 1)
			duration:SetDrawLayer("ARTWORK")
			duration:SetFont(C.font.auras_font, C.font.auras_font_size, C.font.auras_font_style)
			duration:SetShadowOffset(C.font.auras_font_shadow and 1 or 0, C.font.auras_font_shadow and -1 or 0)
		end

		if not aura.hook then
			hooksecurefunc(aura, "UpdateDuration", function(aura, timeLeft)
				UpdateDuration(aura, timeLeft)
			end)
			aura.hook = true
		end

		if aura.Count then
			aura.Count:ClearAllPoints()
			aura.Count:SetPoint("BOTTOMRIGHT", 2, 0)
			aura.Count:SetDrawLayer("ARTWORK")
			aura.Count:SetFont(C.font.auras_font, C.font.auras_font_size, C.font.auras_font_style)
			aura.Count:SetShadowOffset(C.font.auras_font_shadow and 1 or 0, C.font.auras_font_shadow and -1 or 0)
		end
	end
end)