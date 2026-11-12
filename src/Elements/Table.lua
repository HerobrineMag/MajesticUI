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
