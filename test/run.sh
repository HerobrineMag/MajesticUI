#!/bin/sh
# Собирает бандл и гоняет smoke-тест на заглушке Roblox API.
# Использование: LUAU=/путь/к/luau ./test/run.sh   (по умолчанию ищет `luau` в PATH)
cd "$(dirname "$0")/.." || exit 1
LUAU="${LUAU:-luau}"
python3 build.py test/bundle.lua >/dev/null || exit 1
{
  cat test/mock.lua
  echo "local function loadBundle()"
  cat test/bundle.lua
  echo "end"
  cat test/smoke.lua
} > test/run.lua
"$LUAU" test/run.lua
