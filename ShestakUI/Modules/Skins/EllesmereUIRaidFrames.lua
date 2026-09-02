local T, C, L = unpack(ShestakUI)
if C.skins.ellesmere_raidframes ~= true then return end

----------------------------------------------------------------------------------------
--	EllesmereUIRaidFrames 皮肤模块
--	深度适配 EllesmereUI 主插件体系及其 RaidFrames 模组
--	实现 ShestakUI 1px 黑色像素边框、暗色背景与状态条材质统一
----------------------------------------------------------------------------------------

-- 为指定框体创建 ShestakUI 标准 1px 置顶边框（避免覆盖内部血条）
local function CreateUnitBorder(frame)
	if not frame or frame.shestakBorder then return end

	local border = CreateFrame("Frame", nil, frame)
	border:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
	border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
	border:SetFrameLevel(frame:GetFrameLevel() + 25)
	border:SetTemplate("Default")
	-- 将边框内部底色置为透明，避免遮挡内部血条渲染
	border:SetBackdropColor(0, 0, 0, 0)
	frame.shestakBorder = border
end

-- 对单个单元框体/预览框体注入 ShestakUI 材质与边框
local function SkinFrame(frame)
	if not frame then return end

	-- 1. 创建置顶 1px 像素边框
	CreateUnitBorder(frame)

	-- 2. 遍历子对象状态条强制替换为 ShestakUI flat 材质
	local function UpdateBars()
		local children = { frame:GetChildren() }
		for _, child in ipairs(children) do
			if child:IsObjectType("StatusBar") then
				child:SetStatusBarTexture(C.media.texture)
				local barTex = child:GetStatusBarTexture()
				if barTex then
					barTex:SetTexture(C.media.texture)
				end
			end
		end
	end

	UpdateBars()

	-- 绑定显示监听，确保界面重载/切换队伍时材质持续维持
	if not frame.shestakStyled then
		frame.shestakStyled = true
		frame:HookScript("OnShow", UpdateBars)
	end
end

-- 扫描并美化 Header 下的所有单元按钮
local function ScanHeaderButtons(header)
	if not header then return 0 end
	local count = 0

	-- 遍历数字索引按钮（header[1]..header[40]）
	for i = 1, 40 do
		local btn = header[i] or _G[header:GetName() and (header:GetName() .. "UnitButton" .. i)]
		if btn then
			SkinFrame(btn)
			count = count + 1
		end
	end

	-- 遍历直接子对象
	local children = { header:GetChildren() }
	for _, child in ipairs(children) do
		if child:IsObjectType("Button") or child:IsObjectType("Frame") then
			SkinFrame(child)
			count = count + 1
		end
	end

	return count
end

-- 主执行逻辑：全局材质拦截与全量容器扫描
local function ApplyEllesmereSkin()
	-- 1. 全局材质源头拦截：使 EllesmereUI 所有模块在解析材质时均返回 ShestakUI 纹理
	if _G.EllesmereUI and _G.EllesmereUI.ResolveTexturePath then
		if not _G.EllesmereUI._shestakPatched then
			_G.EllesmereUI._shestakPatched = true
			_G.EllesmereUI.ResolveTexturePath = function(tbl, key, fallback)
				return C.media.texture
			end
		end
	end

	-- 2. 扫描并美化所有已知 Header 与容器（涵盖小队、团队、平铺及预览容器）
	local totalStyled = 0
	local headers = {
		_G["ERFPartyHeader"],
		_G["ERFFlatHeader"],
		_G["ERFPreviewFrame"],
		_G["EllesmereUIRaidFrameContainer"],
	}
	for g = 1, 8 do
		table.insert(headers, _G["ERFGroupHeader" .. g])
	end

	for _, hdr in ipairs(headers) do
		if hdr then
			if not hdr._shestakHooked then
				hdr._shestakHooked = true
				hdr:HookScript("OnShow", function(self)
					ScanHeaderButtons(self)
				end)
			end
			totalStyled = totalStyled + ScanHeaderButtons(hdr)
		end
	end

	-- 3. 扫描友方 Boss 框体
	for i = 1, 5 do
		local bossBtn = _G["ERFFriendlyBoss" .. i]
		if bossBtn then
			SkinFrame(bossBtn)
			totalStyled = totalStyled + 1
		end
	end

	return totalStyled
end

-- 事件监听与生命周期初始化
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
	if event == "ADDON_LOADED" and addon ~= "EllesmereUIRaidFrames" and addon ~= "EllesmereUI" then
		return
	end

	-- 延迟执行全量扫描，兼容 EllesmereUI 模组异步初始化
	C_Timer.After(0.3, function()
		local count = ApplyEllesmereSkin()
		if count > 0 and not f.logged then
			f.logged = true
			print("|cff00ff00ShestakUI:|r EllesmereUI 团队框体模组已检测并美化，已适配 " .. count .. " 个单元框体。")
		end
	end)
end)

-- 登录后轻量轮询检测（持续 10 秒，每秒检测 1 次，确保延迟加载的模组框体被捕获）
local tickerCount = 0
C_Timer.NewTicker(1.0, function(self)
	tickerCount = tickerCount + 1
	local count = ApplyEllesmereSkin()
	if count > 0 and not f.logged then
		f.logged = true
		print("|cff00ff00ShestakUI:|r EllesmereUI 团队框体模组已检测并美化，已适配 " .. count .. " 个单元框体。")
	end
	if tickerCount >= 10 then
		self:Cancel()
	end
end)

