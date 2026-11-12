-- Сценарий проверки: выполняется после mock.lua и бандла (см. run.sh)
local failures, checks, warnings = 0, 0, 0
local realWarn = warn
warn = function(...)
	warnings += 1
	realWarn("WARN:", ...)
end

local function check(cond, msg)
	checks += 1
	if not cond then
		failures += 1
		print("FAIL: " .. msg)
	end
end
local function noerr(label, fn, ...)
	local ok, err = pcall(fn, ...)
	checks += 1
	if not ok then
		failures += 1
		print("ERROR in " .. label .. ": " .. tostring(err))
	end
	return ok
end
local function near(a, b)
	return math.abs(a - b) < 1e-6
end

local states = Mock.states
local function walk(root, fn)
	fn(root)
	for _, c in ipairs(states[root].children) do
		walk(c, fn)
	end
end
local function sig(inst, name)
	return states[inst].signals[name]
end
local function fireSig(inst, name, ...)
	local s = sig(inst, name)
	if s then
		s:Fire(...)
	end
end
local function fakeInput(kind, x, y, state)
	return {
		UserInputType = Enum.UserInputType[kind], Position = Vector3.new(x, y, 0),
		UserInputState = Enum.UserInputState[state or "Begin"], KeyCode = Enum.KeyCode.Unknown,
		Changed = Mock.Signal(),
	}
end
local function findText(root, text, class)
	local found
	walk(root, function(i)
		if not found and (not class or i.ClassName == class) and i.Text == text then
			found = i
		end
	end)
	return found
end

local function guiRoot()
	return Mock.coreGui:FindFirstChild("Majestic")
end

----------------------------------------------------------------------
local function runAll(Majestic, label)
	print("=== " .. label .. " ===")
	local calls = {}
	local win = Majestic:Window({
		Title = "Smoke", Subtitle = "test", Icon = "home", Theme = "Ocean", LoadingEnabled = true,
		LoadingTime = 0.1, Folder = "SmokeHub",
	})
	check(win ~= nil, "Window created")

	-- вкладки
	local home = win:HomeTab({
		Welcome = "Hi", Buttons = { { Name = "Discord", Desc = "link", Link = "https://x", Icon = "home" } },
		Changelog = { { Title = "2.0", Text = "everything" } },
	})
	win:TabSection("Features")
	local main = win:Tab("Main", "home")
	win:TabDivider()
	local vis = win:Tab({ Name = "Visuals", Icon = "eye" })
	local emoji = win:Tab("Emoji", "🔥")
	check(#win.Tabs == 4, "4 tabs, got " .. #win.Tabs)
	check(win.ActiveTab == home, "first tab (Home) active")

	-- элементы
	main:Section("Basics")
	main:Divider()
	main:Label("Plain label")
	main:Label({ Name = "Warning label", Desc = "careful", Type = "Warning" })
	main:Paragraph("Title", "Long text that wraps")
	main:Image({ Image = "rbxassetid://1", Height = 80 })
	local btn = main:Button({ Name = "Run", Desc = "d", Icon = "settings", Callback = function() calls.btn = (calls.btn or 0) + 1 end })
	local tg = main:Toggle({
		Name = "Auto Farm", Desc = "desc", Tooltip = "tip", Default = true, Flag = "AutoFarm", Icon = "eye", Fire = true,
		Callback = function(v) calls.toggle = v end,
	})
	check(calls.toggle == true, "Fire=true called toggle callback on create")
	local sl = main:Slider({
		Name = "Speed", Min = 0, Max = 100, Default = 16, Flag = "Speed", Suffix = " st",
		Callback = function(v) calls.slider = v end,
	})
	local fl = main:Slider({ Name = "Smooth", Min = 0, Max = 1, Default = 0.5, Increment = 0.05, Flag = "Smooth" })
	local rg = main:RangeSlider({ Name = "Range", Min = 0, Max = 100, Default = { 25, 75 }, Flag = "Range", Callback = function(lo, hi) calls.range = { lo, hi } end })
	local dd = main:Dropdown({ Name = "Mode", Options = { "A", "B", "C" }, Default = "B", Flag = "Mode", Callback = function(v) calls.dd = v end })
	local md = main:Dropdown({
		Name = "Targets", Options = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }, Default = { "2", "4" }, Multi = true, Flag = "Targets",
	})
	local inp = main:Input({ Name = "Nick", Default = "abc", Flag = "Nick", Callback = function(v) calls.input = v end })
	local num = main:Input({ Name = "Delay", Numeric = true, Default = "5", Flag = "Delay" })
	local multi = main:Input({ Name = "Notes", Multiline = true, Height = 60 })
	local kb = main:Keybind({ Name = "Fly", Default = Enum.KeyCode.F, Mode = "Toggle", Flag = "Fly", Callback = function(s) calls.kb = s end })
	local cp = main:ColorPicker({ Name = "Color", Default = Color3.fromRGB(255, 80, 80), Alpha = true, Rainbow = true, Flag = "Color", Callback = function(c, a) calls.color = { c, a } end })
	local prog = main:Progress("Load", 10)

	-- значения
	tg:Set(false)
	check(tg:Get() == false and calls.toggle == false, "toggle set/callback")
	tg:Set(true, true)
	check(tg:Get() == true, "toggle silent set")
	sl:Set(250)
	check(sl:Get() == 100 and calls.slider == 100, "slider clamps to max")
	sl:Set(33.4)
	check(sl:Get() == 33, "slider snaps to increment")
	fl:Set(0.123)
	check(near(fl:Get(), 0.1), "decimal slider snap, got " .. tostring(fl:Get()))
	rg:Set({ 70, 20 })
	local r = rg:Get()
	check(r[1] == 20 and r[2] == 70, "range sorted")
	check(calls.range and calls.range[1] == 20 and calls.range[2] == 70, "range callback gets lo, hi")
	dd:Set("C")
	check(dd:Get() == "C" and calls.dd == "C", "dropdown set")
	dd:Set("zzz")
	check(dd:Get() == nil, "dropdown ignores unknown option")
	md:Set({ "9", "1" })
	local mv = md:Get()
	check(#mv == 2 and mv[1] == "1" and mv[2] == "9", "multi dropdown order follows options")
	dd:Refresh({ "X", "Y" })
	check(#dd:GetOptions() == 2, "dropdown refresh")
	inp:Set("hello")
	check(inp:Get() == "hello" and calls.input == "hello", "input set")
	num:Set("12.5")
	check(num:Get() == 12.5, "numeric input returns number")
	kb:Set("G")
	check(kb:Get().Name == "G", "keybind set by name")
	cp:Set(Color3.fromRGB(0, 255, 0))
	check(near(cp:Get().G, 1), "colorpicker set")
	cp:SetAlpha(0.5)
	check(near(cp:GetAlpha(), 0.5), "colorpicker alpha")
	cp:SetRainbow(true)
	cp:SetRainbow(false)
	prog:Set(150)
	check(prog:Get() == 100, "progress clamps")

	-- общие методы элементов
	tg:SetTitle("Renamed")
	check(tg._title.Text == "Renamed", "SetTitle")
	tg:SetDesc("new desc")
	check(tg._desc.Text == "new desc" and tg._desc.Visible == true, "SetDesc")
	tg:SetLocked(true)
	check(tg._lock ~= nil, "locked")
	tg:SetLocked(false)
	check(tg._lock == nil, "unlocked")
	tg:SetVisible(false)
	check(tg._row.Visible == false, "SetVisible false")
	tg:SetVisible(true)
	tg:SetTooltip("other")
	check(Majestic.Flags.AutoFarm == true, "Flags mirror values")
	check(Majestic.Options.Speed == sl, "Options registry")

	-- таблица
	local tbl = main:Table({
		Name = "Players", Columns = { "Name", { Name = "Ping", Width = 0.2 } }, Rows = { { "bob", 50 }, { "al", 10 } },
		Search = true, Callback = function(i, row) calls.tbl = row end,
	})
	tbl:AddRow({ "zed", 5 })
	check(#tbl:GetRows() == 3, "table rows")
	tbl:Sort(2, true)
	tbl:Select(1)
	check(tbl:Get() ~= nil, "table selection")
	tbl:RemoveRow(1)
	check(#tbl:GetRows() == 2, "table remove")
	tbl:SetRows({ { "x", 1 } })
	tbl:Clear()
	check(#tbl:GetRows() == 0, "table clear")
	tbl:SetRows({ { "n", 3 }, { "m", 1 } })

	-- группы и колонки
	local g = vis:Group({ Name = "Group", Icon = "save", Collapsible = true })
	local gt = g:Toggle("In group", false)
	g:Slider({ Name = "Group slider", Min = 0, Max = 5, Default = 1 })
	g:Collapse()
	check(g.Collapsed == true and g._body.Visible == false, "group collapse")
	g:Expand()
	check(g._body.Visible == true, "group expand")
	local left, right = vis:Columns(2)
	left:Button({ Name = "Left", Callback = function() end })
	local nested = right:Group({ Name = "Nested" })
	nested:Dropdown({ Name = "N", Options = { "a", "b" } })
	check(gt.Type == "Toggle", "element inside group registered as Toggle")
	emoji:Label("emoji tab ok")

	-- Dropdown: ввод в поле работает как поиск, Enter выбирает первый подходящий пункт
	local ddt = main:Dropdown({ Name = "Typed", Options = { "Alpha", "Beta", "Gamma" } })
	local ddBox
	walk(ddt._row, function(i)
		if i.ClassName == "TextBox" then
			ddBox = i
		end
	end)
	check(ddBox ~= nil, "dropdown has a typeable TextBox")
	fireSig(ddBox, "Focused")
	ddBox.Text = "gam"
	fireSig(ddBox, "FocusLost", true)
	check(ddt:Get() == "Gamma", "typed search + Enter selects first match, got " .. tostring(ddt:Get()))
	check(ddBox.Text == "Gamma", "field shows the selected value")
	md:Set({ "9", "1" })
	local mdBox
	walk(md._row, function(i)
		if i.ClassName == "TextBox" then
			mdBox = i
		end
	end)
	fireSig(mdBox, "Focused")
	mdBox.Text = "9"
	fireSig(mdBox, "FocusLost", true)
	check(#md:Get() == 1 and md:Get()[1] == "1", "multi dropdown: typed Enter toggles the first match")

	-- Slider с Commit: callback только при отпускании
	local cs = main:Slider({ Name = "Commit", Min = 0, Max = 100, Default = 0, Commit = true, Callback = function(v) calls.commit = v end })
	local csArea
	walk(cs._row, function(i)
		if i.ClassName == "TextButton" and not csArea and sig(i, "InputBegan") then
			csArea = i
		end
	end)
	local press = fakeInput("MouseButton1", 150, 10, "Begin")
	fireSig(csArea, "InputBegan", press, false)
	Mock.uis.InputChanged:Fire(fakeInput("MouseMovement", 300, 10, "Change"), false)
	check(calls.commit == nil, "commit slider is silent while dragging")
	press.UserInputState = Enum.UserInputState.End
	press.Changed:Fire()
	check(calls.commit == 100, "commit slider fires on release, got " .. tostring(calls.commit))

	-- Button: иконка вместо текста Click
	local b2 = main:Button({ Name = "Plain", Callback = function() end })
	local pillImage = false
	walk(b2._row, function(i)
		if i.ClassName == "ImageLabel" then
			pillImage = true
		end
	end)
	check(pillImage, "button shows a click icon")
	check(findText(b2._row, "Click", "TextLabel") == nil, "no 'Click' text on buttons")

	-- Иконки: Lucide и Material, выбор через IconUrl
	local I = Majestic.Icons
	local m1 = I.resolve("home", 18, "Material")
	check(m1 ~= nil and m1.Image ~= nil and m1.RectSize == nil, "Material icon is a single image")
	local l1 = I.resolve("home", 18, "Lucide")
	check(l1 ~= nil and l1.RectSize ~= nil, "Lucide icon is a sprite")
	check(I.resolve("material:settings", 18) ~= nil, "material: prefix")
	check(I.resolve("touch_app", 18, "Material") ~= nil, "Material snake_case name")
	check(I.resolve("🔥", 18).Text == "🔥", "emoji stays text")
	check(I.resolve("definitely-not-an-icon", 18) == nil, "unknown icon name gives nil")
	check(#I.names("Material") > 1000, "Material set is embedded")
	local matTab = win:Tab({ Name = "Mat", Icon = "settings", IconUrl = "Material" })
	check(matTab._icon ~= nil, "tab icon taken from IconUrl = Material")

	-- иконки: Lucide загрузился из мок-набора
	check(Mock.httpGetCalls >= 1, "icon set requested")

	-- конфиги
	Majestic.Options.Speed:Set(77)
	Majestic.Options.Mode:Set("X")
	cp:Set(Color3.fromRGB(10, 20, 30))
	kb:Set("H")
	rg:Set({ 10, 90 })
	local ok = win:SaveConfig("a")
	check(ok == true and Mock.files["SmokeHub/Configs/a.json"] ~= nil, "config saved")
	sl:Set(5)
	dd:Set("Y")
	cp:Set(Color3.fromRGB(200, 200, 200))
	kb:Set("J")
	rg:Set({ 40, 60 })
	check(win:LoadConfig("a") == true, "config loaded")
	check(sl:Get() == 77, "slider restored, got " .. tostring(sl:Get()))
	check(dd:Get() == "X", "dropdown restored")
	check(kb:Get().Name == "H", "keybind restored")
	check(rg:Get()[1] == 10 and rg:Get()[2] == 90, "range restored")
	check(math.abs(cp:Get().R * 255 - 10) < 1, "color restored")
	check(table.find(win:ListConfigs(), "a") ~= nil, "config listed")
	check(win:SetAutoload("a") == true and win:GetAutoload() == "a", "autoload set")
	check(win:LoadAutoConfig() == true, "autoload applies")
	check(select(1, win:LoadConfig("nope")) == false, "missing config reports false")
	check(win:DeleteConfig("a") == true and Mock.files["SmokeHub/Configs/a.json"] == nil, "config deleted")
	win:SetAutoload(nil)
	check(win:GetAutoload() == nil, "autoload cleared")

	-- менеджеры
	noerr("Settings tab", function()
		win:Settings()
	end)
	noerr("ConfigManager tab", function()
		win:ConfigManager()
	end)
	noerr("ThemeEditor tab", function()
		win:ThemeEditor()
	end)

	-- темы
	Majestic:RegisterTheme("T1", { Accent = Color3.fromRGB(1, 2, 3) })
	check(Majestic.Themes.T1 ~= nil and Majestic.Themes.T1.Background ~= nil, "RegisterTheme fills missing keys")
	check(Majestic:SetTheme("Rose") == true and Majestic:GetTheme() == "Rose", "SetTheme")
	check(Majestic:SetTheme("Nope") == false, "SetTheme unknown")
	Majestic:SetAccent(Color3.fromRGB(9, 9, 9))

	-- Liquid Glass
	local function dofCount()
		local n = 0
		for _, c in ipairs(Mock.lighting:GetChildren()) do
			if c.ClassName == "DepthOfFieldEffect" then
				n += 1
			end
		end
		return n
	end
	local function glassPart()
		for _, c in ipairs(workspace:GetChildren()) do
			if c.Name == "MajesticGlass" then
				return c
			end
		end
	end
	Majestic:SetTheme("Dark")
	check(near(win._main.BackgroundTransparency, 0), "opaque window outside glass mode")
	check(dofCount() == 0, "no blur effects outside glass mode")
	Majestic:SetGlass({ Color = Color3.fromRGB(10, 20, 40), Blur = 80, Transparency = 40 })
	check(Majestic:GetTheme() == "Liquid Glass", "SetGlass enables Liquid Glass")
	check(near(win._main.BackgroundTransparency, 0.4), "panel transparency follows the setting, got " .. tostring(win._main.BackgroundTransparency))
	check(near(sl._row.BackgroundTransparency, 0.4 + 0.6 * 0.42), "element rows are more see-through than the panel")
	check(dofCount() == 3, "blur 80 -> 3 effects, got " .. dofCount())
	local gp = glassPart()
	check(gp ~= nil and near(gp.Transparency, 0.98), "glass part follows the window")
	Majestic:SetGlass({ Blur = 34 })
	check(dofCount() == 2, "blur 34 -> 2 effects, got " .. dofCount())
	Majestic:SetGlass({ Blur = 0 })
	check(dofCount() == 0 and gp.Transparency == 1, "blur 0 removes effects and hides the part")
	Majestic:SetGlass({ Blur = 60, Transparency = 70 })
	check(near(win._main.BackgroundTransparency, 0.7), "transparency can be changed live")
	win:Toggle(false)
	check(gp.Transparency == 1, "glass part hides with the window")
	win:Toggle(true)
	Majestic:SetTheme("Dark")
	check(dofCount() == 0 and near(win._main.BackgroundTransparency, 0), "leaving glass restores opaque panels")
	check(gp.Transparency == 1, "part hidden after leaving glass")

	-- поиск
	win._searchBox.Text = "renamed"
	check(#win._resultItems >= 1, "search finds element, got " .. #win._resultItems)
	check(win._results.Visible == true, "results visible")
	local first = win._resultItems[1]
	fireSig(first, "MouseButton1Click")
	check(win.ActiveTab == main, "search result click selects element's tab")
	check(win._results.Visible == false, "search cleared after pick")
	win._searchBox.Text = "zzzzqqq"
	check(#win._resultItems == 0 and win._emptyLabel.Visible == true, "search empty state")
	win._searchBox.Text = ""

	-- диалог
	local dlg = win:Dialog({ Title = "T", Content = "C", Buttons = { { "Yes", function() calls.yes = true end }, { "No" } } })
	local yes = findText(dlg.dim, "Yes", "TextButton")
	check(yes ~= nil, "dialog button exists")
	if yes then
		fireSig(yes, "MouseButton1Click")
	end
	check(calls.yes == true, "dialog callback fired")

	-- уведомления
	noerr("Notify", function()
		Majestic:Notify({ Title = "x", Content = "y", Type = "Warning" })
		Majestic:Notify("a", "b", 2)
		Majestic:Notify({ Title = "persistent", Duration = 0 })
		Mock.runDelayed()
	end)

	-- показать / скрыть / масштаб
	noerr("Toggle window", function()
		win:Toggle(false)
		check(win.Visible == false, "hidden")
		win:Toggle(true)
		check(win.Visible == true, "shown")
		win:Toggle(false, true)
		win:Toggle(true)
		win:SetScale(1.2)
		check(near(win._uiscale.Scale, 1.2), "SetScale applies to UIScale")
		win:SetScale(1)
	end)

	-- Key System (в корутине, т.к. цикл ожидает через task.wait)
	local ksResult
	local co = Mock.newThread(function()
		ksResult = Majestic:KeySystem({ Keys = { "secret" }, Folder = "SmokeHub", KeyLink = "https://get.key", SaveKey = true })
	end)
	coroutine.resume(co)
	local boxes = {}
	walk(guiRoot(), function(i)
		if i.ClassName == "TextBox" and i.PlaceholderText == "Enter key..." then
			table.insert(boxes, i)
		end
	end)
	check(#boxes == 1, "key box shown")
	local keyBox = boxes[1]
	local checkBtn = findText(guiRoot(), "Check Key", "TextButton")
	keyBox.Text = "wrong"
	fireSig(checkBtn, "MouseButton1Click")
	check(ksResult == nil, "wrong key rejected")
	keyBox.Text = "secret"
	fireSig(checkBtn, "MouseButton1Click")
	coroutine.resume(co)
	check(ksResult == true, "correct key accepted")
	check(Mock.files["SmokeHub/key.txt"] == "secret", "key saved")
	local again = Majestic:KeySystem({ Keys = { "secret" }, Folder = "SmokeHub" })
	check(again == true, "saved key passes without UI")
	local getBtn = nil

	-- в интерфейсе библиотеки нет символов вне ASCII (они превращаются в квадратики)
	local tofu = {}
	walk(guiRoot(), function(i)
		local cls = i.ClassName
		if cls == "TextLabel" or cls == "TextButton" or cls == "TextBox" then
			for _, prop in ipairs({ "Text", "PlaceholderText" }) do
				local t = i[prop]
				if type(t) == "string" and t ~= "🔥" and t:find("[\128-\255]") then
					table.insert(tofu, t)
				end
			end
		end
	end)
	check(#tofu == 0, "non-ASCII glyphs in library UI: " .. table.concat(tofu, " | "))

	-- "обезьяний" проход: кликаем и тянем всё подряд
	local destroyed = 0
	win.Destroy = function()
		destroyed += 1
	end
	local clicks = 0
	local all = {}
	walk(guiRoot(), function(i)
		table.insert(all, i)
	end)
	for _, inst in ipairs(all) do
		local st = states[inst]
		if st and not st.destroyed then
			for _, name in ipairs({ "MouseEnter", "MouseLeave", "MouseButton1Click", "Focused" }) do
				if sig(inst, name) then
					clicks += 1
					noerr("monkey " .. name .. " on " .. inst.ClassName, function()
						fireSig(inst, name)
					end)
				end
			end
			if sig(inst, "InputBegan") then
				local press = fakeInput("MouseButton1", 40, 20, "Begin")
				noerr("monkey InputBegan on " .. inst.ClassName, function()
					fireSig(inst, "InputBegan", press, false)
					Mock.uis.InputChanged:Fire(fakeInput("MouseMovement", 60, 25, "Change"), false)
					press.UserInputState = Enum.UserInputState.End
					press.Changed:Fire()
				end)
			end
			if inst.ClassName == "TextBox" then
				noerr("monkey TextBox", function()
					for _, txt in ipairs({ "12", "#ff8800", "abc", "" }) do
						inst.Text = txt
						fireSig(inst, "FocusLost", true)
					end
				end)
			end
		end
	end
	check(clicks > 50, "monkey fired many handlers: " .. clicks)

	-- нажатия клавиш: бинд, переключение окна, смена бинда
	noerr("keys", function()
		Mock.uis.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.RightShift }, false)
		Mock.uis.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.RightShift }, false)
		Mock.uis.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Escape }, false)
		Mock.uis.InputEnded:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.H }, false)
	end)

	-- уничтожение элемента и окна
	noerr("destroy element", function()
		tg:Destroy()
		check(Majestic.Options.AutoFarm == nil, "destroyed element leaves registry")
	end)
	getmetatable(win).__index.Destroy(win)
	check(#Majestic.Windows == 0, "window removed")
	Majestic:Unload()
end

----------------------------------------------------------------------
for _, mobile in ipairs({ false, true }) do
	Mock.uis.TouchEnabled = mobile
	Mock.uis.KeyboardEnabled = not mobile
	Mock.httpGetCalls = 0
	Mock.files, Mock.folders = {}, {}
	local Majestic = loadBundle()
	runAll(Majestic, mobile and "MOBILE" or "DESKTOP")
end

print(string.format("checks: %d, failures: %d, callback warnings: %d", checks, failures, warnings))
if failures > 0 or warnings > 0 then
	error("SMOKE TEST FAILED", 0)
end
print("SMOKE TEST OK")
