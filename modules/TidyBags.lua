local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local band = _G.bit.band
local ClearCursor = _G.ClearCursor
local CreateFrame = _G.CreateFrame
local GetContainerFreeSlots = _G.GetContainerFreeSlots
local GetContainerItemID = _G.GetContainerItemID
local GetContainerItemInfo = _G.GetContainerItemInfo
local GetContainerNumFreeSlots = _G.GetContainerNumFreeSlots
local GetContainerNumSlots = _G.GetContainerNumSlots
local GetCursorInfo = _G.GetCursorInfo
local GetItemInfo = _G.GetItemInfo
local InCombatLockdown = _G.InCombatLockdown
local ipairs = _G.ipairs
local KEYRING_CONTAINER = _G.KEYRING_CONTAINER
local next = _G.next
local pairs = _G.pairs
local PickupContainerItem = _G.PickupContainerItem
local PlaySound = _G.PlaySound
local select = _G.select
local setmetatable = _G.setmetatable
local SplitContainerItem = _G.SplitContainerItem
local tinsert = _G.tinsert
local tsort = _G.table.sort
local unpack = _G.unpack
local wipe = _G.wipe
--GLOBALS>

local GetSlotId = addon.GetSlotId
local GetBagSlotFromId = addon.GetBagSlotFromId

local mod = addon:NewModule("TidyBags", "AceEvent-3.0", "AceBucket-3.0")
mod.uiName = L["Tidy bags"]
mod.uiDesc =
	L['Tidy your bags by clicking on the small "T" button at the top of the window. Incomplete stacks are merged and special bags are filled with matching items. With the bank open, T also gathers identical items into the window you clicked.']

local bags = {}

-- Internal bag object
local bagProto = { Debug = addon.Debug }
local bagMeta = { __index = bagProto }

local TIDY_WATCHDOG_TIMEOUT = 5

local function AnyBagRunning()
	for _, bag in pairs(bags) do
		if bag.running then
			return true
		end
	end
end

local function ForceUnlock(reason)
	for _, bag in pairs(bags) do
		wipe(bag.locked)
		bag.running = nil
		bag.cached = nil
		bag.processing = nil
		bag:UpdateButton("ForceUnlock")
	end
	ClearCursor()
	if addon:SetGlobalLock(false) then
		addon:Debug("TidyBags: forced globalLock release -", reason)
	end
end

local watchdog = CreateFrame("Frame")
watchdog:Hide()
local watchdogTimeout = 0
local watchdogGraced
watchdog:SetScript("OnUpdate", function(self, elapsed)
	watchdogTimeout = watchdogTimeout - elapsed
	if watchdogTimeout > 0 then
		return
	end
	if not addon.globalLock then
		self:Hide()
		return
	end
	if GetCursorInfo() and not watchdogGraced then
		watchdogGraced = true
		watchdogTimeout = TIDY_WATCHDOG_TIMEOUT
		return
	end
	self:Hide()
	ForceUnlock("watchdog timeout")
end)

local function ArmWatchdog()
	watchdogTimeout = TIDY_WATCHDOG_TIMEOUT
	watchdogGraced = nil
	watchdog:Show()
end

local function DisarmWatchdog()
	watchdog:Hide()
	watchdogGraced = nil
end

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			autoTidy = false,
			mode = "consolidate",
		},
	})
end

function mod:OnEnable()
	for i, bag in addon:IterateDefinedBags() do
		local name = bag.bagName
		if not bags[name] then
			self:Debug("Adding bag", bag, name, bag.bagIds)
			bags[name] = setmetatable({
				name = "Tidy-" .. name,
				bagIds = bag.bagIds,
				isBank = bag.isBank,
				obj = bag,
				locked = {},
			}, bagMeta)
			self:Debug("Registered", bags[name])
		end
	end
	addon:HookBagFrameCreation(self, "OnBagFrameCreated")

	self:RegisterMessage("AdiBags_InteractingWindowChanged")
	self:RegisterBucketMessage("AdiBags_BagUpdated", 0.2)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "RefreshAllBags")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("LOOT_CLOSED", "AutomaticTidy")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "GlobalLockSafetyCheck")
	self:RegisterEvent("PLAYER_UNGHOST", "GlobalLockSafetyCheck")
	self:RegisterEvent("PLAYER_ALIVE", "GlobalLockSafetyCheck")

	for name, bag in pairs(bags) do
		bag:ShowButton()
	end
end

function mod:OnDisable()
	for name, bag in pairs(bags) do
		bag:HideButton()
	end
end

function mod:GetOptions()
	return {
		mode = {
			name = L["Tidy mode"],
			desc = L["Consolidate: with the bank open, T gathers every stackable item present on both sides into the window you clicked - incomplete stacks are topped up first, whole stacks then move into free slots, and an item without a free slot stays where it is. Local: T only merges incomplete stacks inside the window you clicked and fills profession bags."],
			type = "select",
			values = {
				consolidate = L["Consolidate with the other window"],
				localOnly = L["Tidy this window only"],
			},
			order = 5,
		},
		autoTidy = {
			name = L["Semi-automated tidy"],
			desc = L["Check this so tidying is performed when you close the loot windows or you leave merchants, mailboxes, etc."],
			type = "toggle",
			order = 10,
		},
	},
		addon:GetOptionHandler(self)
end

function mod:AdiBags_InteractingWindowChanged(event, new)
	if not new then
		return self:AutomaticTidy(event)
	end
end

function mod:OnBagFrameCreated(bag)
	bags[bag.bagName]:AttachContainer(bag:GetFrame())
end

function mod:AutomaticTidy(event)
	if not self.db.profile.autoTidy or InCombatLockdown() then
		return
	end
	self:Debug("AutomaticTidy on", event)
	for name, bag in pairs(bags) do
		bag:Tidy()
	end
end

local wasLocked = {}
local wasCached = {}
function mod:AdiBags_BagUpdated(bagIds)
	self:Debug("AdiBags_BagUpdated")
	wipe(wasLocked)
	wipe(wasCached)
	for name, bag in pairs(bags) do
		if bag:IsAvailable() then
			for bagID in pairs(bagIds) do
				if bag.cached then
					bag:Debug("Bag", bagID, "updated")
					wasCached[bag] = true
					bag.cached = nil
				end
				if bag.locked[bagID] then
					bag:Debug("Bag", bagID, "unlocked")
					bag.locked[bagID] = nil
					wasLocked[bag] = true
				end
			end
		end
	end
	for bag in pairs(wasLocked) do
		if bag.running and not next(bag.locked) then
			wasCached[bag] = nil
			bag:Process()
		end
	end
	for bag in pairs(wasCached) do
		bag:UpdateButton("BAG_UPDATE")
	end

	if addon.globalLock and AnyBagRunning() then
		ArmWatchdog()
	end
end

function mod:RefreshAllBags(event)
	for name, bag in pairs(bags) do
		bag.cached = nil
		bag:UpdateButton(event)
	end
end

function mod:GlobalLockSafetyCheck(event)
	if addon.globalLock then
		ForceUnlock(event)
	end
end

function mod:PLAYER_REGEN_ENABLED(event)
	self:GlobalLockSafetyCheck(event)
	self:RefreshAllBags(event)
	self:AutomaticTidy(event)
end

--------------------------------------------------------------------------------
-- Bag methods
--------------------------------------------------------------------------------

local function TidyButton_OnClick(button)
	PlaySound("igMainMenuOptionCheckBoxOn")
	addon:SendMessage("AdiBags_TidyBagsButtonClick")
	return button.bag:Tidy()
end

local function TidyButton_OnShow(button)
	return button.bag:UpdateButton("OnShow")
end

function bagProto:AttachContainer(container)
	self:Debug("Attaching container", container)
	local button = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
	button.bag = self
	button:SetText("T")
	button:SetWidth(20)
	button:SetHeight(20)
	button:SetScript("OnClick", TidyButton_OnClick)
	button:SetScript("OnShow", TidyButton_OnShow)
	addon.SetupTooltip(button, {
		L["Tidy bags"],
		L["Click to tidy bags."],
	}, "ANCHOR_TOPLEFT", 0, 8)
	container:AddHeaderWidget(button, 0)

	self.container = container
	self.button = button
end

function bagProto:ShowButton()
	if self.button then
		self.button:Show()
	end
end

function bagProto:HideButton()
	if self.button then
		self.button:Hide()
	end
end

function bagProto:UpdateButton(event)
	if self.button then
		--[===[@debug@
		self:Debug('UpdateButton on', event, self.running and "(running)" or "", 'GetNextMove:', self:GetNextMove())
		--@end-debug@]===]
		if not self.running and self:GetNextMove() then
			self.button:Enable()
		else
			self.button:Disable()
		end
	end
end

function bagProto:IsAvailable()
	return self.obj:CanOpen()
end

function bagProto:Tidy()
	if not self.running and self:IsAvailable() then
		self.running = true
		self:UpdateButton("Tidy")
		return self:Process()
	end
end

function bagProto:GetNextMove()
	if not self.cached then
		self.cached, self[1], self[2], self[3], self[4], self[5] = true, self:FindNextMove()
	end
	return unpack(self, 1, 5)
end

function bagProto:PickupItem(bag, slot, expectedCursorInfo, amount)
	if amount then
		SplitContainerItem(bag, slot, amount)
	else
		PickupContainerItem(bag, slot)
	end
	if GetCursorInfo() == expectedCursorInfo then
		if addon:SetGlobalLock(true) then
			self:Debug("Locked all items")
		end
		ArmWatchdog()
		if not self.locked[bag] then
			self:Debug("Bag", bag, "locked, waiting for update")
			self.locked[bag] = true
		end
		return true
	end
end

function bagProto:ProcessInternal()
	self:Debug("Processing")
	if not GetCursorInfo() then
		local fromBag, fromSlot, toBag, toSlot, amount = self:GetNextMove()
		if fromBag then
			self:Debug("Trying to move from", fromBag, fromSlot, "to", toBag, toSlot, "amount", amount)
			if self:PickupItem(fromBag, fromSlot, "item", amount) then
				if self:PickupItem(toBag, toSlot, nil) then
					self:Debug("Moved", fromBag, fromSlot, "to", toBag, toSlot)
					return
				end
			end
			self:Debug("Something failed !")
			ClearCursor()
		end
	end
	if addon:SetGlobalLock(false) then
		self:Debug("Unlocked all items")
	end
	DisarmWatchdog()
	self.running = nil
	self:UpdateButton("ProcessInternal")
	self:Debug("Done")
	addon:SendMessage("AdiBags_TidyBags")
end

function bagProto:Process()
	if self.running and not self.processing then
		self.processing = true
		self:ProcessInternal()
		self.processing = nil
	end
end

-- Tidying logic

local CanPutItemInContainer = addon.CanPutItemInContainer
local GetItemFamily = addon.GetItemFamily
local GetBagSlotFromId = addon.GetBagSlotFromId

-- Memoization tables
local itemMaxStackMemo = setmetatable({}, {
	__index = function(t, id)
		if not id then
			return
		end
		local count = select(8, GetItemInfo(id))
		if count then
			t[id] = count
		end
		return count
	end,
})
local itemFamilyMemo = setmetatable({}, {
	__index = function(t, id)
		if not id then
			return
		end
		local family = GetItemFamily(id)
		if family then
			t[id] = family
		end
		return family
	end,
})

local incompleteStacks = {}
local bagList = {}
local freeSlots = {}
local profBags = {}

local function PartialAmount(count, room)
	if not count or not room or room <= 0 then
		return nil
	end
	if room < count then
		return room
	end
end

function bagProto:FindNextMove()
	if InCombatLockdown() then
		return
	end

	wipe(bagList)
	for bag in pairs(self.bagIds) do
		local size = GetContainerNumSlots(bag)
		if size > 0 then
			tinsert(bagList, bag)
		end
	end
	tsort(bagList)
	self:Debug("FindNextMove in bags", unpack(bagList))

	-- Firstly, merge incomplete stacks
	wipe(incompleteStacks)
	wipe(profBags)
	for i, bag in ipairs(bagList) do
		local numFree, bagFamily = GetContainerNumFreeSlots(bag)
		if numFree > 0 and bagFamily ~= 0 and not profBags[bagFamily] then
			profBags[bagFamily] = bag
		end
		for slot = 1, GetContainerNumSlots(bag) do
			local id = GetContainerItemID(bag, slot)
			local maxStack = itemMaxStackMemo[id]
			if maxStack and maxStack > 1 then
				local _, count = GetContainerItemInfo(bag, slot)
				if id and count < maxStack then
					local existingStack = incompleteStacks[id]
					if existingStack then
						local toBag, toSlot = GetBagSlotFromId(existingStack)
						local _, toCount = GetContainerItemInfo(toBag, toSlot)
						toCount = toCount or 0
						self:Debug("FindNextMove: should merge stacks:", bag, slot, toBag, toSlot)
						if toBag < bag or (toBag == bag and toSlot < slot) then
							return bag, slot, toBag, toSlot, PartialAmount(count, maxStack - toCount)
						else
							return toBag, toSlot, bag, slot, PartialAmount(toCount, maxStack - count)
						end
					else
						incompleteStacks[id] = GetSlotId(bag, slot)
					end
				end
			end
		end
	end

	-- Then move profession materials into profession bags, if we have some
	if next(profBags) then
		for i, bag in ipairs(bagList) do
			local _, bagFamily = GetContainerNumFreeSlots(bag)
			if bagFamily == 0 then
				for slot = 1, GetContainerNumSlots(bag) do
					local id = GetContainerItemID(bag, slot)
					local itemFamily = itemFamilyMemo[id]
					if itemFamily and itemFamily ~= 0 then
						for family, toBag in pairs(profBags) do
							if band(family, itemFamily) ~= 0 then
								wipe(freeSlots)
								GetContainerFreeSlots(toBag, freeSlots)
								self:Debug(
									"FindNextMove: should move into profession bag:",
									bag,
									slot,
									toBag,
									freeSlots[1]
								)
								return bag, slot, toBag, freeSlots[1]
							end
						end
					end
				end
			end
		end
	end

	local fromBag, fromSlot, toBag, toSlot, amount = self:FindCrossMove(bagList)
	if fromBag then
		return fromBag, fromSlot, toBag, toSlot, amount
	end

	self:Debug("FindNextMove: nothing to do")
end

function bagProto:FindFreeSlot(bagList, itemId)
	for i, bag in ipairs(bagList) do
		if bag ~= KEYRING_CONTAINER and CanPutItemInContainer(itemId, bag) then
			wipe(freeSlots)
			GetContainerFreeSlots(bag, freeSlots)
			if freeSlots[1] then
				return bag, freeSlots[1]
			end
		end
	end
end

local crossPresent = {}
local crossStacks = {}
local crossBags = {}

function bagProto:FindCrossMove(bagList)
	if mod.db.profile.mode ~= "consolidate" then
		return
	end
	-- Пока банк закрыт, GetContainerNumSlots для его сумок врёт, а содержимое недоступно
	if addon:GetInteractingWindow() ~= "BANKFRAME" then
		return
	end

	wipe(crossPresent)
	wipe(crossStacks)
	for i, bag in ipairs(bagList) do
		for slot = 1, GetContainerNumSlots(bag) do
			local id = GetContainerItemID(bag, slot)
			local maxStack = itemMaxStackMemo[id]
			if id and maxStack and maxStack > 1 then
				crossPresent[id] = true
				if not crossStacks[id] then
					local _, count = GetContainerItemInfo(bag, slot)
					if count and count < maxStack then
						crossStacks[id] = GetSlotId(bag, slot)
					end
				end
			end
		end
	end
	if not next(crossPresent) then
		return
	end

	wipe(crossBags)
	for bag in pairs(self.isBank and addon.BAG_IDS.BAGS or addon.BAG_IDS.BANK) do
		if GetContainerNumSlots(bag) > 0 then
			tinsert(crossBags, bag)
		end
	end
	tsort(crossBags)

	-- Сначала доливаем неполные стопки: так перенос не занимает лишних слотов
	for i, bag in ipairs(crossBags) do
		for slot = 1, GetContainerNumSlots(bag) do
			local id = GetContainerItemID(bag, slot)
			local target = id and crossStacks[id]
			if target then
				local toBag, toSlot = GetBagSlotFromId(target)
				local _, count = GetContainerItemInfo(bag, slot)
				local _, toCount = GetContainerItemInfo(toBag, toSlot)
				local room = (itemMaxStackMemo[id] or 0) - (toCount or 0)
				if count and room > 0 then
					self:Debug("FindCrossMove: top up", bag, slot, "->", toBag, toSlot)
					return bag, slot, toBag, toSlot, PartialAmount(count, room)
				end
			end
		end
	end

	-- Затем перевозим целые стопки в свободные слоты
	for i, bag in ipairs(crossBags) do
		for slot = 1, GetContainerNumSlots(bag) do
			local id = GetContainerItemID(bag, slot)
			if id and crossPresent[id] then
				local toBag, toSlot = self:FindFreeSlot(bagList, id)
				if toBag then
					self:Debug("FindCrossMove: relocate", bag, slot, "->", toBag, toSlot)
					return bag, slot, toBag, toSlot
				end
			end
		end
	end
end
