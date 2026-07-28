local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local C_Item = _G.C_Item
local C_Timer = _G.C_Timer
local CloseMenus = _G.CloseMenus
local CreateFrame = _G.CreateFrame
local date = _G.date
local EasyMenu = _G.EasyMenu
local format = _G.format
local GameFontNormal = _G.GameFontNormal
local GetItemInfo = _G.GetItemInfo
local GetItemInfoInstant = _G.GetItemInfoInstant
local ipairs = _G.ipairs
local pairs = _G.pairs
local PlaySound = _G.PlaySound
local select = _G.select
local tinsert = _G.tinsert
local tsort = _G.table.sort
local UIParent = _G.UIParent
local wipe = _G.wipe
--GLOBALS>

local GetSlotId = addon.GetSlotId
local GetDistinctItemID = addon.GetDistinctItemID
local BAG_INSET = addon.BAG_INSET
local BANNER_HEIGHT = 16

local mod = addon:NewModule("Preview", "AceEvent-3.0")
mod.uiName = L["Bag preview"]
mod.uiDesc = L["Show bags and bank of another character."]

local BAG_ORDER = { 0, 1, 2, 3, 4, -2 }
local BANK_ORDER = { -1, 5, 6, 7, 8, 9, 10, 11 }

local PREVIEW_BAG_IDS = {}
local PREVIEW_BAG_SET = {}
for index = 1, 14 do
	PREVIEW_BAG_IDS[index] = -100 - index
	PREVIEW_BAG_SET[-100 - index] = -100 - index
end

local function CrossChar()
	return addon:GetModule("CrossCharacter", true)
end

local function ColorHex(class)
	local cc = CrossChar()
	local r, g, b = 1, 1, 1
	if cc and cc.ClassColor then
		r, g, b = cc.ClassColor(class)
	end
	return format("%02x%02x%02x", r * 255, g * 255, b * 255)
end

local function FormatDate(stamp)
	if not stamp then
		return L["unknown"]
	end
	return date("%d.%m.%Y", stamp)
end

--------------------------------------------------------------------------------
-- Preview container
--------------------------------------------------------------------------------

local previewClass, previewProto, containerProto = addon:NewClass("PreviewContainer", "Container")
local layeredProto = addon:GetClass("LayeredRegion").prototype
local MISCELLANEOUS = addon.BI["Miscellaneous"]

function previewProto:AcquireItemButton(slotData)
	return addon:AcquirePreviewItemButton(self, slotData)
end

function previewProto:FilterSlot(slotData)
	local section, category, filterName = addon:Filter(slotData, MISCELLANEOUS)
	return section, category, filterName, false
end

function previewProto:UpdateContent(bag)
	local added, removed, changed = self.added, self.removed, self.changed
	local content = self.content[bag]
	local source = self.previewSlots[bag]
	local newSize = source and source.size or 0
	content.family = 0

	for slot = 1, newSize do
		local entry = source[slot]
		local slotData = content[slot]
		if entry then
			if not slotData then
				slotData = {
					bag = bag,
					slot = slot,
					slotId = GetSlotId(bag, slot),
					bagFamily = 0,
					count = 0,
					preview = true,
				}
				content[slot] = slotData
			end
			slotData.isBank = self.previewIsBank
			local link = entry.link
			local distinctOld = GetDistinctItemID(slotData.link)
			local distinctNew = GetDistinctItemID(link)
			if distinctOld ~= distinctNew then
				removed[slotData.slotId] = slotData.link
				slotData.count = entry.count
				slotData.link = link
				slotData.itemId = entry.id
				local name, _, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice =
					GetItemInfo(link)
				if not name then
					self.pendingItems = true
					if C_Item and C_Item.GetItemInfo then
						C_Item.GetItemInfo(entry.id, true)
					end
				end
				local classID, subclassID = select(6, GetItemInfoInstant(entry.id))
				slotData.name, slotData.quality, slotData.iLevel, slotData.reqLevel, slotData.class, slotData.subclass, slotData.equipSlot, slotData.texture, slotData.vendorPrice =
					name, quality, iLevel, reqLevel, class, subclass, equipSlot, texture, vendorPrice
				slotData.classID, slotData.subclassID = classID, subclassID
				slotData.maxStack = maxStack or 1
				added[slotData.slotId] = slotData
			elseif slotData.count ~= entry.count then
				slotData.count = entry.count
				changed[slotData.slotId] = slotData
			end
		elseif slotData then
			removed[slotData.slotId] = slotData.link
			content[slot] = nil
		end
	end

	for slot = content.size, newSize + 1, -1 do
		local slotData = content[slot]
		if slotData then
			removed[slotData.slotId] = slotData.link
			content[slot] = nil
		end
	end
	content.size = newSize
end

function previewProto:RefreshItemInfo()
	local dirty, stillPending = false, false
	for _, content in pairs(self.content) do
		for slot = 1, content.size do
			local slotData = content[slot]
			if slotData and slotData.link and not slotData.name then
				local name, _, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice =
					GetItemInfo(slotData.link)
				if name then
					slotData.name, slotData.quality, slotData.iLevel, slotData.reqLevel, slotData.class, slotData.subclass, slotData.equipSlot, slotData.texture, slotData.vendorPrice =
						name, quality, iLevel, reqLevel, class, subclass, equipSlot, texture, vendorPrice
					slotData.maxStack = maxStack or 1
					self.changed[slotData.slotId] = slotData
					dirty = true
				else
					stillPending = true
				end
			end
		end
	end
	self.pendingItems = stillPending
	if dirty then
		self:UpdateButtons()
		self:LayoutSections()
	end
	return stillPending
end

function previewProto:ResumeUpdates()
	if not self.paused then
		return
	end
	self.paused = false
	self:Rebuild()
end

function previewProto:PauseUpdates()
	self.paused = true
end

function previewProto:BagsUpdated() end

function previewProto:Rebuild()
	self.pendingItems = nil
	for bag in pairs(self.bagIds) do
		self:UpdateContent(bag)
	end
	if self.filtersChanged then
		self:RedispatchAllItems()
	else
		self:UpdateButtons()
	end
	self:LayoutSections(0)
	self:UpdateEmptyState()
end

function previewProto:OnShow()
	PlaySound("igBackPackOpen")
	self:ResumeUpdates()
	layeredProto.OnShow(self)
end

function previewProto:OnLayout()
	containerProto.OnLayout(self)
	self:SetHeight(self:GetHeight() + BANNER_HEIGHT)
end

function previewProto:UpdateSkin()
	containerProto.UpdateSkin(self)
	self:SetBackdropBorderColor(1, 0.5, 0, 1)
end

function previewProto:UpdateEmptyState()
	local hasItems = false
	for _, content in pairs(self.content) do
		if content.size and content.size > 0 then
			for slot = 1, content.size do
				if content[slot] then
					hasItems = true
					break
				end
			end
		end
		if hasItems then
			break
		end
	end
	if hasItems then
		self.EmptyText:Hide()
	else
		self.EmptyText:SetText(self.emptyReason or L["No data"])
		self.EmptyText:Show()
	end
end

function previewProto:SetPreviewData(name, realm, section, data)
	self.charName, self.charRealm, self.charData = name, realm, data
	self.section = section
	self.previewIsBank = (section == "bank")

	local snapshot = data.snapshot
	local store = snapshot and (self.previewIsBank and snapshot.bank or snapshot.bags)
	local order = self.previewIsBank and BANK_ORDER or BAG_ORDER
	local cc = CrossChar()

	wipe(self.previewSlots)
	local index = 0
	if store and cc then
		for _, realBag in ipairs(order) do
			local text = store[realBag]
			if text then
				index = index + 1
				local synthetic = PREVIEW_BAG_IDS[index]
				if synthetic then
					local content = cc:DecodeContainer(text)
					if content then
						self.previewSlots[synthetic] = content
					end
				end
			end
		end
	end

	if index == 0 then
		if self.previewIsBank then
			self.emptyReason = data.bankSeen and L["The bank is empty"] or L["The bank has never been seen"]
		else
			self.emptyReason = L["No data"]
		end
	else
		self.emptyReason = self.previewIsBank and L["The bank is empty"] or L["No data"]
	end

	local stamp = self.previewIsBank and data.bankSeen or data.lastSeen
	self.Title:SetText(
		format(
			"|cff%s%s|r (%s) — %s",
			ColorHex(data.class),
			name,
			realm,
			self.previewIsBank and L["Bank"] or L["Bags"]
		)
	)
	if stamp then
		self.Banner:SetText(format(L["PREVIEW - data from %s"], FormatDate(stamp)))
	else
		self.Banner:SetText(L["PREVIEW - date unknown"])
	end

	if self:IsVisible() then
		self:Rebuild()
	end
end

--------------------------------------------------------------------------------
-- Frame creation
--------------------------------------------------------------------------------

local function CreatePreviewFrame()
	local frame = previewClass:Create("Preview", {}, false)

	frame.previewSlots = {}
	frame.bagIds = PREVIEW_BAG_SET
	for bagId in pairs(PREVIEW_BAG_SET) do
		frame.content[bagId] = { size = 0 }
	end

	frame.ClickReceiver:SetScript("OnClick", nil)
	frame.ClickReceiver:SetScript("OnReceiveDrag", nil)
	frame.ClickReceiver:RegisterForClicks()

	if frame.BagSlotButton then
		frame.BagSlotButton:Hide()
	end
	if frame.BagSlotPanel then
		frame.BagSlotPanel:Hide()
	end

	frame.CloseButton:SetScript("OnClick", function()
		mod:Close()
	end)

	frame.Title:ClearAllPoints()
	frame.Title:SetPoint("TOPLEFT", frame.HeaderLeftRegion, "TOPRIGHT", 4, -1)
	frame.Title:SetPoint("TOPRIGHT", frame.HeaderRightRegion, "TOPLEFT", -4, -1)

	local tint = frame:CreateTexture(nil, "BORDER")
	tint:SetAllPoints(frame)
	tint:SetTexture(1, 0.55, 0.1)
	tint:SetAlpha(0.07)
	frame.PreviewTint = tint

	local overlay = CreateFrame("Frame", nil, frame)
	overlay:SetAllPoints(frame)
	overlay:SetFrameLevel(frame:GetFrameLevel() + 12)
	frame.TextOverlay = overlay

	local banner = overlay:CreateFontString(nil, "OVERLAY")
	banner:SetFontObject(GameFontNormal)
	banner:SetPoint("TOPLEFT", BAG_INSET, -(addon.TOP_PADDING - 4))
	banner:SetPoint("TOPRIGHT", -BAG_INSET, -(addon.TOP_PADDING - 4))
	banner:SetHeight(BANNER_HEIGHT)
	banner:SetJustifyH("CENTER")
	banner:SetTextColor(1, 0.55, 0.1)
	frame.Banner = banner

	frame.Content:ClearAllPoints()
	frame.Content:SetPoint("TOPLEFT", BAG_INSET, -(addon.TOP_PADDING + BANNER_HEIGHT))

	local empty = overlay:CreateFontString(nil, "OVERLAY")
	empty:SetFontObject(GameFontNormal)
	empty:SetPoint("TOPLEFT", frame.Content, "TOPLEFT", 0, -8)
	empty:SetPoint("TOPRIGHT", frame.Content, "TOPRIGHT", 0, -8)
	empty:SetJustifyH("CENTER")
	empty:Hide()
	frame.EmptyText = empty

	frame:UpdateSkin()
	frame.Anchor:ApplySettings()
	frame:SetScale(addon.db.profile.scale)

	addon:SendMessage("AdiBags_PreviewFrameCreated", frame)
	return frame
end

local itemInfoFrame = CreateFrame("Frame")
local refreshScheduled, refreshAttempts

local function FlushItemInfo()
	refreshScheduled = nil
	local frame = mod.frame
	if not (frame and frame:IsShown() and frame.pendingItems) then
		return
	end
	if frame:RefreshItemInfo() and refreshAttempts < 5 then
		refreshAttempts = refreshAttempts + 1
		refreshScheduled = true
		C_Timer:After(0.5, FlushItemInfo)
	end
end

local function ScheduleItemInfoRefresh()
	local frame = mod.frame
	if refreshScheduled or not (frame and frame:IsShown() and frame.pendingItems) then
		return
	end
	refreshScheduled = true
	refreshAttempts = 0
	C_Timer:After(0.3, FlushItemInfo)
end

itemInfoFrame:RegisterCustomEvent("GET_ITEM_INFO_RECEIVED")
itemInfoFrame:SetScript("OnEvent", ScheduleItemInfoRefresh)

function mod:GetFrame()
	if not self.frame then
		self.frame = CreatePreviewFrame()
	end
	return self.frame
end

function mod:IsOpen()
	return self.frame and self.frame:IsShown()
end

function mod:Open(name, realm, section)
	local cc = CrossChar()
	local data = cc and cc:GetCharData(name, realm)
	if not data then
		return
	end
	local frame = self:GetFrame()
	frame:SetScale(addon.db.profile.scale)
	frame:SetPreviewData(name, realm, section, data)
	addon:SendMessage("AdiBags_PreviewOpened", frame)
	frame:Show()
	ScheduleItemInfoRefresh()
end

function mod:Close()
	if self.frame and self.frame:IsShown() then
		CloseMenus()
		self.frame:Hide()
		addon:SendMessage("AdiBags_PreviewClosed", self.frame)
		return true
	end
end

--------------------------------------------------------------------------------
-- Header button and menu
--------------------------------------------------------------------------------

local menuFrame = CreateFrame("Frame", addonName .. "PreviewMenu", UIParent, "UIDropDownMenuTemplate")
local menuList = {}

local function BuildSectionItems(entry, indent)
	local data = entry.data
	local bankTip = data.bankSeen and nil or L["Log in on this character and visit the bank to store its contents."]
	local prefix = indent and "  " or ""
	return {
		text = prefix .. L["Bags"],
		notCheckable = true,
		func = function()
			CloseMenus()
			mod:Open(entry.name, entry.realm, "bags")
		end,
	}, {
		text = prefix .. L["Bank"],
		notCheckable = true,
		disabled = not data.bankSeen,
		tooltipOnButton = bankTip and true or nil,
		tooltipTitle = bankTip and L["The bank has never been seen"] or nil,
		tooltipText = bankTip,
		func = function()
			CloseMenus()
			mod:Open(entry.name, entry.realm, "bank")
		end,
	}
end

local function BuildCharItem(entry)
	local bags, bank = BuildSectionItems(entry)
	return {
		text = format("|cff%s%s|r", ColorHex(entry.data.class), entry.name),
		notCheckable = true,
		hasArrow = true,
		menuList = { bags, bank },
	}
end

function mod:BuildMenu()
	wipe(menuList)

	if self:IsOpen() then
		tinsert(menuList, {
			text = L["Leave preview mode"],
			notCheckable = true,
			func = function()
				CloseMenus()
				mod:Close()
			end,
		})
		tinsert(menuList, { text = "  ", notClickable = true, notCheckable = true })
	end

	local cc = CrossChar()
	if not cc then
		tinsert(menuList, { text = L["No data"], notCheckable = true, disabled = true })
		return menuList
	end

	local _, currentRealm = cc:GetIdentity()
	local entries = cc:GetAllEntries()
	local otherRealms, otherOrder = {}, {}

	for _, entry in ipairs(entries) do
		if entry.realm == currentRealm then
			tinsert(menuList, BuildCharItem(entry))
		else
			local bucket = otherRealms[entry.realm]
			if not bucket then
				bucket = {}
				otherRealms[entry.realm] = bucket
				tinsert(otherOrder, entry.realm)
			end
			-- UIDROPDOWNMENU_MAXLEVELS = 2, поэтому персонажи чужих реалмов раскрыты внутри подменю реалма
			local bags, bank = BuildSectionItems(entry, true)
			tinsert(bucket, {
				text = format("|cff%s%s|r", ColorHex(entry.data.class), entry.name),
				isTitle = true,
				notCheckable = true,
			})
			tinsert(bucket, bags)
			tinsert(bucket, bank)
		end
	end

	tsort(otherOrder)
	if #otherOrder > 0 then
		tinsert(menuList, { text = L["Other realms"], isTitle = true, notCheckable = true })
	end
	for _, realm in ipairs(otherOrder) do
		tinsert(menuList, {
			text = realm,
			notCheckable = true,
			hasArrow = true,
			menuList = otherRealms[realm],
		})
	end

	if #menuList == 0 then
		tinsert(menuList, { text = L["No data"], notCheckable = true, disabled = true })
	end

	return menuList
end

function mod:ShowMenu(anchor)
	EasyMenu(self:BuildMenu(), menuFrame, anchor, 0, 0, "MENU", 2)
end

function mod:OnBagFrameCreated(bag)
	if bag.bagName ~= "Backpack" or self.headerButton then
		return
	end
	local frame = bag:GetFrame()
	local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	button:SetWidth(20)
	button:SetHeight(20)
	button:SetText("P")
	button:RegisterForClicks("AnyUp")
	button:SetScript("OnClick", function(self)
		mod:ShowMenu(self)
	end)
	addon.SetupTooltip(button, {
		L["Bag preview"],
		L["Show bags and bank of another character."],
	}, "ANCHOR_BOTTOMLEFT", 0, 0)
	self.headerButton = button
	frame:AddHeaderWidget(button, -5)
end

--------------------------------------------------------------------------------
-- Module lifecycle
--------------------------------------------------------------------------------

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			closeInCombat = true,
		},
	})
end

function mod:OnEnable()
	addon:HookBagFrameCreation(self, "OnBagFrameCreated")
	if self.headerButton then
		self.headerButton:Show()
	end
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("PLAYER_LEAVING_WORLD", "Close")
	self:RegisterMessage("AdiBags_CharacterDataDeleted", "OnCharacterDataDeleted")
end

function mod:OnDisable()
	self:Close()
	if self.headerButton then
		self.headerButton:Hide()
	end
end

function mod:PLAYER_REGEN_DISABLED()
	if self.db.profile.closeInCombat then
		self:Close()
	end
end

function mod:OnCharacterDataDeleted(event, name, realm)
	local frame = self.frame
	if frame and frame:IsShown() and frame.charName == name and frame.charRealm == realm then
		self:Close()
	end
end

function mod:GetOptions()
	return {
		closeInCombat = {
			name = L["Close the preview when entering combat"],
			type = "toggle",
			order = 10,
			width = "double",
		},
	},
		addon:GetOptionHandler(self)
end
