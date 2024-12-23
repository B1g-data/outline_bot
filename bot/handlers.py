from telegram import Update
from telegram.ext import CallbackContext
from .outline_api import OutlineVPN
from .config import OUTLINE_API_URL, CERT_SHA256
import os
from .utils import restricted  # Импорт декоратора
from telegram.helpers import escape_markdown

# Инициализация клиента OutlineAPI
outline_client = OutlineVPN(OUTLINE_API_URL, CERT_SHA256)

@restricted
async def start(update: Update, context: CallbackContext) -> None:
    """Обработка команды /start"""
    text = f"{
        "Добро пожаловать! Я бот для управления сервером Outline.\n\n"
        "📝 Доступные команды:\n\n"
        "🔑 /list - Показать все ключи.\n"
        "➕ /add <имя> - Добавить новый ключ. Если имя не указано, будет использовано значение по умолчанию.\n"
        "❌ /delete <id> - Удалить ключ по ID.\n"
        "📊 /limit <имя|id|ключ> - Ограничить трафик до нуля для выбранного ключа.\n"
        "🚫 /rem_limit <имя|id|ключ> - Снять ограничение с трафика для выбранного ключа.\n"
    }"

    # Экранирование Markdown символов
    escaped_text = escape_markdown(text, version=2)

    await update.message.reply_text(escaped_text, parse_mode='MarkdownV2')



@restricted
async def list_keys(update: Update, context: CallbackContext) -> None:
    """Обработка команды /list"""
    try:
        keys = outline_client.get_keys()
        if not keys:
            await update.message.reply_text("🔓 Нет доступных ключей.", parse_mode='Markdown')
            return

        message = "🔑 Список ключей:\n\n"
        messages = []  # Список сообщений для отправки

        # Формируем строку для каждого ключа
        for key in keys:
            key_message = (
                f"📄 ID: {getattr(key, 'key_id', 'Не указан')}, "
                f"👤 Имя: {getattr(key, 'name', 'Без имени')}, "
                f"📊 Трафик: {getattr(key, 'data_limit', 'Не указан')}, "
                f"🔗 Ссылка: `{getattr(key, 'access_url', 'Не указана')}`\n\n"
            )

            # Если длина сообщения превышает 4096 символов, сохраняем это сообщение в список
            if len(message) > 4000:
                messages.append(message)  # Добавляем в список сообщение до достижения лимита
                message = key_message  # Начинаем новый блок сообщения с текущего ключа

            message += key_message

        # Добавляем оставшееся сообщение
        if message:
            messages.append(message)

        # Отправляем все сообщения
        for msg in messages:
            await update.message.reply_text(msg, parse_mode='Markdown')

    except Exception as e:
        await update.message.reply_text(f"⚠️ Произошла ошибка при получении списка ключей: {e}", parse_mode='Markdown')

@restricted
async def add_key(update: Update, context: CallbackContext) -> None:
    """Обработка команды /add"""
    try:
        # Получаем имя из аргументов команды, если оно передано
        key_name = "Без имени"  # Значение по умолчанию
        if context.args:
            key_name = " ".join(context.args)  # Соединяем все аргументы в строку

        new_key = outline_client.create_key(name=key_name)  

        # Доступ к данным через свойства объекта
        key_id = new_key.key_id
        access_url = new_key.access_url

        message = (
            "✅ Новый ключ успешно создан!\n\n"
            f"📄 ID: {key_id}\n\n"
            f"🔗 Ссылка: `{access_url}`\n\n"  # Ссылка теперь кликабельная
            f"📝 Имя: {key_name}\n\n"
            "Вы можете использовать этот ключ для подключения к Outline. "
            "Сохраните его в безопасном месте! 🛡️"
        )
        await update.message.reply_text(message, parse_mode='Markdown')  # Указание на использование Markdown
    except AttributeError as e:
        await update.message.reply_text("⚠️ Ошибка при создании ключа. Проверьте настройки клиента.", parse_mode='Markdown')
    except Exception as e:
        await update.message.reply_text("⚠️ Произошла ошибка при создании нового ключа.", parse_mode='Markdown')

@restricted
async def delete_key(update: Update, context: CallbackContext) -> None:
    """Обработка команды /delete <id>"""
    if len(context.args) != 1:
        await update.message.reply_text("⚠️ Использование: /delete <id>")
        return

    key_id = context.args[0]
    try:
        outline_client.delete_key(key_id)  
        await update.message.reply_text(f"✅ Ключ с ID {key_id} успешно удалён.")
    except Exception as e:
        await update.message.reply_text("⚠️ Произошла ошибка при удалении ключа.")

@restricted
async def delete_key(update: Update, context: CallbackContext) -> None:
    """Обработка команды /delete <id>"""
    if len(context.args) < 1:
        await update.message.reply_text("⚠️ Использование: /rem_limit <имя|id|ключ>")
        return
    
    # Получаем входные данные (имя, ID или ключ)
    input_value = " ".join(context.args)  # Соединяем все части аргумента (если есть пробелы)
    try:
        # Пробуем найти ключ по имени
        keys = outline_client.get_keys()
        key = None

        # Ищем ключ по имени
        for k in keys:
            if getattr(k, 'name', '').lower() == input_value.lower():
                key = k
                break

        # Если по имени не нашли, ищем по ID
        if not key:
            for k in keys:
                if str(k.key_id) == input_value:
                    key = k
                    break

        # Если по имени и ID не нашли, ищем по ключу
        if not key:
            for k in keys:
                if str(k.access_url) == input_value:
                    key = k
                    break

        # Если ключ найден, ограничиваем его трафик
        if key:
            # Ограничиваем трафик до нуля
            status = outline_client.delete_key(key.key_id)  
            await update.message.reply_text(f"✅ Ключ с ID {key.key_id} успешно удалён.")
    except Exception as e:
        await update.message.reply_text("⚠️ Произошла ошибка при удалении ключа.")

@restricted
async def limit_traffic(update: Update, context: CallbackContext) -> None:
    """Обработка команды /limit, ограничивает трафик до нуля."""
    if len(context.args) < 1:
        await update.message.reply_text("⚠️ Использование: /rem_limit <имя|id|ключ>")
        return
    
    # Получаем входные данные (имя, ID или ключ)
    input_value = " ".join(context.args)  # Соединяем все части аргумента (если есть пробелы)
    try:
        # Пробуем найти ключ по имени
        keys = outline_client.get_keys()
        key = None

        # Ищем ключ по имени
        for k in keys:
            if getattr(k, 'name', '').lower() == input_value.lower():
                key = k
                break

        # Если по имени не нашли, ищем по ID
        if not key:
            for k in keys:
                if str(k.key_id) == input_value:
                    key = k
                    break

        # Если по имени и ID не нашли, ищем по ключу
        if not key:
            for k in keys:
                if str(k.access_url) == input_value:
                    key = k
                    break

        # Если ключ найден, ограничиваем его трафик
        if key:
            # Ограничиваем трафик до нуля
            status = outline_client.add_data_limit(key.key_id, 0)
            await update.message.reply_text(f"✅ Трафик для ключа {key.key_id} ограничен до нуля.")
        else:
            await update.message.reply_text("⚠️ Ключ не найден. Проверьте правильность введённых данных.")
    
    except Exception as e:
        await update.message.reply_text("⚠️ Произошла ошибка при ограничении трафика.")

@restricted
async def remove_limit(update: Update, context: CallbackContext) -> None:
    """Обработка команды /remove, снимает лимит с трафика."""
    if len(context.args) < 1:
        await update.message.reply_text("⚠️ Использование: /rem_limit <имя|id|ключ>")
        return
    
    # Получаем входные данные (имя, ID или ключ)
    input_value = " ".join(context.args)  # Соединяем все части аргумента (если есть пробелы)
    try:
        # Пробуем найти ключ по имени
        keys = outline_client.get_keys()
        key = None

        # Ищем ключ по имени
        for k in keys:
            if getattr(k, 'name', '').lower() == input_value.lower():
                key = k
                break

        # Если по имени не нашли, ищем по ID
        if not key:
            for k in keys:
                if str(k.key_id) == input_value:
                    key = k
                    break

        # Если по имени и ID не нашли, ищем по ключу
        if not key:
            for k in keys:
                if str(k.access_url) == input_value:
                    key = k
                    break

        # Если ключ найден, снимаем лимит с трафика
        if key:
            # Снимаем ограничение на трафик
            status = outline_client.delete_data_limit(key.key_id)  # Используем функцию delete_data_limit для снятия лимита
            await update.message.reply_text(f"✅ Лимит на трафик для ключа {key.key_id} снят.")
        else:
            await update.message.reply_text("⚠️ Ключ не найден. Проверьте правильность введённых данных.")
    
    except Exception as e:
        await update.message.reply_text("⚠️ Произошла ошибка при снятии лимита трафика.")