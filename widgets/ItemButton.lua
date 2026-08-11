local addonName, addon = ...

--<GLOBALS
local _G = _G
local BankButtonIDToInvSlotID = _G.BankButtonIDToInvSlotID
local BANK_CONTAINER = _G.BANK_CONTAINER
local C_Item = _G.C_Item
local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local ContainerFrame_UpdateCooldown = _G.ContainerFrame_UpdateCooldown
local format = _G.format
local GetContainerItemGUID = _G.GetContainerItemGUID
local GetContainerItemID = _G.GetContainerItemID
local GetContainerItemInfo = _G.GetContainerItemInfo
local GetContainerItemLink = _G.GetContainerItemLink
local GetContainerItemQuestInfo = _G.GetContainerItemQuestInfo
local GetContainerNumFreeSlots = _G.GetContainerNumFreeSlots
local GetItemExpirationTimeLeft = _G.GetItemExpirationTimeLeft
local GetItemInfoEx = _G.GetItemInfoEx
local GetItemInfo = _G.GetItemInfo
local GetItemSetInfo = _G.GetItemSetInfo
local GetItemQualityColor = _G.GetItemQualityColor
local GetTime = _G.GetTime
local InboxFrame = _G.InboxFrame
local IsInventoryItemLocked = _G.IsInventoryItemLocked
local ITEM_QUALITY_POOR = _G.ITEM_QUALITY_POOR
local NumberFontNormalSmall = _G.NumberFontNormalSmall
local OpenMailFrame = _G.OpenMailFrame
local ITEM_QUALITY_UNCOMMON = _G.ITEM_QUALITY_UNCOMMON
local KEYRING_CONTAINER = _G.KEYRING_CONTAINER
local next = _G.next
local pairs = _G.pairs
local select = _G.select
local SetItemButtonDesaturated = _G.SetItemButtonDesaturated
local StackSplitFrame = _G.StackSplitFrame
local TEXTURE_ITEM_QUEST_BANG = _G.TEXTURE_ITEM_QUEST_BANG
local TEXTURE_ITEM_QUEST_BORDER = _G.TEXTURE_ITEM_QUEST_BORDER
local tostring = _G.tostring
local wipe = _G.wipe
--GLOBALS>

local GetSlotId = addon.GetSlotId
local GetBagSlotFromId = addon.GetBagSlotFromId

local ITEM_SIZE = addon.ITEM_SIZE

local Masque = LibStub("Masque", true)
local AceTimer = LibStub("AceTimer-3.0")

local setBadgeData = {}
local replacementTiers = {}
local replacementRetryItems = {}
local replacementAttempts = {}
local pendingSetItems = {}
local setBadgeTooltip
local replacementRetryScheduled

local bagFamilyCache = {}

local function GetBagFamily(bag)
	if bag == KEYRING_CONTAINER then
		return 256
	end
	local family = bagFamilyCache[bag]
	if family == nil then
		family = select(2, GetContainerNumFreeSlots(bag))
		bagFamilyCache[bag] = family
	end
	return family
end

local function ScheduleReplacementRetry(itemID)
	if replacementRetryItems[itemID] then
		return
	end

	local attempt = (replacementAttempts[itemID] or 0) + 1
	replacementAttempts[itemID] = attempt
	if attempt >= 3 then
		replacementTiers[itemID] = false
		return
	end
	replacementRetryItems[itemID] = true
	if replacementRetryScheduled then
		return
	end

	replacementRetryScheduled = true
	C_Timer:After(attempt == 1 and 0.5 or 2, function()
		replacementRetryScheduled = nil
		local needsUpdate
		for retryItemID in pairs(replacementRetryItems) do
			replacementRetryItems[retryItemID] = nil
			replacementTiers[retryItemID] = nil
			needsUpdate = true
		end
		if needsUpdate then
			addon:SendMessage("AdiBags_UpdateAllButtons")
		end
	end)
end

local function ScanReplacementTier(item, itemID)
	if not setBadgeTooltip then
		local name = addonName .. "ItemSetBadgeTooltip"
		setBadgeTooltip = CreateFrame("GameTooltip", name, _G.UIParent, "GameTooltipTemplate")
		setBadgeTooltip:SetOwner(_G.UIParent, "ANCHOR_NONE")
	end

	setBadgeTooltip:SetOwner(_G.UIParent, "ANCHOR_NONE")
	setBadgeTooltip:ClearLines()
	setBadgeTooltip:SetHyperlink(item)
	local numLines = setBadgeTooltip:NumLines() or 0
	if numLines == 0 then
		setBadgeTooltip:Hide()
		setBadgeTooltip:ClearLines()
		ScheduleReplacementRetry(itemID)
		return
	end

	local name = setBadgeTooltip:GetName()
	local replacementText, tier
	for index = 1, numLines do
		local line = _G[name .. "TextLeft" .. index]
		local text = line and line:GetText()
		if text and (replacementText or text:find("Замена комплектного предмета", 1, true)) then
			replacementText = replacementText and (replacementText .. " " .. text) or text
			tier = replacementText:match("тира%s*(%d+)%s+с%s+сетбонусами")
			if tier then
				break
			end
		end
	end
	setBadgeTooltip:Hide()
	setBadgeTooltip:ClearLines()

	if tier then
		replacementTiers[itemID] = tier
		replacementRetryItems[itemID] = nil
		replacementAttempts[itemID] = nil
	elseif replacementText then
		ScheduleReplacementRetry(itemID)
	else
		replacementTiers[itemID] = false
		replacementRetryItems[itemID] = nil
		replacementAttempts[itemID] = nil
	end
	return tier
end

local REPLACEMENT_SCAN_BUDGET = 10
local deferredScans = {}
local deferredScanScheduled
local scanBudgetFrame, scanBudgetUsed = 0, 0

local function TakeScanBudget()
	local now = GetTime()
	if now ~= scanBudgetFrame then
		scanBudgetFrame, scanBudgetUsed = now, 0
	end
	if scanBudgetUsed >= REPLACEMENT_SCAN_BUDGET then
		return false
	end
	scanBudgetUsed = scanBudgetUsed + 1
	return true
end

local FlushDeferredScans
function FlushDeferredScans()
	deferredScanScheduled = nil
	for itemID, item in pairs(deferredScans) do
		if not TakeScanBudget() then
			break
		end
		deferredScans[itemID] = nil
		ScanReplacementTier(item, itemID)
	end
	if next(deferredScans) then
		deferredScanScheduled = true
		C_Timer:After(0.02, FlushDeferredScans)
	end
	addon:SendMessage("AdiBags_UpdateAllButtons")
end

local function GetReplacementTier(item, itemID)
	local tier = replacementTiers[itemID]
	if tier ~= nil then
		return tier or nil
	end

	if not TakeScanBudget() and itemID then
		if not deferredScans[itemID] then
			deferredScans[itemID] = item
			if not deferredScanScheduled then
				deferredScanScheduled = true
				C_Timer:After(0.02, FlushDeferredScans)
			end
		end
		return
	end

	return ScanReplacementTier(item, itemID)
end

local function GetSetBadgeData(item, itemID)
	local itemName, _, _, _, _, _, _, _, _, _, _, _, _, _, _, setID = GetItemInfoEx(item)
	if not itemName then
		if itemID then
			pendingSetItems[itemID] = true
			C_Item.GetItemInfo(itemID, true)
		end
		return
	elseif itemID then
		pendingSetItems[itemID] = nil
	end

	if setID and setID ~= 0 then
		local data = setBadgeData[setID]
		if data == nil then
			local name = GetItemSetInfo(setID)
			if not name then
				return
			end

			local tier = name:match("Рейдовый комплект Тир%s*(%d+)")
			if tier then
				data = tier
			elseif name:find("гладиатора", 1, true) or name:find("Гладиатор", 1, true) then
				data = true
			else
				data = false
			end
			setBadgeData[setID] = data
		end

		if data == true then
			return "pvp"
		elseif data then
			return "tier", data
		end
	end

	local tier = GetReplacementTier(item, itemID)
	if tier then
		return "tier", tier
	end
end

local blockInboxRightClick
local itemInfoFrame = CreateFrame("Frame")

local function UpdateInboxClickState()
	local block = not not (InboxFrame and InboxFrame:IsVisible()
		and (not OpenMailFrame or not OpenMailFrame:IsVisible()))
	if blockInboxRightClick ~= block then
		blockInboxRightClick = block
		addon:SendMessage("AdiBags_UpdateClickRegistration")
	end
end

local inboxCheckElapsed = 0
local function InboxClickStateOnUpdate(_, elapsed)
	inboxCheckElapsed = inboxCheckElapsed + elapsed
	if inboxCheckElapsed < 0.1 then
		return
	end
	inboxCheckElapsed = 0
	UpdateInboxClickState()
end

itemInfoFrame:RegisterCustomEvent("GET_ITEM_INFO_RECEIVED")
itemInfoFrame:RegisterEvent("MAIL_SHOW")
itemInfoFrame:RegisterEvent("MAIL_CLOSED")
itemInfoFrame:RegisterEvent("BAG_UPDATE")
itemInfoFrame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
itemInfoFrame:SetScript("OnEvent", function(self, event, itemID, success)
	if event == "MAIL_SHOW" then
		inboxCheckElapsed = 0
		self:SetScript("OnUpdate", InboxClickStateOnUpdate)
		UpdateInboxClickState()
	elseif event == "MAIL_CLOSED" then
		self:SetScript("OnUpdate", nil)
		blockInboxRightClick = false
		addon:SendMessage("AdiBags_UpdateClickRegistration")
	elseif event == "BAG_UPDATE" or event == "PLAYERBANKBAGSLOTS_CHANGED" then
		wipe(bagFamilyCache)
	elseif pendingSetItems[itemID] then
		pendingSetItems[itemID] = nil
		replacementTiers[itemID] = nil
		replacementAttempts[itemID] = nil
		if success then
			addon:SendMessage("AdiBags_UpdateAllButtons")
		end
	end
end)

--------------------------------------------------------------------------------
-- Button initialization
--------------------------------------------------------------------------------

local buttonClass, buttonProto = addon:NewClass("ItemButton", "Button", "ContainerFrameItemButtonTemplate")
local AceEvent = LibStub("AceEvent-3.0")
buttonProto.RegisterMessage = AceEvent.RegisterMessage
buttonProto.UnregisterMessage = AceEvent.UnregisterMessage
buttonProto.UnregisterAllMessages = AceEvent.UnregisterAllMessages

local childrenNames = { "Cooldown", "IconTexture", "IconQuestTexture", "Count", "Stock", "NormalTexture" }

function buttonProto:OnCreate()
	local name = self:GetName()
	for i, childName in pairs(childrenNames) do
		self[childName] = _G[name .. childName]
	end
	self:RegisterForDrag("LeftButton")
	self:UpdateClickRegistration()
	self:SetScript("OnShow", self.OnShow)
	self:SetScript("OnHide", self.OnHide)
	self:SetScript("OnEvent", self.OnEvent)
	self:SetWidth(ITEM_SIZE)
	self:SetHeight(ITEM_SIZE)
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

function buttonProto:OnAcquire(container, bag, slot)
	self.container = container
	self.bag = bag
	self.slot = slot
	self.stack = nil
	self:SetParent(addon.itemParentFrames[bag])
	if self.SetBagID then
		self:SetBagID(bag)
	end
	self:SetID(slot)
	self:FullUpdate()
end

do
	local buttonProtoHook = addon:GetClass("ItemButton").prototype
	local orig_OnAcquire = buttonProtoHook.OnAcquire

	function buttonProtoHook:OnAcquire(container, bag, slot)
		-- 1) vanilla AdiBags acquire
		orig_OnAcquire(self, container, bag, slot)

		-- 2) only if AddOnSkins is present, retrigger OnCreate hooks
		if not self.isSkinnedByElvUI and IsAddOnLoaded("ElvUI") then
			-- safely unpack ElvUI (won't error if ElvUI is nil)
			local E, L, V, P, G = unpack(_G.ElvUI or {})
			local AS = E and E:GetModule("AddOnSkins", true)
			if AS then
				-- this will fire every hooksecurefunc(*, "OnCreate", …)
				self:OnCreate()
				self.isSkinnedByElvUI = true
			end
		end
	end
end

function buttonProto:OnRelease()
	self:SetSection(nil)
	self.container = nil
	self.itemId = nil
	self.itemLink = nil
	self.hasItem = nil
	self.texture = nil
	self.bagFamily = nil
	self.stack = nil
	self.itemQuality = nil
	self.isQuestItem = nil
	self.questId = nil
	self.slotCount = nil
	self.slotLocked = nil
end

function buttonProto:ToString()
	return format("Button-%s-%s", tostring(self.bag), tostring(self.slot))
end

function buttonProto:IsLocked()
	local locked = self.slotLocked
	if locked ~= nil then
		self.slotLocked = nil
		return locked
	end
	return select(3, GetContainerItemInfo(self.bag, self.slot))
end

--------------------------------------------------------------------------------
-- Generic bank button sub-type
--------------------------------------------------------------------------------

local bankButtonClass, bankButtonProto = addon:NewClass("BankItemButton", "ItemButton")
bankButtonClass.frameTemplate = "BankItemButtonGenericTemplate"

function bankButtonProto:IsLocked()
	return IsInventoryItemLocked(BankButtonIDToInvSlotID(self.slot))
end

--------------------------------------------------------------------------------
-- Pools and acquistion
--------------------------------------------------------------------------------

local containerButtonPool = addon:CreatePool(buttonClass)
local bankButtonPool = addon:CreatePool(bankButtonClass)

function addon:AcquireItemButton(container, bag, slot)
	if bag == BANK_CONTAINER then
		return bankButtonPool:Acquire(container, bag, slot)
	else
		return containerButtonPool:Acquire(container, bag, slot)
	end
end

function addon:UpdateCountAppearance()
	for button in containerButtonPool:IterateActiveObjects() do
		button:UpdateCountAppearance()
	end
	for button in bankButtonPool:IterateActiveObjects() do
		button:UpdateCountAppearance()
	end
	if addon.UpdatePreviewCountAppearance then
		addon:UpdatePreviewCountAppearance()
	end
end

-- Pre-spawn a bunch of buttons, when we are out of combat
-- because buttons created in combat do not work well
hooksecurefunc(addon, "OnInitialize", function()
	addon:Debug("Prespawning buttons")
	containerButtonPool:PreSpawn(100)
end)

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
	local count = self.slotCount
	if count ~= nil then
		self.slotCount = nil
		return count
	end
	return select(2, GetContainerItemInfo(self.bag, self.slot)) or 0
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

local BANK_BAG_IDS = addon.BAG_IDS.BANK
function buttonProto:IsBank()
	return not not BANK_BAG_IDS[self.bag]
end

function buttonProto:IsStack()
	return false
end

function buttonProto:GetRealButton()
	return self
end

function buttonProto:SetStack(stack)
	self.stack = stack
end

function buttonProto:GetStack()
	return self.stack
end

local function SimpleButtonSlotIterator(self, slotId)
	if not slotId and self.bag and self.slot then
		return GetSlotId(self.bag, self.slot), self.bag, self.slot, self.itemId, self.stack
	end
end

function buttonProto:IterateSlots()
	return SimpleButtonSlotIterator, self
end

--------------------------------------------------------------------------------
-- Scripts & event handlers
--------------------------------------------------------------------------------

function buttonProto:UpdateClickRegistration()
	if blockInboxRightClick then
		self:RegisterForClicks("LeftButtonUp")
	else
		self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	end
end

function buttonProto:OnShow()
	self:RegisterEvent("BAG_UPDATE_COOLDOWN")
	self:RegisterEvent("ITEM_LOCK_CHANGED")
	self:RegisterEvent("QUEST_ACCEPTED")
	if self.UpdateSearch then
		self:RegisterEvent("INVENTORY_SEARCH_UPDATE")
	end
	self:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
	self:RegisterMessage("AdiBags_UpdateAllButtons", "Update")
	self:RegisterMessage("AdiBags_GlobalLockChanged", "UpdateLock")
	self:RegisterMessage("AdiBags_UpdateClickRegistration", "UpdateClickRegistration")
	self:UpdateClickRegistration()
	self:FullUpdate()
end

function buttonProto:OnHide()
	self:UnregisterAllEvents()
	self:UnregisterAllMessages()
	if self.hasStackSplit and self.hasStackSplit == 1 then
		StackSplitFrame:Hide()
	end
end

function buttonProto:OnEvent(event, ...)
	if event == "BAG_UPDATE_COOLDOWN" then
		self:UpdateCooldown()
	elseif event == "ITEM_LOCK_CHANGED" then
		local bag, slot = ...
		if bag == self.bag and slot == self.slot then
			self:UpdateLock(true)
		end
	elseif event == "QUEST_ACCEPTED" then
		self:UpdateBorder(true)
	elseif event == "INVENTORY_SEARCH_UPDATE" then
		if self.UpdateSearch then
			self:UpdateSearch()
		end
	elseif event == "UNIT_QUEST_LOG_CHANGED" then
		self:UNIT_QUEST_LOG_CHANGED(event, ...)
	end
end

function buttonProto:UNIT_QUEST_LOG_CHANGED(event, unit)
	if unit == "player" then
		self:UpdateBorder(event)
	end
end

--------------------------------------------------------------------------------
-- Display updating
--------------------------------------------------------------------------------

function buttonProto:CanUpdate()
	if not self:IsVisible() or addon.holdYourBreath then
		return false
	end
	return true
end

function buttonProto:FullUpdate()
	local bag, slot = self.bag, self.slot
	self.itemId = GetContainerItemID(bag, slot)
	self.itemLink = GetContainerItemLink(bag, slot)
	self.hasItem = not not self.itemId
	local texture, count, locked = GetContainerItemInfo(bag, slot)
	self.texture = texture
	self.slotCount = count or 0
	self.slotLocked = locked or false
	self.itemQuality = nil
	self.bagFamily = GetBagFamily(bag)
	self:Update()
	self.slotCount, self.slotLocked = nil, nil
end

function buttonProto:Update()
	if not self:CanUpdate() then
		return
	end

	-- icon & empty-slot handling
	local icon = self.IconTexture
	icon:SetVertexColor(1, 1, 1)
	if self.texture then
		icon:SetTexture(self.texture)
		icon:SetTexCoord(0, 1, 0, 1)
	else
		if Masque then
			icon:SetTexCoord(12 / 64, 51 / 64, 12 / 64, 51 / 64)
			icon:SetTexture(nil)
		else
			icon:SetTexture([[Interface\BUTTONS\UI-EmptySlot]])
			icon:SetTexCoord(12 / 64, 51 / 64, 12 / 64, 51 / 64)
		end
	end

	-- bag-type tag
	local tag = (not self.itemId or addon.db.profile.showBagType) and addon:GetFamilyTag(self.bagFamily)
	if tag then
		self.Stock:SetText(tag)
		self.Stock:Show()
	else
		self.Stock:Hide()
	end

	local setBadge = self.setBadgeText
	local settings = addon.db.profile.setBadges
	local badgeType, tier
	if settings and settings.enabled and self.itemId then
		badgeType, tier = GetSetBadgeData(self.itemLink or self.itemId, self.itemId)
	end
	local setLabel
	if badgeType == "tier" then
		setLabel = (settings.tierPrefix or "Т") .. tier
	elseif badgeType == "pvp" then
		setLabel = settings.pvpText or "ПвП"
	end
	if setLabel and setLabel ~= "" then
		if not setBadge then
			setBadge = self:CreateFontString(nil, "OVERLAY")
			setBadge:SetJustifyH("CENTER")
			setBadge:SetShadowColor(0, 0, 0, 1)
			setBadge:SetShadowOffset(1, -1)
			self.setBadgeText = setBadge
		end
		local anchor = settings.anchor or "TOP"
		setBadge:ClearAllPoints()
		setBadge:SetPoint(anchor, self, anchor, settings.offsetX or 0, settings.offsetY or -1)
		local fontName = NumberFontNormalSmall:GetFont()
		setBadge:SetFont(fontName, settings.fontSize or 10, "OUTLINE")
		setBadge:SetText(setLabel)
		if badgeType == "pvp" then
			local color = settings.pvpColor
			setBadge:SetTextColor(color[1], color[2], color[3])
		else
			local color = settings.tierColor
			setBadge:SetTextColor(color[1], color[2], color[3])
		end
		setBadge:Show()
	elseif setBadge then
		setBadge:Hide()
	end

	self:UpdateCount()
	self:UpdateBorder()
	self:UpdateCooldown()
	self:UpdateLock()
	if self.UpdateSearch then
		self:UpdateSearch()
	end

	addon:SendMessage("AdiBags_UpdateButton", self)
end

function buttonProto:UpdateCount()
	local count = self:GetCount() or 0
	self.count = count
	if count > 1 then
		self.Count:SetText(count)
		self.Count:Show()
	else
		self.Count:Hide()
	end
end

function buttonProto:UpdateLock(isolatedEvent)
	if addon.globalLock then
		SetItemButtonDesaturated(self, true)
		self:Disable()
	else
		self:Enable()
		SetItemButtonDesaturated(self, self:IsLocked())
	end
	if isolatedEvent then
		addon:SendMessage("AdiBags_UpdateLock", self)
	end
end

function buttonProto:UpdateCooldown()
	return ContainerFrame_UpdateCooldown(self.bag, self, self.hasItem)
end

function buttonProto:UpdateBorder(isolatedEvent)
	if self.hasItem then
		local texture, r, g, b, a, x1, x2, y1, y2, blendMode = nil, 1, 1, 1, 1, 0, 1, 0, 1, "BLEND"
		local isQuestItem, questId, isActive = GetContainerItemQuestInfo(self.bag, self.slot)
		self.isQuestItem, self.questId = isQuestItem, questId

		if addon.db.profile.questIndicator and (questId and not isActive) then
			texture = TEXTURE_ITEM_QUEST_BANG
		elseif addon.db.profile.questIndicator and (questId or isQuestItem) then
			texture = TEXTURE_ITEM_QUEST_BORDER
		elseif addon.db.profile.qualityHighlight then
			local quality = self:GetItemQuality()
			if quality and quality >= ITEM_QUALITY_UNCOMMON then
				r, g, b = GetItemQualityColor(quality)
				a = addon.db.profile.qualityOpacity
				texture, x1, x2, y1, y2 =
					[[Interface\Buttons\UI-ActionButton-Border]], 14 / 64, 49 / 64, 15 / 64, 50 / 64
				blendMode = "ADD"
			elseif quality == ITEM_QUALITY_POOR and addon.db.profile.dimJunk then
				local v = 1 - 0.5 * addon.db.profile.qualityOpacity
				texture, blendMode, r, g, b = true, "MOD", v, v, v
			end
		end
		if texture then
			local border = self.IconQuestTexture
			if texture == true then
				border:SetVertexColor(1, 1, 1, 1)
				border:SetTexture(r, g, b, a)
			else
				border:SetTexture(texture)
				border:SetVertexColor(r, g, b, a)
			end
			border:SetTexCoord(x1, x2, y1, y2)
			border:SetBlendMode(blendMode)
			border:Show()
			if isolatedEvent then
				addon:SendMessage("AdiBags_UpdateBorder", self)
			end
			return
		end
	end

	self.IconQuestTexture:Hide()
	if isolatedEvent then
		addon:SendMessage("AdiBags_UpdateBorder", self)
	end
end

--------------------------------------------------------------------------------
-- Masque Support
--------------------------------------------------------------------------------

if Masque then
	hooksecurefunc(buttonProto, "OnCreate", function(self)
		self.masqueData = {
			FloatingBG = false,
			Icon = self.IconTexture,
			Cooldown = self.Cooldown,
			Flash = false,
			Pushed = false,
			Normal = self.NormalTexture,
			Disabled = false,
			Checked = false,
			Border = self.IconQuestTexture,
			AutoCastable = false,
			--Highlight = false,
			HotKey = self.Stock,
			Count = self.Count,
			Name = false,
			Duration = false,
			AutoCast = false,
		}
		-- Optimization flags
		self.masqueInitialized = false
	end)

	hooksecurefunc(buttonProto, "UpdateBorder", function(self)
		if not (self.masqueGroup and self.masqueGroup.AddButton) then
			return
		end

		-- If the AdiBags group is disabled in Masque, don't run the hook
		if self.masqueGroup.db and self.masqueGroup.db.Disabled then
			return
		end

		-- Optimization: AddButton only once
		if not self.masqueInitialized then
			if self.masqueGroup.RemoveButton then
				self.masqueGroup:RemoveButton(self)
			end
			self.masqueGroup:AddButton(self, self.masqueData)
			self.masqueInitialized = true
		end

		-- Hide the default AdiBags border when Masque is active
		local iqTex = self.IconQuestTexture
		local iqTexPath = iqTex:GetTexture()
		local isAdiBagsQuestBang = (iqTexPath == TEXTURE_ITEM_QUEST_BANG)
		local isAdiBagsDefaultBorder = (
			iqTexPath == [[Interface\ContainerFrame\UI-Icon-QuestBorder]]
			or iqTexPath == [[Interface\Buttons\UI-ActionButton-Border]]
		)

		if iqTex:IsShown() and isAdiBagsDefaultBorder and not isAdiBagsQuestBang then
			iqTex:Hide()
		elseif iqTex:IsShown() and isAdiBagsQuestBang then
			-- Quest Bang remains visible
		else
			if iqTex then
				iqTex:Hide()
			end
		end

		-- Recolor the Masque Normal-region via the public API Core.SetNormalColor
		-- This avoids manual region searching and works faster.
		if self.hasItem then
			local itemQuality = self:GetItemQuality()
			local isQuestItem, questId = self.isQuestItem, self.questId

			local r, g, b, a
			if isQuestItem or questId then
				-- Golden color for quest items
				r, g, b, a = 0.9, 0.7, 0.2, addon.db.profile.qualityOpacity or 0.8
			elseif itemQuality == ITEM_QUALITY_POOR and addon.db.profile.dimJunk then
				-- Gray color for junk
				r, g, b, a = 0.5, 0.5, 0.5, addon.db.profile.qualityOpacity or 0.7
			elseif itemQuality and itemQuality >= ITEM_QUALITY_UNCOMMON and addon.db.profile.qualityHighlight then
				-- Color by quality
				r, g, b = GetItemQualityColor(itemQuality)
				a = addon.db.profile.qualityOpacity or 1
			end

			if Masque and Masque.GetNormal then
				local normalRegion = Masque:GetNormal(self)
				if normalRegion then
					if r then
						normalRegion:SetVertexColor(r, g, b, a)
						normalRegion:SetBlendMode("BLEND")
						normalRegion:Show()
					else
						-- Reset color to the skin's default
						local defaultColor = (self.__MSQ_NormalSkin and self.__MSQ_NormalSkin.Color) or { 1, 1, 1, 1 }
						normalRegion:SetVertexColor(defaultColor[1], defaultColor[2], defaultColor[3], defaultColor[4])
					end
				end
			end
		end

		-- Dim the icon for junk items (as in the original AdiBags)
		if self.hasItem then
			local itemQuality = self:GetItemQuality()
			if itemQuality == ITEM_QUALITY_POOR and addon.db.profile.dimJunk then
				-- Dim the junk item icon
				local v = 1 - 0.5 * (addon.db.profile.qualityOpacity or 1)
				self.IconTexture:SetVertexColor(v, v, v, 1)
				self.IconTexture:SetBlendMode("BLEND")
			else
				-- Reset the icon to its normal state
				self.IconTexture:SetVertexColor(1, 1, 1, 1)
				self.IconTexture:SetBlendMode("DISABLE")
			end
		end
	end)

	-- Separate hook for updating icons (junk dimming)
	hooksecurefunc(buttonProto, "Update", function(self)
		if not (self.masqueGroup and self.masqueGroup.AddButton) then
			return
		end

		-- If the AdiBags group is disabled in Masque, don't run the hook
		if self.masqueGroup.db and self.masqueGroup.db.Disabled then
			return
		end

		-- Dim the button for junk items via SetAlpha (more reliable than VertexColor)
		if self.hasItem then
			local itemQuality = self:GetItemQuality()
			if itemQuality == ITEM_QUALITY_POOR and addon.db.profile.dimJunk then
				-- Dim the whole button
				self:SetAlpha(0.5)
			else
				-- Reset transparency
				self:SetAlpha(1)
			end
		else
			-- Reset transparency for empty slots
			self:SetAlpha(1)
		end
	end)

	buttonProto.masqueGroup = Masque:Group(addonName, addon.L["Backpack button"])
	bankButtonProto.masqueGroup = Masque:Group(addonName, addon.L["Bank button"])

	-- Hook for ReSkin
	local function HookMasqueReSkin(masqueGroup)
		if masqueGroup and masqueGroup.ReSkin and not masqueGroup._AdiBagsReSkinHooked then
			hooksecurefunc(masqueGroup, "ReSkin", function(self_group)
				if self_group.Buttons then
					for buttonInstance, _ in pairs(self_group.Buttons) do
						if buttonInstance and buttonInstance.UpdateBorder then
							buttonInstance.masqueInitialized = false
							buttonInstance:UpdateBorder()
						end
					end
				end
			end)
			masqueGroup._AdiBagsReSkinHooked = true
		end
	end

	-- Hook for Disable
	local function HookMasqueDisable(masqueGroup)
		if masqueGroup and masqueGroup.__Disable and not masqueGroup._AdiBagsDisableHooked then
			hooksecurefunc(masqueGroup, "__Disable", function(self_group)
				if self_group.Buttons then
					for buttonInstance, _ in pairs(self_group.Buttons) do
						if buttonInstance and buttonInstance.UpdateBorder then
							buttonInstance.masqueInitialized = false
							buttonInstance:UpdateBorder()
						end
					end
				end
			end)
			masqueGroup._AdiBagsDisableHooked = true
		end
	end

	HookMasqueReSkin(buttonProto.masqueGroup)
	HookMasqueReSkin(bankButtonProto.masqueGroup)
	HookMasqueDisable(buttonProto.masqueGroup)
	HookMasqueDisable(bankButtonProto.masqueGroup)
end

--------------------------------------------------------------------------------
-- Item stack button
--------------------------------------------------------------------------------

local stackClass, stackProto = addon:NewClass("StackButton", "Frame")
stackProto.RegisterMessage = AceEvent.RegisterMessage
stackProto.UnregisterMessage = AceEvent.UnregisterMessage
stackProto.UnregisterAllMessages = AceEvent.UnregisterAllMessages
addon:CreatePool(stackClass, "AcquireStackButton")

function stackProto:OnCreate()
	self:SetWidth(ITEM_SIZE)
	self:SetHeight(ITEM_SIZE)
	self.slots = {}
	self:SetScript("OnShow", self.OnShow)
	self:SetScript("OnHide", self.OnHide)
	self:SetScript("OnEvent", self.OnEvent)
	self.GetCountHook = function()
		return self.count
	end
end

function stackProto:OnAcquire(container, key)
	self.container = container
	self.key = key
	self.count = 0
	self.dirtyCount = true
	self:SetParent(container)
end

function stackProto:OnRelease()
	self:SetVisibleSlot(nil)
	self:SetSection(nil)
	self.key = nil
	self.container = nil
	wipe(self.slots)
end

function stackProto:GetCount()
	return self.count
end

function stackProto:IsStack()
	return true
end

function stackProto:GetRealButton()
	return self.button
end

function stackProto:GetKey()
	return self.key
end

local function GetSlotTimeLeft(bag, slot)
	if not (GetContainerItemGUID and GetItemExpirationTimeLeft) then
		return nil
	end
	local guid = GetContainerItemGUID(bag, slot)
	if not guid then
		return nil
	end
	local _, timeLeft = GetItemExpirationTimeLeft(guid)
	if timeLeft and timeLeft > 0 then
		return timeLeft
	end
end

local function IsBetterSlot(newTime, newCount, oldTime, oldCount)
	if newTime and oldTime then
		return newTime < oldTime
	elseif newTime ~= oldTime then
		return newTime ~= nil
	else
		return newCount > oldCount
	end
end

function stackProto:UpdateVisibleSlot()
	local bestLockedId, bestLockedTime, bestLockedCount
	local bestUnlockedId, bestUnlockedTime, bestUnlockedCount
	if self.slotId and self.slots[self.slotId] then
		local bag, slot = GetBagSlotFromId(self.slotId)
		local _, count, locked = GetContainerItemInfo(bag, slot)
		count = count or 1
		local timeLeft = GetSlotTimeLeft(bag, slot)
		if locked then
			bestLockedId, bestLockedTime, bestLockedCount = self.slotId, timeLeft, count
		else
			bestUnlockedId, bestUnlockedTime, bestUnlockedCount = self.slotId, timeLeft, count
		end
	end
	for slotId in pairs(self.slots) do
		local bag, slot = GetBagSlotFromId(slotId)
		local _, count, locked = GetContainerItemInfo(bag, slot)
		count = count or 1
		local timeLeft = GetSlotTimeLeft(bag, slot)
		if locked then
			if not bestLockedId or IsBetterSlot(timeLeft, count, bestLockedTime, bestLockedCount) then
				bestLockedId, bestLockedTime, bestLockedCount = slotId, timeLeft, count
			end
		else
			if not bestUnlockedId or IsBetterSlot(timeLeft, count, bestUnlockedTime, bestUnlockedCount) then
				bestUnlockedId, bestUnlockedTime, bestUnlockedCount = slotId, timeLeft, count
			end
		end
	end
	return self:SetVisibleSlot(bestUnlockedId or bestLockedId)
end

function stackProto:ITEM_LOCK_CHANGED()
	return self:Update()
end

function stackProto:AddSlot(slotId)
	local slots = self.slots
	if not slots[slotId] then
		slots[slotId] = true
		self.dirtyCount = true
		self:Update()
	end
end

function stackProto:RemoveSlot(slotId)
	local slots = self.slots
	if slots[slotId] then
		slots[slotId] = nil
		self.dirtyCount = true
		self:Update()
	end
end

function stackProto:IsEmpty()
	return not next(self.slots)
end

function stackProto:OnShow()
	self:RegisterMessage("AdiBags_UpdateAllButtons", "Update")
	self:RegisterMessage("AdiBags_PostContentUpdate")
	self:RegisterEvent("ITEM_LOCK_CHANGED")
	if self.button then
		self.button:Show()
	end
	self:Update()
end

function stackProto:OnHide()
	if self.button then
		self.button:Hide()
	end
	self:UnregisterAllEvents()
	self:UnregisterAllMessages()
end

function stackProto:OnEvent(event, ...)
	if event == "ITEM_LOCK_CHANGED" then
		self:ITEM_LOCK_CHANGED(event, ...)
	end
end

function stackProto:SetVisibleSlot(slotId)
	if slotId == self.slotId then
		return
	end
	self.slotId = slotId
	local button = self.button
	if button then
		button.GetCount = nil
		button:Release()
	end
	if slotId then
		button = addon:AcquireItemButton(self.container, GetBagSlotFromId(slotId))
		button.GetCount = self.GetCountHook
		button:SetAllPoints(self)
		button:SetStack(self)
		button:Show()
	else
		button = nil
	end
	self.button = button
	return true
end

function stackProto:Update()
	if not self:CanUpdate() then
		return
	end
	self:UpdateVisibleSlot()
	self:UpdateCount()
	if self.button then
		self.button:Update()
	end
end

stackProto.FullUpdate = stackProto.Update

function stackProto:UpdateCount()
	local count = 0
	for slotId in pairs(self.slots) do
		count = count + (select(2, GetContainerItemInfo(GetBagSlotFromId(slotId))) or 1)
	end
	self.count = count
	self.dirtyCount = nil
end

function stackProto:AdiBags_PostContentUpdate()
	if self.dirtyCount then
		self:UpdateCount()
	end
end

function stackProto:GetItemId()
	return self.button and self.button:GetItemId()
end

function stackProto:GetItemLink()
	return self.button and self.button:GetItemLink()
end

function stackProto:IsBank()
	return self.button and self.button:IsBank()
end

function stackProto:GetBagFamily()
	return self.button and self.button:GetBagFamily()
end

local function StackSlotIterator(self, previous)
	local slotId = next(self.slots, previous)
	if slotId then
		local bag, slot = GetBagSlotFromId(slotId)
		local _, count = GetContainerItemInfo(bag, slot)
		return slotId, bag, slot, self:GetItemId(), count
	end
end
function stackProto:IterateSlots()
	return StackSlotIterator, self
end

-- Reuse button methods
stackProto.CanUpdate = buttonProto.CanUpdate
stackProto.SetSection = buttonProto.SetSection
stackProto.GetSection = buttonProto.GetSection
