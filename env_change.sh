#!/bin/bash

# Переменные
ACCESS_FILE="/opt/outline/access.txt"
ENV_FILE="/opt/tg_outline_bot/.env"

# Функция проверки формата ID пользователя
validate_user_id() {
  local user_id=$1
  if [[ "$user_id" =~ ^[0-9]+$ ]] && [ "$user_id" -gt 0 ]; then
    return 0  # ID корректен
  else
    return 1  # Неверный ID
  fi
}

# Функция проверки формата токена
validate_token_format() {
  local token=$1
  if [[ "$token" =~ ^[0-9]{9,15}:[A-Za-z0-9_-]{35,45}$ ]]; then
    return 0  # Токен соответствует формату
  else
    return 1  # Неверный формат
  fi
}

# Функция проверки действительности токена через Telegram API
validate_telegram_token() {
  local token=$1
  response=$(curl -s "https://api.telegram.org/bot$token/getMe")
  if [[ "$response" =~ "\"ok\":true" ]]; then
    return 0  # Токен действителен
  else
    return 1  # Токен неверный
  fi
}

# 1. Запросить, копировать ли данные из access.txt
read -p "Хотите ли вы скопировать данные из файла access.txt? (y/n): " COPY_ACCESS_DATA

if [[ "$COPY_ACCESS_DATA" =~ ^[Yy]$ ]]; then
  # 2. Чтение данных из access.txt
  if [ -f "$ACCESS_FILE" ]; then
    # Извлечение значений с использованием ":" в качестве разделителя
    API_URL=$(grep -oP '(?<=apiUrl:).*' "$ACCESS_FILE")
    CERT_SHA256=$(grep -oP '(?<=certSha256:).*' "$ACCESS_FILE")
  else
    echo "Файл $ACCESS_FILE не найден. Пожалуйста, укажите данные вручную."
    API_URL=""
    CERT_SHA256=""
  fi
else
  # 3. Запрос данных у пользователя
  echo "Введите данные вручную."
  read -p "Введите URL API: " API_URL
  read -p "Введите SHA256 сертификата: " CERT_SHA256
fi

# 4. Запрос ID пользователя с проверкой
while true; do
  read -p "Введите ID пользователя: " ALLOWED_USER_ID
  if validate_user_id "$ALLOWED_USER_ID"; then
    echo "ID пользователя корректен."
    break
  else
    echo "Ошибка: Неверный формат ID пользователя. Попробуйте снова."
  fi
done

# 5. Запрос токена Telegram-бота с проверкой
while true; do
  read -p "Введите токен Telegram-бота: " TELEGRAM_BOT_TOKEN
  if validate_token_format "$TELEGRAM_BOT_TOKEN"; then
    echo "Формат токена правильный. Проверяем его..."
    if validate_telegram_token "$TELEGRAM_BOT_TOKEN"; then
      echo "Токен действителен!"
      break
    else
      echo "Ошибка: Токен неверный или недействителен. Попробуйте снова."
    fi
  else
    echo "Ошибка: Токен имеет неверный формат. Попробуйте снова."
  fi
done

# 6. Сохранение данных в .env файл
echo "OUTLINE_API_URL=$API_URL" > "$ENV_FILE"
echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN" >> "$ENV_FILE"
echo "CERT_SHA256=$CERT_SHA256" >> "$ENV_FILE"
echo "ALLOWED_USER_ID=$ALLOWED_USER_ID" >> "$ENV_FILE"

echo "Файл .env успешно обновлен."
