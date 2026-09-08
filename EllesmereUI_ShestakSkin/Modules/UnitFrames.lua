-------------------------------------------------------------------------------
--  EllesmereUI_ShestakSkin - Modules/UnitFrames.lua
--  头像模块美化：完美复刻 shestak_custom 经典样式
--  包含：生命条独立边框、4px 悬浮能量条、生命条内 3D OVERLAY 半透明肖像、
--  外侧大号血量百分比（玩家在右、目标在左）、紧凑名字与等级排版、能量数值隐藏
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local SK = ns.SK

-- 字体大小与基础设置
local BASE_FONT_SIZE = 12
local PERCENTAGE_FONT_SIZE = 22

-- 安全数值格式化辅助函数 (兼容暴雪 12.0+ Secret Number 与 AbbreviateNumbers)
local function SafeShortValue(val)
    if not val then return "" end
    if AbbreviateNumbers then
        return AbbreviateNumbers(val)
    end
    local ok, res = pcall(function()
        if val >= 1e6 then
            return string.format("%.1fm", val / 1e6)
        elseif val >= 1e3 then
            return string.format("%.1fk", val / 1e3)
        else
            return tostring(math.floor(val))
        end
    end)
    if ok then return res end
    return tostring(val)
end

-- 获取单位职业或声望十六进制颜色字符串
local function GetUnitColorHex(unit)
    if not unit or not UnitExists(unit) then return "ffffffff" end
    if UnitIsPlayer(unit) or (UnitInPartyIsAI and UnitInPartyIsAI(unit)) then
        local _, class = UnitClass(unit)
        local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
        if color then
            return string.format("ff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
        end
    else
        local reaction = UnitReaction(unit, "player")
        if reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction] then
            local c = FACTION_BAR_COLORS[reaction]
            return string.format("ff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
        end
    end
    return "ffffffff"
end

-- 自定义 3D/2D 肖像更新函数 (OVERLAY 模式，半透明投射在生命条内)
local function UpdateOverlayPortrait(frame, unit)
    if not frame or not unit or not UnitExists(unit) then return end

    -- 优先更新自定义 3D PlayerModel
    local customModel = frame.CustomOverlayPortrait
    if customModel then
        local guid = UnitGUID(unit)
        local isConnected = UnitIsConnected(unit)
        local isVisible = UnitIsVisible(unit)
        if isConnected and isVisible and guid then
            if customModel.ClearModel then customModel:ClearModel() end
            if customModel.SetUnit then customModel:SetUnit(unit) end
            if customModel.SetCamDistanceScale then customModel:SetCamDistanceScale(1) end
            if customModel.SetPosition then customModel:SetPosition(0, 0, 0) end
            if customModel.SetRotation then customModel:SetRotation(0) end
            if customModel.SetPortraitZoom then customModel:SetPortraitZoom(1) end
            customModel:Show()
            return
        else
            if customModel.ClearModel then customModel:ClearModel() end
            customModel:Hide()
        end
    end

    -- 处理已有的 Portrait 元素 (可能为 Model 或 Texture)
    local portrait = frame.Portrait
    if not portrait then return end

    local guid = UnitGUID(unit)
    local isConnected = UnitIsConnected(unit)
    local isVisible = UnitIsVisible(unit)

    if not isConnected or not isVisible or not guid then
        if portrait.ClearModel and type(portrait.ClearModel) == "function" then
            portrait:ClearModel()
        end
        if portrait.Icon and portrait.Icon.SetTexture then
            SetPortraitTexture(portrait.Icon, unit)
            SK:CropIcon(portrait.Icon)
            portrait.Icon:Show()
        elseif portrait.SetTexture then
            SetPortraitTexture(portrait, unit)
            SK:CropIcon(portrait)
        end
    else
        if portrait.Icon then portrait.Icon:Hide() end
        if portrait.ClearModel and type(portrait.ClearModel) == "function" then
            portrait:ClearModel()
            portrait:SetUnit(unit)
            if portrait.SetCamDistanceScale then portrait:SetCamDistanceScale(1) end
            if portrait.SetPosition then portrait:SetPosition(0, 0, 0) end
            if portrait.SetRotation then portrait:SetRotation(0) end
            if portrait.SetPortraitZoom then portrait:SetPortraitZoom(1) end
        elseif portrait.SetTexture then
            SetPortraitTexture(portrait, unit)
            SK:CropIcon(portrait)
        end
    end
end

-- 更新外侧大号百分比与生命值数值 (深度适配暴雪 12.0+ Secret Number)
local function UpdateHealthDisplay(frame, unit)
    if not frame or not unit or not UnitExists(unit) then return end

    local health = frame.healthBar or frame.Health or frame.health
    if not health then return end

    local isDead = not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit)

    -- 使用暴雪官方 C 端 UnitHealthPercent 避开对 Secret Value 进行直接除法运算
    local perc = nil
    if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        perc = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
    elseif UnitHealthPercent then
        perc = UnitHealthPercent(unit)
    end
    if not perc and not isDead then
        local cur = UnitHealth(unit)
        local max = UnitHealthMax(unit) or 1
        local ok, calc = pcall(function() return math.floor((cur / max) * 100 + 0.5) end)
        if ok then perc = calc end
    end

    local isLow = false
    if perc then
        local ok, res = pcall(function() return perc < 50 end)
        if ok then isLow = res end
    end

    -- 1. 更新生命条内的简洁当前数值 (低于 50% 显示红色，正常显示淡绿色)
    if health.value then
        if isDead then
            if not UnitIsConnected(unit) then
                health.value:SetText("|cffD7BEA5离线|r")
            elseif UnitIsDead(unit) then
                health.value:SetText("|cffD7BEA5死亡|r")
            elseif UnitIsGhost(unit) then
                health.value:SetText("|cffD7BEA5灵魂|r")
            end
        else
            local valColor = isLow and "ffff0000" or "ff559655"
            local cur = UnitHealth(unit)
            pcall(function()
                health.value:SetFormattedText("|c%s%s|r", valColor, SafeShortValue(cur))
            end)
        end
    end

    -- 2. 更新外侧大号百分比文本 (玩家在框体右侧外部，目标在框体左侧外部)
    if health.percentage then
        if isDead then
            health.percentage:SetText("|cff9d9d9d0%|r")
        else
            local hex = isLow and "ffff0000" or GetUnitColorHex(unit)
            pcall(function()
                if perc then
                    health.percentage:SetFormattedText("|c%s%d%%|r", hex, perc)
                else
                    health.percentage:SetText("")
                end
            end)
        end
    end

    -- 3. 动态调整 3D 肖像裁切范围 (若处于 OVERLAY 模式)
    if frame.PortraitWrapper and health:GetStatusBarTexture() then
        frame.PortraitWrapper:SetPoint("RIGHT", health:GetStatusBarTexture(), "RIGHT", 0, 0)
    end
end

-- 样式注入函数：应用 shestak_custom 风格至指定单位框体
local function ApplyShestakCustomStyle(frame, unit)
    if not frame or not unit then return end

    -- 1. 隐藏外层主框体的多余统一样式背景，实现极简悬浮质感
    if frame.backdrop then
        frame.backdrop:Hide()
    end

    -- 2. 生命条 (HealthBar) 美化：独立 1px 黑色像素边框 + 纯黑暗底
    local health = frame.healthBar or frame.Health or frame.health
    if health then
        health:SetStatusBarTexture(SK.Texture)
        if health.bg then
            if health.bg.SetTexture then health.bg:SetTexture(SK.Texture) end
            if health.bg.SetVertexColor then health.bg:SetVertexColor(0.05, 0.05, 0.05, 1) end
        end
        SK:CreatePixelBorder(health)
        health:SetFrameLevel(6)

        -- 创建或调整外侧大号百分比文本
        if not health.percentage then
            health.percentage = health:CreateFontString(nil, "OVERLAY")
            health.percentage:SetFont(STANDARD_TEXT_FONT, PERCENTAGE_FONT_SIZE, "OUTLINE")
        end
        health.percentage:ClearAllPoints()
        if unit == "player" then
            -- 玩家大号百分比显示在框体右侧外部
            health.percentage:SetPoint("LEFT", frame, "RIGHT", 8, 0)
            health.percentage:SetJustifyH("LEFT")
        elseif unit == "target" then
            -- 目标大号百分比显示在框体左侧外部
            health.percentage:SetPoint("RIGHT", frame, "LEFT", -8, 0)
            health.percentage:SetJustifyH("RIGHT")
        end

        -- 生命条内右侧数值文本
        if not health.value and health.CreateFontString then
            health.value = health:CreateFontString(nil, "OVERLAY")
            health.value:SetFont(STANDARD_TEXT_FONT, BASE_FONT_SIZE, "OUTLINE")
        end
        if health.value then
            health.value:ClearAllPoints()
            if unit == "player" then
                health.value:SetPoint("RIGHT", health, "RIGHT", -4, 0)
                health.value:SetJustifyH("RIGHT")
            else
                health.value:SetPoint("LEFT", health, "LEFT", 4, 0)
                health.value:SetJustifyH("LEFT")
            end
        end
    end

    -- 3. 能量条 (PowerBar) 美化：固定高度 4px，与生命条底部留 3px 间隙，数值清空
    local power = frame.powerBar or frame.Power or frame.power
    if power and health then
        power:SetStatusBarTexture(SK.Texture)
        power:SetHeight(4)
        power:ClearAllPoints()
        power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -3)
        power:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT", 0, -3)
        if power.bg then
            if power.bg.SetTexture then power.bg:SetTexture(SK.Texture) end
            if power.bg.SetVertexColor then power.bg:SetVertexColor(0.05, 0.05, 0.05, 1) end
        end
        SK:CreatePixelBorder(power)
        power:SetFrameLevel(4)

        -- 隐藏能量具体数值 (shestak_custom 风格)
        if power.value then power.value:SetText("") end
        if power.short_value then power.short_value:SetText("") end
    end

    -- 4. 3D/2D 肖像 OVERLAY 嵌入模式 (半透明投射在生命条内，随剩余血量裁剪)
    if health then
        local wrapper = frame.PortraitWrapper
        if not wrapper then
            wrapper = CreateFrame("Frame", (frame:GetName() or "SKUnit") .. "_PortraitWrapper", health)
            wrapper:SetPoint("TOPLEFT", health, "TOPLEFT", 0, 0)
            wrapper:SetPoint("BOTTOMLEFT", health, "BOTTOMLEFT", 0, 0)
            wrapper:SetPoint("RIGHT", health, "RIGHT", 0, 0)
            wrapper:SetClipsChildren(true)
            frame.PortraitWrapper = wrapper
        end
        wrapper:SetFrameLevel(health:GetFrameLevel() + 1)

        -- 区分检测肖像是否为 Texture 还是 Frame/Model
        local portrait = frame.Portrait
        local pHost = nil

        if portrait then
            if type(portrait.SetParent) == "function" then
                pHost = portrait
            elseif portrait.backdrop and type(portrait.backdrop.SetParent) == "function" then
                pHost = portrait.backdrop
            end
        end

        if not pHost and not frame.CustomOverlayPortrait then
            local model = CreateFrame("PlayerModel", (frame:GetName() or "SKUnit") .. "_CustomPortrait", wrapper)
            frame.CustomOverlayPortrait = model
            pHost = model
        elseif frame.CustomOverlayPortrait then
            pHost = frame.CustomOverlayPortrait
        end

        if pHost then
            pHost:SetParent(wrapper)
            pHost:ClearAllPoints()
            pHost:SetPoint("TOPLEFT", health, "TOPLEFT", 0, 0)
            pHost:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
            if pHost.SetFrameLevel then
                pHost:SetFrameLevel(wrapper:GetFrameLevel())
            end
            if pHost.SetAlpha then
                pHost:SetAlpha(0.35)
            end
            pHost:Show()
        end

        UpdateOverlayPortrait(frame, unit)
    end

    -- 5. 名字与等级排版 (紧凑内嵌)
    if unit == "player" then
        -- 玩家等级显示在生命条左侧内部
        if not frame.Level and health then
            frame.Level = health:CreateFontString(nil, "OVERLAY")
            frame.Level:SetFont(STANDARD_TEXT_FONT, BASE_FONT_SIZE, "OUTLINE")
        end
        if frame.Level and health then
            frame.Level:ClearAllPoints()
            frame.Level:SetPoint("LEFT", health, "LEFT", 4, 0)
            local level = UnitLevel("player")
            frame.Level:SetText(level and tostring(level) or "")
        end
    elseif unit == "target" then
        -- 目标名字直接右对齐在生命条最右端内部，紧贴边缘
        local nameText = frame.nameText or frame.Info or (frame.BottomTextBar and frame.BottomTextBar.nameText)
        if not nameText and health then
            nameText = health:CreateFontString(nil, "OVERLAY")
            nameText:SetFont(STANDARD_TEXT_FONT, BASE_FONT_SIZE, "OUTLINE")
            frame.nameText = nameText
        end
        if nameText and health then
            nameText:ClearAllPoints()
            nameText:SetPoint("RIGHT", health, "RIGHT", -2, 0)
            nameText:SetJustifyH("RIGHT")
            local tName = UnitName("target")
            if tName then
                local hex = GetUnitColorHex("target")
                nameText:SetFormattedText("|c%s%s|r", hex, tName)
            end
        end

        -- 目标等级紧随名字左侧
        if not frame.Level and health then
            frame.Level = health:CreateFontString(nil, "OVERLAY")
            frame.Level:SetFont(STANDARD_TEXT_FONT, BASE_FONT_SIZE, "OUTLINE")
        end
        if frame.Level and nameText then
            frame.Level:ClearAllPoints()
            frame.Level:SetPoint("RIGHT", nameText, "LEFT", -2, 0)
            local tLevel = UnitLevel("target")
            if tLevel and tLevel > 0 then
                frame.Level:SetText(tostring(tLevel))
            elseif tLevel == -1 then
                frame.Level:SetText("??")
            end
        end
    end

    -- 立即刷新一次生命数值与外侧百分比
    UpdateHealthDisplay(frame, unit)
end

-- 全局扫描并刷新各单位框体
local function RefreshAllFrames()
    local unitTargets = {
        { name = "EllesmereUIUnitFrames_Player", unit = "player" },
        { name = "EllesmereUIUnitFrames_Target", unit = "target" },
        { name = "EllesmereUIUnitFrames_Focus",  unit = "focus" },
        { name = "EllesmereUIUnitFrames_Pet",    unit = "pet" },
        -- ShestakUI / oUF 原生框体
        { name = "oUF_Player", unit = "player" },
        { name = "oUF_Target", unit = "target" },
        { name = "oUF_Focus",  unit = "focus" },
        { name = "oUF_Pet",    unit = "pet" },
    }

    local count = 0
    for _, item in ipairs(unitTargets) do
        local f = _G[item.name]
        if f then
            ApplyShestakCustomStyle(f, item.unit)
            count = count + 1
        end
    end

    if count > 0 then
        SK:Log("已成功应用 shestak_custom 头像样式至 %d 个框体", count)
    end
end

SK.SkinAllUnitFrames = RefreshAllFrames

-- 事件监听器驱动
local ufWatcher = CreateFrame("Frame")
ufWatcher:RegisterEvent("PLAYER_LOGIN")
ufWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
ufWatcher:RegisterEvent("PLAYER_TARGET_CHANGED")
ufWatcher:RegisterEvent("PLAYER_FOCUS_CHANGED")
ufWatcher:RegisterEvent("UNIT_HEALTH")
ufWatcher:RegisterEvent("UNIT_MAXHEALTH")
ufWatcher:RegisterEvent("UNIT_PORTRAIT_UPDATE")
ufWatcher:RegisterEvent("UNIT_MODEL_CHANGED")

ufWatcher:SetScript("OnEvent", function(self, event, arg1)
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if arg1 == "player" then
            local pf = _G["EllesmereUIUnitFrames_Player"] or _G["oUF_Player"]
            if pf then UpdateHealthDisplay(pf, "player") end
        elseif arg1 == "target" then
            local tf = _G["EllesmereUIUnitFrames_Target"] or _G["oUF_Target"]
            if tf then UpdateHealthDisplay(tf, "target") end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        local tf = _G["EllesmereUIUnitFrames_Target"] or _G["oUF_Target"]
        if tf then
            ApplyShestakCustomStyle(tf, "target")
            UpdateOverlayPortrait(tf, "target")
            UpdateHealthDisplay(tf, "target")
        end
    elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
        if arg1 == "player" then
            local pf = _G["EllesmereUIUnitFrames_Player"] or _G["oUF_Player"]
            if pf then UpdateOverlayPortrait(pf, "player") end
        elseif arg1 == "target" then
            local tf = _G["EllesmereUIUnitFrames_Target"] or _G["oUF_Target"]
            if tf then UpdateOverlayPortrait(tf, "target") end
        end
    else
        RefreshAllFrames()
        C_Timer.After(0.5, RefreshAllFrames)
        C_Timer.After(1.5, RefreshAllFrames)
        C_Timer.After(3.0, RefreshAllFrames)
    end
end)
