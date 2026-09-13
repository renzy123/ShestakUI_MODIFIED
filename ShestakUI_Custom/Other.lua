local T, C, L = unpack(ShestakUI)
if not T or not C then return end

----------------------------------------------------------------------------------------
--	ShestakUI Custom: 其他杂项优化与锚点校准
----------------------------------------------------------------------------------------

-- 1. Filger 监视条位置校准
if C.filger and C.filger.enable then
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:SetScript("OnEvent", function()
		if _G.T_DE_BUFF_BAR_Anchor and C.position and C.position.filger and C.position.filger.target_bar then
			local pos = C.position.filger.target_bar
			T_DE_BUFF_BAR_Anchor:ClearAllPoints()
			T_DE_BUFF_BAR_Anchor:SetPoint(pos[1], pos[2], pos[3], pos[4], pos[5])
		end
	end)
end

----------------------------------------------------------------------------------------
-- 2. 安全版 T.HasPlayerBuff
-- 使用 12.1.0 官方公开安全的槽位检索接口，杜绝 GetAuraDataByIndex 触发 Secret Taint
----------------------------------------------------------------------------------------
T.HasPlayerBuff = function(spell)
	local slots = { UnitAuraSlots("player", "HELPFUL") }
	for _, slot in ipairs(slots) do
		local auraData = C_UnitAuras.GetAuraDataBySlot("player", slot)
		if auraData and auraData.name == spell then
			return true
		end
	end
	return nil
end

----------------------------------------------------------------------------------------
-- 3. 地下堡难度选择/确认界面 (DelvesDifficultyPickerFrame) 图标越界修复
-- 进入地下堡时弹出的确认界面中，多个图标显示在一行可能导致横向越界，对图标进行等比缩放
----------------------------------------------------------------------------------------
local function FixDelvesDifficultyPickerIcons()
	local frame = _G.DelvesDifficultyPickerFrame
	if not frame then return end

	-- 1. 针对词缀/地图修饰符图标容器 (DelveModifiersWidgetContainer) 进行缩放与边界保护
	local modifiers = frame.DelveModifiersWidgetContainer
	if modifiers then
		modifiers:SetScale(0.85) -- 缩放至 85%，防止一行多个词缀图标超出右侧边界
	end

	-- 2. 针对奖励列表容器 (DelveRewardsContainerFrame) 进行缩放与图标尺寸优化
	local rewards = frame.DelveRewardsContainerFrame
	if rewards then
		rewards:SetScale(0.85) -- 对奖励容器整体进行缩放，确保容纳一行多图标并紧凑排列

		-- 动态缩放并重整每个奖励卡片中的图标，防止滚动或刷新后尺寸反弹
		local function RescaleRewardIcon(rewardFrame)
			if not rewardFrame then return end
			if rewardFrame.Icon then
				rewardFrame.Icon:SetSize(28, 28)
			end
			if rewardFrame.IconBorder then
				rewardFrame.IconBorder:SetSize(28, 28)
			end
			if rewardFrame.backdrop then
				rewardFrame.backdrop:SetInside(rewardFrame.Icon, 0, 0)
			end
		end

		if rewards.ScrollBox then
			hooksecurefunc(rewards.ScrollBox, "Update", function(self)
				if self.ForEachFrame then
					self:ForEachFrame(RescaleRewardIcon)
				end
			end)
		end
	end

	-- 3. 难度切换或显示模式变化时再次保障图标尺寸
	if frame.CheckAndSetDisplayMode then
		hooksecurefunc(frame, "CheckAndSetDisplayMode", function()
			if rewards and rewards.ScrollBox and rewards.ScrollBox.ForEachFrame then
				rewards.ScrollBox:ForEachFrame(function(rewardFrame)
					if rewardFrame and rewardFrame.Icon then
						rewardFrame.Icon:SetSize(28, 28)
					end
				end)
			end
		end)
	end
end

-- 注册按需加载监听 (Blizzard_DelvesDifficultyPicker 为 LoD 插件)
local isLoaded = false
if C_AddOns and C_AddOns.IsAddOnLoaded then
	isLoaded = C_AddOns.IsAddOnLoaded("Blizzard_DelvesDifficultyPicker")
elseif IsAddOnLoaded then
	isLoaded = IsAddOnLoaded("Blizzard_DelvesDifficultyPicker")
end

if isLoaded then
	FixDelvesDifficultyPickerIcons()
else
	local delvesLoader = CreateFrame("Frame")
	delvesLoader:RegisterEvent("ADDON_LOADED")
	delvesLoader:SetScript("OnEvent", function(self, event, addon)
		if addon == "Blizzard_DelvesDifficultyPicker" then
			FixDelvesDifficultyPickerIcons()
			self:UnregisterEvent("ADDON_LOADED")
		end
	end)
end

----------------------------------------------------------------------------------------
-- 4. 玩家 DEBUFF 显示在右上角 BUFF 栏下方并应用 ShestakUI 像素美化
----------------------------------------------------------------------------------------
if C.aura and C.aura.player_auras == true then
	local space = 3
	local rowbuffs = 16

	-- 1. 屏蔽玩家头像（oUF_Player）上方原有的 Debuffs，防止两处重复显示
	local function DisablePlayerFrameDebuffs()
		if _G.oUF_Player and _G.oUF_Player.Debuffs then
			_G.oUF_Player.Debuffs:Hide()
			_G.oUF_Player.Debuffs.Show = function() end
			if _G.oUF_Player.DisableElement then
				_G.oUF_Player:DisableElement("Debuffs")
			end
		end
	end
	DisablePlayerFrameDebuffs()

	-- 2. 调整 DEBUFF 锚点（PrivateAnchor）尺寸以匹配 BUFF 栏整行宽度
	if _G.PrivateAnchor then
		_G.PrivateAnchor:SetSize((15 * C.aura.player_buff_size) + 42, (C.aura.player_buff_size * 2) + space)
	end

	-- 3. 动态计算 DEBUFF 锚点位置：未被 /moveui 自定义移动时，自动紧随当前 BUFF 行数下方
	local function UpdateDebuffsAnchor(numBuffs)
		if not _G.PrivateAnchor or not _G.BuffsAnchor then return end

		local positionTable = T.CurrentProfile()
		if positionTable and positionTable["PrivateAnchor"] then return end

		if not numBuffs then
			numBuffs = BuffFrame and BuffFrame.auraFrames and #BuffFrame.auraFrames or 0
		end
		-- BUFF 占 1 行（≤16个）时紧随第 1 行下方；超过 1 行时随第 2 行下移，避免空隙与跳动
		local rows = numBuffs > rowbuffs and 2 or 1
		local buffHeight = (rows * C.aura.player_buff_size) + ((rows - 1) * space)
		local left = T.IsFramePositionedLeft(BuffsAnchor)

		PrivateAnchor:ClearAllPoints()
		if left then
			PrivateAnchor:SetPoint("TOPLEFT", BuffsAnchor, "TOPLEFT", 0, -(buffHeight + space + 2))
		else
			PrivateAnchor:SetPoint("TOPRIGHT", BuffsAnchor, "TOPRIGHT", 0, -(buffHeight + space + 2))
		end
	end

	-- 4. 监听 BUFF 栏更新，动态联动 DEBUFF 垂直位置
	if BuffFrame and BuffFrame.AuraContainer then
		hooksecurefunc(BuffFrame.AuraContainer, "UpdateGridLayout", function(_, auras)
			UpdateDebuffsAnchor(#auras)
		end)
	end

	-- 5. 格式化倒计时文本辅助函数
	local function GetFormattedTime(s)
		if s >= 86400 then
			return format("%dd", floor(s / 86400 + 0.5))
		elseif s >= 3600 then
			return format("%dh", floor(s / 3600 + 0.5))
		elseif s >= 60 then
			return format("%dm", floor(s / 60 + 0.5))
		end
		return floor(s + 0.5)
	end

	local function UpdateDuration(aura, timeLeft)
		local duration = aura.Duration
		if duration then
			if timeLeft and C.aura.show_timer == true then
				duration:SetVertexColor(1, 1, 1)
				if canaccessvalue(timeLeft) then
					duration:SetFormattedText(GetFormattedTime(timeLeft))
				end
			else
				duration:Hide()
			end
		end
	end

	-- 6. 对原生 DebuffFrame 应用 ShestakUI 像素美化、减益类型染色及排版重整
	if DebuffFrame and DebuffFrame.AuraContainer then
		hooksecurefunc(DebuffFrame.AuraContainer, "UpdateGridLayout", function(_, auras)
			UpdateDebuffsAnchor()

			if #auras > 0 then
				DebuffFrame:Show()
				DebuffFrame.AuraContainer:Show()
			end

			local previousBuff, aboveBuff
			local left = T.IsFramePositionedLeft(BuffsAnchor)
			for index, aura in ipairs(auras) do
				aura:SetSize(C.aura.player_buff_size, C.aura.player_buff_size)

				-- 私有光环锚点（BuffFramePrivateAuraAnchorTemplate）是由暴雪沙盒管理的占位框体，
				-- 仅参与网格排版，其 Icon 与 Duration 均为 Frame 而非 Texture/FontString，跳过常规样式美化
				if not aura.isAuraAnchor then
					aura:SetTemplate("Default")

					-- 根据减益类型（魔法、诅咒、中毒、疾病、物理等）为边框着色
					local debuffBorder = aura.Border or aura.DebuffBorder
					if debuffBorder then
						debuffBorder:SetAlpha(0)
						if not aura.customBorderHook then
							hooksecurefunc(debuffBorder, "SetVertexColor", function(_, r, g, b)
								if C.aura.debuff_color_type then
									aura:SetBackdropBorderColor(r, g, b)
								else
									aura:SetBackdropBorderColor(1, 0, 0)
								end
							end)
							aura.customBorderHook = true
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
				end

				aura:ClearAllPoints()
				if left then
					if (index > 1) and (mod(index, rowbuffs) == 1) then
						aura:SetPoint("TOP", aboveBuff, "BOTTOM", 0, -space)
						aboveBuff = aura
					elseif index == 1 then
						aura:SetPoint("TOPLEFT", PrivateAnchor, "TOPLEFT", 0, 0)
						aboveBuff = aura
					else
						aura:SetPoint("LEFT", previousBuff, "RIGHT", space, 0)
					end
				else
					if (index > 1) and (mod(index, rowbuffs) == 1) then
						aura:SetPoint("TOP", aboveBuff, "BOTTOM", 0, -space)
						aboveBuff = aura
					elseif index == 1 then
						aura:SetPoint("TOPRIGHT", PrivateAnchor, "TOPRIGHT", 0, 0)
						aboveBuff = aura
					else
						aura:SetPoint("RIGHT", previousBuff, "LEFT", -space, 0)
					end
				end

				previousBuff = aura

				-- 仅对普通纹理类型的 Icon 应用裁切和图层设置
				if aura.Icon and aura.Icon.SetTexCoord then
					aura.Icon:CropIcon()
					if aura.Icon.SetDrawLayer then
						aura.Icon:SetDrawLayer("BORDER")
					end
				end

				-- 持续时间文本格式化（仅限 FontString 类型）
				local duration = aura.Duration
				if duration and duration.SetFont then
					duration:ClearAllPoints()
					duration:SetPoint("CENTER", 2, 1)
					duration:SetDrawLayer("ARTWORK")
					duration:SetFont(C.font.auras_font, C.font.auras_font_size, C.font.auras_font_style)
					duration:SetShadowOffset(C.font.auras_font_shadow and 1 or 0, C.font.auras_font_shadow and -1 or 0)
				end

				if aura.UpdateDuration and not aura.customDurationHook then
					hooksecurefunc(aura, "UpdateDuration", function(aura, timeLeft)
						UpdateDuration(aura, timeLeft)
					end)
					aura.customDurationHook = true
				end

				-- 堆叠层数文本格式化（仅限 FontString 类型）
				if aura.Count and aura.Count.SetFont then
					aura.Count:ClearAllPoints()
					aura.Count:SetPoint("BOTTOMRIGHT", 2, 0)
					aura.Count:SetDrawLayer("ARTWORK")
					aura.Count:SetFont(C.font.auras_font, C.font.auras_font_size, C.font.auras_font_style)
					aura.Count:SetShadowOffset(C.font.auras_font_shadow and 1 or 0, C.font.auras_font_shadow and -1 or 0)
				end
			end
		end)
	end

	-- 7. 登录与就绪时完成初始化绑定
	local initFrame = CreateFrame("Frame")
	initFrame:RegisterEvent("PLAYER_LOGIN")
	initFrame:SetScript("OnEvent", function(self)
		DisablePlayerFrameDebuffs()
		UpdateDebuffsAnchor()
		self:UnregisterAllEvents()
	end)
end

