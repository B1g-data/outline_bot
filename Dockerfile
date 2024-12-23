# Используем официальный образ Python 3.13 на базе Debian Slim
FROM python:3.13-slim

# Устанавливаем необходимые зависимости
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Настраиваем переменную среды PYTHONPATH
ENV PYTHONPATH=/app

# Устанавливаем рабочую директорию внутри контейнера
WORKDIR /opt/outline_bot

# Копируем файл requirements.txt и устанавливаем зависимости
COPY requirements.txt /opt/outline_bot/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Копируем весь остальной код в контейнер
COPY . /opt/outline_bot/

# Определяем команду для запуска бота
CMD ["python", "main.py"]
