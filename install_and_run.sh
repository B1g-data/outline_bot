#!/bin/bash

# Переменные
REPO_URL="https://github.com/B1g-data/outline_bot.git"  # Замените на URL репозитория
TARGET_DIR="/opt/outline_bot"
ENV_FILE="${TARGET_DIR}/.env"
CONTAINER_NAME="outline_bot"
IMAGE_NAME="outline_bot_image"  # Имя Docker-образа

# 1. Клонирование репозитория
if [ -d "$TARGET_DIR" ]; then
  echo "Папка $TARGET_DIR уже существует. Обновление содержимого..."
  git -C "$TARGET_DIR" pull
else
  echo "Клонируем репозиторий..."
  git clone "$REPO_URL" "$TARGET_DIR"
fi

# 2. Запрос данных у пользователя
read -p "Введите ID пользователя: " ALLOWED_USER_ID
read -p "Введите токен Telegram-бота: " TELEGRAM_BOT_TOKEN

# 3. Чтение из access.txt
ACCESS_FILE="/opt/outline/access.txt"
if [ -f "$ACCESS_FILE" ]; then
  API_URL=$(grep -oP '(?<=apiUrl=).*' "$ACCESS_FILE")
  CERT_SHA256=$(grep -oP '(?<=certSha256=).*' "$ACCESS_FILE")
else
  echo "Файл $ACCESS_FILE не найден. Завершение."
  exit 1
fi

# 4. Сохранение в .env
cat <<EOF > "$ENV_FILE"
OUTLINE_API_URL="$API_URL"
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
CERT_SHA256="$CERT_SHA256"
ALLOWED_USER_ID="$ALLOWED_USER_ID"
EOF

echo "Файл .env успешно создан."

# 5. Сборка Docker-образа
cd "$TARGET_DIR" || exit 1
echo "Собираем Docker-образ..."
docker build -t "$IMAGE_NAME" .

# 6. Остановка и удаление старого контейнера
if docker ps -a | grep -q "$CONTAINER_NAME"; then
  echo "Останавливаем и удаляем старый контейнер..."
  docker stop "$CONTAINER_NAME"
  docker rm "$CONTAINER_NAME"
fi

# 7. Запуск нового контейнера
echo "Запускаем новый контейнер..."
docker run -d --name "$CONTAINER_NAME" --env-file "$ENV_FILE" "$IMAGE_NAME"

if [ $? -eq 0 ]; then
  echo "Контейнер $CONTAINER_NAME успешно запущен."
else
  echo "Ошибка запуска контейнера."
  exit 1
fi
