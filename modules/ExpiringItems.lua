local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local ceil = _G.math.ceil
local floor = _G.math.floor
local format = _G.format
local GetTime = _G.GetTime
local max = _G.max
local min = _G.min
local NumberFontNormalSmall = _G.NumberFontNormalSmall
local pairs = _G.pairs
local wipe = _G.wipe
--GLOBALS>

local mod = addon:RegisterFilter("ExpiringItems", 99, "AceEvent-3.0", "AceTimer-3.0")
mod.uiName = L["Expiring Items"]
mod.uiDesc = L["Put items that have an expiration time or lifetime in a specific section."]

local TEMP_CATEGORY = L["Temporary items"]

local SECONDS_IN_DAY = 86400
local SECONDS_IN_HOUR = 3600
local SECONDS_IN_MINUTE = 60
local WARNING_TIME = 1800

local texts = {}
local watched = {}
local timer, timerInterval

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			enabled = true,
			showCountdown = true,
		},
	})
end

local function GetSlotTimeLeft(bag, slot)
	if not (bag and slot and _G.GetContainerItemGUID and _G.GetItemExpirationTimeLeft) then
		return nil
	end
	local itemGUID = _G.GetContainerItemGUID(bag, slot)
	if not itemGUID then
		return nil
	end
	local hasExpiration, expirationTimeLeft = _G.GetItemExpirationTimeLeft(itemGUID)
	if hasExpiration and expirationTimeLeft and expirationTimeLeft > 0 then
		return expirationTimeLeft
	end
end

function mod:Filter(slotData)
	if not self.db.profile.enabled or slotData.preview then
		return nil
	end

	if GetSlotTimeLeft(slotData.bag, slotData.slot) then
		return TEMP_CATEGORY
	end

	return nil
end

local function FormatTimeLeft(remaining)
	if remaining >= SECONDS_IN_DAY then
		return format("%dд", ceil(remaining / SECONDS_IN_DAY))
	elseif remaining >= SECONDS_IN_HOUR then
		return format("%dч", floor(remaining / SECONDS_IN_HOUR))
	elseif remaining >= SECONDS_IN_MINUTE then
		return format("%dм", floor(remaining / SECONDS_IN_MINUTE))
	end
	return format("%dс", ceil(remaining))
end

local function CreateText(button)
	local text = button:CreateFontString(nil, "OVERLAY")
	local fontName = NumberFontNormalSmall:GetFont()
	text:SetFont(fontName, 11, "OUTLINE")
	text:SetJustifyH("CENTER")
	text:SetShadowColor(0, 0, 0, 1)
	text:SetShadowOffset(1, -1)
	text:SetPoint("CENTER", button, "CENTER", 0, 0)
	texts[button] = text
	return text
end

local function Draw(button, remaining)
	local text = texts[button] or CreateText(button)
	text:SetText(FormatTimeLeft(remaining))
	if remaining < WARNING_TIME then
		text:SetTextColor(1, 0.3, 0.4)
	else
		text:SetTextColor(1, 1, 1)
	end
	text:Show()
end

local function GetInterval(remaining)
	if remaining < SECONDS_IN_MINUTE then
		return 1
	elseif remaining < SECONDS_IN_HOUR then
		return max(0.5, min(10, remaining - SECONDS_IN_MINUTE))
	end
	return max(0.5, min(60, remaining - SECONDS_IN_HOUR))
end

local Tick

local function Schedule(interval)
	if timer then
		mod:CancelTimer(timer, true)
	end
	timerInterval = interval
	timer = mod:ScheduleTimer(Tick, interval)
end

function Tick()
	timer, timerInterval = nil, nil
	local now = GetTime()
	local soonest
	for button, endTime in pairs(watched) do
		local remaining = endTime - now
		if remaining <= 0 then
			watched[button] = nil
			local text = texts[button]
			if text then
				text:Hide()
			end
		else
			if not soonest or remaining < soonest then
				soonest = remaining
			end
			if button:IsVisible() then
				Draw(button, remaining)
			end
		end
	end
	if soonest then
		Schedule(GetInterval(soonest))
	end
end

function mod:OnEnable()
	self:RegisterMessage("AdiBags_UpdateButton", "UpdateButton")
	self:RegisterEvent("ITEM_EXPIRATION_TIME_UPDATE")
	self:SendMessage("AdiBags_UpdateAllButtons")

	addon.filterProto.OnEnable(self)
end

function mod:OnDisable()
	self:CancelAllTimers()
	timer, timerInterval = nil, nil
	wipe(watched)
	for _, text in pairs(texts) do
		text:Hide()
	end

	addon.filterProto.OnDisable(self)
end

function mod:ITEM_EXPIRATION_TIME_UPDATE()
	if not self.resyncTimer then
		self.resyncTimer = self:ScheduleTimer("Resync", 0.5)
	end
end

function mod:Resync()
	self.resyncTimer = nil
	self:SendMessage("AdiBags_UpdateAllButtons")
end

function mod:UpdateButton(event, button)
	if button.preview then
		return
	end
	local remaining = self.db.profile.showCountdown and GetSlotTimeLeft(button.bag, button.slot)
	if not remaining then
		watched[button] = nil
		local text = texts[button]
		if text then
			text:Hide()
		end
		return
	end

	watched[button] = GetTime() + remaining
	Draw(button, remaining)

	local interval = GetInterval(remaining)
	if not timer or (timerInterval and timerInterval > interval) then
		Schedule(interval)
	end
end

function mod:GetOptions()
	return {
		showCountdown = {
			name = L["Show remaining time"],
			desc = L["Display the remaining lifetime on the item icon and keep it ticking."],
			type = "toggle",
			width = "double",
			order = 10,
		},
	},
		addon:GetOptionHandler(self, true)
end
