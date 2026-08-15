local T, C, L = unpack(ShestakUI)
if not T or not C or C.raidframe.enable ~= true then return end

local _, ns = ...
local oUF = ShestakUI[2].oUF or ns.oUF or oUF

----------------------------------------------------------------------------------------
--	ShestakUI Custom: 小队与团队框体样式优化
----------------------------------------------------------------------------------------

local function CustomStyleRaidFrame(self, unit)
	if not self then return end

	-- 针对小队队友框体：隐藏 Debuff 图标与能量数值文本
	local name = self:GetName() or ""
	if name:match("oUF_PartyDPS") or (unit and unit:match("^party%d?$")) then
		if self.Debuffs then
			self.Debuffs:Hide()
			self.Debuffs.Show = function() end -- 阻止再次被 oUF 自动显示
		end

		if self.Power then
			self.Power.PostUpdate = T.PostUpdatePower
			if C.raidframe.show_party_power ~= true then
				if self.Power.value then self.Power.value:SetText("") end
				if self.Power.short_value then self.Power.short_value:SetText("") end
			end
		end
	end
end

-- 注册到 oUF 初始化回调
if oUF and oUF.RegisterInitCallback then
	oUF:RegisterInitCallback(CustomStyleRaidFrame)
end

-- 登录后对已存在的小队成员框体执行一次安全隐藏与绑定
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
	for i = 1, 5 do
		local f = _G["oUF_PartyDPSUnitButton" .. i]
		if f then
			CustomStyleRaidFrame(f, "party" .. i)
		end
	end
end)
