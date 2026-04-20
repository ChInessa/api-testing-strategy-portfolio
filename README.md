# API Autotests (Postman + Newman + Allure)

##  Live demo

👉 https://chinessa.github.io/api-testing-strategy-portfolio/

##  CI/CD

![GitHub Actions](https://github.com/ChInessa/api-testing-strategy-portfolio/actions/workflows/api-tests.yml/badge.svg)

---

Репозиторий демонстрирует подход к автоматизированному тестированию API с использованием Postman/Newman, генерацией Allure-отчётов и построением CI/CD pipeline на GitHub Actions.
---

## Описание проекта

Проект реализует систему автоматизированного тестирования API с поддержкой smoke и regression сценариев.

Основные задачи:
- регулярная проверка стабильности API;
- визуализация результатов тестирования;
- анализ трендов качества;
- интеграция тестирования в CI/CD процесс.

---

## Скриншоты

### Дашборд отчётов
![Dashboard](docs/dashboard.png)

### Allure — обзор
![Allure Overview](docs/allure-overview.png)

### Тесты в Allure
![Allure Tests](docs/allure-tests.png)

### CI/CD pipeline
![Pipeline](docs/pipeline.png)

---

## Основной функционал

- запуск smoke и regression тестов через Newman;
- генерация отчётов в Allure;
- сбор и хранение результатов выполнения;
- анализ причин падения тестов;
- разделение тестов по окружениям (dev, test);
- запуск тестов через GitHub Actions (push и manual trigger).

---

## CI/CD

Pipeline реализован на GitHub Actions и демонстрирует процесс:

test -> artifacts

- test — запуск автотестов (smoke / regression);
- artifacts — сохранение результатов выполнения (reports, allure-results).

Особенности:
- smoke тесты запускаются автоматически при push в main;
- regression тесты запускаются вручную;
- pipeline не прерывается при падении тестов (continue-on-error);
- результаты сохраняются как артефакты.

---

## Структура проекта

postman/
  collections/
  environments/

scripts/
  run-newman.sh

ci/
  scripts/

.github/
  workflows/

Dockerfile
package.json
README.md

---

## Локальный запуск

npm install

npm run test:smoke

npm run test:regression

---

## Стек технологий

- Postman
- Newman
- Allure
- GitHub Actions
- Bash / Shell
- JavaScript
- Python
- Docker

---

## Ограничения публичной версии

Данный репозиторий является демонстрационной версией.

Реальные автотесты в рабочем проекте выполняются:
- во внутренней инфраструктуре;
- с использованием VPN;
- с приватными Docker-образами и секретами.

В публичной версии:
- отключены реальные интеграции;
- используются демо-данные;
- CI/CD pipeline демонстрирует архитектуру и процесс выполнения.

---

## Для резюме

Проект демонстрирует:
- построение автоматизации API-тестирования;
- интеграцию тестов в CI/CD pipeline;
- организацию отчётности и анализа результатов;
- работу с инструментами Postman, Newman, Allure и GitHub Actions.
