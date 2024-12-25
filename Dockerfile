# Используем официальный образ Python 3.13 на базе Debian Slim
FROM python:3.13-slim

# Устанавливаем необходимые зависимости и очищаем кэш apt
RUN apt-get update && apt-get install --no-install-recommends -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

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
