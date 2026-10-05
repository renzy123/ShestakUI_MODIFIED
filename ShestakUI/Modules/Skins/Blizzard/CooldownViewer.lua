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

	-- 使用弱引用表存储美化背景框，避免直接在暴雪原生 itemFrame 上写入 .backdrop 字段导致池对象沙盒受限污染
	local skinnedBackdrops = setmetatable({}, { __mode = "k" })

	local function SkinIcon(container, icon)
		UpdateTextContainer(container)

		-- 自定义背景：将背景框挂载到容器且只记录在弱引用表中，不侵入 container 原生属性
		if not skinnedBackdrops[container] then
			local b = CreateFrame("Frame", nil, container)
			b:SetOutside(icon)
			b:SetTemplate("Default")
			if container:GetFrameLevel() - 1 >= 0 then
				b:SetFrameLevel(container:GetFrameLevel() - 1)
			else
				b:SetFrameLevel(0)
			end
			skinnedBackdrops[container] = b
		end

		if icon.SetTexCoord then
			icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
		end

		if container.DebuffBorder then
			container.DebuffBorder:SetAlpha(0)
		end

		local _, mask, overlay = container:GetRegions()
		if mask then mask:Hide() end
		if overlay then overlay:Hide() end

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
				elseif atlas == "UI-HUD-CoolDownManager-Bar-BG" and not skinnedBackdrops[region] then
					region:SetAlpha(0)
					local b = CreateFrame("Frame", nil, bar)
					b:SetOutside(region)
					b:SetTemplate("Transparent")
					skinnedBackdrops[region] = b
				end
			end
		end
	end

	local function SetTimerShown(self)
		if self.Cooldown then
			local text = self.Cooldown:GetRegions()
			if text and text.SetFont then
				text:SetFont(C.font.cooldown_timers_font, C.font.cooldown_timers_font_size, C.font.cooldown_timers_font_style)
				text:SetShadowOffset(C.font.cooldown_timers_font_shadow and 1 or 0, C.font.cooldown_timers_font_shadow and -1 or 0)
				text:ClearAllPoints()
				text:SetPoint("LEFT", -2, 0)
				text:SetPoint("RIGHT", 3, 0)
			end
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

	local viewers = {
		_G.UtilityCooldownViewer,
		_G.BuffBarCooldownViewer,
		_G.BuffIconCooldownViewer,
		_G.EssentialCooldownViewer
	}

	for _, viewer in ipairs(viewers) do
		HandleViewer(viewer)
	end

	-- 防御性沙盒安全包装：
	-- 当暴雪在进出战斗、模式切换（如地下堡完成触发 UIModeManager/Roleset 变更）或光环更新（OnUnitAura / CheckAuraAddedAlertTriggers）时，
	-- 若外部执行上下文被污染，原生代码执行索引受限表（forbidden table：auraInstanceIDToItemFramesMap）会抛出阻断异常。
	-- 此处不仅 hook 全局 Mixin，还对已经实例化完成的各个具体 Viewer 对象进行全面的沙盒异常防护包装。
	local function ProtectViewerMethod(target, methodName)
		if not target or not target[methodName] then return end
		local origMethod = target[methodName]
		target[methodName] = function(self, ...)
			local ok, err = pcall(origMethod, self, ...)
			if not ok and T.LogTaint then
				T.LogTaint("CooldownViewer:"..methodName, err)
			end
		end
	end

	local targetMethods = {
		"UnregisterAuraInstanceIDItemFrame",
		"CheckAuraAddedAlertTriggers",
		"OnUnitAura"
	}

	if _G.CooldownViewerMixin then
		for _, method in ipairs(targetMethods) do
			ProtectViewerMethod(_G.CooldownViewerMixin, method)
		end
	end

	for _, viewer in ipairs(viewers) do
		for _, method in ipairs(targetMethods) do
			ProtectViewerMethod(viewer, method)
		end
	end
end

T.SkinFuncs["Blizzard_CooldownViewer"] = LoadSkin