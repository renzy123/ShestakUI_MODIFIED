-------------------------------------------------------------------------------
--  EllesmereUI_ShestakSkin - Modules/Nameplates.lua
--  姓名板模块美化：纯平 Flat 材质、1px 黑色硬边框与光环图标正方形裁切
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local SK = ns.SK

-- 美化单个姓名板（支持 EllesmereUINameplates 与原生系统姓名板）
local function SkinNamePlate(nameplate)
    if not nameplate then return end

    -- 1. 处理 EllesmereUINameplates 内部结构
    local plate = nameplate.UnitFrame or nameplate
    if plate.health and plate.health.SetStatusBarTexture and not plate.health._shetsakSkinned then
        plate.health:SetStatusBarTexture(SK.Texture)
        SK:CreatePixelBorder(plate.health)
        plate.health._shetsakSkinned = true
    end

    if plate.cast and plate.cast.SetStatusBarTexture and not plate.cast._shetsakSkinned then
        plate.cast:SetStatusBarTexture(SK.Texture)
        SK:CreatePixelBorder(plate.cast)
        -- 施法图标
        if plate.cast.icon then
            SK:CropIcon(plate.cast.icon)
            SK:CreatePixelBorder(plate.cast.icon:GetParent() or plate.cast)
        end
        plate.cast._shetsakSkinned = true
    end

    -- 2. 处理原生暴雪姓名板结构 (备用兜底)
    if nameplate.UnitFrame then
        local uf = nameplate.UnitFrame
        if uf.healthBar and uf.healthBar.SetStatusBarTexture and not uf.healthBar._shetsakSkinned then
            uf.healthBar:SetStatusBarTexture(SK.Texture)
            SK:CreatePixelBorder(uf.healthBar)
            uf.healthBar._shetsakSkinned = true
        end
        if uf.castBar and uf.castBar.SetStatusBarTexture and not uf.castBar._shetsakSkinned then
            uf.castBar:SetStatusBarTexture(SK.Texture)
            SK:CreatePixelBorder(uf.castBar)
            if uf.castBar.Icon then
                SK:CropIcon(uf.castBar.Icon)
            end
            uf.castBar._shetsakSkinned = true
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
