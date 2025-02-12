import os
from telegram.ext import Application, CommandHandler
from bot.handlers import start, list_keys, add_key, delete_key, limit_traffic, remove_limit, update_keys, server_info, key_info, key_file
from bot.key_updater import KeyUpdater
from dotenv import load_dotenv

# Загружаем переменные окружения из .env файла
load_dotenv()

from telegram.ext import Application, CommandHandler, CallbackQueryHandler
from bot.handlers import start, list_keys, add_key, delete_key, limit_traffic, remove_limit, handle_pagination
from bot.key_updater import KeyUpdater
from bot.server_info_manager import ServerInfoManager

def main():
    """Запуск бота"""
    application = Application.builder().token(os.getenv("TELEGRAM_BOT_TOKEN")).build()

    # Добавляем обработчики команд
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("list", list_keys))
    application.add_handler(CommandHandler("add", add_key))
    application.add_handler(CommandHandler("delete", delete_key))
    application.add_handler(CommandHandler("limit", limit_traffic))
    application.add_handler(CommandHandler("rem_limit", remove_limit))
    application.add_handler(CommandHandler("server_info", server_info))
    application.add_handler(CommandHandler("key_info", key_info))
    application.add_handler(CommandHandler("key_file", key_file))

    # Обработчик для нажатий на кнопки пагинации
    application.add_handler(CallbackQueryHandler(handle_pagination, pattern="^list_"))

    # Создаем экземпляр KeyUpdater
    key_updater = KeyUpdater()
    
    # Запускаем обновление ключей каждые 1200 секунд
    key_updater.schedule_key_updates()

    # Создаем экземпляр ServerInfoManager
    server_info_manager = ServerInfoManager()

    # Загружаем инфу о сервере в файл
    server_info_manager.save_server_info()

    # Запуск бота
    application.run_polling()

if __name__ == '__main__':
    main()