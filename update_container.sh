#!/bin/bash

# URL репозитория для скачивания
REPO_URL="https://github.com/B1g-data/outline_bot.git"
BRANCH="test"
TARGET_DIR="/opt/tg_outline_bot"
ENV_FILE="${TARGET_DIR}/.env"

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

# Определение директории для репозитория
NEW_DIR="/opt/${CONTAINER_NAME}"

# Проверка, существует ли репозиторий в указанной директории
if [ -d "$NEW_DIR/.git" ]; then
  echo "Папка $NEW_DIR уже содержит репозиторий. Обновление содержимого..."
  git -C "$NEW_DIR" pull origin "$BRANCH" || { echo "Ошибка обновления репозитория"; exit 1; }
else
  echo "Клонируем репозиторий в $NEW_DIR..."
  git clone -b "$BRANCH" --single-branch "$REPO_URL" "$NEW_DIR" || { echo "Ошибка клонирования репозитория"; exit 1; }
fi

echo "Репозиторий успешно обновлен."

# Сборка и запуск контейнера
cd "$NEW_DIR" || { echo "Ошибка перехода в директорию $NEW_DIR"; exit 1; }

IMAGE_NAME="${CONTAINER_NAME}_image"
echo "Собираем Docker-образ..."
docker build -t "$IMAGE_NAME" . || { echo "Ошибка сборки Docker-образа"; exit 1; }

echo "Запускаем контейнер..."
docker run -d --name "$IMAGE_NAME" --restart always --env-file "$ENV_FILE" "$IMAGE_NAME" || { echo "Ошибка запуска контейнера"; exit 1; }

echo "Контейнер $IMAGE_NAME успешно запущен."

