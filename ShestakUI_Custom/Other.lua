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
-- 2. 安全版 T.HasPlayerBuff
-- 使用 12.1.0 官方公开安全的槽位检索接口，杜绝 GetAuraDataByIndex 触发 Secret Taint
----------------------------------------------------------------------------------------
T.HasPlayerBuff = function(spell)
	local slots = { UnitAuraSlots("player", "HELPFUL") }
	for _, slot in ipairs(slots) do
		local auraData = C_UnitAuras.GetAuraDataBySlot("player", slot)
		if auraData and auraData.name == spell then
			return true
		end
	end
	return nil
end




