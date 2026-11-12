-- Минимальная заглушка Roblox API: хватает, чтобы выполнить код библиотеки без Roblox
warn = print

local rawtypeof = typeof
typeof = function(v)
	if type(v) == "table" then
		local t = rawget(v, "__type")
		if t then
			return t
		end
	end
	return rawtypeof(v)
end

----------------------------------------------------------------------
-- Типы данных
----------------------------------------------------------------------
local function makeVec(typeName, fields)
	local mt = {}
	local function new(...)
		local args = { ... }
		local v = { __type = typeName }
		for i, f in ipairs(fields) do
			v[f] = args[i] or 0
		end
		return setmetatable(v, mt)
	end
	local function op(fn)
		return function(a, b)
			local r = { __type = typeName }
			for _, f in ipairs(fields) do
				local x = type(a) == "table" and a[f] or a
				local y = type(b) == "table" and b[f] or b
				r[f] = fn(x, y)
			end
			return setmetatable(r, mt)
		end
	end
	mt.__index = function(t, k)
		if k == "Magnitude" then
			local sum = 0
			for _, f in ipairs(fields) do
				sum += t[f] * t[f]
			end
			return math.sqrt(sum)
		end
		return nil
	end
	mt.__add = op(function(x, y) return x + y end)
	mt.__sub = op(function(x, y) return x - y end)
	mt.__mul = op(function(x, y) return x * y end)
	mt.__div = op(function(x, y) return x / y end)
	return { new = new }
end

Vector2 = makeVec("Vector2", { "X", "Y" })
Vector3 = makeVec("Vector3", { "X", "Y", "Z" })

UDim = {
	new = function(s, o)
		return { __type = "UDim", Scale = s or 0, Offset = o or 0 }
	end,
}
UDim2 = {
	new = function(sx, ox, sy, oy)
		return { __type = "UDim2", X = UDim.new(sx, ox), Y = UDim.new(sy, oy) }
	end,
	fromOffset = function(x, y)
		return UDim2.new(0, x or 0, 0, y or 0)
	end,
	fromScale = function(x, y)
		return UDim2.new(x or 0, 0, y or 0, 0)
	end,
}

local function hsvToRgb(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then return v, t, p elseif i == 1 then return q, v, p elseif i == 2 then return p, v, t
	elseif i == 3 then return p, q, v elseif i == 4 then return t, p, v else return v, p, q end
end

local colorMt = {}
colorMt.__index = function(c, k)
	if k == "ToHSV" then
		return function(self)
			local r, g, b = self.R, self.G, self.B
			local mx, mn = math.max(r, g, b), math.min(r, g, b)
			local d = mx - mn
			local h = 0
			if d > 0 then
				if mx == r then h = ((g - b) / d) % 6 elseif mx == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
				h = h / 6
			end
			return h, mx == 0 and 0 or d / mx, mx
		end
	elseif k == "ToHex" then
		return function(self)
			return string.format("%02x%02x%02x", math.floor(self.R * 255 + 0.5), math.floor(self.G * 255 + 0.5), math.floor(self.B * 255 + 0.5))
		end
	end
	return nil
end
local function color(r, g, b)
	return setmetatable({ __type = "Color3", R = r, G = g, B = b }, colorMt)
end
Color3 = {
	new = color,
	fromRGB = function(r, g, b)
		return color(r / 255, g / 255, b / 255)
	end,
	fromHSV = function(h, s, v)
		return color(hsvToRgb(h, s, v))
	end,
}

CFrame = {
	new = function() return { __type = "CFrame", XVector = Vector3.new(1, 0, 0), YVector = Vector3.new(0, 1, 0), ZVector = Vector3.new(0, 0, 1) } end,
	fromMatrix = function(pos, x, y, z) return { __type = "CFrame", Position = pos, XVector = x, YVector = y, ZVector = z } end,
}

NumberSequence = { new = function(...) return { __type = "NumberSequence", ... } end }
NumberSequenceKeypoint = { new = function(t, v) return { time = t, value = v } end }
ColorSequence = { new = function(...) return { __type = "ColorSequence", ... } end }
ColorSequenceKeypoint = { new = function(t, v) return { time = t, value = v } end }
TweenInfo = { new = function(...) return { ... } end }

local enumCache = {}
Enum = setmetatable({}, {
	__index = function(_, enumName)
		return setmetatable({}, {
			__index = function(_, itemName)
				local key = enumName .. "." .. tostring(itemName)
				if not enumCache[key] then
					enumCache[key] = { __type = "EnumItem", Name = tostring(itemName), EnumType = enumName }
				end
				return enumCache[key]
			end,
		})
	end,
})

----------------------------------------------------------------------
-- Сигналы и инстансы
----------------------------------------------------------------------
local function Signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		local conn = { Connected = true }
		local entry = { fn = fn }
		table.insert(self.handlers, entry)
		function conn:Disconnect()
			conn.Connected = false
			entry.dead = true
		end
		return conn
	end
	s.Once = s.Connect
	function s:Fire(...)
		for _, e in ipairs({ table.unpack(self.handlers) }) do
			if not e.dead then
				e.fn(...)
			end
		end
	end
	return s
end

local signalNames = {}
for _, n in ipairs({
	"MouseButton1Click", "MouseButton1Down", "MouseEnter", "MouseLeave", "InputBegan", "InputChanged", "InputEnded",
	"FocusLost", "Focused", "Changed", "Completed", "Activated", "ChildAdded", "AncestryChanged",
}) do
	signalNames[n] = true
end

local states = setmetatable({}, { __mode = "k" })
Mock = { states = states, instances = {}, Signal = Signal }

local methods = {}
function methods.Destroy(self, st)
	st.destroyed = true
	self.Parent = nil
end
function methods.FindFirstChild(self, st, name)
	for _, c in ipairs(st.children) do
		if c.Name == name then
			return c
		end
	end
	return nil
end
methods.WaitForChild = methods.FindFirstChild
function methods.GetPropertyChangedSignal(self, st, prop)
	local key = "PC_" .. prop
	st.signals[key] = st.signals[key] or Signal()
	return st.signals[key]
end
function methods.IsDescendantOf(self, st, ancestor)
	local p = st.parent
	while p do
		if p == ancestor then
			return true
		end
		p = states[p].parent
	end
	return false
end
function methods.IsA(self, st, cls)
	return st.class == cls
end
function methods.CaptureFocus() end
function methods.GetChildren(self, st)
	return { table.unpack(st.children) }
end

Instance = {
	new = function(class)
		local st = { class = class, props = {}, children = {}, signals = {}, parent = nil }
		local proxy = {}
		states[proxy] = st
		table.insert(Mock.instances, proxy)
		setmetatable(proxy, {
			__index = function(_, k)
				if k == "__type" then return "Instance" end
				if k == "ClassName" then return class end
				if k == "Parent" then return st.parent end
				local v = st.props[k]
				if v ~= nil then return v end
				if signalNames[k] then
					st.signals[k] = st.signals[k] or Signal()
					return st.signals[k]
				end
				local m = methods[k]
				if m then
					return function(self, ...)
						return m(proxy, st, ...)
					end
				end
				if k == "AbsoluteSize" then return Vector2.new(300, 40) end
				if k == "AbsolutePosition" then return Vector2.new(0, 0) end
				if k == "TextBounds" then return Vector2.new(60, 14) end
				if k == "CanvasPosition" then return Vector2.new(0, 0) end
				if k == "Name" then return class end
				if k == "Visible" or k == "Enabled" then return true end
				if k == "BackgroundTransparency" or k == "Transparency" or k == "Rotation" then return 0 end
				return nil
			end,
			__newindex = function(_, k, v)
				if k == "Parent" then
					if st.parent then
						local list = states[st.parent].children
						local idx = table.find(list, proxy)
						if idx then table.remove(list, idx) end
					end
					st.parent = v
					if v then table.insert(states[v].children, proxy) end
				else
					st.props[k] = v
					local sig = st.signals["PC_" .. k]
					if sig then sig:Fire() end
				end
			end,
		})
		return proxy
	end,
}

----------------------------------------------------------------------
-- task / сервисы / глобальные функции
----------------------------------------------------------------------
Mock.delayed = {}
Mock.ours = {}
function Mock.newThread(f)
	local co = coroutine.create(f)
	Mock.ours[co] = true
	return co
end
task = {
	spawn = function(f, ...)
		local co = Mock.newThread(f)
		local ok, err = coroutine.resume(co, ...)
		if not ok then error(err, 0) end
		return co
	end,
	defer = function(f, ...)
		task.spawn(f, ...)
	end,
	delay = function(t, f, ...)
		table.insert(Mock.delayed, { f = f, args = { ... } })
	end,
	wait = function()
		-- уступаем управление только в потоках заглушки; главный поток идёт дальше
		if Mock.ours[coroutine.running()] then
			coroutine.yield()
		end
		return 0
	end,
}
function Mock.runDelayed()
	local list = Mock.delayed
	Mock.delayed = {}
	for _, d in ipairs(list) do
		d.f(table.unpack(d.args))
	end
end

local jsonStore, jsonN = {}, 0
local localPlayer = { Name = "Tester", DisplayName = "Test User", UserId = 1 }
local services = {}
services.Players = {
	LocalPlayer = localPlayer,
	MaxPlayers = 20,
	GetPlayers = function() return { localPlayer } end,
	GetUserThumbnailAsync = function() return "rbxthumb://avatar" end,
}
localPlayer.WaitForChild = function() return nil end
services.TweenService = {
	Create = function(_self, inst, _info, props)
		local tw = { done = false }
		tw.Completed = {
			Connect = function(_, fn)
				if tw.done then fn() end
				return { Disconnect = function() end }
			end,
		}
		function tw:Play()
			for k, v in pairs(props) do
				inst[k] = v
			end
			tw.done = true
		end
		return tw
	end,
}
Mock.uis = {
	InputBegan = Signal(), InputChanged = Signal(), InputEnded = Signal(),
	TouchEnabled = false, KeyboardEnabled = true,
	GetMouseLocation = function() return Vector2.new(100, 100) end,
}
services.UserInputService = Mock.uis
services.RunService = { RenderStepped = Signal(), Heartbeat = Signal() }
services.HttpService = {
	JSONEncode = function(_, t)
		jsonN += 1
		jsonStore["json:" .. jsonN] = t
		return "json:" .. jsonN
	end,
	JSONDecode = function(_, s)
		return jsonStore[s]
	end,
	GenerateGUID = function() return "guid" end,
}
Mock.coreGui = Instance.new("Folder")
services.CoreGui = Mock.coreGui
services.GuiService = { GetGuiInset = function() return Vector2.new(0, 36) end }
services.Stats = { Network = { ServerStatsItem = { ["Data Ping"] = { GetValue = function() return 42 end } } } }
services.MarketplaceService = { GetProductInfo = function() return { Name = "Mock Game" } end }

workspace = Instance.new("Workspace")
Mock.camera = Instance.new("Camera")
Mock.camera.ViewportSize = Vector2.new(1280, 720)
Mock.camera.CFrame = CFrame.new()
Mock.camera.FieldOfView = 70
Mock.camera.ScreenPointToRay = function(_self, x, y)
	return { Origin = Vector3.new(x * 0.001, y * 0.001, 0), Direction = Vector3.new(0, 0, -1) }
end
workspace.CurrentCamera = Mock.camera
Mock.lighting = Instance.new("Lighting")
services.Lighting = Mock.lighting

-- иконки Lucide: крошечный набор в формате Rayfield
Mock.iconTable = {
	["48px"] = {
		home = {111, {48, 48}, {0, 0}}, search = {111, {48, 48}, {48, 0}}, settings = {111, {48, 48}, {96, 0}},
		info = {111, {48, 48}, {144, 0}}, check = {111, {48, 48}, {192, 0}}, x = {111, {48, 48}, {240, 0}},
		["triangle-alert"] = {111, {48, 48}, {288, 0}}, ["layout-dashboard"] = {111, {48, 48}, {336, 0}},
		palette = {111, {48, 48}, {384, 0}}, save = {111, {48, 48}, {432, 0}}, eye = {111, {48, 48}, {480, 0}},
		["mouse-pointer-click"] = {111, {48, 48}, {528, 0}}, copy = {111, {48, 48}, {576, 0}}, layers = {111, {48, 48}, {624, 0}},
		download = {111, {48, 48}, {672, 0}}, ["trash-2"] = {111, {48, 48}, {720, 0}}, ["refresh-cw"] = {111, {48, 48}, {768, 0}},
	},
	["256px"] = {},
}
Mock.httpGetCalls = 0
game = {
	PlaceId = 123, JobId = "job-abc", Name = "Mock",
	GetService = function(_, name)
		return services[name] or {}
	end,
	HttpGet = function(_, url)
		Mock.httpGetCalls += 1
		if string.find(url, "icons.lua", 1, true) then
			return "--ICONS--"
		end
		return nil
	end,
}
-- в Luau CLI нет loadstring: «загружаем» только наш набор иконок
loadstring = function(src)
	if src == "--ICONS--" then
		return function()
			return Mock.iconTable
		end
	end
	return nil
end

-- файловая система в памяти
Mock.files, Mock.folders, Mock.clipboard = {}, {}, nil
writefile = function(p, d) Mock.files[p] = d end
readfile = function(p) return Mock.files[p] end
isfile = function(p) return Mock.files[p] ~= nil end
isfolder = function(p) return Mock.folders[p] == true end
makefolder = function(p) Mock.folders[p] = true end
delfile = function(p) Mock.files[p] = nil end
listfiles = function(dir)
	local out = {}
	for p in pairs(Mock.files) do
		if p:sub(1, #dir + 1) == dir .. "/" then
			table.insert(out, p)
		end
	end
	return out
end
setclipboard = function(t) Mock.clipboard = t end
