-- Slider, RangeSlider, Progress
local Env = import("Core/Env")
local Util = import("Core/Util")
local E = import("Core/Element")
local Container = import("Core/Container")

local new, tween, corner = Util.new, Util.tween, Util.corner
local parse, snap = Util.parse, Util.snap
local buildRow, newElement, register, changed = E.buildRow, E.newElement, E.register, E.changed

local function sliderParts(p, areaHeight)
	local area = new("TextButton", { Size = UDim2.new(1, 0, 0, areaHeight), LayoutOrder = 3, Parent = p.content })
	local track = new("Frame", {
		Size = UDim2.new(1, 0, 0, 6), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
		Theme = { BackgroundColor3 = "Stroke" }, Parent = area,
	})
	corner(track, 3)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), Theme = { BackgroundColor3 = "Accent" }, Parent = track })
	corner(fill, 3)
	return area, track, fill
end

local function makeKnob(track)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = track,
	})
	corner(knob, 6)
	return knob
end

local function valueBox(p, width)
	return new("TextBox", {
		Size = UDim2.fromOffset(width, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Right, TextSize = 12, Theme = { TextColor3 = "SubText" }, Parent = p.header,
	})
end

-- Slider: Min / Max / Default / Increment / Suffix
function Container:Slider(a, b, c, d, e)
	local cfg = parse(a, { "Min", "Max", "Default", "Callback" }, b, c, d, e)
	local p = buildRow(self, cfg, 80)
	local el = newElement(self, p, cfg)
	local min, max = cfg.Min or 0, cfg.Max or 100
	local inc = cfg.Increment or cfg.Step or 1
	local suffix = cfg.Suffix or ""
	local value = min

	local box = valueBox(p, 76)
	local area, track, fill = sliderParts(p, Env.IsMobile and 24 or 16)
	local knob = makeKnob(track)

	local function render()
		local alpha = (max == min) and 0 or (value - min) / (max - min)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		box.Text = tostring(value) .. suffix
	end

	function el:Set(v, silent)
		v = tonumber(v)
		if not v then
			return
		end
		local nv = snap(v, min, max, inc)
		local diff = nv ~= value
		value = nv
		render()
		changed(self, silent or not diff, value)
	end
	function el:Get()
		return value
	end
	function el:SetRange(newMin, newMax)
		min, max = newMin, newMax
		el:Set(value, true)
	end

	-- Commit = true: callback вызывается один раз при отпускании ползунка (удобно для тяжёлых действий, например масштаба UI)
	local pending = false
	E.dragArea(self, el, area, function(x)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local v = min + alpha * (max - min)
		if cfg.Commit then
			local before = value
			el:Set(v, true)
			if value ~= before then
				pending = true
			end
		else
			el:Set(v)
		end
	end, function()
		if pending then
			pending = false
			changed(el, false, value)
		end
	end)
	box.FocusLost:Connect(function()
		local n = tonumber(box.Text:match("-?%d+%.?%d*"))
		if n then
			el:Set(n)
		else
			render()
		end
	end)

	el:Set(cfg.Default or min, true)
	return register(el, cfg, "Slider")
end

-- RangeSlider: диапазон из двух значений. Default = { от, до }, Get() -> { от, до }
function Container:RangeSlider(a, b, c, d, e)
	local cfg = parse(a, { "Min", "Max", "Default", "Callback" }, b, c, d, e)
	local p = buildRow(self, cfg, 110)
	local el = newElement(self, p, cfg)
	local min, max = cfg.Min or 0, cfg.Max or 100
	local inc = cfg.Increment or cfg.Step or 1
	local suffix = cfg.Suffix or ""
	local lo, hi = min, max

	local box = new("TextLabel", {
		Size = UDim2.fromOffset(106, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Right, TextSize = 12, Theme = { TextColor3 = "SubText" }, Parent = p.header,
	})
	local area, track, fill = sliderParts(p, Env.IsMobile and 24 or 16)
	local knobLo, knobHi = makeKnob(track), makeKnob(track)

	local function render()
		local span = (max == min) and 1 or (max - min)
		local aLo, aHi = (lo - min) / span, (hi - min) / span
		fill.Position = UDim2.fromScale(aLo, 0)
		fill.Size = UDim2.fromScale(aHi - aLo, 1)
		knobLo.Position = UDim2.fromScale(aLo, 0.5)
		knobHi.Position = UDim2.fromScale(aHi, 0.5)
		box.Text = tostring(lo) .. suffix .. "  -  " .. tostring(hi) .. suffix
	end

	function el:Set(v, silent)
		if type(v) ~= "table" then
			return
		end
		local nl = snap(tonumber(v[1]) or min, min, max, inc)
		local nh = snap(tonumber(v[2]) or max, min, max, inc)
		if nl > nh then
			nl, nh = nh, nl
		end
		local diff = nl ~= lo or nh ~= hi
		lo, hi = nl, nh
		render()
		changed(self, silent or not diff, lo, hi)
	end
	function el:Get()
		return { lo, hi }
	end

	-- свой drag: при нажатии выбираем ближайший ползунок
	local active -- "lo" | "hi"
	local scroller = self.Scroller
	local function move(x)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local v = min + alpha * (max - min)
		if not active then
			active = math.abs(v - lo) <= math.abs(v - hi) and "lo" or "hi"
			if lo == hi then
				active = v < lo and "lo" or "hi"
			end
		end
		if active == "lo" then
			el:Set({ math.min(v, hi), hi })
		else
			el:Set({ lo, math.max(v, lo) })
		end
	end
	area.InputBegan:Connect(function(i)
		if Util.isPress(i) then
			active = nil
			if scroller then
				scroller.ScrollingEnabled = false
			end
			move(i.Position.X)
			local conn
			conn = i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					active = "done"
					if scroller then
						scroller.ScrollingEnabled = true
					end
					conn:Disconnect()
				end
			end)
		end
	end)
	E.connect(self, el, Env.UserInputService.InputChanged, function(i)
		if active and active ~= "done" and Util.isMove(i) then
			move(i.Position.X)
		end
	end)

	local def = cfg.Default
	if type(def) ~= "table" then
		def = { min, max }
	end
	el:Set(def, true)
	return register(el, cfg, "RangeSlider")
end

-- Progress: полоса прогресса 0-100, управляется из кода
function Container:Progress(a, b)
	local cfg = parse(a, { "Default" }, b)
	local p = buildRow(self, cfg, 64)
	local el = newElement(self, p, cfg)
	local value = 0
	local pct = new("TextLabel", {
		Size = UDim2.fromOffset(56, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Right, TextSize = 12, Theme = { TextColor3 = "SubText" }, Parent = p.header,
	})
	local bar = new("Frame", {
		Size = UDim2.new(1, 0, 0, 6), LayoutOrder = 3, Theme = { BackgroundColor3 = "Stroke" }, Parent = p.content,
	})
	corner(bar, 3)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), Theme = { BackgroundColor3 = "Accent" }, Parent = bar })
	corner(fill, 3)

	function el:Set(x, silent)
		value = math.clamp(tonumber(x) or 0, 0, 100)
		tween(fill, { Size = UDim2.fromScale(value / 100, 1) }, 0.2)
		pct.Text = math.floor(value + 0.5) .. "%"
		changed(self, silent, value)
	end
	function el:Get()
		return value
	end
	el:Set(cfg.Default or 0, true)
	return register(el, cfg, "Progress")
end

return true
