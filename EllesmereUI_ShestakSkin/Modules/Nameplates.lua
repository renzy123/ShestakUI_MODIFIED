-------------------------------------------------------------------------------
--  EllesmereUI_ShestakSkin - Modules/Nameplates.lua
--  姓名板模块美化：纯平 Flat 材质、1px 黑色硬边框与光环图标正方形裁切
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local SK = ns.SK

-- 强制锁定状态条材质为 Shestak 材质，防御暴雪原生更新与重用时回退为默认材质
local function EnforceStatusBarTexture(bar, targetTexture)
    if not bar or not bar.SetStatusBarTexture then return end

    -- 1. 立即设置一次状态条材质
    bar:SetStatusBarTexture(targetTexture)

    -- 2. 挂载安全钩子，防止暴雪原生逻辑（如 CompactUnitFrame / NamePlateDriver）再次将其改写回默认材质
    if not bar._shetsakTexHooked then
        bar._shetsakTexHooked = true
        hooksecurefunc(bar, "SetStatusBarTexture", function(self, texture)
            if texture ~= targetTexture then
                self:SetStatusBarTexture(targetTexture)
            end
        end)
    end

    -- 3. 兼容魔兽世界 11.0+ 暴雪 NamePlateHealthBar 的内部 barTexture 与 Atlas
    local fillTex = bar.barTexture or (bar.GetStatusBarTexture and bar:GetStatusBarTexture())
    if fillTex and not fillTex._shetsakTexHooked then
        fillTex._shetsakTexHooked = true
        if fillTex.SetTexture then
            hooksecurefunc(fillTex, "SetTexture", function(self, tex)
                if tex ~= targetTexture then
                    self:SetTexture(targetTexture)
                end
            end)
        end
        if fillTex.SetAtlas then
            hooksecurefunc(fillTex, "SetAtlas", function(self)
                self:SetTexture(targetTexture)
            end)
        end
    end
end

-- 获取暴雪原生姓名板的生命条（兼容 11.0+ HealthBarsContainer 与传统 healthBar）
local function GetBlizzardHealthBar(uf)
    if not uf then return nil end
    return (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar) or uf.healthBar
end

-- 获取暴雪原生姓名板的施法条（兼容 11.0+ CastBarsContainer 与传统 castBar）
local function GetBlizzardCastBar(uf)
    if not uf then return nil end
    return (uf.CastBarsContainer and uf.CastBarsContainer.castBar) or uf.castBar
end

-- 美化单个姓名板（支持 EllesmereUINameplates 与原生系统姓名板）
local function SkinNamePlate(nameplate)
    if not nameplate then return end

    -- 1. 处理 EllesmereUINameplates 内部结构
    local plate = nameplate.UnitFrame or nameplate
    if plate.health and plate.health.SetStatusBarTexture then
        EnforceStatusBarTexture(plate.health, SK.Texture)
        if not plate.health._shetsakBordered then
            SK:CreatePixelBorder(plate.health)
            plate.health._shetsakBordered = true
        end
    end

    if plate.cast and plate.cast.SetStatusBarTexture then
        EnforceStatusBarTexture(plate.cast, SK.Texture)
        if not plate.cast._shetsakBordered then
            SK:CreatePixelBorder(plate.cast)
            plate.cast._shetsakBordered = true
        end
        -- 施法图标
        if plate.cast.icon and not plate.cast.icon._shetsakBordered then
            SK:CropIcon(plate.cast.icon)
            SK:CreatePixelBorder(plate.cast.icon:GetParent() or plate.cast)
            plate.cast.icon._shetsakBordered = true
        end
    end

    -- 2. 处理原生暴雪姓名板结构 (覆盖友方或副本中未被 Ellesmere 接管的原生姓名板)
    if nameplate.UnitFrame then
        local uf = nameplate.UnitFrame
        local blizzHp = GetBlizzardHealthBar(uf)
        if blizzHp and blizzHp.SetStatusBarTexture then
            EnforceStatusBarTexture(blizzHp, SK.Texture)
            if not blizzHp._shetsakBordered then
                SK:CreatePixelBorder(blizzHp)
                blizzHp._shetsakBordered = true
            end
        end

        local blizzCast = GetBlizzardCastBar(uf)
        if blizzCast and blizzCast.SetStatusBarTexture then
            EnforceStatusBarTexture(blizzCast, SK.Texture)
            if not blizzCast._shetsakBordered then
                SK:CreatePixelBorder(blizzCast)
                blizzCast._shetsakBordered = true
            end
            local icon = blizzCast.Icon or (blizzCast.icon)
            if icon and not icon._shetsakBordered then
                SK:CropIcon(icon)
                icon._shetsakBordered = true
            end
        end
    end
end

-- 扫描当前屏幕上所有活跃的姓名板
local function SkinActiveNameplates()
    local plates = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates()
    if plates then
        for _, plate in ipairs(plates) do
            SkinNamePlate(plate)
        end
    end
end
SK.SkinNameplates = SkinActiveNameplates

-- 钩取光环容器的图标创建 (EllesmereUINameplates 光环)
local function HookNameplateAuras()
    local npAuras = _G.EllesmereUINameplates_AuraContainers
    if npAuras and npAuras.CreateAuraIcon then
        hooksecurefunc(npAuras, "CreateAuraIcon", function(icon)
            if icon and icon.texture then
                SK:CropIcon(icon.texture)
                SK:CreatePixelBorder(icon)
            end
        end)
    end
end

-- 事件驱动监听姓名板生成
local npFrame = CreateFrame("Frame")
npFrame:RegisterEvent("NAME_PLATE_CREATED")
npFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
npFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
npFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "NAME_PLATE_CREATED" then
        -- NAME_PLATE_CREATED 事件的第 1 个参数即为刚创建的 nameplate 框体对象自身
        if arg1 and type(arg1) == "table" then
            SkinNamePlate(arg1)
        end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        -- NAME_PLATE_UNIT_ADDED 事件的第 1 个参数为 unitToken 字符串 (例如 "nameplate1")
        if type(arg1) == "string" and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
            local plate = C_NamePlate.GetNamePlateForUnit(arg1)
            if plate then
                SkinNamePlate(plate)
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        SkinActiveNameplates()
        HookNameplateAuras()
    end
end)
