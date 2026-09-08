-------------------------------------------------------------------------------
--  EllesmereUI_ShestakSkin - Modules/Minimap.lua
--  小地图模块美化：1px 黑色像素边框与方形纯平底板
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local SK = ns.SK

local function SkinMinimap()
    if not Minimap or Minimap._shetsakSkinned then return end

    -- 隐藏暴雪圆形花边及冗余纹理
    local blizzTextures = {
        "MinimapBorder",
        "MinimapBorderTop",
        "MinimapZoneTextButton",
        "MiniMapWorldMapButton",
        "MinimapNorthTag",
    }
    for _, texName in ipairs(blizzTextures) do
        local tex = _G[texName]
        if tex then
            tex:SetAlpha(0)
        end
    end

    -- 为小地图自身挂载 1px 黑色像素边框
    SK:CreatePixelBorder(Minimap)

    -- 如果存在 EllesmereUIMinimap 的外层容器，也挂载边框
    local euiMinimap = _G["EllesmereUIMinimap"] or (MinimapCluster and MinimapCluster.MinimapContainer)
    if euiMinimap and euiMinimap ~= Minimap then
        SK:CreatePixelBorder(euiMinimap)
    end

    Minimap._shetsakSkinned = true
end
SK.SkinMinimap = SkinMinimap

local mapFrame = CreateFrame("Frame")
mapFrame:RegisterEvent("PLAYER_LOGIN")
mapFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mapFrame:SetScript("OnEvent", function(self, event)
    SkinMinimap()
    C_Timer.After(1.0, SkinMinimap)
end)

