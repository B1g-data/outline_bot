import os
from dotenv import load_dotenv

load_dotenv()  # Загружает переменные из .env файла

OUTLINE_API_URL = os.getenv("OUTLINE_API_URL")
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
CERT_SHA256 = os.getenv("CERT_SHA256")
ALLOWED_USER_ID = os.getenv("ALLOWED_USER_ID")

if not OUTLINE_API_URL or not TELEGRAM_BOT_TOKEN or not CERT_SHA256:
    raise ValueError("Не заданы все необходимые переменные окружения.")
