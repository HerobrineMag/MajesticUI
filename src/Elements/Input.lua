-- Input (в т.ч. многострочный) и Keybind
local Env = import("Core/Env")
local Util = import("Core/Util")
local ThemeM = import("Core/Theme")
local E = import("Core/Element")
local Container = import("Core/Container")

local new, tween, corner, stroke, padding = Util.new, Util.tween, Util.corner, Util.stroke, Util.padding
local parse, fire = Util.parse, Util.fire
local buildRow, newElement, register, changed = E.buildRow, E.newElement, E.register, E.changed

-- Input: Placeholder, Numeric, Live (callback на каждый символ), Multiline + Height
function Container:Input(a, b, c)
	local cfg = parse(a, { "Default", "Callback" }, b, c)
	local multiline = cfg.Multiline == true
	local p = buildRow(self, cfg, multiline and 0 or 170)
	local el = newElement(self, p, cfg)

	local props = {
		Text = tostring(cfg.Default or ""), PlaceholderText = cfg.Placeholder or "Type here...", TextSize = 12,
		BackgroundTransparency = 0, ClipsDescendants = true,
		Theme = { BackgroundColor3 = "Background", TextColor3 = "Text", PlaceholderColor3 = "SubText" },
	}
	if multiline then
		props.Size = UDim2.new(1, 0, 0, cfg.Height or 72)
		props.LayoutOrder = 3
		props.MultiLine = true
		props.TextWrapped = true
		props.TextYAlignment = Enum.TextYAlignment.Top
		props.Parent = p.content
	else
		props.Size = UDim2.fromOffset(160, 24)
		props.AnchorPoint = Vector2.new(1, 0.5)
		props.Position = UDim2.new(1, 0, 0.5, 0)
		props.Parent = p.header
	end
	local box = new("TextBox", props)
	corner(box, 5)
	local s = stroke(box)
	padding(box, multiline and 6 or 0, multiline and 6 or 0, 8, 8)
	local value = box.Text

	local function clean()
		if cfg.Numeric then
			local cleaned = box.Text:gsub("[^%d%.%-]", "")
			if cleaned ~= box.Text then
				box.Text = cleaned
			end
		end
	end

	box.Focused:Connect(function()
		tween(s, { Color = ThemeM.Colors.Accent }, 0.12)
	end)
	box.FocusLost:Connect(function()
		tween(s, { Color = ThemeM.Colors.Stroke }, 0.12)
		clean()
		value = box.Text
		changed(el, false, el:Get())
	end)
	if cfg.Live then
		box:GetPropertyChangedSignal("Text"):Connect(function()
			clean()
			value = box.Text
			changed(el, false, el:Get())
		end)
	end

	function el:Set(v, silent)
		box.Text = tostring(v or "")
		value = box.Text
		changed(self, silent, self:Get())
	end
	function el:Get()
		if cfg.Numeric then
			return tonumber(value) or 0
		end
		return value
	end
	function el:Focus()
		box:CaptureFocus()
	end
	return register(el, cfg, "Input")
end
Container.TextBox = Container.Input

-- Keybind: Mode = "Press" | "Toggle" | "Hold"; Callback — на нажатие, OnChange — на смену бинда
function Container:Keybind(a, b, c)
	local cfg = parse(a, { "Default", "Callback" }, b, c)
	local p = buildRow(self, cfg, 120)
	local el = newElement(self, p, cfg)
	local pressCb = cfg.Callback
	el._callback = cfg.OnChange
	local mode = cfg.Mode or "Press"
	local key, state, listening = nil, false, false

	local btn = new("TextButton", {
		Size = UDim2.fromOffset(110, 24), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		BackgroundTransparency = 0, TextSize = 12,
		Theme = { BackgroundColor3 = "Background", TextColor3 = "SubText" }, Parent = p.header,
	})
	corner(btn, 5)
	stroke(btn)

	function el:Set(v, silent)
		if type(v) == "string" then
			local ok, k = pcall(function()
				return Enum.KeyCode[v]
			end)
			v = ok and k or nil
		end
		key = v
		btn.Text = key and key.Name or "None"
		changed(self, silent, key)
	end
	function el:Get()
		return key
	end

	btn.MouseButton1Click:Connect(function()
		listening = true
		btn.Text = "..."
	end)

	E.connect(self, el, Env.UserInputService.InputBegan, function(i, gp)
		if listening then
			if i.UserInputType == Enum.UserInputType.Keyboard then
				listening = false
				if i.KeyCode == Enum.KeyCode.Escape or i.KeyCode == Enum.KeyCode.Backspace then
					el:Set(nil)
				else
					el:Set(i.KeyCode)
				end
			end
			return
		end
		if gp or not key or i.KeyCode ~= key then
			return
		end
		if mode == "Toggle" then
			state = not state
			fire(pressCb, state)
		elseif mode == "Hold" then
			fire(pressCb, true)
		else
			fire(pressCb)
		end
	end)
	E.connect(self, el, Env.UserInputService.InputEnded, function(i)
		if mode == "Hold" and key and i.KeyCode == key then
			fire(pressCb, false)
		end
	end)

	el:Set(cfg.Default, true)
	return register(el, cfg, "Keybind")
end
Container.Bind = Container.Keybind

return true
