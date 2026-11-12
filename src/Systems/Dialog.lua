-- Window:Dialog({ Title, Content, Buttons = { {"Да", fn}, {"Отмена"} } })
local Util = import("Core/Util")
local Gui = import("Core/Gui")
local Window = import("Core/Window")

local new, corner, padding = Util.new, Util.corner, Util.padding

function Window:Dialog(cfg)
	cfg = type(cfg) == "table" and cfg or { Title = tostring(cfg) }
	local modal = Gui.modal(310, self._main, { zindex = 100, dim = 0.45 })
	local inner = modal.inner

	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20), Text = tostring(cfg.Title or "Majestic"), Font = Enum.Font.GothamBold,
		TextSize = 15, LayoutOrder = 1, Theme = { TextColor3 = "Text" }, Parent = inner,
	})
	if cfg.Content then
		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = tostring(cfg.Content),
			TextWrapped = true, TextSize = 12, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2,
			Theme = { TextColor3 = "SubText" }, Parent = inner,
		})
	end
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 3, Parent = inner,
	})
	Util.list(row, 8, {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	for idx, bcfg in ipairs(cfg.Buttons or { { "OK" } }) do
		local label = type(bcfg) == "table" and (bcfg.Text or bcfg[1]) or tostring(bcfg)
		local cb = type(bcfg) == "table" and (bcfg.Callback or bcfg[2]) or nil
		local primary = idx == 1
		local props = {
			Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0,
			Text = tostring(label), TextSize = 12, Font = Enum.Font.GothamBold, LayoutOrder = idx, Parent = row,
			Theme = { BackgroundColor3 = primary and "Accent" or "Element" },
		}
		if primary then
			props.TextColor3 = Color3.new(1, 1, 1)
		else
			props.Theme.TextColor3 = "Text"
		end
		local b = new("TextButton", props)
		corner(b, 6)
		padding(b, 0, 0, 14, 14)
		b.MouseButton1Click:Connect(function()
			modal.close()
			Util.fire(cb)
		end)
	end
	return modal
end

return true
