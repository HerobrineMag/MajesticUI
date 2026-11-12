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
