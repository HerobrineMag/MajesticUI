-- Window:ConfigManager(контейнер), Window:ThemeEditor(контейнер), Window:Settings()
local Env = import("Core/Env")
local ThemeM = import("Core/Theme")
local Config = import("Core/Config")
local Window = import("Core/Window")
local Notify = import("Systems/Notify")

local function note(ok, title, err)
	Notify.show({
		Title = ok and title or (title .. " failed"), Content = (not ok) and err or nil,
		Type = ok and "Success" or "Error", Duration = 3,
	})
end

-- Менеджер конфигов: сохранить / загрузить / удалить / автозагрузка.
-- container — вкладка или группа; без аргумента создаст свою вкладку.
function Window:ConfigManager(container)
	container = container or self:Tab("Configs", "save")

	local nameInput = container:Input({ Name = "Config name", Default = "default", Placeholder = "name" })
	local list = container:Dropdown({ Name = "Saved configs", Options = Config.list(self), Placeholder = "(none)" })
	list:OnChanged(function(v)
		if v then
			nameInput:Set(v, true)
		end
	end)

	local function refresh()
		list:Refresh(Config.list(self))
	end

	container:Button({
		Name = "Save config", ButtonIcon = "save", ButtonText = "Save",
		Callback = function()
			local ok, err = Config.save(self, nameInput:Get())
			note(ok, "Config saved", err)
			refresh()
		end,
	})
	container:Button({
		Name = "Load config", ButtonIcon = "load", ButtonText = "Load",
		Callback = function()
			local ok, err = Config.load(self, nameInput:Get())
			note(ok, "Config loaded", err)
		end,
	})
	container:Button({
		Name = "Delete config", ButtonIcon = "delete", ButtonText = "Delete",
		Callback = function()
			local name = nameInput:Get()
			self:Dialog({
				Title = "Delete config?", Content = tostring(name),
				Buttons = {
					{ "Delete", function()
						local ok, err = Config.delete(self, name)
						note(ok, "Config deleted", err)
						refresh()
					end },
					{ "Cancel" },
				},
			})
		end,
	})
	container:Button({ Name = "Refresh list", ButtonIcon = "refresh", ButtonText = "Refresh", Callback = refresh })

	local autoLabel = container:Label("Autoload: " .. (Config.getAutoload(self) or "none"))
	container:Button({
		Name = "Set as autoload", Desc = "This config is loaded by Window:LoadAutoConfig() on the next start",
		ButtonIcon = "check", ButtonText = "Set",
		Callback = function()
			local ok, err = Config.setAutoload(self, nameInput:Get())
			if ok then
				autoLabel:Set("Autoload: " .. Config.sanitize(nameInput:Get()))
			end
			note(ok, "Autoload set", err)
		end,
	})
	container:Button({
		Name = "Clear autoload", ButtonIcon = "clear", ButtonText = "Clear",
		Callback = function()
			local ok, err = Config.setAutoload(self, nil)
			if ok then
				autoLabel:Set("Autoload: none")
			end
			note(ok, "Autoload cleared", err)
		end,
	})
	return container
end

-- Редактор тем: цвет каждой части интерфейса вживую, сохранение своих тем, копирование как Lua-таблица
function Window:ThemeEditor(container)
	container = container or self:Tab("Themes", "palette")

	local pickers = {}
	local function sync()
		for key, picker in pairs(pickers) do
			picker:Set(ThemeM.Colors[key], true)
		end
	end

	local presets = container:Dropdown({
		Name = "Preset", Options = ThemeM.names(), Default = ThemeM.Name,
		Callback = function(name)
			ThemeM.set(name)
			sync()
		end,
	})
	for _, key in ipairs(ThemeM.Keys) do
		pickers[key] = container:ColorPicker({
			Name = key, Default = ThemeM.Colors[key],
			Callback = function(color)
				ThemeM.setColor(key, color)
			end,
		})
	end

	local nameInput = container:Input({ Name = "Theme name", Default = "MyTheme", Placeholder = "name" })
	container:Button({
		Name = "Save theme", ButtonIcon = "save", ButtonText = "Save",
		Callback = function()
			local ok, err = Config.saveTheme(self, nameInput:Get())
			note(ok, "Theme saved", err)
			presets:Refresh(ThemeM.names())
			presets:Set(Config.sanitize(nameInput:Get()), true)
		end,
	})
	container:Button({
		Name = "Delete theme", ButtonIcon = "delete", ButtonText = "Delete",
		Callback = function()
			local ok, err = Config.deleteTheme(self, nameInput:Get())
			note(ok, "Theme deleted", err)
			presets:Refresh(ThemeM.names())
		end,
	})
	container:Button({
		Name = "Copy as Lua", Desc = "Color table for Majestic:RegisterTheme", ButtonIcon = "copy", ButtonText = "Copy",
		Callback = function()
			local copied = Env.clipboard(ThemeM.toLua())
			Notify.show({
				Title = copied and "Theme copied" or "Clipboard unavailable", Type = copied and "Success" or "Warning", Duration = 2,
			})
		end,
	})
	return container
end

-- Настройки Liquid Glass: включение, оттенок, размытие, прозрачность
function Window:GlassSettings(container)
	container = container or self:Tab("Glass", "layers")
	local g = ThemeM.Glass
	local previous = ThemeM.Name ~= ThemeM.GlassName and ThemeM.Name or "Dark"

	local toggle = container:Toggle({
		Name = "Liquid Glass", Desc = "Translucent glass panels with background blur", Default = g.Enabled,
		Flag = "Majestic.Glass",
		Callback = function(on)
			if on then
				if ThemeM.Name ~= ThemeM.GlassName then
					previous = ThemeM.Name
				end
				ThemeM.set(ThemeM.GlassName)
			elseif ThemeM.Name == ThemeM.GlassName then
				ThemeM.set(previous)
			end
		end,
	})
	container:ColorPicker({
		Name = "Glass tint", Desc = "Base color of the glass", Default = g.Color, Flag = "Majestic.GlassTint",
		Callback = function(color)
			ThemeM.setGlass({ Color = color })
		end,
	})
	container:Slider({
		Name = "Blur", Desc = "How strongly the background behind the window is blurred", Min = 0, Max = 100,
		Default = g.Blur, Suffix = "%", Flag = "Majestic.GlassBlur",
		Callback = function(v)
			ThemeM.setGlass({ Blur = v })
		end,
	})
	container:Slider({
		Name = "Transparency", Desc = "How see-through the panels are", Min = 0, Max = 95,
		Default = math.floor(g.Transparency * 100 + 0.5), Suffix = "%", Flag = "Majestic.GlassTransparency",
		Callback = function(v)
			ThemeM.setGlass({ Transparency = v / 100 })
		end,
	})
	return container, toggle
end

-- Готовая вкладка настроек: интерфейс, Liquid Glass, конфиги, редактор тем
function Window:Settings(opts)
	opts = opts or {}
	local tab = self:Tab({ Name = opts.Name or "Settings", Icon = opts.Icon or "settings", IconUrl = opts.IconUrl })
	local left, right = tab:Columns(2)

	local glassToggle
	local ui = left:Group({ Name = "Interface", Icon = "layout-dashboard" })
	ui:Dropdown({
		Name = "Theme", Options = ThemeM.names(), Default = ThemeM.Name,
		Callback = function(name)
			ThemeM.set(name)
			if glassToggle then
				glassToggle:Set(name == ThemeM.GlassName, true)
			end
		end,
	})
	ui:ColorPicker({
		Name = "Accent color", Default = ThemeM.Colors.Accent,
		Callback = function(color)
			ThemeM.setColor("Accent", color)
		end,
	})
	-- Commit: масштаб применяется при отпускании ползунка, поэтому меню не дёргается
	ui:Slider({
		Name = "UI scale", Min = 0.7, Max = 1.3, Default = self._scale, Increment = 0.05, Commit = true,
		Callback = function(v)
			self:SetScale(v)
		end,
	})
	ui:Keybind({
		Name = "Menu key", Default = self.ToggleKey,
		OnChange = function(k)
			if k then
				self.ToggleKey = k
			end
		end,
	})

	local glassGroup = left:Group({ Name = "Liquid Glass", Icon = "layers" })
	local _, toggle = self:GlassSettings(glassGroup)
	glassToggle = toggle

	local cfgGroup = right:Group({ Name = "Configuration", Icon = "save" })
	self:ConfigManager(cfgGroup)

	if opts.Themes ~= false then
		local themes = tab:Group({ Name = "Theme editor", Icon = "palette", Collapsible = true, Collapsed = true })
		self:ThemeEditor(themes)
	end

	local misc = tab:Group({ Name = "Misc" })
	misc:Button({
		Name = "Unload UI", Desc = "Close the menu completely", ButtonIcon = "clear", ButtonText = "Unload",
		Callback = function()
			self:Destroy()
		end,
	})
	return tab
end

return true
