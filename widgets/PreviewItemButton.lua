local addonName, addon = ...

--<GLOBALS
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local GetItemInfo = _G.GetItemInfo
local GetItemQualityColor = _G.GetItemQualityColor
local ITEM_QUALITY_POOR = _G.ITEM_QUALITY_POOR
local ITEM_QUALITY_UNCOMMON = _G.ITEM_QUALITY_UNCOMMON
local NumberFontNormal = _G.NumberFontNormal
local select = _G.select
local setmetatable = _G.setmetatable
--GLOBALS>

local ITEM_SIZE = addon.ITEM_SIZE

local buttonClass, buttonProto = addon:NewClass("PreviewItemButton", "Button")
local AceEvent = LibStub("AceEvent-3.0")
buttonProto.RegisterMessage = AceEvent.RegisterMessage
buttonProto.UnregisterMessage = AceEvent.UnregisterMessage
buttonProto.UnregisterAllMessages = AceEvent.UnregisterAllMessages

function buttonClass:Create()
	self.serial = self.serial + 1
	local button = setmetatable(CreateFrame("Button"), self.metatable)
	button:ClearAllPoints()
	button:Hide()
	addon.safecall(button, "OnCreate")
	return button
end

function buttonProto:ToString()
	return "PreviewButton"
end

local function Button_OnEnter(self)
	local link = self.itemLink
	if not link then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetHyperlink(link)
	GameTooltip:Show()
end

local function Button_OnLeave(self)
	if GameTooltip:GetOwner() == self then
		GameTooltip:Hide()
	end
end

function buttonProto:OnCreate()
	self.preview = true
	self.bag, self.slot = nil, nil

	self:SetWidth(ITEM_SIZE)
	self:SetHeight(ITEM_SIZE)
	self:EnableMouse(true)

	local icon = self:CreateTexture(nil, "BACKGROUND")
	icon:SetAllPoints(self)
	self.IconTexture = icon

	local border = self:CreateTexture(nil, "ARTWORK")
	border:SetAllPoints(self)
	border:Hide()
	self.IconQuestTexture = border

	local normal = self:CreateTexture(nil, "OVERLAY")
	normal:SetTexture([[Interface\Buttons\UI-Quickslot2]])
	normal:SetPoint("CENTER")
	normal:SetWidth(ITEM_SIZE * 64 / 37)
	normal:SetHeight(ITEM_SIZE * 64 / 37)
	self.NormalTexture = normal

	local highlight = self:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints(self)
	highlight:SetTexture([[Interface\Buttons\ButtonHilight-Square]])
	highlight:SetBlendMode("ADD")

	local count = self:CreateFontString(nil, "OVERLAY")
	count:SetJustifyH("RIGHT")
	self.Count = count

	local stock = self:CreateFontString(nil, "OVERLAY", "NumberFontNormalYellow")
	stock:SetPoint("TOPLEFT", 2, -2)
	stock:Hide()
	self.Stock = stock

	self:SetScript("OnEnter", Button_OnEnter)
	self:SetScript("OnLeave", Button_OnLeave)
	self:SetScript("OnShow", self.OnShow)
	self:SetScript("OnHide", self.OnHide)

	self:UpdateCountAppearance()
end

function buttonProto:UpdateCountAppearance()
	local text = self.Count
	if not text or not addon.db then
		return
	end
	local db = addon.db.profile
	text:SetFontObject(addon.countFont)
	text:ClearAllPoints()
	text:SetPoint(db.countAnchor, self, db.countOffsetX, db.countOffsetY)
end

function buttonProto:OnAcquire(container, slotData)
	self.container = container
	self.bag, self.slot = nil, nil
	self.slotData = slotData
	self:SetParent(container)
	-- SetParent не пересчитывает уровень: без явного подъёма кнопка остаётся вровень с
	-- ClickReceiver окна и тот перехватывает наведение, убивая подсказки
	self:SetFrameLevel(container:GetFrameLevel() + 3)
	self:FullUpdate()
end

function buttonProto:OnRelease()
	self:SetSection(nil)
	self.container = nil
	self.slotData = nil
	self.itemId = nil
	self.itemLink = nil
	self.hasItem = nil
	self.texture = nil
	self.bagFamily = nil
	self.itemQuality = nil
	self.count = nil
end

function buttonProto:OnShow()
	self:RegisterMessage("AdiBags_UpdateAllButtons", "Update")
	self:FullUpdate()
end

function buttonProto:OnHide()
	self:UnregisterAllMessages()
end

--------------------------------------------------------------------------------
-- Model data
--------------------------------------------------------------------------------

function buttonProto:SetSection(section)
	local oldSection = self.section
	if oldSection ~= section then
		if oldSection then
			oldSection:RemoveItemButton(self)
		end
		self.section = section
		return true
	end
end

function buttonProto:GetSection()
	return self.section
end

function buttonProto:GetItemId()
	return self.itemId
end

function buttonProto:GetItemLink()
	return self.itemLink
end

function buttonProto:GetCount()
	return self.count or 0
end

function buttonProto:GetItemQuality()
	local quality = self.itemQuality
	if quality == nil and self.itemId then
		quality = select(3, GetItemInfo(self.itemId))
		self.itemQuality = quality
	end
	return quality
end

function buttonProto:GetBagFamily()
	return self.bagFamily
end

function buttonProto:IsBank()
	return not not (self.slotData and self.slotData.isBank)
end

function buttonProto:IsStack()
	return false
end

function buttonProto:GetRealButton()
	return self
end

local function NoSlots()
	return nil
end

function buttonProto:IterateSlots()
	return NoSlots, self
end

--------------------------------------------------------------------------------
-- Display
--------------------------------------------------------------------------------

function buttonProto:CanUpdate()
	if not self:IsVisible() or addon.holdYourBreath then
		return false
	end
	return true
end

function buttonProto:FullUpdate()
	local slotData = self.slotData
	if slotData then
		self.itemId = slotData.itemId
		self.itemLink = slotData.link or nil
		self.texture = slotData.texture
		self.count = slotData.count or 0
		self.bagFamily = slotData.bagFamily or 0
	else
		self.itemId, self.itemLink, self.texture, self.count, self.bagFamily = nil, nil, nil, 0, 0
	end
	self.hasItem = not not self.itemId
	self.itemQuality = nil
	self:Update()
end

function buttonProto:Update()
	if not self:CanUpdate() then
		return
	end

	local icon = self.IconTexture
	icon:SetVertexColor(1, 1, 1)
	if self.texture then
		icon:SetTexture(self.texture)
		icon:SetTexCoord(0, 1, 0, 1)
	else
		icon:SetTexture([[Interface\BUTTONS\UI-EmptySlot]])
		icon:SetTexCoord(12 / 64, 51 / 64, 12 / 64, 51 / 64)
	end

	local tag = (not self.itemId or addon.db.profile.showBagType) and addon:GetFamilyTag(self.bagFamily)
	if tag then
		self.Stock:SetText(tag)
		self.Stock:Show()
	else
		self.Stock:Hide()
	end

	self:UpdateCount()
	self:UpdateBorder()

	addon:SendMessage("AdiBags_UpdateButton", self)
end

function buttonProto:UpdateCount()
	local count = self:GetCount()
	if count > 1 then
		self.Count:SetText(count)
		self.Count:Show()
	else
		self.Count:Hide()
	end
end

function buttonProto:UpdateBorder()
	if self.hasItem and addon.db.profile.qualityHighlight then
		local quality = self:GetItemQuality()
		local border = self.IconQuestTexture
		if quality and quality >= ITEM_QUALITY_UNCOMMON then
			local r, g, b = GetItemQualityColor(quality)
			border:SetTexture([[Interface\Buttons\UI-ActionButton-Border]])
			border:SetVertexColor(r, g, b, addon.db.profile.qualityOpacity)
			border:SetTexCoord(14 / 64, 49 / 64, 15 / 64, 50 / 64)
			border:SetBlendMode("ADD")
			border:Show()
			return
		elseif quality == ITEM_QUALITY_POOR and addon.db.profile.dimJunk then
			local v = 1 - 0.5 * addon.db.profile.qualityOpacity
			border:SetVertexColor(1, 1, 1, 1)
			border:SetTexture(v, v, v)
			border:SetTexCoord(0, 1, 0, 1)
			border:SetBlendMode("MOD")
			border:Show()
			return
		end
	end
	self.IconQuestTexture:Hide()
end

--------------------------------------------------------------------------------
-- Pool
--------------------------------------------------------------------------------

local previewButtonPool = addon:CreatePool(buttonClass, "AcquirePreviewItemButton")

function addon:UpdatePreviewCountAppearance()
	for button in previewButtonPool:IterateActiveObjects() do
		button:UpdateCountAppearance()
	end
end
