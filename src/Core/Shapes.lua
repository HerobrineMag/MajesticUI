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
