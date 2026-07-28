local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local C_ItemUpgrade = _G.C_ItemUpgrade
local ItemLocation = _G.ItemLocation
local pairs = _G.pairs
local pcall = _G.pcall
--GLOBALS>

local ARROW_TEXTURE = [[Interface\AddOns\AdiBags\assets\UpgradeArrow]]

local mod = addon:NewModule("UpgradeIndicator", "AceEvent-3.0")
mod.uiName = L["Upgradeable items"]
mod.uiDesc = L["Display an arrow on items that can still be upgraded."]

local arrows = {}
local upgradeable = {}

local function CanUpgrade(bag, slot, itemId)
	local state = upgradeable[itemId]
	if state ~= nil then
		return state
	end
	if not (C_ItemUpgrade and C_ItemUpgrade.CanUpgradeItem and ItemLocation and bag and slot) then
		return false
	end
	local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
	local ok, canUpgrade = pcall(C_ItemUpgrade.CanUpgradeItem, location)
	if not ok then
		return false
	end
	state = not not canUpgrade
	upgradeable[itemId] = state
	return state
end

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			anchor = "BOTTOM",
			offsetX = 0,
			offsetY = 1,
			size = 14,
		},
	})
end

local function UpdateArrowLayout()
	local settings = mod.db.profile
	for _, arrow in pairs(arrows) do
		arrow:SetSize(settings.size, settings.size)
		arrow:ClearAndSetPoint(settings.anchor, arrow:GetParent(), settings.offsetX, settings.offsetY)
	end
end

local function CreateArrow(button)
	local settings = mod.db.profile
	local arrow = button:CreateTexture(nil, "OVERLAY")
	arrow:SetTexture(ARROW_TEXTURE)
	arrow:SetSize(settings.size, settings.size)
	arrow:SetPoint(settings.anchor, button, settings.offsetX, settings.offsetY)
	arrows[button] = arrow
	return arrow
end

function mod:OnEnable()
	self:RegisterMessage("AdiBags_UpdateButton", "UpdateButton")
	self:SendMessage("AdiBags_UpdateAllButtons")
	UpdateArrowLayout()
end

function mod:OnDisable()
	for _, arrow in pairs(arrows) do
		arrow:Hide()
	end
end

function mod:UpdateButton(event, button)
	local itemId = button:GetItemId()
	local arrow = arrows[button]
	if itemId and CanUpgrade(button.bag, button.slot, itemId) then
		if not arrow then
			arrow = CreateArrow(button)
		end
		arrow:Show()
	elseif arrow then
		arrow:Hide()
	end
end

function mod:GetOptions()
	return {
		size = {
			name = L["Arrow size"],
			desc = L["Size of the arrow shown on upgradeable items."],
			type = "range",
			min = 8,
			max = 24,
			step = 1,
			order = 10,
			set = function(info, value)
				mod.db.profile[info[#info]] = value
				UpdateArrowLayout()
			end,
		},
		anchor = {
			name = L["Anchor"],
			type = "select",
			values = addon.ANCHOR_POINTS,
			order = 20,
			set = function(info, value)
				mod.db.profile[info[#info]] = value
				UpdateArrowLayout()
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
				UpdateArrowLayout()
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
				UpdateArrowLayout()
			end,
		},
	},
		addon:GetOptionHandler(self)
end
