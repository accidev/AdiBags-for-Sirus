local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local C_TransmogCollection = _G.C_TransmogCollection
local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local GetItemInfo = _G.GetItemInfo
local next = _G.next
local pairs = _G.pairs
local tinsert = _G.tinsert
local tremove = _G.tremove
local TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN = _G.TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN
local wipe = _G.wipe
--GLOBALS>

local BADGE_TEXTURE = [[Interface\RaidFrame\ReadyCheck-Waiting]]
local SEED_DELAY = 0.02
local SEED_FALLBACK = 3
local REFRESH_DELAY = 0.3

local mod = addon:NewModule("Transmog", "AceEvent-3.0")
mod.uiName = L["Uncollected appearances"]
mod.uiDesc = L["Mark equipment whose appearance is not collected yet."]

local badges = {}
local categories = {}
local readyCategories = {}
local seedQueue = {}
local seedScheduled, refreshScheduled
local inFlight
local FlushSeedQueue

local function IsWardrobeOpen()
	local frame = _G.WardrobeCollectionFrame
	if frame and frame:IsVisible() then
		return true
	end
	frame = _G.WardrobeFrame
	return not not (frame and frame:IsVisible())
end

-- Клиентская SIRUS_COLLECTION_RECEIVED_APPEARANCES[category] может быть заполнена
-- частично (гардероб грузит по одной подкатегории), поэтому готовность считаем сами.
local function IsCategoryReady(category)
	return not not readyCategories[category]
end

-- Ответ сервера не несёт своей категории, поэтому досеваем строго по одной:
-- иначе ответ на первую пометил бы готовыми и те, что ещё не отвечены.
local function FinishCategory(category)
	if not category or inFlight ~= category then
		return
	end
	inFlight = nil
	readyCategories[category] = true
	if next(seedQueue) and not seedScheduled then
		seedScheduled = true
		C_Timer:After(SEED_DELAY, FlushSeedQueue)
	end
end

local function ScheduleRefresh()
	if refreshScheduled then
		return
	end
	refreshScheduled = true
	C_Timer:After(REFRESH_DELAY, function()
		refreshScheduled = nil
		FinishCategory(inFlight)
		addon:SendMessage("AdiBags_UpdateAllButtons")
	end)
end

function FlushSeedQueue()
	seedScheduled = nil
	if IsWardrobeOpen() then
		wipe(seedQueue)
		return
	end
	if inFlight then
		return
	end
	local category = tremove(seedQueue)
	if not category then
		return
	end
	inFlight = category
	C_TransmogCollection.SetSearchAndFilterCategory(category)
	C_Timer:After(SEED_FALLBACK, function()
		if inFlight == category then
			FinishCategory(category)
			addon:SendMessage("AdiBags_UpdateAllButtons")
		end
	end)
end

local function RequestCategory(category)
	if inFlight == category or IsWardrobeOpen() then
		return
	end
	for i = 1, #seedQueue do
		if seedQueue[i] == category then
			return
		end
	end
	tinsert(seedQueue, category)
	if not seedScheduled then
		seedScheduled = true
		C_Timer:After(SEED_DELAY, FlushSeedQueue)
	end
end

-- Категория берётся из кэша предметов, поэтому «нет облика» запоминаем только когда
-- данные предмета уже пришли, иначе холодный промах застрял бы навсегда.
local function GetCategory(itemId)
	local category = categories[itemId]
	if category == nil then
		category = C_TransmogCollection.GetAppearanceSourceInfo(itemId)
		if not category or category == 0 then
			if not GetItemInfo(itemId) then
				return nil
			end
			category = false
		end
		categories[itemId] = category
	end
	return category or nil
end

local function IsUncollected(itemId)
	if not (C_TransmogCollection and itemId) then
		return nil
	end
	local category = GetCategory(itemId)
	if not category then
		return nil
	end
	if not IsCategoryReady(category) then
		RequestCategory(category)
		return nil
	end
	local _, canCollect = C_TransmogCollection.PlayerCanCollectSource(itemId)
	if not canCollect then
		return nil
	end
	return not C_TransmogCollection.IsCollectedSource(itemId)
end

function addon.IsAppearanceUncollected(itemId)
	if not mod:IsEnabled() then
		return nil
	end
	return IsUncollected(itemId)
end

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			anchor = "LEFT",
			offsetX = 2,
			offsetY = 0,
			size = 14,
		},
	})
end

local function UpdateBadgeLayout()
	local settings = mod.db.profile
	for _, badge in pairs(badges) do
		badge:SetSize(settings.size, settings.size)
		badge:ClearAndSetPoint(settings.anchor, badge:GetParent(), settings.offsetX, settings.offsetY)
	end
end

local function CreateBadge(button)
	local settings = mod.db.profile
	local badge = button:CreateTexture(nil, "OVERLAY")
	badge:SetTexture(BADGE_TEXTURE)
	badge:SetSize(settings.size, settings.size)
	badge:SetPoint(settings.anchor, button, settings.offsetX, settings.offsetY)
	badges[button] = badge
	return badge
end

function mod:OnEnable()
	self:RegisterMessage("AdiBags_UpdateButton", "UpdateButton")
	if not self.hooked then
		addon:RegisterItemTooltipHandler(function(tt)
			if self:IsEnabled() then
				self:CleanTooltip(tt)
			end
		end)
		self.hooked = true
	end
	self:SendMessage("AdiBags_UpdateAllButtons")
	UpdateBadgeLayout()
end

function mod:OnDisable()
	for _, badge in pairs(badges) do
		badge:Hide()
	end
end

function mod:UpdateButton(event, button)
	local badge = badges[button]
	if IsUncollected(button:GetItemId()) then
		if not badge then
			badge = CreateBadge(button)
		end
		badge:Show()
	elseif badge then
		badge:Hide()
	end
end

-- Клиентская строка "нет такой модели" врёт, поэтому её текст мы переписываем на месте
function mod:CleanTooltip(tt)
	local button = tt:GetOwner()
	if not (button and button.bag and button.slot and button.container) then
		return
	end
	if not TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN then
		return
	end
	local name = tt.GetName and tt:GetName()
	for index = tt:NumLines(), 1, -1 do
		local line
		if tt.GetLine then
			line = tt:GetLine(index)
		elseif name then
			line = _G[name .. "TextLeft" .. index]
		end
		if line and line:GetText() == TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN then
			local itemId = button:GetItemId()
			if
				itemId
				and addon.TestTooltipModifier
				and addon.TestTooltipModifier("appearance")
				and IsUncollected(itemId)
			then
				line:SetText(L["Appearance not collected"])
				line:SetTextColor(0.53, 0.67, 1)
			else
				line:SetText("")
			end
			return
		end
	end
end

function mod:GetOptions()
	return {
		size = {
			name = L["Badge size"],
			desc = L["Size of the badge shown on items with an uncollected appearance."],
			type = "range",
			min = 8,
			max = 24,
			step = 1,
			order = 10,
			set = function(info, value)
				mod.db.profile[info[#info]] = value
				UpdateBadgeLayout()
			end,
		},
		anchor = {
			name = L["Anchor"],
			type = "select",
			values = addon.ANCHOR_POINTS,
			order = 20,
			set = function(info, value)
				mod.db.profile[info[#info]] = value
				UpdateBadgeLayout()
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
				UpdateBadgeLayout()
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
				UpdateBadgeLayout()
			end,
		},
	},
		addon:GetOptionHandler(self)
end

local stateFrame = CreateFrame("Frame")
stateFrame:RegisterCustomEvent("TRANSMOG_COLLECTION_UPDATED")
stateFrame:RegisterCustomEvent("TRANSMOG_SEARCH_UPDATED")
stateFrame:SetScript("OnEvent", function()
	if mod:IsEnabled() then
		ScheduleRefresh()
	end
end)
