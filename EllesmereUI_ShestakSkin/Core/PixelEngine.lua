-------------------------------------------------------------------------------
--  EllesmereUI_ShestakSkin - Core/PixelEngine.lua
--  ShestakUI 核心像素引擎：1px 纯黑像素边框、图标正方形裁切与状态条渲染
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local SK = ns.SK

-- 像素对齐缩放因子计算
local mult = 1
local function GetPixelScale()
    local screenHeight = select(2, GetPhysicalScreenSize())
    local uiScale = UIParent:GetEffectiveScale()
    if screenHeight and screenHeight > 0 and uiScale and uiScale > 0 then
        mult = (768 / screenHeight) / uiScale
    else
        mult = 1
    end
    return mult
end

-- 检查对象是否为有效的 WoW UIFrame 实例
local function IsUIFrame(obj)
    return type(obj) == "table" and type(obj.GetObjectType) == "function" and type(obj.GetFrameLevel) == "function"
end

-- 为目标框体创建无缝置顶的 1px 纯黑像素边框 (基于 4 条 1px 独立线段，防撕裂且高稳定性)
function SK:CreatePixelBorder(frame, r, g, b, a)
    if not IsUIFrame(frame) then return end
    if frame._shetsakBorder then return frame._shetsakBorder end

    r = r or SK.BorderColor[1]
    g = g or SK.BorderColor[2]
    b = b or SK.BorderColor[3]
    a = a or SK.BorderColor[4]

    local bdr = CreateFrame("Frame", nil, frame)
    bdr:SetAllPoints(frame)
    bdr:SetFrameLevel(math.max(frame:GetFrameLevel() + 5, 1))

    local scale = GetPixelScale()

    -- 顶线
    local top = bdr:CreateTexture(nil, "OVERLAY", nil, 7)
    top:SetTexture(SK.Blank)
    top:SetVertexColor(r, g, b, a)
    top:SetPoint("TOPLEFT", bdr, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", bdr, "TOPRIGHT", 0, 0)
    top:SetHeight(scale)

    -- 底线
    local bottom = bdr:CreateTexture(nil, "OVERLAY", nil, 7)
    bottom:SetTexture(SK.Blank)
    bottom:SetVertexColor(r, g, b, a)
    bottom:SetPoint("BOTTOMLEFT", bdr, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", bdr, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(scale)

    -- 左线
    local left = bdr:CreateTexture(nil, "OVERLAY", nil, 7)
    left:SetTexture(SK.Blank)
    left:SetVertexColor(r, g, b, a)
    left:SetPoint("TOPLEFT", bdr, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", bdr, "BOTTOMLEFT", 0, 0)
    left:SetWidth(scale)

    -- 右线
    local right = bdr:CreateTexture(nil, "OVERLAY", nil, 7)
    right:SetTexture(SK.Blank)
    right:SetVertexColor(r, g, b, a)
    right:SetPoint("TOPRIGHT", bdr, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", bdr, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(scale)

    bdr.lines = { top, bottom, left, right }

    function bdr:SetColor(cr, cg, cb, ca)
        for _, line in ipairs(self.lines) do
            line:SetVertexColor(cr, cg, cb, ca or 1)
        end
    end

    frame._shetsakBorder = bdr
    return bdr
end

-- 创建经典暗黑半透明背景 + 1px 像素边框
function SK:CreateBackdrop(frame, bgAlpha)
    if not IsUIFrame(frame) then return end
    if frame._shetsakBackdrop then return frame._shetsakBackdrop end

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetAllPoints(frame)
    bg:SetTexture(SK.Blank)
    local col = SK.BackdropColor
    bg:SetVertexColor(col[1], col[2], col[3], bgAlpha or col[4])
    frame._shetsakBackdrop = bg

    -- 挂载 1px 边框
    self:CreatePixelBorder(frame)
    return bg
end

-- 正方形裁切图标 (剔除暴雪默认圆角与灰框)
function SK:CropIcon(icon)
    if not icon or not icon.SetTexCoord then return end
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

-- 动作条/功能按钮通用美化
function SK:SkinButton(button)
    if not button or button._shetsakSkinned then return end

    -- 裁切主图标
    local icon = button.icon or button.Icon or (button.GetName and _G[button:GetName() .. "Icon"])
    if icon then
        self:CropIcon(icon)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    end

    -- 隐藏浮雕正常态纹理
    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal then
        normal:SetAlpha(0)
        normal:SetTexture(nil)
    end

    -- 隐藏浮雕边框
    local border = button.Border or (button.GetName and _G[button:GetName() .. "Border"])
    if border then
        border:SetAlpha(0)
    end

    -- 挂载暗色底图与 1px 边框
    local bg = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints(button)
    bg:SetTexture(SK.Blank)
    bg:SetVertexColor(SK.BackdropColor[1], SK.BackdropColor[2], SK.BackdropColor[3], 1)

    self:CreatePixelBorder(button)

    -- 美化高亮与按下态
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if highlight then
        highlight:SetColorTexture(1, 1, 1, 0.3)
    end

    local pushed = button.GetPushedTexture and button:GetPushedTexture()
    if pushed then
        pushed:SetColorTexture(0.9, 0.8, 0.1, 0.3)
    end

    button._shetsakSkinned = true
end

-- 状态条纯平材质与像素边框美化
function SK:SkinStatusBar(bar)
    if not bar or bar._shetsakSkinned then return end
    if bar.SetStatusBarTexture then
        bar:SetStatusBarTexture(SK.Texture)
    end
    self:CreatePixelBorder(bar)
    bar._shetsakSkinned = true
end
