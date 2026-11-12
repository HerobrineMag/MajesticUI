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
