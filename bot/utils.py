from telegram import Update
from telegram.ext import CallbackContext
import os
from .config import ALLOWED_USER_ID

# Декоратор для проверки прав пользователя
def restricted(func):
    async def wrapper(update: Update, context: CallbackContext, *args, **kwargs):
        if (update.message.from_user.id) != int(ALLOWED_USER_ID):
            await update.message.reply_text("⚠️ У вас нет доступа к этому боту.")
            return
        return await func(update, context, *args, **kwargs)
    return wrapper
