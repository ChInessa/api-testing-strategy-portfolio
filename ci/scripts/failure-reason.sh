#!/usr/bin/env bash
set -euo pipefail

# Скрипт анализирует лог Newman и определяет причину падения тестов.
# Результат записывается в файл reports/failure_reason_<suite>.txt

# Проверяем аргументы:
# $1 — набор тестов (smoke / regression)
# $2 — код возврата Newman
if [ "$#" -lt 2 ]; then
  echo "Ошибка: не переданы аргументы."
  echo "Использование: $0 <suite> <exit_code>"
  exit 1
fi

SUITE="$1"
EXIT_CODE="$2"

LOG_FILE="reports/newman-${SUITE}.log"
OUTPUT_FILE="reports/failure_reason_${SUITE}.txt"

# Значение по умолчанию
FAILURE_REASON="No failure"

# Если лог отсутствует — это уже проблема
if [ ! -f "$LOG_FILE" ]; then
  echo "Лог не найден: $LOG_FILE"
  echo "Log not found" > "$OUTPUT_FILE"
  exit 0
fi

# Определяем причину падения по содержимому логов
if grep -q "ECONNREFUSED" "$LOG_FILE"; then
  FAILURE_REASON="Backend unavailable"

elif grep -q "500 Internal Server Error" "$LOG_FILE"; then
  FAILURE_REASON="500 error"

elif grep -q "<!doctype html>" "$LOG_FILE"; then
  FAILURE_REASON="Auth returned HTML (возможно ошибка авторизации)"

# Если Newman вернул ненулевой код, но явная причина не найдена
elif [ "$EXIT_CODE" -ne 0 ]; then
  FAILURE_REASON="Newman failures (см. лог)"
fi

# Записываем результат
echo "$FAILURE_REASON" > "$OUTPUT_FILE"

# Для удобства — выводим в консоль (будет видно в CI)
echo "Причина падения: $FAILURE_REASON"