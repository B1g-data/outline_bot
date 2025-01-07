#!/bin/bash

# Функция проверки формата URL
validate_url() {
  local url=$1
  if [[ "$url" =~ ^https?://[a-zA-Z0-9.-]+(\:[0-9]+)?(/.*)?$ ]]; then
    return 0  # URL корректен
  else
    return 1  # Неверный URL
  fi
}

# Функция проверки формата SHA256
validate_sha256() {
  local sha256=$1
  if [[ "$sha256" =~ ^[a-fA-F0-9]{64}$ ]]; then
    return 0  # SHA256 корректен
  else
    return 1  # Неверный формат SHA256
  fi
}

# Функция проверки формата ID пользователя
validate_user_id() {
  local user_id=$1
  if [[ "$user_id" =~ ^[0-9]+$ ]] && [ "$user_id" -gt 0 ]; then
    return 0  # ID корректен
  else
    return 1  # Неверный ID
  fi
}

# Функция проверки существования пользователя через Telegram API
validate_user_exists() {
  local user_id=$1
  response=$(curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getChat?chat_id=$user_id")
  if [[ "$response" =~ "\"ok\":true" ]]; then
    return 0  # Пользователь существует
  else
    return 1  # Пользователь не найден или ошибка
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

# Запрос суффикса
read -p "Хотите сгенерировать суффикс автоматически? (y/n): " generate_suffix
if [[ "$generate_suffix" == "y" || "$generate_suffix" == "Y" ]]; then
  SUFFIX=$(date +%Y%m%d%H%M%S)  # Генерация суффикса на основе текущей даты и времени
  echo "Сгенерированный суффикс: $SUFFIX"
else
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
ACCESS_FILE="/opt/outline/access.txt"
OLD_DIR="/opt/tg_outline_bot"

# Создаем новую папку
mkdir -p "$NEW_DIR"

# Клонируем репозиторий
echo "Клонируем репозиторий в $NEW_DIR..."
git clone "$REPO_URL" "$NEW_DIR" || { echo "Ошибка клонирования репозитория"; exit 1; }

# Проверка на наличие файла access.txt
if [ -f "$ACCESS_FILE" ]; then
  read -p "Хотите извлечь данные из файла access.txt (y/n)? " extract_from_file
  if [[ "$extract_from_file" == "y" || "$extract_from_file" == "Y" ]]; then
    API_URL=$(grep -oP '(?<=apiUrl:).*' "$ACCESS_FILE")
    CERT_SHA256=$(grep -oP '(?<=certSha256:).*' "$ACCESS_FILE")
    echo "OUTLINE_API_URL=$API_URL" > "$ENV_FILE"
    echo "CERT_SHA256=$CERT_SHA256" >> "$ENV_FILE"
  fi
else
  echo "Файл access.txt не найден."
  # Запрос API URL и SHA256 сертификата
  while true; do
    read -p "Введите API URL (например, https://example.com): " API_URL
    if validate_url "$API_URL"; then
      echo "API URL корректен."
      break  # Прерываем цикл, если URL корректен
    else
      echo "Ошибка: Неверный формат API URL. Попробуйте снова."
    fi
  done

  while true; do
    read -p "Введите SHA256 сертификата (64 символа): " CERT_SHA256
    if validate_sha256 "$CERT_SHA256"; then
      echo "SHA256 корректен."
      break  # Прерываем цикл, если SHA256 корректен
    else
      echo "Ошибка: Неверный формат SHA256. Попробуйте снова."
    fi
  done

  echo "OUTLINE_API_URL=$API_URL" > "$ENV_FILE"
  echo "CERT_SHA256=$CERT_SHA256" >> "$ENV_FILE"
fi

# 4. Проверка формата ID пользователя
while true; do
  read -p "Введите ID пользователя: " ALLOWED_USER_ID
  if validate_user_id "$ALLOWED_USER_ID"; then
    echo "ID пользователя корректен. Проверяем его наличие..."
    if validate_user_exists "$ALLOWED_USER_ID"; then
      echo "Пользователь с ID $ALLOWED_USER_ID существует."
      break  # Прерываем цикл, если ID пользователя найден
    else
      echo "Ошибка: Пользователь с ID $ALLOWED_USER_ID не найден."
    fi
  else
    echo "Ошибка: Неверный формат ID пользователя. Используйте только цифры."
  fi
done

# Цикл запроса токена, пока он не будет правильным
while true; do
  read -p "Введите токен Telegram-бота (формат: 1234567890:ABCDEFghijklMNOpqrsTUVwxYz-1234abcde): " TELEGRAM_BOT_TOKEN
  if validate_token_format "$TELEGRAM_BOT_TOKEN"; then
    echo "Формат токена правильный. Проверяем его..."
    if validate_telegram_token "$TELEGRAM_BOT_TOKEN"; then
      echo "Токен действителен!"
      break  # Прерываем цикл, если токен действителен
    else
      echo "Ошибка: Токен неверный или недействителен. Попробуйте снова."
    fi
  else
    echo "Ошибка: Токен имеет неверный формат. Попробуйте снова."
  fi
done

# Обновляем Dockerfile
echo "Обновляем Dockerfile..."
sed -i "s|$OLD_DIR|$NEW_DIR|g" "$NEW_DIR/Dockerfile"

# Сборка Docker-образа
cd "$NEW_DIR" || { echo "Ошибка при переходе в директорию $NEW_DIR"; exit 1; }
docker build -t "$NEW_CONTAINER_NAME" . || { echo "Ошибка сборки Docker-образа"; exit 1; }

echo "Docker-образ для контейнера $NEW_CONTAINER_NAME успешно собран."

# Запуск контейнера
echo "Запускаем контейнер $NEW_CONTAINER_NAME..."
docker run -d --name "$NEW_CONTAINER_NAME" --env-file "$ENV_FILE" "$NEW_CONTAINER_NAME" || { echo "Ошибка запуска контейнера"; exit 1; }

echo "Контейнер $NEW_CONTAINER_NAME успешно запущен."
