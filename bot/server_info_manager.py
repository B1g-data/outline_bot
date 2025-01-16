import json
import os
import time
from outline_vpn.outline_vpn import OutlineVPN
from .config import OUTLINE_API_URL, CERT_SHA256

outline_client = OutlineVPN(OUTLINE_API_URL, CERT_SHA256)

class ServerInfoManager:
    def __init__(self, server_info_file="server_info.json", max_retries=3, retry_delay=2):
        self.server_info_file = server_info_file
        self.max_retries = max_retries  # Максимальное количество попыток
        self.retry_delay = retry_delay  # Задержка между попытками в секундах

    def save_server_info(self):
        """Получает информацию о сервере и сохраняет в файл JSON с попытками повторить при ошибке."""
        attempt = 0
        while attempt < self.max_retries:
            try:
                # Получаем информацию о сервере
                server_info = outline_client.get_server_information()

                # Сохраняем информацию в JSON файл
                with open(self.server_info_file, "w", encoding="utf-8") as json_file:
                    json.dump(server_info, json_file, ensure_ascii=False, indent=4)

                print(f"Информация о сервере успешно сохранена в {self.server_info_file}")
                return  # Если операция успешна, выходим из метода

            except Exception as e:
                attempt += 1
                print(f"Ошибка при получении или сохранении информации о сервере: {e}")
                if attempt < self.max_retries:
                    print(f"Попытка {attempt} не удалась. Повтор через {self.retry_delay} секунд.")
                    time.sleep(self.retry_delay)  # Задержка перед повторной попыткой
                else:
                    print("Достигнуто максимальное количество попыток.")
                    return None  # После всех попыток возвращаем None

    def load_server_info(self):
        """Загружает информацию о сервере из файла JSON с попытками повторить при ошибке."""
        attempt = 0
        while attempt < self.max_retries:
            try:
                if os.path.exists(self.server_info_file):
                    with open(self.server_info_file, "r", encoding="utf-8") as json_file:
                        server_info = json.load(json_file)
                    return server_info
                else:
                    print(f"Файл {self.server_info_file} не найден.")
                    return None

            except Exception as e:
                attempt += 1
                print(f"Ошибка при загрузке информации о сервере: {e}")
                if attempt < self.max_retries:
                    print(f"Попытка {attempt} не удалась. Повтор через {self.retry_delay} секунд.")
                    time.sleep(self.retry_delay)  # Задержка перед повторной попыткой
                else:
                    print("Достигнуто максимальное количество попыток.")
                    return None  # После всех попыток возвращаем None
