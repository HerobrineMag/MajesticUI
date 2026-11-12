-- Корневой ScreenGui, тултипы, модальные карточки
local Env = import("Core/Env")
local ThemeM = import("Core/Theme")
local Util = import("Core/Util")

local new, tween, corner, stroke, padding = Util.new, Util.tween, Util.corner, Util.stroke, Util.padding

local Gui = { _gui = nil, _tip = nil, _conns = {} }

function Gui.get()
	if Gui._gui and Gui._gui.Parent then
		return Gui._gui
	end
	pcall(function()
		local env = getgenv and getgenv() or _G
		if env.__MajesticGui then
			env.__MajesticGui:Destroy()
		end
	end)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Majestic"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 999
	pcall(function()
		if syn and syn.protect_gui then
			syn.protect_gui(gui)
		end
	end)
	local parent
	pcall(function()
		parent = gethui and gethui()
	end)
	parent = parent or Env.CoreGui
	local ok = pcall(function()
		gui.Parent = parent
	end)
	if not ok or not gui.Parent then
		gui.Parent = Env.LocalPlayer:WaitForChild("PlayerGui")
	end
	pcall(function()
		(getgenv and getgenv() or _G).__MajesticGui = gui
	end)
	Gui._gui = gui
	ThemeM.Root = gui
	return gui
end

function Gui.destroy()
	for _, c in ipairs(Gui._conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(Gui._conns)
	if Gui._gui then
		Gui._gui:Destroy()
		Gui._gui = nil
	end
	Gui._tip = nil
end

----------------------------------------------------------------------
-- Тултипы
----------------------------------------------------------------------
local function ensureTip()
	if Gui._tip then
		return Gui._tip
	end
	local gui = Gui.get()
	local frame = new("Frame", {
		Name = "Tooltip", Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY,
		Visible = false, ZIndex = 900, Theme = { BackgroundColor3 = "Topbar" }, Parent = gui,
	})
	corner(frame, 6)
	stroke(frame)
	padding(frame, 6, 6, 9, 9)
	local label = new("TextLabel", {
		Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, TextWrapped = true,
		TextSize = 12, ZIndex = 901, Theme = { TextColor3 = "Text" }, Parent = frame,
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(260, 1000), Parent = label })
	table.insert(Gui._conns, Env.UserInputService.InputChanged:Connect(function(i)
		if frame.Visible and i.UserInputType == Enum.UserInputType.MouseMovement then
			local cam = workspace.CurrentCamera
			local maxX = cam and cam.ViewportSize.X - frame.AbsoluteSize.X - 6 or 9999
			frame.Position = UDim2.fromOffset(math.min(i.Position.X + 14, maxX), i.Position.Y + 18)
		end
	end))
	Gui._tip = { frame = frame, label = label }
	return Gui._tip
end

-- ref = { text = "..." }; текст можно менять после создания
function Gui.tooltip(inst, ref)
	local token = 0
	inst.MouseEnter:Connect(function()
		token += 1
		local my = token
		task.delay(0.4, function()
			if my ~= token or not ref.text or ref.text == "" then
				return
			end
			local tip = ensureTip()
			tip.label.Text = ref.text
			local m = Env.UserInputService:GetMouseLocation() - Env.GuiService:GetGuiInset()
			tip.frame.Position = UDim2.fromOffset(m.X + 14, m.Y + 18)
			tip.frame.Visible = true
		end)
	end)
	inst.MouseLeave:Connect(function()
		token += 1
		if Gui._tip then
			Gui._tip.frame.Visible = false
		end
	end)
end

----------------------------------------------------------------------
-- Модальная карточка по центру (загрузка, ключ, диалог)
----------------------------------------------------------------------
function Gui.modal(width, parent, opts)
	opts = opts or {}
	parent = parent or Gui.get()
	local dim = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
		Active = true, ZIndex = opts.zindex or 100, Parent = parent,
	})
	tween(dim, { BackgroundTransparency = opts.dim or 0.4 }, 0.2)
	local card = new("Frame", {
		Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Theme = { BackgroundColor3 = "Topbar" }, Parent = dim,
	})
	corner(card, 12)
	stroke(card)
	local scale = new("UIScale", { Scale = 0.9, Parent = card })
	tween(scale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
	local inner = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = card,
	})
	padding(inner, 18, 18, 18, 18)
	Util.list(inner, 10)

	local modal = { dim = dim, card = card, inner = inner, scale = scale, closed = false }
	function modal.close(instant)
		if modal.closed then
			return
		end
		modal.closed = true
		if instant then
			dim:Destroy()
			return
		end
		tween(dim, { BackgroundTransparency = 1 }, 0.18)
		tween(scale, { Scale = 0.92 }, 0.18)
		task.delay(0.2, function()
			dim:Destroy()
		end)
	end
	return modal
end

return Gui
