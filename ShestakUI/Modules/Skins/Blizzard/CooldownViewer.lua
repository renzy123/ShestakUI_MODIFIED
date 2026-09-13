local T, C, L = unpack(ShestakUI)
if C.skins.blizzard_frames ~= true then return end

----------------------------------------------------------------------------------------
--	Cooldown Viewer skin
----------------------------------------------------------------------------------------
local function LoadSkin()
	local frame = _G.CooldownViewerSettings
	T.SkinFrame(frame, true, -1, 0)

	local tabs = {
		frame.SpellsTab,
		frame.AurasTab,
		frame.GroupBuffsTab
	}
	for _, tab in pairs(tabs) do
		T.SkinFrameTab(tab)
	end

	T.SkinFrame(CooldownViewerLayoutDialog)
	CooldownViewerLayoutDialog.AcceptButton:SkinButton()
	CooldownViewerLayoutDialog.CancelButton:SkinButton()
	T.SkinEditBox(CooldownViewerLayoutDialog.LayoutNameEditBox)
	CooldownViewerLayoutDialog.LayoutNameEditBox.backdrop:SetOutside(nil, 2, -4)

	T.SkinEditBox(frame.SearchBox)
	frame.SearchBox.backdrop:SetOutside(nil, 2, -4)
	T.SkinScrollBar(frame.CooldownScroll.ScrollBar)
	frame.UndoButton:SkinButton()
	T.SkinDropDownBox(frame.LayoutDropdown)

	local oldAtlas = {
		Options_ListExpand_Right = 1,
		Options_ListExpand_Right_Expanded = 1
	}

	local function updateCollapse(texture, atlas)
		if not atlas or oldAtlas[atlas] then
			if not atlas or atlas == "Options_ListExpand_Right_Expanded" then
				texture:SetAtlas("Soulbinds_Collection_CategoryHeader_Collapse")
			else
				texture:SetAtlas("Soulbinds_Collection_CategoryHeader_Expand")
			end
		end
	end

	T.SkinScrollBar(frame.GroupBuffFilter.Scroll.ScrollBar)

	-- 使用弱引用侧表记录已美化的框架，绝不向暴雪原生对象直接注入字段，防止引发沙盒 Taint
	local skinnedHeaders = setmetatable({}, { __mode = "k" })
	local skinnedItems = setmetatable({}, { __mode = "k" })
	local skinnedFrames = setmetatable({}, { __mode = "k" })

	local function SkinHeaders(header)
		if header and not skinnedHeaders[header] then
			header:StripTextures()
			header:CreateBackdrop("Overlay")
			header.backdrop:SetPoint("TOPLEFT", 2, 0)
			header.backdrop:SetPoint("BOTTOMRIGHT", -2, -2)
			updateCollapse(header.Right)
			updateCollapse(header.HighlightRight)

			hooksecurefunc(header.Right, "SetAtlas", updateCollapse)
			hooksecurefunc(header.HighlightRight, "SetAtlas", updateCollapse)

			skinnedHeaders[header] = true
		end
	end

	local function SkinSettingItem(item)
		if not item or skinnedItems[item] then return end

		local icon = item.Icon
		if icon then
			local highlight = item.Highlight
			if highlight then
				highlight:SetColorTexture(1, 1, 1, 0.3)
				highlight:SetAllPoints(icon)
			end

			icon:SkinIcon()
		end

		local bar = item.Bar
		if bar then
			bar:SetStatusBarTexture(C.media.texture)

			for _, region in next, {bar:GetRegions()} do
				if region:IsObjectType("Texture") then
					local atlas = region:GetAtlas()

					if atlas == "UI-HUD-CoolDownManager-Bar" then
						region:SetPoint("TOPLEFT", 1, 0)
						region:SetPoint("BOTTOMLEFT", -1, 0)
					elseif atlas == "UI-HUD-CoolDownManager-Bar-BG" and not region.backdrop then
						region:SetAlpha(0)
						region:CreateBackdrop("Transparent")
					end
				end
			end
		end

		skinnedItems[item] = true
	end

	local function HandleSettingItemPool(self)
		for frame in self:EnumerateActive() do
			SkinSettingItem(frame)
		end
	end

	local hookedItemPools = {}
	local function RefreshContent(content)
		if not content then return end

		for _, child in next, {content:GetChildren()} do
			local header = child.Header
			if header and not header.IsSkinned then
				SkinHeaders(child.Header)
			end

			local itemPool = child.itemPool
			if itemPool and not hookedItemPools[itemPool] then
				hookedItemPools[itemPool] = true

				HandleSettingItemPool(itemPool)

				hooksecurefunc(itemPool, "Acquire", HandleSettingItemPool)
			end
		end
	end

	local function RefreshLayout()
		local CooldownViewer = _G.CooldownViewerSettings
		if not CooldownViewer or not CooldownViewer.CooldownScroll then return end

		local content = CooldownViewer.CooldownScroll.Content

		if content then
			RefreshContent(content)
		end

		local groupBuffFilter = CooldownViewer.GroupBuffFilter
		if groupBuffFilter and groupBuffFilter.Scroll then
			RefreshContent(groupBuffFilter.Scroll.Content)
		end
	end

	RefreshLayout()
	hooksecurefunc(frame, "RefreshLayout", RefreshLayout)

	-- Tracker
	local function UpdateTextContainer(container)
		local countText = container.Applications and container.Applications.Applications
		if countText then
			countText:SetFont(C.font.cooldown_timers_font, C.font.cooldown_timers_font_size, C.font.cooldown_timers_font_style)
			countText:SetShadowOffset(C.font.cooldown_timers_font_shadow and 1 or 0, C.font.cooldown_timers_font_shadow and -1 or 0)
		end

		local chargeText = container.ChargeCount and container.ChargeCount.Current
		if chargeText then
			chargeText:SetFont(C.font.cooldown_timers_font, C.font.cooldown_timers_font_size, C.font.cooldown_timers_font_style)
			chargeText:SetShadowOffset(C.font.cooldown_timers_font_shadow and 1 or 0, C.font.cooldown_timers_font_shadow and -1 or 0)
		end
	end

	local function UpdateTextBar(bar)
		if bar.Name then
			bar.Name:SetFont(C.font.filger_font, C.font.filger_font_size, C.font.filger_font_style)
			bar.Name:SetShadowOffset(C.font.filger_font_shadow and 1 or 0, C.font.filger_font_shadow and -1 or 0)
		end

		if bar.Duration then
			bar.Duration:SetFont(C.font.filger_font, C.font.filger_font_size, C.font.filger_font_style)
			bar.Duration:SetShadowOffset(C.font.filger_font_shadow and 1 or 0, C.font.filger_font_shadow and -1 or 0)
		end
	end

	local function SkinIcon(container, icon)
		UpdateTextContainer(container)
		icon:SkinIcon()

		if container.DebuffBorder then
			container.DebuffBorder:SetAlpha(0)
		end

		local _, mask, overlay = container:GetRegions()
		mask:Hide()
		overlay:Hide()

		local outOfRange = container.OutOfRange
		if outOfRange then
			outOfRange:SetColorTexture(0.8, 0.1, 0.1, 0.3)
		end
	end

	local function SkinBar(frame, bar)
		UpdateTextBar(bar)
		bar:SetStatusBarTexture(C.media.texture)

		if frame.DebuffBorder then
			frame.DebuffBorder:SetAlpha(0)
		end

		if frame.Icon then
			frame.Icon.Icon:ClearAllPoints()
			frame.Icon.Icon:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", -7, 0)
			frame.Icon.Icon:SetSize(26, 26)
			SkinIcon(frame.Icon, frame.Icon.Icon)
		end

		for _, region in next, {bar:GetRegions()} do
			if region:IsObjectType("Texture") then
				local atlas = region:GetAtlas()

				if atlas == "UI-HUD-CoolDownManager-Bar" then
					region:SetPoint("TOPLEFT", 1, 0)
					region:SetPoint("BOTTOMLEFT", -1, 0)
				elseif atlas == "UI-HUD-CoolDownManager-Bar-BG" and not region.backdrop then
					region:SetAlpha(0)
					region:CreateBackdrop("Transparent")
				end
			end
		end
	end

	local function SetTimerShown(self)
		if self.Cooldown then
			local text = self.Cooldown:GetRegions()
			text:SetFont(C.font.cooldown_timers_font, C.font.cooldown_timers_font_size, C.font.cooldown_timers_font_style)
			text:SetShadowOffset(C.font.cooldown_timers_font_shadow and 1 or 0, C.font.cooldown_timers_font_shadow and -1 or 0)
			text:ClearAllPoints()
			text:SetPoint("LEFT", -2, 0)
			text:SetPoint("RIGHT", 3, 0)
		end
	end

	local hookFunctions = {
		SetTimerShown = SetTimerShown
	}

	local function SkinItemFrame(frame)
		if not frame or skinnedFrames[frame] then return end
		skinnedFrames[frame] = true

		if frame.Cooldown then
			frame.Cooldown:SetSwipeTexture(C.media.blank)
			SetTimerShown(frame)
		end

		if frame.Bar then
			SkinBar(frame, frame.Bar)
		elseif frame.Icon then
			SkinIcon(frame, frame.Icon)
		end
	end

	local function AcquireItemFrame(frame)
		SkinItemFrame(frame)
	end

	local function HandleViewer(element)
		if not element or not element.itemFramePool then return end
		hooksecurefunc(element, "OnAcquireItemFrame", AcquireItemFrame)

		for frame in element.itemFramePool:EnumerateActive() do
			SkinItemFrame(frame)
		end
	end

	HandleViewer(_G.UtilityCooldownViewer)
	HandleViewer(_G.BuffBarCooldownViewer)
	HandleViewer(_G.BuffIconCooldownViewer)
	HandleViewer(_G.EssentialCooldownViewer)

	-- 防御性沙盒安全包装：
	-- 当暴雪在进出战斗（PLAYER_IN_COMBAT_CHANGED）释放 itemFrame 对象池时，
	-- 若由于外部执行环境受限导致 UnregisterAuraInstanceIDItemFrame 索引 forbidden table 报错，
	-- 此处使用 pcall 捕获异常，防止向用户弹窗阻断，并通过 TaintTracker 记录详细上下文日志供调试排查。
	if _G.CooldownViewerMixin and _G.CooldownViewerMixin.UnregisterAuraInstanceIDItemFrame then
		local origUnregister = _G.CooldownViewerMixin.UnregisterAuraInstanceIDItemFrame
		_G.CooldownViewerMixin.UnregisterAuraInstanceIDItemFrame = function(self, auraInstanceID, itemFrame)
			local ok, err = pcall(origUnregister, self, auraInstanceID, itemFrame)
			if not ok and T.LogTaint then
				T.LogTaint("CooldownViewer", err)
			end
		end
	end
end

T.SkinFuncs["Blizzard_CooldownViewer"] = LoadSkin