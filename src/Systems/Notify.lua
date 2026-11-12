-- Уведомления: Majestic:Notify("Заголовок", "Текст", 4) или таблицей { Title, Content, Type, Duration, Icon }
local Util = import("Core/Util")
local ThemeM = import("Core/Theme")
local Gui = import("Core/Gui")
local Icons = import("Core/Icons")
local Shapes = import("Core/Shapes")

local new, tween, corner, stroke, padding = Util.new, Util.tween, Util.corner, Util.stroke, Util.padding

local Notify = { _n = 0 }

local typeInfo = {
	Info = { key = "Accent", glyph = "i" },
	Success = { key = "Success", shape = "check" },
	Warning = { key = "Warning", glyph = "!" },
	Error = { key = "Danger", shape = "close" },
}

function Notify.show(a, b, c)
	local cfg = type(a) == "table" and a or { Title = a, Content = b, Duration = c }
	local gui = Gui.get()
	local holder = gui:FindFirstChild("Notifications")
	if not holder then
		holder = new("Frame", {
			Name = "Notifications", Size = UDim2.new(0, 290, 1, -20), AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 1, -12), BackgroundTransparency = 1, Parent = gui,
		})
		Util.list(holder, 8, {
			VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		})
	end

	local info = typeInfo[cfg.Type or "Info"] or typeInfo.Info
	local col = ThemeM.Colors[info.key]
	local dur = cfg.Duration or 4

	Notify._n += 1
	local wrap = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		LayoutOrder = Notify._n, Parent = holder,
	})
	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(1, 310, 0, 0),
		ClipsDescendants = true, Theme = { BackgroundColor3 = "Element" }, Parent = wrap,
	})
	corner(card, 8)
	stroke(card)

	-- значок слева: свой Icon или бейдж по типу (нарисованные фигуры, без символов шрифта)
	local leftPad = 16
	local custom = cfg.Icon and Icons.create(card, cfg.Icon, 18, info.key, cfg.IconUrl)
	if custom then
		custom.Position = UDim2.fromOffset(14, 11)
		leftPad = 42
	else
		local badge = new("Frame", {
			Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(12, 10), BackgroundTransparency = 0.8,
			Theme = { BackgroundColor3 = info.key }, Parent = card,
		})
		corner(badge, 11)
		local glyph
		if info.shape == "check" then
			glyph = Shapes.check(badge, 12, info.key)
		elseif info.shape == "close" then
			glyph = Shapes.close(badge, 10, info.key)
		else
			glyph = new("TextLabel", {
				Size = UDim2.fromOffset(22, 22), Text = info.glyph, Font = Enum.Font.GothamBold, TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Center, Theme = { TextColor3 = info.key }, Parent = badge,
			})
		end
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.5)
		leftPad = 42
	end

	local inner = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = card,
	})
	padding(inner, 10, 13, leftPad, 12)
	Util.list(inner, 2)
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = tostring(cfg.Title or "Majestic"),
		Font = Enum.Font.GothamBold, TextSize = 13, TextWrapped = true, LayoutOrder = 1,
		Theme = { TextColor3 = "Text" }, Parent = inner,
	})
	if cfg.Content then
		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = tostring(cfg.Content),
			TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2,
			Theme = { TextColor3 = "SubText" }, Parent = inner,
		})
	end
	new("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = col, Parent = card })
	local bar = new("Frame", {
		Size = UDim2.new(1, 0, 0, 2), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = col, Parent = card,
	})

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		tween(card, { Position = UDim2.new(1, 310, 0, 0) }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			.Completed:Connect(function()
				wrap:Destroy()
			end)
	end
	card.InputBegan:Connect(function(i)
		if Util.isPress(i) then
			close()
		end
	end)

	tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.35, Enum.EasingStyle.Back)
	if dur > 0 then
		tween(bar, { Size = UDim2.new(0, 0, 0, 2) }, dur, Enum.EasingStyle.Linear)
		task.delay(dur, close)
	else
		bar:Destroy()
	end
	return { Close = close }
end

return Notify
