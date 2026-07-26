local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local ipairs = _G.ipairs
local pairs = _G.pairs
local strtrim = _G.strtrim
local tinsert = _G.tinsert
local tsort = _G.table.sort
local type = _G.type
local wipe = _G.wipe
--GLOBALS>

local mod = addon:NewModule("CustomCategories", "AceEvent-3.0")
mod.uiName = L["Custom categories"]
mod.uiDesc = L["Create your own section categories and choose where they appear in your bags."]

local MIN_ORDER, MAX_ORDER, ORDER_STEP = -100, 100, 5

local registered = {}

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, { profile = { categories = {} } })
end

local function IsForeignCategory(name)
	if registered[name] then
		return false
	end
	for other in addon:IterateCategories() do
		if other == name then
			return true
		end
	end
	return false
end

local function ReleaseCategories()
	for name in pairs(registered) do
		addon:RemoveCategory(name)
	end
	wipe(registered)
end

local function ApplyCategories()
	for name, order in pairs(mod.db.profile.categories) do
		if not IsForeignCategory(name) then
			addon:SetCategoryOrder(name, order)
			registered[name] = true
		end
	end
end

function mod:OnEnable()
	ApplyCategories()
	self:UpdateOptions()
end

function mod:OnDisable()
	ReleaseCategories()
	self:UpdateOptions()
end

function mod:ApplyChanges()
	if self:IsEnabled() then
		ReleaseCategories()
		ApplyCategories()
		self:SendMessage("AdiBags_LayoutChanged")
	end
	self:UpdateOptions()
end

function mod:RenameCategory(oldName, newName)
	if oldName == newName then
		return
	end
	local categories = self.db.profile.categories
	local order = categories[oldName]
	categories[oldName] = nil
	categories[newName] = order
	local filterOverride = addon:GetModule("FilterOverride", true)
	if filterOverride then
		filterOverride:ReplaceCategory(oldName, newName)
	end
	self:ApplyChanges()
end

--------------------------------------------------------------------------------
-- Options
--------------------------------------------------------------------------------

local function TrimName(value)
	return type(value) == "string" and strtrim(value) or ""
end

local function ValidateName(value, currentName)
	local name = TrimName(value)
	if name == "" then
		return L["Enter the name of the new category."]
	end
	if name == currentName then
		return true
	end
	if mod.db.profile.categories[name] then
		return L["A category with this name already exists."]
	end
	for other in addon:IterateCategories() do
		if other == name then
			return L["This name is already used by another category."]
		end
	end
	return true
end

local function BuildCategoryGroup(name, order)
	return {
		type = "group",
		name = name,
		order = order,
		inline = true,
		args = {
			name = {
				type = "input",
				name = L["Name"],
				order = 10,
				get = function()
					return name
				end,
				set = function(_, value)
					mod:RenameCategory(name, TrimName(value))
				end,
				validate = function(_, value)
					return ValidateName(value, name)
				end,
			},
			order = {
				type = "range",
				name = L["Order"],
				desc = L["Higher values put the category closer to the top of your bags."],
				order = 20,
				min = MIN_ORDER,
				max = MAX_ORDER,
				step = ORDER_STEP,
				bigStep = ORDER_STEP,
				get = function()
					return mod.db.profile.categories[name] or 0
				end,
				set = function(_, value)
					mod.db.profile.categories[name] = value
					mod:ApplyChanges()
				end,
			},
			remove = {
				type = "execute",
				name = L["Remove"],
				desc = L["Sections put in a deleted category are kept, but they are no longer sorted."],
				order = 30,
				confirm = true,
				confirmText = L["Are you sure you want to delete this category ?"],
				func = function()
					mod.db.profile.categories[name] = nil
					mod:ApplyChanges()
				end,
			},
		},
	}
end

local options
function mod:GetOptions()
	if not options then
		local newName, newOrder = "", 0
		options = {
			new = {
				type = "group",
				name = L["New category"],
				order = 10,
				inline = true,
				args = {
					name = {
						type = "input",
						name = L["Name"],
						desc = L["Enter the name of the new category."],
						order = 10,
						get = function()
							return newName
						end,
						set = function(_, value)
							newName = TrimName(value)
						end,
						validate = function(_, value)
							return ValidateName(value)
						end,
					},
					order = {
						type = "range",
						name = L["Order"],
						desc = L["Higher values put the category closer to the top of your bags."],
						order = 20,
						min = MIN_ORDER,
						max = MAX_ORDER,
						step = ORDER_STEP,
						bigStep = ORDER_STEP,
						get = function()
							return newOrder
						end,
						set = function(_, value)
							newOrder = value
						end,
					},
					add = {
						type = "execute",
						name = L["Add category"],
						order = 30,
						func = function()
							mod.db.profile.categories[newName] = newOrder
							newName, newOrder = "", 0
							mod:ApplyChanges()
						end,
						disabled = function()
							return ValidateName(newName) ~= true
						end,
					},
				},
			},
		}
		mod:UpdateOptions()
	end

	return options
end

do
	local groupKeys = {}
	local sorted = {}
	local orders

	local function CompareCategories(a, b)
		if orders[a] == orders[b] then
			return a < b
		end
		return orders[a] > orders[b]
	end

	function mod:UpdateOptions()
		if not options then
			return
		end
		for _, key in ipairs(groupKeys) do
			options[key] = nil
		end
		wipe(groupKeys)
		wipe(sorted)
		orders = self.db.profile.categories
		for name in pairs(orders) do
			tinsert(sorted, name)
		end
		tsort(sorted, CompareCategories)
		for index, name in ipairs(sorted) do
			local key = "c_" .. name
			options[key] = BuildCategoryGroup(name, 20 + index)
			tinsert(groupKeys, key)
		end
		-- FilterOverride caches the category list, it has to rebuild it to see ours
		local filterOverride = addon:GetModule("FilterOverride", true)
		if filterOverride then
			filterOverride:UpdateOptions()
		end
		local acr = LibStub("AceConfigRegistry-3.0", true)
		if acr then
			acr:NotifyChange(addonName)
		end
	end
end
