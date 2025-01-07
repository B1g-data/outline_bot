#!/bin/bash

# URL репозитория для скачивания
REPO_URL="https://raw.githubusercontent.com/B1g-data/outline_bot/test"

# Загрузка и выполнение скрипта для обновления контейнера
download_and_execute() {
  SCRIPT_URL="$1"
  SCRIPT_NAME="$2"
  
  echo "Скачиваем скрипт $SCRIPT_NAME..."
  curl -s "$SCRIPT_URL" -o "$SCRIPT_NAME" || { echo "Ошибка скачивания скрипта $SCRIPT_NAME"; exit 1; }
  
  echo "Делаем скрипт исполнимым..."
  chmod +x "$SCRIPT_NAME" || { echo "Ошибка изменения прав на скрипт $SCRIPT_NAME"; exit 1; }

  echo "Запускаем скрипт $SCRIPT_NAME..."
  ./"$SCRIPT_NAME" || { echo "Ошибка выполнения скрипта $SCRIPT_NAME"; exit 1; }
}

# Запрос действия у пользователя
echo "Что вы хотите сделать?"
echo "1. Обновить существующий контейнер"
echo "2. Создать новый контейнер"
read -p "Выберите действие (1 или 2): " ACTION

if [[ "$ACTION" == "1" ]]; then
  download_and_execute "$REPO_URL/update_container.sh" "update_container.sh"
elif [[ "$ACTION" == "2" ]]; then
  download_and_execute "$REPO_URL/create_container.sh" "create_container.sh"
else
  echo "Некорректный выбор. Завершаем работу."
  exit 1
fi
