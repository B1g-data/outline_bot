from telegram import Update
from telegram.ext import CallbackContext
from outline_vpn.outline_vpn import OutlineVPN
from .config import OUTLINE_API_URL, CERT_SHA256
from .utils import restricted  # Импорт декоратора
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import CallbackContext
import json
from urllib.parse import urlparse
import os
from bot.key_updater import KeyUpdater

key_updater = KeyUpdater()

# Инициализация клиента OutlineAPI
outline_client = OutlineVPN(OUTLINE_API_URL, CERT_SHA256)

keys = []

def update_keys():
    """Функция для обновления ключей"""
    try:
        # Получаем новые ключи
        global keys
        keys = outline_client.get_keys()
       
    except Exception as e:
        print(f"Ошибка при обновлении ключей: {e}")


def find_key(keys, input_value):
    """Ищет ключ по имени, ID или access_url."""
    input_value_lower = str(input_value[0])  # Подготовка строки один раз
    for k in keys:
        name = " ".join(k.get('name', '').lower().split())
        key_id = str(k.get('key_id'))
        access_url = str(k.get('access_url'))
        
        if name == input_value_lower or key_id == input_value_lower or access_url == input_value_lower:
            return k  # Возвращаем найденный ключ
    return None  # Если ключ не найден


def load_keys_from_file():
    """Функция для загрузки ключей из файла keys.json"""
    try:
        with open("keys.json", "r", encoding="utf-8") as file:
            keys = json.load(file)
        return keys
    except Exception as e:
        print(f"Ошибка при загрузке ключей из файла: {e}")
        return []

async def load_server_info_from_file(file_path="server_info.json", update=None):
    """
    Загружает информацию о сервере из указанного файла JSON.
    В случае ошибки возвращает сообщение и None.
    """
    try:
        with open(file_path, "r", encoding="utf-8") as file:
            server_info = json.load(file)
        return server_info  # Если загрузка прошла успешно, возвращаем данные

    except FileNotFoundError:
        if update:
            await update.message.reply_html("⚠️ Файл с информацией о сервере не найден.")
        return None  # Возвращаем None, если файл не найден

    except json.JSONDecodeError:
        if update:
            await update.message.reply_html("⚠️ Ошибка при чтении файла с информацией о сервере.")
        return None  # Возвращаем None, если произошла ошибка при декодировании JSON


@restricted
async def start(update: Update, context: CallbackContext) -> None:
    """Обработка команды /start"""
    text = (
        "<b>Добро пожаловать!</b> Я бот для управления сервером Outline.\n\n"
        "📝 <i>Доступные команды:</i>\n\n"
        "🚀 <b>/start</b> - Показать ещё раз набор доступных команд.\n\n"
        "🖥 <b>/server_info</b> - Показать информацию о Вашем сервере Outline VPN.\n\n"
        "🔑 <b>/list</b> - Показать все ключи.\n\n"
        "➕ <code>/add </code>&lt;имя&gt; - Добавить новый ключ. Если имя не указано, будет использовано значение по умолчанию.\n\n"
        "❌ <code>/delete </code>&lt;имя|id|ключ&gt; - Удалить ключ.\n\n"
        "📊 <code>/limit </code>&lt;имя|id|ключ&gt; - Ограничить трафик до нуля для выбранного ключа.\n\n"
        "🚫 <code>/rem_limit </code>&lt;имя|id|ключ&gt; - Снять ограничение с трафика для выбранного ключа.\n\n"
        "📁 <code>/key_info </code>&lt;имя|id|ключ&gt; - Получить информацию о ключе.\n\n"
        "📥 <code>/key_file </code>&lt;имя|id|ключ&gt; - Скачать JSON файл с информацией о ключе.\n\n"
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

    elif query:
        message = query.message
    
    keys = load_keys_from_file()

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
            key_id = key.get("key_id", "Не указан")
            name = key.get("name", "Без имени")
            data_limit = "No limit" if key.get("data_limit") is None else "Ограничен"
            access_url = key.get("access_url", "Не указано")


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

        # Создаем новый ключ с помощью клиента Outline
        new_key = outline_client.create_key(name=key_name)

        # Формируем новый ключ в виде словаря
        new_key_dict = {
            "key_id": str(new_key.key_id),
            "name": key_name,
            "password": new_key.password,
            "port": new_key.port,
            "method": new_key.method,
            "access_url": new_key.access_url,
            "used_bytes": new_key.used_bytes,
            "data_limit": new_key.data_limit
        }

        # Загрузка существующих ключей из файла
        keys = load_keys_from_file()

        # Добавляем новый ключ в список
        keys.append(new_key_dict)

        # Сохраняем обновленный список ключей в файл
        with open("keys.json", "w", encoding="utf-8") as file:
            json.dump(keys, file, ensure_ascii=False, indent=4)

        # Сообщение пользователю
        message = (
            "✅ Новый ключ успешно создан!\n\n"
            f"<b>- ID:</b>  {new_key.key_id}\n\n"
            f"<b>- Имя:</b>  {key_name}\n\n"
            f"🔗  <code>{new_key.access_url}</code>\n\n" 
            "Вы можете использовать этот ключ для подключения к Outline. "
            "Сохраните его в безопасном месте! 🛡️"
        )
        
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
    
    try:
        # Загрузка ключей из файла (делаем это один раз)
        keys = load_keys_from_file()

        # Поиск ключа
        key = find_key(keys, context.args)

        # Если ключ найден, удаление ключа
        if key:
            # Удаляем ключ с помощью Outline API
            status = outline_client.delete_key(key['key_id'])  # Используем строковый ID

            if status:
                # Удаляем ключ из списка
                keys.remove(key)

                # Сохраняем обновленный список ключей в файл
                with open("keys.json", "w", encoding="utf-8") as file:
                    json.dump(keys, file, ensure_ascii=False, indent=4)

                await update.message.reply_text(f"✅ Ключ с ID {key['key_id']} успешно удалён.")
            else:
                await update.message.reply_text("⚠️ Не удалось удалить ключ через API.")
        else:
            await update.message.reply_text("⚠️ Ключ не найден.")
    
    except Exception as e:
        await update.message.reply_text(f"⚠️ Произошла ошибка при удалении ключа: {e}")

@restricted
async def limit_traffic(update: Update, context: CallbackContext) -> None:
    """Обработка команды /limit, ограничивает трафик до нуля."""
    if len(context.args) < 1:
        await update.message.reply_text("⚠️ Использование: /limit <имя|id|ключ>")
        return
    try:
        keys = load_keys_from_file()

        key = find_key(keys, context.args)

        # Если ключ найден, ограничиваем его трафик
        if key:
            # Ограничиваем трафик до нуля
            status = outline_client.add_data_limit(key['key_id'], 0)
            if status:
                await update.message.reply_text(f"✅ Трафик для ключа {key['key_id']} ограничен до нуля.")

                # Обновляем данные в ключах
                for k in keys:
                    if k['key_id'] == key['key_id']:
                        k['data_limit'] = 0
                        break

                with open("keys.json", "w", encoding="utf-8") as file:
                    json.dump(keys, file, ensure_ascii=False, indent=4)

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
    
    try:
        keys = load_keys_from_file()

        key = find_key(keys, context.args)

        # Если ключ найден, снимаем лимит с трафика
        if key:
            # Снимаем ограничение на трафик
            status = outline_client.delete_data_limit(key['key_id'])
            if status:
                await update.message.reply_text(f"✅ Лимит на трафик для ключа {key['key_id']} снят.")

                # Обновляем данные в ключах
                for k in keys:
                    if k['key_id'] == key['key_id']:
                        k['data_limit'] = None
                        break

                with open("keys.json", "w", encoding="utf-8") as file:
                    json.dump(keys, file, ensure_ascii=False, indent=4)

        else:
            await update.message.reply_text("⚠️ Ключ не найден. Проверьте правильность введённых данных.")
    
    except Exception as e:
        await update.message.reply_text("⚠️ Произошла ошибка при снятии лимита трафика.")

@restricted
async def server_info(update: Update, context: CallbackContext) -> None:
    """Обработка команды /serverinfo"""
    try:
        # Загружаем ключи из файла
        keys = load_keys_from_file()

        # Проверяем, что ключи загружены корректно
        if not keys:
            await update.message.reply_html("⚠️ Не удалось загрузить данные о ключах.")
            return

        # Загружаем информацию о сервере из файла
        server_info = await load_server_info_from_file()

        # Формируем информацию о пользователях с трафиком
        user_data = [
            {
                "name": key["name"],
                "id": key["key_id"],
                # Проверяем, что tрафик не None, если None - считаем, что трафика нет
                "traffic": (key["used_bytes"] or 0) / (1024 ** 3)  # Переводим трафик в гигабайты, если None - считаем 0
            }
            for key in keys
        ]

        # Подсчёт общей информации
        total_traffic = sum(user["traffic"] for user in user_data)
        user_count = len(user_data)

        # Формирование сообщения
        message = (
            "🖥 Информация о Вашем сервере Outline VPN\n\n"
            f"Имя сервера: {server_info.get('name', 'Не указано')}\n"
            f"Версия сервера: {server_info.get('version', 'Не указана')}\n"
            f"Общее количество пользователей: {user_count}\n"
            f"Суммарный трафик: {total_traffic:.2f} ГБ\n\n"
            "📊 Детальная информация по пользователям:\n"
        )

        # Добавление информации о пользователях
        for i, user in enumerate(user_data):
            message += f"{i+1}. {user['name']} (ID: {user['id']}): {user['traffic']:.2f} ГБ\n"

        # Отправляем сообщение
        await update.message.reply_html(message)

    except Exception as e:
        # Обработка ошибок общего характера
        await update.message.reply_html("⚠️ Произошла ошибка при получении информации о сервере.")
        print(f"Ошибка: {e}")

@restricted
async def key_info(update: Update, context: CallbackContext) -> None:
    """Обработка команды /key_info <имя|id|ключ> для получения информации о ключе"""
    if len(context.args) < 1:
        await update.message.reply_text("⚠️ Использование: /key_info <имя|id|ключ>")
        return

    try:
        # Загружаем ключи из файла
        keys = load_keys_from_file()

        # Находим ключ по имени, ID или ключу
        key = find_key(keys, context.args)

        # Загружаем информацию о сервере из файла
        server_info = await load_server_info_from_file()

        # Проверка на наличие данных ключа
        if not key:
            await update.message.reply_html("⚠️ Не удалось получить информацию о ключе.")
            return
        
        if not server_info:
            await update.message.reply_html("⚠️ Не удалось получить информацию о сервере (адрес и порт, перезапустите бота).")
            return

        server_address = server_info.get('hostnameForAccessKeys', 'Не указан')
        server_port = server_info.get('portForNewAccessKeys', 'Не указан')

        # Формируем строку с подробной информацией о ключе
        key_info = (
            f"<b>Информация о ключе {key['key_id']}:</b>\n\n"
            f"<b>Имя пользователя:</b> {key['name']}\n"
            f"<b>Сервер:</b> {server_address}\n"
            f"<b>Порт сервера:</b> {server_port}\n"
            f"<b>Пароль:</b> {key.get('password', 'Не указан')}\n"
            f"<b>Метод шифрования:</b> {key.get('method', 'Не указан')}\n"
            f"<b>Потреблено трафика:</b> {key['used_bytes'] / (1024 ** 3):.2f} ГБ\n"
        )

        # Отправляем ответ с информацией о ключе
        await update.message.reply_html(key_info)

    except Exception as e:
        # Обработка ошибок: информируем пользователя, если что-то пошло не так
        await update.message.reply_html(f"⚠️ Произошла ошибка при получении информации о ключе: {e}")


@restricted
async def key_file(update: Update, context: CallbackContext) -> None:
    """Обработка команды /keyfile <имя|id|ключ>, возвращает json файл"""
    if len(context.args) < 1:
        await update.message.reply_text("⚠️ Использование: /keyfile <имя|id|ключ>")
        return

    try:
        # Загружаем ключи из файла
        keys = load_keys_from_file()

        # Находим ключ по имени, ID или ключу
        key = find_key(keys, context.args)

        # Загружаем информацию о сервере из файла
        server_info = await load_server_info_from_file()

        # Проверка на наличие данных ключа
        if not key:
            await update.message.reply_html("⚠️ Не удалось получить информацию о ключе.")
            return
        
        if not server_info:
            await update.message.reply_html("⚠️ Не удалось получить информацию о сервере (адрес и порт, перезапустите бота).")
            return

        server_address = server_info.get('hostnameForAccessKeys', 'Не указан')
        server_port = server_info.get('portForNewAccessKeys', 'Не указан')

        # Формируем данные для JSON
        response = {
            "server": server_address,  # IP сервера
            "server_port": server_port,  # Порт сервера
            "password": key.get('password', "Не указан"),  # Пароль для подключения
            "timeout": "300",  # Время ожидания
            "method": key.get('method', "Не указан"),  # Метод шифрования
            "fast_open": "True"  # Быстрое соединение
        }

        # Сохраняем JSON в файл
        file_path = f"config_{key['key_id']}.json"
        with open(file_path, "w", encoding="utf-8") as json_file:
            json.dump(response, json_file, ensure_ascii=False, indent=2)

        # Отправляем JSON-файл пользователю
        with open(file_path, "rb") as json_file:
            await update.message.reply_document(document=json_file, filename=file_path)

        # Удаляем временный файл после отправки
        os.remove(file_path)

    except Exception as e:
        await update.message.reply_html(f"⚠️ Произошла ошибка при отправке файла: {e}")