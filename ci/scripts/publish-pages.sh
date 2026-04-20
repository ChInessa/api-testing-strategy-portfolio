#!/usr/bin/env bash
set -euo pipefail

# Настройка git-автора для коммитов из CI
git config --global user.name "gitlab-ci"
git config --global user.email "gitlab-ci@example.com"

# Проверка обязательных переменных окружения
: "${REPORT_ENV:?Переменная REPORT_ENV не задана}"
: "${CI_PIPELINE_ID:?Переменная CI_PIPELINE_ID не задана}"
: "${CI_SERVER_HOST:?Переменная CI_SERVER_HOST не задана}"
: "${CI_PROJECT_PATH:?Переменная CI_PROJECT_PATH не задана}"
: "${GL_PAGES_PUSH_TOKEN:?Переменная GL_PAGES_PUSH_TOKEN не задана}"

# Клонируем репозиторий в отдельную папку для работы с веткой gl-pages
git clone "https://oauth2:${GL_PAGES_PUSH_TOKEN}@${CI_SERVER_HOST}/${CI_PROJECT_PATH}.git" repo-pages

cd repo-pages

# Подтягиваем удалённые ветки и переключаемся на gl-pages
git fetch origin
git checkout gl-pages || git checkout -b gl-pages origin/gl-pages || git checkout -b gl-pages

# Гарантируем наличие базовой структуры каталогов
mkdir -p public/dev
mkdir -p public/test-stand
mkdir -p public/dev/archive
mkdir -p public/test-stand/archive

cd ..

# Дата публикации текущего pipeline
PIPELINE_DATE="${CI_PIPELINE_CREATED_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

# -----------------------------
# Публикация latest + archive для smoke
# -----------------------------
mkdir -p "repo-pages/public/${REPORT_ENV}"
mkdir -p "repo-pages/public/${REPORT_ENV}/archive"

if [ -d "site/${REPORT_ENV}/smoke" ]; then
  mkdir -p "repo-pages/public/${REPORT_ENV}/smoke"
  mkdir -p "repo-pages/public/${REPORT_ENV}/archive/smoke-${CI_PIPELINE_ID}"

  # Обновляем latest smoke
  rsync -a --delete "site/${REPORT_ENV}/smoke/" "repo-pages/public/${REPORT_ENV}/smoke/"

  # Сохраняем архивную копию smoke для текущего pipeline
  rsync -a --delete "site/${REPORT_ENV}/smoke/" "repo-pages/public/${REPORT_ENV}/archive/smoke-${CI_PIPELINE_ID}/"

  # Записываем дату публикации архива
  echo "${PIPELINE_DATE}" > "repo-pages/public/${REPORT_ENV}/archive/smoke-${CI_PIPELINE_ID}/.published_at"
fi

# -----------------------------
# Публикация latest + archive для regression
# Только для test-stand
# -----------------------------
if [ "${REPORT_ENV}" = "test-stand" ] && [ -d "site/${REPORT_ENV}/regression" ]; then
  mkdir -p "repo-pages/public/${REPORT_ENV}/regression"
  mkdir -p "repo-pages/public/${REPORT_ENV}/archive/regression-${CI_PIPELINE_ID}"

  # Обновляем latest regression
  rsync -a --delete "site/${REPORT_ENV}/regression/" "repo-pages/public/${REPORT_ENV}/regression/"

  # Сохраняем архивную копию regression для текущего pipeline
  rsync -a --delete "site/${REPORT_ENV}/regression/" "repo-pages/public/${REPORT_ENV}/archive/regression-${CI_PIPELINE_ID}/"

  # Записываем дату публикации архива
  echo "${PIPELINE_DATE}" > "repo-pages/public/${REPORT_ENV}/archive/regression-${CI_PIPELINE_ID}/.published_at"
fi

# -----------------------------
# Очистка старых архивов по количеству
# Оставляем только последние архивы:
# - smoke: 10
# - regression: 5
# -----------------------------
cleanup_archives() {
  local base_dir="$1"
  local prefix="$2"
  local keep_count="$3"

  # Если каталога нет, очищать нечего
  if [ ! -d "$base_dir" ]; then
    return 0
  fi

  # Собираем список каталогов архива и сортируем по имени в обратном порядке.
  # Так как в имени есть pipeline id, сверху будут самые новые прогоны.
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

cleanup_archives "repo-pages/public/dev/archive" "smoke" 10
cleanup_archives "repo-pages/public/test-stand/archive" "smoke" 10
cleanup_archives "repo-pages/public/test-stand/archive" "regression" 5

# -----------------------------
# Генерация главной страницы с дашбордом
# -----------------------------
python3 ci/scripts/generate-reports-dashboard.py

cd repo-pages

# Добавляем изменения в git
git add public

# Коммитим только если действительно есть изменения
if ! git diff --cached --quiet; then
  git commit -m "Publish ${REPORT_ENV} reports ${CI_PIPELINE_ID}"
else
  echo "Изменений для коммита нет"
fi

# Подтягиваем актуальное состояние ветки и отправляем изменения
git pull --rebase origin gl-pages || {
  git rebase --abort || true
  echo "Не удалось выполнить rebase на gl-pages"
  exit 1
}

git push origin gl-pages