-- Конфиги, автозагрузка, пользовательские темы на диске
local Env = import("Core/Env")
local State = import("Core/State")
local ThemeM = import("Core/Theme")

local HttpService = Env.HttpService
local fs = Env.fs

local Config = {}

local savable = {
	Toggle = true, Slider = true, RangeSlider = true, Dropdown = true,
	Input = true, Keybind = true, ColorPicker = true,
}

local NO_FS = "у экзекутора нет функций работы с файлами"

function Config.sanitize(name)
	local s = tostring(name or ""):gsub("[^%w%-_ %.]", "")
	s = s:gsub("^%s+", "")
	s = s:gsub("%s+$", "")
	if s == "" then
		s = "default"
	end
	return s
end

local function cfgDir(win)
	return win.Folder .. "/Configs"
end

local function themeDir(win)
	return win.Folder .. "/Themes"
end

local function serialize(opt)
	local t, val = opt.Type, opt:Get()
	if t == "ColorPicker" then
		local a = opt.GetAlpha and opt:GetAlpha() or 1
		return {
			math.floor(val.R * 255 + 0.5), math.floor(val.G * 255 + 0.5),
			math.floor(val.B * 255 + 0.5), a,
		}
	elseif t == "Keybind" then
		return val and val.Name or "None"
	end
	return val
end

local function deserialize(opt, raw)
	local t = opt.Type
	if t == "ColorPicker" then
		opt:Set(Color3.fromRGB(raw[1], raw[2], raw[3]))
		if raw[4] and opt.SetAlpha then
			opt:SetAlpha(raw[4])
		end
	elseif t == "Keybind" then
		opt:Set(raw ~= "None" and raw or nil)
	else
		opt:Set(raw)
	end
end

-- все значения текущих флагов одной таблицей
function Config.collect()
	local data = {}
	for flag, opt in pairs(State.Options) do
		if savable[opt.Type] then
			local ok, val = pcall(serialize, opt)
			if ok and val ~= nil then
				data[flag] = val
			end
		end
	end
	return data
end

function Config.apply(data)
	for flag, raw in pairs(data) do
		local opt = State.Options[flag]
		if opt and savable[opt.Type] then
			pcall(deserialize, opt, raw)
		end
	end
end

function Config.save(win, name)
	if not Env.fsReady() then
		return false, NO_FS
	end
	name = Config.sanitize(name)
	Env.ensureFolder(cfgDir(win))
	local ok, err = pcall(fs.write, cfgDir(win) .. "/" .. name .. ".json", HttpService:JSONEncode(Config.collect()))
	if not ok then
		return false, tostring(err)
	end
	return true
end

function Config.load(win, name)
	if not Env.fsReady() then
		return false, NO_FS
	end
	name = Config.sanitize(name)
	local path = cfgDir(win) .. "/" .. name .. ".json"
	if not fs.isfile(path) then
		return false, "конфиг не найден"
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(fs.read(path))
	end)
	if not ok or type(data) ~= "table" then
		return false, "конфиг повреждён"
	end
	Config.apply(data)
	return true
end

function Config.delete(win, name)
	if not (fs.delete and fs.isfile) then
		return false, NO_FS
	end
	local path = cfgDir(win) .. "/" .. Config.sanitize(name) .. ".json"
	if not fs.isfile(path) then
		return false, "конфиг не найден"
	end
	local ok, err = pcall(fs.delete, path)
	if not ok then
		return false, tostring(err)
	end
	return true
end

local function listJson(dir)
	local result = {}
	if fs.list then
		local ok, files = pcall(fs.list, dir)
		if ok and type(files) == "table" then
			for _, f in ipairs(files) do
				local n = tostring(f):match("([^/\\]+)%.json$")
				if n then
					table.insert(result, n)
				end
			end
		end
	end
	table.sort(result)
	return result
end

function Config.list(win)
	return listJson(cfgDir(win))
end

----------------------------------------------------------------------
-- Автозагрузка
----------------------------------------------------------------------
function Config.getAutoload(win)
	if not (fs.isfile and fs.read) then
		return nil
	end
	local path = win.Folder .. "/autoload.txt"
	if fs.isfile(path) then
		local ok, name = pcall(fs.read, path)
		if ok and name and name ~= "" then
			return name
		end
	end
	return nil
end

function Config.setAutoload(win, name)
	if not Env.fsReady() then
		return false, NO_FS
	end
	Env.ensureFolder(win.Folder)
	local path = win.Folder .. "/autoload.txt"
	if name == nil then
		if fs.delete and fs.isfile(path) then
			pcall(fs.delete, path)
		else
			pcall(fs.write, path, "")
		end
		return true
	end
	local ok, err = pcall(fs.write, path, Config.sanitize(name))
	if not ok then
		return false, tostring(err)
	end
	return true
end

function Config.loadAuto(win)
	local name = Config.getAutoload(win)
	if name then
		return Config.load(win, name)
	end
	return false, "автозагрузка не задана"
end

----------------------------------------------------------------------
-- Пользовательские темы
----------------------------------------------------------------------
function Config.saveTheme(win, name)
	if not Env.fsReady() then
		return false, NO_FS
	end
	name = Config.sanitize(name)
	local data = {}
	for _, key in ipairs(ThemeM.Keys) do
		local c = ThemeM.Colors[key]
		data[key] = { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
	end
	Env.ensureFolder(themeDir(win))
	local ok, err = pcall(fs.write, themeDir(win) .. "/" .. name .. ".json", HttpService:JSONEncode(data))
	if not ok then
		return false, tostring(err)
	end
	ThemeM.register(name, (function()
		local t = {}
		for k, v in pairs(data) do
			t[k] = Color3.fromRGB(v[1], v[2], v[3])
		end
		return t
	end)())
	return true
end

-- читает все сохранённые темы и регистрирует их
function Config.loadThemes(win)
	local loaded = {}
	for _, name in ipairs(listJson(themeDir(win))) do
		local ok, data = pcall(function()
			return HttpService:JSONDecode(fs.read(themeDir(win) .. "/" .. name .. ".json"))
		end)
		if ok and type(data) == "table" then
			local colors = {}
			for k, v in pairs(data) do
				if type(v) == "table" and #v >= 3 then
					colors[k] = Color3.fromRGB(v[1], v[2], v[3])
				end
			end
			ThemeM.register(name, colors)
			table.insert(loaded, name)
		end
	end
	return loaded
end

function Config.deleteTheme(win, name)
	if not (fs.delete and fs.isfile) then
		return false, NO_FS
	end
	name = Config.sanitize(name)
	local path = themeDir(win) .. "/" .. name .. ".json"
	if not fs.isfile(path) then
		return false, "тема не найдена"
	end
	local ok, err = pcall(fs.delete, path)
	if ok then
		ThemeM.Themes[name] = nil
	end
	if not ok then
		return false, tostring(err)
	end
	return true
end

return Config
