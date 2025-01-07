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
# Нумерация контейнеров
index=1
for CONTAINER in $CONTAINERS; do
  echo "$index. $CONTAINER"
  ((index++))
done

# Запрос номера контейнера
read -p "Введите номер контейнера, который хотите обновить: " CONTAINER_NUMBER

# Поиск имени контейнера по номеру
CONTAINER_NAME=$(echo "$CONTAINERS" | sed -n "${CONTAINER_NUMBER}p")

if [ -z "$CONTAINER_NAME" ]; then
  echo "Неверный номер контейнера."
  exit 1
fi

echo "Вы выбрали контейнер: $CONTAINER_NAME"

# Остановка и удаление старого контейнера
echo "Останавливаем и удаляем старый контейнер: $CONTAINER_NAME..."
docker stop "$CONTAINER_NAME" || { echo "Ошибка остановки контейнера $CONTAINER_NAME"; exit 1; }
docker rm "$CONTAINER_NAME" || { echo "Ошибка удаления контейнера $CONTAINER_NAME"; exit 1; }

# Определение директории для репозитория
NEW_DIR="/opt/${CONTAINER_NAME}"

# Проверка, существует ли репозиторий в указанной директории
if [ -d "$NEW_DIR/.git" ]; then
  echo "Папка $NEW_DIR уже содержит репозиторий. Обновление содержимого..."
  git -C "$NEW_DIR" pull origin "$BRANCH" || { echo "Ошибка обновления репозитория"; exit 1; }
else
  echo "Папка $NEW_DIR не содержит репозитория. Клонируем репозиторий..."
  git clone -b "$BRANCH" --single-branch "$REPO_URL" "$NEW_DIR" || { echo "Ошибка клонирования репозитория"; exit 1; }
fi

echo "Репозиторий успешно обновлен."

# Сборка и запуск контейнера
cd "$NEW_DIR" || { echo "Ошибка перехода в директорию $NEW_DIR"; exit 1; }

echo "Собираем Docker-образ..."
docker build -t "$CONTAINER_NAME" . || { echo "Ошибка сборки Docker-образа"; exit 1; }

echo "Запускаем контейнер..."
docker run -d --name "$CONTAINER_NAME" --restart always --env-file "$ENV_FILE" "$CONTAINER_NAME" || { echo "Ошибка запуска контейнера"; exit 1; }

echo "Контейнер $CONTAINER_NAME успешно запущен."
