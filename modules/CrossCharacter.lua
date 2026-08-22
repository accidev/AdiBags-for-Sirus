local addonName, addon = ...
local L = addon.L

local _G = _G
local pairs = pairs
local ipairs = ipairs
local format = format
local select = select
local type = type
local tinsert = table.insert
local tsort = table.sort
local tconcat = table.concat
local wipe = wipe
local tonumber = tonumber
local strmatch = string.match
local strsub = string.sub
local time = time
local GetContainerNumSlots = _G.GetContainerNumSlots
local GetContainerNumFreeSlots = _G.GetContainerNumFreeSlots
local GetContainerItemInfo = _G.GetContainerItemInfo
local GetContainerItemLink = _G.GetContainerItemLink
local GetInventoryItemLink = _G.GetInventoryItemLink
local GetInventoryItemCount = _G.GetInventoryItemCount
local GetMoney = _G.GetMoney
local GetRealmName = _G.GetRealmName
local UnitName = _G.UnitName
local UnitClass = _G.UnitClass
local GameTooltip = _G.GameTooltip
local NUM_BAG_SLOTS = _G.NUM_BAG_SLOTS
local NUM_BANKBAGSLOTS = _G.NUM_BANKBAGSLOTS or 7
local BANK_CONTAINER = _G.BANK_CONTAINER or -1
local KEYRING_CONTAINER = _G.KEYRING_CONTAINER or -2
local REAGENTBANK_CONTAINER = _G.REAGENTBANK_CONTAINER
local INVSLOT_FIRST_EQUIPPED = _G.INVSLOT_FIRST_EQUIPPED or 1
local INVSLOT_LAST_EQUIPPED = _G.INVSLOT_LAST_EQUIPPED or 19
local GetCurrencyListInfo = _G.GetCurrencyListInfo
local GetCurrencyListSize = _G.GetCurrencyListSize
local ExpandCurrencyList = _G.ExpandCurrencyList
local GetBackpackCurrencyInfo = _G.GetBackpackCurrencyInfo
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local hooksecurefunc = _G.hooksecurefunc

local mod = addon:NewModule("CrossCharacter", "AceEvent-3.0", "AceBucket-3.0", "AceTimer-3.0")
mod.uiName = L["Cross-character items"]
mod.uiDesc = L["Show item and currency counts from other characters in tooltips."]

local DB_VERSION = 3

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		global = {
			realms = {},
		},
		profile = {
			showItems = true,
			showMoney = true,
			showCurrencies = true,
			showOtherRealms = false,
			saveLayout = true,
		},
	})
	addon.db.RegisterCallback(self, "OnProfileChanged", "OnProfileUpdated")
	addon.db.RegisterCallback(self, "OnProfileCopied", "OnProfileUpdated")
	addon.db.RegisterCallback(self, "OnProfileReset", "OnProfileUpdated")
end

local currentPlayer, currentRealm, currentClass
local entriesDirty = true

function mod:OnProfileUpdated()
	entriesDirty = true
end

local function MigrateDB()
	local db = mod.db.global
	local version = db.version or 1
	if version >= DB_VERSION then
		return
	end
	if version < 2 then
		for _, realm in pairs(db.realms) do
			for _, char in pairs(realm) do
				char.currencies = {}
			end
		end
	end
	if version < 3 then
		for _, realm in pairs(db.realms) do
			for _, char in pairs(realm) do
				if type(char.snapshot) ~= "table" then
					char.snapshot = { bags = {}, bank = {} }
				end
			end
		end
	end
	db.version = DB_VERSION
end

local function GetClassColor(class)
	local color = RAID_CLASS_COLORS[class]
	if color then
		return color.r, color.g, color.b
	end
	return 1, 1, 1
end

local SILVER = "|cffc7c7cf%s|r"
local TEAL = "|cff00ff9a%s|r"

local function GetItemId(link)
	if not link then
		return nil
	end
	local id = link:match("item:(%d+)")
	return tonumber(id)
end

local function EnsureCharDB()
	local realms = mod.db.global.realms
	local realmDB = realms[currentRealm]
	if not realmDB then
		realmDB = {}
		realms[currentRealm] = realmDB
		entriesDirty = true
	end
	local charDB = realmDB[currentPlayer]
	if not charDB then
		charDB = {
			class = currentClass,
			money = 0,
			items = {},
			currencies = {},
		}
		realmDB[currentPlayer] = charDB
		entriesDirty = true
	end
	if type(charDB.snapshot) ~= "table" then
		charDB.snapshot = { bags = {}, bank = {} }
	end
	charDB.class = currentClass
	return charDB
end

local linkFields = {}

local function EncodeSlot(link, count)
	local id, ench, g1, g2, g3, g4, suffix, unique =
		strmatch(link, "item:(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+)")
	if not id then
		id = strmatch(link, "item:(%-?%d+)")
		if not id then
			return nil
		end
		ench, g1, g2, g3, g4, suffix, unique = "0", "0", "0", "0", "0", "0", "0"
	end

	linkFields[1], linkFields[2], linkFields[3], linkFields[4] = id, ench, g1, g2
	linkFields[5], linkFields[6], linkFields[7], linkFields[8] = g3, g4, suffix, unique

	local last = 1
	for i = 8, 2, -1 do
		if linkFields[i] ~= "0" then
			last = i
			break
		end
	end

	local body = tconcat(linkFields, ":", 1, last)
	if count and count > 1 then
		body = body .. "x" .. count
	end
	return body
end

local function DecodeSlot(body)
	local count = 1
	local mult = strmatch(body, "x(%d+)$")
	if mult then
		count = tonumber(mult) or 1
		body = strsub(body, 1, -(#mult + 2))
	end

	local num = 0
	for field in body:gmatch("[^:]+") do
		num = num + 1
		linkFields[num] = field
	end
	if num == 0 then
		return nil
	end
	for i = num + 1, 8 do
		linkFields[i] = "0"
	end
	linkFields[9] = "0"

	local id = tonumber(linkFields[1])
	if not id then
		return nil
	end
	return id, "item:" .. tconcat(linkFields, ":", 1, 9), count
end

local encodeBuffer = {}

local function EncodeContainer(bag)
	local numSlots = GetContainerNumSlots(bag) or 0
	if numSlots == 0 then
		return nil
	end

	local num = 1
	encodeBuffer[1] = numSlots
	for slot = 1, numSlots do
		local link = GetContainerItemLink(bag, slot)
		if link then
			local _, count = GetContainerItemInfo(bag, slot)
			local body = EncodeSlot(link, count)
			if body then
				num = num + 1
				encodeBuffer[num] = slot .. "=" .. body
			end
		end
	end
	return tconcat(encodeBuffer, ";", 1, num)
end

-- Возвращает { size = <всего слотов>, [слот] = { id, link, count } } либо nil
function mod:DecodeContainer(text)
	if type(text) ~= "string" then
		return nil
	end
	local content
	for chunk in text:gmatch("[^;]+") do
		if not content then
			content = { size = tonumber(chunk) or 0 }
		else
			local slot, body = strmatch(chunk, "^(%d+)=(.+)$")
			slot = tonumber(slot)
			if slot and body then
				local id, link, count = DecodeSlot(body)
				if id then
					content[slot] = { id = id, link = link, count = count }
				end
			end
		end
	end
	return content
end

local function IsReagentBankReadable()
	if not REAGENTBANK_CONTAINER then
		return false
	end
	return (GetContainerNumSlots(REAGENTBANK_CONTAINER) or 0) > 0
end

local function SaveContainers(store, first, last, extra)
	for bag = first, last do
		store[bag] = EncodeContainer(bag)
	end
	if extra then
		store[extra] = EncodeContainer(extra)
	end
end

function mod:SaveBagLayout()
	if not self.db.profile.saveLayout then
		return
	end
	local snapshot = EnsureCharDB().snapshot
	wipe(snapshot.bags)
	SaveContainers(snapshot.bags, 0, NUM_BAG_SLOTS, KEYRING_CONTAINER)
end

function mod:SaveBankLayout()
	if not self.db.profile.saveLayout then
		return
	end
	local charDB = EnsureCharDB()
	local snapshot = charDB.snapshot
	local reagent = REAGENTBANK_CONTAINER and snapshot.bank[REAGENTBANK_CONTAINER]
	wipe(snapshot.bank)
	SaveContainers(snapshot.bank, NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS, BANK_CONTAINER)
	if REAGENTBANK_CONTAINER then
		if IsReagentBankReadable() then
			reagent = EncodeContainer(REAGENTBANK_CONTAINER)
		end
		snapshot.bank[REAGENTBANK_CONTAINER] = reagent
	end
	charDB.bankSeen = time()
end

local function EnsureItem(items, id)
	local data = items[id]
	if not data then
		data = { bags = 0, bank = 0, equipped = 0 }
		items[id] = data
	end
	return data
end

local function RemoveEmptyItems(items)
	for id, data in pairs(items) do
		if data.bags == 0 and data.bank == 0 and data.equipped == 0 and (data.reagentBank or 0) == 0 then
			items[id] = nil
		end
	end
end

function mod:SaveMoney()
	EnsureCharDB().money = GetMoney()
end

function mod:SaveEquipped()
	local items = EnsureCharDB().items

	for _, data in pairs(items) do
		data.equipped = 0
	end

	for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
		local link = GetInventoryItemLink("player", slot)
		if link then
			local itemId = GetItemId(link)
			if itemId then
				local count = GetInventoryItemCount("player", slot) or 1
				local data = EnsureItem(items, itemId)
				data.equipped = data.equipped + count
			end
		end
	end

	RemoveEmptyItems(items)
end

function mod:SaveBagItems()
	local items = EnsureCharDB().items

	for _, data in pairs(items) do
		data.bags = 0
		data.equipped = 0
	end

	for bag = 0, NUM_BAG_SLOTS do
		local numSlots = GetContainerNumSlots(bag)
		for slot = 1, numSlots do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local itemId = GetItemId(link)
				if itemId then
					local _, count = GetContainerItemInfo(bag, slot)
					local data = EnsureItem(items, itemId)
					data.bags = data.bags + (count or 1)
				end
			end
		end
	end

	local keySlots = GetContainerNumSlots(KEYRING_CONTAINER)
	for slot = 1, keySlots do
		local link = GetContainerItemLink(KEYRING_CONTAINER, slot)
		if link then
			local itemId = GetItemId(link)
			if itemId then
				local _, count = GetContainerItemInfo(KEYRING_CONTAINER, slot)
				local data = EnsureItem(items, itemId)
				data.bags = data.bags + (count or 1)
			end
		end
	end

	for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
		local link = GetInventoryItemLink("player", slot)
		if link then
			local itemId = GetItemId(link)
			if itemId then
				local count = GetInventoryItemCount("player", slot) or 1
				local data = EnsureItem(items, itemId)
				data.equipped = data.equipped + count
			end
		end
	end

	RemoveEmptyItems(items)
	self:SaveBagLayout()
end

local function IsBankReadable()
	local numSlots = GetContainerNumSlots(BANK_CONTAINER)
	if not numSlots or numSlots == 0 then
		return false
	end
	if (GetContainerNumFreeSlots(BANK_CONTAINER) or 0) > 0 then
		return true
	end
	for slot = 1, numSlots do
		if GetContainerItemLink(BANK_CONTAINER, slot) then
			return true
		end
	end
	for bag = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
		if (GetContainerNumSlots(bag) or 0) > 0 then
			return true
		end
	end
	return false
end

function mod:SaveBankItems()
	if not IsBankReadable() then
		return
	end

	local items = EnsureCharDB().items

	for _, data in pairs(items) do
		data.bank = 0
	end

	local numSlots = GetContainerNumSlots(BANK_CONTAINER)
	for slot = 1, numSlots do
		local link = GetContainerItemLink(BANK_CONTAINER, slot)
		if link then
			local itemId = GetItemId(link)
			if itemId then
				local _, count = GetContainerItemInfo(BANK_CONTAINER, slot)
				local data = EnsureItem(items, itemId)
				data.bank = data.bank + (count or 1)
			end
		end
	end

	for bag = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
		local numSlots = GetContainerNumSlots(bag)
		for slot = 1, numSlots do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local itemId = GetItemId(link)
				if itemId then
					local _, count = GetContainerItemInfo(bag, slot)
					local data = EnsureItem(items, itemId)
					data.bank = data.bank + (count or 1)
				end
			end
		end
	end

	if IsReagentBankReadable() then
		for _, data in pairs(items) do
			data.reagentBank = 0
		end
		for slot = 1, GetContainerNumSlots(REAGENTBANK_CONTAINER) do
			local link = GetContainerItemLink(REAGENTBANK_CONTAINER, slot)
			if link then
				local itemId = GetItemId(link)
				if itemId then
					local _, count = GetContainerItemInfo(REAGENTBANK_CONTAINER, slot)
					local data = EnsureItem(items, itemId)
					data.reagentBank = (data.reagentBank or 0) + (count or 1)
				end
			end
		end
	end

	RemoveEmptyItems(items)
	self:SaveBankLayout()
end

function mod:SaveCurrencies()
	local size = GetCurrencyListSize()
	if not size or size == 0 then
		return
	end

	local charDB = EnsureCharDB()
	wipe(charDB.currencies)

	local collapsed = {}
	local index = 0
	repeat
		index = index + 1
		local name, isHeader, isExpanded, _, _, count, _, _, itemID = GetCurrencyListInfo(index)
		if name then
			if isHeader then
				if not isExpanded then
					tinsert(collapsed, 1, index)
					ExpandCurrencyList(index, 1)
					size = GetCurrencyListSize()
				end
			else
				if itemID and count and count > 0 then
					charDB.currencies[itemID] = {
						count = count,
						name = name,
					}
				end
			end
		end
	until index >= size

	for _, i in ipairs(collapsed) do
		ExpandCurrencyList(i, 0)
	end
end

local sortedEntries = {}

local function CompareEntries(a, b)
	local aIsCurrent = (a.name == currentPlayer and a.realm == currentRealm)
	local bIsCurrent = (b.name == currentPlayer and b.realm == currentRealm)
	if aIsCurrent then
		return true
	end
	if bIsCurrent then
		return false
	end
	if a.realm ~= b.realm then
		return a.realm < b.realm
	end
	return a.name < b.name
end

local function CollectEntries()
	if not entriesDirty then
		return sortedEntries
	end

	wipe(sortedEntries)
	local realms = mod.db.global.realms
	local showOtherRealms = mod.db.profile.showOtherRealms

	if showOtherRealms then
		for realm, chars in pairs(realms) do
			for name, data in pairs(chars) do
				tinsert(sortedEntries, { name = name, realm = realm, data = data })
			end
		end
	else
		local realmDB = realms[currentRealm]
		if realmDB then
			for name, data in pairs(realmDB) do
				tinsert(sortedEntries, { name = name, realm = currentRealm, data = data })
			end
		end
	end

	tsort(sortedEntries, CompareEntries)

	entriesDirty = false
	return sortedEntries
end

local allEntries = {}

function mod:GetAllEntries()
	wipe(allEntries)
	for realm, chars in pairs(self.db.global.realms) do
		for name, data in pairs(chars) do
			tinsert(allEntries, { name = name, realm = realm, data = data })
		end
	end
	tsort(allEntries, CompareEntries)
	return allEntries
end

function mod:GetIdentity()
	return currentPlayer, currentRealm
end

function mod:GetCharData(name, realm)
	local realmDB = self.db.global.realms[realm]
	return realmDB and realmDB[name]
end

mod.ClassColor = GetClassColor

local function GetDisplayName(entry)
	if mod.db.profile.showOtherRealms and entry.realm ~= currentRealm then
		return entry.name .. " - " .. entry.realm
	end
	return entry.name
end

local function FormatCount(bagCount, bankCount, equipCount)
	local parts = {}
	local total = bagCount + bankCount + equipCount

	if total == 0 then
		return nil
	end

	if bagCount > 0 then
		tinsert(parts, L["Bags"] .. ": " .. bagCount)
	end
	if bankCount > 0 then
		tinsert(parts, L["Bank"] .. ": " .. bankCount)
	end
	if equipCount > 0 then
		tinsert(parts, L["Equipped"])
	end

	local detail = table.concat(parts, ", ")

	if
		(bagCount > 0 and bankCount == 0 and equipCount == 0)
		or (bagCount == 0 and bankCount > 0 and equipCount == 0)
		or (bagCount == 0 and bankCount == 0 and equipCount > 0)
	then
		return format(TEAL, detail)
	end

	return format(TEAL, total) .. format(SILVER, format(" (%s)", detail))
end

function mod:AddItemOwners(tooltip, itemLink)
	if not self.db.profile.showItems then
		return
	end

	local itemId = GetItemId(itemLink)
	if not itemId then
		return
	end

	local found = false
	local entries = CollectEntries()

	for _, entry in ipairs(entries) do
		local charData = entry.data
		if charData and charData.items then
			local itemData = charData.items[itemId]
			if itemData then
				local bagCount = itemData.bags or 0
				local bankCount = (itemData.bank or 0) + (itemData.reagentBank or 0)
				local equipCount = itemData.equipped or 0
				local info = FormatCount(bagCount, bankCount, equipCount)
				if info then
					if not found then
						tooltip:AddLine(" ")
						tooltip:AddLine(L["Other characters"], 1, 0.82, 0)
						found = true
					end
					local r, g, b = GetClassColor(charData.class)
					tooltip:AddDoubleLine(GetDisplayName(entry), info, r, g, b)
				end
			end
		end
	end

	if found then
		tooltip:Show()
	end
end

local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

local function FormatMoney(copper)
	if not copper or copper == 0 then
		return nil
	end
	local gold = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)
	local cop = copper % 100
	local parts = {}
	if gold > 0 then
		tinsert(parts, format("|cffffffff%d|r%s", gold, GOLD_ICON))
	end
	if silver > 0 then
		tinsert(parts, format("|cffffffff%d|r%s", silver, SILVER_ICON))
	end
	if cop > 0 then
		tinsert(parts, format("|cffffffff%d|r%s", cop, COPPER_ICON))
	end
	return table.concat(parts, " ")
end

function mod:AddMoneyTooltip(tooltip)
	if not self.db.profile.showMoney then
		return
	end

	local entries = CollectEntries()
	local totalMoney = 0
	local found = false

	for _, entry in ipairs(entries) do
		local charData = entry.data
		if charData and charData.money and charData.money > 0 then
			if not found then
				tooltip:AddLine(" ")
				tooltip:AddLine(L["Other characters"], 1, 0.82, 0)
				found = true
			end
			local r, g, b = GetClassColor(charData.class)
			tooltip:AddDoubleLine(GetDisplayName(entry), FormatMoney(charData.money), r, g, b)
			totalMoney = totalMoney + charData.money
		end
	end

	if found and #entries > 1 then
		tooltip:AddLine(" ")
		tooltip:AddDoubleLine(L["Total"], FormatMoney(totalMoney), 1, 0.82, 0)
	end

	if found then
		tooltip:Show()
	end
end

function mod:AddCurrencyTooltip(tooltip, currencyId)
	if not self.db.profile.showCurrencies or not currencyId then
		return
	end

	local entries = CollectEntries()
	local found = false

	for _, entry in ipairs(entries) do
		local charData = entry.data
		if charData and charData.currencies then
			local currData = charData.currencies[currencyId]
			if currData and currData.count and currData.count > 0 then
				if not found then
					tooltip:AddLine(" ")
					tooltip:AddLine(L["Other characters"], 1, 0.82, 0)
					found = true
				end
				local r, g, b = GetClassColor(charData.class)
				tooltip:AddDoubleLine(GetDisplayName(entry), format(TEAL, currData.count), r, g, b)
			end
		end
	end

	if found then
		tooltip:Show()
	end
end

local bankUpdateTimer
local currencyUpdateTimer
local bankOpen = false

function mod:OnEnable()
	currentPlayer = UnitName("player")
	currentRealm = GetRealmName()
	currentClass = select(2, UnitClass("player"))

	MigrateDB()

	self:SaveMoney()
	self:SaveBagItems()
	self:SaveCurrencies()
	EnsureCharDB().lastSeen = time()

	self:RegisterBucketEvent("BAG_UPDATE", 0.2, "OnBagUpdate")
	self:RegisterEvent("PLAYER_MONEY", "OnMoneyUpdate")
	self:RegisterEvent("BANKFRAME_OPENED", "OnBankOpened")
	self:RegisterEvent("BANKFRAME_CLOSED", "OnBankClosed")
	self:RegisterEvent("PLAYERBANKSLOTS_CHANGED", "OnBankChanged")
	self:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED", "OnBankChanged")
	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "OnCurrencyUpdate")
	self:RegisterEvent("KNOWN_CURRENCY_TYPES_UPDATE", "OnCurrencyUpdate")
	self:RegisterEvent("PLAYER_LOGOUT", "OnLogout")
	self:RegisterBucketEvent("UNIT_INVENTORY_CHANGED", 0.2, "OnEquipmentChanged")

	if not self.hooked then
		addon:RegisterItemTooltipHandler(function(tt, itemLink)
			if mod:IsEnabled() and itemLink then
				mod:AddItemOwners(tt, itemLink)
			end
		end)

		hooksecurefunc(GameTooltip, "SetCurrencyToken", function(tt, index)
			if not mod:IsEnabled() then
				return
			end
			local itemID = select(9, GetCurrencyListInfo(index))
			if itemID then
				mod:AddCurrencyTooltip(tt, itemID)
			end
		end)

		if GameTooltip.SetBackpackToken and GetBackpackCurrencyInfo then
			hooksecurefunc(GameTooltip, "SetBackpackToken", function(tt, id)
				if not mod:IsEnabled() then
					return
				end
				local itemID = select(5, GetBackpackCurrencyInfo(id))
				if itemID then
					mod:AddCurrencyTooltip(tt, itemID)
				end
			end)
		end

		self.hooked = true
	end
end

function mod:OnDisable()
	if bankUpdateTimer then
		self:CancelTimer(bankUpdateTimer)
		bankUpdateTimer = nil
	end
	if currencyUpdateTimer then
		self:CancelTimer(currencyUpdateTimer)
		currencyUpdateTimer = nil
	end
	bankOpen = false
end

function mod:OnBagUpdate()
	self:SaveBagItems()
end

function mod:OnMoneyUpdate()
	self:SaveMoney()
end

local function ScheduleBankSave()
	if bankUpdateTimer then
		mod:CancelTimer(bankUpdateTimer)
	end
	bankUpdateTimer = mod:ScheduleTimer(function()
		bankUpdateTimer = nil
		mod:SaveBankItems()
	end, 0.3)
end

function mod:OnBankOpened()
	bankOpen = true
	ScheduleBankSave()
end

if REAGENTBANK_CONTAINER then
	local frame = _G.CreateFrame("Frame")
	if frame.RegisterCustomEvent then
		frame:SetScript("OnEvent", function()
			if bankOpen then
				ScheduleBankSave()
			end
		end)
		frame:RegisterCustomEvent("PLAYERREAGENTBANKSLOTS_CHANGED")
		frame:RegisterCustomEvent("REAGENTBANK_UPDATE")
	end
end

function mod:OnBankClosed()
	if bankUpdateTimer then
		self:CancelTimer(bankUpdateTimer)
		bankUpdateTimer = nil
	end
	if bankOpen then
		self:SaveBankItems()
		bankOpen = false
	end
end

function mod:OnBankChanged()
	if not bankOpen then
		return
	end
	ScheduleBankSave()
end

function mod:OnCurrencyUpdate()
	if currencyUpdateTimer then
		self:CancelTimer(currencyUpdateTimer)
	end
	currencyUpdateTimer = self:ScheduleTimer(function()
		currencyUpdateTimer = nil
		mod:SaveCurrencies()
	end, 1.0)
end

function mod:OnEquipmentChanged(units)
	if units["player"] then
		self:SaveEquipped()
	end
end

function mod:OnLogout()
	self:SaveMoney()
	self:SaveBagItems()
	if bankOpen then
		self:SaveBankItems()
	end
	self:SaveCurrencies()
	EnsureCharDB().lastSeen = time()
end

function mod:GetOptions()
	return {
		showItems = {
			name = L["Show items on other characters"],
			desc = L["Show item counts from other characters in item tooltips."],
			type = "toggle",
			order = 10,
			width = "double",
		},
		showMoney = {
			name = L["Show money on other characters"],
			desc = L["Show gold from other characters in the money tooltip."],
			type = "toggle",
			order = 20,
			width = "double",
		},
		showCurrencies = {
			name = L["Show currencies on other characters"],
			desc = L["Show currency counts from other characters in the currency tooltip."],
			type = "toggle",
			order = 30,
			width = "double",
		},
		showOtherRealms = {
			name = L["Show other realms"],
			desc = L["Show characters from other realms. When disabled, only characters from the current realm are shown."],
			type = "toggle",
			order = 35,
			width = "double",
			set = function(info, value)
				info.handler:Set(info, value)
				entriesDirty = true
			end,
		},
		saveLayout = {
			name = L["Save character bag layout"],
			desc = L["Store a per-slot snapshot of bags and bank so they can be previewed later."],
			type = "toggle",
			order = 37,
			width = "double",
		},
		deleteChar = {
			name = L["Delete character data"],
			type = "select",
			order = 40,
			width = "double",
			values = function()
				local vals = {}
				local realms = mod.db.global.realms
				for realm, chars in pairs(realms) do
					for name, _ in pairs(chars) do
						if not (name == currentPlayer and realm == currentRealm) then
							local key = name .. "\001" .. realm
							vals[key] = name .. " - " .. realm
						end
					end
				end
				return vals
			end,
			get = function()
				return nil
			end,
			set = function(_, key)
				local name, realm = key:match("^(.+)\001(.+)$")
				if name and realm and mod.db.global.realms[realm] then
					mod.db.global.realms[realm][name] = nil
					local hasChars = false
					for _ in pairs(mod.db.global.realms[realm]) do
						hasChars = true
						break
					end
					if not hasChars then
						mod.db.global.realms[realm] = nil
					end
					entriesDirty = true
					addon:SendMessage("AdiBags_CharacterDataDeleted", name, realm)
				end
			end,
			confirm = function(_, key)
				local name, realm = key:match("^(.+)\001(.+)$")
				local display = name and realm and (name .. " - " .. realm) or key
				return format(L["Are you sure you want to delete data for %s?"], display)
			end,
		},
	},
		addon:GetOptionHandler(self)
end
