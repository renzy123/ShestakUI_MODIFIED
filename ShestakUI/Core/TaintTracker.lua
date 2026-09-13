local T, C, L = unpack(ShestakUI)

----------------------------------------------------------------------------------------
--	ShestakUI Taint & Error Diagnostic Tracker (污染与沙盒错误捕获追踪系统)
--	用于捕捉、诊断暴雪安全沙盒被 ShestakUI 污染导致的报错，提供清晰的根因追踪与调试信息。
----------------------------------------------------------------------------------------

-- 全局日志存储表
T.TaintLogs = T.TaintLogs or {}
local MAX_LOGS = 30

-- 常见暴雪受保护系统与 ShestakUI 模块的知识关联库
local TAINT_DIAGNOSTIC_MAP = {
	["CooldownViewer"] = {
		module = "ShestakUI/Modules/Skins/Blizzard/CooldownViewer.lua",
		desc = "技能冷却管理器（CooldownViewer）沙盒保护。常见原因为向 itemFrame 写入自定义字段或在 RefreshLayout 释放池对象时触发 forbidden table 访问。"
	},
	["SharedMapPoiTemplates"] = {
		module = "ShestakUI/Modules/Maps/WorldMap.lua 或 MoveBlizzFrames.lua",
		desc = "世界地图标记点（SharedMapPoiPinMixin）调用 SetPropagateMouseClicks 遭拦截。常见原因为对地图或子元素设置了移动/鼠标脚本产生 Taint。"
	},
	["WorldMap"] = {
		module = "ShestakUI/Modules/Maps/WorldMap.lua",
		desc = "世界地图框架操作。常见原因为在 SynchronizeDisplayState 或战斗中直接调用 ClearAllPoints/SetPoint。"
	},
	["FlightPoint"] = {
		module = "ShestakUI/Modules/Maps/WorldMap.lua",
		desc = "飞行点标记刷新。与 SharedMapPoiTemplates 相关联，受地图 Pin 池污染影响。"
	},
	["BuffFrame"] = {
		module = "ShestakUI/Modules/Auras/BuffFrame.lua 或 ShestakUI_Custom/Other.lua",
		desc = "光环系统更新。常见原因为对私有光环占位锚点（PrivateAuraAnchor）执行了纹理裁切或边框设置。"
	},
	["DebuffFrame"] = {
		module = "ShestakUI_Custom/Other.lua 或 BuffFrame.lua",
		desc = "减益光环容器排版。常见原因为 UpdateGridLayout 中对非安全槽位进行锚点篡改或 Show/Hide 触发保护。"
	},
	["EditMode"] = {
		module = "ShestakUI/Core/Movers.lua 或各模块锚点联动",
		desc = "暴雪编辑模式（EditMode）系统设置。常见原因为在未退出编辑模式或非安全路径下写入了布局属性。"
	},
	["UIWidget"] = {
		module = "ShestakUI/Modules/Blizzard/UIWidget.lua 或 Tooltip",
		desc = "UIWidget 文本状态组件。常见原因为 Tooltip 钩子在 Widget 渲染期间修改了文本高度导致秘密数值（secret value）计算异常。"
	}
}

-- 格式化时间戳
local function GetTimestamp()
	return date("%H:%M:%S")
end

-- 智能分析报错归属
local function DiagnoseError(errMsg, stack)
	local matchedSystem = "Unknown"
	local diagnosticInfo = "未匹配到具体已知模块，请根据堆栈排查相关 Hook 与对象操作。"

	for key, info in pairs(TAINT_DIAGNOSTIC_MAP) do
		if (errMsg and errMsg:find(key)) or (stack and stack:find(key)) then
			matchedSystem = key
			diagnosticInfo = string.format("【疑似关联模块】: %s\n【原因分析】: %s", info.module, info.desc)
			break
		end
	end

	return matchedSystem, diagnosticInfo
end

-- 记录一条污染/阻断日志
function T.LogTaint(systemName, message, customStack)
	local stack = customStack or debugstack(2, 20, 20)
	local timestamp = GetTimestamp()
	local inCombat = InCombatLockdown()

	local matchedSystem, diagnostic = DiagnoseError(message, stack)
	if systemName and systemName ~= "" then
		matchedSystem = systemName
	end

	local entry = {
		time = timestamp,
		inCombat = inCombat,
		system = matchedSystem,
		message = tostring(message or "Unknown Error"),
		stack = stack,
		diagnostic = diagnostic
	}

	table.insert(T.TaintLogs, 1, entry)
	if #T.TaintLogs > MAX_LOGS then
		table.remove(T.TaintLogs)
	end

	-- 聊天框高亮通告
	print(string.format("|cffff2020[ShestakUI 污染追踪]|r [%s] 捕获到暴雪沙盒受限异常！受影响系统: |cffffff00%s|r", timestamp, matchedSystem))
	print(string.format("|cff00ffff[诊断建议]|r %s", diagnostic))
	print("|cff888888输入 |cffffd100/staint|r 可查看详细堆栈与历史记录。|r")

	return entry
end

----------------------------------------------------------------------------------------
--	1. 挂载全局错误处理器钩子
----------------------------------------------------------------------------------------
local originalErrorHandler = geterrorhandler()

local function ShestakUI_ErrorHandler(errMsg)
	if type(errMsg) == "string" then
		-- 匹配 ShestakUI 引起的 Taint、Forbidden Table、Secret Value 或 Block 错误
		local isShestakTaint = errMsg:find("ShestakUI")
			or errMsg:find("cannot be accessed while tainted")
			or errMsg:find("secret %a+ value")
			or errMsg:find("ADDON_ACTION_BLOCKED")
			or errMsg:find("ADDON_ACTION_FORBIDDEN")

		if isShestakTaint then
			local stack = debugstack(2, 25, 25)
			T.LogTaint(nil, errMsg, stack)
		end
	end

	if originalErrorHandler and originalErrorHandler ~= ShestakUI_ErrorHandler then
		return originalErrorHandler(errMsg)
	end
end

seterrorhandler(ShestakUI_ErrorHandler)

----------------------------------------------------------------------------------------
--	2. 事件监听器：ADDON_ACTION_BLOCKED & ADDON_ACTION_FORBIDDEN & LUA_WARNING
----------------------------------------------------------------------------------------
local trackerFrame = CreateFrame("Frame")
trackerFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
trackerFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
if trackerFrame.RegisterEvent then
	pcall(trackerFrame.RegisterEvent, trackerFrame, "LUA_WARNING")
end

trackerFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
	if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
		local addonName = tostring(arg1 or "")
		local funcName = tostring(arg2 or "")

		if addonName:find("ShestakUI") or addonName == "" then
			local msg = string.format("[%s] 插件 '%s' 尝试调用保护功能 '%s'", event, addonName, funcName)
			T.LogTaint(funcName, msg, debugstack(2, 20, 20))
		end
	elseif event == "LUA_WARNING" then
		local warnType = tostring(arg1 or "")
		local warnMessage = tostring(arg2 or "")

		if warnMessage:find("ShestakUI") or warnMessage:find("taint") or warnMessage:find("forbidden") then
			T.LogTaint("LUA_WARNING", string.format("[%s] %s", warnType, warnMessage), debugstack(2, 20, 20))
		end
	end
end)

----------------------------------------------------------------------------------------
--	3. 斜杠调试命令 /staint
----------------------------------------------------------------------------------------
SLASH_STAINT1 = "/staint"
SLASH_STAINT2 = "/sheerror"
SlashCmdList.STAINT = function(msg)
	local cmd, arg = strsplit(" ", strtrim(msg or ""), 2)
	cmd = cmd and cmd:lower() or ""

	if cmd == "clear" then
		T.TaintLogs = {}
		print("|cff00ff00[ShestakUI 污染追踪]|r 日志记录已清空。")
	elseif cmd == "last" then
		local last = T.TaintLogs[1]
		if not last then
			print("|cffffff00[ShestakUI 污染追踪]|r 当前暂无捕获到的污染记录。")
			return
		end
		print("|cffff2020================ ShestakUI 最近一次污染堆栈 ================|r")
		print(string.format("|cffffff00时间:|r %s  |cffffff00战斗中:|r %s  |cffffff00系统:|r %s", last.time, tostring(last.inCombat), last.system))
		print(string.format("|cffffff00报错信息:|r %s", last.message))
		print(string.format("|cff00ffff诊断:|r %s", last.diagnostic))
		print("|cffffff00完整堆栈:|r")
		print(last.stack)
		print("|cffff2020===========================================================|r")
	elseif cmd == "check" and arg and arg ~= "" then
		local targetFrame = _G[arg]
		if not targetFrame then
			print(string.format("|cffff0000[ShestakUI 污染检查]|r 未找到框架: %s", arg))
			return
		end
		print(string.format("|cffffff00[ShestakUI 污染检查]|r 正在检测框架: |cff00ffff%s|r", arg))
		local isSecure, taintedBy = issecurevariable(arg)
		print(string.format("  全局变量安全性: issecure=%s, taintedBy=%s", tostring(isSecure), tostring(taintedBy or "none")))

		-- 检查常见敏感字段
		local sensitiveKeys = {"OnShow", "OnHide", "RefreshLayout", "UpdateGridLayout", "itemFramePool", "auraInstanceIDToItemFramesMap"}
		for _, key in ipairs(sensitiveKeys) do
			if targetFrame[key] ~= nil then
				local sec, tb = issecurevariable(targetFrame, key)
				print(string.format("  - %s: issecure=%s, taintedBy=%s", key, tostring(sec), tostring(tb or "none")))
			end
		end
	elseif cmd == "test" then
		print("|cff00ff00[ShestakUI 污染追踪]|r 触发测试诊断日志...")
		T.LogTaint("CooldownViewer", "测试模拟: attempted to index a table that cannot be accessed while tainted (execution tainted by 'ShestakUI')")
	else
		-- 打印日志列表
		print("|cff00ffff================ ShestakUI 污染与沙盒错误诊断列表 ================|r")
		if #T.TaintLogs == 0 then
			print("|cff00ff00当前运行正常，暂无捕获到由 ShestakUI 引起的沙盒污染报错。|r")
		else
			for i, entry in ipairs(T.TaintLogs) do
				if i <= 5 then
					print(string.format("|cffffff00[%d]|r [%s] |cffff5555%s|r (战斗中: %s)", i, entry.time, entry.system, tostring(entry.inCombat)))
					print(string.format("     信息: %s", entry.message:sub(1, 100)))
				end
			end
			if #T.TaintLogs > 5 then
				print(string.format("|cff888888... 还有 %d 条记录未显示|r", #T.TaintLogs - 5))
			end
		end
		print("|cff888888用法: /staint last (查看最新堆栈) | /staint check <FrameName> (检查框架污染) | /staint clear (清空)|r")
		print("|cff00ffff===================================================================|r")
	end
end
