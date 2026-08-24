local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local CursorHasItem = _G.CursorHasItem
local format = _G.format
local GameTooltip = _G.GameTooltip
local GetCoinTextureString = _G.GetCoinTextureString
local GetContainerFreeSlots = _G.GetContainerFreeSlots
local GetContainerNumSlots = _G.GetContainerNumSlots
local GetScreenWidth = _G.GetScreenWidth
local pairs = _G.pairs
local PickupContainerItem = _G.PickupContainerItem
local PlaySound = _G.PlaySound
local REAGENTBANK_CONTAINER = _G.REAGENTBANK_CONTAINER
local ResetCursor = _G.ResetCursor
local StaticPopup_Show = _G.StaticPopup_Show
local wipe = _G.wipe
--GLOBALS>

if not REAGENTBANK_CONTAINER then
	return
end

local REAGENT_BANK_TITLE = _G.REAGENT_BANK or "Reagent Bank"
local REAGENT_BANK_HELP = _G.REAGENT_BANK_HELP
local REAGENT_BANK_POPUP = "CONFIRM_BUY_REAGENTBANK_TAB"
local PURCHASE_ICON = [[Interface\MoneyFrame\UI-GoldIcon]]

local slotClass, slotProto = addon:NewClass("ReagentBankSlot", "ItemButton")

local function IsUnlocked()
	return _G.IsReagentBankUnlocked and _G.IsReagentBankUnlocked() and true or false
end

local freeSlots = {}
local function GetFreeSlots()
	wipe(freeSlots)
	GetContainerFreeSlots(REAGENTBANK_CONTAINER, freeSlots)
	return freeSlots
end

local function GetFirstFreeSlot()
	return GetFreeSlots()[1]
end

local function GetSpace()
	return #GetFreeSlots(), GetContainerNumSlots(REAGENTBANK_CONTAINER) or 0
end

local function Slot_OnClick(self, button)
	if not IsUnlocked() then
		if _G.StaticPopupDialogs and _G.StaticPopupDialogs[REAGENT_BANK_POPUP] then
			StaticPopup_Show(REAGENT_BANK_POPUP)
		end
		return
	end
	if CursorHasItem() then
		local slot = GetFirstFreeSlot()
		if slot then
			PickupContainerItem(REAGENTBANK_CONTAINER, slot)
		end
		return
	end
	if button ~= "RightButton" and _G.DepositReagentBank then
		PlaySound("igMainMenuOptionCheckBoxOn")
		_G.DepositReagentBank()
	end
end

local function Slot_OnReceiveDrag(self)
	return Slot_OnClick(self, "LeftButton")
end

local function Slot_OnEnter(self)
	local right = self:GetRight()
	GameTooltip:SetOwner(self, right and right >= GetScreenWidth() / 2 and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
	if IsUnlocked() then
		local free, total = GetSpace()
		GameTooltip:AddDoubleLine(REAGENT_BANK_TITLE, format("%d/%d", free, total), 1, 0.82, 0, 1, 1, 1)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["Left click: deposit all reagents"], 0.8, 0.8, 0.8)
	else
		GameTooltip:AddLine(REAGENT_BANK_TITLE, 1, 0.82, 0)
		if REAGENT_BANK_HELP then
			GameTooltip:AddLine(REAGENT_BANK_HELP, 1, 1, 1, true)
		end
		if _G.GetReagentBankCost then
			GameTooltip:AddDoubleLine(
				_G.COSTS_LABEL or "",
				GetCoinTextureString(_G.GetReagentBankCost()),
				1,
				1,
				1,
				1,
				1,
				1
			)
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["Left click: buy the reagent bank"], 0.8, 0.8, 0.8)
	end
	GameTooltip:Show()
	ResetCursor()
end

local function Slot_OnLeave(self)
	if GameTooltip:GetOwner() == self then
		GameTooltip:Hide()
	end
	ResetCursor()
end

function slotProto:OnCreate()
	addon:GetClass("ItemButton").prototype.OnCreate(self)
	self.bag = REAGENTBANK_CONTAINER
	self.slot = 0
	self:SetScript("PreClick", nil)
	self:SetScript("OnClick", Slot_OnClick)
	self:SetScript("OnReceiveDrag", Slot_OnReceiveDrag)
	self:SetScript("OnEnter", Slot_OnEnter)
	self:SetScript("OnLeave", Slot_OnLeave)
	self:SetScript("OnDragStart", nil)
	self:RegisterForDrag()
	self.UpdateTooltip = Slot_OnEnter
end

function slotProto:UpdateClickRegistration()
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
end

function slotProto:Invalidate()
	self.cacheValid = nil
end

function slotProto:FullUpdate()
	local unlocked = IsUnlocked()
	local free = unlocked and GetSpace() or 0
	if self.cacheValid and self.cachedUnlocked == unlocked and self.cachedFree == free then
		return
	end
	self.cacheValid, self.cachedUnlocked, self.cachedFree = true, unlocked, free
	self.itemId = nil
	self.itemLink = nil
	self.hasItem = false
	self.itemQuality = nil
	self.isQuestItem = nil
	self.questId = nil
	self.texture = (not unlocked) and PURCHASE_ICON or nil
	self.bagFamily = 0
	self.slotCount = free
	self:Update()
	self.slotCount = nil
end

function slotProto:GetCount()
	local count = self.slotCount
	if count ~= nil then
		self.slotCount = nil
		return count
	end
	return (IsUnlocked() and GetSpace()) or 0
end

function slotProto:UpdateCount()
	local count = self:GetCount() or 0
	self.count = count
	if IsUnlocked() and self.Count then
		self.Count:SetText(count)
		self.Count:Show()
	elseif self.Count then
		self.Count:Hide()
	end
end

function slotProto:IsLocked()
	return false
end

function slotProto:GetBagFamily()
	return 0x1000000
end

local function NoSlots() end
function slotProto:IterateSlots()
	return NoSlots
end

local instances = {}

function addon:CreateReagentBankSlot(container)
	local button = slotClass:Create()
	button:SetParent(addon.itemParentFrames[REAGENTBANK_CONTAINER] or container)
	button.container = container
	instances[button] = true
	return button
end

_G.hooksecurefunc(addon, "UpdateCountAppearance", function()
	for button in pairs(instances) do
		button:UpdateCountAppearance()
	end
end)
