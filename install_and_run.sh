#!/bin/bash

# Переменные
REPO_URL="https://github.com/B1g-data/outline_bot.git"
TARGET_DIR="/opt/tg_outline_bot"
ENV_FILE="${TARGET_DIR}/.env"
CONTAINER_NAME="tg_outline_bot"
IMAGE_NAME="tg_outline_bot_image"
ACCESS_FILE="/opt/outline/access.txt"

# Проверка наличия необходимых утилит
for cmd in git docker grep curl; do
  if ! command -v $cmd &>/dev/null; then
    echo "Ошибка: Утилита $cmd не найдена. Пожалуйста, установите её."
    exit 1
  fi
done

# Функция проверки формата строки вида key:value
validate_input_format() {
  local input=$1
  if [[ "$input" =~ ^[a-zA-Z0-9]+:.+$ ]]; then
    return 0
  else
    return 1
  fi
}

# Функция обработки данных из access.txt
process_access_file() {
  if [ -f "$ACCESS_FILE" ]; then
    echo "Файл $ACCESS_FILE найден. Используем данные из него."
    API_URL=$(grep -oP '(?<=apiUrl:).*' "$ACCESS_FILE")
    CERT_SHA256=$(grep -oP '(?<=certSha256:).*' "$ACCESS_FILE")
    if [ -z "$API_URL" ] || [ -z "$CERT_SHA256" ]; then
      echo "Не все данные найдены в файле access.txt. Переключаемся на ручной ввод."
      return 1
    fi
    return 0
  else
    echo "Файл $ACCESS_FILE не найден. Переключаемся на ручной ввод."
    return 1
  fi
}

# Функция ручного ввода данных
manual_input() {
  while true; do
    read -p "Введите строку (формат certSha256:<значение>): " input
    if validate_input_format "$input"; then
      CERT_SHA256=$(echo "$input" | awk -F: '{print $2}')
      break
    else
      echo "Ошибка: Неверный формат. Попробуйте снова."
    fi
  done

  while true; do
    read -p "Введите строку (формат apiUrl:<значение>): " input
    if validate_input_format "$input"; then
      API_URL=$(echo "$input" | awk -F: '{print $2}')
      break
    else
      echo "Ошибка: Неверный формат. Попробуйте снова."
    fi
  done
}

# Запросить у пользователя, откуда брать данные
read -p "Хотите ли вы использовать данные из файла access.txt? (yes/no): " use_access_file
if [[ "$use_access_file" == "yes" ]]; then
  # Обработка данных из файла access.txt
  if ! process_access_file; then
    echo "Переключаемся на ручной ввод данных."
    manual_input
  fi
else
  # Ручной ввод данных, если пользователь не хочет использовать файл
  echo "Переключаемся на ручной ввод данных."
  manual_input
fi

# Сохранение данных в .env
echo "OUTLINE_API_URL=$API_URL" > "$ENV_FILE"
echo "CERT_SHA256=$CERT_SHA256" >> "$ENV_FILE"

echo "Файл .env успешно создан."

# Остальной процесс установки и запуска контейнера
if [ -d "$TARGET_DIR/.git" ]; then
  echo "Обновляем репозиторий..."
  git -C "$TARGET_DIR" pull || { echo "Ошибка обновления репозитория"; exit 1; }
else
  echo "Клонируем репозиторий..."
  git clone "$REPO_URL" "$TARGET_DIR" || { echo "Ошибка клонирования репозитория"; exit 1; }
fi

echo "Собираем Docker-образ..."
docker build -t "$IMAGE_NAME" "$TARGET_DIR" || { echo "Ошибка сборки Docker-образа"; exit 1; }

if docker ps -a | grep -q "$CONTAINER_NAME"; then
  echo "Останавливаем и удаляем старый контейнер..."
  docker stop "$CONTAINER_NAME"
  docker rm "$CONTAINER_NAME"
fi

echo "Запускаем новый контейнер..."
docker run -d --name "$CONTAINER_NAME" --restart always --env-file "$ENV_FILE" "$IMAGE_NAME" || { echo "Ошибка запуска контейнера"; exit 1; }

echo "Контейнер $CONTAINER_NAME успешно запущен."
