local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
--GLOBALS>

local mod = addon:NewModule("MoneyFrame", "AceEvent-3.0")
mod.uiName = L["Money"]
mod.uiDesc = L["Display character money at bottom right of the backpack."]

function mod:OnEnable()
	addon:HookBagFrameCreation(self, "OnBagFrameCreated")
	if self.widget then
		self.widget:Show()
	end
end

function mod:OnDisable()
	if self.widget then
		self.widget:Hide()
	end
end

function mod:OnBagFrameCreated(bag)
	if bag.bagName ~= "Backpack" then
		return
	end
	local frame = bag:GetFrame()
	self.widget = CreateFrame("Frame", addonName .. "MoneyFrame", frame, "MoneyFrameTemplate")
	self.widget:SetHeight(19)
	self.widget:EnableMouse(true)
	frame:AddBottomWidget(self.widget, "RIGHT", 50, nil, 13, 0)

	local overlay = CreateFrame("Frame", nil, self.widget)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(self.widget:GetFrameLevel() + 10)
	overlay:EnableMouse(true)
	overlay:SetScript("OnEnter", function(ov)
		local crossChar = addon:GetModule("CrossCharacter", true)
		if crossChar and crossChar:IsEnabled() then
			GameTooltip:SetOwner(ov, "ANCHOR_TOPLEFT")
			GameTooltip:ClearLines()
			GameTooltip:AddLine(L["Money"], 1, 1, 1)
			crossChar:AddMoneyTooltip(GameTooltip)
			GameTooltip:Show()
		end
	end)
	overlay:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	frame:EnableBackgroundDrag(overlay)
end
