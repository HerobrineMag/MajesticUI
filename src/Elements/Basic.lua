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
