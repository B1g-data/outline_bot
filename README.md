# Outline Bot для VDS

Этот бот предназначен для управления **Outline** на вашем **VDS**. После установки Outline на сервер, вы можете использовать бота для управления им через Telegram.

## Шаги для установки и настройки

1. Получите свой **ID** в [@userinfobot](https://t.me/userinfobot).
   
2. Создайте нового бота в [@BotFather](https://t.me/BotFather):
   - Напишите команду `/newbot` в чат с BotFather.
   - Укажите имя и username для бота.
   - Получите **токен** для вашего нового бота.

3. Запустите установочный скрипт:
   ```bash
   bash <(curl -s https://raw.githubusercontent.com/B1g-data/outline_bot/refs/heads/main/install_and_run.sh)
4. Введите свой ID из [@userinfobot](https://t.me/userinfobot).

5. Введите токен бота, который вы получили от [@BotFather](https://t.me/BotFather).

Готово! После запуска контейнера отправьте команду /start вашему боту в Telegram, и можно приступать к использованию.

Использование
После установки и настройки, ваш бот будет готов к управлению Outline. Отправьте команду /start в чат с ботом, чтобы начать.

Примечания
Убедитесь, что ваш сервер с Outline доступен и настроен корректно.
