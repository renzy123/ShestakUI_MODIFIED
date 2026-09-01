local T, C, L = unpack(ShestakUI)
if C.skins.ellesmere_raidframes ~= true then return end

----------------------------------------------------------------------------------------
--	EllesmereUIRaidFrames 皮肤模块（纯事件驱动与 1px 像素边框美化，0 运行时 CPU 持续开销）
----------------------------------------------------------------------------------------

-- 统一为框架创建置顶的 1px 像素边框
local function CreateUnitBorder(frame)
	if not frame or frame.shestakBorder then return end

	local border = CreateFrame("Frame", nil, frame)
	border:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
	border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
	border:SetFrameLevel(frame:GetFrameLevel() + 20)
	border:SetTemplate("Default")
	frame.shestakBorder = border
end

-- 对单个 Ellesmere 团队/小队单元框体应用美化（一次性执行）
local function SkinRaidButton(button)
	if not button or button.shestakStyled then return end
	button.shestakStyled = true

	-- 1. 创建置顶 1px 像素边框
	CreateUnitBorder(button)

	-- 2. 状态条材质与背景注入
	local d = button._euiData
	if d then
		if d.health and d.health.SetStatusBarTexture then
			d.health:SetStatusBarTexture(C.media.texture)
		end
		if d.power and d.power.SetStatusBarTexture then
			d.power:SetStatusBarTexture(C.media.texture)
		end
		if d.absorbBar and d.absorbBar.SetStatusBarTexture then
			d.absorbBar:SetStatusBarTexture(C.media.texture)
		end
		if d.bg and d.bg.SetTexture then
			d.bg:SetTexture(C.media.texture)
		end
	end

	-- 3. 遍历子 StatusBar 替换材质
	local children = { button:GetChildren() }
	for _, child in ipairs(children) do
		if child:IsObjectType("StatusBar") then
			child:SetStatusBarTexture(C.media.texture)
		end
	end
end

-- 全局注入与 Hook 绑定（纯事件触发，无任何 OnUpdate 轮询开销）
local function InitEllesmereRaidSkin()
	local ns = (EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS["EllesmereUIRaidFrames"]) or _G.EllesmereUIRaidFrames_NS
	if not ns or ns._shestakSkinHooked then return end
	ns._shestakSkinHooked = true

	-- 1. 材质字典全局覆盖：确保原生每一次 ResolveHealthTexture 均返回 ShestakUI 材质
	if ns.healthBarTextures then
		for k in pairs(ns.healthBarTextures) do
			ns.healthBarTextures[k] = C.media.texture
		end
		ns.healthBarTextures["atrocity"] = C.media.texture
		ns.healthBarTextures["shestak"] = C.media.texture
	end

	-- 2. 拦截并 Hook 按钮样式化入口：在创建/重用框体的一瞬间自动美化，无需轮询
	if ns._StyleButtonSecure then
		hooksecurefunc(ns, "_StyleButtonSecure", function(button)
			SkinRaidButton(button)
		end)
	end

	-- 3. 对当前已存在的全部按钮立即执行一次初始化美化
	if ns._euiUnitButtons then
		for button in pairs(ns._euiUnitButtons) do
			SkinRaidButton(button)
		end
	end
end

-- 登录与模块加载事件监听
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
	if event == "ADDON_LOADED" then
		if addon == "EllesmereUIRaidFrames" or addon == "EllesmereUI" then
			InitEllesmereRaidSkin()
		end
	else
		InitEllesmereRaidSkin()
	end
end)


