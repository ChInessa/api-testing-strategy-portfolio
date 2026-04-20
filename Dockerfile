# Образ для запуска API-автотестов и генерации Allure-отчётов
FROM node:18-bullseye

# Версия Allure CLI
ENV ALLURE_VERSION=2.29.0

# Отключаем интерактивные вопросы при установке пакетов
ENV DEBIAN_FRONTEND=noninteractive

# Рабочая директория внутри контейнера
WORKDIR /app

# Устанавливаем системные зависимости:
# - default-jre: нужен для Allure
# - curl, unzip: нужны для скачивания и распаковки
# - git: нужен для работы с репозиторием
# - python3: нужен для генерации dashboard-страницы
# - rsync: используется в скриптах публикации и синхронизации отчётов
# - jq: полезен для обработки JSON при необходимости
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-jre \
    curl \
    unzip \
    git \
    python3 \
    rsync \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Устанавливаем глобальные npm-пакеты для запуска API-тестов и генерации отчётов
RUN npm install -g \
    newman \
    newman-reporter-htmlextra \
    newman-reporter-allure

# Скачиваем и устанавливаем Allure CLI
RUN curl -o /tmp/allure.tgz -Ls "https://github.com/allure-framework/allure2/releases/download/${ALLURE_VERSION}/allure-${ALLURE_VERSION}.tgz" \
    && tar -xzf /tmp/allure.tgz -C /opt \
    && ln -sf "/opt/allure-${ALLURE_VERSION}/bin/allure" /usr/local/bin/allure \
    && rm -f /tmp/allure.tgz

# Команда по умолчанию при запуске контейнера
CMD ["bash"]
