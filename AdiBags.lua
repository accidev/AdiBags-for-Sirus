local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local assert = _G.assert
local BACKPACK_CONTAINER = _G.BACKPACK_CONTAINER
local BankFrame = _G.BankFrame
local BANK_CONTAINER = _G.BANK_CONTAINER
local KEYRING_CONTAINER = _G.KEYRING_CONTAINER
local CloseBankFrame = _G.CloseBankFrame
local ContainerFrame_GenerateFrame = _G.ContainerFrame_GenerateFrame
local ContainerFrame_GetOpenFrame = _G.ContainerFrame_GetOpenFrame
local GetContainerNumSlots = _G.GetContainerNumSlots
local geterrorhandler = _G.geterrorhandler
local ipairs = _G.ipairs
local next = _G.next
local NUM_BAG_SLOTS = _G.NUM_BAG_SLOTS
local NUM_BANKBAGSLOTS = _G.NUM_BANKBAGSLOTS
local NUM_BANKGENERIC_SLOTS = _G.NUM_BANKGENERIC_SLOTS
local NUM_CONTAINER_FRAMES = _G.NUM_CONTAINER_FRAMES
local pairs = _G.pairs
local pcall = _G.pcall
local strmatch = _G.strmatch
local strsplit = _G.strsplit
local tinsert = _G.tinsert
local tsort = _G.table.sort
local type = _G.type
local UIParent = _G.UIParent
local wipe = _G.wipe
--GLOBALS>

LibCompat = LibStub:GetLibrary("LibCompat-1.0")

LibStub("AceAddon-3.0"):NewAddon(addon, addonName, "AceEvent-3.0", "AceBucket-3.0", "AceHook-3.0", "LibCompat-1.0")
--[===[@debug@
_G[addonName] = addon
--@end-debug@]===]

--------------------------------------------------------------------------------
-- Debug stuff
--------------------------------------------------------------------------------

--[===[@alpha@
if AdiDebug then
	AdiDebug:Embed(addon, addonName)
else
--@end-alpha@]===]
function addon.Debug() end
--[===[@alpha@
end
--@end-alpha@]===]

addon:SetDefaultModulePrototype({ Debug = addon.Debug })

--------------------------------------------------------------------------------
-- Helpful constants
--------------------------------------------------------------------------------

do
	-- Keyring, backpack, and bag
	local BAGS = { [KEYRING_CONTAINER] = KEYRING_CONTAINER, [BACKPACK_CONTAINER] = BACKPACK_CONTAINER }
	for i = 1, NUM_BAG_SLOTS do
		BAGS[i] = i
	end

	-- Bank bags
	local BANK = { [BANK_CONTAINER] = BANK_CONTAINER }
	for i = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
		BANK[i] = i
	end

	-- All bags
	local ALL = {}
	for id in pairs(BAGS) do
		ALL[id] = id
	end
	for id in pairs(BANK) do
		ALL[id] = id
	end

	addon.BAG_IDS = { BAGS = BAGS, BANK = BANK, ALL = ALL }
end

local FAMILY_TAGS = {
	--@noloc[[
	[0x0001] = L["QUIVER_TAG"], -- Quiver
	[0x0002] = L["AMMO_TAG"], -- Ammo Pouch
	[0x0004] = L["SOUL_BAG_TAG"], -- Soul Bag
	[0x0008] = L["LEATHERWORKING_BAG_TAG"], -- Leatherworking Bag
	[0x0010] = L["INSCRIPTION_BAG_TAG"], -- Inscription Bag
	[0x0020] = L["HERB_BAG_TAG"], -- Herb Bag
	[0x0040] = L["ENCHANTING_BAG_TAG"], -- Enchanting Bag
	[0x0080] = L["ENGINEERING_BAG_TAG"], -- Engineering Bag
	[0x0100] = L["KEYRING_TAG"], -- Keyring
	[0x0200] = L["GEM_BAG_TAG"], -- Gem Bag
	[0x0400] = L["MINING_BAG_TAG"], -- Mining Bag
	[0x100000] = L["TACKLE_BOX_TAG"], -- Tackle Box
	--@noloc]]
}

local FAMILY_ICONS = {
	[0x0001] = [[Interface\Icons\INV_Misc_Ammo_Arrow_01]], -- Quiver
	[0x0002] = [[Interface\Icons\INV_Misc_Ammo_Bullet_05]], -- Ammo Pouch
	[0x0004] = [[Interface\Icons\INV_Misc_Gem_Amethyst_02]], -- Soul Bag
	[0x0008] = [[Interface\Icons\Trade_LeatherWorking]], -- Leatherworking Bag
	[0x0010] = [[Interface\Icons\INV_Inscription_Tradeskill01]], -- Inscription Bag
	[0x0020] = [[Interface\Icons\Trade_Herbalism]], -- Herb Bag
	[0x0040] = [[Interface\Icons\Trade_Engraving]], -- Enchanting Bag
	[0x0080] = [[Interface\Icons\Trade_Engineering]], -- Engineering Bag
	[0x0100] = [[Interface\Icons\INV_Misc_Key_14]], -- Keyring
	[0x0200] = [[Interface\Icons\INV_Misc_Gem_BloodGem_01]], -- Gem Bag
	[0x0400] = [[Interface\Icons\Trade_Mining]], -- Mining Bag
	[0x100000] = [[Interface\Icons\Trade_Fishing]], -- Tackle Box
}

local band = _G.bit.band
function addon:GetFamilyTag(family)
	if family and family ~= 0 then
		for mask, tag in pairs(FAMILY_TAGS) do
			if band(family, mask) ~= 0 then
				return tag, FAMILY_ICONS[mask]
			end
		end
	end
end

addon.ITEM_SIZE = 37
addon.ITEM_SPACING = 4
addon.SECTION_SPACING = addon.ITEM_SIZE / 3 + addon.ITEM_SPACING
addon.BAG_INSET = 8
addon.TOP_PADDING = 32
addon.HEADER_SIZE = 14 + addon.ITEM_SPACING

local BACKDROP = {
	bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	tile = false,
	edgeSize = 16,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local LSM = LibStub("LibSharedMedia-3.0")

local DEFAULT_SETTINGS = {
	profile = {
		enabled = true,
		bags = {
			["*"] = true,
		},
		positions = {
			Backpack = { point = "BOTTOMRIGHT", xOffset = -111, yOffset = 220 },
			Bank = { point = "TOPLEFT", xOffset = 32, yOffset = -104 },
		},
		scale = 0.8,
		rowWidth = { ["*"] = 9 },
		maxHeight = 0.60,
		backgroundDrag = true,
		showAnchorHighlight = false,
		showAnchorTooltip = true,
		laxOrdering = 1,
		qualityHighlight = true,
		qualityOpacity = 1.0,
		dimJunk = true,
		questIndicator = true,
		showBagType = true,
		setBadges = {
			enabled = true,
			tierPrefix = "Т",
			pvpText = "ПвП",
			fontSize = 10,
			anchor = "TOP",
			offsetX = 0,
			offsetY = -1,
			tierColor = { 1, 0.82, 0 },
			pvpColor = { 1, 0.35, 0.35 },
		},
		countAnchor = "BOTTOMRIGHT",
		countOffsetX = -5,
		countOffsetY = 2,
		filters = { ["*"] = true },
		filterPriorities = {},
		sortingOrder = "default",
		modules = { ["*"] = true },
		virtualStacks = {
			["*"] = false,
			freeSpace = true,
			notWhenTrading = 1,
		},
		skin = {
			background = "Blizzard Tooltip",
			border = "Blizzard Tooltip",
			borderWidth = 16,
			insets = 3,
			BackpackColor = { 0, 0, 0, 1 },
			BankColor = { 0, 0, 0.5, 1 },
		},
	},
	char = {
		collapsedSections = {
			["*"] = false,
		},
	},
}

--------------------------------------------------------------------------------
-- Addon initialization and enabling
--------------------------------------------------------------------------------

addon:SetDefaultModuleState(false)

function addon:OnInitialize()
	local bfd = self:GetFontDefaults(GameFontHighlightLarge)
	bfd.r, bfd.g, bfd.b = 1, 1, 1
	DEFAULT_SETTINGS.profile.bagFont = bfd
	DEFAULT_SETTINGS.profile.sectionFont = self:GetFontDefaults(GameFontNormalLeft)

	local cfd = self:GetFontDefaults(NumberFontNormal)
	cfd.outline = select(3, NumberFontNormal:GetFont()) or ""
	DEFAULT_SETTINGS.profile.countFont = cfd

	self.db = LibStub("AceDB-3.0"):New(addonName .. "DB", DEFAULT_SETTINGS, true)
	self.db.RegisterCallback(self, "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "Reconfigure")
	-- self.db.RegisterCallback(self, "OnLayoutBagsChanged", "LayoutBags")

	self.bagFont = self:CreateFont(addonName .. "BagFont", GameFontHighlightLarge, function()
		return self.db.profile.bagFont
	end)
	self.sectionFont = self:CreateFont(addonName .. "SectionFont", GameFontNormalLeft, function()
		return self.db.profile.sectionFont
	end)
	self.countFont = self:CreateFont(addonName .. "CountFont", NumberFontNormal, function()
		return self.db.profile.countFont
	end)

	self.itemParentFrames = {}

	self:InitializeFilters()
	addon:InitializeOptions()

	self:SetEnabledState(false)

	-- Persistant handlers
	self.RegisterBucketMessage(addonName, "AdiBags_ConfigChanged", 0.2, function(...)
		addon:ConfigChanged(...)
	end)
	self.RegisterEvent(addonName, "PLAYER_ENTERING_WORLD", function()
		if self.db.profile.enabled then
			self:Enable()
		end
	end)

	self:UpgradeProfile()

	-- ProfessionVault support
	local PV = _G.ProfessionsVault
	if PV then
		self:Debug("Installing ProfessionsVault callback")
		self.RegisterMessage(PV, "AdiBags_UpdateButton", function(_, button)
			PV:SlotColor(button.itemId, button.IconTexture)
		end)
	end

	self:Debug("Initialized")
end

local greeted

function addon:OnEnable()
	if not greeted then
		greeted = true
		self.After(8, function()
			print(
				"|cFF00BFFFAdiBags|r |cFFFF4444»|r Спасибо за использование моей адаптации под Sirus. Другие аддоны в: -> |cff9aedff|Hhttp:https://discord.gg/uvRF2AtWzm|h[Discord]|h|r"
			)
		end)
	end

	self.globalLock = false

	self:RegisterEvent("BAG_UPDATE")
	self:RegisterBucketEvent("PLAYERBANKSLOTS_CHANGED", 0, "BankUpdated")

	self:RegisterEvent("PLAYER_LEAVING_WORLD", "Disable")

	self:RegisterMessage("AdiBags_BagOpened", "LayoutBags")
	self:RegisterMessage("AdiBags_BagClosed", "LayoutBags")

	self:RawHook("OpenAllBags", true)
	self:RawHook("CloseAllBags", true)
	self:RawHook("ToggleBackpack", true)
	self:RawHook("ToggleBag", true)
	self:RawHook("OpenBackpack", true)
	self:RawHook("CloseBackpack", true)
	self:RawHook("CloseSpecialWindows", true)

	-- Track most windows involving items
	for _, event in ipairs({
		"BANKFRAME_OPENED",
		"BANKFRAME_CLOSED",
		"MAIL_SHOW",
		"MAIL_CLOSED",
		"MERCHANT_SHOW",
		"MERCHANT_CLOSED",
		"AUCTION_HOUSE_SHOW",
		"AUCTION_HOUSE_CLOSED",
		"TRADE_SHOW",
		"TRADE_CLOSED",
		"GUILDBANKFRAME_OPENED",
		"GUILDBANKFRAME_CLOSED",
	}) do
		self:RegisterEvent(event, "UpdateInteractingWindow")
	end

	self:SetSortingOrder(self.db.profile.sortingOrder)

	for name, module in self:IterateModules() do
		if module.isFilter then
			module:SetEnabledState(self.db.profile.filters[module.moduleName])
		elseif module.isBag then
			module:SetEnabledState(self.db.profile.bags[module.bagName])
		else
			module:SetEnabledState(self.db.profile.modules[module.moduleName])
		end
	end

	self.bagFont:ApplySettings()
	self.sectionFont:ApplySettings()
	self.countFont:ApplySettings()
	self:UpdateCountAppearance()
	self:LayoutBags()

	self:Debug("Enabled")
end

function addon:OnDisable()
	self:CloseAllBags()
	self:Debug("Disabled")
end

function addon:Reconfigure()
	self.holdYourBreath = true -- prevent tons*$% of useless updates
	self:Disable()
	self:Enable()
	self.holdYourBreath = nil
	self:UpdateFilters()
end

function addon:OnProfileChanged()
	self:UpgradeProfile()
	return self:Reconfigure()
end

function addon:UpgradeProfile()
	local profile = self.db.profile

	-- Convert old ordering setting
	if profile.laxOrdering == true then
		profile.laxOrdering = 1
	end

	-- Convert old anchor settings
	if profile.anchor then
		profile.scale = profile.anchor.scale or 0.8
		profile.anchor = nil
	end

	profile.positionMode = nil
	profile.clickMode = nil
	if profile.positions then
		profile.positions.anchor = nil
	end

	-- Convert old "notWhenTrading" setting
	if profile.virtualStacks.notWhenTrading == true then
		profile.virtualStacks.notWhenTrading = 3
	end

	-- Convert old "rowWidth"
	if type(profile.rowWidth) == "number" then
		local rowWidth = profile.rowWidth
		profile.rowWidth = { Bank = rowWidth, Backpack = rowWidth }
	end

	-- Convert old "backgroundColors"
	if type(profile.backgroundColors) == "table" then
		profile.skin.BackpackColor = profile.backgroundColors.Backpack
		profile.skin.BankColor = profile.backgroundColors.Bank
		profile.backgroundColors = nil
	end

	-- Convert old font settings
	if type(profile.skin) == "table" then
		local skin = profile.skin
		if type(skin.font) == "string" then
			profile.bagFont.name = skin.font
			profile.sectionFont.name = skin.font
			skin.font = nil
		end
		if skin.fontSize then
			profile.bagFont.size = skin.fontSize
			profile.sectionFont.size = skin.fontSize - 4
			skin.fontSize = nil
		end
		if skin.fontBagColor then
			local bagFont = profile.bagFont
			bagFont.r, bagFont.g, bagFont.b = unpack(skin.fontBagColor)
			skin.fontBagColor = nil
		end
		if skin.fontSectionColor then
			local sectionFont = profile.sectionFont
			sectionFont.r, sectionFont.g, sectionFont.b = unpack(skin.fontSectionColor)
			skin.fontSectionColor = nil
		end
	end
end

--------------------------------------------------------------------------------
-- Event handlers
--------------------------------------------------------------------------------

function addon:BAG_UPDATE(event, bag)
	self:SendMessage("AdiBags_BagUpdated", bag)
end

function addon:BankUpdated(slots)
	-- Wrap several PLAYERBANKSLOTS_CHANGED into one AdiBags_BagUpdated message
	for slot in pairs(slots) do
		if slot > 0 and slot <= NUM_BANKGENERIC_SLOTS then
			self:SendMessage("AdiBags_BagUpdated", BANK_CONTAINER)
			return
		end
	end
end

function addon:CloseSpecialWindows()
	local bagWasOpen = self:CloseAllBags()
	return self.hooks.CloseSpecialWindows() or bagWasOpen
end

--[===[@debug@
local function DebugTable(t, prevKey)
	local k, v = next(t, prevKey)
	if k ~= nil then
		return k, v, DebugTable(t, k)
	end
end
--@end-debug@]===]

function addon:GetContainerSkin(containerName)
	local skin = self.db.profile.skin
	local r, g, b, a = unpack(skin[containerName .. "Color"], 1, 4)
	BACKDROP.bgFile = LSM:Fetch(LSM.MediaType.BACKGROUND, skin.background)
	BACKDROP.edgeFile = LSM:Fetch(LSM.MediaType.BORDER, skin.border)
	BACKDROP.edgeSize = skin.borderWidth
	BACKDROP.insets.left = skin.insets
	BACKDROP.insets.right = skin.insets
	BACKDROP.insets.top = skin.insets
	BACKDROP.insets.bottom = skin.insets
	return BACKDROP, r, g, b, a
end

function addon:ConfigChanged(vars)
	--[===[@debug@
	self:Debug('ConfigChanged', DebugTable(vars))
	--@end-debug@]===]
	if vars.enabled then
		if self.db.profile.enabled then
			self:Enable()
		else
			self:Disable()
		end
		return
	elseif not self:IsEnabled() then
		return
	elseif vars.filter then
		return self:SendMessage("AdiBags_FiltersChanged")
	else
		for name in pairs(vars) do
			if strmatch(name, "virtualStacks") then
				return self:SendMessage("AdiBags_FiltersChanged")
			elseif strmatch(name, "bags%.") then
				local _, bagName = strsplit(".", name)
				local bag = self:GetModule(bagName)
				local enabled = self.db.profile.bags[bagName]
				if enabled and not bag:IsEnabled() then
					bag:Enable()
				elseif not enabled and bag:IsEnabled() then
					bag:Disable()
				end
			elseif strmatch(name, "rowWidth") then
				return self:SendMessage("AdiBags_LayoutChanged")
			elseif strmatch(name, "^skin%.font") then
				return self:UpdateFonts()
			end
		end
	end
	if vars.sortingOrder then
		return self:SetSortingOrder(self.db.profile.sortingOrder)
	elseif vars.maxHeight or vars.laxOrdering then
		return self:SendMessage("AdiBags_LayoutChanged")
	elseif vars.scale then
		return self:LayoutBags()
	else
		self:SendMessage("AdiBags_UpdateAllButtons")
	end
end

function addon:SetGlobalLock(locked)
	locked = not not locked
	if locked ~= self.globalLock then
		self.globalLock = locked
		self:SendMessage("AdiBags_GlobalLockChanged", locked)
		if not locked then
			self:SendMessage("AdiBags_LayoutChanged")
		end
		return true
	end
end

--------------------------------------------------------------------------------
-- Bag-related function hooks
--------------------------------------------------------------------------------

local hookedBags = {}
local containersFrames = {}
do
	for i = 1, NUM_CONTAINER_FRAMES, 1 do
		containersFrames[i] = _G["ContainerFrame" .. i]
	end
end

local IterateBuiltInContainers
do
	local GetContainerNumSlots = GetContainerNumSlots
	local function iter(maxContainer, id)
		while id < maxContainer do
			id = id + 1
			if not hookedBags[id] and GetContainerNumSlots(id) > 0 then
				return id
			end
		end
	end

	function IterateBuiltInContainers()
		if addon:GetInteractingWindow() == "BANKFRAME" then
			return iter, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS, -1
		else
			return iter, NUM_BAG_SLOTS, -1
		end
	end
end

local function GetContainerFrame(id, spawn)
	for _, frame in pairs(containersFrames) do
		if frame:IsShown() and frame:GetID() == id then
			return frame
		end
	end
	if spawn then
		local size = GetContainerNumSlots(id)
		if size > 0 then
			local frame = ContainerFrame_GetOpenFrame()
			ContainerFrame_GenerateFrame(frame, size, id)
		end
	end
end

function addon:OpenAllBags(forceOpen)
	local total, open = 0, 0
	for i, bag in self:IterateBags() do
		if bag:CanOpen() then
			total = total + 1
			if bag:IsOpen() then
				open = open + 1
			end
		end
	end
	for id in IterateBuiltInContainers() do
		total = total + 1
		if GetContainerFrame(id) then
			open = open + 1
		end
	end
	if open == total and not forceOpen then
		return self:CloseAllBags()
	end

	for _, bag in self:IterateBags() do
		bag:Open()
	end
	for id in IterateBuiltInContainers() do
		GetContainerFrame(id, true)
	end
end

function addon:CloseAllBags()
	local closed = false
	for i, bag in self:IterateBags() do
		if bag:Close() then
			closed = true
		end
	end
	for id in IterateBuiltInContainers() do
		local frame = GetContainerFrame(id)
		if frame then
			frame:Hide()
			closed = true
		end
	end
	return closed
end

function addon:ToggleBag(id)
	local ourBag = hookedBags[id]
	if ourBag then
		return ourBag:Toggle()
	else
		local frame = GetContainerFrame(id, true)
		if frame then
			frame:Hide()
		end
	end
end

function addon:OpenBackpack()
	local ourBackpack = hookedBags[BACKPACK_CONTAINER]
	if ourBackpack then
		self.backpackWasOpen = ourBackpack:IsOpen()
		ourBackpack:Open()
	else
		local frame = GetContainerFrame(BACKPACK_CONTAINER, true)
		self.backpackWasOpen = not not frame
	end
	return self.backpackWasOpen
end

function addon:CloseBackpack()
	if self.backpackWasOpen then
		return
	end
	local ourBackpack = hookedBags[BACKPACK_CONTAINER]
	if ourBackpack then
		return ourBackpack:Close()
	else
		local frame = GetContainerFrame(BACKPACK_CONTAINER)
		if frame then
			frame:Hide()
		end
	end
end

function addon:ToggleBackpack()
	local ourBackpack = hookedBags[BACKPACK_CONTAINER]
	if ourBackpack then
		return ourBackpack:Toggle()
	end
	local frame = GetContainerFrame(BACKPACK_CONTAINER)
	if frame then
		self:CloseAllBags()
	else
		self:OpenBackpack()
	end
end

--------------------------------------------------------------------------------
-- Track windows related to item interaction (merchant, mail, bank, ...)
--------------------------------------------------------------------------------

do
	local current
	function addon:UpdateInteractingWindow(event, ...)
		local new = strmatch(event, "^([_%w]+)_OPENED$") or strmatch(event, "^([_%w]+)_SHOW$")
		self:Debug("UpdateInteractingWindow", event, current, "=>", new, "|", ...)
		if new ~= current then
			local old = current
			current = new
			self.atBank = (current == "BANKFRAME")
			if (tonumber(self.db.profile.virtualStacks.notWhenTrading) or 0) > 1 then
				self:SendMessage("AdiBags_FiltersChanged", 0)
			end
			self:SendMessage("AdiBags_InteractingWindowChanged", new, old)
		end
	end

	function addon:GetInteractingWindow()
		return current
	end
end

--------------------------------------------------------------------------------
-- Bag prototype
--------------------------------------------------------------------------------

local bagProto = {
	Debug = addon.Debug,
	isBag = true,
}
addon.bagProto = bagProto

function bagProto:OnEnable()
	local open = false
	for id in pairs(self.bagIds) do
		local frame = GetContainerFrame(id)
		if frame then
			open = true
			frame:Hide()
		end
		hookedBags[id] = self
	end
	if self.PostEnable then
		self:PostEnable()
	end
	self:Debug("Enabled")
	if open then
		self:Open()
	end
end

function bagProto:OnDisable()
	local open = self:IsOpen()
	self:Close()
	for id in pairs(self.bagIds) do
		hookedBags[id] = nil
		if open then
			GetContainerFrame(id, true)
		end
	end
	if self.PostDisable then
		self:PostDisable()
	end
	self:Debug("Disabled")
end

function bagProto:Open()
	if not self:CanOpen() then
		return
	end
	local frame = self:GetFrame()
	if not frame:IsShown() then
		self:Debug("Open")
		frame:Show()
		addon:SendMessage("AdiBags_BagOpened", self.bagName, self)
		return true
	end
end

function bagProto:Close()
	if self.frame and self.frame:IsShown() then
		self:Debug("Close")
		self.frame:Hide()
		CloseMenus()
		addon:SendMessage("AdiBags_BagClosed", self.bagName, self)
		if self.PostClose then
			self:PostClose()
		end
		return true
	end
end

function bagProto:IsOpen()
	return self.frame and self.frame:IsShown()
end

function bagProto:CanOpen()
	return self:IsEnabled()
end

function bagProto:Toggle()
	if self:IsOpen() then
		self:Close()
	elseif self:CanOpen() then
		self:Open()
	end
end

function bagProto:HasFrame()
	return not not self.frame
end

function bagProto:GetFrame()
	if not self.frame then
		self.frame = self:CreateFrame()
		self.frame.CloseButton:SetScript("OnClick", function()
			self:Close()
		end)
		addon:SendMessage("AdiBags_BagFrameCreated", self)
	end
	return self.frame
end

function bagProto:CreateFrame()
	return addon:CreateContainerFrame(self.bagName, self.bagIds, self.isBank)
end

--------------------------------------------------------------------------------
-- Bags methods
--------------------------------------------------------------------------------

local bags = {}

local function CompareBags(a, b)
	return a.order < b.order
end

function addon:NewBag(name, order, bagIds, isBank, ...)
	self:Debug("NewBag", name, order, bagIds, isBank, ...)
	local bag = addon:NewModule(name, bagProto, "AceEvent-3.0", ...)
	bag.bagName = name
	bag.bagIds = bagIds
	bag.isBank = isBank
	bag.order = order
	tinsert(bags, bag)
	tsort(bags, CompareBags)
	return bag
end

do
	local function iterateOpenBags(numBags, index)
		while index < numBags do
			index = index + 1
			local bag = bags[index]
			if bag:IsEnabled() and bag:IsOpen() then
				return index, bag
			end
		end
	end

	local function iterateBags(numBags, index)
		while index < numBags do
			index = index + 1
			local bag = bags[index]
			if bag:IsEnabled() then
				return index, bag
			end
		end
	end

	function addon:IterateBags(onlyOpen)
		return onlyOpen and iterateOpenBags or iterateBags, #bags, 0
	end
end

function addon:IterateDefinedBags()
	return ipairs(bags)
end

--------------------------------------------------------------------------------
-- Helper for modules
--------------------------------------------------------------------------------

local hooks = {}

function addon:HookBagFrameCreation(target, callback)
	local hook = hooks[target]
	if not hook then
		local target, callback, seen = target, callback, {}
		hook = function(event, bag)
			if seen[bag] then
				return
			end
			seen[bag] = true
			local res, msg
			if type(callback) == "string" then
				res, msg = pcall(target[callback], target, bag)
			else
				res, msg = pcall(callback, bag)
			end
			if not res then
				geterrorhandler()(msg)
			end
		end
		hooks[target] = hook
	end
	local listen = false
	for index, bag in pairs(bags) do
		if bag:HasFrame() then
			hook("HookBagFrameCreation", bag)
		else
			listen = true
		end
	end
	if listen then
		target:RegisterMessage("AdiBags_BagFrameCreated", hook)
	end
end

--------------------------------------------------------------------------------
-- Backpack
--------------------------------------------------------------------------------

do
	-- L["Backpack"]
	local backpack = addon:NewBag("Backpack", 10, addon.BAG_IDS.BAGS, false, "AceHook-3.0")

	function backpack:PostEnable()
		self:RegisterMessage("AdiBags_InteractingWindowChanged")
	end

	function backpack:AdiBags_InteractingWindowChanged(event, window)
		if window then
			self.wasOpen = self:IsOpen()
			if not self.wasOpen then
				self:Open()
			end
		elseif not window and self:IsOpen() and not self.wasOpen then
			self:Close()
		end
	end
end

--------------------------------------------------------------------------------
-- Bank
--------------------------------------------------------------------------------

do
	-- L["Bank"]
	local bank = addon:NewBag("Bank", 20, addon.BAG_IDS.BANK, true, "AceHook-3.0")

	local function NOOP() end

	function bank:PostEnable()
		self:RegisterMessage("AdiBags_InteractingWindowChanged")

		BankFrame:Hide()
		self:RawHookScript(BankFrame, "OnEvent", NOOP, true)
		self:RawHook(BankFrame, "Show", "Open", true)
		self:RawHook(BankFrame, "Hide", "Close", true)
		self:RawHook(BankFrame, "IsShown", "IsOpen", true)

		if addon:GetInteractingWindow() == "BANKFRAME" then
			self:Open()
		end
	end

	function bank:PostDisable()
		if addon:GetInteractingWindow() == "BANKFRAME" then
			self.hooks[BankFrame].Show(BankFrame)
		end
	end

	function bank:AdiBags_InteractingWindowChanged(event, new, old)
		if new == "BANKFRAME" and not self:IsOpen() then
			self:Open()
		elseif old == "BANKFRAME" and self:IsOpen() then
			self:Close()
		end
	end

	function bank:CanOpen()
		return self:IsEnabled() and addon:GetInteractingWindow() == "BANKFRAME"
	end

	function bank:PostClose()
		CloseBankFrame()
	end
end

--------------------------------------------------------------------------------
-- Bag layout
--------------------------------------------------------------------------------

function addon:LayoutBags()
	local scale = self.db.profile.scale
	for index, bag in self:IterateBags() do
		if bag:HasFrame() then
			bag:GetFrame():SetScale(scale)
		end
	end
	for index, bag in self:IterateBags(true) do
		bag:GetFrame().Anchor:ApplySettings()
	end
end

function addon:ResetBagPositions()
	self.db.profile.scale = DEFAULT_SETTINGS.profile.scale
	local positions = self.db.profile.positions
	wipe(positions)
	for key, preset in pairs(DEFAULT_SETTINGS.profile.positions) do
		positions[key] = CopyTable(preset)
	end
	self:LayoutBags()
end

--------------------------------------------------------------------------------
-- Filter prototype
--------------------------------------------------------------------------------

local filterProto = {
	isFilter = true,
	priority = 0,
	Debug = addon.Debug,
	OpenOptions = function(self)
		return addon:OpenOptions("filters", self.filterName)
	end,
}
addon.filterProto = filterProto

function filterProto:OnEnable()
	addon:UpdateFilters()
end

function filterProto:OnDisable()
	addon:UpdateFilters()
end

function filterProto:GetPriority()
	return addon.db.profile.filterPriorities[self.filterName] or self.priority or 0
end

function filterProto:SetPriority(value)
	if value ~= self:GetPriority() then
		addon.db.profile.filterPriorities[self.filterName] = (value ~= self.priority) and value or nil
		addon:UpdateFilters()
	end
end

--------------------------------------------------------------------------------
-- Virtual stacks
--------------------------------------------------------------------------------

function addon:ShouldStack(slotData)
	local conf = self.db.profile.virtualStacks
	if not slotData.link then
		return conf.freeSpace, "*Free*"
	end
	local window, unstack = self:GetInteractingWindow(), 0
	if window then
		unstack = conf.notWhenTrading
		if unstack >= 4 and window ~= "BANKFRAME" then
			return
		end
	end
	local maxStack = slotData.maxStack or 1
	if maxStack > 1 then
		if conf.stackable then
			if (slotData.count or 1) == maxStack then
				return true, slotData.itemId
			elseif unstack < 3 then
				return conf.incomplete, slotData.itemId
			end
		end
	elseif conf.others and unstack < 2 then
		return true, self.GetDistinctItemID(slotData.link)
	end
end

--------------------------------------------------------------------------------
-- Filter handling
--------------------------------------------------------------------------------

function addon:InitializeFilters()
	self:SetupDefaultFilters()
	self:UpdateFilters()
end

local function CompareFilters(a, b)
	local prioA, prioB = a:GetPriority(), b:GetPriority()
	if prioA == prioB then
		return a.filterName < b.filterName
	else
		return prioA > prioB
	end
end

local activeFilters = {}
local allFilters = {}
function addon:UpdateFilters()
	wipe(allFilters)
	for name, filter in self:IterateModules() do
		if filter.isFilter then
			tinsert(allFilters, filter)
		end
	end
	tsort(allFilters, CompareFilters)
	wipe(activeFilters)
	for i, filter in ipairs(allFilters) do
		if filter:IsEnabled() then
			tinsert(activeFilters, filter)
		end
	end
	self:SendMessage("AdiBags_FiltersChanged")
end

function addon:IterateFilters()
	return ipairs(allFilters)
end

function addon:RegisterFilter(name, priority, Filter, ...)
	local filter
	if type(Filter) == "function" then
		filter = addon:NewModule(name, filterProto, ...)
		filter.Filter = Filter
	elseif Filter then
		filter = addon:NewModule(name, filterProto, Filter, ...)
	else
		filter = addon:NewModule(name, filterProto)
	end
	filter.filterName = name
	filter.priority = priority
	return filter
end

--------------------------------------------------------------------------------
-- Filtering process
--------------------------------------------------------------------------------

local safecall = addon.safecall
function addon:Filter(slotData, defaultSection, defaultCategory)
	for i, filter in ipairs(activeFilters) do
		local sectionName, category = safecall(filter.Filter, filter, slotData)
		if sectionName then
			--[===[@alpha@
			assert(type(sectionName) == "string", "Filter "..filter.name.." returned "..type(sectionName).." as section name instead of a string")
			assert(category == nil or type(category) == "string", "Filter "..filter.name.." returned "..type(category).." as category instead of a string")
			--@end-alpha@]===]
			return sectionName, category, filter.uiName
		end
	end
	return defaultSection, defaultCategory
end
