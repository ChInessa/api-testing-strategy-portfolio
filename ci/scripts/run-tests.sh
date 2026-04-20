#!/usr/bin/env bash
set -euo pipefail

# Скрипт запускает API-тесты через Newman,
# сохраняет лог выполнения и формирует причину падения для CI.

# Проверяем обязательные аргументы:
# $1 — набор тестов (smoke / regression)
# $2 — файл окружения Postman
if [ "$#" -lt 2 ]; then
  echo "Ошибка: не переданы обязательные аргументы."
  echo "Использование: $0 <suite> <env_file>"
  exit 1
fi

SUITE="$1"
ENV_FILE="$2"

# Создаём директории для результатов и логов
mkdir -p "allure-results/$SUITE"
mkdir -p "reports/htmlextra/$SUITE"
mkdir -p "reports"

# Определяем, какой CLIENT_SECRET использовать в зависимости от окружения
if [[ "$ENV_FILE" == *"dev.json" ]]; then
  export CLIENT_SECRET="${CLIENT_SECRET_DEV:-}"
elif [[ "$ENV_FILE" == *"test.json" ]]; then
  export CLIENT_SECRET="${CLIENT_SECRET_TEST:-}"
else
  export CLIENT_SECRET="${CLIENT_SECRET:-}"
fi

# Если секрет не найден, работаем в демонстрационном режиме.
# Это нужно для публичной версии проекта в GitHub.
if [[ -z "${CLIENT_SECRET:-}" ]]; then
  echo "CLIENT_SECRET не задан для файла окружения: $ENV_FILE"
  echo "Запуск выполняется в демонстрационном режиме"
fi

# Запускаем Newman.
# Временно отключаем строгий выход по ошибке, чтобы:
# - сохранить код возврата команды,
# - записать лог через tee,
# - после этого отдельно обработать причину падения.
set +e
bash scripts/run-newman.sh "$SUITE" "$ENV_FILE" \
  2>&1 | tee "reports/newman-$SUITE.log"
EXIT_CODE=${PIPESTATUS[0]}
set -e

# Формируем человекочитаемую причину падения для CI
bash ci/scripts/failure-reason.sh "$SUITE" "$EXIT_CODE"

# Возвращаем исходный код выполнения тестов
exit "$EXIT_CODE"
