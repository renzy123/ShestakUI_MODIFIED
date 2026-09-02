local T, C, L = unpack(ShestakUI)
if C.skins.ellesmere_raidframes ~= true then return end

----------------------------------------------------------------------------------------
--	EllesmereUIRaidFrames 皮肤模块
--	实现 ShestakUI 标志性 1px 黑色像素边框、暗色背景与材质全局统一
----------------------------------------------------------------------------------------

-- 统一为框架创建置顶的 1px 像素边框（透明背景，仅保留黑色 1px 边框）
local function CreateUnitBorder(frame)
	if not frame or frame.shestakBorder then return end

	local border = CreateFrame("Frame", nil, frame)
	border:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
	border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
	border:SetFrameLevel(frame:GetFrameLevel() + 25)
	border:SetTemplate("Default")
	-- 将边框内部底色置为透明，避免遮挡框架本身的血量渲染
	border:SetBackdropColor(0, 0, 0, 0)
	frame.shestakBorder = border
end

-- 对单个 Ellesmere 团队/小队单元框体应用美化
local function SkinRaidButton(button)
	if not button then return end

	-- 1. 创建置顶 1px 像素边框
	CreateUnitBorder(button)

	-- 2. 状态条材质与背景强制注入
	local function UpdateBarTextures()
		local children = { button:GetChildren() }
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

	UpdateBarTextures()

	-- 首次美化标记与显示钩子绑定
	if not button.shestakStyled then
		button.shestakStyled = true
		button:HookScript("OnShow", UpdateBarTextures)
	end
end

-- 扫描并美化指定 Header 下的所有子单元按钮
local function ScanHeaderButtons(header)
	if not header then return 0 end
	local count = 0

	-- 遍历数字索引按钮（如 header[1], header[2]...）
	for i = 1, 40 do
		local btn = header[i] or _G[header:GetName() and (header:GetName() .. "UnitButton" .. i)]
		if btn then
			SkinRaidButton(btn)
			count = count + 1
		end
	end

	-- 遍历直接子子节点按钮
	local children = { header:GetChildren() }
	for _, child in ipairs(children) do
		if child:IsObjectType("Button") then
			SkinRaidButton(child)
			count = count + 1
		end
	end

	return count
end

-- 全局扫描与材质拦截总入口
local function ApplyEllesmereSkin()
	-- 1. 全局材质解析函数拦截：强制使 Ellesmere 所有模块返回 ShestakUI 材质
	if _G.EllesmereUI and _G.EllesmereUI.ResolveTexturePath then
		if not _G.EllesmereUI._shestakPatched then
			_G.EllesmereUI._shestakPatched = true
			local origResolve = _G.EllesmereUI.ResolveTexturePath
			_G.EllesmereUI.ResolveTexturePath = function(tbl, key, fallback)
				return C.media.texture
			end
		end
	end

	-- 2. 遍历所有已知 Ellesmere Raid Headers
	local totalStyled = 0
	local headers = {
		_G["ERFPartyHeader"],
		_G["ERFFlatHeader"],
		_G["ERFPreviewFrame"],
	}
	for g = 1, 8 do
		table.insert(headers, _G["ERFGroupHeader" .. g])
	end

	for _, hdr in ipairs(headers) do
		if hdr then
			-- 对 Header 绑定 OnShow，在组队/展开时即时美化
			if not hdr._shestakHooked then
				hdr._shestakHooked = true
				hdr:HookScript("OnShow", function(self)
					ScanHeaderButtons(self)
				end)
			end
			totalStyled = totalStyled + ScanHeaderButtons(hdr)
		end
	end

	-- 3. 额外遍历友方 Boss 框体
	for i = 1, 5 do
		local bossBtn = _G["ERFFriendlyBoss" .. i]
		if bossBtn then
			SkinRaidButton(bossBtn)
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

	-- 延迟执行一次全量扫描，兼容 Ellesmere 的异步队列加载
	C_Timer.After(0.2, function()
		local count = ApplyEllesmereSkin()
		-- 关键位置 DEBUG 日志，方便用户在聊天框验证是否触发
		if count > 0 and not f.logged then
			f.logged = true
			print("|cff00ff00ShestakUI:|r EllesmereUIRaidFrames 美化模块已生效，已美化 " .. count .. " 个单元框体。")
		end
	end)
end)



