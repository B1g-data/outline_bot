#!/bin/bash

# Переменные
REPO_URL="https://github.com/B1g-data/outline_bot.git"  # Замените на URL репозитория
TARGET_DIR="/opt/tg_outline_bot"
ENV_FILE="${TARGET_DIR}/.env"
CONTAINER_NAME="tg_outline_bot"
IMAGE_NAME="tg_outline_bot_image"  # Имя Docker-образа

# Функция для удаления установленных компонентов при прерывании скрипта
cleanup() {
  echo "Прерывание скрипта. Удаляем установленные компоненты..."
  if [ -d "$TARGET_DIR" ]; then
    echo "Удаляем репозиторий..."
    rm -rf "$TARGET_DIR"
  fi
  if docker ps -a | grep -q "$CONTAINER_NAME"; then
    echo "Останавливаем и удаляем контейнер..."
    docker stop "$CONTAINER_NAME" && docker rm "$CONTAINER_NAME"
  fi
  exit 1
}

# Обработчик прерывания (Ctrl+C)
trap cleanup INT

# Проверка наличия необходимых утилит
for cmd in git docker grep curl; do
  if ! command -v $cmd &>/dev/null; then
    echo "Ошибка: Утилита $cmd не найдена. Пожалуйста, установите её."
    exit 1
  fi
done

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

# 1. Проверка наличия каталога и его создание, если отсутствует
if [ ! -d "$TARGET_DIR" ]; then
  echo "Папка $TARGET_DIR не существует. Создаём её..."
  mkdir -p "$TARGET_DIR"
else
  echo "Папка $TARGET_DIR уже существует."
fi

# 2. Клонирование репозитория
if [ -d "$TARGET_DIR/.git" ]; then
  echo "Папка $TARGET_DIR уже содержит репозиторий. Обновление содержимого..."
  git -C "$TARGET_DIR" pull || { echo "Ошибка обновления репозитория"; }
else
  echo "Клонируем репозиторий..."
  git clone "$REPO_URL" "$TARGET_DIR" || { echo "Ошибка клонирования репозитория"; }
fi

# 3. Проверка наличия .env файла и сохранённых переменных
if [ -f "$ENV_FILE" ]; then
  # Чтение сохраненных данных из .env
  source "$ENV_FILE"
  echo "Найден файл .env. Используем сохраненные значения."
else
  # Запрос данных у пользователя, если .env файл не существует
  echo "Файл .env не найден. Требуются данные от пользователя."

  # Запрашиваем корректные данные до тех пор, пока не будут введены правильные значения
  while true; do
    read -p "Введите ID пользователя: " ALLOWED_USER_ID
    if validate_user_id "$ALLOWED_USER_ID"; then
      echo "ID пользователя корректен. Проверяем его наличие..."
      if validate_user_exists "$ALLOWED_USER_ID"; then
        echo "Пользователь с ID $ALLOWED_USER_ID существует."
        break
      else
        echo "Ошибка: Пользователь с ID $ALLOWED_USER_ID не найден. Попробуйте снова."
      fi
    else
      echo "Ошибка: Неверный формат ID пользователя. Попробуйте снова."
    fi
  done

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
fi

# 4. Чтение из access.txt
ACCESS_FILE="/opt/outline/access.txt"
if [ -f "$ACCESS_FILE" ]; then
  # Извлечение значений с использованием ":" в качестве разделителя
  API_URL=$(grep -oP '(?<=apiUrl:).*' "$ACCESS_FILE")
  CERT_SHA256=$(grep -oP '(?<=certSha256:).*' "$ACCESS_FILE")
else
  echo "Файл $ACCESS_FILE не найден. Завершение. Возможно, outline не установлен или установлен не стандартным способом."
  cleanup
fi

# 5. Сохранение в .env, если данные были введены
echo "OUTLINE_API_URL=$API_URL" > "$ENV_FILE"
echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN" >> "$ENV_FILE"
echo "CERT_SHA256=$CERT_SHA256" >> "$ENV_FILE"
echo "ALLOWED_USER_ID=$ALLOWED_USER_ID" >> "$ENV_FILE"

echo "Файл .env успешно создан."

# 6. Сборка Docker-образа
cd "$TARGET_DIR" || { echo "Ошибка при переходе в директорию $TARGET_DIR"; cleanup; }
echo "Собираем Docker-образ..."
docker build -t "$IMAGE_NAME" . || { echo "Ошибка сборки Docker-образа"; cleanup; }

# 7. Остановка и удаление старого контейнера
if docker ps -a | grep -q "$CONTAINER_NAME"; then
  echo "Останавливаем и удаляем старый контейнер..."
  docker stop "$CONTAINER_NAME" && docker rm "$CONTAINER_NAME" || { echo "Ошибка остановки и удаления контейнера"; cleanup; }
fi

# 8. Запуск нового контейнера
echo "Запускаем новый контейнер..."
docker run -d --name "$CONTAINER_NAME" --env-file "$ENV_FILE" "$IMAGE_NAME" || { echo "Ошибка запуска контейнера"; cleanup; }

echo "Контейнер $CONTAINER_NAME успешно запущен."
