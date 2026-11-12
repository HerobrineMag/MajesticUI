-- Group (карточка-контейнер, можно сворачивать) и Columns (колонки)
local Env = import("Core/Env")
local Util = import("Core/Util")
local Icons = import("Core/Icons")
local Shapes = import("Core/Shapes")
local Container = import("Core/Container")

local new, tween, corner, stroke, padding = Util.new, Util.tween, Util.corner, Util.stroke, Util.padding
local parse = Util.parse

local Group = setmetatable({}, { __index = Container })
Group.__index = Group

function Group:SetTitle(t)
	self._titleLabel.Text = tostring(t)
end

function Group:Collapse()
	if not self._collapsible then
		return
	end
	self.Collapsed = true
	self._body.Visible = false
	tween(self._arrow, { Rotation = -90 }, 0.15)
end

function Group:Expand()
	if not self._collapsible then
		return
	end
	self.Collapsed = false
	self._body.Visible = true
	tween(self._arrow, { Rotation = 0 }, 0.15)
end

function Group:ToggleCollapse()
	if self.Collapsed then
		self:Expand()
	else
		self:Collapse()
	end
end

function Group:SetVisible(v)
	self._card.Visible = v and true or false
end

function Group:Destroy()
	self._card:Destroy()
end

-- Group({ Name, Icon, Collapsible, Collapsed }) или Group("Название")
function Container:Group(a, b)
	local cfg = parse(a, { "Collapsible" }, b)
	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = self:_nextOrder(),
		Theme = { BackgroundColor3 = "Topbar" }, Parent = self.Holder,
	})
	corner(card, 8)
	stroke(card)
	local inner = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = card,
	})
	padding(inner, 0, 8, 0, 0)
	Util.list(inner, 0)

	local header = new("TextButton", { Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 1, Parent = inner })
	local indent = 12
	if cfg.Icon then
		local icon = Icons.create(header, cfg.Icon, 16, "Accent", cfg.IconUrl or self.Window.IconUrl)
		if icon then
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, 12, 0.5, 0)
			indent = 36
		end
	end
	local title = new("TextLabel", {
		Size = UDim2.new(1, -(indent + 34), 1, 0), Position = UDim2.fromOffset(indent, 0), Text = cfg.Name,
		Font = Enum.Font.GothamBold, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "Text" }, Parent = header,
	})
	local arrow = Shapes.chevron(header, 12, "SubText")
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.new(1, -20, 0.5, 0)
	arrow.Visible = cfg.Collapsible == true

	local body = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		LayoutOrder = 2, Parent = inner,
	})
	padding(body, 0, 0, 8, 8)
	Util.list(body, 6)

	local group = setmetatable(Container.new(self.Window, self.Tab, body, self.Scroller), Group)
	group._card, group._body, group._arrow, group._titleLabel = card, body, arrow, title
	group._collapsible = cfg.Collapsible == true
	group.Collapsed = false
	header.MouseButton1Click:Connect(function()
		group:ToggleCollapse()
	end)
	if cfg.Collapsed then
		group:Collapse()
	end
	return group
end

-- Columns(n): возвращает n контейнеров рядом. На телефоне колонки встают друг под другом.
-- local left, right = Tab:Columns(2)
function Container:Columns(n, gap)
	n = math.max(1, n or 2)
	gap = gap or 8
	local stack = Env.IsMobile
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		LayoutOrder = self:_nextOrder(), Parent = self.Holder,
	})
	Util.list(row, gap, {
		FillDirection = stack and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})
	local cols = {}
	for i = 1, n do
		local width = stack and UDim2.new(1, 0, 0, 0) or UDim2.new(1 / n, -(gap * (n - 1)) / n, 0, 0)
		local col = new("Frame", {
			Size = width, AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = i, Parent = row,
		})
		Util.list(col, 6)
		cols[i] = Container.new(self.Window, self.Tab, col, self.Scroller)
	end
	return table.unpack(cols)
end

return true
