#!/bin/bash

# URL для скачивания необходимых скриптов
GITHUB_REPO="https://raw.githubusercontent.com/B1g-data/outline_bot/test"

# 1. Получение списка контейнеров
CONTAINERS=$(docker ps -a --filter "name=^tg_outline_bot" --format "{{.Names}}")
if [ -z "$CONTAINERS" ]; then
  echo "Нет существующих контейнеров с префиксом tg_outline_bot."
else
  echo "Существующие контейнеры:"
  echo "$CONTAINERS"
fi

# 2. Запрос у пользователя, хочет ли он обновить контейнер
read -p "Хотите обновить существующий контейнер? (y/n): " UPDATE_EXISTING

if [[ "$UPDATE_EXISTING" == "y" || "$UPDATE_EXISTING" == "Y" ]]; then
  read -p "Введите имя контейнера, который хотите обновить: " CONTAINER_TO_UPDATE
  if [[ ! " $CONTAINERS " =~ " $CONTAINER_TO_UPDATE " ]]; then
    echo "Контейнер с таким именем не найден. Выберите создание нового."
    CREATE_NEW=1
  fi
else
  CREATE_NEW=1
fi

# 3. Если пользователь хочет создать новый контейнер
if [[ "$CREATE_NEW" == 1 ]]; then
  read -p "Введите суффикс для нового контейнера (например, 'v2'): " SUFFIX
  NEW_CONTAINER_NAME="tg_outline_bot_$SUFFIX"

  # Проверяем, существует ли уже контейнер с таким именем
  if docker ps -a --filter "name=$NEW_CONTAINER_NAME" --format "{{.Names}}" | grep -q "$NEW_CONTAINER_NAME"; then
    echo "Контейнер с таким именем уже существует. Пожалуйста, выберите другой суффикс."
    exit 1
  fi
fi

# 4. Скачиваем необходимые скрипты и Dockerfile
echo "Скачиваем скрипты и Dockerfile..."
curl -sSL "$GITHUB_REPO/setup_container.sh" -o setup_container.sh
curl -sSL "$GITHUB_REPO/update_container.sh" -o update_container.sh
curl -sSL "$GITHUB_REPO/Dockerfile" -o Dockerfile

# 5. Запускаем скрипт для создания/обновления контейнера
if [[ "$UPDATE_EXISTING" == "y" || "$UPDATE_EXISTING" == "Y" ]]; then
  bash update_container.sh "$CONTAINER_TO_UPDATE"
else
  bash setup_container.sh "$NEW_CONTAINER_NAME"
fi
