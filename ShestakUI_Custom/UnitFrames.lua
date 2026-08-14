local T, C, L = unpack(ShestakUI)
if not T or not C or C.unitframe.enable ~= true then return end

local _, ns = ...
local oUF = ShestakUI[2].oUF or ns.oUF or oUF

----------------------------------------------------------------------------------------
--	ShestakUI Custom: 单位框体回调与样式注入
----------------------------------------------------------------------------------------

-- 1. 自定义 PostUpdateHealth：生命值简洁数值显示 + 外侧大号百分比联动更新
local gradient = C_CurveUtil.CreateColorCurve()
gradient:SetType(Enum.LuaCurveType.Linear)
gradient:AddPoint(0, CreateColor(0.69, 0.31, 0.31, 1))
gradient:AddPoint(0.5, CreateColor(0.65, 0.63, 0.35, 1))
gradient:AddPoint(1, CreateColor(0.33, 0.59, 0.33, 1))

local full_health_value = C_CurveUtil.CreateColorCurve()
full_health_value:SetType(Enum.LuaCurveType.Step)
full_health_value:AddPoint(0, CreateColor(1, 1, 1, 0))
full_health_value:AddPoint(1, CreateColor(1, 1, 1, 1))

local health_value = C_CurveUtil.CreateColorCurve()
health_value:SetType(Enum.LuaCurveType.Step)
health_value:AddPoint(0, CreateColor(1, 1, 1, 1))
health_value:AddPoint(1, CreateColor(1, 1, 1, 0))

T.PostUpdateHealth = function(health, unit, cur, max)
	if not health.value then return end

	if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then
		health:SetValue(0)
		if not UnitIsConnected(unit) then
			health.value:SetText("|cffD7BEA5" .. (L_UF_OFFLINE or "Offline") .. "|r")
		elseif UnitIsDead(unit) then
			health.value:SetText("|cffD7BEA5" .. (L_UF_DEAD or "Dead") .. "|r")
		elseif UnitIsGhost(unit) then
			health.value:SetText("|cffD7BEA5" .. (L_UF_GHOST or "Ghost") .. "|r")
		end
		health.value:SetAlpha(1)
		if health.short_value then health.short_value:SetText() end

		-- 死亡或离线时，将外侧百分比设为 0%
		if health.percentage then
			local hex = "ff9d9d9d"
			if UnitIsPlayer(unit) or UnitInPartyIsAI(unit) then
				local _, class = UnitClass(unit)
				local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
				if color then
					hex = string.format("ff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
				end
			else
				local reaction = UnitReaction(unit, "player")
				if reaction and T.oUF_colors and T.oUF_colors.reaction then
					local c = T.oUF_colors.reaction[reaction]
					if c then
						hex = string.format("ff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
					end
				end
			end
			health.percentage:SetFormattedText("|c%s0%%|r", hex)
		end
	else
		local perc = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)

		if (unit == "player" or unit == "vehicle" or unit == "target") and health:GetAttribute("normalUnit") ~= "pet" then
			local success, result = pcall(function() return perc < 50 end)
			local isLowHealth = success and result
			local valueHex = isLowHealth and "ffff0000" or "ff559655"

			-- 生命值显示格式：简洁显示当前血量数值缩写
			health.value:SetFormattedText("|c%s%s|r", valueHex, T.ShortValue(cur))
			health.value:SetAlpha(1)
			if health.short_value then health.short_value:SetText("") end

			-- 更新外侧百分比文本，并使用职业/声望颜色
			if health.percentage then
				local hex = "ffffffff"
				if isLowHealth then
					hex = "ffff0000"
				elseif UnitIsPlayer(unit) or UnitInPartyIsAI(unit) then
					local _, class = UnitClass(unit)
					local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
					if color then
						hex = string.format("ff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
					end
				else
					local reaction = UnitReaction(unit, "player")
					if reaction and T.oUF_colors and T.oUF_colors.reaction then
						local c = T.oUF_colors.reaction[reaction]
						if c then
							hex = string.format("ff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
						end
					end
				end
				health.percentage:SetFormattedText("|c%s%d%%|r", hex, perc)
			end
		else
			local hex
			local success, result = pcall(function() return perc < 50 end)
			local isLowHealth = success and result
			if C.unitframe.color_value then
				local color = UnitHealthPercent(unit, true, gradient)
				hex = color:GenerateHexColor()
			else
				hex = isLowHealth and "ffff0000" or "ffffffff"
			end

			if unit and unit:find("boss%d") then
				if C.unitframe.color_value then
					health.value:SetFormattedText("|c%s%d%%|r |cffD7BEA5-|r |cffAF5050%s|r", hex, perc, T.ShortValue(cur))
				else
					health.value:SetFormattedText("|c%s%d%% - %s|r", hex, perc, T.ShortValue(cur))
				end
			else
				health.value:SetFormattedText("|c%s%d%%|r", hex, perc)
			end

			local color = UnitHealthPercent(unit, true, health_value)
			local _, _, _, alpha = color:GetRGBA()
			health.value:SetAlpha(alpha)

			if health.short_value then
				if C.unitframe.color_value then
					health.short_value:SetText("|cff559655" .. T.ShortValue(max) .. "|r")
				else
					health.short_value:SetText("|cffffffff" .. T.ShortValue(max) .. "|r")
				end
				local colorFull = UnitHealthPercent(unit, true, full_health_value)
				local _, _, _, alphaFull = colorFull:GetRGBA()
				health.short_value:SetAlpha(alphaFull)
			end
		end
	end
end

-- 2. 自定义 PostUpdatePower：隐藏玩家、目标及小队队友框体的能量数值文本
T.PostUpdatePower = function(power, unit, cur, _, max)
	local isDead = not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit)
	if isDead then
		power:SetValue(0)
	end

	if not power.value then return end

	-- 玩家框体（根据配置）与目标框体均不显示具体的能量/法力数值文本
	if (unit == "player" and C.unitframe.show_player_power ~= true) or unit == "target" then
		power.value:SetText("")
		if power.short_value then
			power.short_value:SetText("")
		end
		return
	end

	-- 小队队友框体根据配置隐藏能量数值
	if unit and (unit:find("^party%d?$") or unit == "party") and C.raidframe.show_party_power ~= true then
		power.value:SetText("")
		if power.short_value then
			power.short_value:SetText("")
		end
		return
	end

	if isDead then
		power.value:SetText()
		if power.short_value then power.short_value:SetText() end
	else
		local pType, pToken = UnitPowerType(unit)
		local perc = UnitPowerPercent(unit, pType, true, CurveConstants.ScaleTo100)
		if pType == 0 and pToken ~= "POWER_TYPE_DINO_SONIC" then
			if (unit == "player" and power:GetAttribute("normalUnit") == "pet") or unit == "pet" then
				if C.unitframe.color_value then
					power.value:SetFormattedText("%d%%", perc)
				else
					power.value:SetFormattedText("|cffffffff%d%%|r", perc)
				end
			elseif unit and (unit:find("arena%d") or unit:find("boss%d")) then
				if C.unitframe.color_value then
					power.value:SetFormattedText("|cffD7BEA5%d%% - %s|r", perc, T.ShortValue(cur))
				else
					power.value:SetFormattedText("|cffffffff%d%% - %s|r", perc, T.ShortValue(cur))
				end
			else
				if C.unitframe.color_value then
					power.value:SetFormattedText("%d%%", perc)
				else
					power.value:SetFormattedText("|cffffffff%d%%|r", perc)
				end
			end
		else
			if C.unitframe.color_value then
				power.value:SetFormattedText("%d%%", perc)
			else
				power.value:SetFormattedText("|cffffffff%d%%|r", perc)
			end
		end

		if power.short_value then
			local color = UnitPowerPercent(unit, pType, true, power_value)
			local _, _, _, alpha = color:GetRGBA()
			power.value:SetAlpha(alpha)

			if C.unitframe.color_value then
				power.short_value:SetText("|cff559655" .. T.ShortValue(max) .. "|r")
			else
				power.short_value:SetText("|cffffffff" .. T.ShortValue(max) .. "|r")
			end
			local colorFull = UnitPowerPercent(unit, pType, true, full_power_value)
			local _, _, _, alphaFull = colorFull:GetRGBA()
			power.short_value:SetAlpha(alphaFull)
		end
	end
end

-- 3. 注入玩家与目标框体样式与错位布局
local function CustomStyleUnitFrame(self, unit)
	if not self or not self.Health or not self.Power then return end

	local realUnit = unit or self.__unit or self.unit
	if realUnit == "player" or realUnit == "target" then
		-- 隐藏主框体统一样式边框背景
		if self.backdrop then
			self.backdrop:Hide()
		end

		-- 生命条独立背景与置顶 FrameLevel
		self.Health:CreateBackdrop("Default")
		self.Health:SetFrameLevel(6)
		if self.Health.backdrop then
			self.Health.backdrop:SetFrameLevel(5)
		end
		if self.Health.bg then
			self.Health.bg.multiplier = 0 -- 纯黑背景
		end

		-- 能量条高度与层级在下，与生命值条横向错位重叠
		self.Power:SetHeight(7 + (C.unitframe.extra_power_height or 0))
		self.Power:ClearAllPoints()
		if realUnit == "player" then
			self.Power:SetPoint("TOPLEFT", self.Health, "BOTTOMLEFT", -4, 2)
			self.Power:SetPoint("TOPRIGHT", self.Health, "BOTTOMRIGHT", -4, 2)
		else
			self.Power:SetPoint("TOPLEFT", self.Health, "BOTTOMLEFT", 4, 2)
			self.Power:SetPoint("TOPRIGHT", self.Health, "BOTTOMRIGHT", 4, 2)
		end
		self.Power:CreateBackdrop("Default")
		self.Power:SetFrameLevel(4)
		if self.Power.backdrop then
			self.Power.backdrop:SetFrameLevel(3)
		end

		-- 3D 头像 OVERLAY 模式嵌入
		if C.unitframe.portrait_enable and (C.unitframe.portrait_type == "OVERLAY" or C.unitframe.portrait_type == "3D") and self.Portrait then
			self.Portrait:ClearAllPoints()
			self.Portrait:SetAllPoints(self.Health)
			self.Portrait:SetFrameLevel(self.Health:GetFrameLevel() + 1)
			if self.Portrait.backdrop then
				self.Portrait.backdrop:Hide()
			end
			self.Portrait:SetAlpha(0.35)
		end

		-- 文字与外侧大号百分比布局
		if realUnit == "player" then
			-- 玩家等级显示在生命值条左侧
			if not self.Level then
				self.Level = T.SetFontString(self.Health, C.font.unit_frames_font, C.font.unit_frames_font_size, C.font.unit_frames_font_style)
			end
			self.Level:ClearAllPoints()
			self.Level:SetPoint("LEFT", self.Health, "LEFT", 4, 0)
			self:Tag(self.Level, "[GetNameColor][level]")

			-- 玩家生命百分比显示在框体右侧外部
			if not self.Health.percentage then
				self.Health.percentage = T.SetFontString(self, C.font.unit_frames_font, C.font.unit_frames_font_size * 2, C.font.unit_frames_font_style)
			end
			self.Health.percentage:ClearAllPoints()
			self.Health.percentage:SetPoint("LEFT", self, "RIGHT", 8, 0)

			-- 战役指示图标移动到左上角
			if self.CombatIndicator then
				self.CombatIndicator:ClearAllPoints()
				self.CombatIndicator:SetPoint("TOPLEFT", -4, 8)
			end
		elseif realUnit == "target" then
			-- 目标等级放置在生命值条最右侧
			if not self.Level then
				self.Level = T.SetFontString(self.Health, C.font.unit_frames_font, C.font.unit_frames_font_size, C.font.unit_frames_font_style)
			end
			self.Level:ClearAllPoints()
			self.Level:SetPoint("RIGHT", self.Health, "RIGHT", -4, 0)
			self:Tag(self.Level, "[GetNameColor][level]")

			-- 目标名字放置在等级的左侧
			if self.Info then
				self.Info:ClearAllPoints()
				self.Info:SetPoint("RIGHT", self.Level, "LEFT", -4, 0)
				self.Info:SetJustifyH("RIGHT")
				self:Tag(self.Info, "[GetNameColor][NameMedium]")
			end

			-- 目标外侧百分比文本放置在左侧外部
			if not self.Health.percentage then
				self.Health.percentage = T.SetFontString(self, C.font.unit_frames_font, C.font.unit_frames_font_size * 2, C.font.unit_frames_font_style)
			end
			self.Health.percentage:ClearAllPoints()
			self.Health.percentage:SetPoint("RIGHT", self, "LEFT", -8, 0)
		end
	end
end

-- 注册到 oUF 初始化回调
if oUF and oUF.RegisterInitCallback then
	oUF:RegisterInitCallback(CustomStyleUnitFrame)
end

-- 兼容可能已经生成的框架
local frameList = {
	"oUF_Player",
	"oUF_Target",
}
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
	for _, frameName in ipairs(frameList) do
		local f = _G[frameName]
		if f then
			local unit = f.__unit or (frameName == "oUF_Player" and "player") or (frameName == "oUF_Target" and "target")
			CustomStyleUnitFrame(f, unit)
		end
	end
end)
