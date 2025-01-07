#!/bin/bash

# URL репозитория для скачивания
REPO_URL="https://raw.githubusercontent.com/B1g-data/outline_bot/test"

# Функция отката изменений
rollback() {
  echo "Произошла ошибка. Выполняем откат изменений..."
  if [ -f "$SCRIPT_NAME" ]; then
    echo "Удаляем скачанный скрипт $SCRIPT_NAME..."
    rm -f "$SCRIPT_NAME"
  fi
  exit 1
}

# Загрузка и выполнение скрипта для обновления контейнера
download_and_execute() {
  SCRIPT_URL="$1"
  SCRIPT_NAME="$2"
  
  echo "Скачиваем скрипт $SCRIPT_NAME..."
  curl -s "$SCRIPT_URL" -o "$SCRIPT_NAME" || rollback  # Откат, если ошибка скачивания
  
  echo "Делаем скрипт исполнимым..."
  chmod +x "$SCRIPT_NAME" || rollback  # Откат, если ошибка изменения прав на скрипт

  echo "Запускаем скрипт $SCRIPT_NAME..."
  ./"$SCRIPT_NAME" || rollback  # Откат, если ошибка выполнения скрипта
}

# Запрос действия у пользователя
echo "Что вы хотите сделать?"
echo "1. Обновить существующий контейнер (просто обновляет один из установленных ботов до новой версии)"
echo "2. Создать новый контейнер (подходит для начала управления или еще одним сервером хихи)"
read -p "Выберите действие (1 или 2): " ACTION

if [[ "$ACTION" == "1" ]]; then
  download_and_execute "$REPO_URL/update_container.sh" "update_container.sh"
elif [[ "$ACTION" == "2" ]]; then
  download_and_execute "$REPO_URL/setup_container.sh" "setup_container.sh"
else
  echo "Некорректный выбор. Завершаем работу."
  exit 1
fi
