-- Key System. Проверка по списку Keys или своей функцией Validate(key) -> boolean, сообщение.
-- ВАЖНО: ключи в клиентском скрипте может прочитать кто угодно. Для реальной защиты проверяй ключ на своём сервере
-- через Validate (например, HttpGet на твой API).
local Env = import("Core/Env")
local Util = import("Core/Util")
local ThemeM = import("Core/Theme")
local Gui = import("Core/Gui")
local Shapes = import("Core/Shapes")

local new, tween, corner, stroke, padding = Util.new, Util.tween, Util.corner, Util.stroke, Util.padding

local KeySystem = {}

-- cfg: { Title, Subtitle, Note, Keys, Validate, SaveKey, Folder, FileName, KeyLink, MaxAttempts, OnFail }
-- возвращает true (ключ верный) или false (закрыли окно / кончились попытки)
function KeySystem.run(cfg)
	cfg = cfg or {}
	local folder = cfg.Folder or "Majestic"
	local file = folder .. "/" .. (cfg.FileName or "key.txt")
	local saveKey = cfg.SaveKey ~= false

	local function check(key)
		key = Util.trim(key)
		if key == "" then
			return false, "Enter a key"
		end
		if cfg.Validate then
			local ok, res, msg = pcall(cfg.Validate, key)
			if not ok then
				return false, "Key validation error"
			end
			if res == true then
				return true
			end
			return false, type(msg) == "string" and msg or "Invalid key"
		end
		for _, k in ipairs(cfg.Keys or {}) do
			if key == tostring(k) then
				return true
			end
		end
		return false, "Invalid key"
	end

	-- сохранённый ключ
	if saveKey and Env.fs.isfile and Env.fs.read and Env.fs.isfile(file) then
		local ok, saved = pcall(Env.fs.read, file)
		if ok and type(saved) == "string" and saved ~= "" and check(saved) then
			return true
		end
	end

	local modal = Gui.modal(370, nil, { zindex = 300, dim = 0.35 })
	local inner, card = modal.inner, modal.card

	new("TextLabel", {
		Size = UDim2.new(1, -30, 0, 22), Text = tostring(cfg.Title or "Key System"), Font = Enum.Font.GothamBold,
		TextSize = 17, LayoutOrder = 1, Theme = { TextColor3 = "Text" }, Parent = inner,
	})
	local sub = cfg.Subtitle or cfg.Note
	if sub then
		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = tostring(sub), TextWrapped = true,
			TextSize = 12, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2,
			Theme = { TextColor3 = "SubText" }, Parent = inner,
		})
	end
	local box = new("TextBox", {
		Size = UDim2.new(1, 0, 0, 34), PlaceholderText = "Enter key...", TextSize = 13, BackgroundTransparency = 0,
		ClipsDescendants = true, LayoutOrder = 3,
		Theme = { BackgroundColor3 = "Element", TextColor3 = "Text", PlaceholderColor3 = "SubText" }, Parent = inner,
	})
	corner(box, 7)
	local boxStroke = stroke(box)
	padding(box, 0, 0, 12, 12)
	local status = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), Text = "", TextSize = 12, LayoutOrder = 4, Theme = { TextColor3 = "SubText" }, Parent = inner,
	})
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = 5, Parent = inner })
	Util.list(row, 8, { FillDirection = Enum.FillDirection.Horizontal })

	local function button(text, order, primary)
		local props = {
			Size = UDim2.new(0.5, -4, 1, 0), BackgroundTransparency = 0, Text = text, Font = Enum.Font.GothamBold,
			TextSize = 12, LayoutOrder = order, Parent = row,
			Theme = { BackgroundColor3 = primary and "Accent" or "Element" },
		}
		if primary then
			props.TextColor3 = Color3.new(1, 1, 1)
		else
			props.Theme.TextColor3 = "Text"
		end
		local b = new("TextButton", props)
		corner(b, 7)
		return b
	end
	local checkBtn = button("Check Key", 1, true)
	local getBtn = cfg.KeyLink and button("Get Key", 2, false) or nil
	if not getBtn then
		checkBtn.Size = UDim2.new(1, 0, 1, 0)
	end

	local closeBtn = new("TextButton", {
		Size = UDim2.fromOffset(26, 26), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10),
		ZIndex = 5, Parent = card,
	})
	local closeGlyph = Shapes.close(closeBtn, 12, "SubText")
	closeGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
	closeGlyph.Position = UDim2.fromScale(0.5, 0.5)

	local result, busy, attempts = nil, false, 0
	local function setStatus(text, key)
		status.Text = text
		status.TextColor3 = ThemeM.Colors[key]
	end
	local function shake()
		for _, dx in ipairs({ 9, -9, 6, -6, 0 }) do
			tween(card, { Position = UDim2.new(0.5, dx, 0.5, 0) }, 0.05)
			task.wait(0.05)
		end
	end
	local function submit()
		if busy or result ~= nil then
			return
		end
		busy = true
		setStatus("Checking...", "SubText")
		local ok, msg = check(box.Text)
		if ok then
			setStatus("Key accepted", "Success")
			if saveKey and Env.fsReady() then
				Env.ensureFolder(folder)
				pcall(Env.fs.write, file, Util.trim(box.Text))
			end
			task.wait(0.4)
			result = true
		else
			attempts += 1
			setStatus(msg or "Invalid key", "Danger")
			tween(boxStroke, { Color = ThemeM.Colors.Danger }, 0.15)
			shake()
			tween(boxStroke, { Color = ThemeM.Colors.Stroke }, 0.4)
			if cfg.MaxAttempts and attempts >= cfg.MaxAttempts then
				result = false
			end
		end
		busy = false
	end

	checkBtn.MouseButton1Click:Connect(submit)
	box.FocusLost:Connect(function(enter)
		if enter then
			submit()
		end
	end)
	if getBtn then
		getBtn.MouseButton1Click:Connect(function()
			local copied = Env.clipboard(cfg.KeyLink)
			setStatus(copied and "Link copied to clipboard" or tostring(cfg.KeyLink), "SubText")
		end)
	end
	closeBtn.MouseButton1Click:Connect(function()
		result = false
	end)

	while result == nil do
		task.wait(0.1)
	end
	modal.close()
	if result == false and type(cfg.OnFail) == "function" then
		Util.fire(cfg.OnFail)
	end
	return result
end

return KeySystem
