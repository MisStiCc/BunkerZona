#!/bin/bash
# Безопасный запуск headless-теста Godot (урок 03.11: taskkill /IM убивал
# игру и редактор владельца - они тот же exe!). Правила:
#   1) тест ОБЯЗАН сам звать get_tree().quit();
#   2) --quit-after N кадров - страховка от зависания;
#   3) добивание строго по PID запущенного процесса, НЕ по имени.
# Использование: bash run_test.sh <тест>.tscn [секунды_ожидания] [имя_лога]
TEST="$1"; WAIT="${2:-45}"; LOG="${3:-/tmp/test_out.txt}"
GODOT="/c/Users/VB/Desktop/Godot_v4.6.1-stable_win64.exe"
cd "$(dirname "$0")/../.." || exit 1
"$GODOT" --headless --path . --quit-after 30000 "res://$TEST" > "$LOG" 2>&1 &
GPID=$!
sleep "$WAIT"
kill -9 "$GPID" 2>/dev/null
wait "$GPID" 2>/dev/null
echo "done: $LOG"
