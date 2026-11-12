-- Загрузочный экран: логотип, прогресс-бар и шаги. Блокирует поток на время анимации.
local Env = import("Core/Env")
local Util = import("Core/Util")
local Gui = import("Core/Gui")
local Icons = import("Core/Icons")
local Shapes = import("Core/Shapes")

local new, tween, corner = Util.new, Util.tween, Util.corner

local Loading = {}

local defaultSteps = { "Initializing", "Loading modules", "Applying theme", "Building interface" }

-- cfg: { Title, Subtitle, Icon, Steps = {...}, Time = 1.8 }
function Loading.run(cfg)
	cfg = cfg or {}
	local steps = cfg.Steps or defaultSteps
	local total = cfg.Time or 1.8
	local modal = Gui.modal(340, nil, { zindex = 200, dim = 0.2 })
	local inner = modal.inner

	local logoHolder = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 1, Parent = inner })
	local logo = cfg.Icon and Icons.create(logoHolder, cfg.Icon, 34, "Accent", cfg.IconUrl)
	if not logo then
		logo = Shapes.diamond(logoHolder, 34, "Accent")
	end
	do
		logo.AnchorPoint = Vector2.new(0.5, 0.5)
		logo.Position = UDim2.fromScale(0.5, 0.5)
		-- бесконечное вращение
		Env.TweenService:Create(
			logo,
			TweenInfo.new(1.6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
			{ Rotation = 360 }
		):Play()
	end
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22), Text = tostring(cfg.Title or "Majestic"), Font = Enum.Font.GothamBold, TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Theme = { TextColor3 = "Text" }, Parent = inner,
	})
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), Text = tostring(cfg.Subtitle or ""), TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, Theme = { TextColor3 = "SubText" }, Parent = inner,
	})
	local bar = new("Frame", {
		Size = UDim2.new(1, 0, 0, 6), LayoutOrder = 4, Theme = { BackgroundColor3 = "Stroke" }, Parent = inner,
	})
	corner(bar, 3)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), Theme = { BackgroundColor3 = "Accent" }, Parent = bar })
	corner(fill, 3)
	local status = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), Text = "", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 5, Theme = { TextColor3 = "SubText" }, Parent = inner,
	})

	local per = total / #steps
	for i, text in ipairs(steps) do
		status.Text = text .. "..."
		tween(fill, { Size = UDim2.fromScale(i / #steps, 1) }, per, Enum.EasingStyle.Quad)
		task.wait(per)
	end
	modal.close()
	task.wait(0.25)
end

return Loading
