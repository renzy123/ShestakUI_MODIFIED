local _, ns = ...
local oUF = ns.oUF

local function UpdateTooltip(self)
	if(GameTooltip:IsForbidden()) then return end

	if(self.isHarmful) then
		GameTooltip:SetUnitDebuffByAuraInstanceID(self:GetParent().__owner.unit, self.auraInstanceID)
	else
		GameTooltip:SetUnitBuffByAuraInstanceID(self:GetParent().__owner.unit, self.auraInstanceID)
	end
end

local function onEnter(self)
	if(GameTooltip:IsForbidden() or not self:IsVisible()) then return end

	-- Avoid parenting GameTooltip to frames with anchoring restrictions,
	-- otherwise it'll inherit said restrictions which will cause issues with
	-- its further positioning, clamping, etc
	GameTooltip:SetOwner(self, self:GetParent().__restricted and 'ANCHOR_CURSOR' or self:GetParent().tooltipAnchor)
	self:UpdateTooltip()
end

local function onLeave()
	if(GameTooltip:IsForbidden()) then return end

	GameTooltip:Hide()
end

local function CreateButton(element, index)
	local button = CreateFrame('Button', element:GetDebugName() .. 'Button' .. index, element)

	local cd = CreateFrame('Cooldown', '$parentCooldown', button, 'CooldownFrameTemplate')
	cd:SetAllPoints()
	cd:SetDrawEdge(false) -- ShestakUI
	button.Cooldown = cd

	local icon = button:CreateTexture(nil, 'BORDER')
	icon:SetAllPoints()
	button.Icon = icon

	local countFrame = CreateFrame('Frame', nil, button)
	countFrame:SetAllPoints(button)
	countFrame:SetFrameLevel(cd:GetFrameLevel() + 1)

	local count = countFrame:CreateFontString(nil, 'OVERLAY', 'NumberFontNormal')
	count:SetPoint('BOTTOMRIGHT', countFrame, 'BOTTOMRIGHT', -1, 0)
	button.Count = count

	local overlay = button:CreateTexture(nil, 'OVERLAY')
	overlay:SetTexture([[Interface\Buttons\UI-Debuff-Overlays]])
	overlay:SetAllPoints()
	overlay:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
	button.Overlay = overlay

	local stealable = button:CreateTexture(nil, 'OVERLAY')
	stealable:SetTexture([[Interface\TargetingFrame\UI-TargetingFrame-Stealable]])
	stealable:SetPoint('TOPLEFT', -3, 3)
	stealable:SetPoint('BOTTOMRIGHT', 3, -3)
	stealable:SetBlendMode('ADD')
	button.Stealable = stealable

	button.UpdateTooltip = UpdateTooltip
	button:SetScript('OnEnter', onEnter)
	button:SetScript('OnLeave', onLeave)

	--[[ Callback: Auras:PostCreateButton(button)
	Called after a new aura button has been created.

	* self   - the widget holding the aura buttons
	* button - the newly created aura button (Button)
	--]]
	if(element.PostCreateButton) then element:PostCreateButton(button) end

	return button
end

local function SetPosition(element, from, to)
	local width = element.width or element.size or 16
	local height = element.height or element.size or 16
	local sizex = width + (element['spacing-x'] or element.spacing or 0)
	local sizey = height + (element['spacing-y'] or element.spacing or 0)
	local anchor = element.initialAnchor or 'BOTTOMLEFT'
	local growthx = (element['growth-x'] == 'LEFT' and -1) or 1
	local growthy = (element['growth-y'] == 'DOWN' and -1) or 1
	local cols = math.floor(element:GetWidth() / sizex + 0.5)

	for i = from, to do
		local button = element[i]
		if(not button) then break end

		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)

		button:ClearAllPoints()
		button:SetPoint(anchor, element, anchor, col * sizex * growthx, row * sizey * growthy)
	end
end

local function updateAura(element, unit, data, position)
	if(not data.name) then return end

	local button = element[position]
	if(not button) then
		--[[ Override: Auras:CreateButton(position)
		Used to create an aura button at a given position.

		* self     - the widget holding the aura buttons
		* position - the position at which the aura button is to be created (number)

		## Returns

		* button - the button used to represent the aura (Button)
		--]]
		button = (element.CreateButton or CreateButton) (element, position)

		table.insert(element, button)
		element.createdButtons = element.createdButtons + 1
	end

	-- for tooltips
	button.auraInstanceID = data.auraInstanceID
	button.isHarmful = data.isHarmful

	if(button.Cooldown and not element.disableCooldown) then
		if(data.duration > 0) then
			button.Cooldown:SetCooldown(data.expirationTime - data.duration, data.duration, data.timeMod)
			button.Cooldown:Show()
		else
			button.Cooldown:Hide()
		end
	end

	if(button.Overlay) then
		if((data.isHarmful and element.showDebuffType) or (not data.isHarmful and element.showBuffType) or element.showType) then
			local color = element.__owner.colors.debuff[data.dispelName] or element.__owner.colors.debuff.none

			button.Overlay:SetVertexColor(color[1], color[2], color[3])
			button.Overlay:Show()
		else
			button.Overlay:Hide()
		end
	end

	if(button.Stealable) then
		if(not data.isHarmful and data.isStealable and element.showStealableBuffs and not UnitIsUnit('player', unit)) then
			button.Stealable:Show()
		else
			button.Stealable:Hide()
		end
	end

	if(button.Icon) then button.Icon:SetTexture(data.icon) end
	if(button.Count) then button.Count:SetText(data.applications > 1 and data.applications or '') end

	local width = element.width or element.size or 16
	local height = element.height or element.size or 16
	button:SetSize(width, height)
	button:EnableMouse(not element.disableMouse)
	button:Show()

	--[[ Callback: Auras:PostUpdateButton(unit, button, data, position)
	Called after the aura button has been updated.

	* self     - the widget holding the aura buttons
	* button   - the updated aura button (Button)
	* unit     - the unit on which the aura is cast (string)
	* data     - the [UnitAuraInfo](https://wowpedia.fandom.com/wiki/Struct_UnitAuraInfo) object (table)
	* position - the actual position of the aura button (number)
	--]]
	if(element.PostUpdateButton) then
		element:PostUpdateButton(button, unit, data, position)
	end
end

local function FilterAura(element, unit, data)
	if((element.onlyShowPlayer and data.isPlayerAura) or (not element.onlyShowPlayer and data.name)) then
		return true
	end
end

-- see AuraUtil.DefaultAuraCompare
local function SortAuras(a, b)
	if(a.isPlayerAura ~= b.isPlayerAura) then
		return a.isPlayerAura
	end

	if(a.canApplyAura ~= b.canApplyAura) then
		return a.canApplyAura
	end

	return a.auraInstanceID < b.auraInstanceID
end

local function processData(data)
	if(not data) then return end

	data.isPlayerAura = data.sourceUnit and (UnitIsUnit('player', data.sourceUnit) or UnitIsOwnerOrControllerOfUnit('player', data.sourceUnit))

	return data
end

local function UpdateAuras(self, event, unit)
	if(self.unit ~= unit) then return end

	-- 1. 复合光环框架 (Auras: Buffs + Debuffs)
	local auras = self.Auras
	if(auras) then
		if(auras.PreUpdate) then auras:PreUpdate(unit) end

		local numBuffs = auras.numBuffs or 32
		local buffFilter = auras.buffFilter or auras.filter or 'HELPFUL'
		if(type(buffFilter) == 'function') then
			buffFilter = buffFilter(auras, unit)
		end

		local numDebuffs = auras.numDebuffs or 40
		local debuffFilter = auras.debuffFilter or auras.filter or 'HARMFUL'
		if(type(debuffFilter) == 'function') then
			debuffFilter = debuffFilter(auras, unit)
		end

		local numTotal = auras.numTotal or numBuffs + numDebuffs

		auras.activeBuffs = table.wipe(auras.activeBuffs or {})
		auras.sortedBuffs = table.wipe(auras.sortedBuffs or {})
		numBuffs = math.min(numBuffs, numTotal)

		-- 采用全量槽位刷新，彻底避免读取 12.1.0 加密的 updateInfo (Secret Value)
		local slots = {UnitAuraSlots(unit, buffFilter)}
		if(slots[2]) then
			local count = 1
			for i = 2, #slots do
				if count <= numBuffs then
					local data = processData(C_UnitAuras.GetAuraDataBySlot(unit, slots[i]))
					if((auras.FilterAura or FilterAura)(auras, unit, data)) then
						auras.activeBuffs[data.auraInstanceID] = data
						table.insert(auras.sortedBuffs, data)
						count = count + 1
					end
				end
			end
		end

		auras.activeDebuffs = table.wipe(auras.activeDebuffs or {})
		auras.sortedDebuffs = table.wipe(auras.sortedDebuffs or {})
		numDebuffs = math.min(numDebuffs, numTotal - #auras.sortedBuffs)

		slots = {UnitAuraSlots(unit, debuffFilter)}
		if(slots[2]) then
			local count = 1
			for i = 2, #slots do
				if count <= numDebuffs then
					local data = processData(C_UnitAuras.GetAuraDataBySlot(unit, slots[i]))
					if((auras.FilterAura or FilterAura)(auras, unit, data)) then
						auras.activeDebuffs[data.auraInstanceID] = data
						table.insert(auras.sortedDebuffs, data)
						count = count + 1
					end
				end
			end
		end

		table.sort(auras.sortedBuffs, auras.SortBuffs or auras.SortAuras or SortAuras)
		table.sort(auras.sortedDebuffs, auras.SortDebuffs or auras.SortAuras or SortAuras)

		for i = 1, #auras.sortedBuffs do
			updateAura(auras, unit, auras.sortedBuffs[i], i)
		end

		local offset = #auras.sortedBuffs

		if(auras.gap and #auras.sortedBuffs > 0 and #auras.sortedDebuffs > 0) then
			offset = offset + 1
			local button = auras[offset]
			if(not button) then
				button = (auras.CreateButton or CreateButton)(auras, offset)
				table.insert(auras, button)
				auras.createdButtons = auras.createdButtons + 1
			end

			button.auraInstanceID = nil
			button.isBuff = nil
			button.isDebuff = nil

			if(button.Cooldown) then button.Cooldown:Hide() end
			if(button.Icon) then button.Icon:SetTexture() end
			if(button.Overlay) then button.Overlay:Hide() end
			if(button.Stealable) then button.Stealable:Hide() end
			if(button.Count) then button.Count:SetText("") end

			button:EnableMouse(false)
			button:Hide()

			if(auras.PostUpdateGapButton) then
				auras:PostUpdateGapButton(unit, button, offset)
			end
		end

		for i = 1, #auras.sortedDebuffs do
			updateAura(auras, unit, auras.sortedDebuffs[i], i + offset)
		end

		for i = offset + #auras.sortedDebuffs + 1, #auras do
			auras[i]:Hide()
		end

		if(auras.createdButtons > auras.anchoredButtons) then
			(auras.SetPosition or SetPosition)(auras, auras.anchoredButtons + 1, auras.createdButtons)
			auras.anchoredButtons = auras.createdButtons
		end

		if(auras.PostUpdate) then auras:PostUpdate(unit) end
	end

	-- 2. 独立增益框架 (Buffs)
	local buffs = self.Buffs
	if(buffs) then
		if(buffs.PreUpdate) then buffs:PreUpdate(unit) end

		local numBuffs = buffs.num or 32
		local buffFilter = buffs.filter or 'HELPFUL'
		if(type(buffFilter) == 'function') then
			buffFilter = buffFilter(buffs, unit)
		end

		buffs.active = table.wipe(buffs.active or {})
		buffs.sorted = table.wipe(buffs.sorted or {})

		local slots = {UnitAuraSlots(unit, buffFilter)}
		if(slots[2]) then
			local count = 1
			for i = 2, #slots do
				if count <= numBuffs then
					local data = processData(C_UnitAuras.GetAuraDataBySlot(unit, slots[i]))
					if((buffs.FilterAura or FilterAura)(buffs, unit, data)) then
						buffs.active[data.auraInstanceID] = data
						table.insert(buffs.sorted, data)
						count = count + 1
					end
				end
			end
		end

		table.sort(buffs.sorted, buffs.SortBuffs or buffs.SortAuras or SortAuras)

		for i = 1, #buffs.sorted do
			updateAura(buffs, unit, buffs.sorted[i], i)
		end

		for i = #buffs.sorted + 1, #buffs do
			buffs[i]:Hide()
		end

		if(buffs.createdButtons > buffs.anchoredButtons) then
			(buffs.SetPosition or SetPosition)(buffs, buffs.anchoredButtons + 1, buffs.createdButtons)
			buffs.anchoredButtons = buffs.createdButtons
		end

		if(buffs.PostUpdate) then buffs:PostUpdate(unit) end
	end

	-- 3. 独立减益框架 (Debuffs)
	local debuffs = self.Debuffs
	if(debuffs) then
		if(debuffs.PreUpdate) then debuffs:PreUpdate(unit) end

		local numDebuffs = debuffs.num or 40
		local debuffFilter = debuffs.filter or 'HARMFUL'
		if(type(debuffFilter) == 'function') then
			debuffFilter = debuffFilter(debuffs, unit)
		end

		debuffs.active = table.wipe(debuffs.active or {})
		debuffs.sorted = table.wipe(debuffs.sorted or {})

		local slots = {UnitAuraSlots(unit, debuffFilter)}
		if(slots[2]) then
			local count = 1
			for i = 2, #slots do
				if count <= numDebuffs then
					local data = processData(C_UnitAuras.GetAuraDataBySlot(unit, slots[i]))
					if((debuffs.FilterAura or FilterAura)(debuffs, unit, data)) then
						debuffs.active[data.auraInstanceID] = data
						table.insert(debuffs.sorted, data)
						count = count + 1
					end
				end
			end
		end

		table.sort(debuffs.sorted, debuffs.SortDebuffs or debuffs.SortAuras or SortAuras)

		for i = 1, #debuffs.sorted do
			updateAura(debuffs, unit, debuffs.sorted[i], i)
		end

		for i = #debuffs.sorted + 1, #debuffs do
			debuffs[i]:Hide()
		end

		if(debuffs.createdButtons > debuffs.anchoredButtons) then
			(debuffs.SetPosition or SetPosition)(debuffs, debuffs.anchoredButtons + 1, debuffs.createdButtons)
			debuffs.anchoredButtons = debuffs.createdButtons
		end

		if(debuffs.PostUpdate) then debuffs:PostUpdate(unit) end
	end
end

local function Update(self, event, unit)
	if(self.unit ~= unit) then return end

	UpdateAuras(self, event, unit)

	-- 强制更新或初次锚定时重新排版
	if(event == 'ForceUpdate' or not event) then
		local auras = self.Auras
		if(auras) then
			(auras.SetPosition or SetPosition)(auras, 1, auras.createdButtons)
		end

		local buffs = self.Buffs
		if(buffs) then
			(buffs.SetPosition or SetPosition)(buffs, 1, buffs.createdButtons)
		end

		local debuffs = self.Debuffs
		if(debuffs) then
			(debuffs.SetPosition or SetPosition)(debuffs, 1, debuffs.createdButtons)
		end
	end
end

local function ForceUpdate(element)
	return Update(element.__owner, 'ForceUpdate', element.__owner.unit)
end

local function Enable(self)
	if(self.Auras or self.Buffs or self.Debuffs) then
		self:RegisterEvent('UNIT_AURA', UpdateAuras)

		local auras = self.Auras
		if(auras) then
			auras.__owner = self
			-- check if there's any anchoring restrictions
			auras.__restricted = not pcall(self.GetCenter, self)
			auras.ForceUpdate = ForceUpdate

			auras.createdButtons = auras.createdButtons or 0
			auras.anchoredButtons = 0
			auras.tooltipAnchor = auras.tooltipAnchor or 'ANCHOR_BOTTOMRIGHT'

			-- auras:Show() -- ShestakUI
		end

		local buffs = self.Buffs
		if(buffs) then
			buffs.__owner = self
			-- check if there's any anchoring restrictions
			buffs.__restricted = not pcall(self.GetCenter, self)
			buffs.ForceUpdate = ForceUpdate

			buffs.createdButtons = buffs.createdButtons or 0
			buffs.anchoredButtons = 0
			buffs.tooltipAnchor = buffs.tooltipAnchor or 'ANCHOR_BOTTOMRIGHT'

			-- buffs:Show() -- ShestakUI
		end

		local debuffs = self.Debuffs
		if(debuffs) then
			debuffs.__owner = self
			-- check if there's any anchoring restrictions
			debuffs.__restricted = not pcall(self.GetCenter, self)
			debuffs.ForceUpdate = ForceUpdate

			debuffs.createdButtons = debuffs.createdButtons or 0
			debuffs.anchoredButtons = 0
			debuffs.tooltipAnchor = debuffs.tooltipAnchor or 'ANCHOR_BOTTOMRIGHT'

			-- debuffs:Show() -- ShestakUI
		end

		return true
	end
end

local function Disable(self)
	if(self.Auras or self.Buffs or self.Debuffs) then
		self:UnregisterEvent('UNIT_AURA', UpdateAuras)

		if(self.Auras) then self.Auras:Hide() end
		if(self.Buffs) then self.Buffs:Hide() end
		if(self.Debuffs) then self.Debuffs:Hide() end
	end
end

oUF:AddElement('Auras', Update, Enable, Disable)