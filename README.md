# Majestic

UI-библиотека для Roblox-экзекуторов: простой синтаксис, много элементов, группы и колонки, поиск по меню,
конфиги и темы, Liquid Glass, Key System, иконки Lucide и Material, адаптация под телефон.

## Подключение

```lua
local Majestic = loadstring(game:HttpGet("https://raw.githubusercontent.com/HerobrineMag/MajesticUI/refs/heads/main/Majestic/Majestic.lua"))()
```

## Быстрый старт

```lua
local Window = Majestic:Window({ Title = "Мой хаб"; Subtitle = "v1.0"; Icon = "home"; IconUrl = "Lucide" })
local Tab = Window:Tab({ Name = "Main"; Icon = "swords" })

Tab:Toggle({
    Name = "Auto Farm";
    Default = false;
    Callback = function(v)
        print("Auto Farm:", v)
    end;
})

Tab:Slider({
    Name = "WalkSpeed"; Min = 16; Max = 200; Default = 16;
    Callback = function(v)
        print(v)
    end;
})

Window:Settings() -- тема, масштаб, Liquid Glass, конфиги, редактор тем
```

Полный пример: [Example.lua](Example.lua). Справочник по API: [Documentation.md](Documentation.md).

## Что внутри

- Элементы: Toggle, Slider, RangeSlider, Dropdown (поиск вводом, мульти-выбор), Input, Keybind, ColorPicker (с альфой),
  Button, Label, Paragraph, Image, Progress, Table.
- Контейнеры: Group (сворачиваемая карточка), Columns.
- Иконки Lucide и Material (`IconUrl = "Lucide"` или `"Material"`), поиск по всем элементам, тултипы, уведомления, диалоги.
- Liquid Glass: прозрачные панели и размытие фона, настраиваются оттенок, размытие и прозрачность.
- Загрузочный экран, Home-вкладка со статистикой сервера, Key System.
- Конфиги с автозагрузкой, редактор тем, 7 встроенных тем.

## Разработка

Исходники лежат в `src/`, а `Majestic.lua` собирается из них:

```
python3 build.py        # пересобрать Majestic.lua
```

Автотесты запускаются на заглушке Roblox API (нужен бинарник [luau](https://github.com/luau-lang/luau/releases)):

```
LUAU=/путь/к/luau ./test/run.sh
```

После изменений в `src/` пересобери `Majestic.lua` и закоммить его вместе с исходниками.

## Лицензии и авторы

Набор иконок Material (`src/Core/MaterialData.lua`) взят из проекта Luna Interface Suite (BSD-3, Nebula Softworks,
иконки qweery), текст лицензии находится в начале файла.
Иконки Lucide загружаются с внешней ссылки.

## Статус

Библиотека проверена анализатором Luau и тестами на заглушке API, но запускалась не во всех играх и экзекуторах.
Если что-то работает не так, открой issue и приложи ошибку из консоли.
