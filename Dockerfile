# Используем официальный образ Python 3.13 на базе Debian Slim
FROM python:3.13-slim

# Устанавливаем необходимые зависимости
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

ENV PYTHONPATH=/app:$PYTHONPATH

# Устанавливаем рабочую директорию внутри контейнера
WORKDIR /opt/outline_bot

# Копируем файл .env в контейнер
COPY .env /opt/outline_bot/.env

# Копируем файл requirements.txt в рабочую директорию контейнера
COPY requirements.txt /opt/outline_bot/requirements.txt

# Устанавливаем зависимости
RUN pip install --no-cache-dir -r requirements.txt

# Копируем остальной код в контейнер
COPY . /opt/outline_bot/

# Определяем команду для запуска бота
CMD ["python", "main.py"]  # Замените на вашу команду для запуска бота
