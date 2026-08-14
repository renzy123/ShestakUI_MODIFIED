local T, C, L = unpack(ShestakUI)
if not T or not C then return end

----------------------------------------------------------------------------------------
--	ShestakUI Custom: 配置覆盖与预设注入
----------------------------------------------------------------------------------------

-- 聊天框配置：关闭聊天时间戳
if C.chat then
	C.chat.time_stamp = false
end

-- 单位框体配置：开启头像并使用 3D 嵌入 (OVERLAY)
if C.unitframe then
	C.unitframe.portrait_enable = true
	C.unitframe.portrait_type = "OVERLAY"
	C.unitframe.show_player_power = false -- 玩家框体不显示能量/法力数值
end

-- 团队/小队框体配置：小队队友不显示能量数值，小队纵向间距设为 7
if C.raidframe then
	C.raidframe.show_party_power = false
	C.raidframe.party_spacing = 7
end
