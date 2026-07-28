local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local band = _G.bit.band
local floor = _G.floor
local GameTooltip = _G.GameTooltip
local GetContainerNumFreeSlots = _G.GetContainerNumFreeSlots
local geterrorhandler = _G.geterrorhandler
local GetItemFamily = _G.GetItemFamily
local GetItemInfo = _G.GetItemInfo
local GetItemInfoInstant = _G.GetItemInfoInstant
local ITEM_QUALITY_POOR = _G.ITEM_QUALITY_POOR
local ITEM_QUALITY_UNCOMMON = _G.ITEM_QUALITY_UNCOMMON
local pcall = _G.pcall
local select = _G.select
local setmetatable = _G.setmetatable
local strjoin = _G.strjoin
local strmatch = _G.strmatch
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type
--GLOBALS>

--------------------------------------------------------------------------------
-- (bag,slot) <=> slotId conversion
--------------------------------------------------------------------------------

function addon.GetSlotId(bag, slot)
	if bag and slot then
		return bag * 100 + slot
	end
end

function addon.GetBagSlotFromId(slotId)
	if slotId then
		return floor(slotId / 100), slotId % 100
	end
end

--------------------------------------------------------------------------------
-- Safe call
--------------------------------------------------------------------------------

local function safecall_return(success, ...)
	if success then
		return ...
	else
		geterrorhandler()((...))
	end
end

function addon.safecall(funcOrSelf, argOrMethod, ...)
	local func, arg
	if type(funcOrSelf) == "table" and type(argOrMethod) == "string" then
		func, arg = funcOrSelf[argOrMethod], funcOrSelf
	else
		func, arg = funcOrSelf, argOrMethod
	end
	if type(func) == "function" then
		return safecall_return(pcall(func, arg, ...))
	end
end

--------------------------------------------------------------------------------
-- Attaching tooltip to widgets
--------------------------------------------------------------------------------

local function WidgetTooltip_OnEnter(self)
	GameTooltip:SetOwner(self, self.tooltipAnchor, self.tootlipAnchorXOffset, self.tootlipAnchorYOffset)
	self:UpdateTooltip()
end

local function WidgetTooltip_OnLeave(self)
	if GameTooltip:GetOwner() == self then
		GameTooltip:Hide()
	end
end

local function WidgetTooltip_Update(self)
	GameTooltip:ClearLines()
	addon.safecall(self, "tooltipCallback", GameTooltip)
	GameTooltip:Show()
end

function addon.SetupTooltip(widget, content, anchor, xOffset, yOffset)
	if type(content) == "string" then
		widget.tooltipCallback = function(self, tooltip)
			tooltip:AddLine(content)
		end
	elseif type(content) == "table" then
		widget.tooltipCallback = function(self, tooltip)
			tooltip:AddLine(tostring(content[1]), 1, 1, 1)
			for i = 2, #content do
				tooltip:AddLine(tostring(content[i]))
			end
		end
	elseif type(content) == "function" then
		widget.tooltipCallback = content
	else
		return
	end
	widget.tooltipAnchor = anchor or "ANCHOR_TOPLEFT"
	widget.tootlipAnchorXOffset = xOffset or 0
	widget.tootlipAnchorYOffset = yOffset or 0
	widget.UpdateTooltip = WidgetTooltip_Update
	widget:HookScript("OnEnter", WidgetTooltip_OnEnter)
	widget:HookScript("OnLeave", WidgetTooltip_OnLeave)
end

--------------------------------------------------------------------------------
-- Item link checking
--------------------------------------------------------------------------------

function addon.IsValidItemLink(link)
	if type(link) == "string" then
		if strmatch(link, "keystone:") then
			return true
		end
		if strmatch(link, "item:[-:%d]+") and not strmatch(link, "item:%d+:0:0:0:0:0:0:0:0:0") then
			return true
		end
	end
end

--------------------------------------------------------------------------------
-- Get distinct item IDs from item links
--------------------------------------------------------------------------------

local function __GetDistinctItemID(link)
	if not link or not addon.IsValidItemLink(link) then
		return nil, true
	end
	local id, enchant, gem1, gem2, gem3, gem4, suffix =
		strmatch(link, "item:(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):%-?%d+:%-?%d+")
	id = tonumber(id)
	if not id then
		return nil, true
	end
	local equipSlot = select(9, GetItemInfo(id))
	if equipSlot == nil then
		return id, false
	end
	if equipSlot ~= "" and equipSlot ~= "INVTYPE_BAG" then

		id = strjoin(":", "item", id, enchant, gem1, gem2, gem3, gem4, suffix, "0", "0")
	end
	return id, true
end

local distinctIDs = setmetatable({}, {
	__index = function(t, link)
		local result, isFinal = __GetDistinctItemID(link)
		result = result or link
		if isFinal then
			t[link] = result
		end
		return result
	end,
})

function addon.GetDistinctItemID(link)
	return link and distinctIDs[link]
end

--------------------------------------------------------------------------------
-- Basic junk test
--------------------------------------------------------------------------------

local CLASS_MISCELLANEOUS, SUBCLASS_JUNK = 15, 0

function addon.IsJunkCategory(item)
	if not item then
		return false
	end
	local classID, subclassID = select(6, GetItemInfoInstant(item))
	return classID == CLASS_MISCELLANEOUS and subclassID == SUBCLASS_JUNK
end

function addon:IsJunk(itemId)
	local quality = select(3, GetItemInfo(itemId))
	return quality == ITEM_QUALITY_POOR
		or (quality and quality < ITEM_QUALITY_UNCOMMON and addon.IsJunkCategory(itemId))
end

--------------------------------------------------------------------------------
-- Item and container family
--------------------------------------------------------------------------------

local GetItemFamily, GetItemInfo, GetContainerNumFreeSlots = GetItemFamily, GetItemInfo, GetContainerNumFreeSlots

function addon.GetItemFamily(item)
	return select(9, GetItemInfo(item)) == "INVTYPE_BAG" and 0 or GetItemFamily(item)
end

function addon.CanPutItemInContainer(item, container)
	local freeSlots, containerFamily = GetContainerNumFreeSlots(container)
	local itemFamily = addon.GetItemFamily(item)
	return freeSlots > 0 and (containerFamily == 0 or band(itemFamily, containerFamily) ~= 0),
		freeSlots,
		itemFamily,
		containerFamily
end

local itemTooltipHandlers = {}

local function AdiBags_OnTooltipCleared(tt)
	tt.adibags_itemTooltipDone = nil
end

local function AdiBags_OnTooltipSetItem(tt)
	if tt.adibags_itemTooltipDone then
		return
	end
	tt.adibags_itemTooltipDone = true
	local _, itemLink = tt:GetItem()
	for i = 1, #itemTooltipHandlers do
		addon.safecall(itemTooltipHandlers[i], tt, itemLink)
	end
end

local itemTooltipHooked = false
function addon:RegisterItemTooltipHandler(callback)
	if not itemTooltipHooked then
		GameTooltip:HookScript("OnTooltipCleared", AdiBags_OnTooltipCleared)
		GameTooltip:HookScript("OnTooltipSetItem", AdiBags_OnTooltipSetItem)
		itemTooltipHooked = true
	end
	itemTooltipHandlers[#itemTooltipHandlers + 1] = callback
end
