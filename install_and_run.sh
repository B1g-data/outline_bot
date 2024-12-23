#!/bin/bash

# Убедитесь, что указали ваш репозиторий
GITHUB_REPO_URL="https://github.com/B1g-data/outline_bot.git"
REPO_DIR="/opt/outline-vpn-bot"

# Проверяем, что файл access.txt существует
if [ ! -f /opt/outline/access.txt ]; then
    echo "Файл /opt/outline/access.txt не найден!"
    exit 1
fi

# Чтение данных из access.txt
apiUrl=$(grep -i "apiUrl" /opt/outline/access.txt | cut -d ":" -f2- | tr -d '[:space:]')
certSha256=$(grep -i "certSha256" /opt/outline/access.txt | cut -d ":" -f2- | tr -d '[:space:]')

# Проверка на наличие значений
if [ -z "$apiUrl" ] || [ -z "$certSha256" ]; then
    echo "Не удалось извлечь apiUrl или certSha256 из файла!"
    exit 1
fi

# Используем /dev/tty для обработки интерактивного ввода
exec < /dev/tty

# Запрашиваем Telegram User ID у пользователя
echo "Пожалуйста, укажите ваш Telegram User ID, чтобы ограничить доступ к боту."
echo "Вы можете найти свой User ID, написав боту: https://t.me/userinfobot или используя другой способ."
read -p "Введите ваш Telegram User ID: " ALLOWED_USER_ID

# Создание или обновление файла .env
if [ ! -f .env ]; then
    echo "Создаём .env файл..."
    
    # Запрашиваем токен бота, если он отсутствует
    read -p "Введите токен вашего Telegram бота: " bot_token

    cat <<EOL > .env
OUTLINE_API_URL=$apiUrl
CERT_SHA256=$certSha256
TELEGRAM_BOT_TOKEN=$bot_token
ALLOWED_USER_ID=$ALLOWED_USER_ID
EOL

    echo ".env файл создан с параметрами OUTLINE_API_URL, CERT_SHA256, TELEGRAM_BOT_TOKEN и ALLOWED_USER_ID."
else
    echo ".env файл уже существует. Проверяем токен и ALLOWED_USER_ID..."

    # Если токен не найден в .env, запрашиваем его
    if ! grep -q "TELEGRAM_BOT_TOKEN" .env; then
        echo "Токен Telegram бота не найден в .env."
        read -p "Введите токен вашего Telegram бота: " bot_token
        echo "TELEGRAM_BOT_TOKEN=$bot_token" >> .env
        echo "Токен добавлен в .env."
    else
        echo "Токен бота уже присутствует в .env. Используется текущий."
    fi

    # Если ALLOWED_USER_ID не найден в .env, запрашиваем его
    if ! grep -q "ALLOWED_USER_ID" .env; then
        echo "ALLOWED_USER_ID не найден в .env."
        echo "Добавляем ALLOWED_USER_ID..."
        echo "ALLOWED_USER_ID=$ALLOWED_USER_ID" >> .env
        echo "ALLOWED_USER_ID добавлен в .env."
    else
        echo "ALLOWED_USER_ID уже присутствует в .env."
    fi
fi

# Проверка наличия Docker
if ! command -v docker &> /dev/null; then
    echo "Docker не установлен. Устанавливаем Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo "Docker успешно установлен. Перезапустите терминал для применения изменений."
    exit 1
fi

# Клонирование репозитория с кодом бота (или обновление, если он уже существует)
if [ ! -d "$REPO_DIR" ]; then
    echo "Клонируем репозиторий с GitHub..."
    git clone "$GITHUB_REPO_URL" "$REPO_DIR"
else
    echo "Репозиторий уже клонирован. Обновляем..."
    cd "$REPO_DIR" && git pull origin main
fi

# Переходим в директорию с кодом бота
cd "$REPO_DIR"

# Собираем Docker контейнер
echo "Собираем Docker контейнер..."
docker build -t outline-vpn-bot .

# Останавливаем и удаляем старый контейнер (если существует)
if [ "$(docker ps -q -f name=outline-vpn-bot)" ]; then
    echo "Останавливаем и удаляем старый контейнер..."
    docker stop outline-vpn-bot
    docker rm outline-vpn-bot
fi

# Запуск нового контейнера
echo "Запускаем новый контейнер..."
docker run -d --env-file .env --name outline-vpn-bot outline-vpn-bot

echo "Бот успешно обновлен и запущен в контейнере!"
