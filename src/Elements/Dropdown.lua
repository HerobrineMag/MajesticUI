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
