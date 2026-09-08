-------------------------------------------------------------------------------
--  EllesmereUI_ShestakSkin - Modules/BlizzardSkin.lua
--  暴雪原生常用界面美化：核心窗口 1px 黑色像素边框挂载
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local SK = ns.SK

-- 核心系统静态窗口列表
local blizzardFrames = {
    "CharacterFrame",
    "SpellBookFrame",
    "PlayerSpellsFrame",
    "FriendsFrame",
    "CommunitiesFrame",
    "PVEFrame",
    "LootFrame",
    "GameMenuFrame",
    "SettingsPanel",
    "MacroFrame",
    "ContainerFrameCombinedBags",
}

-- 暴雪动态插件到主框体的安全映射表
local addonFrameMap = {
    ["Blizzard_MacroUI"] = "MacroFrame",
    ["Blizzard_AuctionHouseUI"] = "AuctionHouseFrame",
    ["Blizzard_TrainerUI"] = "ClassTrainerFrame",
    ["Blizzard_TradeSkillUI"] = "ProfessionsFrame",
    ["Blizzard_InspectUI"] = "InspectFrame",
    ["Blizzard_ItemSocketingUI"] = "ItemSocketingFrame",
    ["Blizzard_BarbershopUI"] = "BarbershopFrame",
}

local function SkinBlizzardFrame(frame)
    if not frame or frame._shetsakSkinned then return end
    if type(frame) ~= "table" or type(frame.GetObjectType) ~= "function" then return end

    -- 挂载 1px 黑色像素边框
    SK:CreatePixelBorder(frame)
    frame._shetsakSkinned = true
end

local function ScanBlizzardFrames()
    for _, name in ipairs(blizzardFrames) do
        local f = _G[name]
        if f then
            SkinBlizzardFrame(f)
        end
    end

    -- 独立背包框体 (ContainerFrame1..13)
    for i = 1, 13 do
        local bag = _G["ContainerFrame" .. i]
        if bag then
            SkinBlizzardFrame(bag)
        end
    end
end

local blizzFrame = CreateFrame("Frame")
blizzFrame:RegisterEvent("PLAYER_LOGIN")
blizzFrame:RegisterEvent("ADDON_LOADED")
blizzFrame:SetScript("OnEvent", function(self, event, arg1)
    ScanBlizzardFrames()
    -- 安全处理暴雪按需加载插件
    if event == "ADDON_LOADED" and arg1 and addonFrameMap[arg1] then
        local targetName = addonFrameMap[arg1]
        local f = _G[targetName]
        if f then
            SkinBlizzardFrame(f)
        end
    end
end)
