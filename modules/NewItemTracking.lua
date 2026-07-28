local addonName, addon = ...
local L = addon.L

local mod = addon:RegisterFilter("NewItem", 100, "AceEvent-3.0", "AceBucket-3.0", "AceTimer-3.0")
mod.uiName = L["Track new items"]
mod.uiDesc =
	L['Track new items in each bag, displaying a glowing aura over them and putting them in a special section. "New" status can be reset by clicking on the small "N" button at top left of bags.']

local C_NewItems = _G.C_NewItems
local IsNewItem = C_NewItems and C_NewItems.IsNewItem
local ClearAllNewItems = C_NewItems and C_NewItems.ClearAll
local CreateFrame = _G.CreateFrame
local PlaySound = _G.PlaySound
local unpack = unpack

local bags = {}
local glows

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			showGlow = true,
			glowScale = 1.5,
			glowColor = { 0.3, 1, 0.3, 0.7 },
		},
	})
	addon:SetCategoryOrder(L["New"], 100)
end

function mod:OnEnable()
	for _, bag in addon:IterateDefinedBags() do
		if not bags[bag.bagName] then
			bags[bag.bagName] = {}
		end
	end

	addon:HookBagFrameCreation(self, "OnBagFrameCreated")
	for _, bag in pairs(bags) do
		if bag.button then
			bag.button:Show()
		end
	end

	self:RegisterMessage("AdiBags_UpdateButton", "UpdateButton")

	addon.filterProto.OnEnable(self)
end

function mod:OnDisable()
	for _, bag in pairs(bags) do
		if bag.button then
			bag.button:Hide()
		end
	end
	for _, glow in pairs(glows) do
		glow:Hide()
	end
	addon.filterProto.OnDisable(self)
end

local function IsNewItemSlot(bag, slot)
	if not IsNewItem or not bag or not slot then
		return false
	end
	return IsNewItem(bag, slot)
end

--------------------------------------------------------------------------------
-- Widget creation
--------------------------------------------------------------------------------

local function ResetButton_OnClick(button)
	PlaySound("igMainMenuOptionCheckBoxOn")
	if ClearAllNewItems then
		ClearAllNewItems()
		addon:UpdateFilters()
	end
	mod:SendMessage("AdiBags_NewItemReset")
end

function mod:OnBagFrameCreated(bag)
	local container = bag:GetFrame()

	local button = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
	button.bagName = bag.bagName
	button:SetText("N")
	button:SetWidth(20)
	button:SetHeight(20)
	button:SetScript("OnClick", ResetButton_OnClick)
	container:AddHeaderWidget(button, 10)
	addon.SetupTooltip(button, {
		L["Reset new items"],
		L["Click to reset item status."],
	}, "ANCHOR_TOPLEFT", 0, 8)

	bags[bag.bagName].button = button
	bags[bag.bagName].container = container
end

--------------------------------------------------------------------------------
-- Options
--------------------------------------------------------------------------------

function mod:GetOptions()
	return {
		showGlow = {
			name = L["New item highlight"],
			type = "toggle",
			order = 10,
		},
		glowScale = {
			name = L["Highlight scale"],
			type = "range",
			min = 0.5,
			max = 3.0,
			step = 0.01,
			isPercent = true,
			bigStep = 0.05,
			order = 20,
		},
		glowColor = {
			name = L["Highlight color"],
			type = "color",
			order = 30,
			hasAlpha = true,
		},
	},
		addon:GetOptionHandler(self)
end

--------------------------------------------------------------------------------
-- Filtering
--------------------------------------------------------------------------------

function mod:Filter(slotData)
	if IsNewItemSlot(slotData.bag, slotData.slot) then
		return L["New"]
	end
end

--------------------------------------------------------------------------------
-- Item glows
--------------------------------------------------------------------------------

glows = setmetatable({}, { __mode = "k" })
local hookedButtons = setmetatable({}, { __mode = "k" })

local function Glow_Update(glow)
	glow:SetScale(mod.db.profile.glowScale)
	glow.Texture:SetVertexColor(unpack(mod.db.profile.glowColor))
end

local function CreateGlow(button)
	local glow = CreateFrame("FRAME", nil, button)
	glow:SetFrameLevel(button:GetFrameLevel() + 15)
	glow:SetPoint("CENTER")
	glow:SetWidth(addon.ITEM_SIZE)
	glow:SetHeight(addon.ITEM_SIZE)

	local tex = glow:CreateTexture(nil, "OVERLAY")
	tex:SetTexture([[Interface\Cooldown\starburst]])
	tex:SetBlendMode("ADD")
	tex:SetAllPoints(glow)
	glow.Texture = tex

	local group = glow:CreateAnimationGroup()
	group:SetLooping("REPEAT")

	local anim = group:CreateAnimation("Rotation")
	anim:SetOrder(1)
	anim:SetDuration(10)
	anim:SetDegrees(360)
	anim:SetOrigin("CENTER", 0, 0)

	group:Play()

	glow.Update = Glow_Update

	glows[button] = glow
	return glow
end

local function Button_OnEnter(button)
	local glow = glows[button]
	if glow and glow:IsShown() then
		glow:Hide()
	end
end

function mod:UpdateButton(event, button)
	if not hookedButtons[button] then
		button:HookScript("OnEnter", Button_OnEnter)
		hookedButtons[button] = true
	end

	local glow = glows[button]
	local isNew = IsNewItemSlot(button.bag, button.slot)

	if mod.db.profile.showGlow and isNew then
		if not glow then
			glow = CreateGlow(button)
		end
		glow:Update()
		glow:Show()
	elseif glow then
		glow:Hide()
	end
end
