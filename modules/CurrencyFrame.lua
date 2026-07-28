local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local CreateFrame = _G.CreateFrame
local ExpandCurrencyList = _G.ExpandCurrencyList
local format = _G.format
local GetCurrencyListInfo = _G.GetCurrencyListInfo
local GetCurrencyListSize = _G.GetCurrencyListSize
local hooksecurefunc = _G.hooksecurefunc
local ipairs = _G.ipairs
local IsAddOnLoaded = _G.IsAddOnLoaded
local tinsert = _G.tinsert
local wipe = _G.wipe
local GameTooltip = _G.GameTooltip
--GLOBALS>

local mod = addon:NewModule("CurrencyFrame", "AceEvent-3.0")
mod.uiName = L["Currency"]
mod.uiDesc = L["Display character currency at bottom left of the backpack."]

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			shown = { ["*"] = false },
		},
	})
end

function mod:OnEnable()
	addon:HookBagFrameCreation(self, "OnBagFrameCreated")
	if self.widget then
		self.widget:Show()
	end
	self:RegisterEvent("KNOWN_CURRENCY_TYPES_UPDATE", "Update")
	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "Update")
	self:RegisterEvent("HONOR_CURRENCY_UPDATE", "Update")
	if not self.hooked then
		if _G.TokenFrame_Update then
			hooksecurefunc("TokenFrame_Update", function()
				self:Update()
			end)
			self.hooked = true
		elseif IsAddOnLoaded("Blizzard_TokenUI") then
			self:ADDON_LOADED("OnEnable", "Blizzard_TokenUI")
		else
			self:RegisterEvent("ADDON_LOADED")
		end
	end
	self:Update()
end

function mod:ADDON_LOADED(_, name)
	if name ~= "Blizzard_TokenUI" then
		return
	end
	self:UnregisterEvent("ADDON_LOADED")
	if not self.hooked and _G.TokenFrame_Update then
		hooksecurefunc("TokenFrame_Update", function()
			self:Update()
		end)
		self.hooked = true
	end
end

function mod:OnDisable()
	if self.widget then
		self.widget:Hide()
	end
end

local ICON_STRING = "%s\124T%s:0:0:0:0:64:64:5:59:5:59\124t"
local CURRENCY_STRING = "\124T%s:14:14:0:0:64:64:5:59:5:59\124t %s"

local currencyButtons = {}

local function CurrencyButton_OnEnter(self)
	if not self.currencyData then
		return
	end
	local data = self.currencyData
	GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
	GameTooltip:ClearLines()
	GameTooltip:AddDoubleLine(data.left, data.right, 1, 1, 1, 1, 1, 1)
	local crossChar = addon:GetModule("CrossCharacter", true)
	if crossChar and crossChar:IsEnabled() and data.itemID then
		crossChar:AddCurrencyTooltip(GameTooltip, data.itemID)
	end
	GameTooltip:Show()
end

local function CurrencyButton_OnLeave(self)
	GameTooltip:Hide()
end

local function GetOrCreateCurrencyButton(parent, index)
	if currencyButtons[index] then
		return currencyButtons[index]
	end
	local btn = CreateFrame("Frame", addonName .. "CurrencyBtn" .. index, parent)
	btn:EnableMouse(true)
	btn:SetHeight(13)
	btn.fs = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
	btn.fs:SetPoint("LEFT", 0, 1)
	btn:SetScript("OnEnter", CurrencyButton_OnEnter)
	btn:SetScript("OnLeave", CurrencyButton_OnLeave)
	parent:GetParent():EnableBackgroundDrag(btn)
	currencyButtons[index] = btn
	return btn
end

function mod:OnBagFrameCreated(bag)
	if bag.bagName ~= "Backpack" then
		return
	end
	local frame = bag:GetFrame()
	self.widget = CreateFrame("Frame", addonName .. "CurrencyFrame", frame)
	self.widget:EnableMouse(false)
	self.widget:SetHeight(13)
	--AddBottomWidget(widget, side, order, height, xOffset, yOffset)
	frame:AddBottomWidget(self.widget, "LEFT", 50, 13)

	self:Update()
end

local collapse = {}
-- 3.3.5a ExpandCurrencyList rejects booleans, it wants 1/0.
local function RestoreCollapsed()
	for i, index in ipairs(collapse) do
		ExpandCurrencyList(index, 0)
	end
	wipe(collapse)
end

local IterateCurrencies
do
	local function iterator(collapse, index)
		if not index then
			return
		end
		repeat
			index = index + 1
			local name, isHeader, isExpanded, isUnused, isWatched, count, extraCurrencyType, icon, itemID =
				GetCurrencyListInfo(index)
			if name then
				if isHeader then
					if not isExpanded then
						tinsert(collapse, 1, index)
						ExpandCurrencyList(index, 1)
					end
				else
					return index,
						name,
						isHeader,
						isExpanded,
						isUnused,
						isWatched,
						count,
						extraCurrencyType,
						icon,
						itemID
				end
			end
		until index > GetCurrencyListSize()
		RestoreCollapsed()
	end

	function IterateCurrencies()
		wipe(collapse)
		return iterator, collapse, 0
	end
end

local updating
local function DoUpdate(self)
	local btnIndex = 0
	local totalWidth = 0

	for i, name, _, _, _, _, count, extraCurrencyType, icon, itemID in IterateCurrencies() do
		if self.db.profile.shown[name] then
			btnIndex = btnIndex + 1
			local btn = GetOrCreateCurrencyButton(self.widget, btnIndex)

			local text = format(ICON_STRING, count, icon)
			btn.fs:SetText(text)

			local strWidth = btn.fs:GetStringWidth()
			local btnWidth = math.max(strWidth, 10) + 8
			btn:SetWidth(btnWidth)
			btn:ClearAndSetPoint("LEFT", self.widget, "LEFT", totalWidth, 0)
			btn:Show()

			local limitText = count
			if itemID and _G.C_CurrencyInfo and _G.C_CurrencyInfo.GetCurrencyInfo then
				local _, _, _, earnedThisWeek, weeklyMax, maxQuantity = _G.C_CurrencyInfo.GetCurrencyInfo(itemID)
				if weeklyMax and weeklyMax > 0 then
					limitText = format(
						"%s / %s (Неделя: %s / %s)",
						count,
						maxQuantity > 0 and maxQuantity or "?",
						earnedThisWeek,
						weeklyMax
					)
				elseif maxQuantity and maxQuantity > 0 then
					limitText = format("%s / %s", count, maxQuantity)
				end
			end
			btn.currencyData = {
				left = format(CURRENCY_STRING, icon, name),
				right = limitText,
				name = name,
				itemID = itemID,
			}

			totalWidth = totalWidth + btnWidth
		end
	end

	for j = btnIndex + 1, #currencyButtons do
		currencyButtons[j]:Hide()
		currencyButtons[j].currencyData = nil
	end

	self.widget:SetWidth(math.max(totalWidth, 0.1))
	self.widget:Show()
end

function mod:Update()
	if not self.widget or updating then
		return
	end
	updating = true
	local ok, err = pcall(DoUpdate, self)
	local restored, restoreErr = pcall(RestoreCollapsed)
	updating = false
	if not ok then
		addon:Debug("CurrencyFrame update failed", err)
	end
	if not restored then
		addon:Debug("CurrencyFrame collapse restore failed", restoreErr)
	end
end

function mod:GetOptions()
	local values = {}
	local function GetValueList()
		wipe(values)
		for i, name in IterateCurrencies() do
			values[name] = name
		end
		return values
	end

	return {
		shown = {
			name = L["Currencies to show"],
			type = "multiselect",
			order = 10,
			values = GetValueList,
			set = function(info, ...)
				info.handler:Set(info, ...)
				mod:Update()
			end,
		},
	},
		addon:GetOptionHandler(self)
end
