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
