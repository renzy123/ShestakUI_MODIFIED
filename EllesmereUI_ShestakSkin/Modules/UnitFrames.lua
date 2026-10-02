-------------------------------------------------------------------------------
--  EllesmereUI_ShestakSkin - Modules/UnitFrames.lua
--  头像模块美化：ShestakUI_Custom 经典样式 (混合方案 C)
--
--  两层结构：
--  1) EUI profile 预设 —— 凡是 EUI 设置能表达的，直接写 ns.db.profile 后调用
--     ns.ReloadFrames() 原生重排：4px 能量条、关闭 EUI 自带文本区/BottomTextBar/
--     能量百分比、肖像内嵌右侧 (portraitSide="insideright"，EUI 原生裁剪，含
--     隐藏背景盒)。预设每次登录强制生效 —— 本皮肤拥有该外观，EUI 选项里对
--     这些键的修改只在一个会话内有效。
--  2) 皮肤补丁 —— EUI 设置表达不了的部分，hooksecurefunc(ns, "ReloadFrames")
--     后处理：隐藏 unifiedBorder 换 1px 像素边框、生命条暗底、像素字体、
--     2D 肖像 0.35 透明度 + 方形裁切、外侧大号百分比与框内名字/等级/数值。
--
--  硬约束（来自 EUI 源码，勿回退）：
--  - frame.Health/Power 位于 _barClip (SetClipsChildren) 内，任何挂在 health 上
--    且锚定到框体外部的元素会被裁剪不可见 → 外侧百分比必须挂文本宿主。
--  - 生命+能量高度精确填满框体条区，能量条下方没有 3px 间隙的余量，硬塞会
--    被裁剪 → Shestak 的悬浮间隙放弃，保留 EUI 贴边堆叠。
--  - 12.x 受保护副本内 UnitHealth/UnitName/UnitClass 可能返回 secret value，
--    所有数值/字符串格式化必须经 issecretvalue/pcall 防护。
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local SK = ns.SK

local BASE_FONT_SIZE = 12
local PERCENT_FONT_SIZE = 22
local PORTRAIT_ALPHA = 0.35

-- 本皮肤只处理玩家与目标框体（与 ShestakUI_Custom 的作用域一致）
local STYLED_UNITS = {
    player = "EllesmereUIUnitFrames_Player",
    target = "EllesmereUIUnitFrames_Target",
}

local issecretvalue = _G.issecretvalue

-- EllesmereUIUnitFrames 在加载时把自身私有命名空间注册进父级注册表
-- (EllesmereUIUnitFrames.lua:4)，皮肤经此访问 ns.db / ns.ReloadFrames。
local function GetUFNS()
    local EUI = _G.EllesmereUI
    return EUI and EUI._ModuleNS and EUI._ModuleNS.EllesmereUIUnitFrames
end

-------------------------------------------------------------------------------
--  第 1 层：EUI profile 预设
-------------------------------------------------------------------------------
local PRESET = {
    player = {
        leftTextContent = "none", rightTextContent = "none",
        centerTextContent = "none", extraTextContent = "none",
        bottomTextBar = false, powerPercentText = "none",
        powerHeight = 4,
        portraitSide = "insideright",
    },
    target = {
        leftTextContent = "none", rightTextContent = "none",
        centerTextContent = "none", extraTextContent = "none",
        bottomTextBar = false, powerPercentText = "none",
        powerHeight = 4,
        portraitSide = "insideright",
    },
    focus = {
        leftTextContent = "none", rightTextContent = "none",
        centerTextContent = "none", extraTextContent = "none",
        bottomTextBar = false, powerPercentText = "none",
        powerHeight = 4,
    },
    boss = {
        leftTextContent = "none", rightTextContent = "none",
        centerTextContent = "none", extraTextContent = "none",
        bottomTextBar = false, powerPercentText = "none",
        powerHeight = 4,
    },
}

local presetApplied = false

local function ApplyProfilePreset(ufns)
    local profile = ufns.db and ufns.db.profile
    if not profile then return false end
    for unitKey, keys in pairs(PRESET) do
        local t = profile[unitKey]
        if t then
            for k, v in pairs(keys) do
                t[k] = v
            end
        end
    end
    presetApplied = true
    return true
end

-------------------------------------------------------------------------------
--  安全格式化辅助
-------------------------------------------------------------------------------
local function tryformat(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    if ok and type(s) == "string" then return s end
    return ""
end

local function SafeShortValue(val)
    if val == nil then return "" end
    if issecretvalue and issecretvalue(val) then return "" end
    local ok, res = pcall(function()
        if type(val) ~= "number" then return tostring(val) end
        if _G.AbbreviateNumbers then return _G.AbbreviateNumbers(val) end
        if val >= 1e6 then return string.format("%.1fm", val / 1e6) end
        if val >= 1e3 then return string.format("%.1fk", val / 1e3) end
        return tostring(math.floor(val))
    end)
    if ok and type(res) == "string" then return res end
    return ""
end

local function GetUnitColorHex(unit)
    local ok, hex = pcall(function()
        if not unit or not UnitExists(unit) then return "ffffffff" end
        if UnitIsPlayer(unit) or (_G.UnitInPartyIsAI and _G.UnitInPartyIsAI(unit)) then
            local _, class = UnitClass(unit)
            if issecretvalue and issecretvalue(class) then class = nil end
            local color = class and (_G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS)[class]
            if color then
                return string.format("ff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
            end
        else
            local reaction = UnitReaction(unit, "player")
            if type(reaction) == "number" and _G.FACTION_BAR_COLORS and _G.FACTION_BAR_COLORS[reaction] then
                local c = _G.FACTION_BAR_COLORS[reaction]
                return string.format("ff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
            end
        end
        return "ffffffff"
    end)
    if ok and type(hex) == "string" then return hex end
    return "ffffffff"
end

local function SetPixelFont(fs, size)
    fs:SetFont(SK.FontPixel, size, "OUTLINE")
end

-- 文本宿主：EUI 的 _textOverlay 层（框体 +20 层、永不裁剪、永不隐藏）。
-- 若缺失（理论兜底）则自建同层级的覆盖层。
local function GetTextHost(frame)
    local host = frame._textOverlay
    if host then return host end
    host = frame._shestakOverlay
    if not host then
        host = CreateFrame("Frame", nil, frame)
        host:SetAllPoints(frame)
        host:SetFrameStrata(frame:GetFrameStrata())
        host:SetFrameLevel(frame:GetFrameLevel() + 25)
        frame._shestakOverlay = host
    end
    return host
end

-------------------------------------------------------------------------------
--  第 2 层：皮肤补丁
-------------------------------------------------------------------------------
local function EnsureStyle(frame, unitKey)
    if frame._shestak then return frame._shestak end
    local health = frame.Health
    if not health then return nil end

    local host = GetTextHost(frame)
    local t = {}

    local function mkFS(size)
        local fs = host:CreateFontString(nil, "OVERLAY")
        SetPixelFont(fs, size)
        fs:SetWordWrap(false)
        return fs
    end

    -- 外侧大号百分比（玩家在框体右侧外、目标在左侧外）
    t.percent = mkFS(PERCENT_FONT_SIZE)
    t.percent:ClearAllPoints()
    if unitKey == "player" then
        t.percent:SetPoint("LEFT", frame, "RIGHT", 8, 0)
        t.percent:SetJustifyH("LEFT")
    else
        t.percent:SetPoint("RIGHT", frame, "LEFT", -8, 0)
        t.percent:SetJustifyH("RIGHT")
    end

    -- 生命条内当前值
    t.value = mkFS(BASE_FONT_SIZE)
    t.value:ClearAllPoints()
    if unitKey == "player" then
        t.value:SetPoint("RIGHT", health, "RIGHT", -4, 0)
        t.value:SetJustifyH("RIGHT")
    else
        t.value:SetPoint("LEFT", health, "LEFT", 4, 0)
        t.value:SetJustifyH("LEFT")
    end

    if unitKey == "player" then
        t.level = mkFS(BASE_FONT_SIZE)
        t.level:SetPoint("LEFT", health, "LEFT", 4, 0)
    elseif unitKey == "target" then
        t.name = mkFS(BASE_FONT_SIZE)
        t.name:SetPoint("RIGHT", health, "RIGHT", -2, 0)
        t.name:SetJustifyH("RIGHT")
        t.level = mkFS(BASE_FONT_SIZE)
        t.level:SetPoint("RIGHT", t.name, "LEFT", -2, 0)
    end

    -- 生命/能量条 1px 像素边框（CreatePixelBorder 自带缓存，可重入）
    SK:CreatePixelBorder(health)
    if frame.Power then
        SK:CreatePixelBorder(frame.Power)
    end

    frame._shestak = t
    return t
end

local function UpdateTexts(frame, unitKey)
    local t = frame._shestak
    if not t then return end
    local unit = frame._euiUnit or unitKey
    if not unit then return end

    local isDead, isOffline = false, false
    pcall(function()
        if not UnitExists(unit) then return end
        isOffline = not UnitIsConnected(unit)
        isDead = UnitIsDeadOrGhost(unit)
    end)

    -- 百分比走 C 端 UnitHealthPercent，避开对 secret 做除法
    local perc
    if not (isDead or isOffline) and _G.CurveConstants and _G.CurveConstants.ScaleTo100 then
        local ok, v = pcall(UnitHealthPercent, unit, true, _G.CurveConstants.ScaleTo100)
        if ok and type(v) == "number" and not (issecretvalue and issecretvalue(v)) then
            perc = v
        end
    end
    local isLow = perc ~= nil and perc < 50

    -- 1. 生命条内数值（低血量红、正常淡绿；死亡/离线状态字）
    if isOffline then
        t.value:SetText("|cffD7BEA5离线|r")
    elseif isDead then
        local _, ghost = pcall(UnitIsGhost, unit)
        t.value:SetText(ghost and "|cffD7BEA5灵魂|r" or "|cffD7BEA5死亡|r")
    else
        local ok, cur = pcall(UnitHealth, unit)
        local valColor = isLow and "ffff0000" or "ff559655"
        t.value:SetText(tryformat("|c%s%s|r", valColor, SafeShortValue(ok and cur or nil)))
    end

    -- 2. 外侧大号百分比
    if isOffline or isDead then
        t.percent:SetText("|cff9d9d9d0%|r")
    elseif perc then
        local hex = isLow and "ffff0000" or GetUnitColorHex(unit)
        t.percent:SetText(tryformat("|c%s%d%%|r", hex, perc))
    else
        t.percent:SetText("")
    end

    -- 3. 名字与等级
    if t.name then
        local ok, name = pcall(UnitName, unit)
        if ok and type(name) == "string" and name ~= "" and not (issecretvalue and issecretvalue(name)) then
            t.name:SetText(tryformat("|c%s%s|r", GetUnitColorHex(unit), name))
        else
            t.name:SetText("")
        end
    end
    if t.level then
        local ok, lvl = pcall(UnitLevel, unit)
        if ok and type(lvl) == "number" and not (issecretvalue and issecretvalue(lvl)) then
            if lvl == -1 then
                t.level:SetText("??")
            elseif lvl > 0 then
                t.level:SetText(tostring(lvl))
            end
        end
    end
end

-- 每次 ReloadFrames 之后重申的补丁（ReloadFrames 会重挂 unifiedBorder、
-- 重排能量条并可能替换 Portrait 对象，故全部走可重入逻辑）。
local function SkinPatchFrame(frame, unitKey)
    if not frame then return end

    if frame.unifiedBorder then
        frame.unifiedBorder:Hide()
    end

    local health = frame.Health
    if health and health.bg and health.bg.SetVertexColor then
        health.bg:SetVertexColor(0.05, 0.05, 0.05)
        health.bg:SetAlpha(1)
    end

    -- 肖像：EUI insideright 原生锚定与裁剪；补丁只补透明度与方形裁切。
    -- tex2D.PostUpdate 在每次重绘后被调，包一层让裁切/透明度跟随每次重绘。
    local p = frame.Portrait
    if p and p.SetTexCoord and not p._shestakWrapped then
        p._shestakWrapped = true
        local orig = p.PostUpdate
        p.PostUpdate = function(self, ...)
            if orig then orig(self, ...) end
            SK:CropIcon(self)
            self:SetAlpha(PORTRAIT_ALPHA)
        end
    end
    if p then
        if p.SetTexCoord then SK:CropIcon(p) end
        if p.SetAlpha then p:SetAlpha(PORTRAIT_ALPHA) end
    end

    EnsureStyle(frame, unitKey)
    UpdateTexts(frame, unitKey)
end

local function GetFrame(ufns, unitKey)
    local frames = ufns and ufns.frames
    local f = frames and frames[unitKey]
    if f then return f end
    return _G[STYLED_UNITS[unitKey]]
end

local function SkinPatchAll()
    local ufns = GetUFNS()
    for unitKey in pairs(STYLED_UNITS) do
        SkinPatchFrame(GetFrame(ufns, unitKey), unitKey)
    end
end

SK.SkinAllUnitFrames = SkinPatchAll

-------------------------------------------------------------------------------
--  启动时序：等 ns.db 就绪 → 写预设 → ReloadFrames → 挂钩 → 首刷
-------------------------------------------------------------------------------
local bootTries = 0
local hooked = false

local function Boot()
    local ufns = GetUFNS()
    if not (ufns and ufns.db and ufns.db.profile) then
        bootTries = bootTries + 1
        if bootTries < 20 then
            C_Timer.After(0.5, Boot)
        end
        return
    end

    if not presetApplied then
        if ApplyProfilePreset(ufns) and type(ufns.ReloadFrames) == "function" then
            ufns.ReloadFrames()
        end
    end

    if not hooked and type(ufns.ReloadFrames) == "function" then
        hooked = true
        hooksecurefunc(ufns, "ReloadFrames", function()
            SkinPatchAll()
        end)
    end

    SkinPatchAll()
    SK:Log("头像皮肤已应用 (预设 %s)", presetApplied and "生效" or "未生效")
end

local ufWatcher = CreateFrame("Frame")
ufWatcher:RegisterEvent("PLAYER_LOGIN")
ufWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
ufWatcher:RegisterEvent("PLAYER_TARGET_CHANGED")
ufWatcher:RegisterEvent("PLAYER_LEVEL_UP")
ufWatcher:RegisterUnitEvent("UNIT_HEALTH", "player", "target")
ufWatcher:RegisterUnitEvent("UNIT_MAXHEALTH", "player", "target")
ufWatcher:RegisterUnitEvent("UNIT_CONNECTION", "player", "target")
ufWatcher:RegisterUnitEvent("UNIT_NAME_UPDATE", "player", "target")
ufWatcher:RegisterUnitEvent("UNIT_LEVEL", "player", "target")
ufWatcher:RegisterUnitEvent("UNIT_FACTION", "player", "target")

ufWatcher:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Boot()
        return
    end
    if event == "PLAYER_TARGET_CHANGED" then
        local ufns = GetUFNS()
        local f = GetFrame(ufns, "target")
        if f then UpdateTexts(f, "target") end
        return
    end
    if event == "PLAYER_LEVEL_UP" then
        local ufns = GetUFNS()
        local f = GetFrame(ufns, "player")
        if f then UpdateTexts(f, "player") end
        return
    end
    -- UNIT_* 事件只订阅了 player/target
    local ufns = GetUFNS()
    local f = GetFrame(ufns, arg1)
    if f then UpdateTexts(f, arg1) end
end)
