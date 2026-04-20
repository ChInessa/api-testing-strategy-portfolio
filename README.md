# Newman API autotests

Репозиторий для запуска API-автотестов через Postman / Newman с генерацией Allure-отчётов и публикацией в GitLab Pages.

---

## Назначение

Проект предназначен для автоматизированного тестирования API с использованием Postman/Newman.

Основные задачи:
- запуск smoke и regression тестов;
- генерация Allure-отчётов;
- публикация latest и archive отчётов в GitLab Pages;
- хранение истории прогонов и анализ трендов стабильности.

---

## Логика запусков

Проект использует две ветки с разным сценарием запуска тестов:

| Ветка        | Набор тестов | Расписание |
|--------------|--------------|------------|
| dev          | smoke        | ежедневно |
| test-stand   | smoke        | ежедневно |
| test-stand   | regression   | каждый понедельник |

Такое разделение позволяет:
- быстро отслеживать стабильность API в dev;
- регулярно прогонять полный регресс на test-stand.

---

## Отчёты

Общий индекс отчётов:

http://va.pages.videoanalytics.tech/qa/autotests/newman/

### Структура публикации

#### dev
- Latest smoke
- Archive smoke

#### test-stand
- Latest smoke
- Archive smoke
- Latest regression
- Archive regression

---

## Архитектура отчётов

Каждый прогон формирует:
- latest — актуальный отчёт;
- archive/<suite>-<pipeline_id> — архивный отчёт.

Принципы публикации:
- Allure history строится из latest;
- ссылки в trend-графике ведут в archive;
- dev и test-stand изолированы;
- smoke и regression разделены.

---

## Структура проекта

```
postman/
  collections/
  environments/

scripts/
  run-newman.sh

ci/
  scripts/
    run-tests.sh
    failure-reason.sh
    generate-allure.sh
    publish-pages.sh

.gitlab-ci.yml
README.md
```

---

## Локальный запуск

Установка зависимостей:

```bash
npm install
```

Запуск smoke:

```bash
npm run test:smoke
```

или:

```bash
bash scripts/run-newman.sh smoke
```

Запуск regression:

```bash
npm run test:regression
```

или:

```bash
bash scripts/run-newman.sh regression
```

---

## Локальные отчёты

HTML Extra:
```
reports/htmlextra/<suite>/index.html
```

Allure results:
```
allure-results/<suite>/
```

---

## CI pipeline

Pipeline:

```
test -> report -> publish -> pages
```

### Этапы:

- test  
  ci/scripts/run-tests.sh

- report  
  ci/scripts/generate-allure.sh

- publish  
  ci/scripts/publish-pages.sh

- pages  
  GitLab Pages

---

## Логика публикации

Публикация отчётов зависит от ветки:

### dev
- выполняется только smoke;
- публикуется latest и archive для smoke.

### test-stand
- выполняется smoke ежедневно;
- выполняется regression по расписанию (каждый понедельник);
- публикуется latest и archive для обоих наборов тестов.

---

## Хранение архивов

- smoke — 30 дней  
- regression — 120 дней  

---

## Особенности

- allow_failure для test job
- отчёты публикуются даже при падении тестов
- latest + archive
- dev — только smoke
- test-stand — smoke + regression
- ветка gl-pages без CI
