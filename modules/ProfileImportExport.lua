local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local format = _G.format
local LibStub = _G.LibStub
local pairs = _G.pairs
local pcall = _G.pcall
local print = _G.print
local strtrim = _G.strtrim
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type
--GLOBALS>

local AceGUI = LibStub("AceGUI-3.0")
local LibSerialize = LibStub("LibSerialize-AdiBags")
local LibDeflate = LibStub("LibDeflate-AdiBags")

local FORMAT_VERSION = 1
local DEFLATE_CONFIG = { level = 9 }

local ProfileIO = {}
addon.ProfileIO = ProfileIO

local function Print(msg)
	print("|cFF00BFFFAdiBags|r |cFFFF4444»|r " .. msg)
end

local function Snapshot(src)
	local dst = {}
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = Snapshot(v)
		else
			dst[k] = v
		end
	end
	return dst
end

local function ApplyInto(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			local sub = dst[k]
			if type(sub) ~= "table" then
				sub = {}
				dst[k] = sub
			end
			ApplyInto(sub, v)
		else
			dst[k] = v
		end
	end
end

function ProfileIO:BuildPayload()
	local namespaces = {}
	for name, child in pairs(addon.db.children or {}) do
		namespaces[name] = Snapshot(child.profile)
	end
	return {
		addon = addonName,
		version = FORMAT_VERSION,
		profile = Snapshot(addon.db.profile),
		namespaces = namespaces,
	}
end

function ProfileIO:Export()
	local ok, data = pcall(LibSerialize.Serialize, LibSerialize, self:BuildPayload())
	if not ok or type(data) ~= "string" then
		addon:Debug("Export failed", data)
		return ""
	end
	ok, data = pcall(LibDeflate.CompressDeflate, LibDeflate, data, DEFLATE_CONFIG)
	if not ok or type(data) ~= "string" then
		addon:Debug("Compression failed", data)
		return ""
	end
	return "!" .. addonName .. ":" .. FORMAT_VERSION .. "!" .. LibDeflate:EncodeForPrint(data)
end

function ProfileIO:Decode(code)
	if type(code) ~= "string" then
		return nil, L["This is not an AdiBags profile code."]
	end
	local version, body = strtrim(code):match("^!" .. addonName .. ":(%d+)!(.+)$")
	version = tonumber(version)
	if not body then
		return nil, L["This is not an AdiBags profile code."]
	end
	if version ~= FORMAT_VERSION then
		return nil, format(L["Unsupported profile code version: %s (expected %d)."], tostring(version), FORMAT_VERSION)
	end

	local damaged = L["The profile code is damaged or incomplete."]
	local data = LibDeflate:DecodeForPrint(body)
	if type(data) ~= "string" then
		return nil, damaged
	end
	local ok
	ok, data = pcall(LibDeflate.DecompressDeflate, LibDeflate, data)
	if not ok or type(data) ~= "string" then
		return nil, damaged
	end
	local success
	ok, success, data = pcall(LibSerialize.Deserialize, LibSerialize, data)
	if not ok or not success or type(data) ~= "table" then
		return nil, damaged
	end

	if data.addon ~= addonName then
		return nil, L["This is not an AdiBags profile code."]
	end
	if data.version ~= FORMAT_VERSION then
		return nil,
			format(L["Unsupported profile code version: %s (expected %d)."], tostring(data.version), FORMAT_VERSION)
	end
	if type(data.profile) ~= "table" then
		return nil, damaged
	end
	return data
end

function ProfileIO:Apply(data)
	local db = addon.db
	db:ResetProfile(nil, true)
	ApplyInto(db.profile, data.profile)

	local skipped = 0
	if type(data.namespaces) == "table" then
		for name, values in pairs(data.namespaces) do
			local child = db.children and db.children[name]
			if child and type(values) == "table" then
				ApplyInto(child.profile, values)
			else
				skipped = skipped + 1
			end
		end
	end

	db.callbacks:Fire("OnProfileChanged", db, db:GetCurrentProfile())
	return skipped
end

function ProfileIO:Import(code)
	if type(code) ~= "string" or strtrim(code) == "" then
		return false
	end
	local data, err = self:Decode(code)
	if not data then
		return false, err
	end
	local skipped = self:Apply(data)
	local message = L["Profile imported."]
	if skipped > 0 then
		message = message .. " " .. format(L["%d unknown section(s) were skipped."], skipped)
	end
	Print(message)
	return true, message
end

local exportWindow, importWindow

local function CreateWindow(title, width, height)
	local frame = AceGUI:Create("Frame")
	frame:SetTitle(addonName .. " - " .. title)
	frame:SetWidth(width)
	frame:SetHeight(height)
	frame:EnableResize(true)
	return frame
end

-- AceGUI recycles Frame widgets, so our own fields must go before releasing one.
local function ReleaseWindow(frame)
	frame.editBox = nil
	frame.importButton = nil
	AceGUI:Release(frame)
end

function ProfileIO:ShowExport()
	if exportWindow then
		ReleaseWindow(exportWindow)
		exportWindow = nil
	end

	local code = self:Export()
	local frame = CreateWindow(L["Export"], 620, 380)
	exportWindow = frame
	frame:SetLayout("Fill")
	frame:SetStatusText(L["Copy this code to share the current profile or to keep a backup of it."])
	frame:SetCallback("OnClose", function(widget)
		ReleaseWindow(widget)
		exportWindow = nil
	end)

	local edit = AceGUI:Create("MultiLineEditBox")
	edit:SetLabel("")
	edit:DisableButton(true)
	edit:SetFullWidth(true)
	edit:SetFullHeight(true)
	edit:SetText(code)
	edit:SetCallback("OnTextChanged", function(widget)
		if widget:GetText() ~= code then
			widget:SetText(code)
			widget.editBox:HighlightText()
		end
	end)
	frame:AddChild(edit)

	edit:SetFocus()
	edit.editBox:HighlightText()
	frame.editBox = edit
	return frame
end

function ProfileIO:ShowImport()
	if importWindow then
		ReleaseWindow(importWindow)
		importWindow = nil
	end

	local frame = CreateWindow(L["Import"], 620, 400)
	importWindow = frame
	frame:SetLayout("Flow")
	frame:SetStatusText(L["Paste a profile code here, then press Import."])
	frame:SetCallback("OnClose", function(widget)
		ReleaseWindow(widget)
		importWindow = nil
	end)

	local edit = AceGUI:Create("MultiLineEditBox")
	edit:SetLabel("")
	edit:DisableButton(true)
	edit:SetFullWidth(true)
	edit:SetNumLines(14)
	edit:SetText("")
	frame:AddChild(edit)

	local button = AceGUI:Create("Button")
	button:SetText(L["Import"])
	button:SetWidth(200)
	button:SetCallback("OnClick", function()
		local ok, message = ProfileIO:Import(edit:GetText())
		if message then
			frame:SetStatusText(ok and message or ("|cffff5555" .. message .. "|r"))
		end
	end)
	frame:AddChild(button)

	frame.editBox = edit
	frame.importButton = button
	edit:SetFocus()
	return frame
end
