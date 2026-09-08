-------------------------------------------------------------------------------
--  EllesmereUI_ShestakSkin - Core/Init.lua
--  ShestakUI 极简美术风格独立适配层：初始化与媒体注入
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local SK = {}
_G.EllesmereUI_ShestakSkin = SK
ns.SK = SK

-- 基础路径与媒体常量
SK.AddonPath = "Interface\\AddOns\\" .. ADDON_NAME .. "\\"
SK.Texture = SK.AddonPath .. "Media\\Texture.tga"
SK.Blank = SK.AddonPath .. "Media\\Blank.tga"
SK.FontPixel = SK.AddonPath .. "Media\\Pixel.ttf"

-- 经典 Shestak 颜色基准
SK.BorderColor = { 0, 0, 0, 1 }             -- 经典 1px 黑色像素边框
SK.BackdropColor = { 0.05, 0.05, 0.05, 0.85 } -- 高对比度暗黑半透明底色

-- 调试日志输出（默认开启关键提示，便于用户验证插件是否正常运行）
SK.Debug = true
function SK:Log(fmt, ...)
    if self.Debug then
        print("|cff00ffff[ShestakSkin]|r " .. string.format(fmt, ...))
    end
end

-- 注册材质与字体至 LibSharedMedia-3.0
local function RegisterMedia()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        LSM:Register("statusbar", "ShestakUI Flat", SK.Texture)
        LSM:Register("font", "ShestakUI Pixel", SK.FontPixel)
        SK:Log("已注册材质与字体至 LibSharedMedia-3.0")
    end
end

-- 拦截 EllesmereUI 全局状态条材质解析器，全局无侵入强制返回 Flat 纹理
local function HookTextureResolver()
    if _G.EllesmereUI and _G.EllesmereUI.ResolveTexturePath then
        if not _G.EllesmereUI._shetsakHooked then
            _G.EllesmereUI._shetsakHooked = true
            local origResolve = _G.EllesmereUI.ResolveTexturePath
            _G.EllesmereUI.ResolveTexturePath = function(texTable, key, fallback)
                return SK.Texture
            end
            SK:Log("已拦截 EllesmereUI 全局材质解析器 -> 切换为 Flat 纯平材质")
        end
    end
end

-- 安全兼容并防御暴雪/插件底层 StartSizing 传参错误 (自动拦截如 OnDragStart 的 "LeftButton" 等非法值)
local function InstallStartSizingGuard()
    local testFrame = CreateFrame("Frame")
    local frameMeta = getmetatable(testFrame) and getmetatable(testFrame).__index
    if frameMeta and type(frameMeta.StartSizing) == "function" and not frameMeta._shestakGuardInstalled then
        frameMeta._shestakGuardInstalled = true
        local origStartSizing = frameMeta.StartSizing
        local validPoints = {
            ["BOTTOMRIGHT"] = true,
            ["BOTTOMLEFT"] = true,
            ["TOPRIGHT"] = true,
            ["TOPLEFT"] = true,
            ["BOTTOM"] = true,
            ["TOP"] = true,
            ["LEFT"] = true,
            ["RIGHT"] = true,
        }
        frameMeta.StartSizing = function(self, resizePoint, alwaysStartFromMouse)
            -- 若 resizePoint 传入了鼠标按键名 (例如 "LeftButton") 或非法值，自动修正并记录调试日志
            if resizePoint and not validPoints[resizePoint] then
                SK:Log("【StartSizing 来源捕获】框体: %s, 传入非法参数: %s (已自动安全修复为 BOTTOMRIGHT)", self:GetName() or tostring(self), tostring(resizePoint))
                resizePoint = "BOTTOMRIGHT"
            end
            return origStartSizing(self, resizePoint, alwaysStartFromMouse)
        end
    end
end
InstallStartSizingGuard()
-- 注册斜杠调试命令 /sskin 与 /shestakskin
SLASH_SHESTAKSKIN1 = "/sskin"
SLASH_SHESTAKSKIN2 = "/shestakskin"
SlashCmdList["SHESTAKSKIN"] = function(msg)
    print("|cff00ffff[ShestakSkin]|r 正在手动执行全界面美化扫描...")
    if SK.SkinAllUnitFrames then SK:SkinAllUnitFrames() end
    if SK.SkinActionBars then SK:SkinActionBars() end
    if SK.SkinNameplates then SK:SkinNameplates() end
    if SK.SkinMinimap then SK:SkinMinimap() end
    if SK.SkinChat then SK:SkinChat() end
    print("|cff00ffff[ShestakSkin]|r 扫描美化完成！")
end

-- 插件事件监听
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            RegisterMedia()
            SK:Log("插件核心已载入 (v1.0.1)")
        elseif arg1 == "EllesmereUI" then
            HookTextureResolver()
        end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        RegisterMedia()
        HookTextureResolver()
    end
end)
