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
	C.unitframe.show_player_power = false    -- 玩家框体不显示能量/法力数值
	C.unitframe.show_player_castbar = false  -- 玩家施法条开关（true 为显示，false 为隐藏）
end

-- 团队/小队框体配置：小队队友不显示能量数值，小队纵向间距设为 14（可自由调整）
if C.raidframe then
	C.raidframe.show_party_power = false
	C.raidframe.party_spacing = 14
	C.raidframe.dps_party_vertical_spacing = 14
end

-- 任务追踪配置：禁用插件美化，使用暴雪原生任务追踪模块
C.quest = C.quest or {}
C.quest.objective_tracker = false

