local addonName, addon = ...
local L = addon.L

local _G = _G
local GetItemGem = _G.GetItemGem
local GetItemInfo = _G.GetItemInfo
local GetItemQualityColor = _G.GetItemQualityColor
local pairs = _G.pairs

local mod = addon:NewModule("BlackDiamondHighlight", "AceEvent-3.0")
mod.uiName = L["Black Diamond items"]
mod.uiDesc = L["Highlight items with Black Diamonds in your bags"]

local glows = {}

local GLOW_TEXTURE = [[Interface\AddOns\AdiBags\assets\BagNewItemGlow]]

local defaultR, defaultG, defaultB = GetItemQualityColor(5)

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			glowColor = { r = defaultR, g = defaultG, b = defaultB, a = 0.8 },
		},
	})
end

function mod:OnEnable()
	self:RegisterMessage("AdiBags_UpdateButton", "UpdateButton")
	self:SendMessage("AdiBags_UpdateAllButtons")
end

function mod:OnDisable()
	for _, glow in pairs(glows) do
		glow:Hide()
	end
end

local function CreateGlow(button)
	local t = button:CreateTexture(nil, "OVERLAY")
	t:SetTexture(GLOW_TEXTURE)
	t:SetAllPoints(button.IconTexture)
	t:SetBlendMode("ADD")
	t:Hide()
	glows[button] = t
	return t
end

function mod:UpdateButton(event, button)
	local link = button:GetItemLink()
	local glow = glows[button]

	if link then
		for i = 1, 3 do
			local _, gemLink = GetItemGem(link, i)
			if gemLink then
				local _, _, gemQuality = GetItemInfo(gemLink)
				if gemQuality == 5 then
					if not glow then
						glow = CreateGlow(button)
					end
					local c = self.db.profile.glowColor
					glow:SetVertexColor(c.r, c.g, c.b, c.a)
					glow:Show()
					return
				end
			end
		end
	end

	if glow then
		glow:Hide()
	end
end

function mod:GetOptions()
	return {
		glowColor = {
			name = L["Glow color"],
			desc = L["Color of the highlight for items with Black Diamonds"],
			type = "color",
			hasAlpha = true,
			order = 10,
			get = function()
				local c = mod.db.profile.glowColor
				return c.r, c.g, c.b, c.a
			end,
			set = function(_, r, g, b, a)
				local c = mod.db.profile.glowColor
				c.r, c.g, c.b, c.a = r, g, b, a
				mod:SendMessage("AdiBags_UpdateAllButtons")
			end,
		},
	},
		addon:GetOptionHandler(self)
end
