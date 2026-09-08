local T, C, L = unpack(ShestakUI)
if C.skins.ellesmere_damagemeters ~= true then return end

----------------------------------------------------------------------------------------
--	EllesmereUIDamageMeters 皮肤模块
--	参考 ShestakUI Details 皮肤设计，实现 1px 像素边框、平滑状态条材质与统一字体排版
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

	-- 5. 字体排版与阴影统一
	local font = C.media.normal_font
	local fontSize = 11
	local fontStyle = "OUTLINE"

	if bar.pos then
		bar.pos:SetFont(font, fontSize, fontStyle)
		bar.pos:SetShadowOffset(1, -1)
	end
	if bar.label then
		bar.label:SetFont(font, fontSize, fontStyle)
		bar.label:SetShadowOffset(1, -1)
	end
	if bar.amount then
		bar.amount:SetFont(font, fontSize, fontStyle)
		bar.amount:SetShadowOffset(1, -1)
	end
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

	-- 隐藏原生粗糙底色纹理
	if frame._bg then
		frame._bg:SetAlpha(0)
	end

	-- 2. 标题栏顶板美化（Overlay 风格）
	if header and not header.shestakHeader then
		local hBg = CreateFrame("Frame", nil, header)
		hBg:SetTemplate("Overlay")
		hBg:SetAllPoints(header)
		hBg:SetFrameLevel(header:GetFrameLevel() - 1)
		header.shestakHeader = hBg

		-- 隐藏原生纯色背景与底部边线
		if header._hdrBg then header._hdrBg:SetAlpha(0) end
		if header._bottomBorder then header._bottomBorder:Hide() end
	end

	-- 3. 标题栏文本与战斗计时
	if W.titleText then
		W.titleText:SetFont(C.media.normal_font, 12, "OUTLINE")
		W.titleText:SetShadowOffset(1, -1)
	end
	if W.timerText then
		W.timerText:SetFont(C.media.normal_font, 11, "OUTLINE")
		W.timerText:SetShadowOffset(1, -1)
	end

	-- 4. 批量美化已有行
	if W.bars then
		for _, bar in ipairs(W.bars) do
			SkinBar(bar)
		end
	end

	-- 5. 挂钩窗口刷新，确保数据更新、增量渲染时美化实时维持
	hooksecurefunc(W, "Refresh", function()
		if W.bars then
			for _, bar in ipairs(W.bars) do
				if bar.row and bar.row:IsShown() then
					SkinBar(bar)
				end
			end
		end
		if W.stickyPlayer and W.stickyPlayer.row and W.stickyPlayer.row:IsShown() then
			SkinBar(W.stickyPlayer)
		end
	end)
end

-- 美化悬停与技能明细二级弹窗（Tooltip / Breakdown Frame）
local function SkinBreakdownTooltip()
	local EUI = _G.EllesmereUI
	local edmNS = EUI and EUI._ModuleNS and EUI._ModuleNS["EllesmereUIDamageMeters"]
	if not edmNS then return end

	-- 轮询或在弹窗出现时挂钩
	local hookFrame = CreateFrame("Frame")
	hookFrame:SetScript("OnUpdate", function(self)
		-- 寻找内部悬停明细框体
		for k, v in pairs(edmNS) do
			if type(v) == "table" and v.GetObjectType and v:IsObjectType("Frame") then
				if not v._shestakSkinned and v._hdrText then
					v._shestakSkinned = true
					v:SetTemplate("Transparent")
					if v._bg then v._bg:SetAlpha(0) end
					if v._hdr and not v._hdr.shestakBg then
						local hBg = CreateFrame("Frame", nil, v._hdr)
						hBg:SetTemplate("Overlay")
						hBg:SetAllPoints(v._hdr)
						hBg:SetFrameLevel(v._hdr:GetFrameLevel() - 1)
						v._hdr.shestakBg = hBg
					end
					if v._hdrText then
						v._hdrText:SetFont(C.media.normal_font, 11, "OUTLINE")
					end
					self:SetScript("OnUpdate", nil)
					return
				end
			end
		end
	end)
end

-- 主初始化逻辑
local function Initialize()
	-- 1. 源头拦截 EllesmereUI 的材质解析，全面返回 ShestakUI 统一材质
	if _G.EllesmereUI and _G.EllesmereUI.ResolveTexturePath then
		if not _G.EllesmereUI._shestakDMTexturePatched then
			_G.EllesmereUI._shestakDMTexturePatched = true
			local origResolve = _G.EllesmereUI.ResolveTexturePath
			_G.EllesmereUI.ResolveTexturePath = function(tbl, key, fallback)
				-- 对伤害统计状态条材质强制统一为 ShestakUI 材质
				if tbl == _G._EDM_BarTextures or key == "shestak" then
					return C.media.texture
				end
				return origResolve(tbl, key, fallback)
			end
		end
	end

	-- 2. 扫描美化所有活跃窗口实例
	local EUI = _G.EllesmereUI
	local edmNS = EUI and EUI._ModuleNS and EUI._ModuleNS["EllesmereUIDamageMeters"]
	local windows = edmNS and edmNS._windows

	if windows then
		for _, W in ipairs(windows) do
			SkinWindow(W)
		end
	end

	-- 亦可通过全局命名的 frame 扫描（EllesmereUIDMFrame1 ~ EllesmereUIDMFrame5）
	for i = 1, 5 do
		local frame = _G["EllesmereUIDMFrame" .. i]
		if frame and not frame._shestakSkinned then
			-- 若有全局 frame 但尚未在 windows 中取到，等待其 W 初始化完成
			if windows and windows[i] then
				SkinWindow(windows[i])
			end
		end
	end

	-- 3. 美化二级悬停技能明细弹窗
	SkinBreakdownTooltip()
end

-- 模块加载入口
if C_AddOns.IsAddOnLoaded("EllesmereUIDamageMeters") then
	Initialize()
else
	local loader = CreateFrame("Frame")
	loader:RegisterEvent("ADDON_LOADED")
	loader:SetScript("OnEvent", function(self, event, addon)
		if addon == "EllesmereUIDamageMeters" then
			Initialize()
			self:UnregisterEvent("ADDON_LOADED")
		end
	end)
end
