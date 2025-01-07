#!/bin/bash

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
  elif [[ "$response" =~ "\"error_code\":404" ]]; then
    return 1  # Ошибка 404, пользователь не найден
  else
    echo "Ошибка при проверке пользователя: $response"
    return 2  # Ошибка API
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
  read -p "Хотите извлечь данные из файла access.txt (данные Outline данного сервера) (y/n)? " extract_from_file
  if [[ "$extract_from_file" == "y" || "$extract_from_file" == "Y" ]]; then
    API_URL=$(grep -oP '(?<=apiUrl:).*' "$ACCESS_FILE")
    CERT_SHA256=$(grep -oP '(?<=certSha256:).*' "$ACCESS_FILE")
    echo "OUTLINE_API_URL=$API_URL" > "$ENV_FILE"
    echo "CERT_SHA256=$CERT_SHA256" >> "$ENV_FILE"
  fi
else
  echo "Файл access.txt не найден."
  echo "Найдите данные в ином пути или на другом Вашем сервере по пути opt/outline/access.txt"
  # Запрос API URL и SHA256 сертификата
  while true; do
    read -p "Введите API URL (например, https://https://11.111.111.11:11111/eeexAAAmppLe.com): " API_URL
    if [[ "$API_URL" =~ ^https?:// ]]; then
      break
    else
      echo "Ошибка: Неверный формат URL. Попробуйте снова."
    fi
  done
  
  while true; do
    read -p "Введите SHA256 сертификата (64 символа): " CERT_SHA256
    if [[ "$CERT_SHA256" =~ ^[a-fA-F0-9]{64}$ ]]; then
      break
    else
      echo "Ошибка: SHA256 сертификат должен быть длиной 64 символа и состоять только из цифр и букв a-f. Попробуйте снова."
    fi
  done

  echo "OUTLINE_API_URL=$API_URL" > "$ENV_FILE"
  echo "CERT_SHA256=$CERT_SHA256" >> "$ENV_FILE"
fi

# Цикл запроса токена, пока он не будет правильным
while true; do
  read -p "Введите токен Telegram-бота (Узнать - https://t.me/BotFather) (формат: 1234567890:ABCDEFghijklMNOpqrsTUVwxYz-1234abcde): " TELEGRAM_BOT_TOKEN
  if validate_token_format "$TELEGRAM_BOT_TOKEN"; then
    echo "Формат токена правильный. Проверяем его... "
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

# 4. Проверка формата ID пользователя
while true; do
  read -p "Введите ID пользователя (Узнать - https://t.me/userinfobot): " ALLOWED_USER_ID
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

# Добавление данных в .env
echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN" >> "$ENV_FILE"
echo "ALLOWED_USER_ID=$ALLOWED_USER_ID" >> "$ENV_FILE"

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
