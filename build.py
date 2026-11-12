#!/usr/bin/env python3
"""Собирает все модули из src/ в один файл Majestic.lua (подключается одним loadstring).

    python3 build.py            -> ./Majestic.lua
    python3 build.py out.lua    -> out.lua
"""
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, "src")
VERSION = "2.0.0"

# порядок не важен для работы (import ленивый), но так проще читать бандл
ORDER = [
    "Core/Env", "Core/State", "Core/Theme", "Core/Util", "Core/Shapes", "Core/MaterialData", "Core/Gui", "Core/Icons",
    "Core/Glass", "Core/Config",
    "Core/Container", "Core/Element", "Core/Window",
    "Elements/Basic", "Elements/Slider", "Elements/Dropdown", "Elements/Input",
    "Elements/ColorPicker", "Elements/Table", "Elements/Group",
    "Systems/Notify", "Systems/Dialog", "Systems/Loading", "Systems/KeySystem",
    "Systems/Home", "Systems/Managers",
    "init",
]

HEADER = f"""--!nonstrict
--[[
	Majestic UI Library v{VERSION}
	Собрано из модулей build.py. Документация: Documentation.md

	local Majestic = loadstring(game:HttpGet("URL/Majestic.lua"))()
	local Window = Majestic:Window("Hub", "v1.0")
	local Tab = Window:Tab("Main", "home")
	Tab:Toggle("Auto Farm", false, function(v) print(v) end)
]]

local __defs, __cache = {{}}, {{}}
local function import(name)
	local cached = __cache[name]
	if cached ~= nil then
		return cached
	end
	local def = __defs[name]
	if not def then
		error("[Majestic] unknown module: " .. tostring(name))
	end
	local result = def()
	if result == nil then
		result = true
	end
	__cache[name] = result
	return result
end
"""


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "Majestic.lua")
    parts = [HEADER]
    on_disk = set()
    for dirpath, _, files in os.walk(SRC):
        for f in files:
            if f.endswith(".lua"):
                rel = os.path.relpath(os.path.join(dirpath, f), SRC)[:-4].replace(os.sep, "/")
                on_disk.add(rel)
    missing = [m for m in ORDER if m not in on_disk]
    extra = sorted(on_disk - set(ORDER))
    if missing:
        sys.exit(f"нет файлов для модулей: {missing}")
    if extra:
        sys.exit(f"модули не добавлены в ORDER: {extra}")

    for name in ORDER:
        with open(os.path.join(SRC, name + ".lua"), encoding="utf-8") as fh:
            body = fh.read().rstrip() + "\n"
        parts.append(f'\n__defs["{name}"] = function()\n{body}end\n')
    parts.append('\nreturn import("init")\n')

    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("".join(parts))
    total = sum(p.count("\n") for p in parts)
    print(f"собрано: {out_path} ({total} строк, {len(ORDER)} модулей)")


if __name__ == "__main__":
    main()
