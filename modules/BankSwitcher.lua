local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local GameTooltip = _G.GameTooltip
local GetContainerItemGUID = _G.GetContainerItemGUID
local GetContainerItemID = _G.GetContainerItemID
local GetContainerItemInfo = _G.GetContainerItemInfo
local IsItemLockedByGUID = _G.IsItemLockedByGUID
local select = _G.select
local tremove = _G.tremove
local UseContainerItem = _G.UseContainerItem
local wipe = _G.wipe
--GLOBALS>

local mod = addon:NewModule("BankSwitcher", "AceEvent-3.0", "AceTimer-3.0")
mod.uiName = L["Bank Switcher"]
mod.uiDesc = L["Move items from and to back by right-clicking on section headers."]

local PUMP_INTERVAL = 0.15
local MAX_ATTEMPTS = 3
local MAX_WAITS = 40

local queue = {}
local pumpTimer

local function StopPump()
	if pumpTimer then
		mod:CancelTimer(pumpTimer)
		pumpTimer = nil
	end
	wipe(queue)
end

local function IsPending(bag, slot)
	if select(3, GetContainerItemInfo(bag, slot)) then
		return true
	end
	local guid = GetContainerItemGUID and GetContainerItemGUID(bag, slot)
	return (guid and IsItemLockedByGUID and IsItemLockedByGUID(guid)) and true or false
end

local function Pump()
	if addon:GetInteractingWindow() ~= "BANKFRAME" then
		return StopPump()
	end
	local entry = queue[1]
	while entry and GetContainerItemID(entry.bag, entry.slot) ~= entry.id do
		tremove(queue, 1)
		entry = queue[1]
	end
	if not entry then
		return StopPump()
	end
	if IsPending(entry.bag, entry.slot) then
		entry.waits = entry.waits + 1
		if entry.waits >= MAX_WAITS then
			tremove(queue, 1)
		end
		return
	end
	entry.waits = 0
	if entry.attempts < MAX_ATTEMPTS and addon.CanStoreInReagentBank(entry.bag, entry.slot) then
		entry.attempts = entry.attempts + 1
		UseContainerItem(entry.bag, entry.slot, nil, true)
	else
		tremove(queue, 1)
		UseContainerItem(entry.bag, entry.slot)
	end
end

local function Enqueue(bag, slot, id)
	queue[#queue + 1] = { bag = bag, slot = slot, id = id, attempts = 0, waits = 0 }
	if not pumpTimer then
		pumpTimer = mod:ScheduleRepeatingTimer(Pump, PUMP_INTERVAL)
		Pump()
	end
end

function mod:OnEnable()
	self:RegisterMessage("AdiBags_InteractingWindowChanged")
	self:AdiBags_InteractingWindowChanged("OnEnable", addon:GetInteractingWindow())
end

function mod:OnDisable()
	StopPump()
	addon.UnregisterAllSectionHeaderScripts(self)
end

function mod:OnEnterSectionHeader(_, header)
	GameTooltip:SetOwner(header, "ANCHOR_RIGHT", 0, 0)
	GameTooltip:AddLine(L["Right-click to move these items."])
	GameTooltip:Show()
end

function mod:OnLeaveSectionHeader(_, header)
	if GameTooltip:GetOwner() == header then
		GameTooltip:Hide()
	end
end

function mod:OnClickSectionHeader(_, header, button)
	if button ~= "RightButton" then
		return
	end
	for slotId, bag, slot in header.section:IterateContainerSlots() do
		local id = GetContainerItemID(bag, slot)
		if id and addon.CanStoreInReagentBank(bag, slot) then
			Enqueue(bag, slot, id)
		else
			UseContainerItem(bag, slot)
		end
	end
end

function mod:AdiBags_InteractingWindowChanged(_, new, old)
	if new == "BANKFRAME" then
		addon.RegisterSectionHeaderScript(self, "OnEnter", "OnEnterSectionHeader")
		addon.RegisterSectionHeaderScript(self, "OnLeave", "OnLeaveSectionHeader")
		addon.RegisterSectionHeaderScript(self, "OnClick", "OnClickSectionHeader")
	elseif old == "BANKFRAME" then
		StopPump()
		addon.UnregisterAllSectionHeaderScripts(self)
	end
end
