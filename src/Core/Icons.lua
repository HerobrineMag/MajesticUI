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
