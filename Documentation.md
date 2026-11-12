# Majestic UI Library v2

UI-библиотека для Roblox-экзекуторов: простой синтаксис, много элементов, группы и колонки, поиск по меню,
конфиги, темы, Liquid Glass, Key System, иконки Lucide и Material, адаптация под телефон.

```lua
local Majestic = loadstring(game:HttpGet("https://raw.githubusercontent.com/HerobrineMag/MajesticUI/refs/heads/main/Majestic/Majestic.lua"))()

local Window = Majestic:Window(
    {
        Title = "Мой хаб";
        Subtitle = "v1.0";
        Icon = "home"
    })
    local Tab = Window:Tab(
    {
        Name = "Main";
        Icon = "swords"
    })
    
    Tab:Toggle({
        Name = "Auto Farm";
        Default = false;
        Callback = function(v)
            print("hi", v)
        end;
})
```

## Содержание
1. [Как писать код](#как-писать-код)
2. [Окно](#окно)
3. [Вкладки](#вкладки)
4. [Группы и колонки](#группы-и-колонки)
5. [Элементы](#элементы)
6. [Общие поля и методы](#общие-поля-и-методы)
7. [Иконки: Lucide и Material](#иконки-lucide-и-material)
8. [Liquid Glass](#liquid-glass)
9. [Темы](#темы)
10. [Системы](#системы)
11. [Конфиги](#конфиги)
12. [Телефоны](#телефоны)
13. [Сборка и тесты](#сборка-и-тесты)
14. [Ограничения](#ограничения)

---

## Как писать код

Любой элемент создаётся одинаково: `Tab:Элемент({ Поле = значение; Поле = значение })`.
Поля разделяются `;` или `,`, порядок не важен, ненужные поля можно пропускать.

```lua
Tab:Slider({
    Name = "WalkSpeed";      -- название
    Min = 16;                -- минимум
    Max = 200;               -- максимум
    Default = 16;            -- значение по умолчанию
    Callback = function(v)   -- вызывается при изменении
        print(v)
    end;
})
```

`Callback` работает так у всех элементов, у которых есть значение или действие (Toggle, Slider, RangeSlider,
Dropdown, Input, Keybind, ColorPicker, Table, Button).
Синонимы: `Value` = `Default`, `Values`/`List` = `Options`, `Title` = `Name`, `Description` = `Desc`.

Для любителей коротких записей есть необязательная форма без названий полей (порядок: имя, затем поля элемента):
`Tab:Slider("WalkSpeed", 16, 200, 16, callback)` = имя, минимум, максимум, значение, колбэк.
В примерах и документации используется только форма с именами полей.

## Окно

```lua
local Window = Majestic:Window({
    Title = "Hub"; Subtitle = "v1.0"; Icon = "home"; IconUrl = "Lucide";
    Theme = "Dark"; Accent = Color3.fromRGB(139, 92, 246);
    Glass = { Color = Color3.fromRGB(28, 34, 50); Blur = 60; Transparency = 50 };
    Size = Vector2.new(620, 420); Scale = 1;
    ToggleKey = Enum.KeyCode.RightShift;
    Folder = "MyHub";
    LoadingEnabled = true;
    KeySystem = { ... };
})
```

| Поле | Описание |
|---|---|
| `Title`, `Subtitle`, `Icon` | Заголовок и иконка в шапке (подзаголовок скрыт на телефоне) |
| `IconUrl` | Набор иконок по умолчанию для всего окна: `"Lucide"` или `"Material"` |
| `Theme` | `Dark`, `Light`, `Ocean`, `Rose`, `Emerald`, `Midnight`, `Liquid Glass` или своя сохранённая тема |
| `Glass` | Настройки стекла (включают тему Liquid Glass), см. [Liquid Glass](#liquid-glass) |
| `Accent` | Свой цвет акцента |
| `Size`, `MinWidth`, `MinHeight`, `SidebarWidth` | Размеры (окно тянется за правый нижний угол) |
| `Scale` | Масштаб интерфейса |
| `ToggleKey` | Клавиша показать/скрыть |
| `Folder` | Папка для конфигов, тем и ключа |
| `Search` | `false` отключает поиск в шапке |
| `LoadingEnabled`, `LoadingTitle`, `LoadingSubtitle`, `LoadingSteps`, `LoadingTime` | Загрузочный экран |
| `KeySystem` | Ввод ключа перед окном |

Методы: `Toggle(state?, showMini?)`, `SetScale(n)`, `SetTheme(name)`, `Dialog(cfg)`, `Destroy()`, `Tab(...)`,
`TabSection(name)`, `TabDivider()`, `HomeTab(cfg)`, `Settings(opts)`, `ConfigManager(container?)`,
`ThemeEditor(container?)`, `GlassSettings(container?)`, `SaveConfig / LoadConfig / DeleteConfig / ListConfigs`,
`SetAutoload / GetAutoload / LoadAutoConfig`.

Масштаб меняется вокруг центра окна, поэтому меню не уезжает.
Кнопки окна и все стрелки нарисованы фигурами, а не символами шрифта, поэтому квадратиков нет.

## Вкладки

```lua
Window:TabSection("Combat")                                         -- заголовок группы вкладок
local Tab = Window:Tab({ Name = "Aim"; Icon = "crosshair"; IconUrl = "Lucide" })
Window:TabDivider()
```

Вкладка — контейнер: на ней доступны все элементы. Методы: `Select()`, `SetVisible(bool)`.

## Группы и колонки

```lua
local Group = Tab:Group({ Name = "Combat"; Icon = "swords"; Collapsible = true; Collapsed = false })
Group:Toggle({ Name = "Aimbot"; Default = false })
Group:Collapse(); Group:Expand(); Group:ToggleCollapse(); Group:SetTitle("..."); Group:SetVisible(false)

local left, right = Tab:Columns(2)        -- на телефоне колонки встают друг под другом
left:Button({ Name = "Left"; Callback = function() end })
right:Group({ Name = "Nested" }):Slider({ Name = "Speed"; Min = 0; Max = 10; Default = 5 })
```

## Элементы

| Элемент | Основные поля | Методы |
|---|---|---|
| `Section` | `Name` | |
| `Divider` | | |
| `Label` | `Name`, `Desc`, `Type` = `Info`/`Success`/`Warning`/`Error` | `Set(text)` |
| `Paragraph` | `Name`, `Content` | `Set(text)` |
| `Image` | `Image`, `Height`, `Fit` | `Set(image)` |
| `Button` | `Name`, `Callback`, `ButtonIcon`, `ButtonText` | `Fire()`, `SetText(t)` |
| `Toggle` (`Checkbox`) | `Default`, `Callback` | `Set(bool)`, `Get()`, `Toggle()` |
| `Slider` | `Min`, `Max`, `Default`, `Increment`, `Suffix`, `Commit`, `Callback` | `Set(n)`, `Get()`, `SetRange(min, max)` |
| `RangeSlider` | как у Slider, `Default = { от, до }`, Callback `(от, до)` | `Set({от, до})`, `Get()` |
| `Dropdown` | `Options`, `Default`, `Multi`, `Placeholder`, `Callback` | `Set`, `Get`, `Refresh(options)`, `GetOptions()` |
| `Input` (`TextBox`) | `Default`, `Placeholder`, `Numeric`, `Live`, `Multiline`, `Height`, `Callback` | `Set`, `Get`, `Focus()` |
| `Keybind` (`Bind`) | `Default`, `Mode` = `Press`/`Toggle`/`Hold`, `Callback`, `OnChange` | `Set(key)`, `Get()` |
| `ColorPicker` (`Color`) | `Default`, `Alpha`, `Rainbow`, Callback `(color, alpha)` | `Set`, `Get`, `SetAlpha`, `GetAlpha`, `SetRainbow` |
| `Progress` | `Default` (0-100) | `Set(n)`, `Get()` |
| `Table` | `Columns`, `Rows`, `Height`, `Selectable`, `MultiSelect`, `Sortable`, `Search`, `Callback` | `AddRow`, `RemoveRow`, `SetRows`, `Clear`, `GetRows`, `Select`, `Sort`, `Get` |

**Button**: справа иконка клика. `ButtonIcon` меняет иконку: смысл (`"click"`, `"copy"`, `"save"`, `"load"`, `"delete"`,
`"refresh"`, `"check"`, `"clear"`) или любое имя иконки. `ButtonText` показывает текст вместо иконки (или если иконка недоступна).

**Dropdown**: клик по тексту превращает поле в строку поиска, список фильтруется по мере ввода, `Enter` выбирает первый
подходящий пункт (в `Multi` переключает его). Пункты по центру, список раскрывается плавно, клик вне закрывает его.

**Slider**: `Commit = true` вызывает `Callback` один раз при отпускании ползунка, а не на каждом движении
(полезно для тяжёлых действий, например масштаба UI).

**ColorPicker**: компактная панель фиксированного размера, раскрывается плавно. `Alpha = true` добавляет полосу
прозрачности, `Rainbow = true` кнопку радужного режима.

**Table**: `Columns = { "Name", { Name = "Ping", Width = 0.2 } }`, `Rows = { { "Alice", 32 } }`. Клик по заголовку
сортирует, `Search = true` добавляет фильтр. Callback — `(index, rowValues)`, при `MultiSelect` — `(listOfRows)`.

## Общие поля и методы

| Поле | Описание |
|---|---|
| `Name` | Название |
| `Desc` | Описание под названием |
| `Tooltip` | Подсказка при наведении |
| `Icon`, `IconUrl` | Иконка слева от названия и набор, откуда она берётся |
| `Callback` | Вызывается при изменении |
| `Flag` | Имя флага: значение попадёт в `Majestic.Flags[flag]` и в конфиги |
| `Fire` | `true`: вызвать Callback сразу при создании |
| `Locked` | `true`: элемент создаётся заблокированным |

Методы любого элемента: `Set(v, silent?)`, `Get()`, `SetTitle(t)`, `SetDesc(t)`, `SetTooltip(t)`, `SetVisible(bool)`,
`SetLocked(bool)`, `OnChanged(fn)`, `Focus()` (перейти к элементу и подсветить), `Destroy()`.
`Set(v, true)` меняет значение без вызова Callback.

## Иконки: Lucide и Material

Везде, где есть `Icon`, можно указать, откуда она берётся:

```lua
Tab:Toggle({ Name = "ESP"; Icon = "eye"; IconUrl = "Lucide" })          -- Lucide: eye, swords, home, layout-dashboard ...
Tab:Toggle({ Name = "ESP"; Icon = "visibility"; IconUrl = "Material" }) -- Material: visibility, touch_app, content_copy ...
```

`IconUrl` принимает `"Lucide"`, `"Material"` или ссылку на свой набор (формат ниже). Набор для всего окна задаётся
в `Majestic:Window({ IconUrl = "Material" })`, для всей библиотеки: `Majestic.Icons.Default = "Material"`.
Префикс в имени тоже работает: `Icon = "material:home"`, `Icon = "lucide:home"`.

Также в `Icon` подходят эмодзи или текст (`"🔥"`), `rbxassetid://123` или число.

- **Material** (1482 иконки) вшит в библиотеку, имена в `snake_case`: `home`, `settings`, `touch_app`, `content_copy`.
  Набор собран в проекте Luna Interface Suite (BSD-3, автор иконок qweery), лицензия в начале файла
  `src/Core/MaterialData.lua`.
- **Lucide** загружается один раз при первом использовании со ссылки `Majestic.Icons.LucideUrl` (спрайт-лист из
  репозитория Rayfield), имена с дефисами: `home`, `swords`, `layout-dashboard`. Если загрузка не удалась,
  иконки Lucide не показываются, остальное работает.
- Свой набор: `IconUrl = "https://.../icons.lua"`, файл возвращает таблицу
  `{ ["48px"] = { имя = { assetId, {w, h}, {x, y} } }, ["256px"] = { ... } }`.
- Свои имена: `Majestic.Icons.Custom["logo"] = 123456789`.
- Список имён набора: `Majestic.Icons.names("Material")`.

## Liquid Glass

Тема `Liquid Glass`: полупрозрачные панели, блик, светлая кромка и настоящее размытие игры за окном.

```lua
Majestic:SetGlass({
    Color = Color3.fromRGB(28, 34, 50);   -- оттенок стекла (цвета панелей и текста считаются из него)
    Blur = 60;                            -- сила размытия 0-100
    Transparency = 50;                    -- прозрачность панелей, %
})
Majestic:SetTheme("Dark")                 -- вернуть обычную тему
```

Включить можно так: `Theme = "Liquid Glass"` или `Glass = { ... }` в `Majestic:Window`, `Majestic:SetGlass(...)`,
либо в `Window:Settings()` (группа Liquid Glass: переключатель, оттенок, размытие, прозрачность).
Значения этих настроек сохраняются в конфиги.

Как работает размытие: почти прозрачная стеклянная деталь вплотную к камере повторяет прямоугольник окна, а эффект
`DepthOfField` в Lighting размывает всё, что за ней. Сила `Blur` задаёт число и интенсивность таких эффектов.
Чужие эффекты `DepthOfField` на время работы стекла отключаются и потом возвращаются.

Особенности:
- размывается только 3D-мир игры, а не другие интерфейсы;
- на низких настройках графики и на части телефонов `DepthOfField` может не отображаться, тогда остаются
  прозрачные панели без размытия;
- при `Blur = 0` размытие выключено, прозрачность остаётся.

## Темы

Встроенные: `Dark`, `Light`, `Ocean`, `Rose`, `Emerald`, `Midnight`, `Liquid Glass`.

```lua
Majestic:SetTheme("Ocean")
Majestic:SetAccent(Color3.fromRGB(255, 80, 80))
Majestic:RegisterTheme("Mine",
{
    Background = Color3.fromRGB(10, 10, 10);
    Accent = Color3.fromRGB(0, 255, 120)
})
```

Ключи темы: `Background`, `Topbar`, `Sidebar`, `Element`, `ElementHover`, `Stroke`, `Accent`, `Text`, `SubText`,
`Success`, `Warning`, `Danger`. Пропущенные ключи берутся из `Dark`.
`Window:ThemeEditor()` меняет цвета вживую, сохраняет свои темы в `Folder/Themes/*.json` и копирует тему как Lua-таблицу.

## Системы

**Поиск.** Поле в шапке ищет по названиям и описаниям всех элементов и вкладок. Клик по результату открывает вкладку,
прокручивает к элементу, раскрывает свёрнутую группу и подсвечивает рамку. `Esc` очищает поиск.

**Уведомления.**
```lua
Majestic:Notify(
{
    Title = "Готово";
     Content = "Текст";
    Type = "Success";
    Duration = 5
})
```
`Type`: `Info`, `Success`, `Warning`, `Error`. `Duration = 0` не закрывается само. Клик закрывает.

**Диалоги.**
```lua
Window:Dialog({
    Title = "Sure?"; Content = "...";
    Buttons = {
    {
        "Yes", function()
            end
    },
    { "Cancel" } };
})
```

**Key System.**
```lua
KeySystem = {
    Keys = { "key-1", "key-2" };                  -- или Validate = function(key) return ok, "сообщение" end
    KeyLink = "https://example.com/key";          -- кнопка Get Key копирует ссылку
    Subtitle = "Get your key by the link";
    SaveKey = true; MaxAttempts = 5;
}
```
Без окна: `if Majestic:KeySystem({ Keys = { "abc" } }) then ... end`. Если окно ключа закрыли, `Majestic:Window` бросает ошибку и
скрипт останавливается.

> Ключи в клиентском скрипте может прочитать кто угодно. Для настоящей защиты проверяй ключ на своём сервере
> в `Validate` (например, `game:HttpGet` на твой API).

**Home-вкладка.**
```lua
Window:HomeTab(
{
Welcome = "Hi";
Buttons = {
    {
        Name = "Discord";
        Link = "https://..."
    }
    };
        Changelog = {
        {
            Title = "v1";
            Text = "..."
        }
    }
})
```
Аватар и ник, игра, статистика сервера (игроки, пинг, FPS, сессия), Place ID и Job ID целиком (клик копирует).

**Настройки.** `Window:Settings()` создаёт вкладку: тема, акцент, масштаб (применяется при отпускании ползунка), клавиша меню,
Liquid Glass, конфиги, редактор тем.

## Конфиги

```lua
Window:SaveConfig("name");
Window:LoadConfig("name");
Window:DeleteConfig("name")
Window:ListConfigs()
Window:SetAutoload("name");
Window:SetAutoload(nil)
Window:LoadAutoConfig()        -- вызывай в конце скрипта, когда все элементы созданы
```
Сохраняются элементы с `Flag`: Toggle, Slider, RangeSlider, Dropdown, Input, Keybind, ColorPicker (с альфой).
Файлы лежат в `Folder/Configs/<name>.json`, нужны функции файловой системы экзекутора.

## Телефоны

Определяется автоматически (есть тач и нет клавиатуры): окно меньше, строки выше, колонки встают друг под другом,
при скрытии окна появляется плашка для возврата. Перетаскивание слайдеров блокирует прокрутку страницы.

## Сборка и тесты

Исходники в `src/`. Один файл собирается так: `python3 build.py` (получится `Majestic.lua`).
Автотесты (нужен бинарник `luau`): `LUAU=/путь/к/luau ./test/run.sh` собирает бандл и выполняет `test/smoke.lua` на
заглушке Roblox API (десктопный и мобильный режим).

## Ограничения

- Библиотека проверена анализатором Luau с типами Roblox и тестами на заглушке API, но не запускалась в настоящем клиенте.
  Внешний вид (отступы, шрифты, анимации) и размытие стекла стоит посмотреть глазами.
- Иконки Lucide зависят от внешнего файла по ссылке `Majestic.Icons.LucideUrl`.
- Размытие Liquid Glass зависит от `DepthOfField` и настроек графики клиента.
- Key System защищает только настолько, насколько надёжна твоя проверка ключа.
