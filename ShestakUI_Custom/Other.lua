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
-- 2. 任务追踪器 (ObjectiveTracker) 安全沙盒隔离补丁
-- 解决暴雪 12.1.0 下 ScenarioObjectiveTracker:LayoutContents 调用 ShouldShowMawBuffs
-- 触发 'GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by ShestakUI'
-- 导致整个任务列表卡死、进度无法刷新的问题。
----------------------------------------------------------------------------------------
local function WrapMawBuffs()
	_G.ShouldShowMawBuffs = function(...)
		-- 使用 pcall 安全捕获暴雪受限接口的机密调用异常
		local ok, val = pcall(GetAuraDataByIndex, "player", 1, "MAW")
		if ok then
			return val ~= nil
		end
		-- 若由于 Taint 环境被拦截，安全回退为 false，确保任务追踪器继续刷新后续任务列表
		return false
	end
end

-- 立即包装全局函数
WrapMawBuffs()

-- 监听可能动态加载的暴雪模块，确保包装始终生效
local trackerFixFrame = CreateFrame("Frame")
trackerFixFrame:RegisterEvent("ADDON_LOADED")
trackerFixFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
trackerFixFrame:SetScript("OnEvent", function(self, event, addon)
	if event == "PLAYER_ENTERING_WORLD" or addon == "Blizzard_MawBuffs" or addon == "Blizzard_ObjectiveTracker" then
		WrapMawBuffs()
	end
end)

