local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local ceil = _G.ceil
local CreateFrame = _G.CreateFrame
local GetContainerItemGUID = _G.GetContainerItemGUID
local GetLocale = _G.GetLocale
local GetTime = _G.GetTime
local gsub = _G.gsub
local pairs = _G.pairs
local tonumber = _G.tonumber
local wipe = _G.wipe
--GLOBALS>

local mod = addon:RegisterFilter("Tradeable", 100, "AceEvent-3.0", "AceTimer-3.0")
mod.uiName = L["Tradeable items"]
mod.uiDesc =
	L["Group bind-on-pickup items that can still be traded to other eligible raid members, and optionally show the time left."]

local TRADEABLE = L["Tradeable"]
local MIN_SUFFIX = (GetLocale() == "ruRU") and "\208\188" or "m" -- "м"
local REFRESH_INTERVAL = 30
local TRADEABLE_ORDER = 60

local TRADE_PATTERN = _G.BIND_TRADE_TIME_REMAINING and gsub(_G.BIND_TRADE_TIME_REMAINING, "%%s", "(.+)")

local scanTip = CreateFrame("GameTooltip", "AdiBagsTradeableScanTooltip", nil, "GameTooltipTemplate")
scanTip:SetOwner(_G.UIParent, "ANCHOR_NONE")

local cache = {}

local function ParseTradeSeconds(cap)
	local seconds = 0
	for n, unit in cap:gmatch("(%d+)%s*([^%d%s]+)") do
		n = tonumber(n) or 0
		unit = unit:lower()
		if unit:find("^\208\180") or unit:find("^d") then -- д / day
			seconds = seconds + n * 86400
		elseif unit:find("^\209\135") or unit:find("^h") then -- ч / hour
			seconds = seconds + n * 3600
		elseif unit:find("\208\188\208\184\208\189") or unit:find("^m") then -- мин / min
			seconds = seconds + n * 60
		else -- с / сек / s
			seconds = seconds + n
		end
	end
	return seconds
end

local function ScanTradeSeconds(bag, slot)
	if not TRADE_PATTERN then
		return nil
	end
	scanTip:ClearLines()
	scanTip:SetBagItem(bag, slot)
	for i = 1, scanTip:NumLines() do
		local line = _G["AdiBagsTradeableScanTooltipTextLeft" .. i]
		local text = line and line:GetText()
		if text then
			local cap = text:match(TRADE_PATTERN)
			if cap then
				return ParseTradeSeconds(cap)
			end
		end
	end
	return nil
end

local function GetTradeRemaining(bag, slot, allowScan)
	if not (bag and slot and GetContainerItemGUID) then
		return nil
	end
	local guid = GetContainerItemGUID(bag, slot)
	if not guid then
		return nil
	end
	local now = GetTime()
	local exp = cache[guid]
	if exp == nil then
		if not allowScan then
			return nil
		end
		local secs = ScanTradeSeconds(bag, slot)
		exp = (secs and secs > 0) and (now + secs) or false
		cache[guid] = exp
	end
	if not exp then
		return nil
	end
	local remaining = exp - now
	if remaining <= 0 then
		cache[guid] = false
		return nil
	end
	return remaining
end

local function HasTracked()
	for _, exp in pairs(cache) do
		if exp then
			return true
		end
	end
	return false
end

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			enabled = true,
			showTimer = true,
		},
	})
end

function mod:OnEnable()
	addon:SetCategoryOrder(TRADEABLE, TRADEABLE_ORDER)
	wipe(cache)
	self:RegisterMessage("AdiBags_UpdateButton", "UpdateButton")
	self.refreshTimer = self:ScheduleRepeatingTimer("Refresh", REFRESH_INTERVAL)
	self:SendMessage("AdiBags_UpdateAllButtons")
end

function mod:OnDisable()
	if self.refreshTimer then
		self:CancelTimer(self.refreshTimer)
		self.refreshTimer = nil
	end
	for _, text in pairs(self.texts or {}) do
		text:Hide()
	end
end

function mod:Refresh()
	if not self.db.profile.enabled or not HasTracked() then
		return
	end
	local now = GetTime()
	local expired = false
	for guid, exp in pairs(cache) do
		if exp and exp <= now then
			cache[guid] = false
			expired = true
		end
	end
	if expired then
		self:SendMessage("AdiBags_FiltersChanged")
	end
	self:SendMessage("AdiBags_UpdateAllButtons")
end

function mod:Filter(slotData)
	if not self.db.profile.enabled then
		return nil
	end
	if GetTradeRemaining(slotData.bag, slotData.slot, true) then
		return TRADEABLE
	end
	return nil
end

function mod:UpdateButton(event, button)
	local texts = self.texts
	if not texts then
		texts = {}
		self.texts = texts
	end
	local text = texts[button]

	local remaining = self.db.profile.showTimer and GetTradeRemaining(button.bag, button.slot, false)
	if remaining then
		if not text then
			text = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
			text:SetPoint("TOP", button, "TOP", 0, -2)
			texts[button] = text
		end
		text:SetText(ceil(remaining / 60) .. MIN_SUFFIX)
		text:SetTextColor(0, 0.8, 1)
		text:Show()
	elseif text then
		text:Hide()
	end
end

function mod:GetOptions()
	local handler = addon:GetOptionHandler(self)

	local Set = handler.Set
	function handler.Set(info, ...)
		Set(info, ...)
		wipe(cache)
		mod:SendMessage("AdiBags_FiltersChanged")
		mod:SendMessage("AdiBags_UpdateAllButtons")
	end

	return {
		showTimer = {
			name = L["Show remaining trade time"],
			desc = L["Show how many minutes are left to trade each item, on the item itself."],
			type = "toggle",
			order = 10,
		},
	},
		handler
end
