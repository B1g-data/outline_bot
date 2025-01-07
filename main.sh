#!/bin/bash

# URL репозитория для скачивания
REPO_URL="https://github.com/B1g-data/outline_bot.git"
BRANCH="test"

# Запрос действия у пользователя
echo "Что вы хотите сделать?"
echo "1. Обновить существующий контейнер"
echo "2. Создать новый контейнер"
read -p "Выберите действие (1 или 2): " ACTION

# Получение списка контейнеров
CONTAINERS=$(docker ps -a --filter "name=^tg_outline_bot" --format "{{.Names}}")

if [[ "$ACTION" == "1" ]]; then
  # Обновление существующего контейнера
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

  # Клонирование репозитория в новую папку
  NEW_DIR="/opt/${CONTAINER_NAME}"
  echo "Клонируем репозиторий в $NEW_DIR..."
  rm -rf "$NEW_DIR"
  git clone -b "$BRANCH" --single-branch "$REPO_URL" "$NEW_DIR" || { echo "Ошибка клонирования репозитория"; exit 1; }

  # Обновление Dockerfile
  echo "Обновляем Dockerfile..."
  sed -i "s|WORKDIR /opt/.*|WORKDIR $NEW_DIR|g" "$NEW_DIR/Dockerfile"

elif [[ "$ACTION" == "2" ]]; then
  # Создание нового контейнера
  read -p "Введите суффикс для нового контейнера (например, 'v2'): " SUFFIX

  # Проверка существования контейнера с таким суффиксом
  while docker ps -a --filter "name=^tg_outline_bot_${SUFFIX}$" --format "{{.Names}}" | grep -q "."; do
    echo "Контейнер с суффиксом $SUFFIX уже существует. Введите другой суффикс."
    read -p "Введите новый суффикс: " SUFFIX
  done

  # Клонирование репозитория в новую папку
  NEW_DIR="/opt/tg_outline_bot_${SUFFIX}"
  echo "Клонируем репозиторий в $NEW_DIR..."
  rm -rf "$NEW_DIR"
  git clone -b "$BRANCH" --single-branch "$REPO_URL" "$NEW_DIR" || { echo "Ошибка клонирования репозитория"; exit 1; }

  # Обновление Dockerfile
  echo "Обновляем Dockerfile..."
  sed -i "s|WORKDIR /opt/.*|WORKDIR $NEW_DIR|g" "$NEW_DIR/Dockerfile"

else
  echo "Некорректный выбор. Завершаем работу."
  exit 1
fi

# Создание .env файла
ENV_FILE="$NEW_DIR/.env"
if [ -f "$NEW_DIR/access.txt" ]; then
  read -p "Файл access.txt найден. Хотите извлечь данные оттуда? (y/n): " USE_ACCESS
  if [[ "$USE_ACCESS" == "y" ]]; then
    API_URL=$(grep -oP '(?<=apiUrl:).*' "$NEW_DIR/access.txt")
    CERT_SHA256=$(grep -oP '(?<=certSha256:).*' "$NEW_DIR/access.txt")
  else
    read -p "Введите API URL: " API_URL
    read -p "Введите SHA256 сертификата: " CERT_SHA256"
  fi
else
  read -p "Введите API URL: " API_URL
  read -p "Введите SHA256 сертификата: " CERT_SHA256
fi
echo "OUTLINE_API_URL=$API_URL" > "$ENV_FILE"
echo "CERT_SHA256=$CERT_SHA256" >> "$ENV_FILE"

# Запрос токена бота и ID пользователя
while true; do
  read -p "Введите токен Telegram-бота: " TELEGRAM_BOT_TOKEN
  if [[ "$TELEGRAM_BOT_TOKEN" =~ ^[0-9]{9,15}:[A-Za-z0-9_-]{35,45}$ ]]; then
    echo "Формат токена правильный."
    break
  else
    echo "Ошибка: Неверный формат токена. Попробуйте снова."
  fi
done

while true; do
  read -p "Введите ID пользователя: " USER_ID
  if [[ "$USER_ID" =~ ^[0-9]+$ ]]; then
    echo "ID пользователя корректен."
    break
  else
    echo "Ошибка: Некорректный ID пользователя."
  fi
done

echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN" >> "$ENV_FILE"
echo "ALLOWED_USER_ID=$USER_ID" >> "$ENV_FILE"

# Сборка и запуск контейнера
cd "$NEW_DIR" || { echo "Ошибка перехода в директорию $NEW_DIR"; exit 1; }
IMAGE_NAME="tg_outline_bot_${SUFFIX}"
echo "Собираем Docker-образ..."
docker build -t "$IMAGE_NAME" . || { echo "Ошибка сборки Docker-образа"; exit 1; }

echo "Запускаем контейнер..."
docker run -d --name "tg_outline_bot_${SUFFIX}" --restart always --env-file "$ENV_FILE" "$IMAGE_NAME" || { echo "Ошибка запуска контейнера"; exit 1; }

echo "Контейнер tg_outline_bot_${SUFFIX} успешно запущен."
