# Используем официальный образ Python 3.13 на базе Debian Slim
FROM python:3.13-slim

# Устанавливаем необходимые зависимости
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Устанавливаем рабочую директорию внутри контейнера
WORKDIR /opt

# Клонируем репозиторий с кодом бота
RUN git clone https://github.com/your-username/your-repository.git /opt/outline-vpn-bot

# Переходим в директорию с кодом бота
WORKDIR /opt/outline-vpn-bot

# Копируем файл .env в контейнер
COPY .env /opt/outline-vpn-bot/.env

# Устанавливаем зависимости (если есть requirements.txt)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Команда для запуска вашего скрипта
CMD ["bash", "your-script.sh"]