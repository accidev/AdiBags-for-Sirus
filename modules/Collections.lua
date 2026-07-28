local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local C_Heirloom = _G.C_Heirloom
local C_MountJournal = _G.C_MountJournal
local C_PetJournal = _G.C_PetJournal
local C_Timer = _G.C_Timer
local C_ToyBox = _G.C_ToyBox
local CreateFrame = _G.CreateFrame
local pairs = _G.pairs
local PlayerHasToy = _G.PlayerHasToy
local select = _G.select
local wipe = _G.wipe
--GLOBALS>

local MOUNT, PET, TOY, HEIRLOOM = "mount", "pet", "toy", "heirloom"

local IsMountItem = C_MountJournal and C_MountJournal.IsMountItem
local GetMountFromItem = C_MountJournal and C_MountJournal.GetMountFromItem
local IsPetItem = C_PetJournal and C_PetJournal.IsPetItem
local GetPetInfoByItemID = C_PetJournal and C_PetJournal.GetPetInfoByItemID
local IsItemHeirloom = C_Heirloom and C_Heirloom.IsItemHeirloom
local PlayerHasHeirloom = C_Heirloom and C_Heirloom.PlayerHasHeirloom
local GetToyInfo = C_ToyBox and C_ToyBox.GetToyInfo

local kinds = {}
local collectedStates = {}

local function GetKind(itemId)
	local kind = kinds[itemId]
	if kind == nil then
		if IsMountItem and IsMountItem(itemId) then
			kind = MOUNT
		elseif IsPetItem and IsPetItem(itemId) then
			kind = PET
		elseif IsItemHeirloom and IsItemHeirloom(itemId) then
			kind = HEIRLOOM
		elseif GetToyInfo and GetToyInfo(itemId) then
			kind = TOY
		else
			kind = false
		end
		kinds[itemId] = kind
	end
	return kind or nil
end

local function IsCollected(itemId)
	local state = collectedStates[itemId]
	if state == nil then
		local kind = GetKind(itemId)
		if kind == MOUNT then
			state = not not select(9, GetMountFromItem(itemId))
		elseif kind == PET then
			state = not not select(8, GetPetInfoByItemID(itemId))
		elseif kind == HEIRLOOM then
			state = not not PlayerHasHeirloom(itemId)
		elseif kind == TOY then
			state = not not PlayerHasToy(itemId)
		else
			state = false
		end
		collectedStates[itemId] = state
	end
	return state
end

addon.GetCollectionKind = GetKind
addon.IsCollectionCollected = IsCollected

--------------------------------------------------------------------------------
-- Badge on already collected items
--------------------------------------------------------------------------------

local mod = addon:NewModule("CollectionBadges", "AceEvent-3.0")
mod.uiName = L["Collection badges"]
mod.uiDesc = L["Mark mounts, companions, toys and heirlooms you have already collected."]

local BADGE_TEXTURE = [[Interface\RaidFrame\ReadyCheck-Ready]]

local badges = {}

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			anchor = "TOPRIGHT",
			offsetX = -2,
			offsetY = -2,
			size = 14,
		},
	})
end

local function UpdateBadgeLayout()
	local settings = mod.db.profile
	for _, badge in pairs(badges) do
		badge:SetSize(settings.size, settings.size)
		badge:ClearAndSetPoint(settings.anchor, badge:GetParent(), settings.offsetX, settings.offsetY)
	end
end

local function CreateBadge(button)
	local settings = mod.db.profile
	local badge = button:CreateTexture(nil, "OVERLAY")
	badge:SetTexture(BADGE_TEXTURE)
	badge:SetSize(settings.size, settings.size)
	badge:SetPoint(settings.anchor, button, settings.offsetX, settings.offsetY)
	badges[button] = badge
	return badge
end

function mod:OnEnable()
	self:RegisterMessage("AdiBags_UpdateButton", "UpdateButton")
	self:SendMessage("AdiBags_UpdateAllButtons")
	UpdateBadgeLayout()
end

function mod:OnDisable()
	for _, badge in pairs(badges) do
		badge:Hide()
	end
end

function mod:UpdateButton(event, button)
	local itemId = button:GetItemId()
	local badge = badges[button]
	if itemId and IsCollected(itemId) then
		if not badge then
			badge = CreateBadge(button)
		end
		badge:Show()
	elseif badge then
		badge:Hide()
	end
end

function mod:GetOptions()
	return {
		size = {
			name = L["Badge size"],
			desc = L["Size of the badge shown on already collected items."],
			type = "range",
			min = 8,
			max = 24,
			step = 1,
			order = 10,
			set = function(info, value)
				mod.db.profile[info[#info]] = value
				UpdateBadgeLayout()
			end,
		},
		anchor = {
			name = L["Anchor"],
			type = "select",
			values = addon.ANCHOR_POINTS,
			order = 20,
			set = function(info, value)
				mod.db.profile[info[#info]] = value
				UpdateBadgeLayout()
			end,
		},
		offsetX = {
			name = L["X Offset"],
			desc = L["Offset in X direction (horizontal) from the given anchor point."],
			type = "range",
			min = -20,
			max = 20,
			step = 1,
			bigStep = 1,
			order = 30,
			set = function(info, value)
				mod.db.profile[info[#info]] = value
				UpdateBadgeLayout()
			end,
		},
		offsetY = {
			name = L["Y Offset"],
			desc = L["Offset in Y direction (vertical) from the given anchor point."],
			type = "range",
			min = -20,
			max = 20,
			step = 1,
			bigStep = 1,
			order = 40,
			set = function(info, value)
				mod.db.profile[info[#info]] = value
				UpdateBadgeLayout()
			end,
		},
	},
		addon:GetOptionHandler(self)
end

--------------------------------------------------------------------------------
-- Collection state refresh
--------------------------------------------------------------------------------

local refreshScheduled

local function RefreshCollectionStates()
	wipe(collectedStates)
	if refreshScheduled then
		return
	end
	refreshScheduled = true
	C_Timer:After(0.3, function()
		refreshScheduled = nil
		addon:SendMessage("AdiBags_UpdateAllButtons")
	end)
end

local stateFrame = CreateFrame("Frame")
stateFrame:RegisterEvent("COMPANION_LEARNED")
stateFrame:RegisterEvent("COMPANION_UNLEARNED")
stateFrame:RegisterEvent("COMPANION_UPDATE")
stateFrame:RegisterCustomEvent("PET_JOURNAL_LIST_UPDATE")
stateFrame:RegisterCustomEvent("TOYS_UPDATED")
stateFrame:RegisterCustomEvent("HEIRLOOMS_UPDATED")
stateFrame:SetScript("OnEvent", RefreshCollectionStates)

--------------------------------------------------------------------------------
-- Collections filter
--------------------------------------------------------------------------------

local COLLECTIONS_CATEGORY = L["Collections"]

local filter = addon:RegisterFilter("Collections", 78, function(self, slotData)
	local itemId = slotData.itemId
	if itemId and GetKind(itemId) then
		return COLLECTIONS_CATEGORY
	end
end)
filter.uiName = L["Collections"]
filter.uiDesc = L["Put mounts, companions, toys and heirlooms in their own section."]
