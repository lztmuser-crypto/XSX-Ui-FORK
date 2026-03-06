--[[
  XSX-style custom UI library
]]

local CloneRef = cloneref or function(a)return a end

--// Service handlers
local Services = setmetatable({}, {
	__index = function(self, Name: string)
		local Service = game:GetService(Name)
		return CloneRef(Service)
	end,
})

-- / Locals
local Player = Services.Players.LocalPlayer
local Mouse = CloneRef(Player:GetMouse())

-- / Services
local UserInputService = Services.UserInputService
local TextService = Services.TextService
local TweenService =Services.TweenService
local RunService = Services.RunService
local HttpService = Services.HttpService
local CoreGui = RunService:IsStudio() and CloneRef(Player:WaitForChild("PlayerGui")) or Services.CoreGui
local TeleportService = Services.TeleportService
local Workspace = Services.Workspace
local CurrentCam = Workspace.CurrentCamera
local StarterGui = Services.StarterGui

local hiddenUI = get_hidden_gui or gethui or function(a)return CoreGui end

-- / Defaults 
local OptionStates = {} -- Used for panic
local SavedControls = {
	Toggles = {},
	Sliders = {},
}
local library = {
	title = "XSX Styled UI",
	company = "Custom",
	
	RainbowEnabled = false,
	BlurEffect = false,
	BlurSize = 24,
	FieldOfView = CurrentCam.FieldOfView,

	Key = UserInputService.TouchEnabled and Enum.KeyCode.P or Enum.KeyCode.RightShift,
	fps = 0,
	Debug = true,

	-- / Elements Config
	transparency = 0,
	backgroundColor = Color3.fromRGB(31, 31, 31),
	headerColor = Color3.fromRGB(198, 198, 198),
	companyColor = Color3.fromRGB(198, 198, 198),
	acientColor = Color3.fromRGB(198, 198, 198),
	darkGray = Color3.fromRGB(27, 27, 27),
	lightGray = Color3.fromRGB(48, 48, 48),

	Font = Enum.Font.GothamSemibold,
	ConfigFolder = "XSXUI",
	ConfigFile = "settings.json",
	HopQueueFile = "hop_queue.lua",
	AutoloadFile = "autoload.json",
	HopFlagsFile = "hop_flags.json",
	AutoSave = true,
	QueueSource = nil,
	LoadedConfig = nil,
	AutoSaveStarted = false,

	rainbowColors = ColorSequence.new{
		ColorSequenceKeypoint.new(0.00, Color3.fromRGB(198, 198, 198)),
		ColorSequenceKeypoint.new(1.00, Color3.fromRGB(198, 198, 198))
	}
}

local function Warn(...)
	if not library.Debug then return end
	warn("CustomUI:", ...)
end

-- / Remove the previous interface
if _G.XSXCustomUI then
	pcall(function()
		_G.XSXCustomUI:Remove()
	end)
end
_G.XSXCustomUI = library

-- / Blur effect
local Blur = Instance.new("BlurEffect", CurrentCam)
Blur.Enabled = false
Blur.Size = 0

-- / Tween table & function
local TweenWrapper = {}

function TweenWrapper:Init()
	self.RealStyles = {
		Default = {
			TweenInfo.new(0.17, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, false, 0)
		}
	}
	self.Styles = setmetatable({}, {
		__index = function(_, Key)
			local Value = self.RealStyles[Key]
			if not Value then
				Warn(`No Tween style for {Key}, returning default`)
				return self.RealStyles.Default
			end
			return Value
		end,
	})
end

function TweenWrapper:CreateStyle(name, speed, ...)
	if not name then 
		return TweenInfo.new(0) 
	end

	local Tweeninfo = TweenInfo.new(
		speed or 0.17, 
		...
	)

	self.RealStyles[name] = Tweeninfo
	return Tweeninfo
end

TweenWrapper:Init()


-- / Dragging
local function EnableDrag(obj, latency)
	if not obj then
		return
	end
	latency = latency or 0.06

	local toggled = nil
	local input = nil
	local start = nil
	local startPos = obj.Position
	
	local function InputIsAccepted(Input)
		local UserInputType = Input.UserInputType
		
		if UserInputType == Enum.UserInputType.Touch then return true end
		if UserInputType == Enum.UserInputType.MouseButton1 then return true end
		
		return false
	end

	obj.InputBegan:Connect(function(Input)
		if not InputIsAccepted(Input) then return end
		
		toggled = true
		start = Input.Position
		startPos = obj.Position
		
		Input.Changed:Connect(function()
			if Input.UserInputState == Enum.UserInputState.End then
				toggled = false
			end
		end)
	end)

	obj.InputChanged:Connect(function(Input)
		local MouseMovement = Input.UserInputType == Enum.UserInputType.MouseMovement
		if not MouseMovement and not InputIsAccepted(Input) then return end 
		
		input = Input
	end)

	UserInputService.InputChanged:Connect(function(Input)
		if Input == input and toggled then
			local Delta = input.Position - start
			local Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + Delta.X, startPos.Y.Scale, startPos.Y.Offset + Delta.Y)
			TweenService:Create(obj, TweenInfo.new(latency), {Position = Position}):Play()
		end
	end)
end

local function FindFirstChildInsensitive(parent, childName)
	if typeof(parent) ~= "Instance" then
		return nil
	end
	if type(childName) ~= "string" then
		return nil
	end
	local trimmed = childName:gsub("^%s+", ""):gsub("%s+$", "")
	if trimmed == "" then
		return nil
	end

	local direct = parent:FindFirstChild(trimmed)
	if direct then
		return direct
	end

	local lowered = string.lower(trimmed)
	for _, child in ipairs(parent:GetChildren()) do
		if string.lower(child.Name) == lowered then
			return child
		end
	end
	return nil
end

RunService.RenderStepped:Connect(function(v)
	library.fps =  math.round(1/v)
end)

function library:RoundNumber(int, float)
	return tonumber(string.format("%." .. (int or 0) .. "f", float))
end

function library:GetUsername()
	return Player.Name
end

function library:Panic()
	for Frame, Data in next, OptionStates do
		local Functions = Data[2]
		local State = Data[1]

		Functions:Set(State)
	end
	return self
end

function library:SetKeybind(new)
	library.Key = new
	return self
end

function library:ResolveKeyCode(inputValue)
	if typeof(inputValue) == "EnumItem" and inputValue.EnumType == Enum.KeyCode then
		return inputValue
	end
	if type(inputValue) ~= "string" then
		return nil
	end
	local raw = inputValue:gsub("^%s+", ""):gsub("%s+$", "")
	if raw == "" then
		return nil
	end
	if Enum.KeyCode[raw] then
		return Enum.KeyCode[raw]
	end
	local lowered = string.lower(raw)
	for _, keyCode in ipairs(Enum.KeyCode:GetEnumItems()) do
		if string.lower(keyCode.Name) == lowered then
			return keyCode
		end
	end
	return nil
end

function library:IsGameLoaded()
	return game:IsLoaded()
end

function library:GetUserId()
	return Player.UserId
end

function library:GetPlaceId()
	return game.PlaceId
end

function library:GetJobId()
	return game.JobId
end

function library:Rejoin()
	TeleportService:TeleportToPlaceInstance(
		library:GetPlaceId(), 
		library:GetJobId(), 
		library:GetUserId()
	)
end

function library:NativeNotify(title, text, duration)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = tostring(title or "Custom UI"),
			Text = tostring(text or ""),
			Duration = tonumber(duration) or 3,
		})
	end)
end

function library:GetQueueOnTeleport()
	local qot = queue_on_teleport or queueonteleport
	if type(qot) == "function" then
		return qot
	end
	if type(syn) == "table" and type(syn.queue_on_teleport) == "function" then
		return syn.queue_on_teleport
	end
	local env = (getgenv and getgenv()) or _G
	if type(env) == "table" then
		qot = env.queue_on_teleport or env.queueonteleport
		if type(qot) == "function" then
			return qot
		end
	end
	return nil
end

function library:EnsureConfigFolder()
	if type(isfolder) == "function" and type(makefolder) == "function" then
		local ok, exists = pcall(isfolder, library.ConfigFolder)
		if ok and not exists then
			pcall(makefolder, library.ConfigFolder)
		end
	end
end

function library:ConfigPath(fileName)
	local name = fileName or library.ConfigFile
	if type(name) ~= "string" or name == "" then
		return nil
	end
	if string.find(name, "/", 1, true) or string.find(name, "\\", 1, true) then
		return name
	end
	return library.ConfigFolder .. "/" .. name
end

function library:ReadConfig(fileName)
	if type(readfile) ~= "function" or type(isfile) ~= "function" then
		return nil
	end
	local path = library:ConfigPath(fileName)
	if not path then
		return nil
	end
	local okExists, exists = pcall(isfile, path)
	if not okExists or not exists then
		return nil
	end
	local okRead, raw = pcall(readfile, path)
	if not okRead or type(raw) ~= "string" or raw == "" then
		return nil
	end
	local okDecode, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not okDecode or type(data) ~= "table" then
		return nil
	end
	return data
end

function library:WriteConfig(data, fileName)
	if type(writefile) ~= "function" then
		return false
	end
	library:EnsureConfigFolder()
	local path = library:ConfigPath(fileName)
	if not path then
		return false
	end
	local okEncode, raw = pcall(function()
		return HttpService:JSONEncode(data)
	end)
	if not okEncode then
		return false
	end
	local okWrite = pcall(writefile, path, raw)
	return okWrite == true
end

function library:NormalizeConfigName(name)
	local raw = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if raw == "" then
		return nil
	end
	if not raw:lower():find(".json", 1, true) then
		raw = raw .. ".json"
	end
	return raw
end

function library:SetActiveConfig(name)
	local normalized = library:NormalizeConfigName(name)
	if not normalized then
		return false
	end
	library.ConfigFile = normalized
	library.SelectedConfig = normalized
	return true
end

function library:GetConfigList()
	local out = {}
	local seen = {}
	local internalFiles = {
		[string.lower(tostring(library.AutoloadFile or ""))] = true,
		[string.lower(tostring(library.HopFlagsFile or ""))] = true,
		[string.lower("default_theme.json")] = true,
	}
	local function addConfig(name)
		local normalized = library:NormalizeConfigName(name)
		if normalized and not seen[normalized] then
			seen[normalized] = true
			table.insert(out, normalized)
		end
	end

	addConfig(library.SelectedConfig or library.ConfigFile)

	if type(listfiles) == "function" then
		library:EnsureConfigFolder()
		local ok, files = pcall(listfiles, library.ConfigFolder)
		if ok and type(files) == "table" then
			for _, path in ipairs(files) do
				if type(path) == "string" then
					local filename = path:gsub("\\", "/"):match("([^/]+)$")
					if filename and filename:lower():sub(-5) == ".json" and not internalFiles[filename:lower()] then
						addConfig(filename)
					end
				end
			end
		end
	end

	table.sort(out)
	return out
end

function library:GetAutoloadConfigName()
	local data = library:ReadConfig(library.AutoloadFile)
	if type(data) ~= "table" then
		return nil
	end
	if data.Enabled == false then
		return nil
	end
	return library:NormalizeConfigName(data.Config)
end

function library:SetAutoloadConfig(name)
	local normalized = library:NormalizeConfigName(name)
	if not normalized then
		return false
	end
	return library:WriteConfig({
		Enabled = true,
		Config = normalized,
		Updated = os.time(),
	}, library.AutoloadFile)
end

function library:DisableAutoloadConfig()
	return library:WriteConfig({
		Enabled = false,
		Config = nil,
		Updated = os.time(),
	}, library.AutoloadFile)
end

function library:SetSkipAutoloadOnce(enabled)
	return library:WriteConfig({
		SkipAutoloadOnce = enabled == true,
		Updated = os.time(),
	}, library.HopFlagsFile)
end

function library:ConsumeSkipAutoloadOnce()
	local data = library:ReadConfig(library.HopFlagsFile)
	local shouldSkip = type(data) == "table" and data.SkipAutoloadOnce == true
	if shouldSkip then
		library:SetSkipAutoloadOnce(false)
	end
	return shouldSkip
end

library.ThemePresets = {
	Mono = { backgroundColor = Color3.fromRGB(31, 31, 31), darkGray = Color3.fromRGB(27, 27, 27), lightGray = Color3.fromRGB(48, 48, 48), headerColor = Color3.fromRGB(198, 198, 198), companyColor = Color3.fromRGB(198, 198, 198), acientColor = Color3.fromRGB(198, 198, 198) },
	Slate = { backgroundColor = Color3.fromRGB(29, 33, 39), darkGray = Color3.fromRGB(22, 25, 31), lightGray = Color3.fromRGB(53, 59, 67), headerColor = Color3.fromRGB(205, 212, 220), companyColor = Color3.fromRGB(173, 189, 207), acientColor = Color3.fromRGB(173, 189, 207) },
	Crimson = { backgroundColor = Color3.fromRGB(36, 24, 27), darkGray = Color3.fromRGB(29, 19, 22), lightGray = Color3.fromRGB(61, 43, 48), headerColor = Color3.fromRGB(229, 206, 212), companyColor = Color3.fromRGB(221, 146, 166), acientColor = Color3.fromRGB(221, 146, 166) },
	Ocean = { backgroundColor = Color3.fromRGB(22, 31, 40), darkGray = Color3.fromRGB(18, 25, 32), lightGray = Color3.fromRGB(43, 62, 76), headerColor = Color3.fromRGB(199, 222, 235), companyColor = Color3.fromRGB(124, 183, 224), acientColor = Color3.fromRGB(124, 183, 224) },
	Forest = { backgroundColor = Color3.fromRGB(24, 34, 26), darkGray = Color3.fromRGB(19, 28, 21), lightGray = Color3.fromRGB(45, 62, 49), headerColor = Color3.fromRGB(204, 223, 208), companyColor = Color3.fromRGB(142, 201, 154), acientColor = Color3.fromRGB(142, 201, 154) },
	Amber = { backgroundColor = Color3.fromRGB(39, 31, 22), darkGray = Color3.fromRGB(31, 24, 18), lightGray = Color3.fromRGB(68, 53, 37), headerColor = Color3.fromRGB(230, 220, 204), companyColor = Color3.fromRGB(226, 185, 122), acientColor = Color3.fromRGB(226, 185, 122) },
	Violet = { backgroundColor = Color3.fromRGB(33, 27, 41), darkGray = Color3.fromRGB(27, 22, 34), lightGray = Color3.fromRGB(57, 48, 71), headerColor = Color3.fromRGB(220, 213, 235), companyColor = Color3.fromRGB(181, 157, 225), acientColor = Color3.fromRGB(181, 157, 225) },
	Ice = { backgroundColor = Color3.fromRGB(27, 34, 39), darkGray = Color3.fromRGB(22, 28, 33), lightGray = Color3.fromRGB(52, 63, 71), headerColor = Color3.fromRGB(212, 223, 229), companyColor = Color3.fromRGB(154, 196, 221), acientColor = Color3.fromRGB(154, 196, 221) },
	Rose = { backgroundColor = Color3.fromRGB(39, 29, 33), darkGray = Color3.fromRGB(31, 23, 27), lightGray = Color3.fromRGB(66, 48, 54), headerColor = Color3.fromRGB(231, 213, 219), companyColor = Color3.fromRGB(219, 158, 179), acientColor = Color3.fromRGB(219, 158, 179) },
	Mint = { backgroundColor = Color3.fromRGB(24, 36, 34), darkGray = Color3.fromRGB(20, 30, 28), lightGray = Color3.fromRGB(47, 65, 61), headerColor = Color3.fromRGB(206, 225, 222), companyColor = Color3.fromRGB(145, 211, 197), acientColor = Color3.fromRGB(145, 211, 197) },
	Steel = { backgroundColor = Color3.fromRGB(30, 30, 35), darkGray = Color3.fromRGB(24, 24, 29), lightGray = Color3.fromRGB(53, 53, 61), headerColor = Color3.fromRGB(212, 212, 220), companyColor = Color3.fromRGB(170, 170, 186), acientColor = Color3.fromRGB(170, 170, 186) },
	Sunset = { backgroundColor = Color3.fromRGB(40, 28, 24), darkGray = Color3.fromRGB(33, 22, 19), lightGray = Color3.fromRGB(67, 46, 39), headerColor = Color3.fromRGB(232, 214, 205), companyColor = Color3.fromRGB(224, 165, 141), acientColor = Color3.fromRGB(224, 165, 141) },
}
library.CurrentThemeName = "Mono"

function library:GetThemeNames()
	local out = {}
	for themeName in pairs(library.ThemePresets) do
		table.insert(out, themeName)
	end
	table.sort(out)
	return out
end

function library:ApplyTheme(themeName)
	local preset = library.ThemePresets[themeName]
	if not preset then
		return false
	end

	library.CurrentThemeName = themeName
	for key, value in pairs(preset) do
		library[key] = value
	end

	local refs = library.UIRefs
	if refs then
		if refs.Background then refs.Background.BackgroundColor3 = library.backgroundColor end
		if refs.TabButtons then refs.TabButtons.BackgroundColor3 = library.darkGray end
		if refs.Container then refs.Container.BackgroundColor3 = library.darkGray end
		if refs.Company then refs.Company.TextColor3 = library.companyColor end
		if refs.HeaderLabel then refs.HeaderLabel.TextColor3 = library.headerColor end
		if refs.PanicButton then refs.PanicButton.BackgroundColor3 = library.darkGray end
		if refs.Screen then
			for _, inst in ipairs(refs.Screen:GetDescendants()) do
				if inst:IsA("UIStroke") then
					inst.Color = library.lightGray
				elseif inst:IsA("TextButton") or inst:IsA("TextLabel") then
					if inst.TextColor3 ~= Color3.fromRGB(255, 74, 77) and inst.TextColor3 ~= Color3.fromRGB(131, 255, 103) then
						inst.TextColor3 = library.headerColor
					end
				end
			end
		end
	end
	return true
end

function library:ThemeConfigPath()
	return library:ConfigPath("default_theme.json")
end

function library:LoadDefaultTheme()
	if type(readfile) ~= "function" or type(isfile) ~= "function" then
		return
	end
	local path = library:ThemeConfigPath()
	if not path then
		return
	end
	local okExists, exists = pcall(isfile, path)
	if not okExists or not exists then
		return
	end
	local okRead, raw = pcall(readfile, path)
	if not okRead or type(raw) ~= "string" or raw == "" then
		return
	end
	local okDecode, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if okDecode and type(data) == "table" and type(data.Theme) == "string" then
		library:ApplyTheme(data.Theme)
	end
end

function library:SetDefaultTheme(themeName)
	if not library.ThemePresets[themeName] then
		return false
	end
	library:EnsureConfigFolder()
	local path = library:ThemeConfigPath()
	if not path or type(writefile) ~= "function" then
		return false
	end
	local payload = HttpService:JSONEncode({ Theme = themeName })
	local okWrite = pcall(writefile, path, payload)
	return okWrite == true
end

function library:CollectConfig()
	local out = {
		_meta = {
			version = "xsx-custom-1",
			updated = os.time(),
		},
		_settings = {
			keybind = library.Key and library.Key.Name or nil,
			theme = library.CurrentThemeName,
		},
	}

	for key, control in pairs(SavedControls.Toggles) do
		if control and type(control.GetValue) == "function" then
			out[key] = control:GetValue() == true
		end
	end
	for key, control in pairs(SavedControls.Sliders) do
		if control and type(control.GetValue) == "function" then
			out[key] = tonumber(control:GetValue()) or 0
		end
	end

	return out
end

function library:SaveConfig(fileName)
	local target = fileName or library.SelectedConfig or library.ConfigFile
	if target then
		library:SetActiveConfig(target)
	end
	local payload = library:CollectConfig()
	return library:WriteConfig(payload, library.SelectedConfig or library.ConfigFile)
end

function library:LoadConfig(fileName)
	local target = fileName or library.SelectedConfig or library.ConfigFile
	if target then
		library:SetActiveConfig(target)
	end
	local data = library:ReadConfig(library.SelectedConfig or library.ConfigFile)
	if type(data) ~= "table" then
		return false
	end
	library.LoadedConfig = data

	for key, control in pairs(SavedControls.Toggles) do
		local value = data[key]
		if value ~= nil and control and type(control.Set) == "function" then
			control:Set(value == true)
		end
	end

	for key, control in pairs(SavedControls.Sliders) do
		local value = data[key]
		if value ~= nil and control and type(control.Set) == "function" then
			control:Set(tonumber(value) or 0)
		end
	end

	local settings = data._settings
	if type(settings) == "table" then
		local keybindName = settings.keybind
		if type(keybindName) == "string" and Enum.KeyCode[keybindName] then
			library:SetKeybind(Enum.KeyCode[keybindName])
		end
		local themeName = settings.theme
		if type(themeName) == "string" then
			library:ApplyTheme(themeName)
		end
	end

	return true
end

function library:StartAutoSave()
	if library.AutoSaveStarted then
		return
	end
	library.AutoSaveStarted = true
	task.spawn(function()
		while library.AutoSaveStarted do
			if library.AutoSave then
				library:SaveConfig()
			end
			task.wait(2)
		end
	end)
end

function library:SetQueueOnTeleportScript(source)
	if type(source) ~= "string" or source == "" then
		library.QueueSource = nil
		return self
	end
	library.QueueSource = source
	if type(writefile) == "function" then
		library:EnsureConfigFolder()
		local hopPath = library:ConfigPath(library.HopQueueFile)
		if hopPath then
			pcall(writefile, hopPath, source)
		end
	end
	return self
end

function library:SetQueueOnTeleportHttpGet(url)
	if type(url) ~= "string" or url == "" then
		return self
	end
	return library:SetQueueOnTeleportScript(string.format("loadstring(game:HttpGet(%q))()", url))
end

function library:SetQueueOnTeleportReadFile(path)
	if type(path) ~= "string" or path == "" then
		return self
	end
	return library:SetQueueOnTeleportScript(string.format("loadstring(readfile(%q))()", path))
end

function library:ServerHop(sourceOverride, options)
	options = type(options) == "table" and options or {}
	local skipAutoload = options.SkipAutoload
	if skipAutoload == nil then
		skipAutoload = true
	end
	library:SetSkipAutoloadOnce(skipAutoload)
	library:SaveConfig()
	local queueSource = sourceOverride or library.QueueSource
	if (not queueSource) and type(readfile) == "function" and type(isfile) == "function" then
		local hopPath = library:ConfigPath(library.HopQueueFile)
		if hopPath then
			local okExists, exists = pcall(isfile, hopPath)
			if okExists and exists then
				local okRead, source = pcall(readfile, hopPath)
				if okRead and type(source) == "string" and source ~= "" then
					queueSource = source
				end
			end
		end
	end

	if type(queueSource) == "string" and queueSource ~= "" then
		local qot = library:GetQueueOnTeleport()
		if type(qot) == "function" then
			pcall(qot, queueSource)
		else
			library:NativeNotify("Custom UI", "queue_on_teleport unavailable", 3)
		end
	else
		library:NativeNotify("Custom UI", "No queue source set", 3)
	end

	local ok = pcall(function()
		TeleportService:Teleport(game.PlaceId, Player)
	end)
	if not ok then
		pcall(function()
			TeleportService:Teleport(game.PlaceId)
		end)
	end
end

function library:Copy(input) 
	local clipBoard = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)
	if clipBoard then
		clipBoard(input)
	end
end

function library:GetDay(type)
	if type == "word" then -- day in a full word
		return os.date("%A")
	elseif type == "short" then -- day in a shortened word
		return os.date("%a")
	elseif type == "month" then -- day of the month in digits
		return os.date("%d")
	elseif type == "year" then -- day of the year in digits
		return os.date("%j")
	end
end

function library:GetTime(type)
	if type == "24h" then -- time using a 24 hour clock
		return os.date("%H")
	elseif type == "12h" then -- time using a 12 hour clock
		return os.date("%I")
	elseif type == "minute" then -- time in minutes
		return os.date("%M")
	elseif type == "half" then -- what part of the day it is (AM or PM)
		return os.date("%p")
	elseif type == "second" then -- time in seconds
		return os.date("%S")
	elseif type == "full" then -- full time
		return os.date("%X")
	elseif type == "ISO" then -- ISO / UTC ( 1min = 1, 1hour = 100)
		return os.date("%z")
	elseif type == "zone" then -- time zone
		return os.date("%Z") 
	end
end

function library:GetMonth(type)
	if type == "word" then -- full month name
		return os.date("%B")
	elseif type == "short" then -- month in shortened word
		return os.date("%b")
	elseif type == "digit" then -- the months digit
		return os.date("%m")
	end
end

function library:GetWeek(type)
	if type == "year_S" then -- the number of the week in the current year (sunday first day)
		return os.date("%U")
	elseif type == "day" then -- the week day
		return os.date("%w")
	elseif type == "year_M" then -- the number of the week in the current year (monday first day)
		return os.date("%W")
	end
end

function library:GetYear(type)
	if type == "digits" then -- the second 2 digits of the year
		return os.date("%y")
	elseif type == "full" then -- the full year
		return os.date("%Y")
	end
end

function library:UnlockFps(new) 
	if setfpscap then
		setfpscap(new)
	end
end

TweenWrapper:CreateStyle("Rainbow", 5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true)
function library:ApplyRainbow(instance, Wave)
	local Colors = library.rainbowColors
	local RainbowEnabled = library.RainbowEnabled
	
	if not RainbowEnabled then return end

	if not Wave then
		instance.BackgroundColor3 = Colors.Keypoints[1].Value
		TweenService:Create(instance, TweenWrapper.Styles["Rainbow"], {
			BackgroundColor3 =  Colors.Keypoints[#Colors.Keypoints].Value
		}):Play()

		return
	end

	local gradient = Instance.new("UIGradient", instance)
	gradient.Offset = Vector2.new(-0.8, 0)
	gradient.Color = Colors

	TweenService:Create(gradient, TweenWrapper.Styles["Rainbow"], {
		Offset = Vector2.new(0.8, 0)
	}):Play()
end

--/ Watermark library
TweenWrapper:CreateStyle("wm", 0.24)
TweenWrapper:CreateStyle("wm_2", 0.04)

function library:Init(Config)
	Config = Config or {}
	--/ Apply new config
	for Key, Value in next, Config do
		library[Key] = Value
	end
	library:EnsureConfigFolder()
	local fallbackConfig = library:NormalizeConfigName(library.ConfigFile) or library.ConfigFile or "settings.json"
	local skipAutoload = library:ConsumeSkipAutoloadOnce()
	local autoloadConfig = (not skipAutoload) and library:GetAutoloadConfigName() or nil
	library.SelectedConfig = autoloadConfig or fallbackConfig
	library.ConfigFile = library.SelectedConfig
	library:LoadDefaultTheme()
	library.LoadedConfig = library:ReadConfig(library.ConfigFile) or {}
	library:StartAutoSave()

	local watermark = Instance.new("ScreenGui", CoreGui)
	watermark.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local watermarkPadding = Instance.new("UIPadding")
	watermarkPadding.Parent = watermark
	watermarkPadding.PaddingBottom = UDim.new(0, 6)
	watermarkPadding.PaddingLeft = UDim.new(0, 6)

	local watermarkLayout = Instance.new("UIListLayout")
	watermarkLayout.Parent = watermark
	watermarkLayout.FillDirection = Enum.FillDirection.Horizontal
	watermarkLayout.SortOrder = Enum.SortOrder.LayoutOrder
	watermarkLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	watermarkLayout.Padding = UDim.new(0, 4)

	function library:Watermark(text)
		local edge = Instance.new("Frame")
		local edgeCorner = Instance.new("UICorner")
		local background = Instance.new("Frame")
		local barFolder = Instance.new("Folder")
		local bar = Instance.new("Frame")
		local barCorner = Instance.new("UICorner")
		local barLayout = Instance.new("UIListLayout")
		local backgroundGradient = Instance.new("UIGradient")
		local backgroundCorner = Instance.new("UICorner")
		local waterText = Instance.new("TextLabel")
		local waterPadding = Instance.new("UIPadding")
		local backgroundLayout = Instance.new("UIListLayout")

		edge.Parent = watermark
		edge.AnchorPoint = Vector2.new(0.5, 0.5)
		edge.BackgroundColor3 = library.backgroundColor
		edge.Position = UDim2.new(0.5, 0, -0.03, 0)
		edge.Size = UDim2.new(0, 0, 0, 26)
		edge.BackgroundTransparency = 1

		edgeCorner.CornerRadius = UDim.new(0, 2)
		edgeCorner.Parent = edge

		background.Parent = edge
		background.AnchorPoint = Vector2.new(0.5, 0.5)
		background.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		background.BackgroundTransparency = 1
		background.ClipsDescendants = true
		background.Position = UDim2.new(0.5, 0, 0.5, 0)
		background.Size = UDim2.new(0, 0, 0, 24)

		barFolder.Parent = background

		bar.Parent = barFolder
		bar.BackgroundColor3 = library.acientColor
		bar.BackgroundTransparency = 0
		bar.Size = UDim2.new(0, 0, 0, 2)

		self:ApplyRainbow(bar, false)

		barCorner.CornerRadius = UDim.new(0, 2)
		barCorner.Parent = bar

		barLayout.Parent = barFolder
		barLayout.SortOrder = Enum.SortOrder.LayoutOrder

		backgroundGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
		backgroundGradient.Rotation = 90
		backgroundGradient.Parent = background

		backgroundCorner.CornerRadius = UDim.new(0, 2)
		backgroundCorner.Parent = background

		waterText.Parent = background
		waterText.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		waterText.BackgroundTransparency = 1.000
		waterText.Position = UDim2.new(0, 0, -0.0416666679, 0)
		waterText.Size = UDim2.new(0, 0, 0, 24)
		waterText.Font = library.Font
		waterText.Text = text
		waterText.TextColor3 = Color3.fromRGB(198, 198, 198)
		waterText.TextTransparency = 1
		waterText.TextSize = 14.000
		waterText.RichText = true

		local NewSize = TextService:GetTextSize(waterText.Text, waterText.TextSize, waterText.Font, Vector2.new(math.huge, math.huge))
		waterText.Size = UDim2.new(0, NewSize.X + 8, 0, 24)

		waterPadding.Parent = waterText
		waterPadding.PaddingBottom = UDim.new(0, 4)
		waterPadding.PaddingLeft = UDim.new(0, 4)
		waterPadding.PaddingRight = UDim.new(0, 4)
		waterPadding.PaddingTop = UDim.new(0, 4)

		backgroundLayout.Parent = background
		backgroundLayout.SortOrder = Enum.SortOrder.LayoutOrder
		backgroundLayout.VerticalAlignment = Enum.VerticalAlignment.Center

		coroutine.wrap(function()
			TweenService:Create(edge, TweenWrapper.Styles["wm"], {BackgroundTransparency = 0}):Play()
			TweenService:Create(edge, TweenWrapper.Styles["wm"], {Size = UDim2.new(0, NewSize.x + 10, 0, 26)}):Play()
			TweenService:Create(background, TweenWrapper.Styles["wm"], {BackgroundTransparency = 0}):Play()
			TweenService:Create(background, TweenWrapper.Styles["wm"], {Size = UDim2.new(0, NewSize.x + 8, 0, 24)}):Play()
			wait(.2)
			TweenService:Create(bar, TweenWrapper.Styles["wm"], {Size = UDim2.new(0, NewSize.x + 8, 0, 1)}):Play()
			wait(.1)
			TweenService:Create(waterText, TweenWrapper.Styles["wm"], {TextTransparency = 0}):Play()
		end)()

		local WatermarkFunctions = {}

		function WatermarkFunctions:Hide()
			edge.Visible = false
			return self
		end

		function WatermarkFunctions:Show()
			edge.Visible = true
			return self
		end

		function WatermarkFunctions:SetText(new)
			new = new or text
			waterText.Text = new

			local NewSize = TextService:GetTextSize(waterText.Text, waterText.TextSize, waterText.Font, Vector2.new(math.huge, math.huge))
			coroutine.wrap(function()
				TweenService:Create(edge, TweenWrapper.Styles["wm_2"], {Size = UDim2.new(0, NewSize.x + 10, 0, 26)}):Play()
				TweenService:Create(background, TweenWrapper.Styles["wm_2"], {Size = UDim2.new(0, NewSize.x + 8, 0, 24)}):Play()
				TweenService:Create(bar, TweenWrapper.Styles["wm_2"], {Size = UDim2.new(0, NewSize.x + 8, 0, 1)}):Play()
				TweenService:Create(waterText, TweenWrapper.Styles["wm_2"], {Size = UDim2.new(0, NewSize.x + 8, 0, 1)}):Play()
			end)()

			return self
		end

		function WatermarkFunctions:Remove()
			watermark:Destroy()
			return self
		end
		return WatermarkFunctions
	end


	-- InitNotifications

	local Notifications = Instance.new("ScreenGui", hiddenUI())
	local notificationsLayout = Instance.new("UIListLayout", Notifications)
	local notificationsPadding = Instance.new("UIPadding", Notifications)

	Notifications.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Notifications.Name = "CustomUINotifications"
	Notifications.ResetOnSpawn = false

	notificationsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	notificationsLayout.Padding = UDim.new(0, 6)
	notificationsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

	notificationsPadding.PaddingRight = UDim.new(0, 10)
	notificationsPadding.PaddingTop = UDim.new(0, 10)

	function library:Notify(text, duration, kind, callback, titleText)
		local messageText = text
		local notifyDuration = duration
		local notifyKind = kind
		local notifyCallback = callback
		local notifyTitle = titleText

		if type(messageText) == "table" then
			local payload = messageText
			messageText = payload.Text or payload.Description or payload.Message or ""
			notifyDuration = payload.Duration or payload.Time or notifyDuration
			notifyKind = payload.Type or payload.Kind or notifyKind
			notifyCallback = payload.Callback or notifyCallback
			notifyTitle = payload.Title or payload.Header or notifyTitle
		end

		messageText = tostring(messageText or "")
		notifyDuration = tonumber(notifyDuration) or 3
		notifyKind = tostring(notifyKind or "notification")
		notifyCallback = (type(notifyCallback) == "function") and notifyCallback or function() end
		notifyTitle = tostring(notifyTitle or library.company or "Notification")

		local accent = library.acientColor
		if notifyKind == "alert" then
			accent = Color3.fromRGB(255, 246, 112)
		elseif notifyKind == "error" then
			accent = Color3.fromRGB(255, 74, 77)
		elseif notifyKind == "success" then
			accent = Color3.fromRGB(255, 255, 255)
		end

		local titleSize = TextService:GetTextSize(notifyTitle, 13, library.Font, Vector2.new(360, math.huge))
		local messageSize = TextService:GetTextSize(messageText, 12, library.Font, Vector2.new(360, math.huge))
		local hasMessage = messageText ~= ""
		local width = math.clamp(math.max(titleSize.X, messageSize.X) + 26, 170, 380)
		local height = hasMessage and 42 or 28

		local card = Instance.new("Frame")
		card.Parent = Notifications
		card.BackgroundColor3 = library.darkGray
		card.BackgroundTransparency = 1
		card.Size = UDim2.new(0, 0, 0, 0)
		card.BorderSizePixel = 0

		local corner = Instance.new("UICorner")
		corner.Parent = card
		corner.CornerRadius = UDim.new(0, 3)

		local stroke = Instance.new("UIStroke")
		stroke.Parent = card
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = 1
		stroke.Color = library.lightGray
		stroke.Transparency = 1

		local accentBar = Instance.new("Frame")
		accentBar.Parent = card
		accentBar.BorderSizePixel = 0
		accentBar.BackgroundColor3 = accent
		accentBar.BackgroundTransparency = 1
		accentBar.Size = UDim2.new(0, 2, 1, 0)

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Parent = card
		titleLabel.BackgroundTransparency = 1
		titleLabel.Position = UDim2.new(0, 8, 0, 4)
		titleLabel.Size = UDim2.new(1, -12, 0, 14)
		titleLabel.Font = library.Font
		titleLabel.Text = notifyTitle
		titleLabel.TextColor3 = library.headerColor
		titleLabel.TextSize = 13
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.TextTransparency = 1
		titleLabel.TextTruncate = Enum.TextTruncate.AtEnd

		local messageLabel = Instance.new("TextLabel")
		messageLabel.Parent = card
		messageLabel.BackgroundTransparency = 1
		messageLabel.Position = UDim2.new(0, 8, 0, hasMessage and 20 or 16)
		messageLabel.Size = UDim2.new(1, -12, 0, 16)
		messageLabel.Font = library.Font
		messageLabel.Text = messageText
		messageLabel.TextColor3 = Color3.fromRGB(168, 168, 168)
		messageLabel.TextSize = 12
		messageLabel.TextXAlignment = Enum.TextXAlignment.Left
		messageLabel.TextTransparency = 1
		messageLabel.TextTruncate = Enum.TextTruncate.AtEnd
		messageLabel.Visible = hasMessage

		local progress = Instance.new("Frame")
		progress.Parent = card
		progress.BorderSizePixel = 0
		progress.AnchorPoint = Vector2.new(0, 1)
		progress.Position = UDim2.new(0, 0, 1, 0)
		progress.Size = UDim2.new(1, 0, 0, 1)
		progress.BackgroundColor3 = accent
		progress.BackgroundTransparency = 1

		local alive = true
		local NotificationFunctions = {}

		function NotificationFunctions:SetText(newText)
			if not alive then
				return self
			end
			messageText = tostring(newText or "")
			local msgSz = TextService:GetTextSize(messageText, 12, library.Font, Vector2.new(360, math.huge))
			local ttlSz = TextService:GetTextSize(notifyTitle, 13, library.Font, Vector2.new(360, math.huge))
			hasMessage = messageText ~= ""
			width = math.clamp(math.max(ttlSz.X, msgSz.X) + 26, 170, 380)
			height = hasMessage and 42 or 28
			messageLabel.Text = messageText
			messageLabel.Visible = hasMessage
			messageLabel.Position = UDim2.new(0, 8, 0, hasMessage and 20 or 16)
			TweenService:Create(card, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, width, 0, height),
			}):Play()
			return self
		end

		function NotificationFunctions:SetTitle(newTitle)
			if not alive then
				return self
			end
			notifyTitle = tostring(newTitle or notifyTitle)
			titleLabel.Text = notifyTitle
			local msgSz = TextService:GetTextSize(messageText, 12, library.Font, Vector2.new(360, math.huge))
			local ttlSz = TextService:GetTextSize(notifyTitle, 13, library.Font, Vector2.new(360, math.huge))
			width = math.clamp(math.max(ttlSz.X, msgSz.X) + 26, 170, 380)
			TweenService:Create(card, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, width, 0, height),
			}):Play()
			return self
		end

		task.spawn(function()
			TweenService:Create(card, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, width, 0, height),
				BackgroundTransparency = 0.06,
			}):Play()
			TweenService:Create(stroke, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 0.32,
			}):Play()
			TweenService:Create(accentBar, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0,
			}):Play()
			TweenService:Create(progress, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0.12,
			}):Play()
			TweenService:Create(titleLabel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 0,
			}):Play()
			if hasMessage then
				TweenService:Create(messageLabel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextTransparency = 0,
				}):Play()
			end

			local barTween = TweenService:Create(progress, TweenInfo.new(notifyDuration, Enum.EasingStyle.Linear), {
				Size = UDim2.new(0, 0, 0, 1),
			})
			barTween:Play()
			barTween.Completed:Wait()
			if not alive then
				return
			end
			alive = false

			TweenService:Create(titleLabel, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 1,
			}):Play()
			TweenService:Create(messageLabel, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 1,
			}):Play()
			TweenService:Create(accentBar, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}):Play()
			TweenService:Create(progress, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}):Play()
			TweenService:Create(stroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1,
			}):Play()
			TweenService:Create(card, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 1,
			}):Play()
			task.wait(0.14)
			pcall(function()
				card:Destroy()
			end)
			pcall(notifyCallback)
		end)

		return NotificationFunctions
	end

	-- Introduction

	local introduction = Instance.new("ScreenGui", CoreGui)
	local background = Instance.new("Frame")
	local Logo = Instance.new("TextLabel")
	local backgroundGradient_2 = Instance.new("UIGradient")
	local bar = Instance.new("Frame")
	local barCorner = Instance.new("UICorner")
	local messages = Instance.new("Frame")
	local LogExample = Instance.new("TextLabel")
	local backgroundGradient_3 = Instance.new("UIGradient")
	local pageLayout = Instance.new("UIListLayout")

	introduction.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	background.Parent = introduction
	background.BackgroundTransparency = 1
	background.AnchorPoint = Vector2.new(0.5, 0.5)
	background.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	background.ClipsDescendants = true
	background.Position = UDim2.new(0.511773348, 0, 0.5, 0)
	background.Size = UDim2.new(0, 300, 0, 308)

	--/ Style
	local IntroStroke = Instance.new("UIStroke", background)
	IntroStroke.Color = Color3.fromRGB(26, 26, 26)
	IntroStroke.Thickness = 2
	IntroStroke.Transparency = 1

	local backgroundGradient = Instance.new("UIGradient", background)
	backgroundGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	backgroundGradient.Rotation = 90

	local backgroundCorner = Instance.new("UICorner", background)
	backgroundCorner.CornerRadius = UDim.new(0, 3)

	Logo.Parent = background
	Logo.AnchorPoint = Vector2.new(0.5, 0.5)
	Logo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Logo.BackgroundTransparency = 1.000
	Logo.TextTransparency = 1
	Logo.BorderColor3 = Color3.fromRGB(0, 0, 0)
	Logo.BorderSizePixel = 0
	Logo.Position = UDim2.new(0.5, 0, 0.5, 0)
	Logo.Size = UDim2.new(0, 448, 0, 150)
	Logo.Font = Enum.Font.Unknown
	Logo.FontFace.Weight = Enum.FontWeight.Bold
	Logo.Font = Enum.Font.FredokaOne
	Logo.TextColor3 = library.acientColor
	Logo.TextSize = 100.000

	backgroundGradient_2.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(171, 171, 171))}
	backgroundGradient_2.Rotation = 90
	backgroundGradient_2.Parent = Logo

	bar.Parent = background
	bar.BackgroundColor3 = library.lightGray
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, 0, 0, 2)

	barCorner.CornerRadius = UDim.new(0, 2)
	barCorner.Parent = bar

	messages.Parent = background
	messages.AnchorPoint = Vector2.new(0.5, 0.5)
	messages.BackgroundColor3 = Color3.fromRGB(9, 9, 9)
	messages.BackgroundTransparency = 1
	messages.BorderColor3 = Color3.fromRGB(0, 0, 0)
	messages.BorderSizePixel = 1
	messages.Position = UDim2.new(0.5, 0, 0.5, 0)
	messages.Size = UDim2.new(1, -30, 1, -30)

	local messagesUIPadding = Instance.new("UIPadding", messages)
	messagesUIPadding.PaddingLeft = UDim.new(0, 6)
	messagesUIPadding.PaddingTop = UDim.new(0, 3)

	local messagesUIListLayout = Instance.new("UIListLayout", messages)
	messagesUIListLayout.Parent = messages
	messagesUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	messagesUIListLayout.FillDirection = Enum.FillDirection.Vertical
	messagesUIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	messagesUIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top

	LogExample.Parent = messages
	LogExample.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	LogExample.BackgroundTransparency = 1.000
	LogExample.BorderColor3 = Color3.fromRGB(0, 0, 0)
	LogExample.BorderSizePixel = 0
	LogExample.Size = UDim2.new(1, 0, 0, 18)
	LogExample.Visible = false
	LogExample.Font = library.Font
	LogExample.TextColor3 = Color3.fromRGB(255, 255, 255)
	LogExample.TextSize = 18.000
	LogExample.TextTransparency = 1
	LogExample.TextWrapped = true
	LogExample.TextXAlignment = Enum.TextXAlignment.Left
	LogExample.TextYAlignment = Enum.TextYAlignment.Top

	backgroundGradient_3.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(171, 171, 171))}
	backgroundGradient_3.Rotation = 90
	backgroundGradient_3.Parent = LogExample

	pageLayout.Parent = introduction
	pageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pageLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	TweenWrapper:CreateStyle("introduction",0.175)
	TweenWrapper:CreateStyle("introduction end",0.5)

	function library:BeginIntroduction()
		Logo.Text = library.company:sub(1, 1):upper()

		--TweenService:Create(edge, TweenWrapper.Styles["introduction"], {BackgroundTransparency = 0}):Play()
		TweenService:Create(background, TweenWrapper.Styles["introduction"], {BackgroundTransparency = 0}):Play()
		wait(.2)
		TweenService:Create(IntroStroke, TweenWrapper.Styles["introduction end"], {Transparency = 0.55}):Play()
		TweenService:Create(bar, TweenWrapper.Styles["introduction"], {BackgroundTransparency = 0.2}):Play()
		wait(.3)
		TweenService:Create(Logo, TweenWrapper.Styles["introduction"], {TextTransparency = 0}):Play()

		wait(2)

		local LogoTween = TweenService:Create(Logo, TweenWrapper.Styles["introduction"], {TextTransparency = 1})
		TweenService:Create(Logo, TweenInfo.new(1), {TextSize = 0}):Play()
		LogoTween:Play()
		LogoTween.Completed:Wait()
	end

	function library:AddIntroductionMessage(Message)
		if messages.BackgroundTransparency >= 1 then
			TweenService:Create(messages, TweenInfo.new(.2), {BackgroundTransparency = 0.55}):Play()
		end

		local Log = LogExample:Clone()
		local OrginalSize = Log.TextSize
		Log.Parent = messages
		Log.Text = Message
		Log.TextTransparency = 1
		Log.TextSize = OrginalSize*0.9
		Log.Visible = true
		TweenService:Create(Log, TweenInfo.new(1), {TextTransparency = 0}):Play()
		TweenService:Create(Log, TweenInfo.new(.7), {TextSize = OrginalSize}):Play()
		wait(.1)
		return Log
	end

	function library:EndIntroduction(Message)
		for _, Message in next, messages:GetChildren() do
			pcall(function()
				TweenService:Create(Message, TweenWrapper.Styles["introduction end"], {TextTransparency = 1}):Play()
			end)
		end
		wait(0.2)

		TweenService:Create(messages, TweenWrapper.Styles["introduction end"], {BackgroundTransparency = 1}):Play()
		--TweenService:Create(edge, TweenWrapper.Styles["introduction end"], {BackgroundTransparency = 1}):Play()
		TweenService:Create(background, TweenWrapper.Styles["introduction end"], {BackgroundTransparency = 1}):Play()
		TweenService:Create(bar, TweenWrapper.Styles["introduction end"], {BackgroundTransparency = 1}):Play()
		TweenService:Create(Logo, TweenWrapper.Styles["introduction end"], {TextTransparency = 1}):Play()
		TweenService:Create(IntroStroke, TweenWrapper.Styles["introduction end"], {Transparency = 1}):Play()
	end

	----/// UI INIT
	local screen = Instance.new("ScreenGui", hiddenUI())
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local background = Instance.new("Frame", screen)
	background.Visible = false
	background.BorderSizePixel = 0
	background.AnchorPoint = Vector2.new(0.5, 0.5)
	background.BackgroundTransparency = library.transparency
	background.BackgroundColor3 = library.backgroundColor
	background.Position = UDim2.new(0.5, 0, 0.5, 0)
	--background.Size = UDim2.fromScale(0.5, 0.5)
	background.Size = UDim2.fromOffset(684, 540)
	background.ClipsDescendants = true
	EnableDrag(background, 0.1)
	
	local SizeConstraint = Instance.new("UISizeConstraint")
	SizeConstraint.Parent = background
	SizeConstraint.MaxSize = Vector2.new(684, 540)
	SizeConstraint.MinSize = Vector2.new(520, 390)

	--/ Style
	local BGStroke = Instance.new("UIStroke", background)
	BGStroke.Color = Color3.fromRGB(26, 26, 26)
	BGStroke.Thickness = 2
	BGStroke.Transparency = 0.55

	local BGGradient = Instance.new("UIGradient", background)
	BGGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(230, 230, 230))}
	BGGradient.Rotation = 90

	--/ Tabs
	local tabButtons = Instance.new("Frame", background)
	tabButtons.BackgroundTransparency = 1
	tabButtons.ClipsDescendants = true
	tabButtons.Position = UDim2.new(0, 10, 0, 35)
	tabButtons.Size = UDim2.new(0, 152, 0, 464)

	local tabButtonLayout = Instance.new("UIListLayout", tabButtons)
	tabButtonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabButtonLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local tabButtonPadding = Instance.new("UIPadding", tabButtons)
	tabButtonPadding.PaddingBottom = UDim.new(0, 4)
	tabButtonPadding.PaddingLeft = UDim.new(0, 4)
	tabButtonPadding.PaddingRight = UDim.new(0, 4)
	tabButtonPadding.PaddingTop = UDim.new(0, 4)

	local tabButtonCorner_2 = Instance.new("UICorner", tabButtons)
	tabButtonCorner_2.CornerRadius = UDim.new(0, 2)

	--/ Header
	local container = Instance.new("Frame", background)
	container.AnchorPoint = Vector2.new(1, 0)
	container.BackgroundTransparency = 1
	container.Position = UDim2.new(1, -10, 0, 35)
	container.Size = UDim2.new(0, 504, 0, 494)

	local header = Instance.new("Frame", background)
	header.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	header.BackgroundTransparency = 1.000
	header.BorderColor3 = Color3.fromRGB(0, 0, 0)
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, 0, 0, 32)

	local company = Instance.new("TextLabel", header)
	company.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	company.BackgroundTransparency = 1.000
	company.LayoutOrder = 1
	company.AutomaticSize = Enum.AutomaticSize.X
	company.Size = UDim2.new(0, 0, 1, 0)
	company.Font = library.Font
	company.TextColor3 = library.companyColor
	company.TextSize = 16.000
	company.TextTransparency = 0.300
 company.RichText = true
	company.TextXAlignment = Enum.TextXAlignment.Left

	function library:SetCompany(text)
		library.company = text
		company.Text = ("%s: "):format(text) or ""
		return self
	end
	library:SetCompany(library.company)

	local headerLabel = Instance.new("TextLabel", header)
	headerLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	headerLabel.BackgroundTransparency = 1.000
	headerLabel.LayoutOrder = 2
	headerLabel.Size = UDim2.new(1, 0, 1, 0)
	headerLabel.Font = library.Font
	headerLabel.Text = library.title
 headerLabel.RichText = true
	headerLabel.TextColor3 = Color3.fromRGB(198, 198, 198)
	headerLabel.TextSize = 16.000
	headerLabel.TextXAlignment = Enum.TextXAlignment.Left

	function library:SetTitle(text)
		headerLabel.Text = text or ""
		return self
	end

	local UIListLayout = Instance.new("UIListLayout", header)
	UIListLayout.FillDirection = Enum.FillDirection.Horizontal
	UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	UIListLayout.Padding = UDim.new(0, 5)

	local UIPadding = Instance.new("UIPadding", header)
	UIPadding.PaddingLeft = UDim.new(0, 10)

	--/ Bars
	local barFolder = Instance.new("Folder", background)

	local bar = Instance.new("Frame", barFolder)
	bar.BackgroundColor3 = library.lightGray
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, 0, 0, 2)
	bar.BorderSizePixel = 0

	local barCorner = Instance.new("UICorner", bar)
	barCorner.CornerRadius = UDim.new(0, 2)

	local barLayout = Instance.new("UIListLayout", barFolder)
	barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	barLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local tabButtonsOutline = Instance.new("UIStroke", tabButtons)
	tabButtonsOutline.Thickness = 1
	tabButtonsOutline.Color = library.lightGray

	local tabButtonsGradient = Instance.new("UIGradient", tabButtons)
	tabButtonsGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	tabButtonsGradient.Rotation = 90

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 2)
	containerCorner.Parent = container

	local tabButtonsOutline = Instance.new("UIStroke", container)
	tabButtonsOutline.Thickness = 1
	tabButtonsOutline.Color = library.lightGray

	local panic = Instance.new("TextButton", background)
	panic.Text = "User: " .. tostring(Player.Name)
	panic.AnchorPoint = Vector2.new(0, 1)
	panic.BackgroundTransparency = library.transparency
	panic.BackgroundColor3 = library.darkGray
	panic.Position = UDim2.new(0, 10, 1, -10)
	panic.Size = UDim2.new(0, 152, 0, 24)
	panic.Font = library.Font
	panic.TextColor3 = Color3.fromRGB(190, 190, 190)
	panic.TextSize = 14.000
	panic.Activated:Connect(function() end)

	local buttonCorner = Instance.new("UICorner", panic)
	buttonCorner.CornerRadius = UDim.new(0, 2)

	local panicOutline = Instance.new("UIStroke", panic)
	panicOutline.Thickness = 1
	panicOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	panicOutline.Color = library.lightGray

	library.UIRefs = {
		Screen = screen,
		Background = background,
		TabButtons = tabButtons,
		Container = container,
		Company = company,
		HeaderLabel = headerLabel,
		PanicButton = panic,
	}

	local targetHudSessions = {}

	local function trimString(value)
		return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
	end

	local function findPlayerByNameInsensitive(playerName)
		local wanted = string.lower(trimString(playerName))
		if wanted == "" then
			return nil
		end
		for _, plr in ipairs(Services.Players:GetPlayers()) do
			if string.lower(plr.Name) == wanted or string.lower(plr.DisplayName) == wanted then
				return plr
			end
		end
		return nil
	end

	local function resolveInstancePath(pathText)
		local trimmed = trimString(pathText)
		if trimmed == "" then
			return nil
		end

		local parts = {}
		for token in string.gmatch(trimmed, "[^%.]+") do
			table.insert(parts, token)
		end
		if #parts <= 0 then
			return nil
		end

		local current = nil
		local first = string.lower(parts[1])
		if first == "game" then
			current = game
			table.remove(parts, 1)
		elseif first == "workspace" then
			current = Workspace
			table.remove(parts, 1)
		elseif first == "players" then
			current = Services.Players
			table.remove(parts, 1)
		elseif first == "replicatedstorage" then
			current = Services.ReplicatedStorage
			table.remove(parts, 1)
		elseif first == "lighting" then
			current = Services.Lighting
			table.remove(parts, 1)
		else
			current = Workspace
		end

		for _, segment in ipairs(parts) do
			if current == game then
				local okService, serviceInst = pcall(function()
					return game:GetService(segment)
				end)
				if okService and serviceInst then
					current = serviceInst
				else
					current = FindFirstChildInsensitive(current, segment)
				end
			else
				current = FindFirstChildInsensitive(current, segment)
			end
			if not current then
				return nil
			end
		end
		return current
	end

	local function getHumanoidFromModel(model)
		if not model or not model.Parent then
			return nil
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid
		end
		local deepHumanoid = model:FindFirstChild("Humanoid", true)
		if deepHumanoid and deepHumanoid:IsA("Humanoid") then
			return deepHumanoid
		end
		return nil
	end

	local function getHeadPartFromModel(model)
		if not model or not model.Parent then
			return nil
		end
		local head = model:FindFirstChild("Head") or model:FindFirstChild("Head", true)
		if head and head:IsA("BasePart") then
			return head
		end
		local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("HumanoidRootPart", true)
		if hrp and hrp:IsA("BasePart") then
			return hrp
		end
		return model:FindFirstChildWhichIsA("BasePart", true)
	end

	local function resolveModelFromInstance(inst)
		if not inst then
			return nil, nil
		end
		if inst:IsA("Player") then
			return inst.Character, inst
		end
		if inst:IsA("Model") then
			return inst, nil
		end
		if inst:IsA("Humanoid") then
			return inst.Parent, nil
		end
		if inst:IsA("BasePart") then
			return inst:FindFirstAncestorOfClass("Model") or inst.Parent, nil
		end
		local asModel = inst:FindFirstAncestorOfClass("Model")
		if asModel then
			return asModel, nil
		end
		return nil, nil
	end

	function library:TargetHUD(config)
		config = type(config) == "table" and config or {}
		local titleText = tostring(config.Title or config.title or "Target HUD")
		local parentRef = config.Parent
		if typeof(parentRef) ~= "Instance" or (not parentRef:IsA("LayerCollector")) then
			parentRef = screen
		end

		local sizeValue = (typeof(config.Size) == "UDim2" and config.Size) or UDim2.fromOffset(320, 146)
		local positionValue = (typeof(config.Position) == "UDim2" and config.Position)
			or UDim2.new(0.5, -(sizeValue.X.Offset // 2), 0.72, 0)
		local targetPlayerName = tostring(config.PlayerName or config.Player or config.player or "")
		local targetNpcPath = tostring(config.NPCPath or config.Path or config.NpcPath or config.path or "")

		local hudGui = Instance.new("ScreenGui")
		hudGui.Name = "TargetHUD"
		hudGui.ResetOnSpawn = false
		hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		hudGui.Parent = parentRef

		local root = Instance.new("Frame")
		root.Name = "TargetHUDRoot"
		root.Parent = hudGui
		root.Active = true
		root.BackgroundColor3 = library.darkGray
		root.BackgroundTransparency = 0.06
		root.BorderSizePixel = 0
		root.Position = positionValue
		root.Size = sizeValue
		root.ClipsDescendants = true
		Instance.new("UICorner", root).CornerRadius = UDim.new(0, 3)
		local rootStroke = Instance.new("UIStroke", root)
		rootStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rootStroke.Thickness = 1
		rootStroke.Color = library.lightGray
		rootStroke.Transparency = 0.35
		EnableDrag(root, 0.08)

		local title = Instance.new("TextLabel")
		title.Parent = root
		title.BackgroundTransparency = 1
		title.Position = UDim2.new(0, 8, 0, 4)
		title.Size = UDim2.new(1, -34, 0, 18)
		title.Font = library.Font
		title.TextSize = 13
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.fromRGB(205, 205, 205)
		title.Text = titleText

		local closeButton = Instance.new("TextButton")
		closeButton.Parent = root
		closeButton.AnchorPoint = Vector2.new(1, 0)
		closeButton.Position = UDim2.new(1, -6, 0, 4)
		closeButton.Size = UDim2.new(0, 20, 0, 18)
		closeButton.BackgroundColor3 = library.darkGray
		closeButton.BackgroundTransparency = 1
		closeButton.BorderSizePixel = 0
		closeButton.Font = library.Font
		closeButton.Text = "x"
		closeButton.TextSize = 12
		closeButton.TextColor3 = Color3.fromRGB(200, 200, 200)
		closeButton.AutoButtonColor = false

		local viewport = Instance.new("ViewportFrame")
		viewport.Parent = root
		viewport.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		viewport.BorderSizePixel = 0
		viewport.Position = UDim2.new(0, 8, 0, 28)
		viewport.Size = UDim2.new(0, 90, 0, 108)
		viewport.Ambient = Color3.fromRGB(180, 180, 180)
		viewport.LightColor = Color3.fromRGB(255, 255, 255)
		viewport.LightDirection = Vector3.new(-1, -1, -1)
		Instance.new("UICorner", viewport).CornerRadius = UDim.new(0, 2)
		local viewportWorld = Instance.new("WorldModel")
		viewportWorld.Parent = viewport
		local viewportCamera = Instance.new("Camera")
		viewportCamera.Parent = viewport
		viewport.CurrentCamera = viewportCamera

		local hpBarBg = Instance.new("Frame")
		hpBarBg.Parent = root
		hpBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		hpBarBg.BorderSizePixel = 0
		hpBarBg.Position = UDim2.new(0, 102, 0, 28)
		hpBarBg.Size = UDim2.new(0, 8, 0, 108)
		Instance.new("UICorner", hpBarBg).CornerRadius = UDim.new(0, 2)

		local hpFill = Instance.new("Frame")
		hpFill.Parent = hpBarBg
		hpFill.AnchorPoint = Vector2.new(0, 1)
		hpFill.Position = UDim2.new(0, 0, 1, 0)
		hpFill.Size = UDim2.new(1, 0, 0, 0)
		hpFill.BackgroundColor3 = Color3.fromRGB(255, 74, 74)
		hpFill.BorderSizePixel = 0
		Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 2)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Parent = root
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.new(0, 116, 0, 36)
		nameLabel.Size = UDim2.new(1, -124, 0, 22)
		nameLabel.Font = library.Font
		nameLabel.TextSize = 15
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextColor3 = Color3.fromRGB(225, 225, 225)
		nameLabel.Text = "No target"
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

		local hpLabel = Instance.new("TextLabel")
		hpLabel.Parent = root
		hpLabel.BackgroundTransparency = 1
		hpLabel.Position = UDim2.new(0, 116, 0, 62)
		hpLabel.Size = UDim2.new(1, -124, 0, 18)
		hpLabel.Font = library.Font
		hpLabel.TextSize = 13
		hpLabel.TextXAlignment = Enum.TextXAlignment.Left
		hpLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		hpLabel.Text = "HP: -- / --"
		hpLabel.TextTruncate = Enum.TextTruncate.AtEnd

		local statusLabel = Instance.new("TextLabel")
		statusLabel.Parent = root
		statusLabel.BackgroundTransparency = 1
		statusLabel.Position = UDim2.new(0, 116, 0, 82)
		statusLabel.Size = UDim2.new(1, -124, 0, 50)
		statusLabel.Font = library.Font
		statusLabel.TextSize = 12
		statusLabel.TextXAlignment = Enum.TextXAlignment.Left
		statusLabel.TextYAlignment = Enum.TextYAlignment.Top
		statusLabel.TextColor3 = Color3.fromRGB(155, 155, 155)
		statusLabel.Text = ""
		statusLabel.TextWrapped = true
		statusLabel.Visible = false

		local currentModel = nil
		local currentHumanoid = nil
		local currentPlayer = nil
		local previewModelSource = nil
		local resolveSignature = ""
		local resolvePollAt = 0
		local updateConnection = nil
		local destroyed = false

		local function clearViewport()
			for _, inst in ipairs(viewportWorld:GetChildren()) do
				inst:Destroy()
			end
			previewModelSource = nil
		end

		local function applyModelPreview(modelSource)
			if previewModelSource == modelSource then
				return
			end
			clearViewport()
			if not (modelSource and modelSource.Parent and modelSource:IsA("Model")) then
				return
			end

			local clone = nil
			local oldArchivable = modelSource.Archivable
			local okClone = pcall(function()
				if modelSource.Archivable == false then
					modelSource.Archivable = true
				end
				clone = modelSource:Clone()
			end)
			pcall(function()
				modelSource.Archivable = oldArchivable
			end)

			if (not okClone) or (not clone) or (not clone:IsA("Model")) then
				if clone and clone.Parent then
					clone:Destroy()
				end
				return
			end

			for _, inst in ipairs(clone:GetDescendants()) do
				if inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
					inst:Destroy()
				elseif inst:IsA("BasePart") then
					inst.Anchored = true
					inst.CanCollide = false
					inst.CastShadow = false
				end
			end

			clone.Parent = viewportWorld
			previewModelSource = modelSource

			local okPivot, pivot = pcall(function()
				return clone:GetPivot()
			end)
			if okPivot and typeof(pivot) == "CFrame" then
				local pivotPosition = pivot.Position
				local rootPart = clone:FindFirstChild("HumanoidRootPart", true)
				if not (rootPart and rootPart:IsA("BasePart")) then
					rootPart = clone.PrimaryPart
				end

				local alignYaw = CFrame.new()
				if rootPart and rootPart:IsA("BasePart") then
					local look = rootPart.CFrame.LookVector
					local flatLook = Vector3.new(look.X, 0, look.Z)
					if flatLook.Magnitude > 0.001 then
						alignYaw = CFrame.lookAt(Vector3.zero, flatLook.Unit)
					end
				end

				for _, inst in ipairs(clone:GetDescendants()) do
					if inst:IsA("BasePart") then
						local shifted = inst.CFrame - pivotPosition
						inst.CFrame = alignYaw:Inverse() * shifted
					end
				end
			end

			local boundCF = CFrame.new()
			local boundSize = Vector3.new(4, 6, 4)
			local okBounds, resolvedCF, resolvedSize = pcall(function()
				return clone:GetBoundingBox()
			end)
			if okBounds and typeof(resolvedCF) == "CFrame" and typeof(resolvedSize) == "Vector3" then
				boundCF = resolvedCF
				boundSize = resolvedSize
			end

			local maxDimension = math.max(boundSize.X, boundSize.Y, boundSize.Z)
			local focus = boundCF.Position + Vector3.new(0, math.clamp(boundSize.Y * 0.1, 0.5, 3), 0)
			local distance = math.clamp(maxDimension * 1.85, 6, 24) * 0.45
			local cameraHeight = math.clamp(boundSize.Y * 0.18, 0.8, 4.2)
			local frontDirection = Vector3.new(0, 0, 1)
			local previewRoot = clone:FindFirstChild("HumanoidRootPart", true)
			if not (previewRoot and previewRoot:IsA("BasePart")) then
				previewRoot = clone.PrimaryPart
			end
			if previewRoot and previewRoot:IsA("BasePart") then
				local look = previewRoot.CFrame.LookVector
				local flatLook = Vector3.new(look.X, 0, look.Z)
				if flatLook.Magnitude > 0.001 then
					frontDirection = flatLook.Unit
				end
			end
			viewportCamera.CFrame = CFrame.new(
				focus + Vector3.new(0, cameraHeight, 0) + (frontDirection * distance),
				focus
			)
		end

		local function updateHealthView()
			if not (currentHumanoid and currentHumanoid.Parent) then
				hpFill.Size = UDim2.new(1, 0, 0, 0)
				hpFill.BackgroundColor3 = Color3.fromRGB(255, 74, 74)
				hpLabel.Text = "HP: -- / --"
				return
			end
			local maxHealth = math.max(tonumber(currentHumanoid.MaxHealth) or 0, 1)
			local health = math.clamp(tonumber(currentHumanoid.Health) or 0, 0, maxHealth)
			local ratio = health / maxHealth
			hpFill.Size = UDim2.new(1, 0, ratio, 0)
			if ratio > 0.65 then
				hpFill.BackgroundColor3 = Color3.fromRGB(90, 220, 110)
			elseif ratio > 0.35 then
				hpFill.BackgroundColor3 = Color3.fromRGB(255, 190, 80)
			else
				hpFill.BackgroundColor3 = Color3.fromRGB(255, 74, 74)
			end
			hpLabel.Text = string.format("HP: %d / %d", math.floor(health + 0.5), math.floor(maxHealth + 0.5))
		end

		local function resolveTargetModel()
			local playerName = trimString(targetPlayerName)
			local npcPath = trimString(targetNpcPath)

			local playerResult = nil
			if playerName ~= "" then
				playerResult = findPlayerByNameInsensitive(playerName)
				if playerResult then
					if playerResult.Character then
						return playerResult.Character, playerResult, "player"
					end
					return nil, playerResult, "player_wait"
				end
			end

			if npcPath ~= "" then
				local inst = resolveInstancePath(npcPath)
				local model, pathPlayer = resolveModelFromInstance(inst)
				if model or pathPlayer then
					return model, pathPlayer, "path"
				end
			end

			if playerResult then
				return nil, playerResult, "player_wait"
			end
			return nil, nil, "none"
		end

		local function refreshResolvedTarget(forceResolve)
			local now = os.clock()
			local signature = trimString(targetPlayerName) .. "|" .. trimString(targetNpcPath)
			local needsResolve = forceResolve == true
				or signature ~= resolveSignature
				or (not currentModel)
				or (currentModel and not currentModel.Parent)
				or now >= resolvePollAt

			if needsResolve then
				resolveSignature = signature
				resolvePollAt = now + 0.25
				currentModel, currentPlayer = nil, nil
				local model, playerRef = resolveTargetModel()
				currentModel = model
				currentPlayer = playerRef
				currentHumanoid = getHumanoidFromModel(currentModel)

				if currentModel then
					local ownerPlayer = currentPlayer or Services.Players:GetPlayerFromCharacter(currentModel)
					local displayName = ownerPlayer and ownerPlayer.Name or tostring(currentModel.Name)
					nameLabel.Text = tostring(displayName)
					if ownerPlayer then
						statusLabel.Visible = false
						statusLabel.Text = ""
					else
						local targetText = trimString(targetNpcPath)
						if targetText == "" then
							targetText = tostring(currentModel.Name)
						end
						statusLabel.Text = "Target: " .. targetText
						statusLabel.Visible = true
					end
				elseif currentPlayer then
					nameLabel.Text = tostring(currentPlayer.Name)
					statusLabel.Visible = false
					statusLabel.Text = ""
				else
					nameLabel.Text = "No target"
					statusLabel.Visible = false
					statusLabel.Text = ""
					clearViewport()
				end
			end

			if currentModel and currentModel.Parent then
				currentHumanoid = getHumanoidFromModel(currentModel)
				applyModelPreview(currentModel)
			else
				clearViewport()
			end
			updateHealthView()
		end

		local function destroyHudSession()
			if destroyed then
				return
			end
			destroyed = true
			if updateConnection then
				updateConnection:Disconnect()
				updateConnection = nil
			end
			clearViewport()
			targetHudSessions[hudGui] = nil
			if hudGui and hudGui.Parent then
				hudGui:Destroy()
			end
		end

		closeButton.Activated:Connect(function()
			destroyHudSession()
		end)

		updateConnection = RunService.Heartbeat:Connect(function()
			if destroyed then
				return
			end
			refreshResolvedTarget(false)
		end)
		targetHudSessions[hudGui] = destroyHudSession
		refreshResolvedTarget(true)

		local TargetHudFunctions = {}
		function TargetHudFunctions:SetPlayerName(playerName)
			targetPlayerName = tostring(playerName or "")
			refreshResolvedTarget(true)
			return self
		end
		function TargetHudFunctions:SetNPCPath(pathText)
			targetNpcPath = tostring(pathText or "")
			refreshResolvedTarget(true)
			return self
		end
		function TargetHudFunctions:SetTarget(playerName, pathText)
			targetPlayerName = tostring(playerName or "")
			targetNpcPath = tostring(pathText or "")
			refreshResolvedTarget(true)
			return self
		end
		TargetHudFunctions.SetTargetPlayer = TargetHudFunctions.SetPlayerName
		TargetHudFunctions.SetTargetPath = TargetHudFunctions.SetNPCPath
		function TargetHudFunctions:SetVisible(isVisible)
			root.Visible = isVisible == true
			return self
		end
		function TargetHudFunctions:GetPlayerName()
			return targetPlayerName
		end
		function TargetHudFunctions:GetNPCPath()
			return targetNpcPath
		end
		function TargetHudFunctions:GetTarget()
			return currentModel
		end
		function TargetHudFunctions:GetTargetHumanoid()
			return currentHumanoid
		end
		function TargetHudFunctions:Destroy()
			destroyHudSession()
			return self
		end
		TargetHudFunctions.Remove = TargetHudFunctions.Destroy
		return TargetHudFunctions
	end

	function library:CreateTargetHUD(config)
		return library:TargetHUD(config)
	end

	--delay(1, function()
	--	library:Notify("Keybind set to ".. library.Key.Name, 20, "success")
	--end)

	UserInputService.InputBegan:Connect(function(input) -- Toggle UI
		if input.KeyCode ~= library.Key then return end

		local Visible = not background.Visible
		library:ShowUI(Visible)
	end)

	function library:ShowUI(Visible: boolean)
		background.Visible = Visible

		return self
	end

	local TabLibrary = {
		IsFirst = true,
		CurrentTab = ""
	}
	TweenWrapper:CreateStyle("tab_text_colour", 0.16)
	function library:NewTab(title)
		title = title or "tab"

		local tabButton = Instance.new("TextButton")
		local page = Instance.new("ScrollingFrame")
		local pageLayout = Instance.new("UIListLayout")
		local pagePadding = Instance.new("UIPadding")

		tabButton.Parent = tabButtons
		tabButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		tabButton.BackgroundTransparency = 1.000
		tabButton.ClipsDescendants = true
		tabButton.Position = UDim2.new(-0.0281690136, 0, 0, 0)
		tabButton.Size = UDim2.new(0, 150, 0, 22)
		tabButton.AutoButtonColor = false
		tabButton.Font = library.Font
		tabButton.Text = title
		tabButton.TextColor3 = Color3.fromRGB(170, 170, 170)
		tabButton.TextSize = 15.000
		tabButton.RichText = true

		page.Parent = container
		page.Active = true
		page.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		page.BackgroundTransparency = 1.000
		page.BorderSizePixel = 0
		page.Size = UDim2.new(1, -2, 1, -2)
		page.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
		page.MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
		page.ScrollBarThickness = 1
		page.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
		page.ScrollBarImageColor3 = library.acientColor
		page.Visible = false
		page.CanvasSize = UDim2.new(0,0,0,0)
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y

		pageLayout.Parent = page
		pageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
		pageLayout.Padding = UDim.new(0, 4)

		pagePadding.Parent = page
		pagePadding.PaddingBottom = UDim.new(0, 6)
		pagePadding.PaddingLeft = UDim.new(0, 6)
		pagePadding.PaddingRight = UDim.new(0, 6)
		pagePadding.PaddingTop = UDim.new(0, 6)

		local sideSectionsHost = Instance.new("Frame")
		sideSectionsHost.Name = "SideSectionsHost"
		sideSectionsHost.Parent = page
		sideSectionsHost.BackgroundTransparency = 1
		sideSectionsHost.Size = UDim2.new(1, 0, 0, 0)
		sideSectionsHost.Visible = false
		local sideOuterPadding = 2
		local sideHalfGap = 8

		local leftSections = Instance.new("Frame")
		leftSections.Name = "LeftSections"
		leftSections.Parent = sideSectionsHost
		leftSections.BackgroundTransparency = 1
		leftSections.Position = UDim2.new(0, sideOuterPadding, 0, 0)
		leftSections.Size = UDim2.new(0.5, -(sideOuterPadding + sideHalfGap), 0, 0)

		local rightSections = Instance.new("Frame")
		rightSections.Name = "RightSections"
		rightSections.Parent = sideSectionsHost
		rightSections.BackgroundTransparency = 1
		rightSections.AnchorPoint = Vector2.new(0, 0)
		rightSections.Position = UDim2.new(0.5, sideHalfGap, 0, 0)
		rightSections.Size = UDim2.new(0.5, -(sideOuterPadding + sideHalfGap), 0, 0)

		local leftSectionsLayout = Instance.new("UIListLayout")
		leftSectionsLayout.Parent = leftSections
		leftSectionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		leftSectionsLayout.Padding = UDim.new(0, 6)

		local rightSectionsLayout = Instance.new("UIListLayout")
		rightSectionsLayout.Parent = rightSections
		rightSectionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rightSectionsLayout.Padding = UDim.new(0, 6)

		local function updateSideSectionsHostHeight()
			local leftH = leftSectionsLayout.AbsoluteContentSize.Y
			local rightH = rightSectionsLayout.AbsoluteContentSize.Y
			local h = math.max(leftH, rightH)
			sideSectionsHost.Size = UDim2.new(1, 0, 0, h)
			leftSections.Size = UDim2.new(0.5, -(sideOuterPadding + sideHalfGap), 0, h)
			rightSections.Size = UDim2.new(0.5, -(sideOuterPadding + sideHalfGap), 0, h)
		end
		leftSectionsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateSideSectionsHostHeight)
		rightSectionsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateSideSectionsHostHeight)

		if self.IsFirst then
			page.Visible = true
			tabButton.TextColor3 = library.acientColor
			self.CurrentTab = title
		end

		tabButton.MouseButton1Click:Connect(function()
			self.CurrentTab = title
			for i,v in pairs(container:GetChildren()) do 
				if v:IsA("ScrollingFrame") then
					v.Visible = false
				end
			end
			page.Visible = true

			for i,v in pairs(tabButtons:GetChildren()) do
				if v:IsA("TextButton") then
					TweenService:Create(v, TweenWrapper.Styles["tab_text_colour"], {TextColor3 = Color3.fromRGB(170, 170, 170)}):Play()
				end
			end
			TweenService:Create(tabButton, TweenWrapper.Styles["tab_text_colour"], {TextColor3 = library.acientColor}):Play()
		end)

		self.IsFirst = false

		TweenWrapper:CreateStyle("hover", 0.16)
		local Components = {}
		function Components:NewLabel(text, alignment)
			text = text or "label"
			alignment = alignment or "left"

			local label = Instance.new("TextLabel")
			local labelPadding = Instance.new("UIPadding")

			label.Parent = page
			label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			label.BackgroundTransparency = 1.000
			label.Position = UDim2.new(0.00499999989, 0, 0, 0)
			label.Size = UDim2.new(0, 396, 0, 24)
			label.Font = library.Font
			label.Text = text
			label.TextColor3 = Color3.fromRGB(190, 190, 190)
			label.TextSize = 14.000
			label.TextWrapped = true
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.RichText = true

			labelPadding.Parent = page
			labelPadding.PaddingBottom = UDim.new(0, 6)
			labelPadding.PaddingLeft = UDim.new(0, 12)
			labelPadding.PaddingRight = UDim.new(0, 6)
			labelPadding.PaddingTop = UDim.new(0, 6)

			if alignment:lower():find("le") then
				label.TextXAlignment = Enum.TextXAlignment.Left
			elseif alignment:lower():find("cent") then
				label.TextXAlignment = Enum.TextXAlignment.Center
			elseif alignment:lower():find("ri") then
				label.TextXAlignment = Enum.TextXAlignment.Right
			end



			local LabelFunctions = {}
			function LabelFunctions:SetText(text)
				text = text or "new label text"
				label.Text = text
				return self
			end

			function LabelFunctions:Remove()
				label:Destroy()
				return self
			end

			function LabelFunctions:Hide()
				label.Visible = false

				return self
			end

			function LabelFunctions:Show()
				label.Visible = true

				return self
			end

			function LabelFunctions:Align(new)
				new = new or "le"
				if new:lower():find("le") then
					label.TextXAlignment = Enum.TextXAlignment.Left
				elseif new:lower():find("cent") then
					label.TextXAlignment = Enum.TextXAlignment.Center
				elseif new:lower():find("ri") then
					label.TextXAlignment = Enum.TextXAlignment.Right
				end
			end
			return LabelFunctions
		end

		function Components:NewNote(text)
			text = tostring(text or "")
			local note = Instance.new("TextLabel")
			note.Parent = page
			note.BackgroundTransparency = 1
			note.Size = UDim2.new(0, 396, 0, 18)
			note.Font = library.Font
			note.Text = text
			note.TextColor3 = Color3.fromRGB(145, 145, 145)
			note.TextSize = 12
			note.TextXAlignment = Enum.TextXAlignment.Left
			note.RichText = true

			local pad = Instance.new("UIPadding")
			pad.Parent = note
			pad.PaddingLeft = UDim.new(0, 2)

			local NoteFunctions = {}
			function NoteFunctions:SetText(newText)
				note.Text = tostring(newText or "")
				return self
			end
			function NoteFunctions:Hide()
				note.Visible = false
				return self
			end
			function NoteFunctions:Show()
				note.Visible = true
				return self
			end
			function NoteFunctions:Remove()
				note:Destroy()
				return self
			end
			return NoteFunctions
		end

		function Components:NewButton(text, callback)
			text = text or "Button"
			callback = callback or function() end

			local ButtonFunctions = {}
			local button = Instance.new("TextButton")
			local buttonCorner = Instance.new("UICorner", button)
			local buttonStroke = Instance.new("UIStroke", button)

			local Color = library.darkGray

			button.Text = text
			button.Parent = page
			button.BackgroundColor3 = Color
			button.BackgroundTransparency = library.transparency
			button.Size = UDim2.new(0, 396, 0, 24)
			button.AutoButtonColor = true
			button.Font = library.Font
			button.TextColor3 = Color3.fromRGB(190, 190, 190)
			button.TextSize = 14

			buttonStroke.Thickness = 1
			buttonStroke.Color = library.lightGray
			buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			buttonStroke.Transparency = 0.52

			buttonCorner.CornerRadius = UDim.new(0, 2)

			button.MouseButton1Click:Connect(function()
				callback()
			end)

			function ButtonFunctions:Fire()
				callback()
			end

			function ButtonFunctions:Hide()
				button.Visible = false
				return self
			end

			function ButtonFunctions:Show()
				button.Visible = true
				return self
			end

			function ButtonFunctions:SetText(text)
				text = text or ""
				button.Text = text

				return self
			end

			function ButtonFunctions:Remove()
				button:Destroy()
				return self
			end

			function ButtonFunctions:SetFunction(new)
				new = new or function() end
				callback = new
				return self
			end
			return ButtonFunctions
		end

		function Components:NewSection(text)
			text = text or "section"

			local sectionFrame = Instance.new("Frame", page)
			local sectionLayout = Instance.new("UIListLayout")
			local sectionLabel = Instance.new("TextLabel")
			local sectionPadding = Instance.new("UIPadding", sectionFrame)

			local UICorner = Instance.new("UICorner", sectionFrame)
			UICorner.CornerRadius = UDim.new(0, 3)

			sectionFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
			sectionFrame.BackgroundTransparency = 0.500
			sectionFrame.BorderSizePixel = 0
			sectionFrame.ClipsDescendants = true
			sectionFrame.Size = UDim2.new(0, 396, 0, 19)

			sectionPadding.PaddingBottom = UDim.new(0, 6)
			sectionPadding.PaddingLeft = UDim.new(0, 3)
			sectionPadding.PaddingRight = UDim.new(0, 3)
			sectionPadding.PaddingTop = UDim.new(0, 6)

			sectionLayout.Parent = sectionFrame
			sectionLayout.FillDirection = Enum.FillDirection.Horizontal
			sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
			sectionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			sectionLayout.Padding = UDim.new(0, 4)

			sectionLabel.Parent = sectionFrame
			sectionLabel.BackgroundColor3 = library.headerColor 
			sectionLabel.BackgroundTransparency = 1.000
			sectionLabel.ClipsDescendants = true
			sectionLabel.Position = UDim2.new(0.0252525248, 0, 0.020833334, 0)
			sectionLabel.Size = UDim2.new(1, 0, 1, 0)
			sectionLabel.Font = library.Font
			sectionLabel.LineHeight = 1
			sectionLabel.Text = text
			sectionLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			sectionLabel.TextSize = 14.000
			sectionLabel.TextXAlignment = Enum.TextXAlignment.Left
			sectionLabel.RichText = true


			local NewSectionSize = TextService:GetTextSize(sectionLabel.Text, sectionLabel.TextSize, sectionLabel.Font, Vector2.new(math.huge,math.huge))
			sectionLabel.Size = UDim2.new(0, NewSectionSize.X, 0, 18)

			local SectionFunctions = {}
			function SectionFunctions:SetText(new)
				new = new or text
				sectionLabel.Text = new

				local NewSectionSize = TextService:GetTextSize(sectionLabel.Text, sectionLabel.TextSize, sectionLabel.Font, Vector2.new(math.huge,math.huge))
				sectionLabel.Size = UDim2.new(0, NewSectionSize.X, 0, 18)

				return self
			end
			function SectionFunctions:Hide()
				sectionFrame.Visible = false
				return self
			end
			function SectionFunctions:Show()
				sectionFrame.Visible = true
				return self
			end
			function SectionFunctions:Remove()
				sectionFrame:Destroy()
				return self
			end
			--
			return SectionFunctions
		end

		function Components:NewToggle(text, default, callback, loop, ignorepanic)
			text = text or "toggle"
			default = default or false
			callback = callback or function() end
			local controlKey = "toggle::" .. tostring(text):lower():gsub("%s+", "_")
			local loadedValue = library.LoadedConfig and library.LoadedConfig[controlKey]
			if loadedValue ~= nil then
				default = loadedValue == true
			end

			local toggleButton = Instance.new("TextButton", page)
			local toggleLayout = Instance.new("UIListLayout")

			local toggle = Instance.new("Frame")
			local toggleCorner = Instance.new("UICorner")
			local toggleDesign = Instance.new("Frame")
			local toggleDesignCorner = Instance.new("UICorner")
			local toggleStroke = Instance.new("UIStroke", toggle)
			local toggleLabel = Instance.new("TextLabel")
			local toggleLabelPadding = Instance.new("UIPadding")
			local Extras = Instance.new("Folder")
			local ExtrasLayout = Instance.new("UIListLayout")

			toggleButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			toggleButton.BackgroundTransparency = 1.000
			toggleButton.ClipsDescendants = false
			toggleButton.Size = UDim2.new(0, 396, 0, 22)
			toggleButton.Font = library.Font
			toggleButton.Text = ""
			toggleButton.TextColor3 = Color3.fromRGB(190, 190, 190)
			toggleButton.TextSize = 14.000
			toggleButton.TextXAlignment = Enum.TextXAlignment.Left

			toggleLayout.Parent = toggleButton
			toggleLayout.FillDirection = Enum.FillDirection.Horizontal
			toggleLayout.SortOrder = Enum.SortOrder.LayoutOrder
			toggleLayout.VerticalAlignment = Enum.VerticalAlignment.Center

			toggle.Parent = toggleButton
			toggle.BackgroundColor3 = library.darkGray
			toggle.BackgroundTransparency = library.transparency
			toggle.Size = UDim2.new(0, 18, 0, 18)

			toggleStroke.Thickness = 1
			toggleStroke.Color = library.lightGray

			toggleCorner.CornerRadius = UDim.new(0, 2)
			toggleCorner.Parent = toggle

			toggleDesign.Parent = toggle
			toggleDesign.AnchorPoint = Vector2.new(0.5, 0.5)
			toggleDesign.BackgroundColor3 = library.acientColor
			toggleDesign.BackgroundTransparency = 1.000
			toggleDesign.Position = UDim2.new(0.5, 0, 0.5, 0)

			toggleDesignCorner.CornerRadius = UDim.new(0, 2)
			toggleDesignCorner.Parent = toggleDesign

			toggleLabel.Parent = toggleButton
			toggleLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			toggleLabel.BackgroundTransparency = 1.000
			toggleLabel.Position = UDim2.new(0.0454545468, 0, 0, 0)
			toggleLabel.Size = UDim2.new(0, 377, 0, 22)
			toggleLabel.Font = library.Font
			toggleLabel.LineHeight = 1.150
			toggleLabel.Text = text
			toggleLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			toggleLabel.TextSize = 14.000
			toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
			toggleLabel.RichText = true

			toggleLabelPadding.Parent = toggleLabel
			toggleLabelPadding.PaddingLeft = UDim.new(0, 6)

			Extras.Parent = toggleButton

			ExtrasLayout.Parent = Extras
			ExtrasLayout.FillDirection = Enum.FillDirection.Horizontal
			ExtrasLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
			ExtrasLayout.SortOrder = Enum.SortOrder.LayoutOrder
			ExtrasLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			ExtrasLayout.Padding = UDim.new(0, 2)

			local NewToggleLabelSize = TextService:GetTextSize(toggleLabel.Text, toggleLabel.TextSize, toggleLabel.Font, Vector2.new(math.huge,math.huge))
			toggleLabel.Size = UDim2.new(0, NewToggleLabelSize.X + 6, 0, 22)

			toggleButton.MouseEnter:Connect(function()
				TweenService:Create(toggleLabel, TweenWrapper.Styles["hover"], {TextColor3 = Color3.fromRGB(210, 210, 210)}):Play()
			end)
			toggleButton.MouseLeave:Connect(function()
				TweenService:Create(toggleLabel, TweenWrapper.Styles["hover"], {TextColor3 = Color3.fromRGB(190, 190, 190)}):Play()
			end)

			TweenWrapper:CreateStyle("toggle_form", 0.13)
			local On = default
			if default then
				On = true
			else
				On = false
			end

			if loop ~= nil then
				RunService.RenderStepped:Connect(function()
					if On == true then
						callback(On)
					end
				end)
			end

			toggleButton.MouseButton1Click:Connect(function()
				On = not On
				local SizeOn = On and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 0, 0, 0)
				local Transparency = On and 0 or 1
				TweenService:Create(toggleDesign, TweenWrapper.Styles["toggle_form"], {Size = SizeOn}):Play()
				TweenService:Create(toggleDesign, TweenWrapper.Styles["toggle_form"], {BackgroundTransparency = Transparency}):Play()
				callback(On)
				if library.AutoSave then
					library:SaveConfig()
				end
			end)

			local ToggleFunctions = {}

			if not ignorepanic then
				OptionStates[toggleButton] = {false, ToggleFunctions}
			end

			function ToggleFunctions:SetText(new)
				new = new or text
				toggleLabel.Text = new
				return self
			end

			function ToggleFunctions:Hide()
				toggleButton.Visible = false
				return self
			end

			function ToggleFunctions:Show()
				toggleButton.Visible = true
				return self
			end   

			function ToggleFunctions:Change()
				On = not On
				local SizeOn = On and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 0, 0, 0)
				local Transparency = On and 0 or 1
				TweenService:Create(toggleDesign, TweenWrapper.Styles["toggle_form"], {Size = SizeOn}):Play()
				TweenService:Create(toggleDesign, TweenWrapper.Styles["toggle_form"], {BackgroundTransparency = Transparency}):Play()
				callback(On)
				if library.AutoSave then
					library:SaveConfig()
				end
				return self
			end

			function ToggleFunctions:Remove()
				SavedControls.Toggles[controlKey] = nil
				toggleButton:Destroy()
				return self
			end

			function ToggleFunctions:Set(state)
				On = state
				local SizeOn = On and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 0, 0, 0)
				local Transparency = On and 0 or 1
				TweenService:Create(toggleDesign, TweenWrapper.Styles["toggle_form"], {Size = SizeOn}):Play()
				TweenService:Create(toggleDesign, TweenWrapper.Styles["toggle_form"], {BackgroundTransparency = Transparency}):Play()
				callback(On)
				if library.AutoSave then
					library:SaveConfig()
				end
				return ToggleFunctions
			end

			function ToggleFunctions:GetValue()
				return On
			end

			local callback_t
			function ToggleFunctions:SetFunction(new)
				new = new or function() end
				callback = new
				callback_t = new
				return ToggleFunctions
			end


			function ToggleFunctions:AddKeybind(default_t)
				callback_t = callback
				if default_t == Enum.KeyCode.Backspace then
					default_t = nil
				end

				local keybind = Instance.new("TextButton")
				local keybindOutline = Instance.new("UIStroke")
				local keybindCorner = Instance.new("UICorner")
				local keybindBackground = Instance.new("Frame")
				local keybindBackCorner = Instance.new("UICorner")
				local keybindButtonLabel = Instance.new("TextLabel")
				local keybindLabelStraint = Instance.new("UISizeConstraint")
				local keybindBackgroundStraint = Instance.new("UISizeConstraint")
				local keybindStraint = Instance.new("UISizeConstraint")
				
				keybindOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				keybindOutline.Thickness = 1
				keybindOutline.Parent = keybind
				keybindOutline.Color = library.lightGray
				
				keybindCorner.CornerRadius = UDim.new(0, 2)
				keybindCorner.Parent = keybind

				keybind.Parent = Extras
				keybind.BackgroundTransparency = library.transparency
				keybind.BackgroundColor3 = library.darkGray
				keybind.Position = UDim2.new(0.780303001, 0, 0, 0)
				keybind.Size = UDim2.new(0, 87, 0, 22)
				keybind.AutoButtonColor = false
				keybind.Font = library.Font
				keybind.Text = ""
				keybind.TextColor3 = Color3.fromRGB(0, 0, 0)
				keybind.TextSize = 14.000
				keybind.Active = false

				keybindBackground.Parent = keybind
				keybindBackground.AnchorPoint = Vector2.new(0.5, 0.5)
				keybindBackground.BackgroundTransparency = 1 --library.transparency
				keybindBackground.BackgroundColor3 = library.darkGray
				keybindBackground.Position = UDim2.new(0.5, 0, 0.5, 0)
				keybindBackground.Size = UDim2.new(0, 85, 0, 20)

				keybindBackCorner.CornerRadius = UDim.new(0, 2)
				keybindBackCorner.Parent = keybindBackground

				keybindButtonLabel.Parent = keybindBackground
				keybindButtonLabel.AnchorPoint = Vector2.new(0.5, 0.5)
				keybindButtonLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				keybindButtonLabel.BackgroundTransparency = 1.000
				keybindButtonLabel.ClipsDescendants = true
				keybindButtonLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
				keybindButtonLabel.Size = UDim2.new(0, 85, 0, 20)
				keybindButtonLabel.Font = library.Font
				keybindButtonLabel.Text = ". . ."
				keybindButtonLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
				keybindButtonLabel.TextSize = 14.000
				keybindButtonLabel.RichText = true

				keybindLabelStraint.Parent = keybindButtonLabel
				keybindLabelStraint.MinSize = Vector2.new(28, 20)

				keybindBackgroundStraint.Parent = keybindBackground
				keybindBackgroundStraint.MinSize = Vector2.new(28, 20)

				keybindStraint.Parent = keybind
				keybindStraint.MinSize = Vector2.new(30, 22)

				local Shortcuts = {
					Return = "enter"
				}

				keybindButtonLabel.Text = default_t and (Shortcuts[default_t.Name] or default_t.Name) or "None"
				TweenWrapper:CreateStyle("keybind", 0.08)

				local NewKeybindSize = TextService:GetTextSize(keybindButtonLabel.Text, keybindButtonLabel.TextSize, keybindButtonLabel.Font, Vector2.new(math.huge,math.huge))
				keybindButtonLabel.Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)
				keybindBackground.Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)
				keybind.Size = UDim2.new(0, NewKeybindSize.X + 8, 0, 22)

				local function ResizeKeybind()
					NewKeybindSize = TextService:GetTextSize(keybindButtonLabel.Text, keybindButtonLabel.TextSize, keybindButtonLabel.Font, Vector2.new(math.huge,math.huge))
					TweenService:Create(keybindButtonLabel, TweenWrapper.Styles["keybind"], {Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)}):Play()
					TweenService:Create(keybindBackground, TweenWrapper.Styles["keybind"], {Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)}):Play()
					TweenService:Create(keybind, TweenWrapper.Styles["keybind"], {Size = UDim2.new(0, NewKeybindSize.X + 8, 0, 22)}):Play()
				end
				keybindButtonLabel:GetPropertyChangedSignal("Text"):Connect(ResizeKeybind)
				ResizeKeybind()


				local ChosenKey = default_t and default_t.Name

				keybind.MouseButton1Click:Connect(function()
					keybindButtonLabel.Text = ". . ."
					local InputWait = UserInputService.InputBegan:wait()
					if not UserInputService.WindowFocused then return end 

					if InputWait == Enum.KeyCode.Backspace then
						default_t = nil
						ChosenKey = nil
						keybindButtonLabel.Text = "None"
						return
					end

					if InputWait.KeyCode.Name ~= "Unknown" then
						local Result = Shortcuts[InputWait.KeyCode.Name] or InputWait.KeyCode.Name
						keybindButtonLabel.Text = Result
						ChosenKey = InputWait.KeyCode.Name
					end
				end)

				--local ChatTextBox = Player.PlayerGui.Chat.Frame.ChatBarParentFrame.Frame.BoxFrame.Frame.ChatBar
				if UserInputService.WindowFocused then
					UserInputService.InputBegan:Connect(function(c, p)
						if not p and default_t and ChosenKey then
							if c.KeyCode.Name == ChosenKey then --  and not ChatTextBox:IsFocused()
								On = not On
								local SizeOn = On and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 0, 0, 0)
								local Transparency = On and 0 or 1
								TweenService:Create(toggleDesign, TweenWrapper.Styles["toggle_form"], {Size = SizeOn}):Play()
								TweenService:Create(toggleDesign, TweenWrapper.Styles["toggle_form"], {BackgroundTransparency = Transparency}):Play()
								callback_t(On)
								return
							end
						end
					end)
				end

				local ExtraKeybindFunctions = {}
				function ExtraKeybindFunctions:SetKey(new)
					new = new or ChosenKey.Name
					ChosenKey = new.Name
					keybindButtonLabel.Text = new.Name
					return self
				end

				function ExtraKeybindFunctions:Fire()
					callback_t(ChosenKey)
					return self
				end

				function ExtraKeybindFunctions:SetFunction(new)
					new = new or function() end
					callback_t = new
					return self 
				end

				function ExtraKeybindFunctions:Hide()
					keybind.Visible = false
					return self
				end

				function ExtraKeybindFunctions:Show()
					keybind.Visible = true
					return self
				end
				return ExtraKeybindFunctions and ToggleFunctions
			end

			if default then
				toggleDesign.Size = UDim2.new(0, 12, 0, 12)
				toggleDesign.BackgroundTransparency = 0
				callback(true)
			end
			SavedControls.Toggles[controlKey] = ToggleFunctions
			return ToggleFunctions
		end

		function Components:NewKeybind(text, default, callback)
			text = text or "keybind"
			default = default or Enum.KeyCode.P
			callback = callback or function() end

			local keybindFrame = Instance.new("Frame")
			local keybindButton = Instance.new("TextButton")
			local keybindLayout = Instance.new("UIListLayout")
			local keybindLabel = Instance.new("TextLabel")
			local keybindPadding = Instance.new("UIPadding")
			local keybindFolder = Instance.new("Folder")
			local keybindFolderLayout = Instance.new("UIListLayout")
			local keybind = Instance.new("TextButton")
			local keybindCorner = Instance.new("UICorner")
			local keybindBackground = Instance.new("Frame")
			local keybindGradient = Instance.new("UIGradient")
			local keybindBackCorner = Instance.new("UICorner")
			local keybindButtonLabel = Instance.new("TextLabel")
			local keybindLabelStraint = Instance.new("UISizeConstraint")
			local keybindBackgroundStraint = Instance.new("UISizeConstraint")
			local keybindStraint = Instance.new("UISizeConstraint")

			keybindFrame.Parent = page
			keybindFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			keybindFrame.BackgroundTransparency = 1.000
			keybindFrame.ClipsDescendants = true
			keybindFrame.Size = UDim2.new(0, 396, 0, 24)

			keybindButton.Parent = keybindFrame
			keybindButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			keybindButton.BackgroundTransparency = 1.000
			keybindButton.Size = UDim2.new(0, 396, 0, 24)
			keybindButton.AutoButtonColor = false
			keybindButton.Font = library.Font
			keybindButton.Text = ""
			keybindButton.TextColor3 = Color3.fromRGB(0, 0, 0)
			keybindButton.TextSize = 14.000

			keybindLayout.Parent = keybindButton
			keybindLayout.FillDirection = Enum.FillDirection.Horizontal
			keybindLayout.SortOrder = Enum.SortOrder.LayoutOrder
			keybindLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			keybindLayout.Padding = UDim.new(0, 4)

			keybindLabel.Parent = keybindButton
			keybindLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			keybindLabel.BackgroundTransparency = 1.000
			keybindLabel.Size = UDim2.new(0, 396, 0, 24)
			keybindLabel.Font = library.Font
			keybindLabel.Text = text
			keybindLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			keybindLabel.TextSize = 14.000
			keybindLabel.TextWrapped = true
			keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
			keybindLabel.RichText = true

			keybindPadding.Parent = keybindLabel
			keybindPadding.PaddingBottom = UDim.new(0, 6)
			keybindPadding.PaddingLeft = UDim.new(0, 2)
			keybindPadding.PaddingRight = UDim.new(0, 6)
			keybindPadding.PaddingTop = UDim.new(0, 6)

			keybindFolder.Parent = keybindFrame

			keybindFolderLayout.Parent = keybindFolder
			keybindFolderLayout.FillDirection = Enum.FillDirection.Horizontal
			keybindFolderLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
			keybindFolderLayout.SortOrder = Enum.SortOrder.LayoutOrder
			keybindFolderLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			keybindFolderLayout.Padding = UDim.new(0, 4)

			keybind.Parent = keybindFolder
			keybind.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			keybind.Position = UDim2.new(0.780303001, 0, 0, 0)
			keybind.Size = UDim2.new(0, 87, 0, 22)
			keybind.AutoButtonColor = false
			keybind.Font = library.Font
			keybind.Text = ""
			keybind.TextColor3 = Color3.fromRGB(0, 0, 0)
			keybind.TextSize = 14.000
			keybind.Active = false

			keybindCorner.CornerRadius = UDim.new(0, 2)
			keybindCorner.Parent = keybind

			keybindBackground.Parent = keybind
			keybindBackground.AnchorPoint = Vector2.new(0.5, 0.5)
			keybindBackground.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			keybindBackground.Position = UDim2.new(0.5, 0, 0.5, 0)
			keybindBackground.Size = UDim2.new(0, 85, 0, 20)

			keybindGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
			keybindGradient.Rotation = 90
			keybindGradient.Parent = keybindBackground

			keybindBackCorner.CornerRadius = UDim.new(0, 2)
			keybindBackCorner.Parent = keybindBackground

			keybindButtonLabel.Parent = keybindBackground
			keybindButtonLabel.AnchorPoint = Vector2.new(0.5, 0.5)
			keybindButtonLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			keybindButtonLabel.BackgroundTransparency = 1.000
			keybindButtonLabel.ClipsDescendants = true
			keybindButtonLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
			keybindButtonLabel.Size = UDim2.new(0, 85, 0, 20)
			keybindButtonLabel.Font = library.Font
			keybindButtonLabel.Text = ". . ."
			keybindButtonLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			keybindButtonLabel.TextSize = 14.000
			keybindButtonLabel.RichText = true

			keybindLabelStraint.Parent = keybindButtonLabel
			keybindLabelStraint.MinSize = Vector2.new(28, 20)

			keybindBackgroundStraint.Parent = keybindBackground
			keybindBackgroundStraint.MinSize = Vector2.new(28, 20)

			keybindStraint.Parent = keybind
			keybindStraint.MinSize = Vector2.new(30, 22)

			local Shortcuts = {
				Return = "enter"
			}

			keybindButtonLabel.Text = Shortcuts[default.Name] or default.Name
			TweenWrapper:CreateStyle("keybind", 0.08)

			local NewKeybindSize = TextService:GetTextSize(keybindButtonLabel.Text, keybindButtonLabel.TextSize, keybindButtonLabel.Font, Vector2.new(math.huge,math.huge))
			keybindButtonLabel.Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)
			keybindBackground.Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)
			keybind.Size = UDim2.new(0, NewKeybindSize.X + 8, 0, 22)

			local function ResizeKeybind()
				NewKeybindSize = TextService:GetTextSize(keybindButtonLabel.Text, keybindButtonLabel.TextSize, keybindButtonLabel.Font, Vector2.new(math.huge,math.huge))
				TweenService:Create(keybindButtonLabel, TweenWrapper.Styles["keybind"], {Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)}):Play()
				TweenService:Create(keybindBackground, TweenWrapper.Styles["keybind"], {Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)}):Play()
				TweenService:Create(keybind, TweenWrapper.Styles["keybind"], {Size = UDim2.new(0, NewKeybindSize.X + 8, 0, 22)}):Play()
			end
			keybindButtonLabel:GetPropertyChangedSignal("Text"):Connect(ResizeKeybind)
			ResizeKeybind()

			local ChosenKey = default
			keybindButton.MouseButton1Click:Connect(function()
				keybindButtonLabel.Text = "..."
				local InputWait = UserInputService.InputBegan:wait()
				if UserInputService.WindowFocused and InputWait.KeyCode.Name ~= "Unknown" then
					local Result = Shortcuts[InputWait.KeyCode.Name] or InputWait.KeyCode.Name
					keybindButtonLabel.Text = Result
					ChosenKey = InputWait.KeyCode.Name
				end
			end)

			keybind.MouseButton1Click:Connect(function()
				keybindButtonLabel.Text = ". . ."
				local InputWait = UserInputService.InputBegan:wait()
				if UserInputService.WindowFocused and InputWait.KeyCode.Name ~= "Unknown" then
					local Result = Shortcuts[InputWait.KeyCode.Name] or InputWait.KeyCode.Name
					keybindButtonLabel.Text = Result
					ChosenKey = InputWait.KeyCode.Name
				end
			end)

			--local ChatTextBox = Player.PlayerGui.Chat.Frame.ChatBarParentFrame.Frame.BoxFrame.Frame.ChatBar
			if UserInputService.WindowFocused then
				UserInputService.InputBegan:Connect(function(c, GameProcessed)
					if GameProcessed then
						return
					end
					if c.KeyCode.Name == ChosenKey then -- and not ChatTextBox:IsFocused()
						callback(ChosenKey)
						return
					end
				end)
			end



			local KeybindFunctions = {}
			function KeybindFunctions:Fire()
				callback(ChosenKey)
				return KeybindFunctions
			end

			function KeybindFunctions:SetFunction(new)
				new = new or function() end
				callback = new
				return self 
			end

			function KeybindFunctions:SetKey(new)
				new = new or ChosenKey.Name
				ChosenKey = new.Name
				keybindButtonLabel.Text = new.Name
				return self
			end

			function KeybindFunctions:SetText(new)
				new = new or keybindLabel.Text
				keybindLabel.Text = new
				return self
			end

			function KeybindFunctions:Hide()
				keybindFrame.Visible = false
				return self
			end

			function KeybindFunctions:Show()
				keybindFrame.Visible = true
				return self
			end
			return KeybindFunctions
		end

		function Components:NewTextbox(text, default, placeHolder, type, autoexec, autoclear, callback)
			text = text or "text box"
			default = default or ""
			placeHolder = placeHolder or ""
			type = type or "small" -- small, medium, large
			autoexec = autoexec or true
			autoclear = autoclear or false
			callback = callback or function() end

			local textboxFrame = Instance.new("Frame")
			local textboxLabel = Instance.new("TextLabel")
			local textboxPadding = Instance.new("UIPadding")
			local textbox = Instance.new("Frame")
			local textBoxValues = Instance.new("TextBox")
			local textBoxValuesPadding = Instance.new("UIPadding")

			textboxFrame.Parent = page
			textboxFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			textboxFrame.BackgroundTransparency = 1.000
			textboxFrame.BorderSizePixel = 0
			textboxFrame.Position = UDim2.new(0.00499999989, 0, 0.268786132, 0)

			textBoxValues.MultiLine = true
			if type == "small" then
				textBoxValues.MultiLine = false
				textboxFrame.Size = UDim2.new(0, 393, 0, 46)
			elseif type == "medium" then
				textboxFrame.Size = UDim2.new(0, 393, 0, 60)
			elseif type == "large" then
				textboxFrame.Size = UDim2.new(0, 393, 0, 118)
			end

			textboxLabel.Parent = textboxFrame
			textboxLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			textboxLabel.BackgroundTransparency = 1.000
			textboxLabel.Size = UDim2.new(1, 0, 0, 24)
			textboxLabel.Font = library.Font
			textboxLabel.Text = text
			textboxLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			textboxLabel.TextSize = 14.000
			textboxLabel.TextWrapped = true
			textboxLabel.TextXAlignment = Enum.TextXAlignment.Left

			textboxPadding.Parent = textboxLabel
			textboxPadding.PaddingBottom = UDim.new(0, 6)
			textboxPadding.PaddingRight = UDim.new(0, 6)
			textboxPadding.PaddingTop = UDim.new(0, 6)

			textbox.Parent = textboxFrame
			textbox.BackgroundColor3 = library.darkGray
			textbox.BackgroundTransparency = library.transparency
			textbox.BorderSizePixel = 0
			textbox.Position = UDim2.new(0, 0, 0, 24)
			textbox.Size = UDim2.new(1, 0, 1, -24)

			local textboxOutline = Instance.new("UIStroke", textbox)
			textboxOutline.Thickness = 1
			textboxOutline.Color = library.lightGray

			local UICorner = Instance.new("UICorner", textbox)
			UICorner.CornerRadius = UDim.new(0, 2)

			textBoxValues.Parent = textbox
			textBoxValues.BackgroundTransparency = 1
			textBoxValues.BorderSizePixel = 0
			textBoxValues.ClipsDescendants = true
			textBoxValues.Size = UDim2.new(1, 0, 1, 0)
			textBoxValues.Font = library.Font
			textBoxValues.PlaceholderColor3 = Color3.fromRGB(140, 140, 140)
			textBoxValues.PlaceholderText = placeHolder
			textBoxValues.Text = default
			textBoxValues.TextColor3 = Color3.fromRGB(190, 190, 190)
			textBoxValues.TextSize = 14.000
			textBoxValues.TextWrapped = true
			textBoxValues.TextXAlignment = Enum.TextXAlignment.Left
			textBoxValues.TextYAlignment = Enum.TextYAlignment.Top

			textBoxValuesPadding.Parent = textBoxValues
			textBoxValuesPadding.PaddingBottom = UDim.new(0, 4)
			textBoxValuesPadding.PaddingLeft = UDim.new(0, 4)
			textBoxValuesPadding.PaddingRight = UDim.new(0, 4)
			textBoxValuesPadding.PaddingTop = UDim.new(0, 4)

			TweenWrapper:CreateStyle("TextBox", 0.07)


			textBoxValues.FocusLost:Connect(function(enterPressed)
				if autoexec or enterPressed then
					callback(textBoxValues.Text)
				end
			end)

			local TextboxFunctions = {}
			function TextboxFunctions:Input(new)
				new = new or textBoxValues.Text
				textBoxValues = new
				return self
			end

			function TextboxFunctions:Fire()
				callback(textBoxValues.Text)
				return self
			end

			function TextboxFunctions:SetFunction(new)
				new = new or callback
				callback = new
				return self
			end

			function TextboxFunctions:SetText(new)
				new = new or textboxLabel.Text
				textboxLabel.Text = new
				return self
			end

			function TextboxFunctions:Hide()
				textboxFrame.Visible = false
				return self
			end

			function TextboxFunctions:Show()
				textboxFrame.Visible = true
				return self
			end

			function TextboxFunctions:Remove()
				textboxFrame:Destroy()
				return self
			end

			function TextboxFunctions:SetPlaceHolder(new)
				new = new or textBoxValues.PlaceholderText
				textBoxValues.PlaceholderText = new
				return self
			end
			return TextboxFunctions
		end
		--
		function Components:NewSelector(text, default, list, callback)
			text = text or "selector"
			default = default or ". . ."
			list = list or {}
			callback = callback or function() end

			local selectorFrame = Instance.new("Frame")
			local selectorLabel = Instance.new("TextLabel")
			local selectorLabelPadding = Instance.new("UIPadding")
			local selectorFrameLayout = Instance.new("UIListLayout")
			local selector = Instance.new("TextButton")
			local selectorCorner = Instance.new("UICorner")
			local selectorLayout = Instance.new("UIListLayout")
			local selectorPadding = Instance.new("UIPadding")
			local selectorTwo = Instance.new("Frame")
			local selectorText = Instance.new("TextLabel")
			local textBoxValuesPadding = Instance.new("UIPadding")
			local Frame = Instance.new("Frame")
			local selectorTwoLayout = Instance.new("UIListLayout")
			local selectorTwoCorner = Instance.new("UICorner")
			local selectorPadding_2 = Instance.new("UIPadding")
			local selectorContainer = Instance.new("Frame")
			local selectorTwoLayout_2 = Instance.new("UIListLayout")

			selectorFrame.Parent = page
			selectorFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			selectorFrame.BackgroundTransparency = 1.000
			selectorFrame.ClipsDescendants = true
			selectorFrame.Position = UDim2.new(0.00499999989, 0, 0.0895953774, 0)
			selectorFrame.Size = UDim2.new(0, 394, 0, 48)

			selectorLabel.Parent = selectorFrame
			selectorLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			selectorLabel.BackgroundTransparency = 1.000
			selectorLabel.Size = UDim2.new(0, 396, 0, 24)
			selectorLabel.Font = library.Font
			selectorLabel.Text = text
			selectorLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			selectorLabel.TextSize = 14.000
			selectorLabel.TextWrapped = true
			selectorLabel.TextXAlignment = Enum.TextXAlignment.Left
			selectorLabel.RichText = true

			selectorLabelPadding.Parent = selectorLabel
			selectorLabelPadding.PaddingBottom = UDim.new(0, 6)
			selectorLabelPadding.PaddingLeft = UDim.new(0, 2)
			selectorLabelPadding.PaddingRight = UDim.new(0, 6)
			selectorLabelPadding.PaddingTop = UDim.new(0, 6)

			selectorFrameLayout.Parent = selectorFrame
			selectorFrameLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			selectorFrameLayout.SortOrder = Enum.SortOrder.LayoutOrder

			selector.Parent = selectorFrame
			selector.BackgroundColor3 = library.darkGray
			selector.BackgroundTransparency = library.transparency
			selector.ClipsDescendants = true
			selector.Position = UDim2.new(0, 0, 0.0926640928, 0)
			selector.Size = UDim2.new(1, 0, 0, 23)
			selector.AutoButtonColor = false
			selector.Font = library.Font
			selector.Text = ""
			selector.TextColor3 = Color3.fromRGB(0, 0, 0)
			selector.TextSize = 14.000

			selectorCorner.CornerRadius = UDim.new(0, 2)
			selectorCorner.Parent = selector

			selectorLayout.Parent = selector
			selectorLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			selectorLayout.SortOrder = Enum.SortOrder.LayoutOrder

			selectorPadding.Parent = selector
			selectorPadding.PaddingTop = UDim.new(0, 1)

			selectorTwo.Parent = selector
			selectorTwo.BackgroundColor3 = library.darkGray
			selectorTwo.BackgroundTransparency = library.transparency
			selectorTwo.ClipsDescendants = true
			selectorTwo.Position = UDim2.new(0.00252525252, 0, 0, 0)
			selectorTwo.Size = UDim2.new(1, -2, 1, -1)

			selectorText.Parent = selectorTwo
			selectorText.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			selectorText.BackgroundTransparency = 1.000
			selectorText.Size = UDim2.new(0, 394, 0, 20)
			selectorText.Font = library.Font
			selectorText.LineHeight = 1.150
			selectorText.TextColor3 = Color3.fromRGB(160, 160, 160)
			selectorText.TextSize = 14.000
			selectorText.TextXAlignment = Enum.TextXAlignment.Left
			selectorText.Text = default

			local Toggle = Instance.new("TextButton", selectorText)
			Toggle.AnchorPoint = Vector2.new(1, 0.5)
			Toggle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			Toggle.BackgroundTransparency = 1.000
			Toggle.BorderColor3 = Color3.fromRGB(0, 0, 0)
			Toggle.BorderSizePixel = 0
			Toggle.Position = UDim2.new(1, 0, 0.5, 0)
			Toggle.Rotation = 90
			Toggle.Size = UDim2.new(0, 20, 1, 5)
			Toggle.Font = library.Font
			Toggle.Text = ">"
			Toggle.TextColor3 = Color3.fromRGB(160, 160, 160)
			Toggle.TextSize = 14.000

			textBoxValuesPadding.Parent = selectorText
			textBoxValuesPadding.PaddingBottom = UDim.new(0, 6)
			textBoxValuesPadding.PaddingLeft = UDim.new(0, 6)
			textBoxValuesPadding.PaddingRight = UDim.new(0, 6)
			textBoxValuesPadding.PaddingTop = UDim.new(0, 6)

			Frame.Parent = selectorText
			Frame.AnchorPoint = Vector2.new(0.5, 1)
			Frame.BackgroundColor3 = Color3.fromRGB(39, 39, 39)
			Frame.BorderSizePixel = 0
			Frame.Position = UDim2.new(0.5, 0, 1, 7)
			Frame.Size = UDim2.new(1, -6, 0, 1)

			selectorTwoLayout.Parent = selectorTwo
			selectorTwoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			selectorTwoLayout.SortOrder = Enum.SortOrder.LayoutOrder

			selectorTwoCorner.CornerRadius = UDim.new(0, 2)
			selectorTwoCorner.Parent = selectorTwo

			selectorPadding_2.Parent = selectorTwo
			selectorPadding_2.PaddingTop = UDim.new(0, 1)

			selectorContainer.Parent = selectorTwo
			selectorContainer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			selectorContainer.BackgroundTransparency = 1.000
			selectorContainer.Size = UDim2.new(1, 0, 0, 20)

			selectorTwoLayout_2.Parent = selectorContainer
			selectorTwoLayout_2.HorizontalAlignment = Enum.HorizontalAlignment.Center
			selectorTwoLayout_2.SortOrder = Enum.SortOrder.LayoutOrder

			TweenWrapper:CreateStyle("selector", 0.08)


			local Amount = #list
			local Val = (Amount * 20)
			local Size= 0

			local function checkSizes()
				Amount = #list
				Val = (Amount * 20) + 20
			end

			for i,v in next, list do
				local optionButton = Instance.new("TextButton")

				optionButton.Name = "optionButton"
				optionButton.Parent = selectorContainer
				optionButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				optionButton.BackgroundTransparency = 1.000
				optionButton.Size = UDim2.new(0, 394, 0, 20)
				optionButton.AutoButtonColor = false
				optionButton.Font = library.Font
				optionButton.Text = v
				optionButton.TextColor3 = Color3.fromRGB(160, 160, 160)
				optionButton.TextSize = 14.000
				if optionButton.Text == default then
					optionButton.TextColor3 = library.acientColor
					callback(selectorText.Text)
				end

				optionButton.MouseButton1Click:Connect(function()
					for z,x in next, selectorContainer:GetChildren() do
						if x:IsA("TextButton") then
							TweenService:Create(x, TweenWrapper.Styles["selector"], {TextColor3 = Color3.fromRGB(160, 160, 160)}):Play()
						end
					end
					TweenService:Create(optionButton, TweenWrapper.Styles["selector"], {TextColor3 = library.acientColor}):Play()
					selectorText.Text = optionButton.Text
					callback(optionButton.Text)
				end)

				Size = Val + 2


				checkSizes()
			end


			local SelectorFunctions = {}
			local AddAmount = 0

			local IsOpen = false
			local function HandleToggle()
				local Speed = 0.2
				IsOpen = not IsOpen

				TweenService:Create(selector, TweenInfo.new(Speed), {
					Size = UDim2.new(1, 0, 0, IsOpen and Size or 23)
				}):Play()
				TweenService:Create(selectorFrame, TweenInfo.new(Speed), {
					Size = UDim2.new(0, 394, 0, IsOpen and Size+24 or 48)
				}):Play()
				TweenService:Create(Toggle, TweenInfo.new(Speed), {
					Rotation = IsOpen and -90 or 90
				}):Play()
			end

			selector.Activated:Connect(HandleToggle)
			Toggle.Activated:Connect(HandleToggle)

			function SelectorFunctions:AddOption(new, callback_f)
				new = new or "option"
				list[new] = new

				local optionButton = Instance.new("TextButton")

				AddAmount = AddAmount + 20

				optionButton.Name = "optionButton"
				optionButton.Parent = selectorContainer
				optionButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				optionButton.BackgroundTransparency = 1.000
				optionButton.Size = UDim2.new(0, 394, 0, 20)
				optionButton.AutoButtonColor = false
				optionButton.Font = library.Font
				optionButton.Text = new
				optionButton.TextColor3 = Color3.fromRGB(140, 140, 140)
				optionButton.TextSize = 14.000
				if optionButton.Text == default then
					optionButton.TextColor3 = library.acientColor
					callback(selectorText.Text)
				end

				optionButton.MouseButton1Click:Connect(function()
					for z,x in next, selectorContainer:GetChildren() do
						if x:IsA("TextButton") then
							TweenService:Create(x, TweenWrapper.Styles["selector"], {TextColor3 = Color3.fromRGB(140, 140, 140)}):Play()
						end
					end
					TweenService:Create(optionButton, TweenWrapper.Styles["selector"], {TextColor3 = library.acientColor}):Play()
					selectorText.Text = optionButton.Text
					callback(optionButton.Text)
				end)

				checkSizes()
				Size = (Val + AddAmount) + 2


				checkSizes()
				return self
			end

			local RemoveAmount = 0
			function SelectorFunctions:RemoveOption(option)
				list[option] = nil

				RemoveAmount = RemoveAmount + 20
				AddAmount = AddAmount - 20

				for i,v in next, selectorContainer:GetDescendants() do
					if v:IsA("TextButton") then
						if v.Text == option then
							v:Destroy()
							Size = (Val - RemoveAmount) + 2
						end
					end
				end

				if selectorText.Text == option then
					selectorText.Text = ". . ."
				end


				checkSizes()
				return self
			end

			function SelectorFunctions:SetFunction(new)
				new = new or callback
				callback = new
				return self
			end

			function SelectorFunctions:Text(new)
				new = new or selectorLabel.Text
				selectorLabel.Text = new
				return self
			end

			function SelectorFunctions:Hide()
				selectorFrame.Visible = false
				return self
			end

			function SelectorFunctions:Show()
				selectorFrame.Visible = true
				return self
			end

			function SelectorFunctions:Remove()
				selectorFrame:Destroy()
				return self
			end
			return SelectorFunctions
		end

		function Components:NewDropdown(text, default, list, callback)
			local resolvedDefault = default
			local resolvedList = list
			local resolvedCallback = callback

			-- Supports both:
			-- NewDropdown(text, default, list, callback)
			-- NewDropdown(text, list, default, callback)
			if type(default) == "table" then
				resolvedList = default
				if type(list) == "function" then
					resolvedDefault = (resolvedList and resolvedList[1]) or ". . ."
					resolvedCallback = list
				else
					resolvedDefault = list or ((resolvedList and resolvedList[1]) or ". . .")
				end
			end

			return self:NewSelector(text, resolvedDefault, resolvedList, resolvedCallback)
		end

		function Components:NewSlider(text, suffix, compare, compareSign, values, callback)
			text = text or "slider"
			suffix = suffix or ""
			compare = compare or false
			compareSign = compareSign or "/"
			local rawStep = type(values) == "table" and values.step or nil
			values = values or {}
			values = {
				min = values.min or 0,
				max = values.max or 100,
				default = values.default or 0,
				step = rawStep,
			}
			callback = callback or function() end
			local controlKey = "slider::" .. tostring(text):lower():gsub("%s+", "_")
			local loadedValue = library.LoadedConfig and library.LoadedConfig[controlKey]
			if loadedValue ~= nil then
				values.default = tonumber(loadedValue) or values.default
			end

			values.max = values.max + 1
			local sliderMin = tonumber(values.min) or 0
			local sliderMax = tonumber(values.max - 1) or 100
			local stepValue = math.abs(tonumber(values.step) or 1)
			if stepValue <= 0 then
				stepValue = 1
			end
			local stepText = tostring(stepValue)
			local dotIndex = stepText:find("%.")
			local decimals = 0
			if dotIndex then
				decimals = math.min(4, #stepText - dotIndex)
			end
			local function quantize(raw)
				local numeric = math.clamp(tonumber(raw) or sliderMin, sliderMin, sliderMax)
				local snapped = sliderMin + (math.floor(((numeric - sliderMin) / stepValue) + 0.5) * stepValue)
				snapped = math.clamp(snapped, sliderMin, sliderMax)
				if decimals > 0 then
					local power = 10 ^ decimals
					snapped = math.floor((snapped * power) + 0.5) / power
				else
					snapped = math.floor(snapped + 0.5)
				end
				return snapped
			end
			local function formatNumber(raw)
				local numeric = tonumber(raw) or 0
				if decimals > 0 then
					return string.format("%." .. decimals .. "f", numeric)
				end
				return tostring(math.floor(numeric + 0.5))
			end

			local sliderFrame = Instance.new("Frame")
			local sliderFolder = Instance.new("Folder")
			local textboxFolderLayout = Instance.new("UIListLayout")
			local sliderButton = Instance.new("TextButton")
			local sliderButtonCorner = Instance.new("UICorner")
			local sliderBackground = Instance.new("Frame")
			local sliderButtonCorner_2 = Instance.new("UICorner")
			local sliderBackgroundLayout = Instance.new("UIListLayout")
			local sliderIndicator = Instance.new("Frame")
			local sliderIndicatorStraint = Instance.new("UISizeConstraint")
			local sliderIndicatorGradient = Instance.new("UIGradient")
			local sliderIndicatorCorner = Instance.new("UICorner")
			local sliderBackgroundPadding = Instance.new("UIPadding")
			local sliderButtonLayout = Instance.new("UIListLayout")
			local sliderLabel = Instance.new("TextLabel")
			local sliderPadding = Instance.new("UIPadding")
			local sliderValue = Instance.new("TextLabel")

			sliderFrame.Parent = page
			sliderFrame.BackgroundColor3 = Color3.fromRGB(25,25,25)
			sliderFrame.BackgroundTransparency = 1.000
			sliderFrame.ClipsDescendants = true
			sliderFrame.Position = UDim2.new(0.00499999989, 0, 0.667630076, 0)
			sliderFrame.Size = UDim2.new(0, 394, 0, 40)

			sliderFolder.Parent = sliderFrame

			textboxFolderLayout.Parent = sliderFolder
			textboxFolderLayout.FillDirection = Enum.FillDirection.Horizontal
			textboxFolderLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			textboxFolderLayout.SortOrder = Enum.SortOrder.LayoutOrder
			textboxFolderLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
			textboxFolderLayout.Padding = UDim.new(0, 4)

			sliderButton.Parent = sliderFolder
			sliderButton.BackgroundColor3 = library.darkGray
			sliderButton.BackgroundTransparency = library.transparency
			sliderButton.Position = UDim2.new(0.348484844, 0, 0.600000024, 0)
			sliderButton.Size = UDim2.new(0, 394, 0, 16)
			sliderButton.AutoButtonColor = false
			sliderButton.Font = library.Font
			sliderButton.Text = ""
			sliderButton.TextColor3 = Color3.fromRGB(0, 0, 0)
			sliderButton.TextSize = 14.000

			sliderButtonCorner.CornerRadius = UDim.new(0, 2)
			sliderButtonCorner.Parent = sliderButton

			sliderBackground.Parent = sliderButton
			sliderBackground.BackgroundColor3 = library.darkGray
			sliderBackground.BackgroundTransparency = library.transparency
			sliderBackground.Size = UDim2.new(0, 392, 0, 14)
			sliderBackground.Position = UDim2.new(0, 2, 0, 0)
			sliderBackground.ClipsDescendants = true

			sliderButtonCorner_2.CornerRadius = UDim.new(0, 2)
			sliderButtonCorner_2.Parent = sliderBackground

			sliderBackgroundLayout.Parent = sliderBackground
			sliderBackgroundLayout.SortOrder = Enum.SortOrder.LayoutOrder
			sliderBackgroundLayout.VerticalAlignment = Enum.VerticalAlignment.Center

			sliderIndicator.Parent = sliderBackground
			sliderIndicator.BorderSizePixel = 0
			sliderIndicator.Position = UDim2.new(0, 0, -0.1, 0)
			sliderIndicator.Size = UDim2.new(0, 0, 0, 12)
			sliderIndicator.BackgroundColor3 = library.acientColor

			sliderIndicatorStraint.Parent = sliderIndicator
			sliderIndicatorStraint.MaxSize = Vector2.new(392, 12)

			sliderIndicatorGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,255,255)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(181, 181, 181))}
			sliderIndicatorGradient.Rotation = 90
			sliderIndicatorGradient.Parent = sliderIndicator

			sliderIndicatorCorner.CornerRadius = UDim.new(0, 2)
			sliderIndicatorCorner.Parent = sliderIndicator

			sliderBackgroundPadding.Parent = sliderBackground
			sliderBackgroundPadding.PaddingBottom = UDim.new(0, 2)
			sliderBackgroundPadding.PaddingLeft = UDim.new(0, 1)
			sliderBackgroundPadding.PaddingRight = UDim.new(0, 1)
			sliderBackgroundPadding.PaddingTop = UDim.new(0, 2)

			sliderButtonLayout.Parent = sliderButton
			sliderButtonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			sliderButtonLayout.SortOrder = Enum.SortOrder.LayoutOrder
			sliderButtonLayout.VerticalAlignment = Enum.VerticalAlignment.Center

			sliderLabel.Parent = sliderFrame
			sliderLabel.BackgroundTransparency = 1.000
			sliderLabel.Size = UDim2.new(0, 396, 0, 24)
			sliderLabel.Font = library.Font
			sliderLabel.Text = text
			sliderLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			sliderLabel.TextSize = 14.000
			sliderLabel.TextWrapped = true
			sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
			sliderLabel.RichText = true

			sliderPadding.Parent = sliderLabel
			sliderPadding.PaddingBottom = UDim.new(0, 6)
			sliderPadding.PaddingLeft = UDim.new(0, 2)
			sliderPadding.PaddingRight = UDim.new(0, 6)
			sliderPadding.PaddingTop = UDim.new(0, 6)

			sliderValue.Parent = sliderLabel
			sliderValue.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			sliderValue.BackgroundTransparency = 1.000
			sliderValue.Position = UDim2.new(0.577319562, 0, 0, 0)
			sliderValue.Size = UDim2.new(0, 169, 0, 15)
			sliderValue.Font = library.Font
			sliderValue.Text = values.default or ""
			sliderValue.TextColor3 = Color3.fromRGB(140, 140, 140)
			sliderValue.TextSize = 14.000
			sliderValue.TextXAlignment = Enum.TextXAlignment.Right


			local calc1 = values.max - values.min
			local calc2 = values.default - values.min
			local calc3 = calc2 / calc1
			local calc4 = calc3 * sliderBackground.AbsoluteSize.X
			sliderIndicator.Size = UDim2.new(0, calc4, 0, 12)
			sliderValue.Text = values.default

			TweenWrapper:CreateStyle("slider_drag", 0.05, Enum.EasingStyle.Linear)

			local ValueNum = quantize(values.default)
			local slideText = compare and formatNumber(ValueNum) .. compareSign .. tostring(values.max - 1) .. suffix or formatNumber(ValueNum) .. suffix
			sliderValue.Text = slideText
			local function UpdateSlider()
				TweenService:Create(sliderIndicator, TweenWrapper.Styles["slider_drag"], {Size = UDim2.new(0, math.clamp(Mouse.X - sliderIndicator.AbsolutePosition.X, 0, sliderBackground.AbsoluteSize.X), 0, 12)}):Play()

				ValueNum = quantize((((tonumber(values.max) - tonumber(values.min)) / sliderBackground.AbsoluteSize.X) * sliderIndicator.AbsoluteSize.X) + tonumber(values.min))

				local slideText = compare and formatNumber(ValueNum) .. compareSign .. tostring(values.max - 1) .. suffix or formatNumber(ValueNum) .. suffix

				sliderValue.Text = slideText

				pcall(function()
					callback(ValueNum)
				end)

				sliderValue.Text = slideText

				moveconnection = Mouse.Move:Connect(function()
					ValueNum = quantize((((tonumber(values.max) - tonumber(values.min)) / sliderBackground.AbsoluteSize.X) * sliderIndicator.AbsoluteSize.X) + tonumber(values.min))

					slideText = compare and formatNumber(ValueNum) .. compareSign .. tostring(values.max - 1) .. suffix or formatNumber(ValueNum) .. suffix
					sliderValue.Text = slideText

					pcall(function()
						callback(ValueNum)
					end)

					TweenService:Create(sliderIndicator, TweenWrapper.Styles["slider_drag"], {Size = UDim2.new(0, math.clamp(Mouse.X - sliderIndicator.AbsolutePosition.X, 0, sliderBackground.AbsoluteSize.X), 0, 12)}):Play()
					if not UserInputService.WindowFocused then
						moveconnection:Disconnect()
					end
				end)

				releaseconnection = UserInputService.InputEnded:Connect(function(Mouse_2)
					if Mouse_2.UserInputType == Enum.UserInputType.MouseButton1 then
						ValueNum = quantize((((tonumber(values.max) - tonumber(values.min)) / sliderBackground.AbsoluteSize.X) * sliderIndicator.AbsoluteSize.X) + tonumber(values.min))

						slideText = compare and formatNumber(ValueNum) .. compareSign .. tostring(values.max - 1) .. suffix or formatNumber(ValueNum) .. suffix
						sliderValue.Text = slideText

						pcall(function()
							callback(ValueNum)
						end)
						if library.AutoSave then
							library:SaveConfig()
						end

						TweenService:Create(sliderIndicator, TweenWrapper.Styles["slider_drag"], {Size = UDim2.new(0, math.clamp(Mouse.X - sliderIndicator.AbsolutePosition.X, 0, sliderBackground.AbsoluteSize.X), 0, 12)}):Play()
						moveconnection:Disconnect()
						releaseconnection:Disconnect()
					end
				end)
			end

			sliderButton.MouseButton1Down:Connect(function()
				UpdateSlider()
			end)



			local SliderFunctions = {}
			OptionStates[sliderButton] = {values.default, SliderFunctions}

			function SliderFunctions:Set(new, NoCallBack)
				new = quantize(new)
				local ncalc1 = new - values.min
				local ncalc2 = ncalc1 / calc1
				local ncalc3 = ncalc2 * sliderBackground.AbsoluteSize.X
				local nCalculation = ncalc3
				sliderIndicator.Size = UDim2.new(0, nCalculation, 0, 12)
				slideText = compare and formatNumber(new) .. compareSign .. tostring(values.max - 1) .. suffix or formatNumber(new) .. suffix
				ValueNum = new
				sliderValue.Text = slideText
				if not NoCallBack then
					callback(new)
					if library.AutoSave then
						library:SaveConfig()
					end
				end
				return self
			end
			SliderFunctions:Set(values.default, true)

			function SliderFunctions:Max(new)
				new = new or values.max
				values.max = new + 1
				sliderMax = tonumber(new) or sliderMax
				slideText = compare and formatNumber(ValueNum) .. compareSign .. tostring(values.max - 1) .. suffix or formatNumber(ValueNum) .. suffix
				return self
			end

			function SliderFunctions:Min(new)
				new = new or values.min
				values.min = new
				sliderMin = tonumber(new) or sliderMin
				slideText = compare and formatNumber(new) .. compareSign .. tostring(values.max - 1) .. suffix or formatNumber(ValueNum) .. suffix
				TweenService:Create(sliderIndicator, TweenWrapper.Styles["slider_drag"], {Size = UDim2.new(0, math.clamp(Mouse.X - sliderIndicator.AbsolutePosition.X, 0, sliderBackground.AbsoluteSize.X), 0, 12)}):Play()
				return self
			end

			function SliderFunctions:SetFunction(new)
				new = new or callback
				callback = new
				return self
			end

			function SliderFunctions:GetValue()
				return ValueNum
			end

			function SliderFunctions:SetText(new)
				new = new or sliderLabel.Text
				sliderLabel.Text = new
				return self
			end

			function SliderFunctions:Hide()
				sliderFrame.Visible = false
				return self
			end

			function SliderFunctions:Show()
				sliderFrame.Visible = true
				return self
			end

			function SliderFunctions:Remove()
				SavedControls.Sliders[controlKey] = nil
				sliderFrame:Destroy()
				return self
			end
			SavedControls.Sliders[controlKey] = SliderFunctions
			return SliderFunctions
		end

		function Components:NewSeperator()
			local sectionFrame = Instance.new("Frame")
			local sectionLayout = Instance.new("UIListLayout")
			local rightBar = Instance.new("Frame")

			sectionFrame.Name = "sectionFrame"
			sectionFrame.Parent = page
			sectionFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			sectionFrame.BackgroundTransparency = 1.000
			sectionFrame.ClipsDescendants = true
			sectionFrame.Position = UDim2.new(0.00499999989, 0, 0.361271679, 0)
			sectionFrame.Size = UDim2.new(0, 396, 0, 12)

			sectionLayout.Name = "sectionLayout"
			sectionLayout.Parent = sectionFrame
			sectionLayout.FillDirection = Enum.FillDirection.Horizontal
			sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
			sectionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			sectionLayout.Padding = UDim.new(0, 4)

			rightBar.Name = "rightBar"
			rightBar.Parent = sectionFrame
			rightBar.BackgroundColor3 = library.darkGray
			rightBar.BackgroundTransparency = library.transparency
			rightBar.BorderSizePixel = 0
			rightBar.Position = UDim2.new(0.308080822, 0, 0.479166657, 0)
			rightBar.Size = UDim2.new(0, 403, 0, 1)



			local SeperatorFunctions = {}
			function SeperatorFunctions:Hide()
				sectionFrame.Visible = false
				return SeperatorFunctions
			end

			function SeperatorFunctions:Show()
				sectionFrame.Visible = true
				return SeperatorFunctions
			end

			function SeperatorFunctions:Remove()
				sectionFrame:Destroy()
				return SeperatorFunctions
			end
			return SeperatorFunctions
		end

		function Components:AddConfigControls(queueSource)
			if type(queueSource) == "string" and queueSource ~= "" then
				library:SetQueueOnTeleportScript(queueSource)
			end

			if self._configControlsAdded then
				return self
			end
			self._configControlsAdded = true

			local selectedConfig = library.SelectedConfig or library.ConfigFile
			local function configExists(name)
				local normalized = library:NormalizeConfigName(name)
				if not normalized then
					return false
				end
				if type(isfile) == "function" then
					local path = library:ConfigPath(normalized)
					if path then
						local okExists, exists = pcall(isfile, path)
						if okExists then
							return exists == true
						end
					end
				end
				return type(library:ReadConfig(normalized)) == "table"
			end
			local configNames = library:GetConfigList()
			local foundSelected = false
			for _, name in ipairs(configNames) do
				if name == selectedConfig then
					foundSelected = true
					break
				end
			end
			if not foundSelected and selectedConfig then
				table.insert(configNames, 1, selectedConfig)
			end

			local themeNames = library:GetThemeNames()
			local selectedTheme = library.CurrentThemeName or themeNames[1]
			local currentAutoload = library:GetAutoloadConfigName()

			if type(self.AddLeftGroupbox) == "function" and type(self.AddRightGroupbox) == "function" then
				local profiles = self:AddLeftGroupbox("Profiles")
				local configDropdown = profiles:AddDropdown("Config", configNames, selectedConfig or "default.json", function(choice)
					selectedConfig = library:NormalizeConfigName(choice) or selectedConfig
					library:SetActiveConfig(selectedConfig)
				end)
				local configNameInput = profiles:AddTextbox(
					"Name",
					(selectedConfig or "default.json"):gsub("%.json$", ""),
					"new_profile",
					function(textValue)
						local normalized = library:NormalizeConfigName(textValue)
						if normalized then
							selectedConfig = normalized
							library:SetActiveConfig(selectedConfig)
						end
					end
				)
				local function syncConfigNameInput()
					if configNameInput and type(configNameInput.GetValue) == "function" then
						local normalized = library:NormalizeConfigName(configNameInput:GetValue())
						if normalized then
							selectedConfig = normalized
							library:SetActiveConfig(selectedConfig)
						end
					end
				end
				profiles:AddButton("Create New", function()
					syncConfigNameInput()
					if configExists(selectedConfig) then
						library:Notify("Config already exists. Use Overwrite Config.", 2.4, "error")
						return
					end
					local ok = library:SaveConfig(selectedConfig)
					if ok and configDropdown and type(configDropdown.AddOption) == "function" then
						configDropdown:AddOption(selectedConfig)
						if type(configDropdown.Set) == "function" then
							configDropdown:Set(selectedConfig)
						end
					end
					library:Notify(ok and ("Created " .. tostring(library.ConfigFile)) or "Create failed", 2, ok and "success" or "error")
				end)
				profiles:AddButton("Overwrite Config", function()
					syncConfigNameInput()
					local ok = library:SaveConfig(selectedConfig)
					if ok and configDropdown and type(configDropdown.AddOption) == "function" then
						configDropdown:AddOption(selectedConfig)
						if type(configDropdown.Set) == "function" then
							configDropdown:Set(selectedConfig)
						end
					end
					library:Notify(ok and ("Overwrote " .. tostring(library.ConfigFile)) or "Overwrite failed", 2, ok and "success" or "error")
				end)
				profiles:AddButton("Load Selected", function()
					syncConfigNameInput()
					local ok = library:LoadConfig(selectedConfig)
					if ok and configDropdown and type(configDropdown.Set) == "function" then
						configDropdown:Set(selectedConfig)
					end
					library:Notify(ok and ("Loaded " .. tostring(library.ConfigFile)) or "Load failed", 2, ok and "success" or "error")
				end)
				local autoloadNote = profiles:AddNote("Autoload: " .. tostring(currentAutoload or "Disabled"))
				profiles:AddButton("Set Selected As Autoload", function()
					local ok = library:SetAutoloadConfig(selectedConfig)
					currentAutoload = ok and selectedConfig or currentAutoload
					if autoloadNote and type(autoloadNote.SetText) == "function" then
						autoloadNote:SetText("Autoload: " .. tostring(currentAutoload or "Disabled"))
					end
					library:Notify(ok and ("Autoload set: " .. tostring(selectedConfig)) or "Failed to set autoload", 2, ok and "success" or "error")
				end)
				profiles:AddButton("Disable Autoload", function()
					local ok = library:DisableAutoloadConfig()
					if ok then
						currentAutoload = nil
					end
					if autoloadNote and type(autoloadNote.SetText) == "function" then
						autoloadNote:SetText("Autoload: " .. tostring(currentAutoload or "Disabled"))
					end
					library:Notify(ok and "Autoload disabled" or "Failed to disable autoload", 2, ok and "success" or "error")
				end)

				local themes = self:AddRightGroupbox("Appearance")
				themes:AddDropdown("Theme", themeNames, selectedTheme, function(themeName)
					selectedTheme = themeName
					if library:ApplyTheme(themeName) then
						library:Notify("Theme applied: " .. tostring(themeName), 2, "success")
					end
				end)
				themes:AddButton("Set Default Theme", function()
					local ok = library:SetDefaultTheme(selectedTheme)
					library:Notify(ok and ("Default theme set: " .. tostring(selectedTheme)) or "Default theme save failed", 2, ok and "success" or "error")
				end)

				local controls = self:AddRightGroupbox("Menu / Server")
				controls:AddKeybind("Menu Key", library.Key or Enum.KeyCode.RightShift, function(boundKey)
					if typeof(boundKey) == "EnumItem" then
						library:SetKeybind(boundKey)
						library:Notify("Menu key set to " .. tostring(boundKey.Name), 2, "success")
					end
				end, { Minimal = true, Compact = true, BindWidthScale = 0.29 })
				controls:AddButton("Server Hop (Skip Autoload)", function()
					library:ServerHop()
				end)
				return self
			end

			-- Fallback single-column config controls.
			self:NewSection("Config Profiles")
			local configDropdown = self:NewDropdown("Config", selectedConfig or "default.json", configNames, function(choice)
				selectedConfig = library:NormalizeConfigName(choice) or selectedConfig
				library:SetActiveConfig(selectedConfig)
			end)
			self:NewTextbox("Config Name", (selectedConfig or "default.json"):gsub("%.json$", ""), "new_profile", "small", true, false, function(textValue)
				local normalized = library:NormalizeConfigName(textValue)
				if normalized then
					selectedConfig = normalized
					library:SetActiveConfig(selectedConfig)
				end
			end)
			self:NewButton("Create New", function()
				if configExists(selectedConfig) then
					library:Notify("Config already exists. Use Overwrite Config.", 2.4, "error")
					return
				end
				local ok = library:SaveConfig(selectedConfig)
				if ok and configDropdown and type(configDropdown.AddOption) == "function" then
					configDropdown:AddOption(selectedConfig)
					if type(configDropdown.Set) == "function" then
						configDropdown:Set(selectedConfig)
					end
				end
				library:Notify(ok and ("Created " .. tostring(library.ConfigFile)) or "Create failed", 2, ok and "success" or "error")
			end)
			self:NewButton("Overwrite Config", function()
				local ok = library:SaveConfig(selectedConfig)
				if ok and configDropdown and type(configDropdown.AddOption) == "function" then
					configDropdown:AddOption(selectedConfig)
					if type(configDropdown.Set) == "function" then
						configDropdown:Set(selectedConfig)
					end
				end
				library:Notify(ok and ("Overwrote " .. tostring(library.ConfigFile)) or "Overwrite failed", 2, ok and "success" or "error")
			end)
			self:NewButton("Load Selected", function()
				local ok = library:LoadConfig(selectedConfig)
				library:Notify(ok and ("Loaded " .. tostring(library.ConfigFile)) or "Load failed", 2, ok and "success" or "error")
			end)
			local autoloadNote = self:NewNote("Autoload: " .. tostring(currentAutoload or "Disabled"))
			self:NewButton("Set Selected As Autoload", function()
				local ok = library:SetAutoloadConfig(selectedConfig)
				currentAutoload = ok and selectedConfig or currentAutoload
				if autoloadNote and type(autoloadNote.SetText) == "function" then
					autoloadNote:SetText("Autoload: " .. tostring(currentAutoload or "Disabled"))
				end
				library:Notify(ok and ("Autoload set: " .. tostring(selectedConfig)) or "Failed to set autoload", 2, ok and "success" or "error")
			end)
			self:NewButton("Disable Autoload", function()
				local ok = library:DisableAutoloadConfig()
				if ok then
					currentAutoload = nil
				end
				if autoloadNote and type(autoloadNote.SetText) == "function" then
					autoloadNote:SetText("Autoload: " .. tostring(currentAutoload or "Disabled"))
				end
				library:Notify(ok and "Autoload disabled" or "Failed to disable autoload", 2, ok and "success" or "error")
			end)

			self:NewSection("Themes")
			self:NewDropdown("Theme", selectedTheme, themeNames, function(themeName)
				selectedTheme = themeName
				if library:ApplyTheme(themeName) then
					library:Notify("Theme applied: " .. tostring(themeName), 2, "success")
				end
			end)
			self:NewButton("Set Default Theme", function()
				local ok = library:SetDefaultTheme(selectedTheme)
				library:Notify(ok and ("Default theme set: " .. tostring(selectedTheme)) or "Default theme save failed", 2, ok and "success" or "error")
			end)

			self:NewSection("Menu Keybind")
			self:NewKeybind("Toggle Key", library.Key or Enum.KeyCode.RightShift, function(chosenKey)
				local enumKey = nil
				if typeof(chosenKey) == "EnumItem" then
					enumKey = chosenKey
				elseif type(chosenKey) == "string" then
					enumKey = library:ResolveKeyCode(chosenKey)
				end
				if enumKey then
					library:SetKeybind(enumKey)
					library:Notify("Menu key set to " .. tostring(enumKey.Name), 2, "success")
				end
			end)

			self:NewSection("Server")
			self:NewButton("Server Hop (Skip Autoload)", function()
				library:ServerHop()
			end)

			return self
		end

		function Components:AddRandomControls(toggleCount, sliderCount)
			local tCount = math.max(0, math.floor(tonumber(toggleCount) or 0))
			local sCount = math.max(0, math.floor(tonumber(sliderCount) or 0))

			if tCount > 0 then
				self:NewSection("Random Toggles")
			end
			for i = 1, tCount do
				self:NewToggle("Random Toggle " .. tostring(i), math.random() > 0.5, function() end)
			end

			if sCount > 0 then
				self:NewSection("Random Sliders")
			end
			for i = 1, sCount do
				self:NewSlider(
					"Random Slider " .. tostring(i),
					"",
					false,
					"/",
					{ min = 0, max = 100, default = math.random(0, 100) },
					function() end
				)
			end

			return self
		end

		local function createSideSection(sideParent, sectionTitle)
			sideSectionsHost.Visible = true
			local isRightSide = sideParent == rightSections
			local groupName = tostring(sectionTitle or "Section")
			local groupKey = tostring(title):lower():gsub("%s+", "_") .. "::" .. groupName:lower():gsub("%s+", "_")

			local holder = Instance.new("Frame")
			holder.Parent = sideParent
			holder.BackgroundTransparency = 1
			holder.BorderSizePixel = 0
			holder.Size = UDim2.new(1, 0, 0, 0)
			holder.AutomaticSize = Enum.AutomaticSize.Y

			local group = Instance.new("Frame")
			group.Parent = holder
			group.BackgroundColor3 = library.backgroundColor
			group.BackgroundTransparency = 1
			group.BorderSizePixel = 0
			group.AnchorPoint = isRightSide and Vector2.new(1, 0) or Vector2.new(0, 0)
			group.Position = isRightSide and UDim2.new(1, 10, 0, 0) or UDim2.new(0, -10, 0, 0)
			group.Size = UDim2.new(1, 0, 0, 0)
			group.AutomaticSize = Enum.AutomaticSize.Y
			group.ClipsDescendants = true
			Instance.new("UICorner", group).CornerRadius = UDim.new(0, 3)
			local gStroke = Instance.new("UIStroke", group)
			gStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			gStroke.Thickness = 1
			gStroke.Color = library.lightGray
			gStroke.Transparency = 1

			local gTitle = Instance.new("TextLabel")
			gTitle.Parent = group
			gTitle.BackgroundTransparency = 1
			gTitle.Position = UDim2.new(0, 6, 0, 0)
			gTitle.Size = UDim2.new(1, -12, 0, 22)
			gTitle.Font = library.Font
			gTitle.Text = groupName
			gTitle.TextColor3 = Color3.fromRGB(190, 190, 190)
			gTitle.TextSize = 13
			gTitle.TextXAlignment = Enum.TextXAlignment.Left
			gTitle.TextTransparency = 1

			local titleDivider = Instance.new("Frame")
			titleDivider.Parent = group
			titleDivider.BorderSizePixel = 0
			titleDivider.BackgroundColor3 = library.lightGray
			titleDivider.BackgroundTransparency = 1
			titleDivider.Position = UDim2.new(0, 6, 0, 22)
			titleDivider.Size = UDim2.new(1, -12, 0, 1)

			local body = Instance.new("Frame")
			body.Parent = group
			body.BackgroundTransparency = 1
			body.Position = UDim2.new(0, 4, 0, 30)
			body.Size = UDim2.new(1, -8, 0, 0)
			body.AutomaticSize = Enum.AutomaticSize.Y

			local bodyPadding = Instance.new("UIPadding")
			bodyPadding.Parent = body
			bodyPadding.PaddingBottom = UDim.new(0, 2)
			bodyPadding.PaddingLeft = UDim.new(0, 2)
			bodyPadding.PaddingRight = UDim.new(0, 2)
			bodyPadding.PaddingTop = UDim.new(0, 2)

			local bodyLayout = Instance.new("UIListLayout")
			bodyLayout.Parent = body
			bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
			bodyLayout.Padding = UDim.new(0, 4)

			local function refreshSideLayout()
				task.defer(updateSideSectionsHostHeight)
			end

			local function createRow(height)
				local row = Instance.new("Frame")
				row.Parent = body
				row.BackgroundColor3 = library.darkGray
				row.BackgroundTransparency = 0.08
				row.BorderSizePixel = 0
				row.Size = UDim2.new(1, 0, 0, height)
				Instance.new("UICorner", row).CornerRadius = UDim.new(0, 2)
				local stroke = Instance.new("UIStroke", row)
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				stroke.Thickness = 1
				stroke.Color = library.lightGray
				stroke.Transparency = 0.62
				row.MouseEnter:Connect(function()
					TweenService:Create(row, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundTransparency = 0.03,
					}):Play()
				end)
				row.MouseLeave:Connect(function()
					TweenService:Create(row, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundTransparency = 0.08,
					}):Play()
				end)
				refreshSideLayout()
				task.spawn(function()
					RunService.Heartbeat:Wait()
					refreshSideLayout()
				end)
				return row
			end

			local Section = {}

			function Section:AddLabel(textValue)
				local row = createRow(22)
				local label = Instance.new("TextLabel")
				label.Parent = row
				label.BackgroundTransparency = 1
				label.Position = UDim2.new(0, 6, 0, 0)
				label.Size = UDim2.new(1, -12, 1, 0)
				label.Font = library.Font
				label.Text = tostring(textValue or "")
				label.TextColor3 = Color3.fromRGB(190, 190, 190)
				label.TextSize = 13
				label.TextXAlignment = Enum.TextXAlignment.Left
				return Section
			end

			function Section:AddNote(textValue)
				local row = Instance.new("Frame")
				row.Parent = body
				row.BackgroundTransparency = 1
				row.BorderSizePixel = 0
				row.Size = UDim2.new(1, 0, 0, 18)

				local label = Instance.new("TextLabel")
				label.Parent = row
				label.BackgroundTransparency = 1
				label.Position = UDim2.new(0, 2, 0, 0)
				label.Size = UDim2.new(1, -4, 1, 0)
				label.Font = library.Font
				label.Text = tostring(textValue or "")
				label.TextColor3 = Color3.fromRGB(145, 145, 145)
				label.TextSize = 12
				label.TextXAlignment = Enum.TextXAlignment.Left
				label.TextTruncate = Enum.TextTruncate.AtEnd

				refreshSideLayout()

				local NoteFunctions = {}
				function NoteFunctions:SetText(newText)
					label.Text = tostring(newText or "")
					return self
				end
				function NoteFunctions:Hide()
					row.Visible = false
					refreshSideLayout()
					return self
				end
				function NoteFunctions:Show()
					row.Visible = true
					refreshSideLayout()
					return self
				end
				function NoteFunctions:Remove()
					row:Destroy()
					refreshSideLayout()
					return self
				end
				return NoteFunctions
			end

			function Section:AddButton(textValue, callback)
				local row = createRow(24)
				local button = Instance.new("TextButton")
				button.Parent = row
				button.BackgroundColor3 = library.darkGray
				button.BackgroundTransparency = 0.08
				button.Size = UDim2.new(1, 0, 1, 0)
				button.Font = library.Font
				button.Text = tostring(textValue or "Button")
				button.TextColor3 = Color3.fromRGB(190, 190, 190)
				button.TextSize = 13
				button.AutoButtonColor = true
				button.BorderSizePixel = 0
				Instance.new("UICorner", button).CornerRadius = UDim.new(0, 2)
				button.Activated:Connect(function()
					if type(callback) == "function" then
						callback()
					end
				end)
				return Section
			end

			function Section:AddToggle(textValue, defaultValue, callback)
				local key = "toggle::" .. groupKey .. "::" .. tostring(textValue or "toggle"):lower():gsub("%s+", "_")
				local loadedValue = library.LoadedConfig and library.LoadedConfig[key]
				local state = loadedValue ~= nil and (loadedValue == true) or (defaultValue == true)

				local row = createRow(22)
				local button = Instance.new("TextButton")
				button.Parent = row
				button.BackgroundTransparency = 1
				button.Size = UDim2.new(1, 0, 1, 0)
				button.Text = ""
				button.AutoButtonColor = false

				local box = Instance.new("Frame")
				box.Parent = row
				box.BackgroundColor3 = library.darkGray
				box.Position = UDim2.new(0, 2, 0, 2)
				box.Size = UDim2.new(0, 18, 0, 18)
				box.BorderSizePixel = 0
				Instance.new("UICorner", box).CornerRadius = UDim.new(0, 2)
				local boxStroke = Instance.new("UIStroke", box)
				boxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				boxStroke.Thickness = 1
				boxStroke.Color = library.lightGray

				local fill = Instance.new("Frame")
				fill.Parent = box
				fill.AnchorPoint = Vector2.new(0.5, 0.5)
				fill.Position = UDim2.new(0.5, 0, 0.5, 0)
				fill.Size = state and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 0, 0, 0)
				fill.BackgroundColor3 = library.acientColor
				fill.BackgroundTransparency = state and 0 or 1
				fill.BorderSizePixel = 0
				Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 2)

				local label = Instance.new("TextLabel")
				label.Parent = row
				label.BackgroundTransparency = 1
				label.Position = UDim2.new(0, 24, 0, 0)
				label.Size = UDim2.new(1, -24, 1, 0)
				label.Font = library.Font
				label.Text = tostring(textValue or "Toggle")
				label.TextColor3 = Color3.fromRGB(190, 190, 190)
				label.TextSize = 13
				label.TextXAlignment = Enum.TextXAlignment.Left

				local ToggleFunctions = {}
				function ToggleFunctions:GetValue()
					return state
				end
				function ToggleFunctions:Set(newState)
					state = newState == true
					local sizeTarget = state and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 0, 0, 0)
					local alphaTarget = state and 0 or 1
					TweenService:Create(fill, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = sizeTarget,
						BackgroundTransparency = alphaTarget,
					}):Play()
					if type(callback) == "function" then
						callback(state)
					end
					if library.AutoSave then
						library:SaveConfig()
					end
					return ToggleFunctions
				end
				button.Activated:Connect(function()
					ToggleFunctions:Set(not state)
				end)
				SavedControls.Toggles[key] = ToggleFunctions
				return ToggleFunctions
			end

			function Section:AddSlider(textValue, minValue, maxValue, defaultValue, callback, stepValue)
				local minV = tonumber(minValue) or 0
				local maxV = tonumber(maxValue) or 100
				if maxV < minV then
					minV, maxV = maxV, minV
				end
				local stepV = math.abs(tonumber(stepValue) or 1)
				if stepV <= 0 then
					stepV = 1
				end
				local stepText = tostring(stepV)
				local dotIndex = stepText:find("%.")
				local decimalPlaces = 0
				if dotIndex then
					decimalPlaces = math.min(4, #stepText - dotIndex)
				end
				local key = "slider::" .. groupKey .. "::" .. tostring(textValue or "slider"):lower():gsub("%s+", "_")
				local loadedValue = library.LoadedConfig and library.LoadedConfig[key]
				local function snapValue(raw)
					local numeric = math.clamp(tonumber(raw) or minV, minV, maxV)
					local snapped = minV + (math.floor(((numeric - minV) / stepV) + 0.5) * stepV)
					snapped = math.clamp(snapped, minV, maxV)
					if decimalPlaces > 0 then
						local power = 10 ^ decimalPlaces
						snapped = math.floor((snapped * power) + 0.5) / power
					else
						snapped = math.floor(snapped + 0.5)
					end
					return snapped
				end
				local function formatValue(raw)
					local numeric = tonumber(raw) or 0
					if decimalPlaces > 0 then
						return string.format("%." .. decimalPlaces .. "f", numeric)
					end
					return tostring(math.floor(numeric + 0.5))
				end
				local value = snapValue(tonumber(loadedValue) or tonumber(defaultValue) or minV)

				local row = createRow(38)
				local label = Instance.new("TextLabel")
				label.Parent = row
				label.BackgroundTransparency = 1
				label.Position = UDim2.new(0, 6, 0, 0)
				label.Size = UDim2.new(1, -12, 0, 18)
				label.Font = library.Font
				label.Text = tostring(textValue or "Slider")
				label.TextColor3 = Color3.fromRGB(190, 190, 190)
				label.TextSize = 13
				label.TextXAlignment = Enum.TextXAlignment.Left

				local valueLabel = Instance.new("TextLabel")
				valueLabel.Parent = label
				valueLabel.BackgroundTransparency = 1
				valueLabel.AnchorPoint = Vector2.new(1, 0)
				valueLabel.Position = UDim2.new(1, 0, 0, 0)
				valueLabel.Size = UDim2.new(0, 80, 1, 0)
				valueLabel.Font = library.Font
				valueLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
				valueLabel.TextSize = 12
				valueLabel.TextXAlignment = Enum.TextXAlignment.Right

				local bar = Instance.new("TextButton")
				bar.Parent = row
				bar.AutoButtonColor = false
				bar.Text = ""
				bar.BackgroundColor3 = library.darkGray
				bar.Position = UDim2.new(0, 6, 0, 20)
				bar.Size = UDim2.new(1, -12, 0, 14)
				bar.BorderSizePixel = 0
				Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)
				local barStroke = Instance.new("UIStroke", bar)
				barStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				barStroke.Thickness = 1
				barStroke.Color = library.lightGray

				local fill = Instance.new("Frame")
				fill.Parent = bar
				fill.BackgroundColor3 = library.acientColor
				fill.BorderSizePixel = 0
				fill.Size = UDim2.new(0, 0, 1, 0)
				Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 2)

				local function render()
					local scale = (value - minV) / math.max(maxV - minV, 1)
					TweenService:Create(fill, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = UDim2.new(math.clamp(scale, 0, 1), 0, 1, 0),
					}):Play()
					valueLabel.Text = formatValue(value)
				end

				local SliderFunctions = {}
				function SliderFunctions:GetValue()
					return value
				end
				function SliderFunctions:Set(newValue)
					value = snapValue(newValue)
					render()
					if type(callback) == "function" then
						callback(value)
					end
					if library.AutoSave then
						library:SaveConfig()
					end
					return SliderFunctions
				end

				local dragging = false
				bar.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						dragging = true
					end
				end)
				bar.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						dragging = false
					end
				end)
				UserInputService.InputChanged:Connect(function(input)
					if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
						local alpha = (Mouse.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1)
						SliderFunctions:Set(minV + (maxV - minV) * math.clamp(alpha, 0, 1))
					end
				end)

				render()
				SavedControls.Sliders[key] = SliderFunctions
				return SliderFunctions
			end

			function Section:AddDropdown(textValue, arg2, arg3, arg4, arg5)
				local values = {}
				local callback = nil
				local isMulti = false
				local selected = "None"
				local selectedMap = {}

				local function normalizeValue(raw)
					return tostring(raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
				end

				local function copySelectionMap(map)
					local out = {}
					for key, state in pairs(map or {}) do
						if state then
							out[tostring(key)] = true
						end
					end
					return out
				end

				local function normalizeSelectionMap(raw)
					local out = {}
					if type(raw) == "string" then
						local normalized = normalizeValue(raw)
						if normalized ~= "" then
							out[normalized] = true
						end
					elseif type(raw) == "table" then
						for key, entry in pairs(raw) do
							if type(key) == "number" then
								local normalized = normalizeValue(entry)
								if normalized ~= "" then
									out[normalized] = true
								end
							elseif entry then
								local normalized = normalizeValue(key)
								if normalized ~= "" then
									out[normalized] = true
								end
							end
						end
					end
					return out
				end

				if type(arg2) == "table" and (arg2.Values ~= nil or arg2.values ~= nil or arg2.Multi ~= nil or arg2.Callback ~= nil or arg2.Default ~= nil) then
					local spec = arg2
					values = type(spec.Values) == "table" and spec.Values or (type(spec.values) == "table" and spec.values or {})
					callback = type(spec.Callback) == "function" and spec.Callback or (type(arg3) == "function" and arg3 or nil)
					isMulti = spec.Multi == true
					if isMulti then
						selectedMap = normalizeSelectionMap(spec.Default)
					else
						selected = normalizeValue(spec.Default or values[1] or "None")
					end
				elseif type(arg2) == "table" then
					values = arg2
					callback = arg4
					local options = type(arg5) == "table" and arg5 or {}
					isMulti = options.Multi == true
					if isMulti then
						selectedMap = normalizeSelectionMap(arg3)
					else
						selected = normalizeValue(arg3 or values[1] or "None")
					end
				else
					values = type(arg3) == "table" and arg3 or {}
					callback = arg4
					local options = type(arg5) == "table" and arg5 or {}
					isMulti = options.Multi == true
					if isMulti then
						selectedMap = normalizeSelectionMap(arg2)
					else
						selected = normalizeValue(arg2 or values[1] or "None")
					end
				end

				local optionHeight = 20
				local baseHeight = 24
				local contentHeight = 0
				local expandedHeight = baseHeight
				local isOpen = false
				local optionButtons = {}
				local optionWidgets = {}
				local setOpen

				local row = createRow(baseHeight)
				row.ClipsDescendants = true

				local trigger = Instance.new("TextButton")
				trigger.Parent = row
				trigger.BackgroundTransparency = 1
				trigger.Position = UDim2.new(0, 0, 0, 0)
				trigger.Size = UDim2.new(1, 0, 0, baseHeight)
				trigger.Font = library.Font
				trigger.TextSize = 13
				trigger.TextColor3 = Color3.fromRGB(190, 190, 190)
				trigger.AutoButtonColor = false
				trigger.Text = ""

				local valueLabel = Instance.new("TextLabel")
				valueLabel.Parent = row
				valueLabel.BackgroundTransparency = 1
				valueLabel.Position = UDim2.new(0, 6, 0, 0)
				valueLabel.Size = UDim2.new(1, -28, 0, baseHeight)
				valueLabel.Font = library.Font
				valueLabel.TextSize = 13
				valueLabel.TextXAlignment = Enum.TextXAlignment.Left
				valueLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
				valueLabel.TextTruncate = Enum.TextTruncate.AtEnd

				local arrow = Instance.new("TextLabel")
				arrow.Parent = trigger
				arrow.BackgroundTransparency = 1
				arrow.AnchorPoint = Vector2.new(1, 0.5)
				arrow.Position = UDim2.new(1, -8, 0.5, 0)
				arrow.Size = UDim2.new(0, 14, 0, 14)
				arrow.Font = library.Font
				arrow.Text = ">"
				arrow.TextColor3 = Color3.fromRGB(160, 160, 160)
				arrow.TextSize = 13

				local optionsFrame = Instance.new("Frame")
				optionsFrame.Parent = row
				optionsFrame.BackgroundTransparency = 1
				optionsFrame.Position = UDim2.new(0, 0, 0, baseHeight)
				optionsFrame.Size = UDim2.new(1, 0, 0, 0)
				optionsFrame.ClipsDescendants = true

				local optionsLayout = Instance.new("UIListLayout")
				optionsLayout.Parent = optionsFrame
				optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder

				local function getSelectedNamesInOrder()
					local out = {}
					for _, optionName in ipairs(values) do
						if selectedMap[optionName] then
							table.insert(out, optionName)
						end
					end
					return out
				end

				local function recalcHeights()
					contentHeight = math.max(0, #values * optionHeight)
					expandedHeight = baseHeight + contentHeight
					if isOpen then
						row.Size = UDim2.new(1, 0, 0, expandedHeight)
						optionsFrame.Size = UDim2.new(1, 0, 0, contentHeight)
					end
					refreshSideLayout()
				end

				local function setText()
					if isMulti then
						local selectedNames = getSelectedNamesInOrder()
						local summary = "None"
						if #selectedNames == 1 then
							summary = selectedNames[1]
						elseif #selectedNames == 2 then
							summary = selectedNames[1] .. ", " .. selectedNames[2]
						elseif #selectedNames > 2 then
							summary = tostring(#selectedNames) .. " selected"
						end
						valueLabel.Text = tostring(textValue or "Dropdown") .. ": " .. summary
					else
						valueLabel.Text = tostring(textValue or "Dropdown") .. ": " .. tostring(selected or "None")
					end
				end

				local function updateOptionVisual(optionName)
					local widgets = optionWidgets[optionName]
					if not widgets then
						return
					end

					local optionButton = widgets.Button
					local optionLabel = widgets.Label
					local indicator = widgets.Indicator
					local indicatorStroke = widgets.IndicatorStroke
					local checkFill = widgets.CheckFill

					if isMulti then
						local enabled = selectedMap[optionName] == true
						TweenService:Create(optionButton, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							BackgroundTransparency = enabled and 0.92 or 1,
						}):Play()
						TweenService:Create(optionLabel, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							TextColor3 = enabled and library.acientColor or Color3.fromRGB(165, 165, 165),
						}):Play()
						if indicator then
							TweenService:Create(indicator, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								BackgroundTransparency = enabled and 0.7 or 1,
							}):Play()
						end
						if indicatorStroke then
							TweenService:Create(indicatorStroke, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								Transparency = enabled and 0.12 or 0.45,
							}):Play()
						end
						if checkFill then
							TweenService:Create(checkFill, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								Size = enabled and UDim2.new(0, 8, 0, 8) or UDim2.new(0, 0, 0, 0),
								BackgroundTransparency = enabled and 0 or 1,
							}):Play()
						end
					else
						local enabled = (selected == optionName)
						TweenService:Create(optionButton, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							BackgroundTransparency = enabled and 0.94 or 1,
						}):Play()
						TweenService:Create(optionLabel, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							TextColor3 = enabled and library.acientColor or Color3.fromRGB(165, 165, 165),
						}):Play()
					end
				end

				local function refreshAllOptionVisuals()
					for optionName in pairs(optionButtons) do
						updateOptionVisual(optionName)
					end
				end

				local function applySelection(newValue)
					selected = normalizeValue(newValue or selected or "None")
					refreshAllOptionVisuals()
					setText()
					if type(callback) == "function" then
						callback(selected)
					end
				end

				local function applyMultiSelection(newValue, fireCallback)
					local desired = normalizeSelectionMap(newValue)
					local sanitized = {}
					for _, optionName in ipairs(values) do
						if desired[optionName] then
							sanitized[optionName] = true
						end
					end
					selectedMap = sanitized
					refreshAllOptionVisuals()
					setText()
					if fireCallback and type(callback) == "function" then
						callback(copySelectionMap(selectedMap))
					end
				end

				local function addOptionButton(optionValue)
					local normalized = normalizeValue(optionValue)
					if normalized == "" or optionButtons[normalized] then
						return false
					end
					table.insert(values, normalized)

					local optionButton = Instance.new("TextButton")
					optionButton.Parent = optionsFrame
					optionButton.BackgroundColor3 = library.darkGray
					optionButton.BackgroundTransparency = 1
					optionButton.Size = UDim2.new(1, 0, 0, optionHeight)
					optionButton.AutoButtonColor = false
					optionButton.Text = ""
					optionButton.BorderSizePixel = 0
					Instance.new("UICorner", optionButton).CornerRadius = UDim.new(0, 2)

					local optionLabel = Instance.new("TextLabel")
					optionLabel.Parent = optionButton
					optionLabel.BackgroundTransparency = 1
					optionLabel.Position = UDim2.new(0, 8, 0, 0)
					optionLabel.Size = UDim2.new(1, isMulti and -30 or -10, 1, 0)
					optionLabel.Font = library.Font
					optionLabel.Text = normalized
					optionLabel.TextSize = 13
					optionLabel.TextXAlignment = Enum.TextXAlignment.Left
					optionLabel.TextColor3 = Color3.fromRGB(165, 165, 165)

					local indicator = nil
					local indicatorStroke = nil
					local checkFill = nil
					if isMulti then
						indicator = Instance.new("Frame")
						indicator.Parent = optionButton
						indicator.AnchorPoint = Vector2.new(1, 0.5)
						indicator.Position = UDim2.new(1, -8, 0.5, 0)
						indicator.Size = UDim2.new(0, 12, 0, 12)
						indicator.BackgroundColor3 = library.darkGray
						indicator.BackgroundTransparency = 1
						indicator.BorderSizePixel = 0
						Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 2)
						indicatorStroke = Instance.new("UIStroke", indicator)
						indicatorStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
						indicatorStroke.Thickness = 1
						indicatorStroke.Color = library.lightGray
						indicatorStroke.Transparency = 0.45

						checkFill = Instance.new("Frame")
						checkFill.Parent = indicator
						checkFill.AnchorPoint = Vector2.new(0.5, 0.5)
						checkFill.Position = UDim2.new(0.5, 0, 0.5, 0)
						checkFill.Size = UDim2.new(0, 0, 0, 0)
						checkFill.BackgroundColor3 = library.acientColor
						checkFill.BackgroundTransparency = 1
						checkFill.BorderSizePixel = 0
						Instance.new("UICorner", checkFill).CornerRadius = UDim.new(0, 2)
					end

					optionButton.MouseEnter:Connect(function()
						TweenService:Create(optionButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							BackgroundTransparency = 0.96,
						}):Play()
						TweenService:Create(optionLabel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							TextColor3 = Color3.fromRGB(195, 195, 195),
						}):Play()
					end)
					optionButton.MouseLeave:Connect(function()
						updateOptionVisual(normalized)
					end)
					optionButton.Activated:Connect(function()
						if isMulti then
							selectedMap[normalized] = not selectedMap[normalized] and true or nil
							refreshAllOptionVisuals()
							setText()
							if type(callback) == "function" then
								callback(copySelectionMap(selectedMap))
							end
						else
							applySelection(normalized)
							setOpen(false)
						end
					end)
					optionButtons[normalized] = optionButton
					optionWidgets[normalized] = {
						Button = optionButton,
						Label = optionLabel,
						Indicator = indicator,
						IndicatorStroke = indicatorStroke,
						CheckFill = checkFill,
					}
					updateOptionVisual(normalized)
					recalcHeights()
					return true
				end

				setOpen = function(nextOpen)
					if isOpen == nextOpen then
						return
					end
					isOpen = nextOpen
					local rowTarget = isOpen and expandedHeight or baseHeight
					local optionsTarget = isOpen and contentHeight or 0
					TweenService:Create(row, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = UDim2.new(1, 0, 0, rowTarget),
					}):Play()
					TweenService:Create(optionsFrame, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = UDim2.new(1, 0, 0, optionsTarget),
					}):Play()
					TweenService:Create(arrow, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Rotation = isOpen and 90 or 0,
					}):Play()
					refreshSideLayout()
				end

				local initialValues = values
				values = {}
				for _, entry in ipairs(initialValues) do
					addOptionButton(entry)
				end

				if isMulti then
					applyMultiSelection(selectedMap, false)
				else
					if not optionButtons[selected] and #values > 0 then
						selected = values[1]
					end
					setText()
					refreshAllOptionVisuals()
				end

				local DropdownFunctions = {}
				function DropdownFunctions:GetValue()
					if isMulti then
						return copySelectionMap(selectedMap)
					end
					return selected
				end
				function DropdownFunctions:Set(newValue)
					if isMulti then
						applyMultiSelection(newValue, true)
						return self
					end
					local normalized = normalizeValue(newValue)
					if normalized == "" then
						return self
					end
					if not optionButtons[normalized] then
						addOptionButton(normalized)
					end
					applySelection(normalized)
					return self
				end
				function DropdownFunctions:AddOption(newValue)
					addOptionButton(newValue)
					return self
				end
				function DropdownFunctions:SetOptions(newValues)
					for _, button in pairs(optionButtons) do
						if button and button.Parent then
							button:Destroy()
						end
					end
					optionButtons = {}
					optionWidgets = {}
					values = {}
					for _, entry in ipairs(type(newValues) == "table" and newValues or {}) do
						addOptionButton(entry)
					end
					if isMulti then
						applyMultiSelection(selectedMap, false)
					else
						if not optionButtons[selected] then
							selected = values[1] or "None"
						end
						setText()
						refreshAllOptionVisuals()
					end
					recalcHeights()
					return self
				end

				trigger.Activated:Connect(function()
					setOpen(not isOpen)
				end)
				return setmetatable(DropdownFunctions, { __index = Section })
			end

			function Section:AddTextbox(textValue, defaultValue, placeholderValue, callback)
				local row = createRow(24)
				local label = Instance.new("TextLabel")
				label.Parent = row
				label.BackgroundTransparency = 1
				label.Position = UDim2.new(0, 6, 0, 0)
				label.Size = UDim2.new(0.35, -2, 1, 0)
				label.Font = library.Font
				label.Text = tostring(textValue or "Input")
				label.TextSize = 13
				label.TextColor3 = Color3.fromRGB(190, 190, 190)
				label.TextXAlignment = Enum.TextXAlignment.Left

				local inputShell = Instance.new("Frame")
				inputShell.Parent = row
				inputShell.BackgroundTransparency = 1
				inputShell.BorderSizePixel = 0
				inputShell.Position = UDim2.new(0.35, 2, 0, 7)
				inputShell.Size = UDim2.new(0.65, -8, 1, -6)

				local underlineBase = Instance.new("Frame")
				underlineBase.Parent = inputShell
				underlineBase.BorderSizePixel = 0
				underlineBase.AnchorPoint = Vector2.new(0, 1)
				underlineBase.Position = UDim2.new(0, 0, 1, 0)
				underlineBase.Size = UDim2.new(1, 0, 0, 1)
				underlineBase.BackgroundColor3 = library.lightGray
				underlineBase.BackgroundTransparency = 0.45
				underlineBase.ZIndex = 2

				local underlineFocus = Instance.new("Frame")
				underlineFocus.Parent = inputShell
				underlineFocus.BorderSizePixel = 0
				underlineFocus.AnchorPoint = Vector2.new(0, 1)
				underlineFocus.Position = UDim2.new(0, 0, 1, 0)
				underlineFocus.Size = UDim2.new(1, 0, 0, 1)
				underlineFocus.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				underlineFocus.BackgroundTransparency = 1
				underlineFocus.ZIndex = 3

				local box = Instance.new("TextBox")
				box.Parent = inputShell
				box.BackgroundTransparency = 1
				box.Position = UDim2.new(0, 2, 0, -4)
				box.Size = UDim2.new(1, -4, 1, -1)
				box.Font = library.Font
				box.TextSize = 13
				box.TextColor3 = Color3.fromRGB(190, 190, 190)
				box.TextXAlignment = Enum.TextXAlignment.Left
				box.ClearTextOnFocus = false
				box.Text = tostring(defaultValue or "")
				box.PlaceholderText = tostring(placeholderValue or "")
				box.PlaceholderColor3 = Color3.fromRGB(130, 130, 130)
				box.ZIndex = 2
				box.Focused:Connect(function()
					TweenService:Create(underlineFocus, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundTransparency = 0,
					}):Play()
				end)
				box.FocusLost:Connect(function()
					TweenService:Create(underlineFocus, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundTransparency = 1,
					}):Play()
					if type(callback) == "function" then
						callback(box.Text)
					end
				end)

				local TextboxFunctions = {}
				function TextboxFunctions:GetValue()
					return box.Text
				end
				function TextboxFunctions:Set(newValue)
					box.Text = tostring(newValue or "")
					if type(callback) == "function" then
						callback(box.Text)
					end
					return self
				end
				function TextboxFunctions:Focus()
					pcall(function()
						box:CaptureFocus()
					end)
					return self
				end
				function TextboxFunctions:Remove()
					row:Destroy()
					refreshSideLayout()
					return self
				end
				return setmetatable(TextboxFunctions, { __index = Section })
			end

			function Section:AddKeybind(textValue, defaultValue, callback, options)
				options = type(options) == "table" and options or {}
				local minimal = options.Minimal == true
				local compact = options.Compact == true
				local bindWidthScale = tonumber(options.BindWidthScale)
				if compact then
					bindWidthScale = math.clamp(bindWidthScale or 0.25, 0.18, 0.42)
				else
					bindWidthScale = 0.5
				end
				local labelWidthScale = math.clamp(1 - bindWidthScale, 0.5, 0.82)
				local row
				if minimal then
					row = Instance.new("Frame")
					row.Parent = body
					row.BackgroundTransparency = 1
					row.BorderSizePixel = 0
					row.Size = UDim2.new(1, 0, 0, 22)
					refreshSideLayout()
				else
					row = createRow(24)
				end

				local label = Instance.new("TextLabel")
				label.Parent = row
				label.BackgroundTransparency = 1
				label.Position = UDim2.new(0, 6, 0, 0)
				label.Size = UDim2.new(labelWidthScale, -6, 1, 0)
				label.Font = library.Font
				label.Text = tostring(textValue or "Keybind")
				label.TextSize = 13
				label.TextColor3 = minimal and Color3.fromRGB(145, 145, 145) or Color3.fromRGB(190, 190, 190)
				label.TextXAlignment = Enum.TextXAlignment.Left

				local button = Instance.new("TextButton")
				button.Parent = row
				button.AnchorPoint = Vector2.new(1, 0.5)
				button.Position = UDim2.new(1, -6, 0.5, 0)
				button.Size = compact and UDim2.new(bindWidthScale, -4, 0, 18) or UDim2.new(bindWidthScale, -6, 1, -4)
				button.Font = library.Font
				button.TextSize = 13
				button.TextColor3 = Color3.fromRGB(190, 190, 190)
				button.AutoButtonColor = false
				button.BorderSizePixel = 0
				button.BackgroundColor3 = library.darkGray
				button.BackgroundTransparency = minimal and 1 or 0.1
				Instance.new("UICorner", button).CornerRadius = UDim.new(0, 2)
				local bStroke = Instance.new("UIStroke", button)
				bStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				bStroke.Thickness = 1
				bStroke.Color = library.lightGray
				bStroke.Transparency = minimal and 0.45 or 0.55

				local chosenKey = library:ResolveKeyCode(defaultValue) or (library.Key or Enum.KeyCode.RightShift)
				local waiting = false
				local function applyLabel()
					if waiting then
						button.Text = ". . ."
					else
						button.Text = chosenKey and chosenKey.Name or "None"
					end
				end
				applyLabel()

				local inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
					if (not waiting) or gameProcessed then
						return
					end
					if input.UserInputType ~= Enum.UserInputType.Keyboard then
						return
					end

					waiting = false
					if input.KeyCode == Enum.KeyCode.Backspace then
						chosenKey = nil
						applyLabel()
						if type(callback) == "function" then
							callback(nil)
						end
						return
					end

					chosenKey = input.KeyCode
					applyLabel()
					if type(callback) == "function" then
						callback(chosenKey)
					end
				end)
				row.Destroying:Connect(function()
					if inputConn then
						inputConn:Disconnect()
						inputConn = nil
					end
				end)

				button.Activated:Connect(function()
					waiting = true
					applyLabel()
				end)

				local KeybindFunctions = {}
				function KeybindFunctions:GetValue()
					return chosenKey
				end
				function KeybindFunctions:Set(newKey)
					chosenKey = library:ResolveKeyCode(newKey)
					waiting = false
					applyLabel()
					if type(callback) == "function" then
						callback(chosenKey)
					end
					return self
				end
				function KeybindFunctions:Capture()
					waiting = true
					applyLabel()
					return self
				end
				return KeybindFunctions
			end

			function Section:NewToggle(...)
				return Section:AddToggle(...)
			end
			function Section:NewSlider(...)
				return Section:AddSlider(...)
			end
			function Section:NewDropdown(...)
				return Section:AddDropdown(...)
			end
			function Section:NewButton(...)
				return Section:AddButton(...)
			end
			function Section:NewLabel(...)
				return Section:AddLabel(...)
			end
			function Section:NewNote(...)
				return Section:AddNote(...)
			end
			function Section:NewTextbox(...)
				return Section:AddTextbox(...)
			end
			function Section:NewKeybind(...)
				return Section:AddKeybind(...)
			end

			refreshSideLayout()
			task.defer(function()
				TweenService:Create(group, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = isRightSide and UDim2.new(1, 0, 0, 0) or UDim2.new(0, 0, 0, 0),
					BackgroundTransparency = 0.2,
				}):Play()
				TweenService:Create(gStroke, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 0.25,
				}):Play()
				TweenService:Create(gTitle, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextTransparency = 0,
				}):Play()
				TweenService:Create(titleDivider, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 0.55,
				}):Play()
				refreshSideLayout()
			end)
			return Section
		end

		function Components:AddLeftSection(sectionTitle)
			return createSideSection(leftSections, sectionTitle)
		end

		function Components:AddRightSection(sectionTitle)
			return createSideSection(rightSections, sectionTitle)
		end

		function Components:AddLeftGroupbox(sectionTitle)
			return Components:AddLeftSection(sectionTitle)
		end

		function Components:AddRightGroupbox(sectionTitle)
			return Components:AddRightSection(sectionTitle)
		end

		function Components:Open()
			TabLibrary.CurrentTab = title
			for i,v in next, container:GetChildren() do 
				if v:IsA("ScrollingFrame") then
					v.Visible = false
				end
			end
			page.Visible = true

			for i,v in next, tabButtons:GetChildren() do
				if v:IsA("TextButton") then
					TweenService:Create(v, TweenWrapper.Styles["tab_text_colour"], {TextColor3 = Color3.fromRGB(170, 170, 170)}):Play()
				end
			end
			TweenService:Create(tabButton, TweenWrapper.Styles["tab_text_colour"], {TextColor3 = library.acientColor}):Play()

			if sideSectionsHost.Visible then
				leftSections.Position = UDim2.new(0, sideOuterPadding - 10, 0, 0)
				rightSections.Position = UDim2.new(0.5, sideHalfGap + 10, 0, 0)
				TweenService:Create(leftSections, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = UDim2.new(0, sideOuterPadding, 0, 0),
				}):Play()
				TweenService:Create(rightSections, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = UDim2.new(0.5, sideHalfGap, 0, 0),
				}):Play()
			end

			return Components
		end

		function Components:Remove()
			tabButton:Destroy()
			page:Destroy()

			return Components
		end

		function Components:Hide()
			tabButton.Visible = false
			page.Visible = false

			return Components
		end

		function Components:Show()
			tabButton.Visible = true

			return Components
		end

		function Components:Text(text)
			text = text or "new text"
			tabButton.Text = text

			return Components
		end

		if tostring(title):lower() == "config" then
			task.defer(function()
				pcall(function()
					Components:AddConfigControls()
				end)
			end)
		end
		return Components
	end

	function library:Remove()
		local sessionsToClose = {}
		for _, destroySession in pairs(targetHudSessions) do
			if type(destroySession) == "function" then
				table.insert(sessionsToClose, destroySession)
			end
		end
		for _, destroySession in ipairs(sessionsToClose) do
			pcall(destroySession)
		end

		library.AutoSaveStarted = false
		screen:Destroy()
		library:Panic()

		return self
	end


	return library
end

function library:RunExample()
	local ui = library:Init({
		title = "Game Utility",
		company = "Depth",
		Font = Enum.Font.GothamSemibold,
		ConfigFolder = "XSXUI",
		ConfigFile = "example.json",
		AutoSave = true,
	})
	ui:SetQueueOnTeleportReadFile("uilib.lua")

	local main = ui:NewTab("Main")
	local leftMain = main:AddLeftGroupbox("Combat")
	leftMain:AddToggle("Auto Feature", false, function() end)
	leftMain:AddSlider("Distance", 0, 15, 5, function() end)

	local rightMain = main:AddRightGroupbox("Mode")
	rightMain:AddDropdown("Mode", { "Default", "Legit", "Rage" }, "Default", function() end)

	local localPlayer = Services.Players.LocalPlayer
	ui:CreateTargetHUD({
		Title = "Target HUD",
		PlayerName = localPlayer and localPlayer.Name or "",
		Position = UDim2.new(0, 20, 0.5, -100),
	})

	rightMain:AddButton("Damage Self (-5)", function()
		local character = localPlayer and localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:TakeDamage(5)
		end
	end)

	local misc = ui:NewTab("Misc")
	misc:AddRandomControls(3, 2)

	local config = ui:NewTab("Config")
	config:Open()
	ui:ShowUI(true)

	return ui
end

-- Disable autorun by setting:
-- getgenv().__SKIP_UILIB_EXAMPLE = true
do
	local env = (getgenv and getgenv()) or _G
	local skip = type(env) == "table" and env.__SKIP_UILIB_EXAMPLE == true
	if not skip then
		task.spawn(function()
			if not game:IsLoaded() then
				game.Loaded:Wait()
			end
			local ok, err = pcall(function()
				library:RunExample()
			end)
			if not ok then
				warn("CustomUI example error:", tostring(err))
				library:NativeNotify("Custom UI", "Example failed. Check console.", 4)
			end
		end)
	end
end

return library
