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

