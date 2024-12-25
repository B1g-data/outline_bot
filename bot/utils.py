from telegram import Update
from telegram.ext import CallbackContext
import os
from .config import ALLOWED_USER_ID

def restricted(func):
    async def wrapper(update: Update, context: CallbackContext, *args, **kwargs):
        user_id = None

        # Проверяем, что за запрос (сообщение или callback_query)
        if update.message:
            user_id = update.message.from_user.id  # Если это сообщение, берем user_id из сообщения
        elif update.callback_query:
            user_id = update.callback_query.from_user.id  # Если это callback_query, берем user_id из него

        if user_id != int(ALLOWED_USER_ID):
            await update.message.reply_text("⚠️ У вас нет доступа к этому боту.") if update.message else \
                await update.callback_query.answer("⚠️ У вас нет доступа к этому боту.")
            return

        return await func(update, context, *args, **kwargs)

    return wrapper
