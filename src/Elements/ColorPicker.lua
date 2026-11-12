-- ColorPicker: компактная панель (SV-квадрат, оттенок, альфа, HEX, Rainbow), раскрывается плавно
local Env = import("Core/Env")
local Util = import("Core/Util")
local ThemeM = import("Core/Theme")
local E = import("Core/Element")
local Container = import("Core/Container")

local new, tween, corner, stroke, padding = Util.new, Util.tween, Util.corner, Util.stroke, Util.padding
local parse, C = Util.parse, Util.C
local buildRow, newElement, register, changed = E.buildRow, E.newElement, E.register, E.changed

local SV_W, SV_H, BAR_W, GAP = 150, 100, 14, 8

function Container:ColorPicker(a, b, c)
	local cfg = parse(a, { "Default", "Callback" }, b, c)
	local p = buildRow(self, cfg, 50)
	local el = newElement(self, p, cfg)
	local color = typeof(cfg.Default) == "Color3" and cfg.Default or C(255, 255, 255)
	local h, s, v = color:ToHSV()
	local alpha = math.clamp(tonumber(cfg.DefaultAlpha) or 1, 0, 1)
	local hasAlpha = cfg.Alpha == true
	local open = false
	local rainbowConn

	local preview = new("TextButton", {
		Size = UDim2.fromOffset(38, 20), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		BackgroundTransparency = 0, BackgroundColor3 = color, Parent = p.header,
	})
	corner(preview, 5)
	stroke(preview)

	-- панель фиксированного размера справа; body плавно меняет высоту
	local panelW = SV_W + GAP + BAR_W + (hasAlpha and (GAP + BAR_W) or 0)
	local panelH = SV_H + GAP + 24
	local body = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, Visible = false, LayoutOrder = 3,
		ClipsDescendants = true, Parent = p.content,
	})
	local panel = new("Frame", {
		Size = UDim2.fromOffset(panelW, panelH), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1, Parent = body,
	})

	-- квадрат насыщенность/яркость
	local sv = new("Frame", {
		Size = UDim2.fromOffset(SV_W, SV_H), BackgroundColor3 = Color3.fromHSV(h, 1, 1), Active = true, Parent = panel,
	})
	corner(sv, 5)
	local white = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(255, 255, 255), Parent = sv })
	corner(white, 5)
	new("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Parent = white,
	})
	local black = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(0, 0, 0), Parent = sv })
	corner(black, 5)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
		Parent = black,
	})
	local svCursor = new("Frame", {
		Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = sv,
	})
	corner(svCursor, 5)
	new("UIStroke", { Color = C(255, 255, 255), Thickness = 2, Parent = svCursor })

	-- вертикальная полоса оттенка
	local hue = new("Frame", {
		Size = UDim2.fromOffset(BAR_W, SV_H), Position = UDim2.fromOffset(SV_W + GAP, 0),
		BackgroundColor3 = C(255, 255, 255), Active = true, Parent = panel,
	})
	corner(hue, 5)
	local keys = {}
	for i = 0, 6 do
		table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(math.min(i / 6, 0.9999), 1, 1)))
	end
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(keys), Parent = hue })
	local hueCursor = new("Frame", {
		Size = UDim2.new(1, 4, 0, 4), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C(255, 255, 255), Parent = hue,
	})
	corner(hueCursor, 2)
	new("UIStroke", { Color = C(0, 0, 0), Thickness = 1, Parent = hueCursor })

	-- вертикальная полоса прозрачности (сверху непрозрачно)
	local alphaBar, alphaTint, alphaCursor
	if hasAlpha then
		alphaBar = new("Frame", {
			Size = UDim2.fromOffset(BAR_W, SV_H), Position = UDim2.fromOffset(SV_W + GAP + BAR_W + GAP, 0), Active = true,
			Theme = { BackgroundColor3 = "Stroke" }, Parent = panel,
		})
		corner(alphaBar, 5)
		alphaTint = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, Parent = alphaBar })
		corner(alphaTint, 5)
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
			Parent = alphaTint,
		})
		alphaCursor = new("Frame", {
			Size = UDim2.new(1, 4, 0, 4), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0),
			BackgroundColor3 = C(255, 255, 255), Parent = alphaBar,
		})
		corner(alphaCursor, 2)
		new("UIStroke", { Color = C(0, 0, 0), Thickness = 1, Parent = alphaCursor })
	end

	-- HEX и Rainbow под палитрой
	local rowY = SV_H + GAP
	local hexW = cfg.Rainbow and (panelW - 72 - 6) or panelW
	local hex = new("TextBox", {
		Size = UDim2.fromOffset(hexW, 24), Position = UDim2.fromOffset(0, rowY), TextSize = 12, BackgroundTransparency = 0,
		ClipsDescendants = true, Theme = { BackgroundColor3 = "Background", TextColor3 = "Text" }, Parent = panel,
	})
	corner(hex, 5)
	padding(hex, 0, 0, 8, 8)
	local rainbowBtn
	if cfg.Rainbow then
		rainbowBtn = new("TextButton", {
			Size = UDim2.fromOffset(72, 24), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, rowY),
			BackgroundTransparency = 0, Text = "Rainbow", TextSize = 12,
			Theme = { BackgroundColor3 = "Background", TextColor3 = "SubText" }, Parent = panel,
		})
		corner(rainbowBtn, 5)
	end

	local function update(silent)
		color = Color3.fromHSV(h, s, v)
		preview.BackgroundColor3 = color
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.fromScale(s, 1 - v)
		hueCursor.Position = UDim2.fromScale(0.5, h)
		if hasAlpha then
			alphaTint.BackgroundColor3 = color
			alphaCursor.Position = UDim2.fromScale(0.5, 1 - alpha)
			preview.BackgroundTransparency = 1 - alpha
		end
		hex.Text = "#" .. color:ToHex():upper()
		changed(el, silent, color, alpha)
	end

	function el:Set(newColor, silent)
		if typeof(newColor) ~= "Color3" then
			return
		end
		h, s, v = newColor:ToHSV()
		update(silent)
	end
	function el:Get()
		return color
	end
	function el:SetAlpha(a, silent)
		alpha = math.clamp(tonumber(a) or 1, 0, 1)
		update(silent)
	end
	function el:GetAlpha()
		return alpha
	end
	function el:SetRainbow(on)
		if rainbowConn then
			rainbowConn:Disconnect()
			rainbowConn = nil
		end
		if on then
			rainbowConn = Env.RunService.RenderStepped:Connect(function()
				h = (os.clock() * 0.25) % 1
				update()
			end)
			table.insert(el._conns, rainbowConn)
		end
		if rainbowBtn then
			rainbowBtn.TextColor3 = on and ThemeM.Colors.Accent or ThemeM.Colors.SubText
		end
		el._rainbow = on and true or false
	end

	E.dragArea(self, el, sv, function(x, y)
		s = math.clamp((x - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
		v = 1 - math.clamp((y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
		update()
	end)
	E.dragArea(self, el, hue, function(_, y)
		h = math.clamp((y - hue.AbsolutePosition.Y) / math.max(hue.AbsoluteSize.Y, 1), 0, 1)
		update()
	end)
	if hasAlpha then
		E.dragArea(self, el, alphaBar, function(_, y)
			alpha = 1 - math.clamp((y - alphaBar.AbsolutePosition.Y) / math.max(alphaBar.AbsoluteSize.Y, 1), 0, 1)
			update()
		end)
	end
	hex.FocusLost:Connect(function()
		local r, g, bl = hex.Text:match("#?(%x%x)(%x%x)(%x%x)")
		if r then
			el:Set(C(tonumber(r, 16), tonumber(g, 16), tonumber(bl, 16)))
		else
			update(true)
		end
	end)
	if rainbowBtn then
		rainbowBtn.MouseButton1Click:Connect(function()
			el:SetRainbow(not el._rainbow)
		end)
	end

	-- плавное раскрытие/закрытие
	preview.MouseButton1Click:Connect(function()
		open = not open
		if open then
			body.Size = UDim2.new(1, 0, 0, 0)
			body.Visible = true
			tween(body, { Size = UDim2.new(1, 0, 0, panelH + 2) }, 0.24, Enum.EasingStyle.Quart)
		else
			tween(body, { Size = UDim2.new(1, 0, 0, 0) }, 0.18, Enum.EasingStyle.Quart).Completed:Connect(function()
				if not open then
					body.Visible = false
				end
			end)
		end
	end)

	update(true)
	return register(el, cfg, "ColorPicker")
end
Container.Color = Container.ColorPicker

return true
