local addonName, addon = ...
local L = addon.L

local _G = _G
local GetContainerItemGUID = _G.GetContainerItemGUID
local GetItemInfo = _G.GetItemInfo
local C_Item = _G.C_Item
local IsBoundByGUID = C_Item and C_Item.IsBoundByGUID
local pairs = _G.pairs
local select = _G.select

local mod = addon:NewModule("BoEIndicator", "AceEvent-3.0")
mod.uiName = L["BoE indicator"]
mod.uiDesc = L["Displays a 'BoE' tag on equipment that is not bound to your character yet."]

local texts = {}

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			color = { r = 1, g = 0.82, b = 0, a = 1 },
		},
	})
end

function mod:OnEnable()
	self:RegisterMessage("AdiBags_UpdateButton", "UpdateButton")
	self:SendMessage("AdiBags_UpdateAllButtons")
end

function mod:OnDisable()
	for _, text in pairs(texts) do
		text:Hide()
	end
end

local function CreateText(button)
	local fs = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	fs:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
	fs:SetText(L["BoE"])
	fs:SetJustifyH("LEFT")
	fs:Hide()
	texts[button] = fs
	return fs
end

local function IsEquippableUnbound(bag, slot, itemId)
	if not IsBoundByGUID or not bag or not slot or not itemId then
		return false
	end
	local equipLoc = select(9, GetItemInfo(itemId))
	if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_BAG" then
		return false
	end
	local guid = GetContainerItemGUID(bag, slot)
	if not guid then
		return false
	end
	return not IsBoundByGUID(guid)
end

function mod:UpdateButton(event, button)
	local text = texts[button]
	local itemId = button:GetItemId()

	if itemId and IsEquippableUnbound(button.bag, button.slot, itemId) then
		if not text then
			text = CreateText(button)
		end
		local c = self.db.profile.color
		text:SetTextColor(c.r, c.g, c.b, c.a)
		text:Show()
	elseif text then
		text:Hide()
	end
end

function mod:GetOptions()
	return {
		color = {
			name = L["Tag color"],
			desc = L["Color of the 'BoE' text."],
			type = "color",
			hasAlpha = true,
			order = 10,
			get = function()
				local c = mod.db.profile.color
				return c.r, c.g, c.b, c.a
			end,
			set = function(_, r, g, b, a)
				local c = mod.db.profile.color
				c.r, c.g, c.b, c.a = r, g, b, a
				mod:SendMessage("AdiBags_UpdateAllButtons")
			end,
		},
	},
		addon:GetOptionHandler(self)
end
