local T, C, L = unpack(ShestakUI)

----------------------------------------------------------------------------------------
--	EllesmereUIDamageMeters 皮肤模块
--	参考 ShestakUI Details 皮肤规范，实现 1px 像素边框、平滑状态条材质与统一字体排版
----------------------------------------------------------------------------------------

-- 美化单个状态条（参考 DetailsBarra 的 backdrop 与 bg 逻辑）
local function SkinBar(bar)
	if not bar or not bar.row or not bar.fill then return end

	-- 1. 强制统一状态条平滑材质
	bar.fill:SetStatusBarTexture(C.media.texture)
	local barTex = bar.fill:GetStatusBarTexture()
	if barTex then
		barTex:SetTexture(C.media.texture)
	end

	-- 2. 隐藏 Ellesmere 原生可能自带的边框，避免视觉重叠冲突
	if bar._borderFrame then bar._borderFrame:Hide() end
	if bar._fillBorder then bar._fillBorder:Hide() end
	if bar._iconBorderFrame then bar._iconBorderFrame:Hide() end
	if bar._bg then bar._bg:SetAlpha(0) end

	-- 挂钩原生边框刷新函数，防止原生逻辑在刷新时重新显示旧边框
	-- 注意：原生以 bar.ApplyBorder() 形式调用，不携带 self 参数，此处必须直接使用闭包捕获的 bar 实例
	if not bar._shestakHooked then
		bar._shestakHooked = true
		if bar.ApplyBorder then
			hooksecurefunc(bar, "ApplyBorder", function()
				if bar._borderFrame then bar._borderFrame:Hide() end
				if bar._fillBorder then bar._fillBorder:Hide() end
			end)
		end
		if bar.ApplyIconBorder then
			hooksecurefunc(bar, "ApplyIconBorder", function()
				if bar._iconBorderFrame then bar._iconBorderFrame:Hide() end
			end)
		end
		if bar.ApplyBg then
			hooksecurefunc(bar, "ApplyBg", function()
				if bar._bg then bar._bg:SetAlpha(0) end
			end)
		end
	end

	-- 3. 创建 ShestakUI 统一槽位背景底色（暗色半透明底槽）
	if not bar.shestakBg then
		bar.shestakBg = bar.row:CreateTexture(nil, "BACKGROUND", nil, -7)
		bar.shestakBg:SetAllPoints(bar.fill)
		bar.shestakBg:SetTexture(C.media.texture)
		bar.shestakBg:SetVertexColor(0.08, 0.08, 0.08, 0.6)
	end

	-- 4. 创建 ShestakUI 标准 1px 像素边框（包含图标与状态条的整体包裹）
	if not bar.shestakBackdrop then
		local backdrop = CreateFrame("Frame", nil, bar.row)
		backdrop:SetTemplate("Default")
		backdrop:SetBackdropColor(0, 0, 0, 0) -- 内部完全透明，由 fill 和 shestakBg 填充
		backdrop:SetFrameLevel(bar.row:GetFrameLevel() + 1)
		bar.shestakBackdrop = backdrop
	end

	-- 根据专精/职业图标的显示状态动态调整外边框包裹范围
	local icon = bar.classIcon
	bar.shestakBackdrop:ClearAllPoints()
	if icon and icon:IsShown() then
		-- 图标边缘裁剪（去黑边与圆边）
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		bar.shestakBackdrop:SetPoint("TOPLEFT", icon, -2, 2)
		bar.shestakBackdrop:SetPoint("BOTTOMRIGHT", bar.fill, 2, -2)
	else
		bar.shestakBackdrop:SetPoint("TOPLEFT", bar.fill, -2, 2)
		bar.shestakBackdrop:SetPoint("BOTTOMRIGHT", bar.fill, 2, -2)
	end

	-- 5. 字体大小设为 8px，保持原本字体与渲染不作改变，并维持左右 2px 内间距
	local function SetFontSize8(fs)
		if not fs or not fs.GetFont then return end
		local fontPath, _, flags = fs:GetFont()
		if fontPath then
			fs:SetFont(fontPath, 8, flags)
		end
	end

	local function ApplyShestakTextOffsets()
		if bar.pos then
			bar.pos:ClearAllPoints()
			bar.pos:SetPoint("LEFT", bar.fill, "LEFT", 2, 0)
			SetFontSize8(bar.pos)
		end
		if bar.amount then
			bar.amount:ClearAllPoints()
			bar.amount:SetPoint("RIGHT", bar.fill, "RIGHT", -2, 0)
			SetFontSize8(bar.amount)
		end
		if bar.label then
			bar.label:ClearAllPoints()
			if bar.pos and bar.pos:GetText() and bar.pos:GetText() ~= "" then
				bar.label:SetPoint("LEFT", bar.pos, "RIGHT", 2, 0)
			else
				bar.label:SetPoint("LEFT", bar.fill, "LEFT", 2, 0)
			end
			if bar.amount then
				bar.label:SetPoint("RIGHT", bar.amount, "LEFT", -2, 0)
			else
				bar.label:SetPoint("RIGHT", bar.fill, "RIGHT", -2, 0)
			end
			SetFontSize8(bar.label)
		end
	end

	-- 覆盖原生的文本偏移逻辑，确保原生代码在调用 ApplyTextOffsets 时维持左右各 2px 内间距及 8px 字号
	bar.ApplyTextOffsets = ApplyShestakTextOffsets
	ApplyShestakTextOffsets()
end

-- 美化单个伤害统计窗口（支持最多 5 个多实例窗口）
local function SkinWindow(W)
	if not W or not W.frame or W._shestakSkinned then return end
	W._shestakSkinned = true

	local frame = W.frame
	local header = W.header

	-- 1. 主窗口外边框与半透明暗底
	if not frame.backdrop then
		frame:CreateBackdrop("Transparent")
		if frame.backdrop then
			frame.backdrop:ClearAllPoints()
			frame.backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
			frame.backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
		end
	end

	-- 隐藏原生粗糙底色纹理与原生外边框目标
	if frame._bg then
		frame._bg:SetAlpha(0)
	end
	if W.windowBorderTarget then
		W.windowBorderTarget:Hide()
	end

	-- 2. 标题栏顶板美化（Overlay 风格）与底部边框美化
	if header then
		if not header.shestakHeader then
			local hBg = CreateFrame("Frame", nil, header)
			hBg:SetTemplate("Overlay")
			hBg:SetAllPoints(header)
			hBg:SetFrameLevel(header:GetFrameLevel() - 1)
			header.shestakHeader = hBg

			-- 隐藏原生纯色背景
			if header._hdrBg then header._hdrBg:SetAlpha(0) end
		end

		-- 标题栏底部边框美化：创建 ShestakUI 标准 1px 黑色像素分界线，完美对接主窗口外边框
		if not header.shestakBottomBorder then
			local bBorder = header:CreateTexture(nil, "OVERLAY", nil, 7)
			bBorder:SetTexture(C.media.blank)
			bBorder:SetVertexColor(unpack(C.media.border_color))
			bBorder:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", -2, 0)
			bBorder:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 2, 0)
			bBorder:SetHeight(T.mult or 1)
			header.shestakBottomBorder = bBorder
		end
		header.shestakBottomBorder:Show()

		-- 隐藏原生粗糙的底部边线，避免样式冲突与粗细不均
		if header._bottomBorder then
			header._bottomBorder:SetAlpha(0)
		end
	end

	-- 3. 标题栏文本（10px）与图标大小（12px）调整，其他不做额外改变
	local function ApplyHeaderStyling()
		if W.titleText and W.titleText.GetFont then
			local font, _, flags = W.titleText:GetFont()
			if font then
				W.titleText:SetFont(font, 10, flags)
			end
		end
		if W.timerText and W.timerText.GetFont then
			local font, _, flags = W.timerText:GetFont()
			if font then
				W.timerText:SetFont(font, 10, flags)
			end
		end

		local iconSz = 12
		local btnPad = 2
		if W.hdrBtns then
			local bi = 0
			for _, btn in ipairs(W.hdrBtns) do
				if btn:IsShown() then
					bi = bi + 1
					btn:SetSize(iconSz, iconSz)
					btn:ClearAllPoints()
					btn:SetPoint("RIGHT", W.header, "RIGHT", -(iconSz * (bi - 1) + btnPad * bi + 2), 0)
				end
			end
		end
		if W.hdrIcons then
			for _, icon in ipairs(W.hdrIcons) do
				icon:SetSize(iconSz, iconSz)
			end
		end
		if W._closeIconTex then
			W._closeIconTex:SetSize(iconSz, iconSz)
		end
		if W.FitTitle then
			W.FitTitle()
		end
	end

	ApplyHeaderStyling()
	W.ApplyHeaderStyling = ApplyHeaderStyling

	-- 4. 批量美化已有行池（主窗口 rowPool 和 技能池 spellPool）
	if W.rowPool then
		for _, bar in ipairs(W.rowPool) do
			SkinBar(bar)
		end
	end
	if W.spellPool then
		for _, bar in ipairs(W.spellPool) do
			SkinBar(bar)
		end
	end
	if W.stickyPlayer then
		SkinBar(W.stickyPlayer)
	end

	-- 5. 挂钩窗口刷新，确保数据更新、增量渲染时美化实时维持
	if W.Refresh then
		hooksecurefunc(W, "Refresh", function()
			ApplyHeaderStyling()
			if W.rowPool then
				for _, bar in ipairs(W.rowPool) do
					if bar.row and bar.row:IsShown() then
						SkinBar(bar)
						if bar.ApplyTextOffsets then
							bar.ApplyTextOffsets()
						end
					end
				end
			end
			if W.spellPool then
				for _, bar in ipairs(W.spellPool) do
					if bar.row and bar.row:IsShown() then
						SkinBar(bar)
						if bar.ApplyTextOffsets then
							bar.ApplyTextOffsets()
						end
					end
				end
			end
			if W.stickyPlayer and W.stickyPlayer.row and W.stickyPlayer.row:IsShown() then
				SkinBar(W.stickyPlayer)
				if W.stickyPlayer.ApplyTextOffsets then
					W.stickyPlayer.ApplyTextOffsets()
				end
			end
		end)
	end
end

-- 全局材质源头拦截：使状态条平滑材质生效，字体不做改动保持原生
local function HookGlobalMedia()
	local EUI = _G.EllesmereUI
	if not EUI then return end

	-- 材质解析源头替换
	if EUI.ResolveTexturePath and not EUI._shestakDMPatched then
		EUI._shestakDMPatched = true
		local origResolve = EUI.ResolveTexturePath
		EUI.ResolveTexturePath = function(tbl, key, fallback)
			-- 将伤害统计条材质替换为 ShestakUI 平滑纹理
			return C.media.texture
		end
	end
end

-- 主执行逻辑：扫描美化所有活跃窗口实例
local function ApplyEllesmereDMSkin()
	-- 延迟判断配置开关，若配置中显式设为 false 则跳过
	if C.skins and C.skins.ellesmere_damagemeters == false then return 0 end

	-- 1. 拦截底层 Media 解析
	HookGlobalMedia()

	local skinnedCount = 0
	local EUI = _G.EllesmereUI
	local edmNS = EUI and EUI._ModuleNS and EUI._ModuleNS["EllesmereUIDamageMeters"]
	local windows = edmNS and edmNS._windows

	-- 2. 通过 internal _windows 表扫描
	if windows then
		for _, W in ipairs(windows) do
			if W and W.frame and not W._shestakSkinned then
				SkinWindow(W)
				skinnedCount = skinnedCount + 1
			end
		end
	end

	-- 3. 通过全局 Frame 对象 EllesmereUIDMFrame1 ~ EllesmereUIDMFrame5 兜底扫描
	for i = 1, 5 do
		local frame = _G["EllesmereUIDMFrame" .. i]
		if frame and not frame._shestakSkinned then
			-- 尝试在 windows 中匹配对应的窗口逻辑对象 W
			local targetW = windows and windows[i]
			if targetW then
				SkinWindow(targetW)
				skinnedCount = skinnedCount + 1
			else
				-- 独立美化原生 frame 外观
				frame._shestakSkinned = true
				frame:CreateBackdrop("Transparent")
				if frame.backdrop then
					frame.backdrop:ClearAllPoints()
					frame.backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
					frame.backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
				end
				if frame._bg then frame._bg:SetAlpha(0) end
				skinnedCount = skinnedCount + 1
			end
		end
	end

	return skinnedCount
end

-- 模块事件加载与异步轮询监控
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ADDON_LOADED")

f:SetScript("OnEvent", function(self, event, addon)
	if event == "ADDON_LOADED" and addon ~= "EllesmereUIDamageMeters" and addon ~= "EllesmereUI" then
		return
	end

	-- 延迟 0.2 秒执行，确保 EllesmereUI 异步窗口初始化已完成
	C_Timer.After(0.2, function()
		local count = ApplyEllesmereDMSkin()
		if count > 0 and not f.logged then
			f.logged = true
			print("|cff00ff00ShestakUI:|r EllesmereUIDamageMeters 伤害统计美化模块已激活，已适配 " .. count .. " 个窗口。")
		end
	end)
end)

-- 轻量轮询检测（持续 10 秒，每秒检测 1 次，确保异步延迟创建的窗口全量捕获）
local tickerCount = 0
C_Timer.NewTicker(1.0, function(self)
	tickerCount = tickerCount + 1
	local count = ApplyEllesmereDMSkin()
	if count > 0 and not f.logged then
		f.logged = true
		print("|cff00ff00ShestakUI:|r EllesmereUIDamageMeters 伤害统计美化模块已激活，已适配 " .. count .. " 个窗口。")
	end
	if tickerCount >= 10 then
		self:Cancel()
	end
end)
