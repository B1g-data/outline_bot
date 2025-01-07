#!/bin/bash

# URL репозитория для скачивания
REPO_URL="https://github.com/B1g-data/outline_bot.git"
BRANCH="test"

# Получение списка контейнеров
CONTAINERS=$(docker ps -a --filter "name=^tg_outline_bot" --format "{{.Names}}")

# Запрос действия у пользователя
if [ -z "$CONTAINERS" ]; then
  echo "Нет существующих контейнеров для обновления."
  exit 1
fi

echo "Список существующих контейнеров:"
echo "$CONTAINERS"
read -p "Введите имя контейнера, который хотите обновить: " CONTAINER_NAME

if ! echo "$CONTAINERS" | grep -q "^$CONTAINER_NAME$"; then
  echo "Контейнер с именем $CONTAINER_NAME не найден."
  exit 1
fi

# Клонирование репозитория в существующую папку
NEW_DIR="/opt/${CONTAINER_NAME}"
echo "Клонируем репозиторий в $NEW_DIR..."
rm -rf "$NEW_DIR"
git clone -b "$BRANCH" --single-branch "$REPO_URL" "$NEW_DIR" || { echo "Ошибка клонирования репозитория"; exit 1; }

echo "Репозиторий успешно обновлен."

# Создание .env файла или обновление существующего
ENV_FILE="$NEW_DIR/.env"

if [ -f "$ENV_FILE" ]; then
  echo "Найден существующий .env файл."
  read -p "Использовать данные из него? (y/n): " USE_EXISTING_ENV
  if [[ "$USE_EXISTING_ENV" =~ ^[Yy]$ ]]; then
    echo "Используем существующий .env файл."
  else
    echo "Запрашиваем новые данные для .env файла."
    # Запрос новых данных
    read -p "Введите API URL: " API_URL
    read -p "Введите SHA256 сертификата: " CERT_SHA256
    read -p "Введите токен Telegram-бота (https://t.me/BotFather): " TELEGRAM_BOT_TOKEN
    read -p "Введите ID пользователя (https://t.me/userinfobot): " ALLOWED_USER_ID
    # Создание нового .env файла
    echo "OUTLINE_API_URL=$API_URL" > "$ENV_FILE"
    echo "CERT_SHA256=$CERT_SHA256" >> "$ENV_FILE"
    echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN" >> "$ENV_FILE"
    echo "ALLOWED_USER_ID=$ALLOWED_USER_ID" >> "$ENV_FILE"
    echo "Новый .env файл создан."
  fi
else
  echo "Файл .env не найден. Запрашиваем данные для его создания."
  # Запрос данных для нового файла
  read -p "Введите API URL: " API_URL
  read -p "Введите SHA256 сертификата: " CERT_SHA256
  read -p "Введите токен Telegram-бота (https://t.me/BotFather): " TELEGRAM_BOT_TOKEN
  read -p "Введите ID пользователя (https://t.me/userinfobot): " ALLOWED_USER_ID
  # Создание нового .env файла
  echo "OUTLINE_API_URL=$API_URL" > "$ENV_FILE"
  echo "CERT_SHA256=$CERT_SHA256" >> "$ENV_FILE"
  echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN" >> "$ENV_FILE"
  echo "ALLOWED_USER_ID=$ALLOWED_USER_ID" >> "$ENV_FILE"
  echo "Новый .env файл создан."
fi

# Сборка и запуск контейнера
cd "$NEW_DIR" || { echo "Ошибка перехода в директорию $NEW_DIR"; exit 1; }

IMAGE_NAME="tg_outline_bot"
echo "Собираем Docker-образ..."
docker build -t "$IMAGE_NAME" . || { echo "Ошибка сборки Docker-образа"; exit 1; }

echo "Запускаем контейнер..."
docker run -d --name "$IMAGE_NAME" --restart always --env-file "$ENV_FILE" "$IMAGE_NAME" || { echo "Ошибка запуска контейнера"; exit 1; }

echo "Контейнер $IMAGE_NAME успешно запущен."
