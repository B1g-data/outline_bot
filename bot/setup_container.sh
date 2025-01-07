#!/bin/bash

NEW_CONTAINER_NAME=$1
NEW_DIR="/opt/$NEW_CONTAINER_NAME"
REPO_URL="https://github.com/B1g-data/outline_bot.git"

# Создаем новую папку
mkdir -p "$NEW_DIR"

# Клонируем репозиторий
echo "Клонируем репозиторий в $NEW_DIR..."
git clone "$REPO_URL" "$NEW_DIR" || { echo "Ошибка клонирования репозитория"; exit 1; }

# Создаем .env файл
ENV_FILE="$NEW_DIR/.env"
read -p "Хотите извлечь данные из файла access.txt (y/n)? " extract_from_file

if [[ "$extract_from_file" == "y" || "$extract_from_file" == "Y" ]]; then
  if [ -f "$NEW_DIR/access.txt" ]; then
    API_URL=$(grep -oP '(?<=apiUrl:).*' "$NEW_DIR/access.txt")
    CERT_SHA256=$(grep -oP '(?<=certSha256:).*' "$NEW_DIR/access.txt")
    echo "OUTLINE_API_URL=$API_URL" > "$ENV_FILE"
    echo "CERT_SHA256=$CERT_SHA256" >> "$ENV_FILE"
  else
    echo "Файл access.txt не найден."
    exit 1
  fi
else
  read -p "Введите API URL: " API_URL
  read -p "Введите SHA256 сертификата: " CERT_SHA256
  echo "OUTLINE_API_URL=$API_URL" > "$ENV_FILE"
  echo "CERT_SHA256=$CERT_SHA256" >> "$ENV_FILE"
fi

# Запрос токена и ID пользователя
read -p "Введите ID пользователя: " ALLOWED_USER_ID
read -p "Введите токен бота: " TELEGRAM_BOT_TOKEN

echo "ALLOWED_USER_ID=$ALLOWED_USER_ID" >> "$ENV_FILE"
echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN" >> "$ENV_FILE"

# Обновляем Dockerfile
echo "Обновляем Dockerfile..."
sed -i "s|/opt/tg_outline_bot|$NEW_DIR|g" Dockerfile

# Сборка Docker-образа
cd "$NEW_DIR" || { echo "Ошибка при переходе в директорию $NEW_DIR"; exit 1; }
docker build -t "$NEW_CONTAINER_NAME" . || { echo "Ошибка сборки Docker-образа"; exit 1; }

# Запуск нового контейнера
docker run -d --name "$NEW_CONTAINER_NAME" --env-file "$ENV_FILE" "$NEW_CONTAINER_NAME" || { echo "Ошибка запуска контейнера"; exit 1; }
echo "Контейнер $NEW_CONTAINER_NAME успешно запущен."
