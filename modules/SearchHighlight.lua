local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local CreateFrame = _G.CreateFrame
local GetItemInfo = _G.GetItemInfo
--GLOBALS>

local mod = addon:NewModule("SearchHighlight", "AceEvent-3.0")
mod.uiName = L["Item search"]
mod.uiDesc =
	L["Provides a text widget at top of the backpack where you can type (part of) an item name to locate it in your bags."]

local lowerNames = {}

function mod:OnEnable()
	addon:HookBagFrameCreation(self, "OnBagFrameCreated")
	self:RegisterMessage("AdiBags_PreviewFrameCreated", "OnPreviewFrameCreated")
	self:RegisterMessage("AdiBags_PreviewOpened", "OnPreviewOpened")
	if self.widget then
		self.widget.lastSearch = nil
		self.widget:Show()
		self:SendMessage("AdiBags_UpdateAllButtons")
	end
	self:RegisterMessage("AdiBags_UpdateButton", "UpdateButton")
	self:RegisterMessage("AdiBags_UpdateLock", "UpdateButton")
	self:RegisterMessage("AdiBags_UpdateBorder", "UpdateButton")
end

function mod:OnDisable()
	if self.previewWidget then
		self.previewWidget:Hide()
	end
	if self.widget then
		self.widget:Hide()
		self:SendMessage("AdiBags_UpdateAllButtons")
	end
end

local function SearchEditBox_OnTextChanged(editBox)
	local text = editBox:GetText()
	local search = text and text:lower():trim() or ""
	if search == "" then
		editBox.clearButton:Hide()
	else
		editBox.clearButton:Show()
	end
	if search == editBox.lastSearch then
		return
	end
	editBox.lastSearch = search
	mod:SendMessage("AdiBags_UpdateAllButtons")
end

local function SearchEditBox_OnEnterPressed(editBox)
	editBox:ClearFocus()
	return SearchEditBox_OnTextChanged(editBox)
end

local function SearchEditBox_OnEscapePressed(editBox)
	editBox:ClearFocus()
	editBox:SetText("")
	return SearchEditBox_OnTextChanged(editBox)
end

local function CreateSearchBox(frame, name)
	local searchEditBox = CreateFrame("EditBox", name, frame, "InputBoxTemplate")
	searchEditBox:SetSize(100, 18)
	searchEditBox:SetAutoFocus(false)
	searchEditBox:SetPoint("TOPLEFT")
	searchEditBox:SetPoint("TOPRIGHT")
	searchEditBox:SetTextInsets(14, 20, 0, 0)
	searchEditBox:SetScript("OnEnterPressed", SearchEditBox_OnEnterPressed)
	searchEditBox:SetScript("OnEscapePressed", SearchEditBox_OnEscapePressed)
	searchEditBox:SetScript("OnTextChanged", SearchEditBox_OnTextChanged)

	local searchIcon = searchEditBox:CreateTexture(nil, "OVERLAY")
	searchIcon:SetPoint("LEFT", 0, -2)
	searchIcon:SetSize(14, 14)
	searchIcon:SetTexture([[Interface\Common\UI-Searchbox-Icon]])
	searchIcon:SetVertexColor(0.6, 0.6, 0.6)

	local searchClearButton = CreateFrame("Button", nil, searchEditBox, "UIPanelButtonTemplate")
	searchClearButton:SetPoint("RIGHT")
	searchClearButton:SetSize(20, 20)
	searchClearButton:SetText("X")
	searchClearButton:Hide()
	searchClearButton:SetScript("OnClick", function()
		SearchEditBox_OnEscapePressed(searchEditBox)
	end)

	searchEditBox.clearButton = searchClearButton

	addon.SetupTooltip(searchEditBox, {
		L["Item search"],
		L["Enter a text to search in item names."],
	}, "ANCHOR_TOPLEFT", 0, 8)

	frame:AddHeaderWidget(searchEditBox, -10, 100, -1)
	return searchEditBox
end

function mod:OnBagFrameCreated(bag)
	if bag.bagName ~= "Backpack" or self.widget then
		return
	end
	self.widget = CreateSearchBox(bag:GetFrame(), addonName .. "SearchFrame")
end

function mod:OnPreviewFrameCreated(event, frame)
	if self.previewWidget then
		return
	end
	self.previewWidget = CreateSearchBox(frame, addonName .. "PreviewSearchFrame")
end

function mod:OnPreviewOpened()
	local widget = self.previewWidget
	if widget then
		widget:ClearFocus()
		widget:SetText("")
		SearchEditBox_OnTextChanged(widget)
	end
end

function mod:UpdateButton(event, button)
	local widget = button.preview and self.previewWidget or self.widget
	if not widget then
		return
	end
	local text = widget:GetText()
	if not text or text:trim() == "" then
		return
	end
	text = text:lower():trim()
	local itemId = button.itemId
	local name = itemId and lowerNames[itemId]
	if name == nil and itemId then
		name = GetItemInfo(itemId)
		if name then
			name = name:lower()
			lowerNames[itemId] = name
		end
	end
	if name and not name:find(text, 1, true) then
		button.IconTexture:SetVertexColor(0.2, 0.2, 0.2)
		button.IconQuestTexture:Hide()
		button.Count:Hide()
		button.Stock:Hide()
	end
end
