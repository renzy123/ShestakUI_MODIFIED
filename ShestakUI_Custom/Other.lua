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

----------------------------------------------------------------------------------------
-- 3. 冷却框架 (CooldownFrame_Set) 机密值 (Secret Number) 安全绕行防护补丁
-- 解决暴雪 12.1.0 下 Cooldown.lua:3 对 secret number 类型的 start/duration 执行比较 (start > 0)
-- 触发 'attempt to compare local start (a secret number value)' 致命错误的问题。
----------------------------------------------------------------------------------------
local function WrapCooldownFrameSet()
	if not _G.CooldownFrame_Set or _G.CooldownFrame_Set.__shestak_custom_wrapped then return end

	local origCooldownFrame_Set = _G.CooldownFrame_Set
	_G.CooldownFrame_Set = function(self, start, duration, enable, forceShowDrawEdge, modRate)
		if not self or self:IsForbidden() then return end

		-- 若 start 或 duration 是机密数字 (Secret Number)，跳过 Lua 层的数值比较，直接安全调用底层 C 接口
		if issecretvalue(start) or issecretvalue(duration) then
			pcall(self.SetCooldown, self, start, duration, modRate)
			if forceShowDrawEdge ~= nil and self.SetDrawEdge then
				pcall(self.SetDrawEdge, self, forceShowDrawEdge)
			end
			self:Show()
			return
		end

		return origCooldownFrame_Set(self, start, duration, enable, forceShowDrawEdge, modRate)
	end
	_G.CooldownFrame_Set.__shestak_custom_wrapped = true
end

WrapCooldownFrameSet()

local cooldownFixFrame = CreateFrame("Frame")
cooldownFixFrame:RegisterEvent("ADDON_LOADED")
cooldownFixFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
cooldownFixFrame:SetScript("OnEvent", function(self, event, addon)
	WrapCooldownFrameSet()
end)


