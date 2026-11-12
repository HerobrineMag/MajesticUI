local Majestic = loadstring(game:HttpGet"https://raw.githubusercontent.com/HerobrineMag/MajesticUI/main/Majestic.lua")()

local Window = Majestic:Window({
	Title = "Majestic Hub";
	Subtitle = "v2.0";
	Icon = "home";                   -- иконка в шапке
	IconUrl = "Lucide";              -- откуда брать иконки: "Lucide" или "Material"
	Theme = "Dark";                  -- Dark / Light / Ocean / Rose / Emerald / Midnight / Liquid Glass
	ToggleKey = Enum.KeyCode.RightShift;
	Folder = "MajesticHub";          -- папка для конфигов и тем
	LoadingEnabled = true;           -- загрузочный экран

	-- Glass = { Color = Color3.fromRGB(28, 34, 50); Blur = 60; Transparency = 50 };  -- включит Liquid Glass сразу
	-- KeySystem = { Keys = { "my-key" }; KeyLink = "https://example.com/key" };
})

----------------------------------------------------------------------
-- Home: профиль, статистика сервера, ссылки
----------------------------------------------------------------------
Window:HomeTab({
	Welcome = "Welcome back";
	Buttons = {
		{ Name = "Discord", Desc = "Link is copied to clipboard", Link = "https://discord.gg/example", Icon = "users" },
	};
})

----------------------------------------------------------------------
-- Main
----------------------------------------------------------------------
Window:TabSection("Features")
local Main = Window:Tab({ Name = "Main"; Icon = "swords" })

Main:Section("Player")

Main:Toggle({
	Name = "Auto Farm";
	Default = false;
	Callback = function(v)
		print("Auto Farm:", v)
	end;
})

Main:Slider({
	Name = "WalkSpeed";              -- название
	Min = 16;                        -- минимум
	Max = 200;                       -- максимум
	Default = 16;                    -- значение по умолчанию
	Callback = function(v)
		local char = game.Players.LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = v end
	end;
})

Main:Button({
	Name = "Rejoin";
	Callback = function()
		game:GetService("TeleportService"):Teleport(game.PlaceId)
	end;
})

Main:Label({ Name = "Info label"; Desc = "Type: Info / Success / Warning / Error"; Type = "Info" })

----------------------------------------------------------------------
-- Elements: все основные поля
----------------------------------------------------------------------
local Elements = Window:Tab({ Name = "Elements"; Icon = "layout-dashboard" })

Elements:Toggle({
	Name = "ESP";
	Desc = "Highlight players through walls";
	Tooltip = "Shown when you hover the row";
	Icon = "eye";                    -- иконка элемента
	Default = true;
	Flag = "ESP";                    -- попадёт в конфиг и в Majestic.Flags.ESP
	Callback = function(v)
		print("ESP:", v)
	end;
})

Elements:Slider({
	Name = "FOV"; Min = 30; Max = 120; Default = 70; Suffix = " deg"; Flag = "FOV";
	Callback = function(v)
		workspace.CurrentCamera.FieldOfView = v
	end;
})

Elements:RangeSlider({
	Name = "Distance"; Min = 0; Max = 500; Default = { 50, 300 }; Flag = "Distance";
	Callback = function(from, to)
		print("Distance:", from, to)
	end;
})

Elements:Dropdown({
	Name = "Mode";
	Options = { "Legit", "Rage", "Silent" };
	Default = "Legit";
	Flag = "Mode";
	Callback = function(v)
		print("Mode:", v)       -- клик по полю: можно печатать для поиска, Enter выбирает
	end;
})

Elements:Dropdown({
	Name = "Targets";
	Options = { "Head", "Torso", "Arms", "Legs", "Hands", "Feet" };
	Default = { "Head" };
	Multi = true;                    -- мульти-выбор
	Flag = "Targets";
	Callback = function(list)
		print("Targets:", table.concat(list, ", "))
	end;
})

Elements:Input({
	Name = "Player name"; Placeholder = "Type a name..."; Flag = "TargetName";
	Callback = function(text)
		print("Name:", text)
	end;
})

Elements:Keybind({
	Name = "Fly key"; Default = Enum.KeyCode.F; Mode = "Toggle"; Flag = "FlyKey";   -- Press / Toggle / Hold
	Callback = function(state)
		print("Fly:", state)
	end;
})

Elements:ColorPicker({
	Name = "ESP color"; Default = Color3.fromRGB(255, 80, 80); Alpha = true; Rainbow = true; Flag = "ESPColor";
	Callback = function(color, alpha)
		print("Color:", color, alpha)
	end;
})

----------------------------------------------------------------------
-- Layout: колонки, группы, таблица
----------------------------------------------------------------------
local Layout = Window:Tab({ Name = "Layout"; Icon = "table" })

local left, right = Layout:Columns(2)

local combat = left:Group({ Name = "Combat"; Icon = "swords" })
combat:Toggle({ Name = "Aimbot"; Default = false; Callback = function(v) print("Aimbot:", v) end })

local misc = right:Group({ Name = "Misc"; Icon = "settings"; Collapsible = true })
misc:Toggle({ Name = "Anti AFK"; Default = true; Callback = function(v) print("Anti AFK:", v) end })

Layout:Table({
	Name = "Players";
	Columns = { "Name", { Name = "Ping", Width = 0.2 } };
	Rows = { { "Alice", 32 }, { "Bob", 120 }, { "Carol", 54 } };
	Search = true;
	Callback = function(index, row)
		print("Selected:", row[1], row[2])
	end;
})

----------------------------------------------------------------------
-- Иконки из Material: IconUrl можно задать на любом элементе
----------------------------------------------------------------------
local Icons = Window:Tab({ Name = "Material"; Icon = "settings"; IconUrl = "Material" })
Icons:Toggle({ Name = "Material icon"; Icon = "visibility"; IconUrl = "Material"; Default = true })
Icons:Button({
	Name = "Notification";
	Callback = function()
		Majestic:Notify({ Title = "Hello"; Content = "Notification from Majestic"; Type = "Success" })
	end;
})

----------------------------------------------------------------------
-- Настройки: тема, масштаб, Liquid Glass, конфиги
----------------------------------------------------------------------
Window:TabDivider()
Window:Settings()

-- В самом конце: загрузить конфиг, помеченный как автозагрузка
Window:LoadAutoConfig()

Majestic:Notify({ Title = "Majestic"; Content = "RightShift: show / hide the menu"; Type = "Info"; Duration = 5 })

----------------------------------------------------------------------
-- Управление из кода
----------------------------------------------------------------------
-- local t = Main:Toggle({ Name = "Test"; Default = false })
-- t:Set(true)          -- поменять значение (вызовет Callback)
-- t:Set(true, true)    -- поменять тихо, без Callback
-- t:Get()              -- прочитать значение
-- Majestic:SetGlass({ Color = Color3.fromRGB(28, 34, 50); Blur = 70; Transparency = 45 })
-- Majestic:SetTheme("Dark")
