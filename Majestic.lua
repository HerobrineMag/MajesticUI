--!nonstrict
--[[
	Majestic UI Library v2.0.0
	Собрано из модулей build.py. Документация: Documentation.md

	local Majestic = loadstring(game:HttpGet("URL/Majestic.lua"))()
	local Window = Majestic:Window("Hub", "v1.0")
	local Tab = Window:Tab("Main", "home")
	Tab:Toggle("Auto Farm", false, function(v) print(v) end)
]]

local __defs, __cache = {}, {}
local function import(name)
	local cached = __cache[name]
	if cached ~= nil then
		return cached
	end
	local def = __defs[name]
	if not def then
		error("[Majestic] unknown module: " .. tostring(name))
	end
	local result = def()
	if result == nil then
		result = true
	end
	__cache[name] = result
	return result
end

__defs["Core/Env"] = function()
-- Сервисы, функции экзекутора и платформа
local Players = game:GetService("Players")

local Env = {
	Players = Players,
	TweenService = game:GetService("TweenService"),
	UserInputService = game:GetService("UserInputService"),
	RunService = game:GetService("RunService"),
	HttpService = game:GetService("HttpService"),
	CoreGui = game:GetService("CoreGui"),
	GuiService = game:GetService("GuiService"),
	Stats = game:GetService("Stats"),
	Lighting = game:GetService("Lighting"),
	MarketplaceService = game:GetService("MarketplaceService"),
	LocalPlayer = Players.LocalPlayer,
}

local UIS = Env.UserInputService
Env.IsMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

-- функции файловой системы экзекутора (любая может быть nil)
Env.fs = {
	write = writefile,
	read = readfile,
	isfile = isfile,
	isfolder = isfolder,
	makefolder = makefolder,
	list = listfiles,
	delete = delfile,
}

function Env.fsReady()
	local fs = Env.fs
	return fs.write ~= nil and fs.read ~= nil and fs.isfile ~= nil and fs.makefolder ~= nil
end

-- создаёт вложенные папки: "A/B/C"
function Env.ensureFolder(path)
	if not Env.fs.makefolder then
		return
	end
	local cur = ""
	for part in string.gmatch(path, "[^/\\]+") do
		cur = cur == "" and part or (cur .. "/" .. part)
		local exists = Env.fs.isfolder and Env.fs.isfolder(cur)
		if not exists then
			pcall(Env.fs.makefolder, cur)
		end
	end
end

function Env.clipboard(text)
	local f = setclipboard or toclipboard
	if f then
		local ok = pcall(f, text)
		return ok
	end
	return false
end

function Env.httpGet(url)
	local ok, res = pcall(function()
		return (game :: any):HttpGet(url, true)
	end)
	if ok and type(res) == "string" then
		return res
	end
	return nil
end

return Env
end

__defs["Core/State"] = function()
-- Общее состояние библиотеки
return {
	Version = "2.0.0",
	Flags = {},
	Options = {},
	Windows = {},
}
end

__defs["Core/Theme"] = function()
-- Темы, привязка свойств к теме, живое обновление, режим Liquid Glass (прозрачные поверхности)
local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function lerp(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function luminance(c)
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

local Shared = { Success = C(34, 197, 94), Warning = C(245, 158, 11), Danger = C(239, 68, 68) }

local Themes = {
	Dark = {
		Background = C(15, 15, 21), Topbar = C(20, 20, 28), Sidebar = C(18, 18, 25),
		Element = C(27, 27, 37), ElementHover = C(35, 35, 48), Stroke = C(46, 46, 62),
		Accent = C(139, 92, 246), Text = C(240, 240, 248), SubText = C(148, 148, 170),
	},
	Light = {
		Background = C(245, 245, 250), Topbar = C(255, 255, 255), Sidebar = C(238, 238, 245),
		Element = C(255, 255, 255), ElementHover = C(240, 240, 248), Stroke = C(214, 214, 226),
		Accent = C(99, 102, 241), Text = C(30, 30, 40), SubText = C(110, 110, 130),
	},
	Ocean = {
		Background = C(10, 18, 28), Topbar = C(14, 24, 37), Sidebar = C(12, 21, 33),
		Element = C(19, 32, 48), ElementHover = C(26, 43, 64), Stroke = C(36, 58, 84),
		Accent = C(56, 189, 248), Text = C(232, 243, 252), SubText = C(133, 158, 184),
	},
	Rose = {
		Background = C(22, 14, 18), Topbar = C(28, 18, 23), Sidebar = C(25, 16, 21),
		Element = C(36, 23, 29), ElementHover = C(48, 31, 39), Stroke = C(66, 42, 53),
		Accent = C(244, 63, 94), Text = C(250, 238, 242), SubText = C(178, 146, 157),
	},
	Emerald = {
		Background = C(12, 20, 17), Topbar = C(16, 26, 22), Sidebar = C(14, 23, 19),
		Element = C(21, 34, 29), ElementHover = C(28, 45, 38), Stroke = C(38, 62, 53),
		Accent = C(16, 185, 129), Text = C(235, 250, 244), SubText = C(139, 170, 157),
	},
	Midnight = {
		Background = C(8, 8, 12), Topbar = C(12, 12, 17), Sidebar = C(10, 10, 15),
		Element = C(18, 18, 25), ElementHover = C(25, 25, 35), Stroke = C(34, 34, 47),
		Accent = C(99, 179, 237), Text = C(226, 232, 240), SubText = C(120, 130, 150),
	},
}
for _, t in pairs(Themes) do
	for k, v in pairs(Shared) do
		t[k] = v
	end
end

local GLASS = "Liquid Glass"

local M = {
	Themes = Themes,
	Colors = {},
	Name = "Dark",
	Root = nil,
	GlassName = GLASS,
	-- Liquid Glass: Color — оттенок стекла, Blur 0..100 — сила размытия фона,
	-- Transparency 0..0.95 — прозрачность панелей (больше = прозрачнее)
	Glass = { Enabled = false, Color = C(28, 34, 50), Blur = 60, Transparency = 0.5, Accent = C(110, 168, 255) },
	Keys = {
		"Background", "Topbar", "Sidebar", "Element", "ElementHover", "Stroke",
		"Accent", "Text", "SubText", "Success", "Warning", "Danger",
	},
	_hooks = {}, -- функции, которые вызываются после apply (например, размытие фона)
}

local themed = {}
local refreshers = {}
local surfaces, strokes, decor = {}, {}, {}

-- коэффициенты прозрачности по слоям стекла: чем выше, тем прозрачнее слой относительно окна
local roleFactor = { Background = 0, Topbar = 0.12, Sidebar = 0.18, Element = 0.42 }
local keyRoles = { Background = "Background", Topbar = "Topbar", Sidebar = "Sidebar", Element = "Element" }
M.KeyRoles = keyRoles

local function glassColors()
	local g = M.Glass
	local tint, white = g.Color, Color3.new(1, 1, 1)
	local text = luminance(tint) > 0.6 and C(18, 20, 28) or C(244, 247, 255)
	local t = {
		Background = tint, Topbar = lerp(tint, white, 0.06), Sidebar = lerp(tint, white, 0.03),
		Element = lerp(tint, white, 0.14), ElementHover = lerp(tint, white, 0.24), Stroke = lerp(tint, white, 0.8),
		Accent = g.Accent, Text = text, SubText = lerp(text, tint, 0.42),
	}
	for k, v in pairs(Shared) do
		t[k] = v
	end
	return t
end
Themes[GLASS] = glassColors()

function M.register(name, colors)
	local t = {}
	for k, v in pairs(Themes.Dark) do
		t[k] = v
	end
	for k, v in pairs(Shared) do
		t[k] = v
	end
	for k, v in pairs(colors) do
		t[k] = v
	end
	Themes[name] = t
end

function M.load(name)
	if name == GLASS then
		Themes[GLASS] = glassColors()
	end
	local src = Themes[name]
	if not src then
		return false
	end
	for k, v in pairs(src) do
		M.Colors[k] = v
	end
	M.Name = name
	M.Glass.Enabled = name == GLASS
	return true
end
M.load("Dark")

-- привязывает свойство инстанса к цвету темы
function M.bind(inst, prop, key)
	inst[prop] = M.Colors[key]
	table.insert(themed, { inst, prop, key })
end

-- функция, которая перерисовывает состояние элемента при смене темы
function M.addRefresh(inst, fn)
	table.insert(refreshers, { inst, fn })
end

local function surfaceT(role)
	local T = M.Glass.Transparency
	return T + (1 - T) * (roleFactor[role] or 0)
end

-- слой поверхности: в режиме стекла получает прозрачность, вне его возвращается к исходной
function M.surface(inst, role)
	table.insert(surfaces, { inst, role, inst.BackgroundTransparency })
	if M.Glass.Enabled then
		inst.BackgroundTransparency = surfaceT(role)
	end
end

-- рамка: в режиме стекла становится полупрозрачной (светлая тонкая кромка)
function M.glassStroke(stroke)
	table.insert(strokes, { stroke, stroke.Transparency })
	if M.Glass.Enabled then
		stroke.Transparency = 0.62
	end
end

-- декор, который виден только в режиме стекла (блик, градиент кромки); prop = "Visible" | "Enabled"
function M.glassDecor(inst, prop)
	inst[prop] = M.Glass.Enabled
	table.insert(decor, { inst, prop })
end

function M.apply()
	local root = M.Root
	local on = M.Glass.Enabled
	for i = #themed, 1, -1 do
		local e = themed[i]
		if root and e[1]:IsDescendantOf(root) then
			e[1][e[2]] = M.Colors[e[3]]
		else
			table.remove(themed, i)
		end
	end
	for i = #surfaces, 1, -1 do
		local e = surfaces[i]
		if root and e[1]:IsDescendantOf(root) then
			e[1].BackgroundTransparency = on and surfaceT(e[2]) or e[3]
		else
			table.remove(surfaces, i)
		end
	end
	for i = #strokes, 1, -1 do
		local e = strokes[i]
		if root and e[1]:IsDescendantOf(root) then
			e[1].Transparency = on and 0.62 or e[2]
		else
			table.remove(strokes, i)
		end
	end
	for i = #decor, 1, -1 do
		local e = decor[i]
		if root and e[1]:IsDescendantOf(root) then
			e[1][e[2]] = on
		else
			table.remove(decor, i)
		end
	end
	for i = #refreshers, 1, -1 do
		local e = refreshers[i]
		if root and e[1]:IsDescendantOf(root) then
			pcall(e[2])
		else
			table.remove(refreshers, i)
		end
	end
	for _, hook in ipairs(M._hooks) do
		pcall(hook)
	end
end

function M.set(name)
	if not M.load(name) then
		return false
	end
	M.apply()
	return true
end

function M.setColor(key, color)
	M.Colors[key] = color
	if key == "Accent" and M.Glass.Enabled then
		M.Glass.Accent = color
	end
	M.apply()
end

-- настройки стекла: { Color, Blur (0-100), Transparency (0-0.95), Accent }
function M.setGlass(opts)
	local g = M.Glass
	if opts.Color ~= nil then
		g.Color = opts.Color
	end
	if opts.Blur ~= nil then
		g.Blur = math.clamp(opts.Blur, 0, 100)
	end
	if opts.Transparency ~= nil then
		g.Transparency = math.clamp(opts.Transparency, 0, 0.95)
	end
	if opts.Accent ~= nil then
		g.Accent = opts.Accent
	end
	if g.Enabled then
		M.load(GLASS) -- пересчитать цвета из нового оттенка
	end
	M.apply()
end

local function fmt(c)
	return string.format(
		"Color3.fromRGB(%d, %d, %d)",
		math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
	)
end

-- текущая тема как Lua-таблица (для копирования в буфер)
function M.toLua()
	local lines = { "{" }
	for _, k in ipairs(M.Keys) do
		table.insert(lines, string.format("\t%s = %s,", k, fmt(M.Colors[k])))
	end
	table.insert(lines, "}")
	return table.concat(lines, "\n")
end

function M.names()
	local names = {}
	for k in pairs(Themes) do
		table.insert(names, k)
	end
	table.sort(names)
	return names
end

return M
end

__defs["Core/Util"] = function()
-- Общие утилиты: создание инстансов, твины, парсинг параметров
local Env = import("Core/Env")
local ThemeM = import("Core/Theme")

local TweenService = Env.TweenService

local Util = {}

local Defaults = {
	Frame = { BorderSizePixel = 0 },
	CanvasGroup = { BorderSizePixel = 0 },
	TextLabel = {
		BorderSizePixel = 0, BackgroundTransparency = 1, Font = Enum.Font.GothamMedium,
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
	},
	TextButton = {
		BorderSizePixel = 0, BackgroundTransparency = 1, AutoButtonColor = false, Text = "",
		Font = Enum.Font.GothamMedium, TextSize = 13,
	},
	TextBox = {
		BorderSizePixel = 0, BackgroundTransparency = 1, ClearTextOnFocus = false, Text = "",
		Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
	},
	ImageLabel = { BorderSizePixel = 0, BackgroundTransparency = 1 },
	ImageButton = { BorderSizePixel = 0, BackgroundTransparency = 1, AutoButtonColor = false },
	ScrollingFrame = { BorderSizePixel = 0, BackgroundTransparency = 1, ScrollBarThickness = 3 },
	UIListLayout = { SortOrder = Enum.SortOrder.LayoutOrder },
	UIGridLayout = { SortOrder = Enum.SortOrder.LayoutOrder },
}

function Util.C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

function Util.copy(t)
	local n = {}
	for k, v in pairs(t) do
		n[k] = v
	end
	return n
end

function Util.trim(s)
	local r = tostring(s or ""):gsub("^%s+", "")
	r = r:gsub("%s+$", "")
	return r
end

-- props.Theme = { Свойство = "КлючТемы" } привязывает свойство к теме.
-- Фоны с ключами Background/Topbar/Sidebar/Element автоматически становятся слоями Liquid Glass.
function Util.new(class, props)
	local inst = Instance.new(class)
	local d = Defaults[class]
	if d then
		for k, v in pairs(d) do
			(inst :: any)[k] = v
		end
	end
	local parent, theme
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then
				parent = v
			elseif k == "Theme" then
				theme = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if theme then
		for prop, key in pairs(theme) do
			ThemeM.bind(inst, prop, key)
			local role = prop == "BackgroundColor3" and ThemeM.KeyRoles[key]
			if role and inst.BackgroundTransparency < 1 then
				ThemeM.surface(inst, role)
			end
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Util.tween(inst, props, t, style, dir)
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

function Util.corner(parent, r)
	return Util.new("UICorner", { CornerRadius = UDim.new(0, r or 6), Parent = parent })
end

function Util.stroke(parent, key, thickness)
	local st = Util.new("UIStroke", {
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Theme = { Color = key or "Stroke" },
		Parent = parent,
	})
	ThemeM.glassStroke(st)
	return st
end

function Util.padding(parent, top, bottom, left, right)
	return Util.new("UIPadding", {
		PaddingTop = UDim.new(0, top or 0), PaddingBottom = UDim.new(0, bottom or 0),
		PaddingLeft = UDim.new(0, left or 0), PaddingRight = UDim.new(0, right or 0),
		Parent = parent,
	})
end

function Util.list(parent, gap, props)
	local p = { Padding = UDim.new(0, gap or 0), Parent = parent }
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	return Util.new("UIListLayout", p)
end

function Util.isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

function Util.isMove(i)
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

-- безопасный вызов колбэка: ошибка в чужом коде не ломает UI
function Util.fire(cb, ...)
	if type(cb) ~= "function" then
		return
	end
	task.spawn(function(...)
		local ok, err = pcall(cb, ...)
		if not ok then
			warn("[Majestic] callback error: " .. tostring(err))
		end
	end, ...)
end

function Util.decimalsOf(n)
	local d = tostring(n):match("%.(%d+)$")
	return d and #d or 0
end

function Util.snap(v, min, max, inc)
	v = math.clamp(v, min, max)
	v = min + math.floor((v - min) / inc + 0.5) * inc
	v = math.clamp(v, min, max)
	return tonumber(string.format("%." .. Util.decimalsOf(inc) .. "f", v))
end

-- параметры можно передавать списком или таблицей
function Util.parse(first, keys, ...)
	local cfg = {}
	if type(first) == "table" then
		for k, v in pairs(first) do
			cfg[k] = v
		end
	else
		cfg.Name = first
		local args = table.pack(...)
		for i, k in ipairs(keys) do
			cfg[k] = args[i]
		end
		-- колбэк можно передать вместо любого необязательного аргумента
		for _, k in ipairs(keys) do
			if k ~= "Callback" and type(cfg[k]) == "function" then
				cfg.Callback = cfg.Callback or cfg[k]
				cfg[k] = nil
			end
		end
	end
	cfg.Name = tostring(cfg.Name or cfg.Title or cfg.Text or "")
	cfg.Desc = cfg.Desc or cfg.Description
	cfg.Callback = cfg.Callback or cfg.Function
	cfg.Tooltip = cfg.Tooltip or cfg.Hint
	cfg.IconUrl = cfg.IconUrl or cfg.IconSource or cfg.IconSet
	-- удобные синонимы полей
	if cfg.Default == nil then
		cfg.Default = cfg.Value
	end
	cfg.Options = cfg.Options or cfg.Values or cfg.List
	return cfg
end

function Util.makeDraggable(handle, target, connect)
	local dragging, startMouse, startPos = false, nil, nil
	handle.InputBegan:Connect(function(i)
		if Util.isPress(i) then
			dragging = true
			startMouse = i.Position
			startPos = target.Position
			local conn
			conn = i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					dragging = false
					conn:Disconnect()
				end
			end)
		end
	end)
	connect(Env.UserInputService.InputChanged, function(i)
		if dragging and Util.isMove(i) then
			local d = i.Position - startMouse
			target.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y
			)
		end
	end)
end

return Util
end

__defs["Core/Shapes"] = function()
-- Нарисованные значки (стрелки, крестик, галочка, ромб, лупа).
-- Вместо символов шрифта (✕ ▾ ✓ ◆), которые в части шрифтов Roblox превращаются в квадратики.
-- colorKey = ключ темы ("SubText", "Accent", ...) или false для белого цвета.
local Util = import("Core/Util")

local new = Util.new

local Shapes = {}

local function holder(parent, size)
	return new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, Parent = parent })
end

-- палочка длиной len и толщиной thick; cx, cy в долях контейнера
local function bar(parent, len, thick, cx, cy, rot, key)
	local props = {
		Size = UDim2.fromOffset(len, thick), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(cx, cy),
		Rotation = rot, Parent = parent,
	}
	if key then
		props.Theme = { BackgroundColor3 = key }
	else
		props.BackgroundColor3 = Color3.new(1, 1, 1)
	end
	local f = new("Frame", props)
	Util.corner(f, thick / 2)
	return f
end

local function thickness(size)
	return math.max(2, math.floor(size / 8 + 0.5))
end

-- стрелка-шеврон; dir: "down" (по умолчанию), "up", "left", "right"
function Shapes.chevron(parent, size, key, dir)
	local h = holder(parent, size)
	local t = thickness(size)
	local len = size * 0.43 + t * 0.5
	bar(h, len, t, 0.35, 0.5, 45, key)
	bar(h, len, t, 0.65, 0.5, -45, key)
	local rot = { down = 0, up = 180, left = 90, right = -90 }
	h.Rotation = rot[dir or "down"] or 0
	return h
end

function Shapes.close(parent, size, key)
	local h = holder(parent, size)
	local t = thickness(size)
	bar(h, size * 0.72, t, 0.5, 0.5, 45, key)
	bar(h, size * 0.72, t, 0.5, 0.5, -45, key)
	return h
end

function Shapes.minus(parent, size, key)
	local h = holder(parent, size)
	bar(h, size * 0.62, thickness(size), 0.5, 0.5, 0, key)
	return h
end

function Shapes.check(parent, size, key)
	local h = holder(parent, size)
	local t = thickness(size)
	bar(h, size * 0.3 + t * 0.4, t, 0.3, 0.62, 45, key)
	bar(h, size * 0.58 + t * 0.4, t, 0.6, 0.51, -46, key)
	return h
end

function Shapes.diamond(parent, size, key)
	local h = holder(parent, size)
	local props = {
		Size = UDim2.fromOffset(size * 0.62, size * 0.62), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Rotation = 45, Parent = h,
	}
	if key then
		props.Theme = { BackgroundColor3 = key }
	else
		props.BackgroundColor3 = Color3.new(1, 1, 1)
	end
	local d = new("Frame", props)
	Util.corner(d, 2)
	return h
end

function Shapes.search(parent, size, key)
	local h = holder(parent, size)
	local t = thickness(size)
	local ring = new("Frame", {
		Size = UDim2.fromOffset(size * 0.62, size * 0.62), Position = UDim2.fromScale(0.04, 0.04),
		BackgroundTransparency = 1, Parent = h,
	})
	Util.corner(ring, 999)
	if key then
		new("UIStroke", { Thickness = t, Theme = { Color = key }, Parent = ring })
	else
		new("UIStroke", { Thickness = t, Color = Color3.new(1, 1, 1), Parent = ring })
	end
	bar(h, size * 0.34 + t * 0.5, t, 0.8, 0.8, 45, key)
	return h
end

return Shapes
end

__defs["Core/MaterialData"] = function()
-- Набор иконок Material (1482 шт.): имя=assetId.
-- Данные собраны в проекте Luna Interface Suite (Nebula Softworks); иконки Material предоставил qweery.
-- Распространяется на условиях лицензии исходного проекта:
--
--[[
BSD 3-Clause License

Copyright (c) 2024, Nebula Softworks

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]
--
-- Формат: "имя=id;" (парсится лениво при первом обращении, см. Core/Icons)
return [==[
10k=6026643035;10mp=6031328149;11mp=6031328141;12mp=6031328140;13mp=6031328137;14mp=6031328161;
15mp=6031328158;16mp=6031328168;17mp=6031339055;18mp=6031339064;19mp=6031339054;1k=6026643002;
1k_plus=6026681580;20mp=6031488940;21mp=6031339065;22mp=6031360353;23mp=6031339045;24mp=6031360352;
2k=6026643032;2k_plus=6026681588;2mp=6031328138;360=6034767608;3d_rotation=6022668893;3k=6026681574;
3k_plus=6026681598;3mp=6031328136;4k=6026643017;4k_plus=6026643005;4mp=6031328152;5g=6026643007;5k=6026681575;
5k_plus=6026643028;5mp=6031328144;6k=6026681579;6k_plus=6026643019;6mp=6031328131;7k=6026681584;
7k_plus=6026643012;7mp=6031328139;8k=6026643014;8k_plus=6026643003;8mp=6031328133;9k=6026643013;
9k_plus=6026681585;9mp=6031328146;_add_alert=6031071067;_auto_delete=6031071068;_error=6031071057;
_error_outline=6031071050;_notification_important=6031071056;_warning=6031071053;ac_unit=6035107929;
access_alarm=6034983844;access_alarms=6034983853;access_time=6034983856;accessibility=6022668887;
accessibility_new=6022668945;accessible=6022668902;accessible_forward=6022668906;account_balance=6022668900;
account_balance_wallet=6022668892;account_box=6023426915;account_circle=6022668898;account_tree=6034418507;
ad_units=6034983845;adb=6034418515;add=6035047377;add_a_photo=6031339049;add_alarm=6034983850;
add_box=6035047375;add_business=6034483666;add_call=6034418524;add_chart=6034898093;add_circle=6035047380;
add_circle_outline=6035047391;add_comment=6034898128;add_ic_call=6035173839;add_link=6035047374;
add_location=6034483672;add_location_alt=6034483678;add_moderator=6034295699;add_photo_alternate=6031471484;
add_road=6034483677;add_shopping_cart=6022668875;add_task=6022668912;add_to_drive=6022860335;
add_to_home_screen=6034983858;add_to_photos=6031371075;add_to_queue=6026647903;addchart=6023426905;
adjust=6031339048;admin_panel_settings=6022668961;agriculture=6034483674;airline_seat_flat=6034418511;
airline_seat_flat_angled=6034418513;airline_seat_individual_suite=6034418514;
airline_seat_legroom_extra=6034418508;airline_seat_legroom_normal=6034418532;
airline_seat_legroom_reduced=6034418520;airline_seat_recline_extra=6034418528;
airline_seat_recline_normal=6034418512;airplanemode_active=6034983864;airplanemode_inactive=6034983848;
airplay=6026647929;airport_shuttle=6035107921;alarm=6023426910;alarm_add=6023426898;alarm_off=6023426901;
alarm_on=6023426920;album=6026647905;all_inbox=6022668909;all_inclusive=6035107920;all_out=6022668876;
alt_route=6034483670;alternate_email=6035173865;amp_stories=6035047382;analytics=6022668884;anchor=6023426906;
android=6022668966;animation=6031625150;announcement=6022668946;apartment=6035107922;api=6022668911;
app_blocking=6022668952;app_registration=6035173870;app_settings_alt=6031090998;approval=6031302928;
apps=6031090999;architecture=6034275730;archive=6035047379;arrow_back=6031091000;arrow_back_ios=6031091003;
arrow_circle_down=6022668877;arrow_circle_up=6022668934;arrow_downward=6031090991;arrow_drop_down=6031091004;
arrow_drop_down_circle=6031091001;arrow_drop_up=6031090990;arrow_forward=6031090995;
arrow_forward_ios=6031091008;arrow_left=6031091002;arrow_right=6031090994;arrow_right_alt=6022668890;
arrow_upward=6031090997;art_track=6026647908;article=6022668907;aspect_ratio=6022668895;assessment=6022668897;
assignment=6022668882;assignment_ind=6022668935;assignment_late=6022668880;assignment_return=6023426931;
assignment_returned=6023426899;assignment_turned_in=6023426904;assistant=6031360356;
assistant_direction=6031091005;assistant_navigation=6031091006;assistant_photo=6031339052;atm=6034767614;
attach_email=6031302935;attach_file=6034898102;attach_money=6034898098;attachment=6031302921;
attractions=6034767620;audiotrack=6031471489;auto_awesome=6031360365;auto_awesome_mosaic=6031371053;
auto_awesome_motion=6031360370;auto_fix_high=6031360355;auto_fix_normal=6031371074;auto_fix_off=6031360381;
auto_stories=6031360360;autorenew=6023565901;av_timer=6026647934;baby_changing_station=6035107930;
backpack=6035107928;backspace=6035047397;backup=6023426911;backup_table=6022860338;badge=6034767607;
bakery_dining=6034767610;ballot=6035047386;bar_chart=6034898096;batch_prediction=6022860334;
bathtub=6035107939;battery_alert=6034983843;battery_charging_full=6034983849;battery_full=6034983854;
battery_unknown=6034983842;beach_access=6035107923;bedtime=6031371054;beenhere=6034483675;bento=6035107924;
bike_scooter=6034483669;biotech=6035047385;block=6035047387;block_flipped=6035047378;bluetooth=6034983880;
bluetooth_audio=6034418522;bluetooth_connected=6034983855;bluetooth_disabled=6034989562;
bluetooth_searching=6034989553;blur_circular=6031488945;blur_linear=6031488930;blur_off=6031371055;
blur_on=6031371068;bolt=6035047381;book=6022860343;book_online=6022860332;bookmark=6022852108;
bookmark_border=6022860339;bookmarks=6023426924;border_all=6034898101;border_bottom=6034898094;
border_clear=6034898135;border_color=6034898100;border_horizontal=6034898105;border_inner=6034898131;
border_left=6034898099;border_outer=6034898104;border_right=6034898120;border_style=6034898097;
border_top=6034900726;border_vertical=6034900725;branding_watermark=6026647911;breakfast_dining=6034483671;
brightness_1=6031471488;brightness_2=6031488938;brightness_3=6031572317;brightness_4=6031471483;
brightness_5=6031471479;brightness_6=6031572309;brightness_7=6031471491;brightness_auto=6034989545;
brightness_high=6034989541;brightness_low=6034989542;brightness_medium=6034989543;broken_image=6031471480;
browser_not_supported=6034789875;brunch_dining=6034767611;brush=6031572320;bubble_chart=6034925612;
bug_report=6022852107;build=6023426938;build_circle=6023426952;burst_mode=6031572306;bus_alert=6034767618;
business=6035173853;business_center=6035107933;cached=6023426921;cake=6034295702;calculate=6035047384;
calendar_today=6022668917;calendar_view_day=6023426946;call=6035173859;call_end=6035173845;
call_made=6035173858;call_merge=6035173843;call_missed=6035173850;call_missed_outgoing=6035173847;
call_received=6035173844;call_split=6035173861;call_to_action=6026647898;camera=6031572312;
camera_alt=6031572307;camera_enhance=6023426935;camera_front=6031572318;camera_rear=6031572316;
camera_roll=6031572314;campaign=6031094666;cancel=6031094677;cancel_presentation=6035173837;
cancel_schedule_send=6022668963;car_rental=6034767641;car_repair=6034767617;card_giftcard=6023426978;
card_membership=6023426942;card_travel=6023426925;carpenter=6035107955;cases=6031572324;casino=6035107936;
cast=6034789876;cast_connected=6034789895;cast_for_education=6034789872;category=6034767621;
celebration=6034767613;cell_wifi=6035173852;center_focus_strong=6031625147;center_focus_weak=6031625144;
change_history=6023426914;charging_station=6035107925;chat=6035173838;chat_bubble=6035181858;
chat_bubble_outline=6035181869;check=6031094667;check_box=6031068421;check_box_outline_blank=6031068420;
check_circle=6023426945;check_circle_outline=6023426909;checkroom=6035107931;chevron_left=6031094670;
chevron_right=6031094680;child_care=6035107927;child_friendly=6035121942;chrome_reader_mode=6023426912;
circle=6031625146;circle_notifications=6023426923;class=6022668949;clean_hands=6034275729;
cleaning_services=6034767619;clear=6035047409;clear_all=6035181870;close=6031094678;
close_fullscreen=6023426928;closed_caption=6026647896;closed_caption_disabled=6026647900;
closed_caption_off=6026647943;cloud=6031302918;cloud_circle=6031302919;cloud_done=6031302927;
cloud_download=6031302917;cloud_off=6031302993;cloud_queue=6031302916;cloud_upload=6031302992;code=6022668955;
collections=6031625145;collections_bookmark=6034328965;color_lens=6031625148;colorize=6031625161;
comment=6035181871;comment_bank=6023426937;commute=6022668901;compare=6031625151;compare_arrows=6022668951;
compass_calibration=6034767623;compress=6022668878;computer=6034789874;confirmation_number=6034418519;
connect_without_contact=6034275800;connected_tv=6034789870;construction=6034275725;contact_mail=6035181868;
contact_page=6022668881;contact_phone=6035181861;contact_support=6022668879;contactless=6022668886;
contacts=6035181864;content_copy=6035053278;content_cut=6035053280;content_paste=6035053285;
control_camera=6026647916;control_point=6031625131;control_point_duplicate=6034328959;copyright=6023565898;
coronavirus=6034275724;corporate_fare=6035121908;countertops=6035121914;create=6035053304;
create_new_folder=6031302933;crop=6034328964;crop_16_9=6031630205;crop_3_2=6034328956;crop_5_4=6034328960;
crop_7_5=6031630197;crop_din=6031630208;crop_free=6031630212;crop_landscape=6031630202;
crop_original=6031630204;crop_portrait=6031630198;crop_rotate=6031630203;crop_square=6031630222;
dangerous=6022668916;dashboard=6022668883;dashboard_customize=6022668899;data_usage=6034989568;
date_range=6022668894;deck=6034295703;dehaze=6031630200;delete=6022668885;delete_forever=6022668939;
delete_outline=6022668962;delete_sweep=6035053301;delivery_dining=6034767644;departure_board=6034767615;
description=6022668888;design_services=6034754453;desktop_access_disabled=6035181863;desktop_mac=6034789898;
desktop_windows=6034789893;details=6034328968;developer_board=6034789883;developer_mode=6034989549;
device_hub=6034789877;device_thermostat=6034989544;device_unknown=6034789884;devices=6034989540;
devices_other=6034789873;dialer_sip=6035181865;dialpad=6035181892;dinner_dining=6034754457;
directions=6034754449;directions_bike=6034754459;directions_boat=6034754442;directions_bus=6034754434;
directions_car=6034754441;directions_off=6034418517;directions_railway=6034754433;directions_run=6034754445;
directions_subway=6034754440;directions_transit=6034754436;directions_walk=6034754448;dirty_lens=6034328967;
disabled_by_default=6023426939;disc_full=6034418518;dns=6023426958;do_not_disturb=6034439645;
do_not_disturb_alt=6034461619;do_not_disturb_off=6034439642;do_not_disturb_on=6034439649;
do_not_step=6035121910;do_not_touch=6035121915;dock=6034789888;domain=6034275722;domain_disabled=6035181862;
domain_verification=6035181867;done=6023426926;done_all=6023426929;done_outline=6023426936;
double_arrow=6031094674;drafts=6035053297;drag_handle=6034910907;drag_indicator=6023426962;
drive_eta=6034464371;drive_file_move=6031302922;drive_file_move_outline=6031302924;
drive_file_rename_outline=6031302994;drive_folder_upload=6031302929;dry=6035121909;dry_cleaning=6034754456;
duo=6035181860;dvr=6034989561;dynamic_feed=6035053289;dynamic_form=6023426970;east=6031094675;eco=6023426988;
edit=6034328955;edit_attributes=6034754443;edit_location=6034754439;edit_off=6023426983;edit_road=6034744035;
eject=6023426930;elderly=6034295698;electric_bike=6034744032;electric_car=6034744029;
electric_moped=6034744027;electric_rickshaw=6034744043;electric_scooter=6034744041;
electrical_services=6034744038;elevator=6035121912;email=6035181866;emoji_emotions=6034275731;
emoji_events=6034275726;emoji_flags=6034304898;emoji_food_beverage=6034304883;emoji_nature=6034281896;
emoji_objects=6034281900;emoji_people=6034281904;emoji_symbols=6034281899;emoji_transportation=6034281894;
engineering=6034281908;enhanced_encryption=6034439652;equalizer=6026647906;escalator=6035121939;
escalator_warning=6035121930;euro=6034328963;euro_symbol=6023426954;ev_station=6034744037;event=6023426959;
event_available=6034439643;event_busy=6034439634;event_note=6034439637;exit_to_app=6023426922;
expand=6022668891;expand_less=6031094679;expand_more=6031094687;explicit=6026647913;explore=6023426941;
explore_off=6023426953;exposure=6034328962;exposure_neg_1=6034328957;exposure_neg_2=6034328973;
exposure_plus_1=6034328970;exposure_plus_2=6034328961;exposure_zero=6034329000;extension=6023565892;
face=6023426944;face_retouching_natural=6034333274;facebook=6034281898;fact_check=6023426951;
family_restroom=6035121916;fast_forward=6026647902;fast_rewind=6026647942;fastfood=6034744034;
favorite=6023426974;favorite_border=6023565882;featured_play_list=6026647932;featured_video=6026647910;
feedback=6023426957;fence=6035121923;festival=6034744031;fiber_dvr=6026647912;fiber_manual_record=6026647909;
fiber_new=6026647930;fiber_pin=6026660064;fiber_smart_record=6026660080;file_copy=6035053293;
file_download=6031302931;file_download_done=6031302926;file_upload=6031302996;filter=6031597514;
filter_1=6031597511;filter_2=6031597521;filter_3=6031597513;filter_4=6031597512;filter_5=6031597518;
filter_6=6031597524;filter_7=6031597515;filter_8=6031597532;filter_9=6031597534;filter_9_plus=6031600812;
filter_alt=6023426984;filter_b_and_w=6031600824;filter_center_focus=6031600817;filter_drama=6031600813;
filter_frames=6031600833;filter_hdr=6031600819;filter_list=6035053294;filter_list_alt=6023426955;
filter_none=6031600815;filter_tilt_shift=6031600814;filter_vintage=6031600811;find_in_page=6023426986;
find_replace=6023426979;fingerprint=6023565895;fire_extinguisher=6035121913;fireplace=6034281910;
first_page=6031094682;fitness_center=6035121907;flag=6035053279;flaky=6031082523;flare=6031600816;
flash_auto=6034333287;flash_off=6034333270;flash_on=6034333271;flight=6034744030;flight_land=6023565897;
flight_takeoff=6023565891;flip=6034333275;flip_camera_android=6034333280;flip_camera_ios=6034333267;
flip_to_back=6023565896;flip_to_front=6023565894;folder=6031302932;folder_open=6031302934;
folder_shared=6031302945;folder_special=6034439639;follow_the_signs=6034281911;font_download=6035053275;
food_bank=6035121921;format_align_center=6034900718;format_align_justify=6034900721;
format_align_left=6034900727;format_align_right=6034900723;format_bold=6034900732;format_clear=6034910902;
format_color_fill=6034910903;format_color_reset=6034900743;format_color_text=6034910910;
format_indent_decrease=6034900733;format_indent_increase=6034900724;format_italic=6034910912;
format_line_spacing=6034910905;format_list_bulleted=6034925620;format_list_numbered=6034925622;
format_list_numbered_rtl=6034910906;format_paint=6034925618;format_quote=6034925629;format_shapes=6034910909;
format_size=6034910908;format_strikethrough=6034910904;format_textdirection_l_to_r=6034925619;
format_textdirection_r_to_l=6034925623;format_underlined=6034925627;forum=6035202002;forward=6035053298;
forward_10=6026660062;forward_30=6026660088;forward_5=6026660067;forward_to_inbox=6035190840;
foundation=6035121918;free_breakfast=6035145363;fullscreen=6031094681;fullscreen_exit=6031094691;
functions=6034925614;g_translate=6031082526;gamepad=6034789879;games=6026660074;gavel=6023565902;
gesture=6035053287;get_app=6023565889;gif=6031082540;golf_course=6035145423;gps_fixed=6034989550;
gps_not_fixed=6034989547;gps_off=6034989548;grade=6026568189;gradient=6034333261;grading=6026568191;
grain=6034333288;graphic_eq=6034989551;grass=6035145359;grid_off=6034333286;grid_on=6034333276;
grid_view=6031302950;group=6034281901;group_add=6034281909;group_work=6023565910;groups=6034281935;
hail=6034744033;handyman=6034744057;hardware=6034744036;hd=6026660065;hdr_enhanced_select=6034333281;
hdr_off=6034333266;hdr_on=6034333279;hdr_strong=6034333272;hdr_weak=6034407083;headset=6034789880;
headset_mic=6034818383;headset_off=6034818402;healing=6034407071;hearing=6026660060;
hearing_disabled=6026660068;height=6034925613;help_center=6026568192;help_outline=6026568201;
high_quality=6026660059;highlight=6034925617;highlight_alt=6023565913;highlight_off=6023565916;
history=6026568197;history_edu=6034281934;history_toggle_off=6026568196;home=6026568195;
home_repair_service=6034744064;home_work=6031094683;horizontal_rule=6034925610;horizontal_split=6026568194;
hot_tub=6035145382;hotel=6034687977;hourglass_bottom=6035202043;hourglass_disabled=6026568193;
hourglass_full=6026568190;hourglass_top=6035190886;house=6035145364;house_siding=6035145393;
how_to_reg=6035053288;how_to_vote=6035053295;https=6026568200;hvac=6034687960;icecream=6034687967;
image=6034407078;image_aspect_ratio=6034407073;image_not_supported=6034407076;image_search=6034407084;
imagesearch_roller=6034439635;import_contacts=6035190854;import_export=6035202040;
important_devices=6026568202;inbox=6035067831;indeterminate_check_box=6031068445;info=6026568227;
info_outline=6026568210;input=6026568225;insert_chart=6034925628;insert_chart_outlined=6034925606;
insert_comment=6034925609;insert_drive_file=6034941697;insert_emoticon=6034973079;
insert_invitation=6034973091;insert_link=6034973074;insert_photo=6034941703;insights=6035067839;
integration_instructions=6026568214;inventory=6035056487;invert_colors=6026568253;
invert_colors_off=6035190842;ios_share=6034281941;iso=6034407106;keyboard=6034818398;
keyboard_arrow_down=6034818372;keyboard_arrow_left=6034818375;keyboard_arrow_right=6034818365;
keyboard_arrow_up=6034818379;keyboard_backspace=6034818381;keyboard_capslock=6034818403;
keyboard_hide=6034818386;keyboard_return=6034818370;keyboard_tab=6034818363;keyboard_voice=6034818360;
king_bed=6034281948;kitchen=6035145362;label=6031082525;label_important=6026568215;
label_important_outline=6026568199;label_off=6026568209;label_outline=6026568207;landscape=6034407069;
language=6026568213;laptop=6034818367;laptop_chromebook=6034818364;laptop_mac=6034837808;
laptop_windows=6034837796;last_page=6031094686;launch=6026568211;layers=6034687957;layers_clear=6034687975;
leaderboard=6026568216;leak_add=6034407074;leak_remove=6034407080;legend_toggle=6031097233;lens=6034407081;
library_add=6026660063;library_add_check=6026660083;library_books=6026660085;library_music=6026660075;
lightbulb=6026568247;lightbulb_outline=6026568254;line_style=6026568276;line_weight=6026568226;
linear_scale=6034941707;link=6035056475;link_off=6035056484;linked_camera=6034407082;list=6026568229;
list_alt=6035190838;live_help=6035190836;live_tv=6034439648;local_activity=6034687955;
local_airport=6034687951;local_atm=6034687953;local_bar=6034687950;local_cafe=6034687954;
local_car_wash=6034687976;local_convenience_store=6034687956;local_dining=6034687963;local_drink=6034687965;
local_fire_department=6034684949;local_florist=6034684940;local_gas_station=6034684935;
local_grocery_store=6034684933;local_hospital=6034684956;local_hotel=6034684939;
local_laundry_service=6034684943;local_library=6034684931;local_mall=6034684934;local_movies=6034684936;
local_offer=6034513891;local_parking=6034513893;local_pharmacy=6034513903;local_phone=6034513884;
local_pizza=6034513885;local_play=6034513889;local_police=6034513895;local_post_office=6034513883;
local_printshop=6034513897;local_see=6034513887;local_shipping=6034684926;local_taxi=6034684927;
location_city=6034304889;location_disabled=6034996694;location_off=6035202049;location_on=6035190846;
location_pin=6034684937;location_searching=6034996695;lock=6026568224;lock_clock=6026568260;
lock_open=6026568220;lock_outline=6031082533;login=6031082527;logout=6031082522;looks=6034407096;
looks_3=6034407088;looks_4=6034407089;looks_5=6034412764;looks_6=6034412759;looks_one=6034412761;
looks_two=6034412757;loop=6026660087;loupe=6034412770;low_priority=6035056491;loyalty=6026568237;
luggage=6034295708;lunch_dining=6034684928;mail=6035056477;mail_outline=6035190844;map=6034684930;
maps_ugc=6034509992;margin=6034941701;mark_as_unread=6026568223;mark_chat_read=6035202031;
mark_chat_unread=6035190841;mark_email_read=6035202038;mark_email_unread=6035202027;markunread=6035056476;
markunread_mailbox=6031082531;masks=6034295710;maximize=6026568267;mediation=6026568249;
medical_services=6034510001;meeting_room=6035145361;memory=6034837807;menu=6031097225;menu_book=6034509994;
menu_open=6031097229;merge_type=6034941705;message=6035202033;mic=6026660078;mic_external_off=6034323672;
mic_external_on=6034323671;mic_none=6026660066;mic_off=6026660076;microwave=6035145367;
military_tech=6034295711;minimize=6026568240;miscellaneous_services=6034509993;mms=6034461621;
mobile_friendly=6034996699;mobile_off=6034996702;mobile_screen_share=6035202021;mode_comment=6034941700;
mode_edit=6034941708;model_training=6026568222;monetization_on=6034973115;money=6034509997;
money_off=6034973088;monitor=6034837803;monochrome_photos=6034323678;mood=6034295704;mood_bad=6034295706;
moped=6034509999;more=6034461627;more_horiz=6031104650;more_time=6035202036;more_vert=6031104648;
motion_photos_off=6034323670;motion_photos_on=6034323669;motion_photos_pause=6034323668;
motion_photos_paused=6034323675;mouse=6034837797;move_to_inbox=6035067838;movie=6026660081;
movie_creation=6034323681;movie_filter=6034323687;mp=6034323674;multiline_chart=6034941721;
multiple_stop=6034510026;museum=6034510005;music_note=6034323673;music_off=6034323679;music_video=6026663704;
my_location=6034509987;nat=6035202082;nature=6034323695;nature_people=6034323711;navigate_before=6034323696;
navigate_next=6034315956;navigation=6034509984;near_me=6034509996;near_me_disabled=6034509988;
network_cell=6034996709;network_check=6034461631;network_locked=6034457064;network_wifi=6034996712;
new_releases=6026663730;next_plan=6026568231;next_week=6035067835;nfc=6034996698;night_shelter=6035145378;
nightlife=6034510003;nightlight_round=6031084743;nights_stay=6034304881;no_backpack=6035145368;
no_cell=6035145376;no_drinks=6035145390;no_encryption=6034457059;no_flash=6035145424;no_food=6035145372;
no_luggage=6034304891;no_meals=6034510024;no_meals_ouline=6034510025;no_meeting_room=6035153649;
no_photography=6035153664;no_sim=6035202030;no_stroller=6035153661;no_transfer=6034503363;
north_east=6031097228;north_west=6031104630;not_accessible=6026568269;not_interested=6026663743;
not_listed_location=6034503380;not_started=6026568232;note=6026663734;note_add=6031084749;notes=6034973084;
notifications=6034308946;notifications_active=6034304908;notifications_none=6034308947;
notifications_off=6034304894;notifications_paused=6034304896;offline_bolt=6031084742;offline_pin=6031084770;
offline_share=6031097267;ondemand_video=6034457065;online_prediction=6026568239;opacity=6026568295;
open_in_browser=6026568266;open_in_full=6026568245;open_in_new=6026568256;open_with=6026568265;
outbond=6026568244;outbox=6026568263;outdoor_grill=6034304900;outgoing_mail=6026568242;outlet=6031084748;
outlined_flag=6035056486;padding=6034973078;pages=6034304892;pageview=6031216007;palette=6034316009;
pan_tool=6031084771;panorama=6034315955;panorama_fish_eye=6034315969;panorama_horizontal=6034315966;
panorama_horizontal_select=6034315965;panorama_photosphere=6034412763;panorama_photosphere_select=6034315975;
panorama_vertical=6034315963;panorama_vertical_select=6034315961;panorama_wide_angle=6031770995;
panorama_wide_angle_select=6031770990;park=6034503369;party_mode=6034287521;pause=6026663719;
pause_circle_filled=6026663718;pause_circle_outline=6026663701;pause_presentation=6035202015;
payment=6031084751;payments=6031097227;pedal_bike=6034503374;pending=6031084745;pending_actions=6031260777;
people=6034287513;people_alt=6034287518;people_outline=6034287528;perm_camera_mic=6031215983;
perm_contact_calendar=6031215990;perm_data_setting=6031215991;perm_device_information=6031215996;
perm_identity=6031215978;perm_media=6031215982;perm_phone_msg=6031215986;perm_scan_wifi=6031215985;
person=6034287594;person_add=6034287514;person_add_alt=6034267994;person_add_alt_1=6034287519;
person_add_disabled=6035202007;person_outline=6034268008;person_pin=6034503364;person_pin_circle=6034503375;
person_remove=6034267996;person_remove_alt_1=6034287515;person_search=6035202013;personal_video=6034457070;
pest_control=6034470809;pest_control_rodent=6034470803;pets=6031260782;phone=6035202017;
phone_android=6034837793;phone_bluetooth_speaker=6034457057;phone_callback=6034457104;
phone_disabled=6035202028;phone_enabled=6035202089;phone_forwarded=6034457106;phone_in_talk=6034457067;
phone_iphone=6034837811;phone_locked=6034457058;phone_missed=6034457056;phone_paused=6034457066;
phonelink=6034837801;phonelink_erase=6035202085;phonelink_lock=6035202064;phonelink_off=6034837804;
phonelink_ring=6035202066;phonelink_setup=6035202025;photo=6031770993;photo_album=6031770989;
photo_camera=6031770997;photo_camera_back=6031771007;photo_camera_front=6031771000;photo_filter=6031770992;
photo_library=6031770998;photo_size_select_actual=6031771012;photo_size_select_large=6031763423;
photo_size_select_small=6031763457;picture_as_pdf=6031763425;picture_in_picture=6031215994;
picture_in_picture_alt=6031215979;pie_chart=6034973076;pie_chart_outlined=6034973077;pin_drop=6034470807;
pivot_table_chart=6031097234;place=6034503372;plagiarism=6031243320;play_arrow=6026663699;
play_circle_filled=6026663705;play_circle_outline=6026663726;play_disabled=6026663702;
play_for_work=6031260776;playlist_add=6026663728;playlist_add_check=6026663727;playlist_play=6026663723;
plumbing=6034470800;plus_one=6034268012;point_of_sale=6034837798;policy=6035056512;poll=6034267991;
polymer=6031260785;pool=6035153655;portable_wifi_off=6035202091;portrait=6031763434;post_add=6034973083;
power=6034457105;power_input=6034837794;power_off=6034457087;power_settings_new=6031260781;
present_to_all=6035202020;preview=6031260793;print=6031243324;print_disabled=6035202041;
priority_high=6034457092;privacy_tip=6031260784;psychology=6034287516;public=6034287522;public_off=6034287538;
publish=6034973085;published_with_changes=6031243328;push_pin=6035056481;qr_code=6035202012;
qr_code_scanner=6035202022;query_builder=6031086183;question_answer=6031086172;queue=6026663724;
queue_music=6026663725;queue_play_next=6026663700;quickreply=6031243319;radio=6026663698;
radio_button_checked=6031068426;radio_button_unchecked=6031068433;railway_alert=6034470823;
ramen_dining=6034503377;rate_review=6034503385;read_more=6035202014;receipt=6031086173;
receipt_long=6031763428;recent_actors=6026663773;recommend=6034287524;record_voice_over=6031243318;
redeem=6031086170;redo=6035056483;reduce_capacity=6034268013;refresh=6031097226;remove=6035067836;
remove_circle=6035067837;remove_circle_outline=6035067843;remove_done=6031086169;remove_from_queue=6026663771;
remove_moderator=6034267998;remove_red_eye=6031763426;remove_shopping_cart=6031260778;reorder=6031154868;
repeat=6026666998;repeat_on=6026666994;repeat_one=6026681590;repeat_one_on=6026666992;replay=6026666999;
replay_10=6026667007;replay_30=6026667010;replay_5=6026666993;replay_circle_filled=6026667002;
reply=6035067844;reply_all=6035067824;report=6035067826;report_off=6035067830;report_problem=6031086176;
request_page=6031154873;request_quote=6031302941;reset_tv=6034996696;restaurant=6034503366;
restaurant_menu=6034503378;restore=6031260800;restore_from_trash=6031154869;restore_page=6031154877;
rice_bowl=6035153662;ring_volume=6035202032;roofing=6035153656;room=6031154875;room_preferences=6035153642;
room_service=6035153648;rotate_90_degrees_ccw=6031763456;rotate_left=6031763427;rotate_right=6031763429;
rounded_corner=6031154861;router=6034837806;rowing=6031154857;rss_feed=6035202016;rtt=6035202010;
rule=6031154859;rule_folder=6031302940;run_circle=6034503367;sanitizer=6034287586;satellite=6034503370;
save=6035067857;save_alt=6035067842;saved_search=6031154867;scanner=6034837799;scatter_plot=6034973094;
schedule=6031260808;schedule_send=6031154866;school=6034230641;science=6034230640;score=6034934041;
screen_lock_landscape=6034996700;screen_lock_portrait=6034996706;screen_lock_rotation=6034996710;
screen_rotation=6034996701;screen_search_desktop=6034996711;screen_share=6035202008;sd=6026681582;
sd_card=6034457089;sd_storage=6034996719;search=6031154871;search_off=6031260783;security=6034837802;
segment=6031260773;select_all=6035067834;self_improvement=6034230634;send=6035067832;
send_and_archive=6031280889;send_to_mobile=6034996697;sensor_door=6031067241;sensor_window=6031067242;
sentiment_dissatisfied=6034230637;sentiment_neutral=6034230636;sentiment_satisfied=6034230668;
sentiment_satisfied_alt=6035202069;sentiment_very_dissatisfied=6034230659;sentiment_very_satisfied=6034230650;
set_meal=6034503368;settings=6031280882;settings_applications=6031280894;settings_backup_restore=6031280886;
settings_bluetooth=6031280905;settings_brightness=6031280902;settings_cell=6031280890;
settings_ethernet=6031280883;settings_input_antenna=6031280891;settings_input_component=6031280884;
settings_input_composite=6031280896;settings_input_hdmi=6031280970;settings_input_svideo=6031289444;
settings_overscan=6031289459;settings_phone=6031289445;settings_power=6031289446;settings_remote=6031289442;
settings_system_daydream=6035030081;settings_voice=6031265966;share=6034230648;shield=6035078889;
shop=6031265983;shop_two=6031289461;shopping_bag=6031265970;shopping_basket=6031265997;
shopping_cart=6031265976;short_text=6034934035;show_chart=6034934032;shuffle=6026667003;shuffle_on=6026666996;
shutter_speed=6031763443;sick=6034230642;signal_cellular_0_bar=6035030072;signal_cellular_4_bar=6035030076;
signal_cellular_alt=6035030079;signal_cellular_connected_no_internet_4=6035229858;
signal_cellular_no_sim=6035030078;signal_cellular_null=6035030075;signal_cellular_off=6035030084;
signal_wifi_0_bar=6035030067;signal_wifi_4_bar=6035030077;signal_wifi_off=6035030074;sim_card=6034837800;
sim_card_alert=6034452641;single_bed=6034230651;skip_next=6026667005;skip_previous=6026667011;
slideshow=6031754546;slow_motion_video=6026681583;smart_button=6031265962;smartphone=6034848731;
smoke_free=6035153647;smoking_rooms=6035153636;sms=6034452645;sms_failed=6034452676;snippet_folder=6031302947;
snooze=6026667006;soap=6035153645;sort=6035078888;sort_by_alpha=6026667009;source=6031289451;south=6031104646;
south_east=6031104642;south_west=6031104652;spa=6035153639;space_bar=6034934037;sparkle=4483362748;
speaker=6034848746;speaker_group=6034848732;speaker_notes=6031266001;speaker_notes_off=6031265965;
speaker_phone=6035202018;speed=6026681578;spellcheck=6031289450;sports=6034230647;sports_bar=6035153638;
sports_baseball=6034230652;sports_basketball=6034230649;sports_cricket=6034230660;sports_esports=6034227061;
sports_football=6034227067;sports_golf=6034227060;sports_handball=6034227074;sports_hockey=6034227064;
sports_kabaddi=6034227141;sports_mma=6034227072;sports_motorsports=6034227071;sports_rugby=6034227073;
sports_soccer=6034227075;sports_tennis=6034227068;sports_volleyball=6034227139;square_foot=6035078918;
stacked_bar_chart=6035078892;stacked_line_chart=6034934039;stairs=6035153637;star=6031068423;
star_border=6031068425;star_half=6031068427;star_outline=6031068428;star_rate=6031265978;stars=6031265971;
stay_current_landscape=6035202011;stay_current_portrait=6035202004;stay_primary_landscape=6035202026;
stay_primary_portrait=6035202009;sticky_note_2=6031265972;stop=6026681576;stop_circle=6026681577;
stop_screen_share=6035202042;storage=6035030083;store=6031265968;store_mall_directory=6034470811;
storefront=6035161534;straighten=6031754545;stream=6035078897;streetview=6034470805;
strikethrough_s=6034934030;stroller=6035161535;style=6031754538;subdirectory_arrow_left=6031104654;
subdirectory_arrow_right=6031104647;subject=6031289452;subscript=6034934059;subscriptions=6026671207;
subtitles=6026671203;subtitles_off=6031289466;subway=6034467790;superscript=6034934034;
supervised_user_circle=6031289449;supervisor_account=6031251516;support=6031251532;support_agent=6034452656;
surround_sound=6026671209;swap_calls=6035202037;swap_horiz=6031233841;swap_horizontal_circle=6031233833;
swap_vert=6031233847;swap_vertical_circle=6031233839;swipe=6031233863;switch_account=6034227138;
switch_camera=6031754550;switch_left=6031104651;switch_right=6031104649;switch_video=6031754536;
sync=6034452662;sync_alt=6031233840;sync_disabled=6034452649;sync_problem=6034452653;system_update=6034452663;
system_update_alt=6031251515;tab=6031233851;tab_unselected=6031251505;table_chart=6034973081;
table_rows=6034934025;table_view=6031233835;tablet=6034848733;tablet_android=6034848734;tag=6035078895;
tag_faces=6031754560;takeout_dining=6034467808;tap_and_play=6034452650;tapas=6035161533;taxi_alert=6034467792;
terrain=6034467794;text_fields=6034934040;text_format=6035078890;text_rotate_up=6031251526;
text_rotate_vertical=6031251518;text_rotation_angledown=6031251513;text_rotation_angleup=6031229337;
text_rotation_down=6031229334;text_rotation_none=6031229344;text_snippet=6031302995;textsms=6035202006;
texture=6031754553;theater_comedy=6034467796;theaters=6031229335;thumb_down=6031229336;
thumb_down_alt=6034227069;thumb_down_off_alt=6031229354;thumb_up=6031229347;thumb_up_alt=6034227076;
thumb_up_off_alt=6031229342;thumbs_up_down=6031229373;time_to_leave=6034452660;timelapse=6031754541;
timeline=6031229350;timer=6031754564;timer_10=6031734880;timer_3=6031754540;timer_off=6031734881;
title=6034934042;toc=6031229341;today=6031229352;toggle_off=6031068429;toggle_on=6031068430;toll=6031229343;
tonality=6031734891;topic=6031302976;touch_app=6031229361;tour=6031229362;toys=6034848752;
track_changes=6031225814;traffic=6034467797;train=6034467803;tram=6034467806;
transfer_within_a_station=6034467809;transform=6031734873;transit_enterexit=6034467805;translate=6031225812;
trending_down=6031225811;trending_flat=6031225818;trending_up=6031225816;trip_origin=6034467804;
tty=6035161541;tune=6031734877;turned_in=6031225808;turned_in_not=6031225806;tv=6034848740;tv_off=6034452646;
two_wheeler=6034467795;umbrella=6035161550;unarchive=6035078921;undo=6035078896;unfold_less=6031104681;
unfold_more=6031104644;unpublished=6031225817;unsubscribe=6035202044;update=6031225810;upgrade=6031225815;
upload_file=6031302959;usb=6035030080;verified=6031225809;verified_user=6031225819;
vertical_align_bottom=6034934023;vertical_align_center=6034934051;vertical_align_top=6034973080;
vertical_split=6031225820;vibration=6034452651;video_label=6026671204;video_library=6026671208;
video_settings=6026671211;videocam=6026671213;videocam_off=6026671212;videogame_asset=6034848748;
view_agenda=6031225831;view_array=6031225842;view_carousel=6031251507;view_column=6031079172;
view_comfy=6031734876;view_compact=6031734878;view_day=6031079153;view_headline=6031079151;
view_in_ar=6031079158;view_list=6031079156;view_module=6031079152;view_quilt=6031079155;
view_sidebar=6031079160;view_stream=6031079164;view_week=6031079154;vignette=6031734905;visibility=6031075931;
visibility_off=6031075929;voice_over_off=6031075927;voicemail=6035202019;volume_down=6026671206;
volume_mute=6026671214;volume_off=6026671224;volume_up=6026671215;volunteer_activism=6034467799;
vpn_key=6035202034;vpn_lock=6034452648;wallpaper=6035030102;wash=6035161540;watch=6034848747;
watch_later=6031075924;water_damage=6035161563;waterfall_chart=6031104632;waves=6035078898;wb_auto=6031734875;
wb_cloudy=6031734907;wb_incandescent=6034316010;wb_iridescent=6034315972;wb_shade=6034315974;
wb_sunny=6034412758;wb_twighlight=6034412760;wc=6034452643;web=6026671234;web_asset=6026671239;
weekend=6035078894;west=6031104677;whatshot=6034287525;wheelchair_pickup=6035161536;where_to_vote=6035078913;
widgets=6035039429;wifi=6034461626;wifi_calling=6035202065;wifi_lock=6035039428;wifi_off=6034461625;
wifi_protected_setup=6031075926;wifi_tethering=6035039430;work=6031075939;work_off=6031075937;
work_outline=6031075930;workspaces_filled=6031302961;workspaces_outline=6031302952;wrap_text=6034973118;
wrong_location=6034467801;wysiwyg=6031075938;youtube_searched_for=6031075934;zoom_in=6031075573;
zoom_out=6031075577;zoom_out_map=6035229856;
]==]
end

__defs["Core/Gui"] = function()
-- Корневой ScreenGui, тултипы, модальные карточки
local Env = import("Core/Env")
local ThemeM = import("Core/Theme")
local Util = import("Core/Util")

local new, tween, corner, stroke, padding = Util.new, Util.tween, Util.corner, Util.stroke, Util.padding

local Gui = { _gui = nil, _tip = nil, _conns = {} }

function Gui.get()
	if Gui._gui and Gui._gui.Parent then
		return Gui._gui
	end
	pcall(function()
		local env = getgenv and getgenv() or _G
		if env.__MajesticGui then
			env.__MajesticGui:Destroy()
		end
	end)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Majestic"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 999
	pcall(function()
		if syn and syn.protect_gui then
			syn.protect_gui(gui)
		end
	end)
	local parent
	pcall(function()
		parent = gethui and gethui()
	end)
	parent = parent or Env.CoreGui
	local ok = pcall(function()
		gui.Parent = parent
	end)
	if not ok or not gui.Parent then
		gui.Parent = Env.LocalPlayer:WaitForChild("PlayerGui")
	end
	pcall(function()
		(getgenv and getgenv() or _G).__MajesticGui = gui
	end)
	Gui._gui = gui
	ThemeM.Root = gui
	return gui
end

function Gui.destroy()
	for _, c in ipairs(Gui._conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(Gui._conns)
	if Gui._gui then
		Gui._gui:Destroy()
		Gui._gui = nil
	end
	Gui._tip = nil
end

----------------------------------------------------------------------
-- Тултипы
----------------------------------------------------------------------
local function ensureTip()
	if Gui._tip then
		return Gui._tip
	end
	local gui = Gui.get()
	local frame = new("Frame", {
		Name = "Tooltip", Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY,
		Visible = false, ZIndex = 900, Theme = { BackgroundColor3 = "Topbar" }, Parent = gui,
	})
	corner(frame, 6)
	stroke(frame)
	padding(frame, 6, 6, 9, 9)
	local label = new("TextLabel", {
		Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, TextWrapped = true,
		TextSize = 12, ZIndex = 901, Theme = { TextColor3 = "Text" }, Parent = frame,
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(260, 1000), Parent = label })
	table.insert(Gui._conns, Env.UserInputService.InputChanged:Connect(function(i)
		if frame.Visible and i.UserInputType == Enum.UserInputType.MouseMovement then
			local cam = workspace.CurrentCamera
			local maxX = cam and cam.ViewportSize.X - frame.AbsoluteSize.X - 6 or 9999
			frame.Position = UDim2.fromOffset(math.min(i.Position.X + 14, maxX), i.Position.Y + 18)
		end
	end))
	Gui._tip = { frame = frame, label = label }
	return Gui._tip
end

-- ref = { text = "..." }; текст можно менять после создания
function Gui.tooltip(inst, ref)
	local token = 0
	inst.MouseEnter:Connect(function()
		token += 1
		local my = token
		task.delay(0.4, function()
			if my ~= token or not ref.text or ref.text == "" then
				return
			end
			local tip = ensureTip()
			tip.label.Text = ref.text
			local m = Env.UserInputService:GetMouseLocation() - Env.GuiService:GetGuiInset()
			tip.frame.Position = UDim2.fromOffset(m.X + 14, m.Y + 18)
			tip.frame.Visible = true
		end)
	end)
	inst.MouseLeave:Connect(function()
		token += 1
		if Gui._tip then
			Gui._tip.frame.Visible = false
		end
	end)
end

----------------------------------------------------------------------
-- Модальная карточка по центру (загрузка, ключ, диалог)
----------------------------------------------------------------------
function Gui.modal(width, parent, opts)
	opts = opts or {}
	parent = parent or Gui.get()
	local dim = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
		Active = true, ZIndex = opts.zindex or 100, Parent = parent,
	})
	tween(dim, { BackgroundTransparency = opts.dim or 0.4 }, 0.2)
	local card = new("Frame", {
		Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Theme = { BackgroundColor3 = "Topbar" }, Parent = dim,
	})
	corner(card, 12)
	stroke(card)
	local scale = new("UIScale", { Scale = 0.9, Parent = card })
	tween(scale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
	local inner = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = card,
	})
	padding(inner, 18, 18, 18, 18)
	Util.list(inner, 10)

	local modal = { dim = dim, card = card, inner = inner, scale = scale, closed = false }
	function modal.close(instant)
		if modal.closed then
			return
		end
		modal.closed = true
		if instant then
			dim:Destroy()
			return
		end
		tween(dim, { BackgroundTransparency = 1 }, 0.18)
		tween(scale, { Scale = 0.92 }, 0.18)
		task.delay(0.2, function()
			dim:Destroy()
		end)
	end
	return modal
end

return Gui
end

__defs["Core/Icons"] = function()
-- Иконки. Наборы: Lucide (спрайт-лист по ссылке), Material (встроен), свой набор по ссылке.
-- Выбор набора: IconUrl = "Lucide" | "Material" | "https://...", либо префикс в имени: "material:home".
local Env = import("Core/Env")
local ThemeM = import("Core/Theme")
local Util = import("Core/Util")
local Shapes = import("Core/Shapes")

local Icons = {
	Default = "Lucide", -- набор по умолчанию: "Lucide" или "Material"
	-- спрайт-лист Lucide (формат { ["48px"] = { имя = { assetId, {w,h}, {x,y} } } })
	LucideUrl = "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/icons.lua",
	Custom = {}, -- свои иконки: Icons.Custom["logo"] = 123456789
	Aliases = {
		house = "home", gear = "settings", cog = "settings", person = "user", players = "users",
		config = "sliders-horizontal", theme = "palette", warning = "triangle-alert",
		visuals = "eye", combat = "swords", misc = "layout-dashboard",
	},
	-- «действия»: одна и та же смысловая иконка в разных наборах
	Semantic = {
		click = { lucide = "mouse-pointer-click", material = "touch_app" },
		copy = { lucide = "copy", material = "content_copy" },
		save = { lucide = "save", material = "save" },
		load = { lucide = "download", material = "file_download" },
		delete = { lucide = "trash-2", material = "delete_outline" },
		refresh = { lucide = "refresh-cw", material = "refresh" },
		check = { lucide = "check", material = "check" },
		clear = { lucide = "x", material = "close" },
		user = { lucide = "user", material = "person" },
	},
	_sheets = {}, -- url -> { set = таблица | nil, failed = bool }
	_material = nil,
}

----------------------------------------------------------------------
-- Загрузка наборов
----------------------------------------------------------------------
local function loadSheet(url)
	local entry = Icons._sheets[url]
	if entry then
		return entry.set
	end
	entry = { failed = false }
	Icons._sheets[url] = entry
	local src = Env.httpGet(url)
	if src then
		local ok, res = pcall(function()
			local f = loadstring(src)
			return f()
		end)
		if ok and type(res) == "table" then
			entry.set = res
			return res
		end
	end
	entry.failed = true
	return nil
end

local function materialSet()
	if Icons._material then
		return Icons._material
	end
	local map = {}
	local data = import("Core/MaterialData")
	for name, id in string.gmatch(data, "([%w_]+)=(%d+)") do
		map[name] = id
	end
	Icons._material = map
	return map
end

local function assetOf(v)
	if type(v) == "number" then
		return "rbxassetid://" .. v
	end
	return v
end

-- "Lucide" / "Material" / "https://..." -> "lucide" / "material" / ссылка
local function normalizeSet(set)
	if type(set) ~= "string" or set == "" then
		return nil
	end
	local l = set:lower()
	if l == "lucide" or l == "material" then
		return l
	end
	if l:find("^https?://") then
		return set
	end
	return nil
end

local function lookup(source, name, px)
	if source == "material" then
		local id = materialSet()[name:gsub("-", "_")]
		if id then
			return { Image = "rbxassetid://" .. id, Tint = true }
		end
		return nil
	end
	local set
	if source == "lucide" then
		set = loadSheet(Icons.LucideUrl)
		name = Icons.Aliases[name] or name
		name = name:gsub("_", "-")
	else
		set = loadSheet(source)
	end
	if not set then
		return nil
	end
	local sheet = (px and px > 24) and set["256px"] or set["48px"]
	local e = sheet and sheet[name]
	if e then
		return {
			Image = "rbxassetid://" .. e[1],
			RectSize = Vector2.new(e[2][1], e[2][2]),
			RectOffset = Vector2.new(e[3][1], e[3][2]),
			Tint = true,
		}
	end
	return nil
end

----------------------------------------------------------------------
-- Разбор значения Icon
----------------------------------------------------------------------
-- icon: имя | "lucide:имя" | "material:имя" | число | rbxassetid | эмодзи/текст | таблица { Image, RectSize, RectOffset }
-- set:  IconUrl элемента/окна
function Icons.resolve(icon, px, set)
	if icon == nil or icon == "" then
		return nil
	end
	local t = typeof(icon)
	if t == "number" then
		return { Image = assetOf(icon) }
	end
	if t == "table" then
		return icon
	end
	if t ~= "string" then
		return nil
	end
	if icon:find("^rbxassetid://") or icon:find("^rbxasset://") or icon:find("^https?://") then
		return { Image = icon }
	end

	local name, forced = icon, nil
	local prefix, rest = icon:match("^(%a+):(.+)$")
	if prefix and (prefix:lower() == "lucide" or prefix:lower() == "material") then
		forced, name = prefix:lower(), rest
	end

	local custom = Icons.Custom[name]
	if custom ~= nil then
		if type(custom) == "table" then
			return custom
		end
		return { Image = assetOf(custom) }
	end

	if forced or name:match("^[%l%d%-_]+$") then
		local primary = forced or normalizeSet(set) or normalizeSet(Icons.Default) or "lucide"
		local found = lookup(primary, name, px)
		if not found and not forced then
			-- запасной вариант: другой встроенный набор
			found = lookup(primary == "material" and "lucide" or "material", name, px)
		end
		return found
	end
	return { Text = icon } -- эмодзи или обычный текст
end

-- имя «действия» (click, copy, save, ...) в выбранном наборе
function Icons.semanticName(key, set)
	local s = Icons.Semantic[key]
	if not s then
		return nil
	end
	local source = normalizeSet(set) or normalizeSet(Icons.Default) or "lucide"
	if source ~= "lucide" and source ~= "material" then
		source = "lucide"
	end
	return source .. ":" .. s[source]
end

-- создаёт ImageLabel/TextLabel с иконкой; nil, если иконки нет.
-- colorKey: ключ темы (по умолчанию "Text") или false (не красить, белая)
function Icons.create(parent, icon, px, colorKey, set)
	local r = Icons.resolve(icon, px, set)
	if not r then
		return nil
	end
	local inst
	if r.Image then
		inst = Util.new("ImageLabel", { Size = UDim2.fromOffset(px, px), Image = r.Image })
		if r.RectSize then
			inst.ImageRectSize = r.RectSize
			inst.ImageRectOffset = r.RectOffset
		end
		if r.Tint and colorKey ~= false then
			ThemeM.bind(inst, "ImageColor3", colorKey or "Text")
		end
	else
		inst = Util.new("TextLabel", {
			Size = UDim2.fromOffset(px, px), Text = r.Text, TextSize = math.max(px - 4, 10),
			TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold,
		})
		if colorKey == false then
			inst.TextColor3 = Color3.new(1, 1, 1)
		else
			ThemeM.bind(inst, "TextColor3", colorKey or "Text")
		end
	end
	inst.Parent = parent
	return inst
end

-- иконка «действия» по смыслу; если иконки недоступны, рисуется стрелка
function Icons.createAction(parent, key, px, colorKey, set)
	local name = Icons.semanticName(key, set)
	local inst = name and Icons.create(parent, name, px, colorKey, set)
	if inst then
		return inst
	end
	return Shapes.chevron(parent, px, colorKey, "right")
end

-- список имён набора ("Lucide" требует загрузки)
function Icons.names(set)
	local source = normalizeSet(set) or "lucide"
	local out = {}
	if source == "material" then
		for n in pairs(materialSet()) do
			table.insert(out, n)
		end
	else
		local s
		if source == "lucide" then
			s = loadSheet(Icons.LucideUrl)
		else
			s = loadSheet(source)
		end
		local sheet = s and s["48px"]
		for n in pairs(sheet or {}) do
			table.insert(out, n)
		end
	end
	table.sort(out)
	return out
end

return Icons
end

__defs["Core/Glass"] = function()
-- Liquid Glass: настоящее размытие игрового мира за окном.
-- Принцип (как в акриле Fluent): почти прозрачная стеклянная Part вплотную к камере повторяет прямоугольник окна,
-- а эффект DepthOfField размывает «ближние» пиксели, то есть всё, что закрыто этой деталью.
-- Сила размытия: Blur 0-100 -> от 0 до 3 наложенных эффектов DepthOfField.
-- Ограничения: размывается только 3D-сцена (не другие GUI); на низкой графике DepthOfField может не отображаться.
local Env = import("Core/Env")
local ThemeM = import("Core/Theme")

local EFFECT_NAME = "MajesticGlassBlur"
local PART_TRANSPARENCY = 0.98

local Glass = {
	_targets = {},
	_effects = {},
	_saved = {}, -- чужие DepthOfField, которые мы отключили на время работы
	_camConns = {},
	_bound = false,
}

local function map(v, a, b, c, d)
	return (v - a) * (d - c) / (b - a) + c
end

local function worldPoint(pos, dist)
	local ray = workspace.CurrentCamera:ScreenPointToRay(pos.X, pos.Y)
	return ray.Origin + ray.Direction * dist
end

local function createPart()
	local part = Instance.new("Part")
	part.Name = "MajesticGlass"
	part.Color = Color3.new(0, 0, 0)
	part.Material = Enum.Material.Glass
	part.Size = Vector3.new(1, 1, 0)
	part.Anchored = true
	part.CanCollide = false
	part.Locked = true
	part.CastShadow = false
	part.Transparency = 1
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Brick
	mesh.Offset = Vector3.new(0, 0, -1e-6)
	mesh.Parent = part
	part.Parent = workspace
	return part, mesh
end

local function active()
	return ThemeM.Glass.Enabled and ThemeM.Glass.Blur > 0 and #Glass._targets > 0
end

-- подгоняет деталь под экранный прямоугольник рамки
local function updateTarget(t)
	local cam = workspace.CurrentCamera
	local frame = t.frame
	if not cam or not frame.Parent then
		return
	end
	local show = active() and frame.Visible and frame.AbsoluteSize.X > 2
	t.part.Transparency = show and PART_TRANSPARENCY or 1
	if not show then
		return
	end
	-- размытие чуть меньше окна, чтобы края не «вытекали» за рамку
	local off = map(cam.ViewportSize.Y, 0, 2560, 8, 56)
	local size = frame.AbsoluteSize - Vector2.new(off, off)
	local pos = frame.AbsolutePosition + Vector2.new(off / 2, off / 2)
	local dist = 0.001
	local tl = worldPoint(pos, dist)
	local tr = worldPoint(pos + Vector2.new(size.X, 0), dist)
	local br = worldPoint(pos + size, dist)
	local width, height = (tr - tl).Magnitude, (tr - br).Magnitude
	local cf = cam.CFrame
	t.part.CFrame = CFrame.fromMatrix((tl + br) / 2, cf.XVector, cf.YVector, cf.ZVector)
	t.mesh.Scale = Vector3.new(width, height, 0)
end

local function updateAll()
	for _, t in ipairs(Glass._targets) do
		updateTarget(t)
	end
end

----------------------------------------------------------------------
-- Эффекты DepthOfField
----------------------------------------------------------------------
local function setOtherDofEnabled(enabled)
	if enabled then
		for inst, was in pairs(Glass._saved) do
			pcall(function()
				inst.Enabled = was
			end)
		end
		table.clear(Glass._saved)
		return
	end
	local function scan(parent)
		if not parent then
			return
		end
		for _, c in ipairs(parent:GetChildren()) do
			if c:IsA("DepthOfFieldEffect") and c.Name ~= EFFECT_NAME and Glass._saved[c] == nil then
				Glass._saved[c] = c.Enabled
				c.Enabled = false
			end
		end
	end
	scan(Env.Lighting)
	scan(workspace.CurrentCamera)
end

local function applyEffects()
	if not active() then
		for _, e in ipairs(Glass._effects) do
			e:Destroy()
		end
		table.clear(Glass._effects)
		setOtherDofEnabled(true)
		return
	end
	-- Blur 0-100 -> суммарная интенсивность 0-3, раскладывается на эффекты по 1.0
	local total = ThemeM.Glass.Blur / 100 * 3
	local count = math.ceil(total)
	if #Glass._effects == 0 then
		setOtherDofEnabled(false)
	end
	while #Glass._effects < count do
		local e = Instance.new("DepthOfFieldEffect")
		e.Name = EFFECT_NAME
		e.FarIntensity = 0
		e.InFocusRadius = 0.1
		e.Parent = Env.Lighting
		table.insert(Glass._effects, e)
	end
	while #Glass._effects > count do
		local last = table.remove(Glass._effects)
		if last then
			last:Destroy()
		end
	end
	for i, e in ipairs(Glass._effects) do
		e.NearIntensity = math.clamp(total - (i - 1), 0, 1)
	end
end

local function bindCamera()
	if Glass._bound then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	Glass._bound = true
	for _, prop in ipairs({ "CFrame", "ViewportSize", "FieldOfView" }) do
		table.insert(Glass._camConns, cam:GetPropertyChangedSignal(prop):Connect(updateAll))
	end
end

local function unbindCamera()
	for _, c in ipairs(Glass._camConns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(Glass._camConns)
	Glass._bound = false
end

-- вызывается при смене темы и настроек стекла
function Glass.refresh()
	applyEffects()
	updateAll()
end

-- frame — рамка, область которой нужно размывать; возвращает { Destroy = function }
function Glass.attach(frame)
	local part, mesh = createPart()
	local t = { frame = frame, part = part, mesh = mesh, conns = {} }
	table.insert(Glass._targets, t)
	local function upd()
		updateTarget(t)
	end
	table.insert(t.conns, frame:GetPropertyChangedSignal("AbsolutePosition"):Connect(upd))
	table.insert(t.conns, frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(upd))
	table.insert(t.conns, frame:GetPropertyChangedSignal("Visible"):Connect(upd))
	bindCamera()
	Glass.refresh()
	local handle = {}
	function handle.Destroy()
		for _, c in ipairs(t.conns) do
			pcall(function()
				c:Disconnect()
			end)
		end
		part:Destroy()
		local idx = table.find(Glass._targets, t)
		if idx then
			table.remove(Glass._targets, idx)
		end
		if #Glass._targets == 0 then
			unbindCamera()
		end
		applyEffects()
	end
	return handle
end

function Glass.destroyAll()
	for i = #Glass._targets, 1, -1 do
		local t = Glass._targets[i]
		pcall(function()
			t.part:Destroy()
		end)
		for _, c in ipairs(t.conns) do
			pcall(function()
				c:Disconnect()
			end)
		end
	end
	table.clear(Glass._targets)
	unbindCamera()
	applyEffects()
end

table.insert(ThemeM._hooks, Glass.refresh)

return Glass
end

__defs["Core/Config"] = function()
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
end

__defs["Core/Container"] = function()
-- Контейнер элементов: от него наследуются Tab, Group и колонки.
-- Методы элементов (Toggle, Slider, ...) добавляются в Elements/*.lua
local Container = {}
Container.__index = Container

function Container.new(window, tab, holder, scroller)
	return setmetatable({
		Window = window,
		Tab = tab, -- вкладка-владелец (для поиска и прокрутки)
		Holder = holder, -- Frame, куда кладутся карточки
		Scroller = scroller, -- ScrollingFrame вкладки (блокируется при перетаскивании)
		Elements = {},
		_n = 0,
	}, Container)
end

function Container:_nextOrder()
	self._n += 1
	return self._n
end

return Container
end

__defs["Core/Element"] = function()
-- Базовый элемент: общие методы, построитель карточки, перетаскивание
local Env = import("Core/Env")
local State = import("Core/State")
local ThemeM = import("Core/Theme")
local Util = import("Core/Util")
local Icons = import("Core/Icons")
local Gui = import("Core/Gui")
local Shapes = import("Core/Shapes")

local new, tween, corner, stroke, padding = Util.new, Util.tween, Util.corner, Util.stroke, Util.padding
local fire = Util.fire

local E = {}

local Element = {}
Element.__index = Element
E.Element = Element

function Element:SetVisible(v)
	self._row.Visible = v and true or false
end

function Element:SetTitle(t)
	self._title.Text = tostring(t)
	self.Name = tostring(t)
end

function Element:SetDesc(t)
	if not self._desc then
		return
	end
	t = tostring(t or "")
	self._desc.Text = t
	self._desc.Visible = t ~= ""
end

function Element:SetTooltip(t)
	if self._tip then
		self._tip.text = t
	end
end

-- блокирует элемент: затемнение + перехват ввода
function Element:SetLocked(v)
	self.Locked = v and true or false
	if v then
		if not self._lock then
			self._lock = new("TextButton", {
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.5, ZIndex = 20, Active = true,
				Theme = { BackgroundColor3 = "Background" }, Parent = self._row,
			})
		end
	elseif self._lock then
		self._lock:Destroy()
		self._lock = nil
	end
end

function Element:OnChanged(fn)
	table.insert(self._listeners, fn)
	return self
end

-- переходит на вкладку элемента, прокручивает к нему и подсвечивает рамку
function Element:Focus()
	local container = self._container
	local tab = container.Tab
	if container.Expand then
		container:Expand()
	end
	if tab and tab.Select then
		tab:Select()
	end
	task.defer(function()
		local page = tab and tab.Page
		if page and self._row.Parent then
			local y = self._row.AbsolutePosition.Y - page.AbsolutePosition.Y + page.CanvasPosition.Y - 10
			page.CanvasPosition = Vector2.new(0, math.max(0, y))
		end
		local st = self._stroke
		if st then
			st.Color = ThemeM.Colors.Accent
			st.Thickness = 2
			tween(st, { Color = ThemeM.Colors.Stroke, Thickness = 1 }, 1.4)
		end
	end)
end

function Element:Destroy()
	if self.Flag then
		State.Flags[self.Flag] = nil
		State.Options[self.Flag] = nil
	end
	for _, c in ipairs(self._conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	local list = self._container.Elements
	local idx = table.find(list, self)
	if idx then
		table.remove(list, idx)
	end
	local all = self._container.Window._elements
	idx = table.find(all, self)
	if idx then
		table.remove(all, idx)
	end
	self._row:Destroy()
end

----------------------------------------------------------------------
-- Конструкторы
----------------------------------------------------------------------

-- карточка: header (иконка + название + контрол справа), desc, дальше body
function E.buildRow(container, cfg, reserve)
	local mobile = Env.IsMobile
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = true,
		LayoutOrder = container:_nextOrder(), Theme = { BackgroundColor3 = "Element" }, Parent = container.Holder,
	})
	corner(row, 7)
	local st = stroke(row)
	local content = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = row,
	})
	local pad = mobile and 11 or 9
	padding(content, pad, pad, 12, 12)
	Util.list(content, 5)
	local header = new("Frame", {
		Size = UDim2.new(1, 0, 0, mobile and 26 or 22), BackgroundTransparency = 1, LayoutOrder = 1, Parent = content,
	})
	local indent, icon = 0, nil
	if cfg.Icon then
		icon = Icons.create(header, cfg.Icon, 16, "SubText", cfg.IconUrl or container.Window.IconUrl)
		if icon then
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, 0, 0.5, 0)
			indent = 24
		end
	end
	local title = new("TextLabel", {
		Size = UDim2.new(1, -((reserve or 0) + indent), 1, 0), Position = UDim2.fromOffset(indent, 0),
		Text = cfg.Name, TextTruncate = Enum.TextTruncate.AtEnd, Theme = { TextColor3 = "Text" }, Parent = header,
	})
	local hasDesc = cfg.Desc ~= nil and cfg.Desc ~= ""
	local desc = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2,
		Text = hasDesc and tostring(cfg.Desc) or "", Visible = hasDesc, TextWrapped = true, TextSize = 12,
		TextYAlignment = Enum.TextYAlignment.Top, Theme = { TextColor3 = "SubText" }, Parent = content,
	})
	local tip = { text = cfg.Tooltip }
	Gui.tooltip(row, tip)
	return {
		row = row, content = content, header = header, title = title, desc = desc,
		stroke = st, tip = tip, icon = icon,
	}
end

function E.newElement(container, p, cfg)
	return setmetatable({
		_container = container, _row = p.row, _title = p.title, _desc = p.desc, _stroke = p.stroke,
		_tip = p.tip, _callback = cfg.Callback, _conns = {}, _listeners = {}, Name = cfg.Name,
	}, Element)
end

-- обновляет флаг и вызывает колбэки (silent = только флаг)
function E.changed(el, silent, ...)
	if el.Flag then
		State.Flags[el.Flag] = el:Get()
	end
	if silent then
		return
	end
	fire(el._callback, ...)
	for _, fn in ipairs(el._listeners) do
		fire(fn, ...)
	end
end

function E.register(el, cfg, typ)
	el.Type = typ
	if cfg.Flag then
		el.Flag = cfg.Flag
		State.Options[cfg.Flag] = el
		State.Flags[cfg.Flag] = el:Get()
	end
	table.insert(el._container.Elements, el)
	table.insert(el._container.Window._elements, el)
	if cfg.Locked then
		el:SetLocked(true)
	end
	if cfg.Fire and typ ~= "Button" then
		fire(el._callback, el:Get())
	end
	return el
end

-- подключение, которое отключится вместе с элементом и окном
function E.connect(container, el, signal, fn)
	local c = signal:Connect(fn)
	table.insert(el._conns, c)
	table.insert(container.Window._conns, c)
	return c
end

-- прозрачная кнопка поверх всей карточки (подсветка + клик)
function E.overlay(row, onClick)
	local b = new("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = row })
	b.MouseEnter:Connect(function()
		tween(row, { BackgroundColor3 = ThemeM.Colors.ElementHover }, 0.12)
	end)
	b.MouseLeave:Connect(function()
		tween(row, { BackgroundColor3 = ThemeM.Colors.Element }, 0.12)
	end)
	b.MouseButton1Click:Connect(function()
		if onClick then
			onClick()
		end
	end)
	return b
end

-- перетаскивание по области (слайдеры, колорпикер); onDrag(x, y), onEnd() после отпускания
function E.dragArea(container, el, area, onDrag, onEnd)
	local dragging = false
	local scroller = container.Scroller
	area.InputBegan:Connect(function(i)
		if Util.isPress(i) then
			dragging = true
			if scroller then
				scroller.ScrollingEnabled = false
			end
			onDrag(i.Position.X, i.Position.Y)
			local conn
			conn = i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					dragging = false
					if scroller then
						scroller.ScrollingEnabled = true
					end
					conn:Disconnect()
					if onEnd then
						onEnd()
					end
				end
			end)
		end
	end)
	E.connect(container, el, Env.UserInputService.InputChanged, function(i)
		if dragging and Util.isMove(i) then
			onDrag(i.Position.X, i.Position.Y)
		end
	end)
end

-- Круглая «таблетка» справа в строке кнопки: иконка действия вместо текста.
-- cfg.ButtonIcon: смысл ("click", "copy", "save", "load", "delete", "refresh", "check", "clear") или имя иконки;
-- cfg.ButtonText: текст вместо иконки (если иконка не задана).
function E.actionPill(container, header, cfg, defaultAction)
	local set = cfg.IconUrl or container.Window.IconUrl
	local text = cfg.ButtonText
	local action = cfg.ButtonIcon or ((not text) and defaultAction or nil)
	local pill = new("Frame", {
		Size = UDim2.fromOffset(34, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Theme = { BackgroundColor3 = "Accent" }, Parent = header,
	})
	corner(pill, 6)
	local inner
	if action then
		local iconName = Icons.Semantic[action] and Icons.semanticName(action, set) or action
		inner = Icons.create(pill, iconName, 14, false, set)
	end
	if inner then
		inner.AnchorPoint = Vector2.new(0.5, 0.5)
		inner.Position = UDim2.fromScale(0.5, 0.5)
	elseif text then
		-- иконка недоступна: показываем текст
		pill.Size = UDim2.fromOffset(70, 22)
		new("TextLabel", {
			Size = UDim2.fromScale(1, 1), Text = tostring(text), TextXAlignment = Enum.TextXAlignment.Center,
			Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), Parent = pill,
		})
	else
		local arrow = Shapes.chevron(pill, 14, false, "right")
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.Position = UDim2.fromScale(0.5, 0.5)
	end
	return pill
end

return E
end

__defs["Core/Window"] = function()
-- Окно, вкладки, поиск по меню
local Env = import("Core/Env")
local State = import("Core/State")
local ThemeM = import("Core/Theme")
local Util = import("Core/Util")
local Gui = import("Core/Gui")
local Icons = import("Core/Icons")
local Shapes = import("Core/Shapes")
local Glass = import("Core/Glass")
local Config = import("Core/Config")
local Container = import("Core/Container")

local new, tween, corner, stroke, padding = Util.new, Util.tween, Util.corner, Util.stroke, Util.padding
local isPress, isMove = Util.isPress, Util.isMove
local UIS = Env.UserInputService

local Window = {}
Window.__index = Window

-- Tab наследует Container: tab:Toggle(...), tab:Group(...), tab:Columns(...)
local Tab = setmetatable({}, { __index = Container })
Tab.__index = Tab
Window.TabClass = Tab

----------------------------------------------------------------------
-- Tab
----------------------------------------------------------------------
function Tab:_visual(active, animate)
	self.Page.Visible = active
	self._indicator.Visible = active
	tween(self.TabButton, { BackgroundTransparency = active and 0 or 1 }, 0.15)
	local color = active and ThemeM.Colors.Text or ThemeM.Colors.SubText
	tween(self._label, { TextColor3 = color }, 0.15)
	if self._icon then
		tween(self._icon, { ImageColor3 = color }, 0.15)
	end
	if active and animate then
		self.Page.Position = UDim2.fromOffset(0, 14)
		tween(self.Page, { Position = UDim2.fromOffset(0, 0) }, 0.25, Enum.EasingStyle.Quart)
	end
end

function Tab:Select()
	local win = self.Window
	local changedTab = win.ActiveTab ~= self
	win.ActiveTab = self
	for _, t in ipairs(win.Tabs) do
		t:_visual(t == self, t == self and changedTab)
	end
end

function Tab:SetVisible(v)
	self.TabButton.Visible = v and true or false
end

----------------------------------------------------------------------
-- Window: общее
----------------------------------------------------------------------
function Window:_connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(self._conns, c)
	return c
end

function Window:Toggle(state, showMini)
	if state == nil then
		state = not self.Visible
	end
	if state == self.Visible then
		return
	end
	self.Visible = state
	if state then
		self._mini.Visible = false
		self._main.Visible = true
		self._uiscale.Scale = self._scale * 0.92
		tween(self._uiscale, { Scale = self._scale }, 0.25, Enum.EasingStyle.Back)
	else
		self._mini.Visible = showMini or Env.IsMobile
		tween(self._uiscale, { Scale = self._scale * 0.92 }, 0.15).Completed:Connect(function()
			if not self.Visible then
				self._main.Visible = false
			end
		end)
	end
end

-- окно масштабируется вокруг центра, поэтому не «уезжает»
function Window:SetScale(s)
	self._scale = math.clamp(tonumber(s) or 1, 0.5, 1.6)
	if self.Visible then
		self._uiscale.Scale = self._scale
	end
end

function Window:SetTheme(name)
	return ThemeM.set(name)
end

function Window:Destroy()
	for _, c in ipairs(self._conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(self._conns)
	self._alive = false
	if self._glass then
		self._glass.Destroy()
		self._glass = nil
	end
	if self._main then
		self._main:Destroy()
	end
	if self._mini then
		self._mini:Destroy()
	end
	local idx = table.find(State.Windows, self)
	if idx then
		table.remove(State.Windows, idx)
	end
	for flag, opt in pairs(State.Options) do
		if opt._container and opt._container.Window == self then
			State.Options[flag] = nil
			State.Flags[flag] = nil
		end
	end
end

-- конфиги
function Window:SaveConfig(name)
	return Config.save(self, name)
end
function Window:LoadConfig(name)
	return Config.load(self, name)
end
function Window:DeleteConfig(name)
	return Config.delete(self, name)
end
function Window:ListConfigs()
	return Config.list(self)
end
function Window:SetAutoload(name)
	return Config.setAutoload(self, name)
end
function Window:GetAutoload()
	return Config.getAutoload(self)
end
-- вызови в конце скрипта, когда все элементы уже созданы
function Window:LoadAutoConfig()
	return Config.loadAuto(self)
end

----------------------------------------------------------------------
-- Вкладки и разделители сайдбара
----------------------------------------------------------------------
function Window:TabSection(name)
	self._tabOrder += 1
	local l = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24), Text = string.upper(tostring(name)), Font = Enum.Font.GothamBold, TextSize = 10,
		LayoutOrder = self._tabOrder, Theme = { TextColor3 = "SubText" }, Parent = self._tabList,
	})
	padding(l, 6, 0, 8, 0)
	return l
end

function Window:TabDivider()
	self._tabOrder += 1
	local holder = new("Frame", {
		Size = UDim2.new(1, 0, 0, 9), BackgroundTransparency = 1, LayoutOrder = self._tabOrder, Parent = self._tabList,
	})
	new("Frame", {
		Size = UDim2.new(1, -8, 0, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Theme = { BackgroundColor3 = "Stroke" }, Parent = holder,
	})
	return holder
end

-- Window:Tab({ Name = "Main", Icon = "home", IconUrl = "Lucide" }) или Window:Tab("Main", "home")
function Window:Tab(a, b)
	local name, icon, iconUrl
	if type(a) == "table" then
		name, icon = a.Name or a.Title, a.Icon
		iconUrl = a.IconUrl or a.IconSource or a.IconSet
	else
		name, icon = a, b
	end
	name = tostring(name or "Tab")

	self._tabOrder += 1
	local page = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), Visible = false, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Theme = { ScrollBarImageColor3 = "Accent" }, Parent = self._pages,
	})
	padding(page, 10, 10, 10, 12)
	Util.list(page, 6)

	local tab = setmetatable(Container.new(self, nil, page, page), Tab)
	tab.Tab = tab
	tab.Name = name
	tab.Page = page
	table.insert(self.Tabs, tab)

	local mobile = Env.IsMobile
	tab.TabButton = new("TextButton", {
		Size = UDim2.new(1, 0, 0, mobile and 36 or 32), LayoutOrder = self._tabOrder,
		Theme = { BackgroundColor3 = "Element" }, Parent = self._tabList,
	})
	corner(tab.TabButton, 6)
	tab._indicator = new("Frame", {
		Size = UDim2.fromOffset(3, 16), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
		Visible = false, Theme = { BackgroundColor3 = "Accent" }, Parent = tab.TabButton,
	})
	corner(tab._indicator, 2)
	local labelX = 14
	local iconInst = icon and Icons.create(tab.TabButton, icon, 18, "SubText", iconUrl or self.IconUrl)
	if iconInst then
		iconInst.AnchorPoint = Vector2.new(0, 0.5)
		iconInst.Position = UDim2.new(0, 12, 0.5, 0)
		labelX = 38
		if iconInst:IsA("ImageLabel") then
			tab._icon = iconInst
		end
	end
	tab._label = new("TextLabel", {
		Size = UDim2.new(1, -(labelX + 6), 1, 0), Position = UDim2.fromOffset(labelX, 0), Text = name,
		TextColor3 = ThemeM.Colors.SubText, TextTruncate = Enum.TextTruncate.AtEnd, Parent = tab.TabButton,
	})

	tab.TabButton.MouseButton1Click:Connect(function()
		self:_clearSearch()
		tab:Select()
	end)
	tab.TabButton.MouseEnter:Connect(function()
		if self.ActiveTab ~= tab then
			tween(tab.TabButton, { BackgroundTransparency = 0.6 }, 0.1)
		end
	end)
	tab.TabButton.MouseLeave:Connect(function()
		if self.ActiveTab ~= tab then
			tween(tab.TabButton, { BackgroundTransparency = 1 }, 0.1)
		end
	end)
	ThemeM.addRefresh(tab.TabButton, function()
		tab:_visual(self.ActiveTab == tab)
	end)

	if #self.Tabs == 1 then
		tab:Select()
	else
		tab:_visual(false)
	end
	return tab
end

----------------------------------------------------------------------
-- Поиск по всем элементам
----------------------------------------------------------------------
function Window:_clearSearch()
	if self._searchBox and self._searchBox.Text ~= "" then
		self._searchBox.Text = ""
	end
	if self._results then
		self._results.Visible = false
	end
end

function Window:_runSearch(query)
	local q = Util.trim(query):lower()
	local results = self._results
	if q == "" then
		results.Visible = false
		return
	end
	results.Visible = true
	for _, item in ipairs(self._resultItems) do
		item:Destroy()
	end
	table.clear(self._resultItems)

	local count = 0
	local function add(title, sub, action)
		if count >= 40 then
			return
		end
		count += 1
		local b = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 42), LayoutOrder = count, BackgroundTransparency = 0,
			Theme = { BackgroundColor3 = "Element" }, Parent = self._resultList,
		})
		corner(b, 7)
		new("TextLabel", {
			Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(12, 5), Text = title,
			TextTruncate = Enum.TextTruncate.AtEnd, Theme = { TextColor3 = "Text" }, Parent = b,
		})
		new("TextLabel", {
			Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(12, 23), Text = sub, TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd, Theme = { TextColor3 = "SubText" }, Parent = b,
		})
		b.MouseEnter:Connect(function()
			tween(b, { BackgroundColor3 = ThemeM.Colors.ElementHover }, 0.1)
		end)
		b.MouseLeave:Connect(function()
			tween(b, { BackgroundColor3 = ThemeM.Colors.Element }, 0.1)
		end)
		b.MouseButton1Click:Connect(function()
			self:_clearSearch()
			action()
		end)
		table.insert(self._resultItems, b)
	end

	for _, tab in ipairs(self.Tabs) do
		if tab.Name:lower():find(q, 1, true) then
			add(tab.Name, "Tab", function()
				tab:Select()
			end)
		end
	end
	for _, el in ipairs(self._elements) do
		if el.Searchable ~= false and el._row and el._row.Parent and el._title then
			local title = el._title.Text
			local hay = (title .. " " .. (el._desc and el._desc.Text or "")):lower()
			if hay:find(q, 1, true) then
				local tabName = el._container.Tab and el._container.Tab.Name or "?"
				add(title, tabName .. "  /  " .. tostring(el.Type), function()
					el:Focus()
				end)
			end
		end
	end
	self._emptyLabel.Visible = count == 0
end

----------------------------------------------------------------------
-- Создание окна
----------------------------------------------------------------------
function Window.create(cfg)
	cfg.Title = tostring(cfg.Title or cfg.Name or "Majestic")
	local mobile = Env.IsMobile
	local gui = Gui.get()

	local self = setmetatable({
		Title = cfg.Title, Tabs = {}, ActiveTab = nil, Visible = true, _alive = true,
		ToggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift, Folder = cfg.Folder or "Majestic",
		IconUrl = cfg.IconUrl or cfg.IconSource or cfg.IconSet,
		_conns = {}, _elements = {}, _tabOrder = 0, _resultItems = {}, _scale = cfg.Scale or 1,
		_main = nil, _mini = nil, _uiscale = nil, _searchBox = nil, _results = nil, _resultList = nil, _emptyLabel = nil,
		_tabList = nil, _pages = nil, _glass = nil,
	}, Window)
	table.insert(State.Windows, self)

	-- пользовательские темы с диска, затем выбранная тема и настройки стекла
	if cfg.LoadThemes ~= false then
		pcall(Config.loadThemes, self)
	end
	if cfg.Theme and ThemeM.Themes[cfg.Theme] then
		ThemeM.load(cfg.Theme)
	end
	if type(cfg.Glass) == "table" then
		ThemeM.setGlass(cfg.Glass)
	end
	if typeof(cfg.Accent) == "Color3" then
		ThemeM.setColor("Accent", cfg.Accent)
	end

	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local w, h = mobile and 480 or 620, mobile and 300 or 420
	if typeof(cfg.Size) == "UDim2" then
		w, h = cfg.Size.X.Offset, cfg.Size.Y.Offset
	elseif typeof(cfg.Size) == "Vector2" then
		w, h = cfg.Size.X, cfg.Size.Y
	end
	w, h = math.min(w, vp.X - 20), math.min(h, vp.Y - 70)
	local sidebarW = cfg.SidebarWidth or (mobile and 120 or 160)

	-- окно с центром-якорем: масштаб и анимации идут от центра
	local main = new("Frame", {
		Name = "Window", Size = UDim2.fromOffset(w, h), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), ClipsDescendants = true, Theme = { BackgroundColor3 = "Background" }, Parent = gui,
	})
	corner(main, 10)
	local mainStroke = stroke(main)
	self._main = main
	self._uiscale = new("UIScale", { Scale = self._scale * 0.9, Parent = main })

	-- стекло: блик и светлая кромка (видны только в теме Liquid Glass) + размытие фона за окном
	local sheen = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9, Parent = main,
	})
	corner(sheen, 10)
	new("UIGradient", {
		Rotation = 35, Parent = sheen,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.35, 0.9), NumberSequenceKeypoint.new(1, 0.97),
		}),
	})
	ThemeM.glassDecor(sheen, "Visible")
	local rim = new("UIGradient", {
		Rotation = 45, Parent = mainStroke,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 0.2),
		}),
	})
	ThemeM.glassDecor(rim, "Enabled")
	self._glass = Glass.attach(main)

	-- верхняя панель
	local topbar = new("Frame", { Size = UDim2.new(1, 0, 0, 42), Theme = { BackgroundColor3 = "Topbar" }, Parent = main })
	new("Frame", {
		Size = UDim2.new(1, 0, 0, 1), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Theme = { BackgroundColor3 = "Stroke" }, Parent = topbar,
	})
	local titleHolder = new("Frame", {
		Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.fromOffset(14, 0),
		BackgroundTransparency = 1, Parent = topbar,
	})
	Util.list(titleHolder, 8, {
		FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	local logo = cfg.Icon and Icons.create(titleHolder, cfg.Icon, 18, "Accent", self.IconUrl)
	if not logo then
		logo = Shapes.diamond(titleHolder, 18, "Accent")
	end
	logo.LayoutOrder = 1
	new("TextLabel", {
		Size = UDim2.new(0, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.X, Text = cfg.Title, Font = Enum.Font.GothamBold,
		TextSize = 15, LayoutOrder = 2, Theme = { TextColor3 = "Text" }, Parent = titleHolder,
	})
	if cfg.Subtitle and not mobile then
		new("TextLabel", {
			Size = UDim2.new(0, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.X, Text = tostring(cfg.Subtitle),
			TextSize = 12, LayoutOrder = 3, Theme = { TextColor3 = "SubText" }, Parent = titleHolder,
		})
	end

	-- кнопки окна с нарисованными значками (никаких символов шрифта)
	local function topButton(shapeFn, xOffset, hoverKey)
		local bt = new("TextButton", {
			Size = UDim2.fromOffset(28, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xOffset, 0.5, 0),
			Parent = topbar,
		})
		corner(bt, 6)
		local glyph = shapeFn(bt, 12, "SubText")
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.5)
		bt.MouseEnter:Connect(function()
			bt.BackgroundColor3 = ThemeM.Colors[hoverKey]
			tween(bt, { BackgroundTransparency = 0.8 }, 0.1)
		end)
		bt.MouseLeave:Connect(function()
			tween(bt, { BackgroundTransparency = 1 }, 0.1)
		end)
		return bt
	end
	local closeBtn = topButton(Shapes.close, -8, "Danger")
	local minBtn = topButton(Shapes.minus, -40, "Accent")

	-- поиск по всем элементам
	if cfg.Search ~= false then
		local sw = mobile and 110 or 180
		local holder = new("Frame", {
			Size = UDim2.fromOffset(sw, 26), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -76, 0.5, 0),
			Theme = { BackgroundColor3 = "Element" }, Parent = topbar,
		})
		corner(holder, 6)
		stroke(holder)
		local lens = Shapes.search(holder, 13, "SubText")
		lens.AnchorPoint = Vector2.new(0, 0.5)
		lens.Position = UDim2.new(0, 8, 0.5, 0)
		self._searchBox = new("TextBox", {
			Size = UDim2.new(1, -34, 1, 0), Position = UDim2.fromOffset(28, 0), PlaceholderText = "Search...",
			TextSize = 12, ClipsDescendants = true,
			Theme = { TextColor3 = "Text", PlaceholderColor3 = "SubText" }, Parent = holder,
		})
		self._searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			self:_runSearch(self._searchBox.Text)
		end)
	end

	-- плашка восстановления (после сворачивания; на телефоне — всегда при скрытии)
	self._mini = new("TextButton", {
		Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10), BackgroundTransparency = 0, Visible = false,
		Theme = { BackgroundColor3 = "Accent" }, Parent = gui,
	})
	corner(self._mini, 16)
	padding(self._mini, 0, 0, 12, 14)
	Util.list(self._mini, 8, {
		FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	local miniLogo = Shapes.diamond(self._mini, 16, false)
	miniLogo.LayoutOrder = 1
	new("TextLabel", {
		Size = UDim2.new(0, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.X, Text = cfg.Title, Font = Enum.Font.GothamBold,
		TextSize = 12, TextColor3 = Color3.new(1, 1, 1), LayoutOrder = 2, Parent = self._mini,
	})
	self._mini.MouseButton1Click:Connect(function()
		self:Toggle(true)
	end)

	minBtn.MouseButton1Click:Connect(function()
		self:Toggle(false, true)
	end)
	closeBtn.MouseButton1Click:Connect(function()
		self:Dialog({
			Title = "Close " .. cfg.Title .. "?", Content = "The menu will be unloaded.",
			Buttons = {
				{ "Close", function()
					self:Destroy()
				end },
				{ "Cancel" },
			},
		})
	end)

	-- боковая панель
	local sidebar = new("Frame", {
		Size = UDim2.new(0, sidebarW, 1, -42), Position = UDim2.fromOffset(0, 42),
		Theme = { BackgroundColor3 = "Sidebar" }, Parent = main,
	})
	new("Frame", {
		Size = UDim2.new(0, 1, 1, 0), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
		Theme = { BackgroundColor3 = "Stroke" }, Parent = sidebar,
	})
	self._tabList = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -36), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0, Parent = sidebar,
	})
	padding(self._tabList, 8, 8, 8, 9)
	Util.list(self._tabList, 4)
	local lp = Env.LocalPlayer
	new("TextLabel", {
		Size = UDim2.new(1, -20, 0, 36), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, 0),
		Text = lp and lp.DisplayName or "Player", TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "SubText" }, Parent = sidebar,
	})

	-- страницы и панель результатов поиска
	self._pages = new("Frame", {
		Size = UDim2.new(1, -sidebarW, 1, -42), Position = UDim2.fromOffset(sidebarW, 42), BackgroundTransparency = 1,
		ClipsDescendants = true, Parent = main,
	})
	self._results = new("Frame", {
		Size = UDim2.new(1, -sidebarW, 1, -42), Position = UDim2.fromOffset(sidebarW, 42), Visible = false, ZIndex = 30,
		Theme = { BackgroundColor3 = "Background" }, Parent = main,
	})
	self._resultList = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 31, Theme = { ScrollBarImageColor3 = "Accent" }, Parent = self._results,
	})
	padding(self._resultList, 10, 10, 10, 12)
	Util.list(self._resultList, 6)
	self._emptyLabel = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 20), Text = "No results", Visible = false,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 32, Theme = { TextColor3 = "SubText" }, Parent = self._results,
	})

	-- перетаскивание и изменение размера
	Util.makeDraggable(topbar, main, function(sig, fn)
		return self:_connect(sig, fn)
	end)
	local grip = new("TextButton", {
		Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1),
		ZIndex = 40, Parent = main,
	})
	new("Frame", {
		Size = UDim2.fromOffset(10, 2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(13, 13),
		Rotation = -45, BackgroundTransparency = 0.4, Theme = { BackgroundColor3 = "SubText" }, Parent = grip,
	})
	local minW, minH = cfg.MinWidth or 440, cfg.MinHeight or 300
	local resizing = false
	local startMouse, startW, startH, startPos = Vector3.new(), 0, 0, main.Position
	grip.InputBegan:Connect(function(i)
		if isPress(i) then
			resizing = true
			startMouse, startW, startH, startPos = i.Position, main.Size.X.Offset, main.Size.Y.Offset, main.Position
			local conn
			conn = i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					resizing = false
					conn:Disconnect()
				end
			end)
		end
	end)
	self:_connect(UIS.InputChanged, function(i)
		if resizing and isMove(i) then
			local d = i.Position - startMouse
			local s = self._scale
			local nw, nh = math.max(minW, startW + d.X / s), math.max(minH, startH + d.Y / s)
			main.Size = UDim2.fromOffset(nw, nh)
			-- центр-якорь: сдвигаем центр, чтобы левый верхний угол стоял на месте
			main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + (nw - startW) * s / 2,
				startPos.Y.Scale, startPos.Y.Offset + (nh - startH) * s / 2
			)
		end
	end)

	-- клавиша показать / скрыть
	self:_connect(UIS.InputBegan, function(i, gp)
		if gp or not self.ToggleKey then
			return
		end
		if i.KeyCode == self.ToggleKey then
			self:Toggle()
		end
		if i.KeyCode == Enum.KeyCode.Escape and self._searchBox and self._searchBox.Text ~= "" then
			self:_clearSearch()
		end
	end)

	-- появление окна
	tween(self._uiscale, { Scale = self._scale }, 0.3, Enum.EasingStyle.Back)
	return self
end

return Window
end

__defs["Elements/Basic"] = function()
-- Базовые элементы: Section, Divider, Label, Paragraph, Image, Button, Toggle
local Util = import("Core/Util")
local ThemeM = import("Core/Theme")
local E = import("Core/Element")
local Container = import("Core/Container")

local new, tween, corner, stroke, padding = Util.new, Util.tween, Util.corner, Util.stroke, Util.padding
local parse, fire = Util.parse, Util.fire
local buildRow, newElement, register, changed, overlay = E.buildRow, E.newElement, E.register, E.changed, E.overlay
local Element = E.Element

-- элемент без карточки (Section, Divider, Image)
local function bareElement(container, row, title)
	return setmetatable({
		_container = container, _row = row, _title = title, _conns = {}, _listeners = {}, Searchable = false,
	}, Element)
end

-- Section: заголовок группы
function Container:Section(a)
	local cfg = parse(a, {})
	local l = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24), Text = string.upper(cfg.Name), Font = Enum.Font.GothamBold,
		TextSize = 11, LayoutOrder = self:_nextOrder(), Theme = { TextColor3 = "Accent" }, Parent = self.Holder,
	})
	padding(l, 0, 0, 2, 0)
	local el = bareElement(self, l, l)
	function el:Get()
		return l.Text
	end
	return register(el, cfg, "Section")
end

-- Divider: разделитель
function Container:Divider()
	local holder = new("Frame", {
		Size = UDim2.new(1, 0, 0, 8), BackgroundTransparency = 1, LayoutOrder = self:_nextOrder(), Parent = self.Holder,
	})
	new("Frame", {
		Size = UDim2.new(1, 0, 0, 1), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5),
		Theme = { BackgroundColor3 = "Stroke" }, Parent = holder,
	})
	local el = bareElement(self, holder, nil)
	function el:Get() end
	return register(el, {}, "Divider")
end

local labelColors = { Info = "Accent", Success = "Success", Warning = "Warning", Error = "Danger" }

-- Label: текст с переносом + описание; Type = Info / Success / Warning / Error
function Container:Label(a, b)
	local cfg = parse(a, { "Desc" }, b)
	local p = buildRow(self, cfg, 0)
	p.header.AutomaticSize = Enum.AutomaticSize.Y
	p.title.Size = UDim2.new(1, -(p.icon and 24 or 0), 0, 22)
	p.title.AutomaticSize = Enum.AutomaticSize.Y
	p.title.TextWrapped = true
	local colorKey = cfg.Type and labelColors[cfg.Type]
	if colorKey then
		new("Frame", { Size = UDim2.new(0, 3, 1, 0), ZIndex = 3, Theme = { BackgroundColor3 = colorKey }, Parent = p.row })
	end
	local el = newElement(self, p, cfg)
	function el:Set(t)
		p.title.Text = tostring(t)
	end
	function el:Get()
		return p.title.Text
	end
	return register(el, cfg, "Label")
end

-- Paragraph: жирный заголовок + длинный текст
function Container:Paragraph(a, b)
	local cfg = parse(a, { "Content" }, b)
	cfg.Desc = cfg.Desc or cfg.Content
	local el = self:Label(cfg)
	el._title.Font = Enum.Font.GothamBold
	return el
end

-- Image: картинка (rbxassetid или ссылка)
function Container:Image(a, b)
	local cfg = parse(a, { "Image", "Height" }, b)
	local holder = new("Frame", {
		Size = UDim2.new(1, 0, 0, cfg.Height or 120), ClipsDescendants = true,
		LayoutOrder = self:_nextOrder(), Theme = { BackgroundColor3 = "Element" }, Parent = self.Holder,
	})
	corner(holder, 7)
	stroke(holder)
	local img = new("ImageLabel", {
		Size = UDim2.fromScale(1, 1), Image = tostring(cfg.Image or ""),
		ScaleType = cfg.Fit and Enum.ScaleType.Fit or Enum.ScaleType.Crop, Parent = holder,
	})
	local el = bareElement(self, holder, nil)
	function el:Set(image)
		img.Image = tostring(image)
	end
	function el:Get()
		return img.Image
	end
	return register(el, cfg, "Image")
end

-- Button: справа иконка клика (ButtonIcon меняет иконку, ButtonText заменяет иконку текстом)
function Container:Button(a, b)
	local cfg = parse(a, { "Callback" }, b)
	local p = buildRow(self, cfg, 44)
	local el = newElement(self, p, cfg)
	local pill = E.actionPill(self, p.header, cfg, "click")
	overlay(p.row, function()
		tween(pill, { BackgroundTransparency = 0.5 }, 0.08).Completed:Connect(function()
			tween(pill, { BackgroundTransparency = 0 }, 0.12)
		end)
		fire(el._callback)
	end)
	function el:Fire()
		fire(self._callback)
	end
	function el:SetText(t)
		for _, c in ipairs(pill:GetChildren()) do
			if c:IsA("TextLabel") then
				c.Text = tostring(t)
			end
		end
	end
	function el:Get() end
	return register(el, cfg, "Button")
end

-- Toggle (чекбокс)
function Container:Toggle(a, b, c)
	local cfg = parse(a, { "Default", "Callback" }, b, c)
	local p = buildRow(self, cfg, 50)
	local el = newElement(self, p, cfg)
	local value = cfg.Default == true

	local track = new("Frame", {
		Size = UDim2.fromOffset(38, 20), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Parent = p.header,
	})
	corner(track, 10)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1), Parent = track,
	})
	corner(knob, 7)

	local function render(instant)
		local trackColor = value and ThemeM.Colors.Accent or ThemeM.Colors.Stroke
		local knobPos = value and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		if instant then
			track.BackgroundColor3 = trackColor
			knob.Position = knobPos
		else
			tween(track, { BackgroundColor3 = trackColor }, 0.15)
			tween(knob, { Position = knobPos }, 0.18, Enum.EasingStyle.Back)
		end
	end
	render(true)
	ThemeM.addRefresh(track, function()
		render(true)
	end)

	overlay(p.row, function()
		el:Set(not value)
	end)

	function el:Set(v, silent)
		v = v and true or false
		local diff = v ~= value
		value = v
		render()
		changed(self, silent or not diff, value)
	end
	function el:Get()
		return value
	end
	function el:Toggle()
		self:Set(not value)
	end
	return register(el, cfg, "Toggle")
end
Container.Checkbox = Container.Toggle

return true
end

__defs["Elements/Slider"] = function()
-- Slider, RangeSlider, Progress
local Env = import("Core/Env")
local Util = import("Core/Util")
local E = import("Core/Element")
local Container = import("Core/Container")

local new, tween, corner = Util.new, Util.tween, Util.corner
local parse, snap = Util.parse, Util.snap
local buildRow, newElement, register, changed = E.buildRow, E.newElement, E.register, E.changed

local function sliderParts(p, areaHeight)
	local area = new("TextButton", { Size = UDim2.new(1, 0, 0, areaHeight), LayoutOrder = 3, Parent = p.content })
	local track = new("Frame", {
		Size = UDim2.new(1, 0, 0, 6), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
		Theme = { BackgroundColor3 = "Stroke" }, Parent = area,
	})
	corner(track, 3)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), Theme = { BackgroundColor3 = "Accent" }, Parent = track })
	corner(fill, 3)
	return area, track, fill
end

local function makeKnob(track)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = track,
	})
	corner(knob, 6)
	return knob
end

local function valueBox(p, width)
	return new("TextBox", {
		Size = UDim2.fromOffset(width, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Right, TextSize = 12, Theme = { TextColor3 = "SubText" }, Parent = p.header,
	})
end

-- Slider: Min / Max / Default / Increment / Suffix
function Container:Slider(a, b, c, d, e)
	local cfg = parse(a, { "Min", "Max", "Default", "Callback" }, b, c, d, e)
	local p = buildRow(self, cfg, 80)
	local el = newElement(self, p, cfg)
	local min, max = cfg.Min or 0, cfg.Max or 100
	local inc = cfg.Increment or cfg.Step or 1
	local suffix = cfg.Suffix or ""
	local value = min

	local box = valueBox(p, 76)
	local area, track, fill = sliderParts(p, Env.IsMobile and 24 or 16)
	local knob = makeKnob(track)

	local function render()
		local alpha = (max == min) and 0 or (value - min) / (max - min)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		box.Text = tostring(value) .. suffix
	end

	function el:Set(v, silent)
		v = tonumber(v)
		if not v then
			return
		end
		local nv = snap(v, min, max, inc)
		local diff = nv ~= value
		value = nv
		render()
		changed(self, silent or not diff, value)
	end
	function el:Get()
		return value
	end
	function el:SetRange(newMin, newMax)
		min, max = newMin, newMax
		el:Set(value, true)
	end

	-- Commit = true: callback вызывается один раз при отпускании ползунка (удобно для тяжёлых действий, например масштаба UI)
	local pending = false
	E.dragArea(self, el, area, function(x)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local v = min + alpha * (max - min)
		if cfg.Commit then
			local before = value
			el:Set(v, true)
			if value ~= before then
				pending = true
			end
		else
			el:Set(v)
		end
	end, function()
		if pending then
			pending = false
			changed(el, false, value)
		end
	end)
	box.FocusLost:Connect(function()
		local n = tonumber(box.Text:match("-?%d+%.?%d*"))
		if n then
			el:Set(n)
		else
			render()
		end
	end)

	el:Set(cfg.Default or min, true)
	return register(el, cfg, "Slider")
end

-- RangeSlider: диапазон из двух значений. Default = { от, до }, Get() -> { от, до }
function Container:RangeSlider(a, b, c, d, e)
	local cfg = parse(a, { "Min", "Max", "Default", "Callback" }, b, c, d, e)
	local p = buildRow(self, cfg, 110)
	local el = newElement(self, p, cfg)
	local min, max = cfg.Min or 0, cfg.Max or 100
	local inc = cfg.Increment or cfg.Step or 1
	local suffix = cfg.Suffix or ""
	local lo, hi = min, max

	local box = new("TextLabel", {
		Size = UDim2.fromOffset(106, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Right, TextSize = 12, Theme = { TextColor3 = "SubText" }, Parent = p.header,
	})
	local area, track, fill = sliderParts(p, Env.IsMobile and 24 or 16)
	local knobLo, knobHi = makeKnob(track), makeKnob(track)

	local function render()
		local span = (max == min) and 1 or (max - min)
		local aLo, aHi = (lo - min) / span, (hi - min) / span
		fill.Position = UDim2.fromScale(aLo, 0)
		fill.Size = UDim2.fromScale(aHi - aLo, 1)
		knobLo.Position = UDim2.fromScale(aLo, 0.5)
		knobHi.Position = UDim2.fromScale(aHi, 0.5)
		box.Text = tostring(lo) .. suffix .. "  -  " .. tostring(hi) .. suffix
	end

	function el:Set(v, silent)
		if type(v) ~= "table" then
			return
		end
		local nl = snap(tonumber(v[1]) or min, min, max, inc)
		local nh = snap(tonumber(v[2]) or max, min, max, inc)
		if nl > nh then
			nl, nh = nh, nl
		end
		local diff = nl ~= lo or nh ~= hi
		lo, hi = nl, nh
		render()
		changed(self, silent or not diff, lo, hi)
	end
	function el:Get()
		return { lo, hi }
	end

	-- свой drag: при нажатии выбираем ближайший ползунок
	local active -- "lo" | "hi"
	local scroller = self.Scroller
	local function move(x)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local v = min + alpha * (max - min)
		if not active then
			active = math.abs(v - lo) <= math.abs(v - hi) and "lo" or "hi"
			if lo == hi then
				active = v < lo and "lo" or "hi"
			end
		end
		if active == "lo" then
			el:Set({ math.min(v, hi), hi })
		else
			el:Set({ lo, math.max(v, lo) })
		end
	end
	area.InputBegan:Connect(function(i)
		if Util.isPress(i) then
			active = nil
			if scroller then
				scroller.ScrollingEnabled = false
			end
			move(i.Position.X)
			local conn
			conn = i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					active = "done"
					if scroller then
						scroller.ScrollingEnabled = true
					end
					conn:Disconnect()
				end
			end)
		end
	end)
	E.connect(self, el, Env.UserInputService.InputChanged, function(i)
		if active and active ~= "done" and Util.isMove(i) then
			move(i.Position.X)
		end
	end)

	local def = cfg.Default
	if type(def) ~= "table" then
		def = { min, max }
	end
	el:Set(def, true)
	return register(el, cfg, "RangeSlider")
end

-- Progress: полоса прогресса 0-100, управляется из кода
function Container:Progress(a, b)
	local cfg = parse(a, { "Default" }, b)
	local p = buildRow(self, cfg, 64)
	local el = newElement(self, p, cfg)
	local value = 0
	local pct = new("TextLabel", {
		Size = UDim2.fromOffset(56, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Right, TextSize = 12, Theme = { TextColor3 = "SubText" }, Parent = p.header,
	})
	local bar = new("Frame", {
		Size = UDim2.new(1, 0, 0, 6), LayoutOrder = 3, Theme = { BackgroundColor3 = "Stroke" }, Parent = p.content,
	})
	corner(bar, 3)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), Theme = { BackgroundColor3 = "Accent" }, Parent = bar })
	corner(fill, 3)

	function el:Set(x, silent)
		value = math.clamp(tonumber(x) or 0, 0, 100)
		tween(fill, { Size = UDim2.fromScale(value / 100, 1) }, 0.2)
		pct.Text = math.floor(value + 0.5) .. "%"
		changed(self, silent, value)
	end
	function el:Get()
		return value
	end
	el:Set(cfg.Default or 0, true)
	return register(el, cfg, "Progress")
end

return true
end

__defs["Elements/Dropdown"] = function()
-- Dropdown: одиночный выбор и Multi. Клик по тексту = ввод для поиска, Enter выбирает первый подходящий пункт.
local Env = import("Core/Env")
local Util = import("Core/Util")
local ThemeM = import("Core/Theme")
local Shapes = import("Core/Shapes")
local E = import("Core/Element")
local Container = import("Core/Container")

local new, tween, corner, stroke = Util.new, Util.tween, Util.corner, Util.stroke
local parse = Util.parse
local buildRow, newElement, register, changed = E.buildRow, E.newElement, E.register, E.changed

local ITEM_H = 28
local MAX_H = 150

local function inside(inst, pos)
	local p, s = inst.AbsolutePosition, inst.AbsoluteSize
	return pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
end

function Container:Dropdown(a, b, c, d)
	local cfg = parse(a, { "Options", "Default", "Callback" }, b, c, d)
	local p = buildRow(self, cfg, 175)
	local el = newElement(self, p, cfg)
	local multi = cfg.Multi == true
	local hint = cfg.Placeholder or "Select..."

	local options = {}
	for _, o in ipairs(cfg.Options or {}) do
		table.insert(options, tostring(o))
	end
	local selected, single = {}, nil
	local items = {}
	local open = false
	local typing, filter = false, ""

	-- поле: текст выбранного значения; по клику превращается в строку поиска
	local field = new("Frame", {
		Size = UDim2.fromOffset(165, 24), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Theme = { BackgroundColor3 = "Background" }, Parent = p.header,
	})
	corner(field, 5)
	local fieldStroke = stroke(field)
	local box = new("TextBox", {
		Size = UDim2.new(1, -28, 1, 0), Position = UDim2.fromOffset(8, 0), TextSize = 12, PlaceholderText = hint,
		TextTruncate = Enum.TextTruncate.AtEnd, ClipsDescendants = true,
		Theme = { TextColor3 = "Text", PlaceholderColor3 = "SubText" }, Parent = field,
	})
	local arrowBtn = new("TextButton", {
		Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Parent = field,
	})
	local arrow = Shapes.chevron(arrowBtn, 10, "SubText")
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.5)

	local body = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, Visible = false, LayoutOrder = 3,
		ClipsDescendants = true, Parent = p.content,
	})
	local list = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Theme = { ScrollBarImageColor3 = "Accent" }, Parent = body,
	})
	Util.list(list, 2)

	local function isSelected(name)
		if multi then
			return selected[name] == true
		end
		return single == name
	end

	local function displayText()
		if multi then
			local names = {}
			for _, o in ipairs(options) do
				if selected[o] then
					table.insert(names, o)
				end
			end
			return table.concat(names, ", ")
		end
		return single or ""
	end

	local function paint()
		for _, item in ipairs(items) do
			local on = isSelected(item.name)
			item.check.Visible = on
			item.label.TextColor3 = on and ThemeM.Colors.Accent or ThemeM.Colors.Text
		end
		if not typing then
			box.Text = displayText()
		end
	end
	ThemeM.addRefresh(field, paint)

	-- пересчитывает видимые пункты и плавно подгоняет высоту списка
	local function layout(animate)
		local count = 0
		for _, item in ipairs(items) do
			local show = filter == "" or item.name:lower():find(filter, 1, true) ~= nil
			item.button.Visible = show
			if show then
				count += 1
			end
		end
		if not open then
			return
		end
		local h = math.min(math.max(count, 1) * ITEM_H, MAX_H)
		tween(body, { Size = UDim2.new(1, 0, 0, h) }, animate and 0.2 or 0.1, Enum.EasingStyle.Quart)
	end

	local function setOpen(v)
		if v == open then
			if v then
				layout()
			end
			return
		end
		open = v
		tween(arrow, { Rotation = v and 180 or 0 }, 0.18)
		tween(fieldStroke, { Color = v and ThemeM.Colors.Accent or ThemeM.Colors.Stroke }, 0.15)
		if v then
			body.Size = UDim2.new(1, 0, 0, 0)
			body.Visible = true
			layout(true)
		else
			filter = ""
			layout()
			tween(body, { Size = UDim2.new(1, 0, 0, 0) }, 0.16, Enum.EasingStyle.Quart).Completed:Connect(function()
				if not open then
					body.Visible = false
				end
			end)
		end
	end

	local function choose(name)
		if multi then
			local nl = {}
			for _, o in ipairs(options) do
				local on = selected[o]
				if o == name then
					on = not on
				end
				if on then
					table.insert(nl, o)
				end
			end
			el:Set(nl)
		else
			el:Set(name)
			setOpen(false)
		end
	end

	local function rebuild()
		for _, item in ipairs(items) do
			item.button:Destroy()
		end
		table.clear(items)
		for i, name in ipairs(options) do
			local ib = new("TextButton", {
				Size = UDim2.new(1, -6, 0, ITEM_H - 2), LayoutOrder = i, BackgroundTransparency = 1,
				Theme = { BackgroundColor3 = "ElementHover" }, Parent = list,
			})
			corner(ib, 5)
			-- текст пункта по центру
			local lbl = new("TextLabel", {
				Size = UDim2.new(1, -36, 1, 0), Position = UDim2.fromOffset(18, 0), Text = name, TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = ThemeM.Colors.Text, Parent = ib,
			})
			local chk = Shapes.check(ib, 12, "Accent")
			chk.AnchorPoint = Vector2.new(1, 0.5)
			chk.Position = UDim2.new(1, -8, 0.5, 0)
			chk.Visible = false
			ib.MouseEnter:Connect(function()
				tween(ib, { BackgroundTransparency = 0 }, 0.1)
			end)
			ib.MouseLeave:Connect(function()
				tween(ib, { BackgroundTransparency = 1 }, 0.1)
			end)
			ib.MouseButton1Click:Connect(function()
				choose(name)
			end)
			table.insert(items, { name = name, button = ib, label = lbl, check = chk })
		end
		paint()
		layout()
	end

	function el:Set(v, silent)
		if multi then
			selected = {}
			if type(v) == "table" then
				for _, o in ipairs(v) do
					selected[tostring(o)] = true
				end
			elseif v ~= nil then
				selected[tostring(v)] = true
			end
		else
			v = v ~= nil and tostring(v) or nil
			if v ~= nil and not table.find(options, v) then
				v = nil
			end
			single = v
		end
		paint()
		changed(self, silent, self:Get())
	end
	function el:Get()
		if multi then
			local r = {}
			for _, o in ipairs(options) do
				if selected[o] then
					table.insert(r, o)
				end
			end
			return r
		end
		return single
	end
	function el:Refresh(newOptions)
		options = {}
		for _, o in ipairs(newOptions or {}) do
			table.insert(options, tostring(o))
		end
		if multi then
			for k in pairs(selected) do
				if not table.find(options, k) then
					selected[k] = nil
				end
			end
		elseif single and not table.find(options, single) then
			single = nil
		end
		rebuild()
		changed(self, true)
	end
	function el:GetOptions()
		return table.clone(options)
	end

	-- клик по тексту: ввод для поиска
	box.Focused:Connect(function()
		typing, filter = true, ""
		box.Text = ""
		box.PlaceholderText = "Type to search..."
		setOpen(true)
		layout()
	end)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if typing then
			filter = box.Text:lower()
			layout()
		end
	end)
	box.FocusLost:Connect(function(enter)
		typing = false
		box.PlaceholderText = hint
		if enter then
			-- Enter выбирает первый подходящий пункт
			for _, item in ipairs(items) do
				if filter == "" or item.name:lower():find(filter, 1, true) then
					if filter ~= "" then
						choose(item.name)
					end
					break
				end
			end
			if not multi then
				filter = ""
			end
		end
		paint() -- вернуть текст выбранного значения (фильтр сбросится при закрытии списка)
	end)
	arrowBtn.MouseButton1Click:Connect(function()
		setOpen(not open)
	end)

	-- клик вне поля и списка закрывает список
	E.connect(self, el, Env.UserInputService.InputBegan, function(i)
		if open and Util.isPress(i) and not typing then
			if not inside(field, i.Position) and not inside(body, i.Position) then
				setOpen(false)
			end
		end
	end)

	rebuild()
	el:Set(cfg.Default, true)
	return register(el, cfg, "Dropdown")
end

return true
end

__defs["Elements/Input"] = function()
-- Input (в т.ч. многострочный) и Keybind
local Env = import("Core/Env")
local Util = import("Core/Util")
local ThemeM = import("Core/Theme")
local E = import("Core/Element")
local Container = import("Core/Container")

local new, tween, corner, stroke, padding = Util.new, Util.tween, Util.corner, Util.stroke, Util.padding
local parse, fire = Util.parse, Util.fire
local buildRow, newElement, register, changed = E.buildRow, E.newElement, E.register, E.changed

-- Input: Placeholder, Numeric, Live (callback на каждый символ), Multiline + Height
function Container:Input(a, b, c)
	local cfg = parse(a, { "Default", "Callback" }, b, c)
	local multiline = cfg.Multiline == true
	local p = buildRow(self, cfg, multiline and 0 or 170)
	local el = newElement(self, p, cfg)

	local props = {
		Text = tostring(cfg.Default or ""), PlaceholderText = cfg.Placeholder or "Type here...", TextSize = 12,
		BackgroundTransparency = 0, ClipsDescendants = true,
		Theme = { BackgroundColor3 = "Background", TextColor3 = "Text", PlaceholderColor3 = "SubText" },
	}
	if multiline then
		props.Size = UDim2.new(1, 0, 0, cfg.Height or 72)
		props.LayoutOrder = 3
		props.MultiLine = true
		props.TextWrapped = true
		props.TextYAlignment = Enum.TextYAlignment.Top
		props.Parent = p.content
	else
		props.Size = UDim2.fromOffset(160, 24)
		props.AnchorPoint = Vector2.new(1, 0.5)
		props.Position = UDim2.new(1, 0, 0.5, 0)
		props.Parent = p.header
	end
	local box = new("TextBox", props)
	corner(box, 5)
	local s = stroke(box)
	padding(box, multiline and 6 or 0, multiline and 6 or 0, 8, 8)
	local value = box.Text

	local function clean()
		if cfg.Numeric then
			local cleaned = box.Text:gsub("[^%d%.%-]", "")
			if cleaned ~= box.Text then
				box.Text = cleaned
			end
		end
	end

	box.Focused:Connect(function()
		tween(s, { Color = ThemeM.Colors.Accent }, 0.12)
	end)
	box.FocusLost:Connect(function()
		tween(s, { Color = ThemeM.Colors.Stroke }, 0.12)
		clean()
		value = box.Text
		changed(el, false, el:Get())
	end)
	if cfg.Live then
		box:GetPropertyChangedSignal("Text"):Connect(function()
			clean()
			value = box.Text
			changed(el, false, el:Get())
		end)
	end

	function el:Set(v, silent)
		box.Text = tostring(v or "")
		value = box.Text
		changed(self, silent, self:Get())
	end
	function el:Get()
		if cfg.Numeric then
			return tonumber(value) or 0
		end
		return value
	end
	function el:Focus()
		box:CaptureFocus()
	end
	return register(el, cfg, "Input")
end
Container.TextBox = Container.Input

-- Keybind: Mode = "Press" | "Toggle" | "Hold"; Callback — на нажатие, OnChange — на смену бинда
function Container:Keybind(a, b, c)
	local cfg = parse(a, { "Default", "Callback" }, b, c)
	local p = buildRow(self, cfg, 120)
	local el = newElement(self, p, cfg)
	local pressCb = cfg.Callback
	el._callback = cfg.OnChange
	local mode = cfg.Mode or "Press"
	local key, state, listening = nil, false, false

	local btn = new("TextButton", {
		Size = UDim2.fromOffset(110, 24), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		BackgroundTransparency = 0, TextSize = 12,
		Theme = { BackgroundColor3 = "Background", TextColor3 = "SubText" }, Parent = p.header,
	})
	corner(btn, 5)
	stroke(btn)

	function el:Set(v, silent)
		if type(v) == "string" then
			local ok, k = pcall(function()
				return Enum.KeyCode[v]
			end)
			v = ok and k or nil
		end
		key = v
		btn.Text = key and key.Name or "None"
		changed(self, silent, key)
	end
	function el:Get()
		return key
	end

	btn.MouseButton1Click:Connect(function()
		listening = true
		btn.Text = "..."
	end)

	E.connect(self, el, Env.UserInputService.InputBegan, function(i, gp)
		if listening then
			if i.UserInputType == Enum.UserInputType.Keyboard then
				listening = false
				if i.KeyCode == Enum.KeyCode.Escape or i.KeyCode == Enum.KeyCode.Backspace then
					el:Set(nil)
				else
					el:Set(i.KeyCode)
				end
			end
			return
		end
		if gp or not key or i.KeyCode ~= key then
			return
		end
		if mode == "Toggle" then
			state = not state
			fire(pressCb, state)
		elseif mode == "Hold" then
			fire(pressCb, true)
		else
			fire(pressCb)
		end
	end)
	E.connect(self, el, Env.UserInputService.InputEnded, function(i)
		if mode == "Hold" and key and i.KeyCode == key then
			fire(pressCb, false)
		end
	end)

	el:Set(cfg.Default, true)
	return register(el, cfg, "Keybind")
end
Container.Bind = Container.Keybind

return true
end

__defs["Elements/ColorPicker"] = function()
-- ColorPicker: компактная панель (SV-квадрат, оттенок, альфа, HEX, Rainbow), раскрывается плавно
local Env = import("Core/Env")
local Util = import("Core/Util")
local ThemeM = import("Core/Theme")
local E = import("Core/Element")
local Container = import("Core/Container")

local new, tween, corner, stroke, padding = Util.new, Util.tween, Util.corner, Util.stroke, Util.padding
local parse, C = Util.parse, Util.C
local buildRow, newElement, register, changed = E.buildRow, E.newElement, E.register, E.changed

local SV_W, SV_H, BAR_W, GAP = 150, 100, 14, 8

function Container:ColorPicker(a, b, c)
	local cfg = parse(a, { "Default", "Callback" }, b, c)
	local p = buildRow(self, cfg, 50)
	local el = newElement(self, p, cfg)
	local color = typeof(cfg.Default) == "Color3" and cfg.Default or C(255, 255, 255)
	local h, s, v = color:ToHSV()
	local alpha = math.clamp(tonumber(cfg.DefaultAlpha) or 1, 0, 1)
	local hasAlpha = cfg.Alpha == true
	local open = false
	local rainbowConn

	local preview = new("TextButton", {
		Size = UDim2.fromOffset(38, 20), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		BackgroundTransparency = 0, BackgroundColor3 = color, Parent = p.header,
	})
	corner(preview, 5)
	stroke(preview)

	-- панель фиксированного размера справа; body плавно меняет высоту
	local panelW = SV_W + GAP + BAR_W + (hasAlpha and (GAP + BAR_W) or 0)
	local panelH = SV_H + GAP + 24
	local body = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, Visible = false, LayoutOrder = 3,
		ClipsDescendants = true, Parent = p.content,
	})
	local panel = new("Frame", {
		Size = UDim2.fromOffset(panelW, panelH), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1, Parent = body,
	})

	-- квадрат насыщенность/яркость
	local sv = new("Frame", {
		Size = UDim2.fromOffset(SV_W, SV_H), BackgroundColor3 = Color3.fromHSV(h, 1, 1), Active = true, Parent = panel,
	})
	corner(sv, 5)
	local white = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(255, 255, 255), Parent = sv })
	corner(white, 5)
	new("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Parent = white,
	})
	local black = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(0, 0, 0), Parent = sv })
	corner(black, 5)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
		Parent = black,
	})
	local svCursor = new("Frame", {
		Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = sv,
	})
	corner(svCursor, 5)
	new("UIStroke", { Color = C(255, 255, 255), Thickness = 2, Parent = svCursor })

	-- вертикальная полоса оттенка
	local hue = new("Frame", {
		Size = UDim2.fromOffset(BAR_W, SV_H), Position = UDim2.fromOffset(SV_W + GAP, 0),
		BackgroundColor3 = C(255, 255, 255), Active = true, Parent = panel,
	})
	corner(hue, 5)
	local keys = {}
	for i = 0, 6 do
		table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(math.min(i / 6, 0.9999), 1, 1)))
	end
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(keys), Parent = hue })
	local hueCursor = new("Frame", {
		Size = UDim2.new(1, 4, 0, 4), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C(255, 255, 255), Parent = hue,
	})
	corner(hueCursor, 2)
	new("UIStroke", { Color = C(0, 0, 0), Thickness = 1, Parent = hueCursor })

	-- вертикальная полоса прозрачности (сверху непрозрачно)
	local alphaBar, alphaTint, alphaCursor
	if hasAlpha then
		alphaBar = new("Frame", {
			Size = UDim2.fromOffset(BAR_W, SV_H), Position = UDim2.fromOffset(SV_W + GAP + BAR_W + GAP, 0), Active = true,
			Theme = { BackgroundColor3 = "Stroke" }, Parent = panel,
		})
		corner(alphaBar, 5)
		alphaTint = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, Parent = alphaBar })
		corner(alphaTint, 5)
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
			Parent = alphaTint,
		})
		alphaCursor = new("Frame", {
			Size = UDim2.new(1, 4, 0, 4), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0),
			BackgroundColor3 = C(255, 255, 255), Parent = alphaBar,
		})
		corner(alphaCursor, 2)
		new("UIStroke", { Color = C(0, 0, 0), Thickness = 1, Parent = alphaCursor })
	end

	-- HEX и Rainbow под палитрой
	local rowY = SV_H + GAP
	local hexW = cfg.Rainbow and (panelW - 72 - 6) or panelW
	local hex = new("TextBox", {
		Size = UDim2.fromOffset(hexW, 24), Position = UDim2.fromOffset(0, rowY), TextSize = 12, BackgroundTransparency = 0,
		ClipsDescendants = true, Theme = { BackgroundColor3 = "Background", TextColor3 = "Text" }, Parent = panel,
	})
	corner(hex, 5)
	padding(hex, 0, 0, 8, 8)
	local rainbowBtn
	if cfg.Rainbow then
		rainbowBtn = new("TextButton", {
			Size = UDim2.fromOffset(72, 24), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, rowY),
			BackgroundTransparency = 0, Text = "Rainbow", TextSize = 12,
			Theme = { BackgroundColor3 = "Background", TextColor3 = "SubText" }, Parent = panel,
		})
		corner(rainbowBtn, 5)
	end

	local function update(silent)
		color = Color3.fromHSV(h, s, v)
		preview.BackgroundColor3 = color
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.fromScale(s, 1 - v)
		hueCursor.Position = UDim2.fromScale(0.5, h)
		if hasAlpha then
			alphaTint.BackgroundColor3 = color
			alphaCursor.Position = UDim2.fromScale(0.5, 1 - alpha)
			preview.BackgroundTransparency = 1 - alpha
		end
		hex.Text = "#" .. color:ToHex():upper()
		changed(el, silent, color, alpha)
	end

	function el:Set(newColor, silent)
		if typeof(newColor) ~= "Color3" then
			return
		end
		h, s, v = newColor:ToHSV()
		update(silent)
	end
	function el:Get()
		return color
	end
	function el:SetAlpha(a, silent)
		alpha = math.clamp(tonumber(a) or 1, 0, 1)
		update(silent)
	end
	function el:GetAlpha()
		return alpha
	end
	function el:SetRainbow(on)
		if rainbowConn then
			rainbowConn:Disconnect()
			rainbowConn = nil
		end
		if on then
			rainbowConn = Env.RunService.RenderStepped:Connect(function()
				h = (os.clock() * 0.25) % 1
				update()
			end)
			table.insert(el._conns, rainbowConn)
		end
		if rainbowBtn then
			rainbowBtn.TextColor3 = on and ThemeM.Colors.Accent or ThemeM.Colors.SubText
		end
		el._rainbow = on and true or false
	end

	E.dragArea(self, el, sv, function(x, y)
		s = math.clamp((x - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
		v = 1 - math.clamp((y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
		update()
	end)
	E.dragArea(self, el, hue, function(_, y)
		h = math.clamp((y - hue.AbsolutePosition.Y) / math.max(hue.AbsoluteSize.Y, 1), 0, 1)
		update()
	end)
	if hasAlpha then
		E.dragArea(self, el, alphaBar, function(_, y)
			alpha = 1 - math.clamp((y - alphaBar.AbsolutePosition.Y) / math.max(alphaBar.AbsoluteSize.Y, 1), 0, 1)
			update()
		end)
	end
	hex.FocusLost:Connect(function()
		local r, g, bl = hex.Text:match("#?(%x%x)(%x%x)(%x%x)")
		if r then
			el:Set(C(tonumber(r, 16), tonumber(g, 16), tonumber(bl, 16)))
		else
			update(true)
		end
	end)
	if rainbowBtn then
		rainbowBtn.MouseButton1Click:Connect(function()
			el:SetRainbow(not el._rainbow)
		end)
	end

	-- плавное раскрытие/закрытие
	preview.MouseButton1Click:Connect(function()
		open = not open
		if open then
			body.Size = UDim2.new(1, 0, 0, 0)
			body.Visible = true
			tween(body, { Size = UDim2.new(1, 0, 0, panelH + 2) }, 0.24, Enum.EasingStyle.Quart)
		else
			tween(body, { Size = UDim2.new(1, 0, 0, 0) }, 0.18, Enum.EasingStyle.Quart).Completed:Connect(function()
				if not open then
					body.Visible = false
				end
			end)
		end
	end)

	update(true)
	return register(el, cfg, "ColorPicker")
end
Container.Color = Container.ColorPicker

return true
end

__defs["Elements/Table"] = function()
-- Table: колонки, строки, сортировка по клику на заголовок, поиск, выбор строк
local Util = import("Core/Util")
local ThemeM = import("Core/Theme")
local Shapes = import("Core/Shapes")
local E = import("Core/Element")
local Container = import("Core/Container")

local new, tween, corner, stroke, padding = Util.new, Util.tween, Util.corner, Util.stroke, Util.padding
local parse, fire = Util.parse, Util.fire
local buildRow, newElement, register = E.buildRow, E.newElement, E.register

-- Table({ Name, Columns = {"Имя", {Name="Ping", Width=0.2}}, Rows = {{"a", 1}}, Height, Selectable, MultiSelect, Search, Callback })
-- Callback(index, rowValues) для одиночного выбора, Callback(listOfRowValues) для MultiSelect
function Container:Table(a, b, c)
	local cfg = parse(a, { "Columns", "Rows", "Callback" }, b, c)
	local p = buildRow(self, cfg, 0)
	local el = newElement(self, p, cfg)
	local selectable = cfg.Selectable ~= false
	local multi = cfg.MultiSelect == true
	local sortable = cfg.Sortable ~= false
	local height = cfg.Height or 160

	-- нормализация колонок: без Width делят остаток поровну
	local cols = {}
	for i, col in ipairs(cfg.Columns or { "Column" }) do
		cols[i] = {
			name = type(col) == "table" and tostring(col.Name or col[1] or "") or tostring(col),
			width = type(col) == "table" and col.Width or nil,
		}
	end
	local fixed, free = 0, 0
	for _, col in ipairs(cols) do
		if col.width then
			fixed += col.width
		else
			free += 1
		end
	end
	local xPos = 0
	for _, col in ipairs(cols) do
		col.width = col.width or (math.max(1 - fixed, 0.1) / math.max(free, 1))
		col.x = xPos
		xPos += col.width
	end

	local data = {} -- { values = {...} }
	local selected = {}
	local rowButtons = {}
	local sortCol, sortAsc = nil, true

	local searchH = cfg.Search and 30 or 0
	local wrap = new("Frame", {
		Size = UDim2.new(1, 0, 0, height + searchH), BackgroundTransparency = 1, LayoutOrder = 3, Parent = p.content,
	})
	local searchBox
	if cfg.Search then
		searchBox = new("TextBox", {
			Size = UDim2.new(1, 0, 0, 24), PlaceholderText = "Filter...", TextSize = 12, BackgroundTransparency = 0,
			Theme = { BackgroundColor3 = "Background", TextColor3 = "Text", PlaceholderColor3 = "SubText" }, Parent = wrap,
		})
		corner(searchBox, 5)
		padding(searchBox, 0, 0, 8, 8)
	end
	local frame = new("Frame", {
		Size = UDim2.new(1, 0, 0, height), Position = UDim2.fromOffset(0, searchH), ClipsDescendants = true,
		Theme = { BackgroundColor3 = "Background" }, Parent = wrap,
	})
	corner(frame, 6)
	stroke(frame)
	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 24), Theme = { BackgroundColor3 = "Topbar" }, Parent = frame })
	local list = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -24), Position = UDim2.fromOffset(0, 24), CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Theme = { ScrollBarImageColor3 = "Accent" }, Parent = frame,
	})
	Util.list(list, 0)

	local headerArrows = {}
	local function paintHeaders()
		for i, arrow in ipairs(headerArrows) do
			arrow.Visible = sortCol == i
			arrow.Rotation = sortAsc and 180 or 0 -- вверх = по возрастанию
		end
	end

	local function matches(entry, q)
		for _, v in ipairs(entry.values) do
			if tostring(v):lower():find(q, 1, true) then
				return true
			end
		end
		return false
	end

	local function compare(x, y)
		local a1, b1 = x.values[sortCol], y.values[sortCol]
		local na, nb = tonumber(a1), tonumber(b1)
		local less
		if na and nb then
			less = na < nb
		else
			less = tostring(a1):lower() < tostring(b1):lower()
		end
		if sortAsc then
			return less
		end
		return not less and tostring(a1) ~= tostring(b1)
	end

	local function selectedValues()
		local out = {}
		for _, entry in ipairs(data) do
			if selected[entry] then
				table.insert(out, entry.values)
			end
		end
		return out
	end

	local render
	local function onClickRow(entry)
		if not selectable then
			return
		end
		if multi then
			selected[entry] = not selected[entry] or nil
		else
			selected = { [entry] = true }
		end
		render()
		if multi then
			fire(el._callback, selectedValues())
		else
			fire(el._callback, table.find(data, entry), entry.values)
		end
		for _, fn in ipairs(el._listeners) do
			fire(fn, el:Get())
		end
	end

	function render()
		for _, rb in ipairs(rowButtons) do
			rb:Destroy()
		end
		table.clear(rowButtons)
		local q = searchBox and searchBox.Text:lower() or ""
		local display = {}
		for _, entry in ipairs(data) do
			if q == "" or matches(entry, q) then
				table.insert(display, entry)
			end
		end
		if sortCol then
			table.sort(display, compare)
		end
		for i, entry in ipairs(display) do
			local rb = new("TextButton", {
				Size = UDim2.new(1, 0, 0, 24), LayoutOrder = i, Theme = { BackgroundColor3 = "Accent" },
				BackgroundTransparency = selected[entry] and 0.7 or 1, Parent = list,
			})
			for ci, col in ipairs(cols) do
				local v = entry.values[ci]
				new("TextLabel", {
					Size = UDim2.new(col.width, -10, 1, 0), Position = UDim2.new(col.x, 8, 0, 0),
					Text = v ~= nil and tostring(v) or "", TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd,
					Theme = { TextColor3 = "Text" }, Parent = rb,
				})
			end
			rb.MouseEnter:Connect(function()
				if not selected[entry] then
					tween(rb, { BackgroundTransparency = 0.88 }, 0.1)
				end
			end)
			rb.MouseLeave:Connect(function()
				if not selected[entry] then
					tween(rb, { BackgroundTransparency = 1 }, 0.1)
				end
			end)
			rb.MouseButton1Click:Connect(function()
				onClickRow(entry)
			end)
			table.insert(rowButtons, rb)
		end
	end

	for i, col in ipairs(cols) do
		local hb = new("TextButton", {
			Size = UDim2.new(col.width, 0, 1, 0), Position = UDim2.new(col.x, 0, 0, 0), Parent = header,
		})
		new("TextLabel", {
			Size = UDim2.new(1, -26, 1, 0), Position = UDim2.fromOffset(8, 0), Text = col.name, Font = Enum.Font.GothamBold,
			TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd, Theme = { TextColor3 = "SubText" }, Parent = hb,
		})
		local arrow = Shapes.chevron(hb, 10, "SubText")
		arrow.AnchorPoint = Vector2.new(1, 0.5)
		arrow.Position = UDim2.new(1, -8, 0.5, 0)
		arrow.Visible = false
		headerArrows[i] = arrow
		hb.MouseButton1Click:Connect(function()
			if not sortable then
				return
			end
			if sortCol == i then
				sortAsc = not sortAsc
			else
				sortCol, sortAsc = i, true
			end
			paintHeaders()
			render()
		end)
	end
	if searchBox then
		searchBox:GetPropertyChangedSignal("Text"):Connect(render)
	end

	function el:AddRow(values)
		table.insert(data, { values = values })
		render()
	end
	function el:SetRows(rows)
		data, selected = {}, {}
		for _, values in ipairs(rows or {}) do
			table.insert(data, { values = values })
		end
		render()
	end
	function el:RemoveRow(index)
		local entry = data[index]
		if entry then
			selected[entry] = nil
			table.remove(data, index)
			render()
		end
	end
	function el:Clear()
		data, selected = {}, {}
		render()
	end
	function el:GetRows()
		local out = {}
		for _, entry in ipairs(data) do
			table.insert(out, entry.values)
		end
		return out
	end
	function el:Select(index)
		local entry = data[index]
		if entry then
			if multi then
				selected[entry] = true
			else
				selected = { [entry] = true }
			end
			render()
		end
	end
	function el:Sort(colIndex, ascending)
		sortCol, sortAsc = colIndex, ascending ~= false
		paintHeaders()
		render()
	end
	-- одиночный выбор -> значения строки или nil; MultiSelect -> список строк
	function el:Get()
		local vals = selectedValues()
		if multi then
			return vals
		end
		return vals[1]
	end

	ThemeM.addRefresh(frame, render)
	for _, values in ipairs(cfg.Rows or {}) do
		table.insert(data, { values = values })
	end
	paintHeaders()
	render()
	return register(el, cfg, "Table")
end

return true
end

__defs["Elements/Group"] = function()
-- Group (карточка-контейнер, можно сворачивать) и Columns (колонки)
local Env = import("Core/Env")
local Util = import("Core/Util")
local Icons = import("Core/Icons")
local Shapes = import("Core/Shapes")
local Container = import("Core/Container")

local new, tween, corner, stroke, padding = Util.new, Util.tween, Util.corner, Util.stroke, Util.padding
local parse = Util.parse

local Group = setmetatable({}, { __index = Container })
Group.__index = Group

function Group:SetTitle(t)
	self._titleLabel.Text = tostring(t)
end

function Group:Collapse()
	if not self._collapsible then
		return
	end
	self.Collapsed = true
	self._body.Visible = false
	tween(self._arrow, { Rotation = -90 }, 0.15)
end

function Group:Expand()
	if not self._collapsible then
		return
	end
	self.Collapsed = false
	self._body.Visible = true
	tween(self._arrow, { Rotation = 0 }, 0.15)
end

function Group:ToggleCollapse()
	if self.Collapsed then
		self:Expand()
	else
		self:Collapse()
	end
end

function Group:SetVisible(v)
	self._card.Visible = v and true or false
end

function Group:Destroy()
	self._card:Destroy()
end

-- Group({ Name, Icon, Collapsible, Collapsed }) или Group("Название")
function Container:Group(a, b)
	local cfg = parse(a, { "Collapsible" }, b)
	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = self:_nextOrder(),
		Theme = { BackgroundColor3 = "Topbar" }, Parent = self.Holder,
	})
	corner(card, 8)
	stroke(card)
	local inner = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = card,
	})
	padding(inner, 0, 8, 0, 0)
	Util.list(inner, 0)

	local header = new("TextButton", { Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 1, Parent = inner })
	local indent = 12
	if cfg.Icon then
		local icon = Icons.create(header, cfg.Icon, 16, "Accent", cfg.IconUrl or self.Window.IconUrl)
		if icon then
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, 12, 0.5, 0)
			indent = 36
		end
	end
	local title = new("TextLabel", {
		Size = UDim2.new(1, -(indent + 34), 1, 0), Position = UDim2.fromOffset(indent, 0), Text = cfg.Name,
		Font = Enum.Font.GothamBold, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "Text" }, Parent = header,
	})
	local arrow = Shapes.chevron(header, 12, "SubText")
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.new(1, -20, 0.5, 0)
	arrow.Visible = cfg.Collapsible == true

	local body = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		LayoutOrder = 2, Parent = inner,
	})
	padding(body, 0, 0, 8, 8)
	Util.list(body, 6)

	local group = setmetatable(Container.new(self.Window, self.Tab, body, self.Scroller), Group)
	group._card, group._body, group._arrow, group._titleLabel = card, body, arrow, title
	group._collapsible = cfg.Collapsible == true
	group.Collapsed = false
	header.MouseButton1Click:Connect(function()
		group:ToggleCollapse()
	end)
	if cfg.Collapsed then
		group:Collapse()
	end
	return group
end

-- Columns(n): возвращает n контейнеров рядом. На телефоне колонки встают друг под другом.
-- local left, right = Tab:Columns(2)
function Container:Columns(n, gap)
	n = math.max(1, n or 2)
	gap = gap or 8
	local stack = Env.IsMobile
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		LayoutOrder = self:_nextOrder(), Parent = self.Holder,
	})
	Util.list(row, gap, {
		FillDirection = stack and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})
	local cols = {}
	for i = 1, n do
		local width = stack and UDim2.new(1, 0, 0, 0) or UDim2.new(1 / n, -(gap * (n - 1)) / n, 0, 0)
		local col = new("Frame", {
			Size = width, AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = i, Parent = row,
		})
		Util.list(col, 6)
		cols[i] = Container.new(self.Window, self.Tab, col, self.Scroller)
	end
	return table.unpack(cols)
end

return true
end

__defs["Systems/Notify"] = function()
-- Уведомления: Majestic:Notify("Заголовок", "Текст", 4) или таблицей { Title, Content, Type, Duration, Icon }
local Util = import("Core/Util")
local ThemeM = import("Core/Theme")
local Gui = import("Core/Gui")
local Icons = import("Core/Icons")
local Shapes = import("Core/Shapes")

local new, tween, corner, stroke, padding = Util.new, Util.tween, Util.corner, Util.stroke, Util.padding

local Notify = { _n = 0 }

local typeInfo = {
	Info = { key = "Accent", glyph = "i" },
	Success = { key = "Success", shape = "check" },
	Warning = { key = "Warning", glyph = "!" },
	Error = { key = "Danger", shape = "close" },
}

function Notify.show(a, b, c)
	local cfg = type(a) == "table" and a or { Title = a, Content = b, Duration = c }
	local gui = Gui.get()
	local holder = gui:FindFirstChild("Notifications")
	if not holder then
		holder = new("Frame", {
			Name = "Notifications", Size = UDim2.new(0, 290, 1, -20), AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 1, -12), BackgroundTransparency = 1, Parent = gui,
		})
		Util.list(holder, 8, {
			VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		})
	end

	local info = typeInfo[cfg.Type or "Info"] or typeInfo.Info
	local col = ThemeM.Colors[info.key]
	local dur = cfg.Duration or 4

	Notify._n += 1
	local wrap = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		LayoutOrder = Notify._n, Parent = holder,
	})
	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(1, 310, 0, 0),
		ClipsDescendants = true, Theme = { BackgroundColor3 = "Element" }, Parent = wrap,
	})
	corner(card, 8)
	stroke(card)

	-- значок слева: свой Icon или бейдж по типу (нарисованные фигуры, без символов шрифта)
	local leftPad = 16
	local custom = cfg.Icon and Icons.create(card, cfg.Icon, 18, info.key, cfg.IconUrl)
	if custom then
		custom.Position = UDim2.fromOffset(14, 11)
		leftPad = 42
	else
		local badge = new("Frame", {
			Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(12, 10), BackgroundTransparency = 0.8,
			Theme = { BackgroundColor3 = info.key }, Parent = card,
		})
		corner(badge, 11)
		local glyph
		if info.shape == "check" then
			glyph = Shapes.check(badge, 12, info.key)
		elseif info.shape == "close" then
			glyph = Shapes.close(badge, 10, info.key)
		else
			glyph = new("TextLabel", {
				Size = UDim2.fromOffset(22, 22), Text = info.glyph, Font = Enum.Font.GothamBold, TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Center, Theme = { TextColor3 = info.key }, Parent = badge,
			})
		end
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.5)
		leftPad = 42
	end

	local inner = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = card,
	})
	padding(inner, 10, 13, leftPad, 12)
	Util.list(inner, 2)
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = tostring(cfg.Title or "Majestic"),
		Font = Enum.Font.GothamBold, TextSize = 13, TextWrapped = true, LayoutOrder = 1,
		Theme = { TextColor3 = "Text" }, Parent = inner,
	})
	if cfg.Content then
		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = tostring(cfg.Content),
			TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2,
			Theme = { TextColor3 = "SubText" }, Parent = inner,
		})
	end
	new("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = col, Parent = card })
	local bar = new("Frame", {
		Size = UDim2.new(1, 0, 0, 2), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = col, Parent = card,
	})

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		tween(card, { Position = UDim2.new(1, 310, 0, 0) }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			.Completed:Connect(function()
				wrap:Destroy()
			end)
	end
	card.InputBegan:Connect(function(i)
		if Util.isPress(i) then
			close()
		end
	end)

	tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.35, Enum.EasingStyle.Back)
	if dur > 0 then
		tween(bar, { Size = UDim2.new(0, 0, 0, 2) }, dur, Enum.EasingStyle.Linear)
		task.delay(dur, close)
	else
		bar:Destroy()
	end
	return { Close = close }
end

return Notify
end

__defs["Systems/Dialog"] = function()
-- Window:Dialog({ Title, Content, Buttons = { {"Да", fn}, {"Отмена"} } })
local Util = import("Core/Util")
local Gui = import("Core/Gui")
local Window = import("Core/Window")

local new, corner, padding = Util.new, Util.corner, Util.padding

function Window:Dialog(cfg)
	cfg = type(cfg) == "table" and cfg or { Title = tostring(cfg) }
	local modal = Gui.modal(310, self._main, { zindex = 100, dim = 0.45 })
	local inner = modal.inner

	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20), Text = tostring(cfg.Title or "Majestic"), Font = Enum.Font.GothamBold,
		TextSize = 15, LayoutOrder = 1, Theme = { TextColor3 = "Text" }, Parent = inner,
	})
	if cfg.Content then
		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = tostring(cfg.Content),
			TextWrapped = true, TextSize = 12, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2,
			Theme = { TextColor3 = "SubText" }, Parent = inner,
		})
	end
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 3, Parent = inner,
	})
	Util.list(row, 8, {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	for idx, bcfg in ipairs(cfg.Buttons or { { "OK" } }) do
		local label = type(bcfg) == "table" and (bcfg.Text or bcfg[1]) or tostring(bcfg)
		local cb = type(bcfg) == "table" and (bcfg.Callback or bcfg[2]) or nil
		local primary = idx == 1
		local props = {
			Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0,
			Text = tostring(label), TextSize = 12, Font = Enum.Font.GothamBold, LayoutOrder = idx, Parent = row,
			Theme = { BackgroundColor3 = primary and "Accent" or "Element" },
		}
		if primary then
			props.TextColor3 = Color3.new(1, 1, 1)
		else
			props.Theme.TextColor3 = "Text"
		end
		local b = new("TextButton", props)
		corner(b, 6)
		padding(b, 0, 0, 14, 14)
		b.MouseButton1Click:Connect(function()
			modal.close()
			Util.fire(cb)
		end)
	end
	return modal
end

return true
end

__defs["Systems/Loading"] = function()
-- Загрузочный экран: логотип, прогресс-бар и шаги. Блокирует поток на время анимации.
local Env = import("Core/Env")
local Util = import("Core/Util")
local Gui = import("Core/Gui")
local Icons = import("Core/Icons")
local Shapes = import("Core/Shapes")

local new, tween, corner = Util.new, Util.tween, Util.corner

local Loading = {}

local defaultSteps = { "Initializing", "Loading modules", "Applying theme", "Building interface" }

-- cfg: { Title, Subtitle, Icon, Steps = {...}, Time = 1.8 }
function Loading.run(cfg)
	cfg = cfg or {}
	local steps = cfg.Steps or defaultSteps
	local total = cfg.Time or 1.8
	local modal = Gui.modal(340, nil, { zindex = 200, dim = 0.2 })
	local inner = modal.inner

	local logoHolder = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 1, Parent = inner })
	local logo = cfg.Icon and Icons.create(logoHolder, cfg.Icon, 34, "Accent", cfg.IconUrl)
	if not logo then
		logo = Shapes.diamond(logoHolder, 34, "Accent")
	end
	do
		logo.AnchorPoint = Vector2.new(0.5, 0.5)
		logo.Position = UDim2.fromScale(0.5, 0.5)
		-- бесконечное вращение
		Env.TweenService:Create(
			logo,
			TweenInfo.new(1.6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
			{ Rotation = 360 }
		):Play()
	end
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22), Text = tostring(cfg.Title or "Majestic"), Font = Enum.Font.GothamBold, TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Theme = { TextColor3 = "Text" }, Parent = inner,
	})
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), Text = tostring(cfg.Subtitle or ""), TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, Theme = { TextColor3 = "SubText" }, Parent = inner,
	})
	local bar = new("Frame", {
		Size = UDim2.new(1, 0, 0, 6), LayoutOrder = 4, Theme = { BackgroundColor3 = "Stroke" }, Parent = inner,
	})
	corner(bar, 3)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), Theme = { BackgroundColor3 = "Accent" }, Parent = bar })
	corner(fill, 3)
	local status = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), Text = "", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 5, Theme = { TextColor3 = "SubText" }, Parent = inner,
	})

	local per = total / #steps
	for i, text in ipairs(steps) do
		status.Text = text .. "..."
		tween(fill, { Size = UDim2.fromScale(i / #steps, 1) }, per, Enum.EasingStyle.Quad)
		task.wait(per)
	end
	modal.close()
	task.wait(0.25)
end

return Loading
end

__defs["Systems/KeySystem"] = function()
-- Key System. Проверка по списку Keys или своей функцией Validate(key) -> boolean, сообщение.
-- ВАЖНО: ключи в клиентском скрипте может прочитать кто угодно. Для реальной защиты проверяй ключ на своём сервере
-- через Validate (например, HttpGet на твой API).
local Env = import("Core/Env")
local Util = import("Core/Util")
local ThemeM = import("Core/Theme")
local Gui = import("Core/Gui")
local Shapes = import("Core/Shapes")

local new, tween, corner, stroke, padding = Util.new, Util.tween, Util.corner, Util.stroke, Util.padding

local KeySystem = {}

-- cfg: { Title, Subtitle, Note, Keys, Validate, SaveKey, Folder, FileName, KeyLink, MaxAttempts, OnFail }
-- возвращает true (ключ верный) или false (закрыли окно / кончились попытки)
function KeySystem.run(cfg)
	cfg = cfg or {}
	local folder = cfg.Folder or "Majestic"
	local file = folder .. "/" .. (cfg.FileName or "key.txt")
	local saveKey = cfg.SaveKey ~= false

	local function check(key)
		key = Util.trim(key)
		if key == "" then
			return false, "Enter a key"
		end
		if cfg.Validate then
			local ok, res, msg = pcall(cfg.Validate, key)
			if not ok then
				return false, "Key validation error"
			end
			if res == true then
				return true
			end
			return false, type(msg) == "string" and msg or "Invalid key"
		end
		for _, k in ipairs(cfg.Keys or {}) do
			if key == tostring(k) then
				return true
			end
		end
		return false, "Invalid key"
	end

	-- сохранённый ключ
	if saveKey and Env.fs.isfile and Env.fs.read and Env.fs.isfile(file) then
		local ok, saved = pcall(Env.fs.read, file)
		if ok and type(saved) == "string" and saved ~= "" and check(saved) then
			return true
		end
	end

	local modal = Gui.modal(370, nil, { zindex = 300, dim = 0.35 })
	local inner, card = modal.inner, modal.card

	new("TextLabel", {
		Size = UDim2.new(1, -30, 0, 22), Text = tostring(cfg.Title or "Key System"), Font = Enum.Font.GothamBold,
		TextSize = 17, LayoutOrder = 1, Theme = { TextColor3 = "Text" }, Parent = inner,
	})
	local sub = cfg.Subtitle or cfg.Note
	if sub then
		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = tostring(sub), TextWrapped = true,
			TextSize = 12, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2,
			Theme = { TextColor3 = "SubText" }, Parent = inner,
		})
	end
	local box = new("TextBox", {
		Size = UDim2.new(1, 0, 0, 34), PlaceholderText = "Enter key...", TextSize = 13, BackgroundTransparency = 0,
		ClipsDescendants = true, LayoutOrder = 3,
		Theme = { BackgroundColor3 = "Element", TextColor3 = "Text", PlaceholderColor3 = "SubText" }, Parent = inner,
	})
	corner(box, 7)
	local boxStroke = stroke(box)
	padding(box, 0, 0, 12, 12)
	local status = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), Text = "", TextSize = 12, LayoutOrder = 4, Theme = { TextColor3 = "SubText" }, Parent = inner,
	})
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = 5, Parent = inner })
	Util.list(row, 8, { FillDirection = Enum.FillDirection.Horizontal })

	local function button(text, order, primary)
		local props = {
			Size = UDim2.new(0.5, -4, 1, 0), BackgroundTransparency = 0, Text = text, Font = Enum.Font.GothamBold,
			TextSize = 12, LayoutOrder = order, Parent = row,
			Theme = { BackgroundColor3 = primary and "Accent" or "Element" },
		}
		if primary then
			props.TextColor3 = Color3.new(1, 1, 1)
		else
			props.Theme.TextColor3 = "Text"
		end
		local b = new("TextButton", props)
		corner(b, 7)
		return b
	end
	local checkBtn = button("Check Key", 1, true)
	local getBtn = cfg.KeyLink and button("Get Key", 2, false) or nil
	if not getBtn then
		checkBtn.Size = UDim2.new(1, 0, 1, 0)
	end

	local closeBtn = new("TextButton", {
		Size = UDim2.fromOffset(26, 26), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10),
		ZIndex = 5, Parent = card,
	})
	local closeGlyph = Shapes.close(closeBtn, 12, "SubText")
	closeGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
	closeGlyph.Position = UDim2.fromScale(0.5, 0.5)

	local result, busy, attempts = nil, false, 0
	local function setStatus(text, key)
		status.Text = text
		status.TextColor3 = ThemeM.Colors[key]
	end
	local function shake()
		for _, dx in ipairs({ 9, -9, 6, -6, 0 }) do
			tween(card, { Position = UDim2.new(0.5, dx, 0.5, 0) }, 0.05)
			task.wait(0.05)
		end
	end
	local function submit()
		if busy or result ~= nil then
			return
		end
		busy = true
		setStatus("Checking...", "SubText")
		local ok, msg = check(box.Text)
		if ok then
			setStatus("Key accepted", "Success")
			if saveKey and Env.fsReady() then
				Env.ensureFolder(folder)
				pcall(Env.fs.write, file, Util.trim(box.Text))
			end
			task.wait(0.4)
			result = true
		else
			attempts += 1
			setStatus(msg or "Invalid key", "Danger")
			tween(boxStroke, { Color = ThemeM.Colors.Danger }, 0.15)
			shake()
			tween(boxStroke, { Color = ThemeM.Colors.Stroke }, 0.4)
			if cfg.MaxAttempts and attempts >= cfg.MaxAttempts then
				result = false
			end
		end
		busy = false
	end

	checkBtn.MouseButton1Click:Connect(submit)
	box.FocusLost:Connect(function(enter)
		if enter then
			submit()
		end
	end)
	if getBtn then
		getBtn.MouseButton1Click:Connect(function()
			local copied = Env.clipboard(cfg.KeyLink)
			setStatus(copied and "Link copied to clipboard" or tostring(cfg.KeyLink), "SubText")
		end)
	end
	closeBtn.MouseButton1Click:Connect(function()
		result = false
	end)

	while result == nil do
		task.wait(0.1)
	end
	modal.close()
	if result == false and type(cfg.OnFail) == "function" then
		Util.fire(cfg.OnFail)
	end
	return result
end

return KeySystem
end

__defs["Systems/Home"] = function()
-- Window:HomeTab({ Welcome, Buttons = {{Name, Desc, Link, Callback}}, Changelog = {{Title, Text}} })
-- Профиль игрока + живая статистика сервера (игроки, пинг, FPS, сессия, Place ID, Job ID)
local Env = import("Core/Env")
local Util = import("Core/Util")
local Window = import("Core/Window")
local Notify = import("Systems/Notify")

local new, corner, stroke = Util.new, Util.corner, Util.stroke

local function formatTime(sec)
	return string.format("%d:%02d:%02d", math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60)
end

function Window:HomeTab(cfg)
	cfg = cfg or {}
	local lp = Env.LocalPlayer
	local tab = self:Tab({ Name = cfg.Name or "Home", Icon = cfg.Icon or "home", IconUrl = cfg.IconUrl })
	tab.TabButton.LayoutOrder = 0 -- всегда первая в списке

	-- карточка профиля
	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 88), ClipsDescendants = true, LayoutOrder = tab:_nextOrder(),
		Theme = { BackgroundColor3 = "Element" }, Parent = tab.Holder,
	})
	corner(card, 8)
	stroke(card)
	local avatar = new("ImageLabel", {
		Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(14, 14), BackgroundTransparency = 0,
		Theme = { BackgroundColor3 = "Background" }, Parent = card,
	})
	corner(avatar, 30)
	task.spawn(function()
		pcall(function()
			avatar.Image = Env.Players:GetUserThumbnailAsync(
				lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100
			)
		end)
	end)
	new("TextLabel", {
		Size = UDim2.new(1, -100, 0, 22), Position = UDim2.fromOffset(86, 14),
		Text = (cfg.Welcome or "Welcome back") .. ", " .. lp.DisplayName, Font = Enum.Font.GothamBold, TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd, Theme = { TextColor3 = "Text" }, Parent = card,
	})
	new("TextLabel", {
		Size = UDim2.new(1, -100, 0, 16), Position = UDim2.fromOffset(86, 38), Text = "@" .. lp.Name, TextSize = 12,
		Theme = { TextColor3 = "SubText" }, Parent = card,
	})
	local gameLabel = new("TextLabel", {
		Size = UDim2.new(1, -100, 0, 16), Position = UDim2.fromOffset(86, 56), Text = "", TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd, Theme = { TextColor3 = "Accent" }, Parent = card,
	})
	task.spawn(function()
		local ok, info = pcall(function()
			return Env.MarketplaceService:GetProductInfo(game.PlaceId)
		end)
		gameLabel.Text = ok and info and info.Name or game.Name
	end)

	-- статистика сервера
	if cfg.ShowStats ~= false then
		-- верхний ряд: 4 компактные карточки
		local grid = new("Frame", {
			Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, LayoutOrder = tab:_nextOrder(), Parent = tab.Holder,
		})
		new("UIGridLayout", {
			CellSize = UDim2.new(0.25, -6, 0, 56), CellPadding = UDim2.fromOffset(8, 8), Parent = grid,
		})

		local function statCard(caption)
			local b = new("Frame", { Theme = { BackgroundColor3 = "Element" }, Parent = grid })
			corner(b, 8)
			stroke(b)
			local value = new("TextLabel", {
				Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(10, 8), Text = "-", Font = Enum.Font.GothamBold,
				TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd, Theme = { TextColor3 = "Text" }, Parent = b,
			})
			new("TextLabel", {
				Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(10, 32), Text = caption, TextSize = 11,
				Theme = { TextColor3 = "SubText" }, Parent = b,
			})
			return value
		end

		-- широкие карточки: ID целиком, без обрезки (клик копирует)
		local function wideCard(caption, text)
			local b = new("TextButton", {
				Size = UDim2.new(1, 0, 0, 46), LayoutOrder = tab:_nextOrder(), BackgroundTransparency = 0,
				Theme = { BackgroundColor3 = "Element" }, Parent = tab.Holder,
			})
			corner(b, 8)
			stroke(b)
			new("TextLabel", {
				Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(10, 6), Text = caption .. "  (click to copy)",
				TextSize = 11, Theme = { TextColor3 = "SubText" }, Parent = b,
			})
			new("TextLabel", {
				Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 22), Text = text, Font = Enum.Font.GothamBold,
				TextSize = Env.IsMobile and 11 or 12, Theme = { TextColor3 = "Text" }, Parent = b,
			})
			b.MouseButton1Click:Connect(function()
				local copied = Env.clipboard(text)
				Notify.show({
					Title = copied and "Copied" or "Clipboard unavailable", Content = caption,
					Type = copied and "Success" or "Warning", Duration = 2,
				})
			end)
		end

		local vPlayers = statCard("Players")
		local vPing = statCard("Ping")
		local vFps = statCard("FPS")
		local vTime = statCard("Session")
		wideCard("Place ID", tostring(game.PlaceId))
		wideCard("Job ID", game.JobId ~= "" and game.JobId or "Studio")

		local frames, last, started = 0, os.clock(), os.clock()
		self:_connect(Env.RunService.RenderStepped, function()
			frames += 1
		end)
		task.spawn(function()
			while self._alive do
				local now = os.clock()
				local fps = math.floor(frames / math.max(now - last, 0.001) + 0.5)
				frames, last = 0, now
				pcall(function()
					vPlayers.Text = #Env.Players:GetPlayers() .. " / " .. Env.Players.MaxPlayers
					vFps.Text = tostring(fps)
					vTime.Text = formatTime(math.floor(now - started))
					local ok, ping = pcall(function()
						return Env.Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
					end)
					vPing.Text = ok and (math.floor(ping + 0.5) .. " ms") or "-"
				end)
				task.wait(1)
			end
		end)
	end

	-- кнопки-ссылки
	if cfg.Buttons and #cfg.Buttons > 0 then
		tab:Section("Links")
		for _, b in ipairs(cfg.Buttons) do
			tab:Button({
				Name = b.Name, Desc = b.Desc, Icon = b.Icon, IconUrl = b.IconUrl, ButtonIcon = b.ButtonIcon or (b.Link and "copy" or "click"),
				Callback = function()
					if b.Link then
						local copied = Env.clipboard(b.Link)
						Notify.show({ Title = copied and "Link copied" or b.Link, Content = b.Name, Type = "Info", Duration = 3 })
					end
					Util.fire(b.Callback)
				end,
			})
		end
	end

	-- список изменений
	if cfg.Changelog and #cfg.Changelog > 0 then
		tab:Section("Changelog")
		for _, entry in ipairs(cfg.Changelog) do
			tab:Paragraph(entry.Title or entry[1] or "", entry.Text or entry[2] or "")
		end
	end
	return tab
end

return true
end

__defs["Systems/Managers"] = function()
-- Window:ConfigManager(контейнер), Window:ThemeEditor(контейнер), Window:Settings()
local Env = import("Core/Env")
local ThemeM = import("Core/Theme")
local Config = import("Core/Config")
local Window = import("Core/Window")
local Notify = import("Systems/Notify")

local function note(ok, title, err)
	Notify.show({
		Title = ok and title or (title .. " failed"), Content = (not ok) and err or nil,
		Type = ok and "Success" or "Error", Duration = 3,
	})
end

-- Менеджер конфигов: сохранить / загрузить / удалить / автозагрузка.
-- container — вкладка или группа; без аргумента создаст свою вкладку.
function Window:ConfigManager(container)
	container = container or self:Tab("Configs", "save")

	local nameInput = container:Input({ Name = "Config name", Default = "default", Placeholder = "name" })
	local list = container:Dropdown({ Name = "Saved configs", Options = Config.list(self), Placeholder = "(none)" })
	list:OnChanged(function(v)
		if v then
			nameInput:Set(v, true)
		end
	end)

	local function refresh()
		list:Refresh(Config.list(self))
	end

	container:Button({
		Name = "Save config", ButtonIcon = "save", ButtonText = "Save",
		Callback = function()
			local ok, err = Config.save(self, nameInput:Get())
			note(ok, "Config saved", err)
			refresh()
		end,
	})
	container:Button({
		Name = "Load config", ButtonIcon = "load", ButtonText = "Load",
		Callback = function()
			local ok, err = Config.load(self, nameInput:Get())
			note(ok, "Config loaded", err)
		end,
	})
	container:Button({
		Name = "Delete config", ButtonIcon = "delete", ButtonText = "Delete",
		Callback = function()
			local name = nameInput:Get()
			self:Dialog({
				Title = "Delete config?", Content = tostring(name),
				Buttons = {
					{ "Delete", function()
						local ok, err = Config.delete(self, name)
						note(ok, "Config deleted", err)
						refresh()
					end },
					{ "Cancel" },
				},
			})
		end,
	})
	container:Button({ Name = "Refresh list", ButtonIcon = "refresh", ButtonText = "Refresh", Callback = refresh })

	local autoLabel = container:Label("Autoload: " .. (Config.getAutoload(self) or "none"))
	container:Button({
		Name = "Set as autoload", Desc = "This config is loaded by Window:LoadAutoConfig() on the next start",
		ButtonIcon = "check", ButtonText = "Set",
		Callback = function()
			local ok, err = Config.setAutoload(self, nameInput:Get())
			if ok then
				autoLabel:Set("Autoload: " .. Config.sanitize(nameInput:Get()))
			end
			note(ok, "Autoload set", err)
		end,
	})
	container:Button({
		Name = "Clear autoload", ButtonIcon = "clear", ButtonText = "Clear",
		Callback = function()
			local ok, err = Config.setAutoload(self, nil)
			if ok then
				autoLabel:Set("Autoload: none")
			end
			note(ok, "Autoload cleared", err)
		end,
	})
	return container
end

-- Редактор тем: цвет каждой части интерфейса вживую, сохранение своих тем, копирование как Lua-таблица
function Window:ThemeEditor(container)
	container = container or self:Tab("Themes", "palette")

	local pickers = {}
	local function sync()
		for key, picker in pairs(pickers) do
			picker:Set(ThemeM.Colors[key], true)
		end
	end

	local presets = container:Dropdown({
		Name = "Preset", Options = ThemeM.names(), Default = ThemeM.Name,
		Callback = function(name)
			ThemeM.set(name)
			sync()
		end,
	})
	for _, key in ipairs(ThemeM.Keys) do
		pickers[key] = container:ColorPicker({
			Name = key, Default = ThemeM.Colors[key],
			Callback = function(color)
				ThemeM.setColor(key, color)
			end,
		})
	end

	local nameInput = container:Input({ Name = "Theme name", Default = "MyTheme", Placeholder = "name" })
	container:Button({
		Name = "Save theme", ButtonIcon = "save", ButtonText = "Save",
		Callback = function()
			local ok, err = Config.saveTheme(self, nameInput:Get())
			note(ok, "Theme saved", err)
			presets:Refresh(ThemeM.names())
			presets:Set(Config.sanitize(nameInput:Get()), true)
		end,
	})
	container:Button({
		Name = "Delete theme", ButtonIcon = "delete", ButtonText = "Delete",
		Callback = function()
			local ok, err = Config.deleteTheme(self, nameInput:Get())
			note(ok, "Theme deleted", err)
			presets:Refresh(ThemeM.names())
		end,
	})
	container:Button({
		Name = "Copy as Lua", Desc = "Color table for Majestic:RegisterTheme", ButtonIcon = "copy", ButtonText = "Copy",
		Callback = function()
			local copied = Env.clipboard(ThemeM.toLua())
			Notify.show({
				Title = copied and "Theme copied" or "Clipboard unavailable", Type = copied and "Success" or "Warning", Duration = 2,
			})
		end,
	})
	return container
end

-- Настройки Liquid Glass: включение, оттенок, размытие, прозрачность
function Window:GlassSettings(container)
	container = container or self:Tab("Glass", "layers")
	local g = ThemeM.Glass
	local previous = ThemeM.Name ~= ThemeM.GlassName and ThemeM.Name or "Dark"

	local toggle = container:Toggle({
		Name = "Liquid Glass", Desc = "Translucent glass panels with background blur", Default = g.Enabled,
		Flag = "Majestic.Glass",
		Callback = function(on)
			if on then
				if ThemeM.Name ~= ThemeM.GlassName then
					previous = ThemeM.Name
				end
				ThemeM.set(ThemeM.GlassName)
			elseif ThemeM.Name == ThemeM.GlassName then
				ThemeM.set(previous)
			end
		end,
	})
	container:ColorPicker({
		Name = "Glass tint", Desc = "Base color of the glass", Default = g.Color, Flag = "Majestic.GlassTint",
		Callback = function(color)
			ThemeM.setGlass({ Color = color })
		end,
	})
	container:Slider({
		Name = "Blur", Desc = "How strongly the background behind the window is blurred", Min = 0, Max = 100,
		Default = g.Blur, Suffix = "%", Flag = "Majestic.GlassBlur",
		Callback = function(v)
			ThemeM.setGlass({ Blur = v })
		end,
	})
	container:Slider({
		Name = "Transparency", Desc = "How see-through the panels are", Min = 0, Max = 95,
		Default = math.floor(g.Transparency * 100 + 0.5), Suffix = "%", Flag = "Majestic.GlassTransparency",
		Callback = function(v)
			ThemeM.setGlass({ Transparency = v / 100 })
		end,
	})
	return container, toggle
end

-- Готовая вкладка настроек: интерфейс, Liquid Glass, конфиги, редактор тем
function Window:Settings(opts)
	opts = opts or {}
	local tab = self:Tab({ Name = opts.Name or "Settings", Icon = opts.Icon or "settings", IconUrl = opts.IconUrl })
	local left, right = tab:Columns(2)

	local glassToggle
	local ui = left:Group({ Name = "Interface", Icon = "layout-dashboard" })
	ui:Dropdown({
		Name = "Theme", Options = ThemeM.names(), Default = ThemeM.Name,
		Callback = function(name)
			ThemeM.set(name)
			if glassToggle then
				glassToggle:Set(name == ThemeM.GlassName, true)
			end
		end,
	})
	ui:ColorPicker({
		Name = "Accent color", Default = ThemeM.Colors.Accent,
		Callback = function(color)
			ThemeM.setColor("Accent", color)
		end,
	})
	-- Commit: масштаб применяется при отпускании ползунка, поэтому меню не дёргается
	ui:Slider({
		Name = "UI scale", Min = 0.7, Max = 1.3, Default = self._scale, Increment = 0.05, Commit = true,
		Callback = function(v)
			self:SetScale(v)
		end,
	})
	ui:Keybind({
		Name = "Menu key", Default = self.ToggleKey,
		OnChange = function(k)
			if k then
				self.ToggleKey = k
			end
		end,
	})

	local glassGroup = left:Group({ Name = "Liquid Glass", Icon = "layers" })
	local _, toggle = self:GlassSettings(glassGroup)
	glassToggle = toggle

	local cfgGroup = right:Group({ Name = "Configuration", Icon = "save" })
	self:ConfigManager(cfgGroup)

	if opts.Themes ~= false then
		local themes = tab:Group({ Name = "Theme editor", Icon = "palette", Collapsible = true, Collapsed = true })
		self:ThemeEditor(themes)
	end

	local misc = tab:Group({ Name = "Misc" })
	misc:Button({
		Name = "Unload UI", Desc = "Close the menu completely", ButtonIcon = "clear", ButtonText = "Unload",
		Callback = function()
			self:Destroy()
		end,
	})
	return tab
end

return true
end

__defs["init"] = function()
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
end

return import("init")
