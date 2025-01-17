#!/bin/bash

# URL репозитория для скачивания
REPO_URL="https://github.com/B1g-data/outline_bot.git"
BRANCH="main"
TARGET_DIR="/opt/tg_outline_bot"
NEW_DIR="/opt/${CONTAINER_NAME}"

# Получение списка контейнеров
CONTAINERS=$(docker ps -a --filter "name=^tg_outline_bot" --format "{{.Names}}")

# Функция отката изменений
rollback() {
  echo "Произошла ошибка. Выполняем откат изменений..."
  if [ -d "$NEW_DIR" ]; then
    echo "Удаляем репозиторий в директории $NEW_DIR..."
    rm -rf "$NEW_DIR"
  fi
  exit 1
}

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

# Переходим в директорию
cd "$NEW_DIR" 

# Проверка, существует ли репозиторий в указанной директории
if [ -d "$NEW_DIR/.git" ]; then
  echo "Папка $NEW_DIR уже содержит репозиторий. Обновление содержимого..."
  git -C "$NEW_DIR" pull origin "$BRANCH" Откат, если ошибка обновления репозитория
else
  echo "Папка $NEW_DIR не содержит репозитория. Клонируем репозиторий..."
  git clone -b "$BRANCH" --single-branch "$REPO_URL" "$NEW_DIR"  # Откат, если ошибка клонирования
fi

echo "Репозиторий успешно обновлен."

echo "Собираем Docker-образ..."
docker build -t "$CONTAINER_NAME" . # Откат, если ошибка сборки Docker-образа

echo "Docker-образ успешно собран."

# Остановка и удаление старого контейнера
echo "Останавливаем и удаляем старый контейнер: $CONTAINER_NAME..."
docker stop "$CONTAINER_NAME"  
docker rm "$CONTAINER_NAME"    

# Запуск нового контейнера
echo "Запускаем контейнер..."
docker run -d --name "$CONTAINER_NAME" --restart always --env-file "$ENV_FILE" "$CONTAINER_NAME"

echo "Контейнер $CONTAINER_NAME успешно запущен."
