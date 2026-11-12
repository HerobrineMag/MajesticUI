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
