#!/usr/bin/env bash
set -euo pipefail

# Скрипт запускает Newman для выбранного набора тестов,
# сохраняет лог, Allure-результаты и HTML-отчёт.

# Определяем корень проекта
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Аргументы:
# $1 — набор тестов (smoke / regression)
# $2 — файл окружения Postman
# Если аргументы не переданы, используем значения по умолчанию
SUITE="${1:-smoke}"
ENV_FILE="${2:-$PROJECT_ROOT/postman/environments/dev.json}"

# Определяем, какую коллекцию запускать в зависимости от набора тестов
case "$SUITE" in
  smoke)
    COLLECTION="$PROJECT_ROOT/postman/collections/smoke.postman_collection.json"
    ;;
  regression)
    COLLECTION="$PROJECT_ROOT/postman/collections/regression.postman_collection.json"
    ;;
  *)
    echo "Ошибка: неизвестный набор тестов: $SUITE"
    echo "Использование: bash scripts/run-newman.sh [smoke|regression] [environment_file]"
    exit 1
    ;;
esac

# Пути для артефактов запуска
ALLURE_DIR="$PROJECT_ROOT/allure-results/$SUITE"
HTML_DIR="$PROJECT_ROOT/reports/htmlextra/$SUITE"
LOG_DIR="$PROJECT_ROOT/reports"
LOG_FILE="$LOG_DIR/newman-$SUITE.log"

# Создаём директории для результатов
mkdir -p "$ALLURE_DIR" "$HTML_DIR" "$LOG_DIR"

# Выводим параметры запуска
echo "Запуск Newman"
echo "Набор тестов: $SUITE"
echo "Коллекция: $COLLECTION"
echo "Файл окружения: $ENV_FILE"

# Проверяем, что файл коллекции существует
if [ ! -f "$COLLECTION" ]; then
  echo "Ошибка: файл коллекции не найден: $COLLECTION"
  exit 1
fi

# Проверяем, что файл окружения существует
if [ ! -f "$ENV_FILE" ]; then
  echo "Ошибка: файл окружения не найден: $ENV_FILE"
  exit 1
fi

# Формируем аргументы Newman
NEWMAN_ARGS=(
  run "$COLLECTION"
  -e "$ENV_FILE"
  -r cli,allure,htmlextra
  --reporter-allure-resultsDir "$ALLURE_DIR"
  --reporter-htmlextra-export "$HTML_DIR/index.html"
  --timeout-request 10000
  --timeout-script 10000
  --timeout 20000
)

# Если CLIENT_SECRET задан, добавляем его в запуск.
# Если нет — выполняем запуск в демонстрационном режиме.
if [[ -n "${CLIENT_SECRET:-}" ]]; then
  echo "Режим запуска: с CLIENT_SECRET"
  NEWMAN_ARGS+=(--env-var "client_secret=$CLIENT_SECRET")
else
  echo "Режим запуска: демонстрационный (CLIENT_SECRET не задан)"
fi

# Запускаем Newman.
# Временно отключаем строгий выход по ошибке,
# чтобы сохранить код возврата команды при использовании tee.
set +e
npx newman "${NEWMAN_ARGS[@]}" 2>&1 | tee "$LOG_FILE"
EXIT_CODE=${PIPESTATUS[0]}
set -e

# Выводим итоговую информацию по запуску
echo "Код завершения Newman: $EXIT_CODE"
echo "Папка Allure-результатов: $ALLURE_DIR"
echo "Папка HTML-отчёта: $HTML_DIR"
echo "Файл лога: $LOG_FILE"

# Возвращаем исходный код завершения Newman
exit "$EXIT_CODE"
