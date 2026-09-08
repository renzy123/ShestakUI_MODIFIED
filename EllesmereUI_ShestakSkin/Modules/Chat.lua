-------------------------------------------------------------------------------
--  EllesmereUI_ShestakSkin - Modules/Chat.lua
--  聊天模块美化：1px 黑色像素边框与暗色半透明底座
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local SK = ns.SK

local function SkinChatFrames()
    -- 1. 美化 EllesmereUIChat 主面板（如果存在）
    local euiChatPanel = _G["EllesmereUIChat_Panel"] or _G["EllesmereUIChatFrame"]
    if euiChatPanel then
        SK:CreateBackdrop(euiChatPanel, 0.8)
    end

    -- 2. 遍历美化系统各聊天窗口与输入框
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local chat = _G["ChatFrame" .. i]
        if chat and not chat._shetsakSkinned then
            -- 挂载暗色半透明背景与 1px 像素边框
            SK:CreateBackdrop(chat, 0.6)

            -- 美化聊天输入框 (EditBox)
            local editBox = _G["ChatFrame" .. i .. "EditBox"]
            if editBox and not editBox._shetsakSkinned then
                -- 隐藏暴雪浮雕背景贴图
                local left = _G["ChatFrame" .. i .. "EditBoxLeft"]
                local mid = _G["ChatFrame" .. i .. "EditBoxMid"]
                local right = _G["ChatFrame" .. i .. "EditBoxRight"]
                if left then left:SetAlpha(0) end
                if mid then mid:SetAlpha(0) end
                if right then right:SetAlpha(0) end

                SK:CreateBackdrop(editBox, 0.8)
                editBox._shetsakSkinned = true
            end

            chat._shetsakSkinned = true
        end
    end
end
SK.SkinChat = SkinChatFrames

local chatWatch = CreateFrame("Frame")
chatWatch:RegisterEvent("PLAYER_LOGIN")
chatWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
chatWatch:SetScript("OnEvent", function(self, event)
    SkinChatFrames()
    C_Timer.After(1.5, SkinChatFrames)
end)
