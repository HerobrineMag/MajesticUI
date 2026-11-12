-- Точка входа: собирает публичный API Majestic
local State = import("Core/State")
local ThemeM = import("Core/Theme")
local Util = import("Core/Util")
local Gui = import("Core/Gui")
local Icons = import("Core/Icons")
local Glass = import("Core/Glass")
local Config = import("Core/Config")
local Window = import("Core/Window")

import("Elements/Basic")
import("Elements/Slider")
import("Elements/Dropdown")
import("Elements/Input")
import("Elements/ColorPicker")
import("Elements/Table")
import("Elements/Group")

import("Systems/Dialog")
local Notify = import("Systems/Notify")
local Loading = import("Systems/Loading")
local KeySystem = import("Systems/KeySystem")
import("Systems/Home")
import("Systems/Managers")

local Majestic = {
	Version = State.Version,
	Flags = State.Flags,
	Options = State.Options,
	Windows = State.Windows,
	Themes = ThemeM.Themes,
	Icons = Icons,
	CurrentTheme = ThemeM.Name,
}

-- Majestic:Window("Название", "подзаголовок") или Majestic:Window({ Title, Subtitle, Icon, Theme, Size, ... })
function Majestic:Window(a, b)
	local cfg = type(a) == "table" and Util.copy(a) or { Title = a, Subtitle = b }
	cfg.Title = tostring(cfg.Title or cfg.Name or "Majestic")

	pcall(Config.loadThemes, { Folder = cfg.Folder or "Majestic" })
	if cfg.Theme and ThemeM.Themes[cfg.Theme] then
		ThemeM.load(cfg.Theme)
		Majestic.CurrentTheme = cfg.Theme
	end
	if type(cfg.Glass) == "table" and not ThemeM.Glass.Enabled and cfg.Theme == nil then
		cfg.Theme = ThemeM.GlassName -- заданы настройки стекла: включаем Liquid Glass
		ThemeM.load(cfg.Theme)
		Majestic.CurrentTheme = cfg.Theme
	end

	if cfg.KeySystem then
		local ks = type(cfg.KeySystem) == "table" and Util.copy(cfg.KeySystem) or {}
		ks.Folder = ks.Folder or cfg.Folder
		ks.Title = ks.Title or cfg.Title
		if not KeySystem.run(ks) then
			error("[Majestic] key system was closed", 0)
		end
	end

	if cfg.LoadingEnabled then
		Loading.run({
			Title = cfg.LoadingTitle or cfg.Title, Subtitle = cfg.LoadingSubtitle, Icon = cfg.Icon,
			Steps = cfg.LoadingSteps, Time = cfg.LoadingTime,
		})
	end
	return Window.create(cfg)
end

-- Majestic:Notify("Заголовок", "Текст", 4) или таблицей { Title, Content, Type, Duration, Icon }
function Majestic:Notify(...)
	return Notify.show(...)
end

-- отдельный загрузочный экран (если нужен без окна)
function Majestic:Loading(cfg)
	return Loading.run(cfg)
end

-- Key System без окна: if Majestic:KeySystem({ Keys = {"abc"} }) then ... end
function Majestic:KeySystem(cfg)
	return KeySystem.run(cfg)
end

function Majestic:SetTheme(name)
	local ok = ThemeM.set(name)
	if ok then
		Majestic.CurrentTheme = name
	end
	return ok
end

function Majestic:GetTheme()
	return ThemeM.Name
end

function Majestic:SetAccent(color)
	if typeof(color) == "Color3" then
		ThemeM.setColor("Accent", color)
	end
end

-- Majestic:RegisterTheme("Name", { Background = Color3..., Accent = Color3..., ... })
function Majestic:RegisterTheme(name, colors)
	ThemeM.register(name, colors)
end

-- Liquid Glass: Majestic:SetGlass({ Color = Color3, Blur = 0-100, Transparency = 0-95 (проценты) })
-- Без аргументов только включает тему Liquid Glass.
function Majestic:SetGlass(opts)
	opts = opts or {}
	local t = Util.copy(opts)
	if t.Transparency ~= nil then
		t.Transparency = t.Transparency / 100
	end
	if not ThemeM.Glass.Enabled then
		ThemeM.load(ThemeM.GlassName)
		Majestic.CurrentTheme = ThemeM.GlassName
	end
	ThemeM.setGlass(t)
end

function Majestic:Unload()
	for i = #State.Windows, 1, -1 do
		State.Windows[i]:Destroy()
	end
	Glass.destroyAll()
	Gui.destroy()
end

return Majestic
