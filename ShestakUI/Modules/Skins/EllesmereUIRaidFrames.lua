local T, C, L = unpack(ShestakUI)
if C.skins.ellesmere_raidframes ~= true then return end

----------------------------------------------------------------------------------------
--	EllesmereUIRaidFrames 皮肤模块（实现 ShestakUI 1px 像素边框、暗色背景与材质统一）
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

-- 美化单颗 Aura / Debuff 图标
local function SkinAuraIcon(iconFrame)
	if not iconFrame or iconFrame.shestakStyled then return end
	iconFrame.shestakStyled = true

	local icon = iconFrame.icon or iconFrame.Icon or iconFrame.texture
	if icon and icon.SetTexCoord then
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	CreateUnitBorder(iconFrame)
end

-- 对单个 Ellesmere 团队/小队单元框体应用美化
local function SkinRaidButton(button)
	if not button then return end

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

	-- 3. 子 StatusBar 材质全量替换
	local children = { button:GetChildren() }
	for _, child in ipairs(children) do
		if child:IsObjectType("StatusBar") then
			child:SetStatusBarTexture(C.media.texture)
		end
	end
end

-- 全局注入与扫描
local function SkinEllesmereRaidFrames()
	local ns = (EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS["EllesmereUIRaidFrames"]) or _G.EllesmereUIRaidFrames_NS
	if not ns then return end

	-- 1. 材质字典全量重写：使 Ellesmere 内部每次 UpdateButton / ResolveHealthTexture 均返回 ShestakUI 材质
	if ns.healthBarTextures then
		for k in pairs(ns.healthBarTextures) do
			ns.healthBarTextures[k] = C.media.texture
		end
		ns.healthBarTextures["atrocity"] = C.media.texture
		ns.healthBarTextures["shestak"] = C.media.texture
	end

	-- 2. 遍历美化所有已注册的单元按钮
	if ns._euiUnitButtons then
		for button in pairs(ns._euiUnitButtons) do
			SkinRaidButton(button)
		end
	end
end

-- 周期轮询检查当前活动的团队框体实例（覆盖战斗外动态生成的框体）
local function onUpdate(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed < 0.2 then return end
	self.elapsed = 0

	SkinEllesmereRaidFrames()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
	if event == "ADDON_LOADED" then
		if addon == "EllesmereUIRaidFrames" or addon == "EllesmereUI" then
			SkinEllesmereRaidFrames()
		end
	else
		SkinEllesmereRaidFrames()
		self:SetScript("OnUpdate", onUpdate)
	end
end)

