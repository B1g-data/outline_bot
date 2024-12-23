import logging
import os
from telegram.ext import Application, CommandHandler
from bot.handlers import start, list_keys, add_key, delete_key, limit_traffic, remove_limit
from dotenv import load_dotenv

# Загружаем переменные окружения из .env файла
load_dotenv()

# Настройка логирования
logging.basicConfig(format="%(asctime)s - %(name)s - %(levelname)s - %(message)s", level=logging.INFO)
logger = logging.getLogger(__name__)

def main():
    """Запуск бота"""
    # Создаем экземпляр приложения с токеном Telegram
    application = Application.builder().token(os.getenv("TELEGRAM_BOT_TOKEN")).build()

    # Добавляем обработчики команд
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("list", list_keys))
    application.add_handler(CommandHandler("add", add_key))
    application.add_handler(CommandHandler("delete", delete_key))
    application.add_handler(CommandHandler("limit", limit_traffic))
    application.add_handler(CommandHandler("rem_limit", remove_limit))

    # Запуск бота
    logger.info("Bot is running...")
    application.run_polling()

if __name__ == '__main__':
    main()
