#!/bin/bash

# Запрос пользователя, генерировать ли суффикс автоматически
read -p "Хотите сгенерировать суффикс автоматически? (y/n): " generate_suffix
if [[ "$generate_suffix" == "y" || "$generate_suffix" == "Y" ]]; then
  SUFFIX=$(date +%Y%m%d%H%M%S)  # Генерация суффикса на основе текущей даты и времени
  echo "Сгенерированный суффикс: $SUFFIX"
else
  # Запрос суффикса для контейнера и директории
  read -p "Введите суффикс для контейнера и директории: " SUFFIX
  if [ -z "$SUFFIX" ]; then
    echo "Не указан суффикс. Выход..."
    exit 1
  fi
fi

# Формируем имя нового контейнера и директории
NEW_CONTAINER_NAME="tg_outline_bot_$SUFFIX"
NEW_DIR="/opt/$NEW_CONTAINER_NAME"
REPO_URL="https://github.com/B1g-data/outline_bot.git"
ENV_FILE="$NEW_DIR/.env"

# Создаем новую папку
mkdir -p "$NEW_DIR"

# Проверка на наличие файла access.txt
if [ -f "$NEW_DIR/access.txt" ]; then
  read -p "Хотите извлечь данные из файла access.txt (y/n)? " extract_from_file
  if [[ "$extract_from_file" == "y" || "$extract_from_file" == "Y" ]]; then
    API_URL=$(grep -oP '(?<=apiUrl:).*' "$NEW_DIR/access.txt")
    CERT_SHA256=$(grep -oP '(?<=certSha256:).*' "$NEW_DIR/access.txt")
    echo "OUTLINE_API_URL=$API_URL" > "$ENV_FILE"
    echo "CERT_SHA256=$CERT_SHA256" >> "$ENV_FILE"
  fi
else
  echo "Файл access.txt не найден."
  read -p "Продолжить с ручным вводом данных? (y/n): " continue_manual
  if [[ "$continue_manual" == "y" || "$continue_manual" == "Y" ]]; then
    # Запрос API URL и SHA256 сертификата
    read -p "Введите API URL: " API_URL
    read -p "Введите SHA256 сертификата: " CERT_SHA256
    echo "OUTLINE_API_URL=$API_URL" > "$ENV_FILE"
    echo "CERT_SHA256=$CERT_SHA256" >> "$ENV_FILE"
  else
    echo "Выход из скрипта."
    exit 1
  fi
fi

# Запрос токена и ID пользователя
read -p "Введите ID пользователя: " ALLOWED_USER_ID
read -p "Введите токен бота: " TELEGRAM_BOT_TOKEN

echo "ALLOWED_USER_ID=$ALLOWED_USER_ID" >> "$ENV_FILE"
echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN" >> "$ENV_FILE"

# Обновляем Dockerfile
echo "Обновляем Dockerfile..."
sed -i "s|/opt/tg_outline_bot|$NEW_DIR|g" "$NEW_DIR/Dockerfile"

# Сборка Docker-образа
cd "$NEW_DIR" || { echo "Ошибка при переходе в директорию $NEW_DIR"; exit 1; }
docker build -t "$NEW_CONTAINER_NAME" . || { echo "Ошибка сборки Docker-образа"; exit 1; }

echo "Docker-образ для контейнера $NEW_CONTAINER_NAME успешно собран."
