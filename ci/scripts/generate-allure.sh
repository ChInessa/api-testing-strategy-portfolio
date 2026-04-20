#!/usr/bin/env bash
set -euo pipefail

# Скрипт:
# 1. подготавливает history для Allure,
# 2. создаёт executor.json и environment.properties,
# 3. генерирует готовый HTML-отчёт в папку site.

# Проверяем обязательный аргумент:
# $1 — набор тестов (smoke / regression)
if [ "$#" -lt 1 ]; then
  echo "Ошибка: не передан набор тестов."
  echo "Использование: $0 <suite>"
  exit 1
fi

SUITE="$1"

# Проверяем обязательные переменные окружения
: "${REPORT_ENV:?Ошибка: переменная REPORT_ENV не задана}"
: "${REPORT_BASE:?Ошибка: переменная REPORT_BASE не задана}"
: "${CI_PIPELINE_ID:?Ошибка: переменная CI_PIPELINE_ID не задана}"
: "${CI_PIPELINE_URL:?Ошибка: переменная CI_PIPELINE_URL не задана}"
: "${CI_SERVER_URL:?Ошибка: переменная CI_SERVER_URL не задана}"
: "${CI_COMMIT_REF_NAME:?Ошибка: переменная CI_COMMIT_REF_NAME не задана}"
: "${CI_COMMIT_SHA:?Ошибка: переменная CI_COMMIT_SHA не задана}"
: "${PAGES_BRANCH:?Ошибка: переменная PAGES_BRANCH не задана}"

# Дата запуска в удобочитаемом формате
RUN_DATE_HUMAN="$(date +"%Y-%m-%d %H:%M:%S %Z")"

# Ссылки и идентификаторы сборки для Allure
BUILD_URL="${CI_PIPELINE_URL}"
BUILD_ORDER="${CI_PIPELINE_ID}"

# Формируем человекочитаемые названия сборки и отчёта
if [ "$SUITE" = "smoke" ]; then
  BUILD_NAME="Smoke pipeline ${CI_PIPELINE_ID} ${RUN_DATE_HUMAN}"
  REPORT_NAME="${REPORT_ENV} smoke"
else
  BUILD_NAME="Regression pipeline ${CI_PIPELINE_ID} ${RUN_DATE_HUMAN}"
  REPORT_NAME="${REPORT_ENV} regression"
fi

# Ссылка на архивный отчёт конкретного pipeline
REPORT_URL="${REPORT_BASE}/${REPORT_ENV}/archive/${SUITE}-${CI_PIPELINE_ID}/"

# Создаём базовую директорию для результатов Allure
mkdir -p "allure-results/$SUITE"

# Подтягиваем history из gh-pages, если ветка существует
if git ls-remote --exit-code github "${PAGES_BRANCH}" >/dev/null 2>&1; then
  git clone --depth 1 --branch "${PAGES_BRANCH}" "$(git remote get-url github)" repo-history
fi

# Копируем history предыдущего отчёта, если он существует
mkdir -p "allure-results/$SUITE/history"
if [ -d "repo-history/${REPORT_ENV}/${SUITE}/history" ]; then
  cp -r "repo-history/${REPORT_ENV}/${SUITE}/history/"* "allure-results/$SUITE/history/" 2>/dev/null || true
fi

# Формируем executor.json — метаданные о запуске в GitHub Actions
python3 - <<PY
import json

data = {
    "name": "GitHub Actions",
    "type": "github",
    "url": "${CI_SERVER_URL}",
    "buildOrder": int("${BUILD_ORDER}"),
    "buildName": "${BUILD_NAME}",
    "buildUrl": "${BUILD_URL}",
    "reportName": "${REPORT_NAME}",
    "reportUrl": "${REPORT_URL}",
}

with open("allure-results/${SUITE}/executor.json", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False)
PY

# Читаем причину падения тестов
FAILURE_REASON="$(cat "reports/failure_reason_${SUITE}.txt" 2>/dev/null || echo "No failure")"

# Формируем environment.properties
{
  echo "environment=${REPORT_ENV}"
  echo "suite=${SUITE}"
  echo "branch=${CI_COMMIT_REF_NAME}"
  echo "pipeline_id=${CI_PIPELINE_ID}"
  echo "pipeline_url=${CI_PIPELINE_URL}"
  echo "commit_sha=${CI_COMMIT_SHA}"
  echo "postman_env=${POSTMAN_ENV:-}"
  echo "run_date=${RUN_DATE_HUMAN}"
  echo "failure_reason=${FAILURE_REASON}"
} > "allure-results/$SUITE/environment.properties"

# Генерируем HTML-отчёт Allure
mkdir -p "site/${REPORT_ENV}/${SUITE}"
allure generate "allure-results/$SUITE" -o "site/${REPORT_ENV}/${SUITE}" --clean

# Проверяем, что итоговый отчёт действительно создан
test -f "site/${REPORT_ENV}/${SUITE}/index.html"
