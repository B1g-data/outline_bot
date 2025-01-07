#!/bin/bash

CONTAINER_NAME=$1

# Остановка и удаление старого контейнера
docker stop "$CONTAINER_NAME" || { echo "Ошибка остановки контейнера"; exit 1; }
docker rm "$CONTAINER_NAME" || { echo "Ошибка удаления контейнера"; exit 1; }

# Обновление репозитория и повторный запуск контейнера
NEW_DIR="/opt/$CONTAINER_NAME"

cd "$NEW_DIR" || { echo "Ошибка при переходе в директорию $NEW_DIR"; exit 1; }
git pull || { echo "Ошибка обновления репозитория"; exit 1; }

# Пересборка Docker-образа
docker build -t "$CONTAINER_NAME" . || { echo "Ошибка пересборки Docker-образа"; exit 1; }

# Запуск обновленного контейнера
docker run -d --name "$CONTAINER_NAME" --env-file "$NEW_DIR/.env" "$CONTAINER_NAME" || { echo "Ошибка запуска контейнера"; exit 1; }
echo "Контейнер $CONTAINER_NAME успешно обновлен и запущен."
