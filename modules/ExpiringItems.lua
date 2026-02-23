local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local setmetatable = _G.setmetatable
local string = _G.string
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
--GLOBALS>

local mod = addon:RegisterFilter("ExpiringItems", 99, "AceEvent-3.0")
mod.uiName = L["Expiring Items"]
mod.uiDesc = L["Put items that have an expiration time or lifetime in a specific section."]

local TEMP_CATEGORY = L["Temporary items"]

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			enabled = true,
		}
	})
end

local tooltip = CreateFrame("GameTooltip", "AdiBagsExpiringItemsTooltip", UIParent, "GameTooltipTemplate")
tooltip:SetOwner(UIParent, "ANCHOR_NONE")

local cache = setmetatable({}, { __index = function(t, itemId)
	local isExpiring = mod:CheckItem(itemId)
	t[itemId] = isExpiring
	return isExpiring
end})

function mod:OnEnable()
	addon:UpdateFilters()
end

function mod:OnDisable()
	addon:UpdateFilters()
end

function mod:CheckItem(itemId)
	if not itemId then return false end

	tooltip:ClearLines()
	tooltip:SetHyperlink("item:" .. itemId)

	for i = 1, tooltip:NumLines() do
		local leftLine = _G["AdiBagsExpiringItemsTooltipTextLeft" .. i]
		if leftLine then
			local text = leftLine:GetText()
			if text then
				if string.find(text, "Исчезнет через") or string.find(text, "срок жизни") then
					return true
				end
			end
		end
		
		local rightLine = _G["AdiBagsExpiringItemsTooltipTextRight" .. i]
		if rightLine then
			local text = rightLine:GetText()
			if text then
				if string.find(text, "Исчезнет через") or string.find(text, "срок жизни") then
					return true
				end
			end
		end
	end

	return false
end

function mod:Filter(slotData)
	if not self.db.profile.enabled then return nil end

	if cache[slotData.itemId] then
		return TEMP_CATEGORY
	end

	return nil
end

function mod:GetOptions()
	return {
		enabled = {
			name = L["Enable Expiring Items Category"],
			desc = L["Check this to automatically group items that have an expiration time or lifetime."],
			type = "toggle",
			order = 10,
		},
	}, addon:GetOptionHandler(self)
end
