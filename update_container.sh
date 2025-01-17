#!/bin/bash

# URL репозитория для скачивания
REPO_URL="https://github.com/B1g-data/outline_bot.git"
BRANCH="main"
TARGET_DIR="/opt/tg_outline_bot"

# Получение списка контейнеров
CONTAINERS=$(docker ps -a --filter "name=^tg_outline_bot" --format "{{.Names}}")

# Функция отката изменений
rollback() {
  echo "Произошла ошибка. Откат изменений..."
  exit 1
}

# Проверка существующих контейнеров
if [ -z "$CONTAINERS" ]; then
  echo "Нет существующих контейнеров для обновления."
  exit 1
fi

# Список контейнеров с нумерацией
echo "Список существующих контейнеров:"
index=1
for CONTAINER in $CONTAINERS; do
  echo "$index. $CONTAINER"
  ((index++))
done

# Выбор контейнера
read -p "Введите номер контейнера, который хотите обновить: " CONTAINER_NUMBER
CONTAINER_NAME=$(echo "$CONTAINERS" | sed -n "${CONTAINER_NUMBER}p")

if [ -z "$CONTAINER_NAME" ]; then
  echo "Неверный номер контейнера."
  exit 1
fi

echo "Вы выбрали контейнер: $CONTAINER_NAME"

# Директория обновления
NEW_DIR="/opt/${CONTAINER_NAME}"

# Проверка и обновление репозитория
if [ -d "$NEW_DIR/.git" ]; then
  echo "Папка $NEW_DIR уже содержит репозиторий. Обновление содержимого..."
  git -C "$NEW_DIR" pull origin "$BRANCH" || rollback
else
  echo "Папка $NEW_DIR не содержит репозитория. Клонируем репозиторий..."
  git clone -b "$BRANCH" --single-branch "$REPO_URL" "$NEW_DIR" 
fi

echo "Репозиторий успешно обновлён."

# Сборка Docker-образа
echo "Собираем Docker-образ для $CONTAINER_NAME..."
cd "$NEW_DIR" || rollback
docker build -t "$CONTAINER_NAME" . || rollback

echo "Docker-образ успешно собран."

# Остановка и удаление старого контейнера
echo "Останавливаем и удаляем старый контейнер $CONTAINER_NAME..."
docker stop "$CONTAINER_NAME"
docker rm "$CONTAINER_NAME"

# Запуск нового контейнера
ENV_FILE="/opt/${CONTAINER_NAME}/.env" # Замените на актуальный путь
echo "Запускаем новый контейнер $CONTAINER_NAME..."
docker run -d --name "$CONTAINER_NAME" --restart always --env-file "$ENV_FILE" "$CONTAINER_NAME" || rollback

echo "Контейнер $CONTAINER_NAME успешно обновлён и запущен."
