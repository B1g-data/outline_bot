# Используем официальный образ Python 3.13 на базе Alpine
FROM python:3.13-alpine

# Устанавливаем необходимые зависимости и очищаем кэш
RUN apk update && apk add --no-cache \
    git \
    curl \
    build-base \
    libmagic \
    && rm -rf /var/cache/apk/*

# Настроим переменную среды PYTHONPATH
ENV PYTHONPATH=/app

# Устанавливаем рабочую директорию внутри контейнера
WORKDIR /opt/tg_outline_bot

# Копируем файл requirements.txt и устанавливаем зависимости
COPY requirements.txt /opt/tg_outline_bot/requirements.txt
RUN pip install --no-cache-dir --upgrade -r requirements.txt

# Копируем весь остальной код в контейнер
COPY . /opt/tg_outline_bot/

# Определяем команду для запуска бота
CMD ["python", "main.py"]
