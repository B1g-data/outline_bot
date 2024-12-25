from telegram import Update
from telegram.ext import CallbackContext
from .outline_api import OutlineVPN
from .config import OUTLINE_API_URL, CERT_SHA256
from .utils import restricted  # Импорт декоратора
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import CallbackContext

# Инициализация клиента OutlineAPI
outline_client = OutlineVPN(OUTLINE_API_URL, CERT_SHA256)

keys = []

def update_keys():
    """Функция для обновления ключей"""
    try:
        # Получаем новые ключи
        global keys
        keys = outline_client.get_keys()
       
        print("Ключи обновлены.")
    except Exception as e:
        print(f"Ошибка при обновлении ключей: {e}")

@restricted
async def start(update: Update, context: CallbackContext) -> None:
    """Обработка команды /start"""
    # Текст с HTML-разметкой
    text = (
        "<b>Добро пожаловать!</b> Я бот для управления сервером Outline.""\n\n"
        "📝 <i>Доступные команды:</i>""\n\n"
        "🚀 <b>/start</b> - Показать ещё раз набор доступных команд.""\n\n"
        "🔑 <b>/list</b> - Показать все ключи.""\n\n"
        "➕ <code>/add </code>&lt;имя&gt; - Добавить новый ключ. Если имя не указано, будет использовано значение по умолчанию.""\n\n"
        "❌ <code>/delete </code>&lt;имя|id|ключ&gt; - Удалить ключ.""\n\n"
        "📊 <code>/limit </code>&lt;имя|id|ключ&gt; - Ограничить трафик до нуля для выбранного ключа.""\n\n"
        "🚫 <code>/rem_limit </code>&lt;имя|id|ключ&gt; - Снять ограничение с трафика для выбранного ключа."
    )

    await update.message.reply_text(text, parse_mode='HTML')
    update_keys()


@restricted
async def list_keys(update: Update, context: CallbackContext) -> None:
    query = update.callback_query
    message = None

    # Если это команда /list, используем message, иначе используем callback_query
    if update.message:
        message = update.message
        update_keys()

    elif query:
        message = query.message

    try:
        if not keys:
            await message.reply_text("🔓 Нет доступных ключей.", parse_mode='HTML')
            return

        # Параметры пагинации
        limit = 5  # Количество ключей на одной странице

        # Обработка offset в случае нажатия на кнопку
        offset = int(query.data.split('_')[1]) if query else (int(context.args[0]) if context.args else 0)

        # Вычисляем подсписок ключей, соответствующих текущей странице
        paginated_keys = keys[offset:offset + limit]

        if not paginated_keys:
            await message.reply_text("🔓 Нет доступных ключей на этой странице.", parse_mode='HTML')
            return

        # Формируем сообщение с ключами
        message_text = "🔑 <b>Список ключей:</b>\n\n"
        message_parts = []
        for key in paginated_keys:
            key_id = getattr(key, "key_id", "Не указан")
            name = getattr(key, "name", "Без имени")
            data_limit = getattr(key, "data_limit", "No limit") if getattr(key, "data_limit", None) else "No limit"
            access_url = getattr(key, "access_url", "Не указано")

            message_parts.append(
                f"<b>- ID:</b> {key_id},\n"
                f"<b>- Имя:</b> {name},\n"
                f"<b>- Трафик:</b> {data_limit},\n"
                f"<b>🔗</b> <code>{access_url}</code>\n\n"
            )

        message_text += "".join(message_parts)

        # Создаем кнопки для пагинации
        keyboard = []
        if offset > 0:
            keyboard.append([InlineKeyboardButton("Назад", callback_data=f"list_{offset - limit}")])

        if offset + limit < len(keys):
            keyboard.append([InlineKeyboardButton("Вперед", callback_data=f"list_{offset + limit}")])

        reply_markup = InlineKeyboardMarkup(keyboard)

        # Если это команда /list, отправляем новое сообщение с текстом и кнопками
        if not query:
            await message.reply_text(message_text, parse_mode='HTML', reply_markup=reply_markup)
        # Если это нажатие кнопки, обновляем существующее сообщение
        else:
            await message.edit_text(message_text, parse_mode='HTML', reply_markup=reply_markup)

    except Exception as e:
        await message.reply_text(
            f"⚠️ <b>Произошла ошибка при получении списка ключей:</b> {e}", 
            parse_mode='HTML'
        )


@restricted
# Обработчик для пагинации (обработка кнопок)
async def handle_pagination(update: Update, context: CallbackContext):
    await list_keys(update, context)


@restricted
async def add_key(update: Update, context: CallbackContext) -> None:
    """Обработка команды /add"""
    try:
        # Получаем имя из аргументов команды, если оно передано
        key_name = ""  # Значение по умолчанию
        if context.args:
            key_name = " ".join(context.args)  # Соединяем все аргументы в строку

        new_key = outline_client.create_key(name=key_name)  

        # Доступ к данным через свойства объекта
        key_id = new_key.key_id
        access_url = new_key.access_url

        message = (
            "✅ Новый ключ успешно создан!\n\n"
            f"<b>- ID:</b>  {key_id}\n\n"
            f"<b>- Имя:</b>  {key_name}\n\n"
            f"<b>🔗</b>  {access_url}\n\n" 
            "Вы можете использовать этот ключ для подключения к Outline. "
            "Сохраните его в безопасном месте! 🛡️"
        )
        update_keys()
        await update.message.reply_html(message)  # Использование HTML разметки
    except AttributeError as e:
        await update.message.reply_html("⚠️ Ошибка при создании ключа. Проверьте настройки клиента.")
    except Exception as e:
        await update.message.reply_html("⚠️ Произошла ошибка при создании нового ключа.")

@restricted
async def delete_key(update: Update, context: CallbackContext) -> None:
    """Обработка команды /delete <имя|id|ключ>"""
    if len(context.args) < 1:
        await update.message.reply_text("⚠️ Использование: /delete <имя|id|ключ>")
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
            if status:
                await update.message.reply_text(f"✅ Ключ с ID {key.key_id} успешно удалён.")
                await update_keys()
    except Exception as e:
        await update.message.reply_text("⚠️ Произошла ошибка при удалении ключа.")

@restricted
async def limit_traffic(update: Update, context: CallbackContext) -> None:
    """Обработка команды /limit, ограничивает трафик до нуля."""
    if len(context.args) < 1:
        await update.message.reply_text("⚠️ Использование: /limit <имя|id|ключ>")
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
            if status:
                await update.message.reply_text(f"✅ Трафик для ключа {key.key_id} ограничен до нуля.")
                update_keys()
        else:
            await update.message.reply_text("⚠️ Ключ не найден. Проверьте правильность введённых данных.")
    
    except Exception as e:
        await update.message.reply_text("⚠️ Произошла ошибка при ограничении трафика.")

@restricted
async def remove_limit(update: Update, context: CallbackContext) -> None:
    """Обработка команды /rem_limit <имя|id|ключ>, снимает лимит с трафика."""
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
            if status:
                await update.message.reply_text(f"✅ Лимит на трафик для ключа {key.key_id} снят.")
                update_keys()
        else:
            await update.message.reply_text("⚠️ Ключ не найден. Проверьте правильность введённых данных.")
    
    except Exception as e:
        await update.message.reply_text("⚠️ Произошла ошибка при снятии лимита трафика.")
