local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local HideUIPanel = _G.HideUIPanel
local InterfaceOptionsFrame = _G.InterfaceOptionsFrame
local ipairs = _G.ipairs
local setmetatable = _G.setmetatable
local sort = _G.table.sort
local strjoin = _G.strjoin
local type = _G.type
local unpack = _G.unpack
local wipe = _G.wipe
--GLOBALS>

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

local options

--------------------------------------------------------------------------------
-- Option handler prototype
--------------------------------------------------------------------------------

local handlerProto = {}
local handlerMeta = { __index = handlerProto }

function handlerProto:ResolvePath(info)
	local db = self.dbHolder.db.profile
	local path = info.arg or info[#info]
	if type(path) == "string" then
		return db, path, path
	elseif type(path) == "table" then
		local n = #path
		for i = 1, n - 1 do
			db = db[path[i]]
		end
		return db, path[n], strjoin(".", unpack(path))
	end
end

function handlerProto:Get(info, ...)
	local db, key = self:ResolvePath(info)
	if info.type == "multiselect" then
		local subKey = ...
		return db[key] and db[key][subKey]
	elseif info.type == "color" then
		return unpack(db[key], 1, 4)
	else
		return db[key]
	end
end

function handlerProto:Set(info, value, ...)
	local db, key, path = self:ResolvePath(info)
	if info.type == "multiselect" then
		local subKey, value = value, ...
		db[key][subKey] = value
		path = strjoin(".", path, subKey)
	elseif info.type == "color" then
		if db[key] then
			local color = db[key]
			color[1], color[2], color[3], color[4] = value, ...
		else
			db[key] = { value, ... }
		end
	else
		db[key] = value
	end
	self.dbHolder:Debug("ConfigSet", path, value, ...)
	if self.isFilter then
		self.dbHolder:SendMessage("AdiBags_ConfigChanged", "filter")
	else
		self.dbHolder:SendMessage("AdiBags_ConfigChanged", path)
	end
end

function handlerProto:IsDisabled(info)
	return (info.option ~= options and not addon.db.profile.enabled)
		or (self.dbHolder ~= addon and not self.dbHolder:IsEnabled())
end

local handlers = {}
function addon:GetOptionHandler(dbHolder, isFilter)
	if not handlers[dbHolder] then
		handlers[dbHolder] = setmetatable({ dbHolder = dbHolder, isFilter = isFilter }, handlerMeta)
		dbHolder.SendMessage = LibStub("AceEvent-3.0").SendMessage
	end
	return handlers[dbHolder]
end

--------------------------------------------------------------------------------
-- Filter & plugin options
--------------------------------------------------------------------------------

local filterOptions, moduleOptions = {}, {}

local OnModuleCreated
local UpdateFilterOrder, UpdateModuleOrder

do
	local filters = {
		options = filterOptions,
		count = 0,
		nameAttribute = "filterName",
		dbKey = "filters",
		optionPath = "filters",
	}
	local modules = {
		options = moduleOptions,
		count = 0,
		nameAttribute = "moduleName",
		dbKey = "modules",
		optionPath = "modules",
	}

	function OnModuleCreated(self, module)
		if module.isBag and not module.isFilter and not module.GetOptions then
			return
		end

		local data = module.isFilter and filters or modules
		local name = module[data.nameAttribute]

		local baseOptions = {
			name = module.uiName or L[name] or name,
			desc = module.uiDesc,
			type = "group",
			inline = true,
			order = 100 + data.count,
			args = {
				enabled = {
					name = L["Enabled"],
					desc = L["Check to enable this module."],
					type = "toggle",
					order = 20,
					get = function(info)
						return addon.db.profile[data.dbKey][name]
					end,
					set = function(info, value)
						addon.db.profile[data.dbKey][name] = value
						if value then
							module:Enable()
						else
							module:Disable()
						end
					end,
				},
			},
		}
		local extendedOptions

		if module.cannotDisable then
			baseOptions.args.enabled.disabled = true
		end
		if module.uiDesc then
			baseOptions.args.description = {
				name = module.uiDesc,
				type = "description",
				order = 10,
			}
		end
		if module.isFilter then
			baseOptions.args.priority = {
				name = L["Priority"],
				type = "range",
				order = 30,
				min = 0,
				max = 100,
				step = 1,
				bigStep = 1,
				get = function(info)
					return module:GetPriority()
				end,
				set = function(info, value)
					module:SetPriority(value)
				end,
			}
		end

		if module.GetOptions then
			local opts, handler = module:GetOptions()
			extendedOptions = {
				handler = handler,
				args = opts,
			}
		elseif module.GetFilterOptions then
			local opts, handler = module:GetFilterOptions()
			extendedOptions = {
				handler = handler,
				args = opts,
			}
		end

		data.options[name .. "Basic"] = baseOptions

		if extendedOptions then
			extendedOptions.name = module.uiName or L[name] or name
			extendedOptions.desc = module.uiDesc
			extendedOptions.type = "group"
			extendedOptions.order = 1000 + data.count
			data.options[name] = extendedOptions

			if module.uiDesc then
				extendedOptions.args.description = {
					name = module.uiDesc,
					type = "description",
					order = 1,
				}
			end

			baseOptions.args.configure = {
				name = L["Configure"],
				type = "execute",
				func = function()
					AceConfigDialog:SelectGroup(addonName, data.optionPath, name)
				end,
			}
		end
		data.count = data.count + 1
		if options and not module.isFilter then
			UpdateModuleOrder()
		end
	end
end

local function SetEntryOrder(opts, name, index)
	local basic = opts[name .. "Basic"]
	if basic then
		basic.order = 100 + 10 * index
	end
	local extended = opts[name]
	if extended then
		extended.order = 1000 + 10 * index
	end
end

function UpdateFilterOrder()
	for index, filter in addon:IterateFilters() do
		SetEntryOrder(filterOptions, filter.filterName, index)
	end
end

do
	local sorted = {}
	local names = {}

	local function CompareModules(a, b)
		return names[a] < names[b]
	end

	function UpdateModuleOrder()
		wipe(sorted)
		wipe(names)
		for _, module in addon:IterateModules() do
			local name = module.moduleName
			if not module.isFilter and moduleOptions[name .. "Basic"] then
				sorted[#sorted + 1] = name
				names[name] = module.uiName or L[name] or name
			end
		end
		sort(sorted, CompareModules)
		for index, name in ipairs(sorted) do
			SetEntryOrder(moduleOptions, name, index)
		end
	end
end

--------------------------------------------------------------------------------
-- Core options
--------------------------------------------------------------------------------

-- Keys are stored in the database and passed to SetPoint; only the values are displayed.
local ANCHOR_POINTS = {
	TOPLEFT = L["TOPLEFT"],
	TOP = L["TOP"],
	TOPRIGHT = L["TOPRIGHT"],
	LEFT = L["LEFT"],
	CENTER = L["CENTER"],
	RIGHT = L["RIGHT"],
	BOTTOMLEFT = L["BOTTOMLEFT"],
	BOTTOM = L["BOTTOM"],
	BOTTOMRIGHT = L["BOTTOMRIGHT"],
}
addon.ANCHOR_POINTS = ANCHOR_POINTS

local function GetCountSetting(info)
	return addon.db.profile[info[#info]]
end

local function SetCountSetting(info, value)
	addon.db.profile[info[#info]] = value
	addon:UpdateCountAppearance()
end

local function FontOptions(font, title, order)
	local opts = addon:CreateFontOptions(font, title, order)
	opts.args.size.step = 1
	return opts
end

local function CountTextOptions(order)
	local opts = addon:CreateFontOptions(addon.countFont, L["Stack count"], order, true)
	opts.args.size.step = 1
	opts.args.countAnchor = {
		name = L["Anchor"],
		desc = L["Corner of the item button the stack count is attached to."],
		type = "select",
		order = 50,
		values = ANCHOR_POINTS,
		get = GetCountSetting,
		set = SetCountSetting,
	}
	opts.args.countOffsetX = {
		name = L["X Offset"],
		desc = L["Offset in X direction (horizontal) from the given anchor point."],
		type = "range",
		order = 60,
		min = -20,
		max = 20,
		step = 1,
		bigStep = 1,
		get = GetCountSetting,
		set = SetCountSetting,
	}
	opts.args.countOffsetY = {
		name = L["Y Offset"],
		desc = L["Offset in Y direction (vertical) from the given anchor point."],
		type = "range",
		order = 70,
		min = -20,
		max = 20,
		step = 1,
		bigStep = 1,
		get = GetCountSetting,
		set = SetCountSetting,
	}
	return opts
end

local DISCORD_URL = "https://discord.gg/uvRF2AtWzm"

StaticPopupDialogs["ADIBAGS_DISCORD_LINK"] = {
	text = L["AdiBags Discord — select the link and press Ctrl+C to copy."],
	button1 = CLOSE,
	hasEditBox = true,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
	OnShow = function(self)
		self.editBox:SetText(DISCORD_URL)
		self.editBox:HighlightText()
		self.editBox:SetFocus()
	end,
	EditBoxOnTextChanged = function(self)
		if self:GetText() ~= DISCORD_URL then
			self:SetText(DISCORD_URL)
			self:HighlightText()
		end
	end,
	EditBoxOnEnterPressed = function(self)
		self:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end,
}

function addon:GetOptions()
	if options then
		return options
	end
	filterOptions._desc = {
		name = L["Filters are used to dispatch items in bag sections. One item can only appear in one section. If the same item is selected by several filters, the one with the highest priority wins."],
		type = "description",
		order = 1,
	}
	local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	profiles.order = 600
	profiles.disabled = false

	local function noProfileIO()
		return not addon.ProfileIO
	end
	profiles.args.importexport = {
		name = L["Profile import/export"],
		type = "header",
		order = 90,
		hidden = noProfileIO,
	}
	profiles.args.importexportdesc = {
		name = L["Export the current profile, with every filter and plugin setting, as a text code, or replace it with a code copied from somewhere else."],
		type = "description",
		order = 91,
		hidden = noProfileIO,
	}
	profiles.args.export = {
		name = L["Export"],
		desc = L["Open a window with the code of the current profile."],
		type = "execute",
		order = 92,
		hidden = noProfileIO,
		func = function()
			addon.ProfileIO:ShowExport()
		end,
	}
	profiles.args.import = {
		name = L["Import"],
		desc = L["Open a window where you can paste a profile code. The current profile is entirely replaced."],
		type = "execute",
		order = 93,
		hidden = noProfileIO,
		func = function()
			addon.ProfileIO:ShowImport()
		end,
	}
	local bagList = {}
	for name, module in self:IterateModules() do
		if module.isBag then
			bagList[module.bagName] = L[module.bagName]
		end
	end

	options = {
		--[===[@debug@
		name = addonName..' DEV',
		--@end-debug@]===]
		--@non-debug@
		name = addonName .. " " .. (GetAddOnMetadata(addonName, "Version") or ""),
		--@end-non-debug@
		type = "group",
		handler = addon:GetOptionHandler(addon),
		get = "Get",
		set = "Set",
		disabled = "IsDisabled",
		args = {
			enabled = {
				name = L["Enabled"],
				desc = L["Uncheck this to disable AdiBags."],
				type = "toggle",
				order = 10,
				width = "half",
				disabled = false,
			},
			discord = {
				name = "|cffff2020" .. L["Discord"] .. "|r",
				desc = L["Open a window with the Discord link."],
				type = "execute",
				order = 15,
				width = "half",
				disabled = false,
				func = function()
					StaticPopup_Show("ADIBAGS_DISCORD_LINK")
				end,
			},
			general = {
				name = L["General"],
				type = "group",
				order = 100,
				args = {
					bags = {
						name = L["Managed bags"],
						desc = L["Select which bags AdiBags should manage."],
						type = "multiselect",
						order = 10,
						values = bagList,
					},
					backgroundDrag = {
						name = L["Drag by empty space"],
						desc = L["Allow moving a bag by dragging any empty spot of its background, not only by its title bar."],
						type = "toggle",
						order = 35,
					},
					reset = {
						name = L["Reset position"],
						desc = L["Click there to reset the bag positions and sizes."],
						type = "execute",
						order = 50,
						func = function()
							addon:ResetBagPositions()
						end,
					},
					anchorFeedback = {
						name = L["Title bar highlight and tooltip"],
						type = "group",
						inline = true,
						order = 60,
						args = {
							showAnchorHighlight = {
								name = L["Show title bar highlight"],
								desc = L["Show a highlight when hovering over the bag title bar"],
								type = "toggle",
								order = 10,
								disabled = function(info)
									return (info.handler and info.handler:IsDisabled(info))
								end,
							},
							showAnchorTooltip = {
								name = L["Show title bar tooltip"],
								desc = L["Show a tooltip when hovering over the bag title bar"],
								type = "toggle",
								order = 20,
								disabled = function(info)
									return (info.handler and info.handler:IsDisabled(info))
								end,
							},
						},
					},
				},
			},
			appearance = {
				name = L["Appearance"],
				type = "group",
				order = 200,
				args = {
					layout = {
						name = L["Size and layout"],
						type = "group",
						inline = true,
						order = 10,
						args = {
							scale = {
								name = L["Scale"],
								desc = L["Use this to adjust the bag scale."],
								type = "range",
								order = 10,
								isPercent = true,
								min = 0.1,
								max = 3.0,
								step = 0.1,
								set = function(info, newScale)
									self.db.profile.scale = newScale
									self:LayoutBags()
									self:SendMessage("AdiBags_LayoutChanged")
								end,
							},
							maxHeight = {
								name = L["Maximum bag height"],
								desc = L["Adjust the maximum height of the bags, relative to screen size."],
								type = "range",
								order = 20,
								isPercent = true,
								min = 0.30,
								max = 0.90,
								step = 0.01,
							},
							rowWidth = {
								name = L["Maximum row width"],
								desc = L["Adjust the maximum number of items per row."],
								type = "group",
								inline = true,
								order = 30,
								args = {
									Backpack = {
										name = L["Backpack"],
										type = "range",
										order = 10,
										min = 4,
										max = 16,
										step = 1,
										arg = { "rowWidth", "Backpack" },
									},
									Bank = {
										name = L["Bank"],
										type = "range",
										order = 20,
										min = 4,
										max = 16,
										step = 1,
										arg = { "rowWidth", "Bank" },
									},
								},
							},
							laxOrdering = {
								name = L["Layout priority"],
								desc = L["Choose how sections are placed: keep their strict order, group sections of the same category together, or fill each row as much as possible."],
								type = "select",
								width = "double",
								order = 40,
								values = {
									[0] = L["Strictly keep ordering"],
									[1] = L["Group sections of same category"],
									[2] = L["Fill lines at most"],
								},
							},
							sortingOrder = {
								name = L["Sorting order"],
								desc = L["Select how items should be sorted within each section."],
								width = "double",
								type = "select",
								order = 50,
								values = {
									default = L["By category, subcategory, quality and item level (default)"],
									byName = L["By name"],
									byQualityAndLevel = L["By quality and item level"],
								},
							},
						},
					},
					background = {
						name = L["Bag background"],
						type = "group",
						inline = true,
						order = 20,
						args = {
							texture = {
								name = L["Texture"],
								type = "select",
								dialogControl = "AdiBags_LSM30_Background",
								values = AceGUIWidgetLSMlists.background,
								order = 10,
								arg = { "skin", "background" },
							},
							insets = {
								name = L["Insets"],
								type = "range",
								order = 20,
								arg = { "skin", "insets" },
								min = -16,
								max = 16,
								step = 1,
							},
							border = {
								name = L["Border"],
								type = "select",
								dialogControl = "AdiBags_LSM30_Border",
								values = AceGUIWidgetLSMlists.border,
								order = 30,
								arg = { "skin", "border" },
							},
							borderWidth = {
								name = L["Border width"],
								type = "range",
								order = 40,
								arg = { "skin", "borderWidth" },
								min = 1,
								max = 64,
								step = 1,
							},
							backpackColor = {
								name = L["Backpack color"],
								type = "color",
								order = 50,
								hasAlpha = true,
								arg = { "skin", "BackpackColor" },
							},
							bankColor = {
								name = L["Bank color"],
								type = "color",
								order = 60,
								hasAlpha = true,
								arg = { "skin", "BankColor" },
							},
						},
					},
					text = {
						name = L["Text"],
						type = "group",
						inline = true,
						order = 30,
						args = {
							bagFont = FontOptions(addon.bagFont, L["Bag title"], 10),
							sectionFont = FontOptions(addon.sectionFont, L["Section header"], 20),
							countFont = CountTextOptions(30),
						},
					},
				},
			},
			items = {
				name = L["Items"],
				type = "group",
				order = 300,
				args = {
					quality = {
						name = L["Quality highlight"],
						type = "group",
						inline = true,
						order = 10,
						args = {
							qualityHighlight = {
								name = L["Enabled"],
								desc = L["Check this to display a colored border around items, based on item quality."],
								type = "toggle",
								order = 10,
							},
							qualityOpacity = {
								name = L["Opacity"],
								desc = L["Use this to adjust the quality-based border opacity. 100% means fully opaque."],
								type = "range",
								order = 20,
								isPercent = true,
								min = 0.05,
								max = 1.0,
								step = 0.05,
								disabled = function(info)
									return info.handler:IsDisabled(info) or not addon.db.profile.qualityHighlight
								end,
							},
							dimJunk = {
								name = L["Dim junk"],
								desc = L["Check this to have poor quality items dimmed."],
								type = "toggle",
								order = 30,
								disabled = function(info)
									return info.handler:IsDisabled(info) or not addon.db.profile.qualityHighlight
								end,
							},
						},
					},
					indicators = {
						name = L["Indicators"],
						type = "group",
						inline = true,
						order = 20,
						args = {
							questIndicator = {
								name = L["Quest indicator"],
								desc = L["Check this to display an indicator on quest items."],
								type = "toggle",
								order = 10,
							},
							showBagType = {
								name = L["Bag type"],
								desc = L["Check this to display a bag type tag in the top left corner of items."],
								type = "toggle",
								order = 20,
							},
						},
					},
					setBadges = {
						name = L["Item set badges"],
						desc = L["Display short labels for raid, PvP and set replacement items."],
						type = "group",
						inline = true,
						order = 30,
						args = {
							enabled = {
								name = L["Enabled"],
								type = "toggle",
								order = 1,
								arg = { "setBadges", "enabled" },
							},
							tierPrefix = {
								name = L["Tier prefix"],
								desc = L["Text placed before the tier number."],
								type = "input",
								order = 10,
								arg = { "setBadges", "tierPrefix" },
							},
							pvpText = {
								name = L["PvP label"],
								desc = L["Text shown on items from gladiator sets."],
								type = "input",
								order = 20,
								arg = { "setBadges", "pvpText" },
							},
							fontSize = {
								name = L["Font size"],
								type = "range",
								min = 6,
								max = 24,
								step = 1,
								order = 30,
								arg = { "setBadges", "fontSize" },
							},
							anchor = {
								name = L["Anchor"],
								type = "select",
								values = ANCHOR_POINTS,
								order = 40,
								arg = { "setBadges", "anchor" },
							},
							offsetX = {
								name = L["X Offset"],
								type = "range",
								min = -20,
								max = 20,
								step = 1,
								order = 50,
								arg = { "setBadges", "offsetX" },
							},
							offsetY = {
								name = L["Y Offset"],
								type = "range",
								min = -20,
								max = 20,
								step = 1,
								order = 60,
								arg = { "setBadges", "offsetY" },
							},
							tierColor = {
								name = L["Tier color"],
								type = "color",
								order = 70,
								arg = { "setBadges", "tierColor" },
							},
							pvpColor = {
								name = L["PvP color"],
								type = "color",
								order = 80,
								arg = { "setBadges", "pvpColor" },
							},
						},
					},
					virtualStacks = {
						name = L["Virtual stacks"],
						type = "group",
						inline = true,
						order = 40,
						args = {
							_desc = {
								name = L["Virtual stacks display in one place items that actually spread over several bag slots."],
								type = "description",
								order = 1,
							},
							freeSpace = {
								name = L["Merge free space"],
								desc = L["Show only one free slot for each kind of bags."],
								order = 10,
								type = "toggle",
								arg = { "virtualStacks", "freeSpace" },
							},
							others = {
								name = L["Merge unstackable items"],
								desc = L["Show only one slot of items that cannot be stacked."],
								order = 15,
								width = "double",
								type = "toggle",
								arg = { "virtualStacks", "others" },
							},
							stackable = {
								name = L["Merge stackable items"],
								desc = L["Show only one slot of items that can be stacked."],
								order = 20,
								width = "double",
								type = "toggle",
								arg = { "virtualStacks", "stackable" },
							},
							incomplete = {
								name = L["... including incomplete stacks"],
								desc = L["Merge incomplete stacks with complete ones."],
								order = 30,
								width = "double",
								type = "toggle",
								arg = { "virtualStacks", "incomplete" },
								disabled = function(info)
									return info.handler:IsDisabled(info) or not addon.db.profile.virtualStacks.stackable
								end,
							},
							notWhenTrading = {
								name = L["When trading:"],
								desc = L["Change stacking at merchants', auction house, bank, mailboxes or when trading."],
								order = 40,
								width = "double",
								type = "select",
								arg = { "virtualStacks", "notWhenTrading" },
								values = {
									L["Keep all stacks together."],
									L["Separate unstackable items."],
									L["Separate incomplete stacks."],
									L["Show every distinct item stacks."],
								},
								disabled = function(info)
									return info.handler:IsDisabled(info)
										or not (
											addon.db.profile.virtualStacks.stackable
											or addon.db.profile.virtualStacks.others
										)
								end,
							},
						},
					},
				},
			},
			filters = {
				name = L["Filters"],
				desc = L["Toggle and configure item filters."],
				type = "group",
				order = 400,
				args = filterOptions,
			},
			modules = {
				name = L["Plugins"],
				desc = L["Toggle and configure plugins."],
				type = "group",
				order = 500,
				args = moduleOptions,
			},
			profiles = profiles,
		},
	}
	addon.OnModuleCreated = OnModuleCreated
	for name, module in addon:IterateModules() do
		addon:OnModuleCreated(module)
	end
	UpdateFilterOrder()
	UpdateModuleOrder()

	LibStub("AceEvent-3.0").RegisterMessage(addonName .. "Options", "AdiBags_FiltersChanged", UpdateFilterOrder)

	return options
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

function addon:InitializeOptions()
	local AceConfig = LibStub("AceConfig-3.0")

	AceConfig:RegisterOptionsTable(addonName .. "BlizzOptions", {
		name = addonName,
		type = "group",
		args = {
			configure = {
				name = L["Configure"],
				type = "execute",
				order = 100,
				func = function()
					-- Close all UIPanels
					-- Doing InterfaceOptionsFrame.lastFrame = nil here taints the thing, causing weird issues
					local currentFrame = InterfaceOptionsFrame
					while currentFrame do
						local lastFrame = currentFrame.lastFrame
						HideUIPanel(currentFrame)
						currentFrame = lastFrame
					end
					-- Open the option pane on next update, hopefully after AceConfigDialog tried to close all its windows
					LibStub("AceTimer-3.0").ScheduleTimer(addonName, addon.OpenOptions, 0)
				end,
			},
		},
	})
	AceConfigDialog:AddToBlizOptions(addonName .. "BlizzOptions", addonName)

	AceConfig:RegisterOptionsTable(addonName, function()
		return self:GetOptions()
	end)

	LibStub("AceConsole-3.0"):RegisterChatCommand("ab", function(cmd)
		addon:OpenOptions(strsplit(" ", cmd or ""))
	end, true)
	LibStub("AceConsole-3.0"):RegisterChatCommand("adibags", function(cmd)
		addon:OpenOptions(strsplit(" ", cmd or ""))
	end, true)
end

-- Open Options Function with ability to open certain tab. Usage: addon:OpenOptions("module name") or ("module name", "submodule name")
function addon:OpenOptions(...)
	AceConfigDialog:SetDefaultSize(addonName, 650, 540)
	if select("#", ...) > 0 then
		self:Debug("OpenOptions =>", select("#", ...), ...)
		AceConfigDialog:Open(addonName)
		AceConfigDialog:SelectGroup(addonName, ...)
	elseif not AceConfigDialog:Close(addonName) then
		AceConfigDialog:Open(addonName)
	end
end

-- Close Options Function
function addon:CloseOptions()
	AceConfigDialog:Close(addonName)
end
