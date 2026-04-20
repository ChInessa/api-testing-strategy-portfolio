#!/usr/bin/env bash
set -euo pipefail

# Настройка git-автора для коммитов из CI
git config --global user.name "github-actions"
git config --global user.email "github-actions@users.noreply.github.com"

# Проверка обязательных переменных окружения
: "${REPORT_ENV:?Переменная REPORT_ENV не задана}"
: "${CI_PIPELINE_ID:?Переменная CI_PIPELINE_ID не задана}"
: "${PAGES_BRANCH:?Переменная PAGES_BRANCH не задана}"

# Подтягиваем gh-pages, если она существует
if git ls-remote --exit-code origin "${PAGES_BRANCH}" >/dev/null 2>&1; then
  git clone --depth 1 --branch "${PAGES_BRANCH}" . repo-pages
else
  git clone . repo-pages
  cd repo-pages
  git checkout --orphan "${PAGES_BRANCH}"
  git rm -rf . >/dev/null 2>&1 || true
  cd ..
fi

cd repo-pages

mkdir -p dev
mkdir -p test
mkdir -p dev/archive
mkdir -p test/archive

cd ..

# Дата публикации текущего pipeline
PIPELINE_DATE="${CI_PIPELINE_CREATED_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

# Публикация latest + archive для smoke
mkdir -p "repo-pages/${REPORT_ENV}"
mkdir -p "repo-pages/${REPORT_ENV}/archive"

if [ -d "site/${REPORT_ENV}/smoke" ]; then
  mkdir -p "repo-pages/${REPORT_ENV}/smoke"
  mkdir -p "repo-pages/${REPORT_ENV}/archive/smoke-${CI_PIPELINE_ID}"

  rsync -a --delete "site/${REPORT_ENV}/smoke/" "repo-pages/${REPORT_ENV}/smoke/"
  rsync -a --delete "site/${REPORT_ENV}/smoke/" "repo-pages/${REPORT_ENV}/archive/smoke-${CI_PIPELINE_ID}/"

  echo "${PIPELINE_DATE}" > "repo-pages/${REPORT_ENV}/archive/smoke-${CI_PIPELINE_ID}/.published_at"
fi

# Публикация latest + archive для regression
if [ "${REPORT_ENV}" = "test" ] && [ -d "site/${REPORT_ENV}/regression" ]; then
  mkdir -p "repo-pages/${REPORT_ENV}/regression"
  mkdir -p "repo-pages/${REPORT_ENV}/archive/regression-${CI_PIPELINE_ID}"

  rsync -a --delete "site/${REPORT_ENV}/regression/" "repo-pages/${REPORT_ENV}/regression/"
  rsync -a --delete "site/${REPORT_ENV}/regression/" "repo-pages/${REPORT_ENV}/archive/regression-${CI_PIPELINE_ID}/"

  echo "${PIPELINE_DATE}" > "repo-pages/${REPORT_ENV}/archive/regression-${CI_PIPELINE_ID}/.published_at"
fi

# Очистка старых архивов
cleanup_archives() {
  local base_dir="$1"
  local prefix="$2"
  local keep_count="$3"

  if [ ! -d "$base_dir" ]; then
    return 0
  fi

  mapfile -t dirs < <(find "$base_dir" -maxdepth 1 -mindepth 1 -type d -name "${prefix}-*" | sort -r)

  local total="${#dirs[@]}"
  if [ "$total" -le "$keep_count" ]; then
    echo "Для ${base_dir}/${prefix} очистка не требуется: всего ${total}, лимит ${keep_count}"
    return 0
  fi

  echo "Для ${base_dir}/${prefix} найдено ${total} архивов, оставляем ${keep_count}"

  for dir in "${dirs[@]:$keep_count}"; do
    echo "Удаляем старый архив: $dir"
    rm -rf "$dir"
  done
}

cleanup_archives "repo-pages/dev/archive" "smoke" 10
cleanup_archives "repo-pages/test/archive" "smoke" 10
cleanup_archives "repo-pages/test/archive" "regression" 5

# Генерация главной страницы с дашбордом
python3 ci/scripts/generate-reports-dashboard.py

cd repo-pages

git add .

if ! git diff --cached --quiet; then
  git commit -m "Publish ${REPORT_ENV} reports ${CI_PIPELINE_ID}"
else
  echo "Изменений для коммита нет"
fi

git push origin "${PAGES_BRANCH}"
