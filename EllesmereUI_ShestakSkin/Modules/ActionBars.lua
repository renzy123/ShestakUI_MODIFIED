-------------------------------------------------------------------------------
--  EllesmereUI_ShestakSkin - Modules/ActionBars.lua
--  动作条模块美化：1px 黑色像素边框、图标正方形裁切与按键样式
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local SK = ns.SK

local function SkinActionBarButtons()
    -- 1. 美化 EllesmereUIActionBars 自有动作按钮 (EABButton1..120)
    for i = 1, 120 do
        local btn = _G["EABButton" .. i]
        if btn then
            SK:SkinButton(btn)
        end
    end

    -- 2. 美化暴雪原生主副动作条按钮 (备用与兼容)
    local barButtonPrefixes = {
        "ActionButton",
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBarRightButton",
        "MultiBarLeftButton",
        "MultiBar5Button",
        "MultiBar6Button",
        "MultiBar7Button",
    }
    for _, prefix in ipairs(barButtonPrefixes) do
        for i = 1, 12 do
            local btn = _G[prefix .. i]
            if btn then
                SK:SkinButton(btn)
            end
        end
    end

    -- 3. 美化宠物条按钮 (PetActionButton1..10)
    for i = 1, 10 do
        local btn = _G["PetActionButton" .. i]
        if btn then
            SK:SkinButton(btn)
        end
    end

    -- 4. 美化姿态条按钮 (StanceButton1..10)
    for i = 1, 10 do
        local btn = _G["StanceButton" .. i]
        if btn then
            SK:SkinButton(btn)
        end
    end

    -- 5. 额外快捷键按钮与离开载具按钮
    if ExtraActionButton1 then
        SK:SkinButton(ExtraActionButton1)
    end
    if MainMenuBarVehicleLeaveButton then
        SK:SkinButton(MainMenuBarVehicleLeaveButton)
    end
end

-- 安全钩取动作条图标刷新，防止换页或技能变动时被系统重置裁剪
local function HookActionBarUpdates()
    if not hooksecurefunc then return end

    -- 1. 兼容经典版本暴雪全局 ActionButton_Update (存在才 hook)
    if type(_G["ActionButton_Update"]) == "function" then
        hooksecurefunc("ActionButton_Update", function(button)
            if button and button.icon then
                SK:CropIcon(button.icon)
            end
        end)
    end

    -- 2. 兼容现代版本 ActionButtonMixin:Update (存在才 hook)
    if ActionButtonMixin and type(ActionButtonMixin.Update) == "function" then
        hooksecurefunc(ActionButtonMixin, "Update", function(button)
            if button and button.icon then
                SK:CropIcon(button.icon)
            end
        end)
    end
end

SK.SkinActionBars = SkinActionBarButtons

-- 模块加载事件
local barFrame = CreateFrame("Frame")
barFrame:RegisterEvent("PLAYER_LOGIN")
barFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
barFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
barFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
barFrame:SetScript("OnEvent", function(self, event)
    SkinActionBarButtons()
    if event == "PLAYER_LOGIN" then
        HookActionBarUpdates()
    end
    C_Timer.After(0.5, SkinActionBarButtons)
    C_Timer.After(1.5, SkinActionBarButtons)
end)
