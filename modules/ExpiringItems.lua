local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
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

function mod:Filter(slotData)
	if not self.db.profile.enabled then return nil end

	if slotData.bag and slotData.slot and _G.GetContainerItemGUID and _G.GetItemExpirationTimeLeft then
		local itemGUID = _G.GetContainerItemGUID(slotData.bag, slotData.slot)
		if itemGUID then
			local hasExpiration, expirationTimeLeft = _G.GetItemExpirationTimeLeft(itemGUID)
			if hasExpiration and expirationTimeLeft and expirationTimeLeft > 0 then
				return TEMP_CATEGORY
			end
		end
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
