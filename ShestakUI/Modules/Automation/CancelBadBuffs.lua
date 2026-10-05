local T, C, L = unpack(ShestakUI)
if C.automation.cancel_bad_buffs ~= true then return end

----------------------------------------------------------------------------------------
--	Auto cancel various buffs(by Unknown)
----------------------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("UNIT_AURA")
frame:SetScript("OnEvent", function(_, event, unit)
	if event == "UNIT_AURA" and unit == "player" and not InCombatLockdown() then
		local i = 1
		while true do
			local auraData = C_UnitAuras.GetBuffDataByIndex(unit, i)
			if not auraData then return end
			local name = auraData.name
			if name and T.BadBuffs[name] then
				CancelSpellByName(name)
				print("|cffffff00"..ACTION_SPELL_AURA_REMOVED.." ["..name.."].|r")
			end
			i = i + 1
		end
	end
end)